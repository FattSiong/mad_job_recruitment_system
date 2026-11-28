-- =====================================================================
-- Community Hub and chat names, mock interview overall score
--
--   ChatRoom."user1_ID" / "user2_ID"  -> "user1ID" / "user2ID"
--   "PostSaved"                       -> "SavedPost"
--   PostComment."userID"              -> "authorID" (same as CommunityPost)
--   PostComment."updateAt"            -> "editedAt" (same as CommunityPost
--                                        and Message)
--   CommunityPost."category"          -> "topic"
--   search_community_posts(p_category) -> (p_topic)
--   MockInterviewSession."overallScore": no longer worked out by the
--     database; the mock-interview function saves it (0 to 100, needed
--     when the session is completed).
--
-- Data is kept. Access rules, indexes, CHECKs and keys follow the renames
-- by themselves; the database functions that use the old names are
-- written again below. Deploy the new app build and the send-push and
-- mock-interview functions straight after this. Safe to run again.
-- =====================================================================

-- ---------------------------------------------------------------------
-- 1. Renames
-- ---------------------------------------------------------------------
create or replace function pg_temp.rename_col(t text, old_name text, new_name text)
returns void language plpgsql as $$
begin
  if exists (select 1 from information_schema.columns
             where table_schema = 'public' and table_name = t and column_name = old_name)
     and not exists (select 1 from information_schema.columns
             where table_schema = 'public' and table_name = t and column_name = new_name) then
    execute format('alter table public.%I rename column %I to %I', t, old_name, new_name);
  end if;
end $$;

create or replace function pg_temp.rename_con(t text, old_name text, new_name text)
returns void language plpgsql as $$
begin
  if exists (select 1 from pg_constraint
             where conrelid = format('public.%I', t)::regclass and conname = old_name) then
    execute format('alter table public.%I rename constraint %I to %I', t, old_name, new_name);
  end if;
end $$;

-- Chat
select pg_temp.rename_col('ChatRoom', 'user1_ID', 'user1ID');
select pg_temp.rename_col('ChatRoom', 'user2_ID', 'user2ID');
select pg_temp.rename_con('ChatRoom', 'ChatRoom_user1_ID_fkey', 'ChatRoom_user1ID_fkey');
select pg_temp.rename_con('ChatRoom', 'ChatRoom_user2_ID_fkey', 'ChatRoom_user2ID_fkey');

-- Saved posts
do $$
begin
  if to_regclass('public."PostSaved"') is not null and to_regclass('public."SavedPost"') is null then
    alter table public."PostSaved" rename to "SavedPost";
  end if;
end $$;
select pg_temp.rename_con('SavedPost', 'PostSaved_pkey', 'SavedPost_pkey');
select pg_temp.rename_con('SavedPost', 'PostSaved_postID_fkey', 'SavedPost_postID_fkey');
select pg_temp.rename_con('SavedPost', 'PostSaved_userID_fkey', 'SavedPost_userID_fkey');
alter index if exists public.postsaved_user_idx rename to savedpost_user_idx;

-- Comments
select pg_temp.rename_col('PostComment', 'userID', 'authorID');
select pg_temp.rename_col('PostComment', 'updateAt', 'editedAt');
select pg_temp.rename_con('PostComment', 'PostComment_userID_fkey', 'PostComment_authorID_fkey');

-- Posts
select pg_temp.rename_col('CommunityPost', 'category', 'topic');
select pg_temp.rename_con('CommunityPost', 'CommunityPost_category_check', 'CommunityPost_topic_check');
alter index if exists public.community_post_category_idx rename to community_post_topic_idx;

-- ---------------------------------------------------------------------
-- 2. Mock interview overall score: a normal column
-- ---------------------------------------------------------------------
do $$
begin
  if exists (select 1 from pg_attribute
             where attrelid = 'public."MockInterviewSession"'::regclass
               and attname = 'overallScore' and attgenerated <> '') then
    -- keeps the scores already worked out
    alter table public."MockInterviewSession" alter column "overallScore" drop expression;
  end if;
end $$;

alter table public."MockInterviewSession"
  drop constraint if exists "MockInterviewSession_overallScore_check";
