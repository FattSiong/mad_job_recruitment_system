-- =====================================================================
-- Community posts: drafts are a status, not a separate column
--
-- "isDraft" and "status" described one lifecycle with two columns, which
-- allowed combinations that mean nothing (a draft "deleted by admin").
-- Now "status" alone:
--
--   draft  ->  active  ->  author_deleted (deleted by its author while
--                          reported, kept for the admin)
--                      ->  deleted (removed by an admin)
--
--   * the author can only publish a draft (draft -> active); the other
--     status changes stay with the database functions and admins
--   * a published post can't become a draft again
--   * a draft can only be published or deleted (so never "removed")
--   * only the author can see a draft
--
-- Existing drafts become status 'draft'; then "isDraft" is dropped.
-- Install the new app build straight after this (older builds still send
-- "isDraft"). Safe to run again.
-- =====================================================================

-- ---------------------------------------------------------------------
-- 1. Move the drafts over, then drop the column
-- ---------------------------------------------------------------------
do $$
begin
  if exists (select 1 from information_schema.columns
             where table_schema = 'public' and table_name = 'CommunityPost' and column_name = 'isDraft') then
    -- (a draft already marked deleted keeps that status)
    update public."CommunityPost" set "status" = 'draft'
    where "isDraft" and "status" = 'active';

    drop policy if exists "community_post_drafts_private" on public."CommunityPost";
    alter table public."CommunityPost" drop column "isDraft";
  end if;
end $$;

-- ---------------------------------------------------------------------
-- 2. The allowed statuses
-- ---------------------------------------------------------------------
alter table public."CommunityPost" drop constraint if exists "CommunityPost_status_check";
do $$
declare
  v_bad text;
begin
  select string_agg(distinct coalesce("status", 'null'), ', ') into v_bad
  from public."CommunityPost"
  where "status" is null or "status" not in ('draft', 'active', 'author_deleted', 'deleted');

  if v_bad is null then
    alter table public."CommunityPost" add constraint "CommunityPost_status_check"
      check ("status" in ('draft', 'active', 'author_deleted', 'deleted'));
  else
    -- Applies to new and changed rows; old rows with these values stay
    alter table public."CommunityPost" add constraint "CommunityPost_status_check"
      check ("status" in ('draft', 'active', 'author_deleted', 'deleted')) not valid;
    raise notice 'CommunityPost has other status values (%), please check them', v_bad;
  end if;
end $$;

alter table public."CommunityPost" alter column "status" set default 'active';

-- ---------------------------------------------------------------------
-- 3. Access rules
-- ---------------------------------------------------------------------
-- Only the author can see a draft (restrictive: applies on top of the
-- other read rules, admins included)
drop policy if exists "community_post_drafts_private" on public."CommunityPost";
create policy "community_post_drafts_private" on public."CommunityPost"
  as restrictive
  for select to public
  using ("status" <> 'draft' or "authorID"::text = (select auth.uid())::text);

-- A new post is published or saved as a draft
drop policy if exists "community_post_insert_own" on public."CommunityPost";
create policy "community_post_insert_own" on public."CommunityPost"
  for insert to authenticated
  with check ("authorID"::text = (select auth.uid())::text
              and "status" in ('draft', 'active'));

-- ---------------------------------------------------------------------
-- 4. Changes to a post (trigger)
-- ---------------------------------------------------------------------
create or replace function public.app_community_post_before_update()
returns trigger
language plpgsql
set search_path = public
as $$
begin
  if new."status" is distinct from old."status" then
    if new."status" = 'draft' then
      raise exception 'post_published: a published post cannot become a draft again';
    end if;
    if old."status" = 'draft' and new."status" <> 'active' then
      raise exception 'draft_not_published: a draft can only be published or deleted';
    end if;
  end if;

  -- The author (not an admin) can only publish a draft; the owner and the
  -- other status changes stay as they were
  if auth.uid() is not null
     and old."authorID"::text = auth.uid()::text
     and not public.app_is_admin()
     and not public.app_in_moderation() then
    if not (old."status" = 'draft' and new."status" = 'active') then
      new."status" := old."status";
    end if;
    new."authorID" := old."authorID";
    new."createdAt" := old."createdAt";
  end if;

  if old."status" = 'draft' and new."status" = 'active' then
    -- Publishing a draft: it appears as a new post
    new."createdAt" := now();
    new."editedAt" := null;
  elsif new."status" <> 'draft'
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

-- ---------------------------------------------------------------------
-- 5. Admin: drafts can't be removed (admins can't see them anyway)
-- ---------------------------------------------------------------------
create or replace function public.admin_remove_post(
  p_post_id uuid, p_note text default null, p_notify boolean default true)
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
  v_posts integer;
  v_comments integer;
begin
  if not public.app_is_admin() then
    raise exception 'not_admin' using errcode = '42501';
  end if;

  select "status", "authorID", "content" into v_status, v_author, v_content
  from "CommunityPost" where "postID" = p_post_id
  for update;
  if not found or v_status = 'draft' then
    raise exception 'not_found' using errcode = 'P0002';
  end if;

  v_reasons := public.app_report_reasons('post', p_post_id); -- before they are closed

  -- Already deleted by its author: it stays that way (the author must not
  -- see it come back as "removed by admin" in My Posts).
  if v_status <> 'author_deleted' then
    update "CommunityPost" set "status" = 'deleted' where "postID" = p_post_id;
  end if;

  update "ReportedPost"
  set "status" = 'deleted', "resolvedAt" = now(), "adminID" = v_admin,
      "adminNotes" = coalesce(v_note, "adminNotes")
  where "postID" = p_post_id and "status" = 'pending';
  get diagnostics v_posts = row_count;

  -- Its comments can't be seen any more, so their reports are done too
  update "ReportedComment"
  set "status" = 'deleted', "resolvedAt" = now(), "adminID" = v_admin,
      "adminNotes" = coalesce(v_note, 'Post removed')
  where "status" = 'pending'
    and "commentID" in (select "commentID" from "PostComment" where "postID" = p_post_id);
  get diagnostics v_comments = row_count;

  if p_notify and v_status = 'active' and v_author::text <> auth.uid()::text then
    perform public.app_notify_user(
      v_author, 'community_post_removed', 'Your post was removed',
      public.app_removal_message('post', v_content, v_reasons));
  end if;

  return v_posts + v_comments;
end;
$$;

-- ---------------------------------------------------------------------
-- 6. Community search: status 'active' already leaves drafts out
-- ---------------------------------------------------------------------
create or replace function public.search_community_posts(
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

-- ---------------------------------------------------------------------
-- 7. Anything else still using "isDraft" (e.g. made in the dashboard)
-- ---------------------------------------------------------------------
do $$
declare
  r record;
begin
  for r in
    select p.proname from pg_proc p
    where p.pronamespace = 'public'::regnamespace and p.prosrc ~ '"isDraft"'
  loop
    raise notice 'Function % still uses "isDraft", please check it', r.proname;
  end loop;
end $$;

notify pgrst, 'reload schema';

-- Shows the result in the SQL editor (should be one row, all true)
select
  not exists (select 1 from information_schema.columns
              where table_schema = 'public' and table_name = 'CommunityPost'
                and column_name = 'isDraft')                            as "isDraft dropped",
  exists (select 1 from pg_constraint
          where conname = 'CommunityPost_status_check' and convalidated) as "status check on",
  not exists (select 1 from pg_proc
              where pronamespace = 'public'::regnamespace
                and prosrc ~ '"isDraft"')                               as "no function uses isDraft";
