-- =====================================================================
-- Admin > Community moderation (code review, 17 Nov 2026)
-- Run AFTER 20261116060000_chat_community_guards.sql (app_is_admin and
-- the community update triggers).
--
-- 1. Admin actions as database functions (one transaction each, they
--    check the caller is an admin and say when nothing was changed):
--      admin_remove_post(post, note)      post hidden + its reports and
--                                         its comments' reports resolved
--      admin_remove_comment(comment, note) comment and its replies hidden
--                                         + their reports resolved
--      admin_dismiss_reports(kind, id, note) reports closed, content kept
--    Each resolved report gets "resolvedAt", "adminID" (when the admin is
--    in "Admin") and "adminNotes".
-- 2. Access rules on "ReportedPost" / "ReportedComment": users send and
--    see their own reports only; admins see and handle all of them.
-- 3. A post or comment that has open reports is no longer erased when its
--    author deletes it: it is hidden from everyone (status
--    'author_deleted') and stays in the admin's list with its reports.
--    Content without open reports is still deleted for good.
-- Report status: 'pending' -> 'deleted' (content removed) or 'dismissed'.
-- Old data is not changed. Safe to run again.
-- =====================================================================

-- ---------------------------------------------------------------------
-- Helpers
-- ---------------------------------------------------------------------

-- The caller's "Admin"."adminID" (the report column points to "Admin"),
-- or null when the admin is only marked in "User"."role".
create or replace function public.app_moderator_id()
returns uuid
language plpgsql
stable
security definer
set search_path = public
as $$
declare
  v_found boolean := false;
begin
  if auth.uid() is null or to_regclass('public."Admin"') is null then
    return null;
  end if;
  execute 'select exists (select 1 from public."Admin" where "adminID" = $1)'
    into v_found using auth.uid();
  return case when v_found then auth.uid() end;
end;
$$;

revoke all on function public.app_moderator_id() from public, anon;
grant execute on function public.app_moderator_id() to authenticated;

-- True while one of the functions below is changing a status itself (the
-- update triggers then don't undo the change). The setting only lives
-- until the end of the current transaction.
create or replace function public.app_in_moderation()
returns boolean
language sql
stable
as $$
  select coalesce(current_setting('app.moderation', true), '') = 'on';
$$;

-- ---------------------------------------------------------------------
-- Update triggers: same as 20261116060000, plus "not app_in_moderation()"
-- ---------------------------------------------------------------------
create or replace function public.app_community_post_before_update()
returns trigger
language plpgsql
set search_path = public
as $$
begin
  -- The author (not an admin) can't change the status or the owner
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
          or new."category" is distinct from old."category") then
    new."editedAt" := now();
  else
    new."editedAt" := old."editedAt"; -- only the database sets it
  end if;
  return new;
end;
$$;

create or replace function public.app_post_comment_before_update()
returns trigger
language plpgsql
set search_path = public
as $$
begin
  if auth.uid() is not null
     and old."userID"::text = auth.uid()::text
     and not public.app_is_admin()
     and not public.app_in_moderation() then
    new."status" := old."status";
    new."postID" := old."postID";
    new."userID" := old."userID";
    new."parentCommentID" := old."parentCommentID";
    new."createdAt" := old."createdAt";
  end if;

  if new."content" is distinct from old."content" then
    new."updateAt" := now();
  else
    new."updateAt" := old."updateAt"; -- only the database sets it
  end if;
  return new;
end;
$$;

-- (the triggers themselves are unchanged: trg_community_post_before_update
--  and trg_post_comment_before_update from 20261116060000)

-- ---------------------------------------------------------------------
-- 1. Admin actions
-- ---------------------------------------------------------------------

-- Hides a post. Returns how many open reports were closed.
create or replace function public.admin_remove_post(
  p_post_id "CommunityPost"."postID"%type,
  p_note text default null
)
returns integer
language plpgsql
security definer
set search_path = public
as $$
declare
  v_status text;
  v_note text := nullif(btrim(coalesce(p_note, '')), '');
  v_admin uuid := public.app_moderator_id();
  v_posts integer;
  v_comments integer;