alter table public."MockInterviewSession"
  add constraint "MockInterviewSession_overallScore_check"
  check ("overallScore" between 0 and 100);

-- A completed interview needs all three scores
alter table public."MockInterviewSession" drop constraint if exists mock_session_completed_check;
alter table public."MockInterviewSession"
  add constraint mock_session_completed_check
  check ("status" <> 'completed'
         or ("completedAt" is not null and "contentScore" is not null
             and "deliveryScore" is not null and "overallScore" is not null));

-- ---------------------------------------------------------------------
-- 3. Database functions that used the old names
-- ---------------------------------------------------------------------

-- Chat
create or replace function public.app_is_chat_member(p_room_id uuid)
returns boolean
language sql
stable
security definer
set search_path = public
as $$
  select exists (
    select 1 from "ChatRoom" r
    where r."roomID" = p_room_id
      and auth.uid() in (r."user1ID", r."user2ID")
  );
$$;

create or replace function public.app_room_is_blocked(p_room_id uuid)
returns boolean
language sql
stable
security definer
set search_path = public
as $$
  select exists (
    select 1
    from "ChatRoom" r
    join "UserBlock" b
      on (b."blockerID" = r."user1ID" and b."blockedID" = r."user2ID")
      or (b."blockerID" = r."user2ID" and b."blockedID" = r."user1ID")
    where r."roomID" = p_room_id
      and auth.uid() in (r."user1ID", r."user2ID")
  );
$$;

create or replace function public.my_unread_counts()
returns table (room_id text, unread bigint)
language sql
stable
set search_path = public
as $$
  select m."roomID"::text, count(*)
  from public."Message" m
  join public."ChatRoom" r on r."roomID" = m."roomID"
  where (r."user1ID"::text = auth.uid()::text or r."user2ID"::text = auth.uid()::text)
    and m."isRead" = false
    and m."senderID"::text <> auth.uid()::text
    and not coalesce(m."isDeleted", false)
  group by m."roomID";
$$;

-- Posts: the author can't change the status or the owner; editedAt is
-- set here only
create or replace function public.app_community_post_before_update()
returns trigger
language plpgsql
set search_path = public
as $$
begin
  if auth.uid() is not null
     and old."authorID"::text = auth.uid()::text
     and not public.app_is_admin()
     and not public.app_in_moderation() then
    new."status" := old."status";
    new."authorID" := old."authorID";
    new."createdAt" := old."createdAt";
  end if;

  if not old."isDraft" and new."isDraft" then
    raise exception 'post_published: a published post cannot become a draft again';
  end if;

  if old."isDraft" and not new."isDraft" then
    -- Publishing a draft: it appears as a new post
    new."createdAt" := now();
    new."editedAt" := null;
  elsif not new."isDraft"
        and (new."content"  is distinct from old."content"
          or new."mediaURL" is distinct from old."mediaURL"
          or new."topic"    is distinct from old."topic") then
    new."editedAt" := now();
  else
    new."editedAt" := old."editedAt"; -- only the database sets it
  end if;
  return new;
end;
$$;

-- Comments: same rules
create or replace function public.app_post_comment_before_update()
returns trigger
language plpgsql
set search_path = public
as $$
begin
  if auth.uid() is not null
     and old."authorID"::text = auth.uid()::text
     and not public.app_is_admin()
     and not public.app_in_moderation() then
    new."status" := old."status";
    new."postID" := old."postID";
    new."authorID" := old."authorID";
    new."parentCommentID" := old."parentCommentID";
    new."createdAt" := old."createdAt";
  end if;

  if new."content" is distinct from old."content" then
    new."editedAt" := now();
  else
    new."editedAt" := old."editedAt"; -- only the database sets it
  end if;
  return new;
end;
$$;

create or replace function public.delete_my_comment(p_comment_id uuid)
returns integer
language plpgsql
security definer
set search_path = public
as $$
declare
  v_owner "PostComment"."authorID"%type;
  v_ids uuid[];
  v_count integer;