begin
  if not public.app_is_admin() then
    raise exception 'not_admin' using errcode = '42501';
  end if;

  select "status" into v_status
  from "CommunityPost" where "postID" = p_post_id
  for update;
  if not found then
    raise exception 'not_found' using errcode = 'P0002';
  end if;

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

  return v_posts + v_comments;
end;
$$;

-- Hides a comment and every reply under it. Returns how many comments.
create or replace function public.admin_remove_comment(
  p_comment_id "PostComment"."commentID"%type,
  p_note text default null
)
returns integer
language plpgsql
security definer
set search_path = public
as $$
declare
  v_note text := nullif(btrim(coalesce(p_note, '')), '');
  v_admin uuid := public.app_moderator_id();
  v_ids uuid[];
begin
  if not public.app_is_admin() then
    raise exception 'not_admin' using errcode = '42501';
  end if;

  perform 1 from "PostComment" where "commentID" = p_comment_id for update;
  if not found then
    raise exception 'not_found' using errcode = 'P0002';
  end if;

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

  return coalesce(array_length(v_ids, 1), 0);
end;
$$;

-- Closes the open reports on a post (p_kind 'post') or comment
-- ('comment') and keeps the content. Returns how many reports.
create or replace function public.admin_dismiss_reports(
  p_kind text,
  p_id uuid,
  p_note text default null
)
returns integer
language plpgsql
security definer
set search_path = public
as $$
declare
  v_note text := nullif(btrim(coalesce(p_note, '')), '');
  v_admin uuid := public.app_moderator_id();
  v_count integer;
begin
  if not public.app_is_admin() then
    raise exception 'not_admin' using errcode = '42501';
  end if;

  if p_kind = 'post' then
    update "ReportedPost"
    set "status" = 'dismissed', "resolvedAt" = now(), "adminID" = v_admin,
        "adminNotes" = coalesce(v_note, "adminNotes")
    where "postID" = p_id and "status" = 'pending';
  elsif p_kind = 'comment' then
    update "ReportedComment"
    set "status" = 'dismissed', "resolvedAt" = now(), "adminID" = v_admin,
        "adminNotes" = coalesce(v_note, "adminNotes")
    where "commentID" = p_id and "status" = 'pending';
  else
    raise exception 'bad_kind: use post or comment' using errcode = '22023';
  end if;
  get diagnostics v_count = row_count;
  return v_count;
end;
$$;

revoke all on function public.admin_remove_post(uuid, text) from public, anon;
revoke all on function public.admin_remove_comment(uuid, text) from public, anon;
revoke all on function public.admin_dismiss_reports(text, uuid, text) from public, anon;
grant execute on function public.admin_remove_post(uuid, text) to authenticated;
grant execute on function public.admin_remove_comment(uuid, text) to authenticated;
grant execute on function public.admin_dismiss_reports(text, uuid, text) to authenticated;

-- ---------------------------------------------------------------------
-- 2. Access rules on the report tables
-- ---------------------------------------------------------------------
alter table public."ReportedPost" enable row level security;
alter table public."ReportedComment" enable row level security;

drop policy if exists "reported_post_insert_own" on public."ReportedPost";
create policy "reported_post_insert_own" on public."ReportedPost"
  for insert to authenticated
  with check ("reporterID"::text = auth.uid()::text
              and "status" = 'pending'
              and "resolvedAt" is null and "adminID" is null and "adminNotes" is null);

drop policy if exists "reported_post_select_own_or_admin" on public."ReportedPost";
create policy "reported_post_select_own_or_admin" on public."ReportedPost"
  for select to authenticated
  using ("reporterID"::text = auth.uid()::text or public.app_is_admin());

drop policy if exists "reported_post_update_admin" on public."ReportedPost";
create policy "reported_post_update_admin" on public."ReportedPost"
  for update to authenticated
  using (public.app_is_admin()) with check (public.app_is_admin());

drop policy if exists "reported_post_delete_admin" on public."ReportedPost";
create policy "reported_post_delete_admin" on public."ReportedPost"
  for delete to authenticated
  using (public.app_is_admin());