begin
  if auth.uid() is null then
    raise exception 'not_authenticated' using errcode = '28000';
  end if;

  select "authorID" into v_owner
  from "PostComment"
  where "commentID" = p_comment_id
  for update;

  if not found then
    return 0;
  end if;

  if v_owner::text <> auth.uid()::text then
    raise exception 'not_owner' using errcode = '42501';
  end if;

  -- The comment and every reply below it (any depth)
  with recursive thread as (
    select "commentID" from "PostComment" where "commentID" = p_comment_id
    union
    select c."commentID"
    from "PostComment" c
    join thread t on c."parentCommentID" = t."commentID"
  )
  select array_agg("commentID") into v_ids from thread;

  -- Something in the thread is reported and not handled yet -> hidden,
  -- kept for the admin
  if exists (select 1 from "ReportedComment"
             where "commentID" = any (v_ids) and "status" = 'pending') then
    perform set_config('app.moderation', 'on', true);
    update "PostComment" set "status" = 'author_deleted'
    where "commentID" = any (v_ids) and "status" = 'active';
    perform set_config('app.moderation', 'off', true);
    return coalesce(array_length(v_ids, 1), 0);
  end if;

  delete from "ReportedComment" where "commentID" = any (v_ids);
  delete from "PostComment" where "commentID" = any (v_ids);
  get diagnostics v_count = row_count;

  return v_count;
end;
$$;

create or replace function public.delete_my_post(p_post_id uuid)
returns text
language plpgsql
security definer
set search_path = public
as $$
declare
  v_author "CommunityPost"."authorID"%type;
begin
  if auth.uid() is null then
    raise exception 'not_authenticated' using errcode = '28000';
  end if;

  select "authorID" into v_author
  from "CommunityPost"
  where "postID" = p_post_id
  for update;

  if not found then
    return 'gone';
  end if;

  if v_author::text <> auth.uid()::text then
    raise exception 'not_owner' using errcode = '42501';
  end if;

  -- Reported and not handled yet -> hidden, kept for the admin
  if exists (select 1 from "ReportedPost"
             where "postID" = p_post_id and "status" = 'pending')
     or exists (select 1 from "ReportedComment" rc
                join "PostComment" c on c."commentID" = rc."commentID"
                where c."postID" = p_post_id and rc."status" = 'pending') then
    perform set_config('app.moderation', 'on', true);
    update "CommunityPost" set "status" = 'author_deleted' where "postID" = p_post_id;
    perform set_config('app.moderation', 'off', true);
    return 'hidden';
  end if;

  -- Reports about the post's comments, then the comments (all in one
  -- statement, so replies and their parents go together).
  delete from "ReportedComment"
  where "commentID" in (select "commentID" from "PostComment" where "postID" = p_post_id);

  delete from "PostComment"  where "postID" = p_post_id;
  delete from "PostLike"     where "postID" = p_post_id;
  delete from "SavedPost"    where "postID" = p_post_id;
  delete from "ReportedPost" where "postID" = p_post_id;

  delete from "CommunityPost" where "postID" = p_post_id;
  return 'deleted';
end;
$$;

create or replace function public.admin_remove_comment(
  p_comment_id uuid, p_note text default null, p_notify boolean default true)
returns integer
language plpgsql
security definer
set search_path = public
as $$
declare
  v_status text;
  v_author uuid;
  v_content text;
  v_reasons text;
  v_note text := nullif(btrim(coalesce(p_note, '')), '');
  v_admin uuid := public.app_moderator_id();
  v_ids uuid[];
begin
  if not public.app_is_admin() then
    raise exception 'not_admin' using errcode = '42501';
  end if;

  select "status", "authorID", "content" into v_status, v_author, v_content
  from "PostComment" where "commentID" = p_comment_id
  for update;
  if not found then
    raise exception 'not_found' using errcode = 'P0002';
  end if;

  v_reasons := public.app_report_reasons('comment', p_comment_id);

  with recursive thread as (
    select "commentID" from "PostComment" where "commentID" = p_comment_id
    union
    select c."commentID"
    from "PostComment" c
    join thread t on c."parentCommentID" = t."commentID"
  )
  select array_agg("commentID") into v_ids from thread;

  -- (comments their author already deleted keep that status)
  update "PostComment" set "status" = 'deleted'
  where "commentID" = any (v_ids) and "status" <> 'author_deleted';

  update "ReportedComment"
  set "status" = 'deleted', "resolvedAt" = now(), "adminID" = v_admin,
      "adminNotes" = coalesce(v_note, "adminNotes")
  where "commentID" = any (v_ids) and "status" = 'pending';

  -- Only the author of the removed comment is told (not the people who
  -- replied under it)
  if p_notify and v_status = 'active' and v_author::text <> auth.uid()::text then
    perform public.app_notify_user(
      v_author, 'community_comment_removed', 'Your comment was removed',
      public.app_removal_message('comment', v_content, v_reasons));
  end if;

  return coalesce(array_length(v_ids, 1), 0);