drop policy if exists "reported_comment_insert_own" on public."ReportedComment";
create policy "reported_comment_insert_own" on public."ReportedComment"
  for insert to authenticated
  with check ("reporterID"::text = auth.uid()::text
              and "status" = 'pending'
              and "resolvedAt" is null and "adminID" is null and "adminNotes" is null);

drop policy if exists "reported_comment_select_own_or_admin" on public."ReportedComment";
create policy "reported_comment_select_own_or_admin" on public."ReportedComment"
  for select to authenticated
  using ("reporterID"::text = auth.uid()::text or public.app_is_admin());

drop policy if exists "reported_comment_update_admin" on public."ReportedComment";
create policy "reported_comment_update_admin" on public."ReportedComment"
  for update to authenticated
  using (public.app_is_admin()) with check (public.app_is_admin());

drop policy if exists "reported_comment_delete_admin" on public."ReportedComment";
create policy "reported_comment_delete_admin" on public."ReportedComment"
  for delete to authenticated
  using (public.app_is_admin());

-- Rules made in the dashboard are added to these ("OR"), so an old
-- "allow everything" rule would keep the tables open: list them.
do $$
declare
  r record;
begin
  for r in
    select tablename, policyname from pg_policies
    where schemaname = 'public'
      and tablename in ('ReportedPost', 'ReportedComment')
      and policyname not in (
        'reported_post_insert_own', 'reported_post_select_own_or_admin',
        'reported_post_update_admin', 'reported_post_delete_admin',
        'reported_comment_insert_own', 'reported_comment_select_own_or_admin',
        'reported_comment_update_admin', 'reported_comment_delete_admin')
  loop
    raise notice 'Check this older rule on "%": "%" (delete it if it lets everyone read or change reports)',
      r.tablename, r.policyname;
  end loop;
end $$;

-- ---------------------------------------------------------------------
-- 3. Author deletes: keep content that has open reports
--    (same as 20261102050000, plus the "open reports" part)
-- ---------------------------------------------------------------------
create or replace function public.delete_my_post(p_post_id "CommunityPost"."postID"%type)
returns boolean
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
    return false; -- already gone
  end if;

  if v_author::text <> auth.uid()::text then
    raise exception 'not_owner' using errcode = '42501';
  end if;

  -- NEW: reported and not handled yet -> hidden, kept for the admin
  if exists (select 1 from "ReportedPost"
             where "postID" = p_post_id and "status" = 'pending')
     or exists (select 1 from "ReportedComment" rc
                join "PostComment" c on c."commentID" = rc."commentID"
                where c."postID" = p_post_id and rc."status" = 'pending') then
    perform set_config('app.moderation', 'on', true);
    update "CommunityPost" set "status" = 'author_deleted' where "postID" = p_post_id;
    perform set_config('app.moderation', 'off', true);
    return true;
  end if;

  -- Reports about the post's comments, then the comments (all in one
  -- statement, so replies and their parents go together).
  delete from "ReportedComment"
  where "commentID" in (select "commentID" from "PostComment" where "postID" = p_post_id);

  delete from "PostComment" where "postID" = p_post_id;
  delete from "PostLike"    where "postID" = p_post_id;
  delete from "PostSaved"   where "postID" = p_post_id;
  delete from "ReportedPost" where "postID" = p_post_id;

  delete from "CommunityPost" where "postID" = p_post_id;
  return true;
end;
$$;

create or replace function public.delete_my_comment(p_comment_id "PostComment"."commentID"%type)
returns integer
language plpgsql
security definer
set search_path = public
as $$
declare
  v_owner "PostComment"."userID"%type;
  v_ids uuid[];
  v_count integer;
begin
  if auth.uid() is null then
    raise exception 'not_authenticated' using errcode = '28000';
  end if;

  select "userID" into v_owner
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

  -- NEW: something in the thread is reported and not handled yet ->
  -- hidden, kept for the admin
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

revoke all on function public.delete_my_post from public, anon;
revoke all on function public.delete_my_comment from public, anon;
grant execute on function public.delete_my_post to authenticated;
grant execute on function public.delete_my_comment to authenticated;