end;
$$;

-- Community search: p_category -> p_topic (a parameter name can only
-- change by dropping the function)
drop function if exists public.search_community_posts(text, text, text, timestamptz, text, text, integer, integer);

create function public.search_community_posts(
  p_search      text        default null,
  p_author_role text        default null,
  p_topic       text        default null,
  p_since       timestamptz default null,
  p_media       text        default null,
  p_sort        text        default 'newest',
  p_limit       integer     default 15,
  p_offset      integer     default 0)
returns table (post_id uuid)
language sql
stable
security definer
set search_path = public
as $$
  with term as (
    select lower(nullif(btrim(p_search), '')) as q
  ),
  posts as (
    select
      p."postID",
      p."createdAt",
      (select count(*) from "PostLike" l where l."postID" = p."postID") as likes,
      (select count(*) from "PostComment" c
        where c."postID" = p."postID"
          and coalesce(c."status", 'active') <> 'deleted') as comments
    from "CommunityPost" p
    cross join term t
    left join "User"      u  on u."userID"::text      = p."authorID"::text
    left join "JobSeeker" js on js."seekerID"::text   = p."authorID"::text
    left join "Employer"  e  on e."employerID"::text  = p."authorID"::text
    where auth.uid() is not null
      and p."status" = 'active'
      and not p."isDraft"
      and not exists (select 1 from "ReportedPost" r
                      where r."postID" = p."postID"
                        and r."reporterID"::text = auth.uid()::text)
      and (p_topic is null or p."topic" = p_topic)
      and (p_since is null or p."createdAt" >= p_since)
      and (p_author_role is null
           or coalesce(u."role",
                       case when e."employerID" is not null then 'employer' else 'job_seeker' end)
              = p_author_role)
      and (p_media is null
           or (p_media = 'image' and lower(coalesce(p."mediaURL", '')) ~ '\.(jpe?g|png|webp|gif)($|\?)')
           or (p_media = 'pdf'   and lower(coalesce(p."mediaURL", '')) ~ '\.pdf($|\?)'))
      and (t.q is null
           or strpos(lower(coalesce(p."content", '')), t.q) > 0
           or strpos(lower(coalesce(e."fullName", js."fullName", u."username", '')), t.q) > 0)
  )
  select "postID"
  from posts
  order by
    case p_sort
      when 'most_liked'     then likes
      when 'most_discussed' then comments
      else 0
    end desc,
    "createdAt" desc,
    "postID"
  limit least(greatest(coalesce(p_limit, 15), 1), 50)
  offset greatest(coalesce(p_offset, 0), 0);
$$;

revoke all on function public.search_community_posts(text, text, text, timestamptz, text, text, integer, integer)
  from public, anon;
grant execute on function public.search_community_posts(text, text, text, timestamptz, text, text, integer, integer)
  to authenticated;

-- ---------------------------------------------------------------------
-- 4. Anything else still using an old name (e.g. made in the dashboard)
-- ---------------------------------------------------------------------
do $$
declare
  r record;
begin
  for r in
    select p.proname
    from pg_proc p
    where p.pronamespace = 'public'::regnamespace
      and (p.prosrc ~ 'user[12]_ID|"PostSaved"|"updateAt"'
           or (p.prosrc ~ '"CommunityPost"' and p.prosrc ~ '"category"'))
  loop
    raise notice 'Function % may still use an old column name, please check it', r.proname;
  end loop;
end $$;

notify pgrst, 'reload schema';
