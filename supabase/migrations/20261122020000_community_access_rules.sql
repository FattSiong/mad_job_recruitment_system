-- =====================================================================
-- Community Hub access rules, written down in the repo
--
-- The read / write rules for CommunityPost, PostComment, PostLike and
-- PostSaved were only set in the Supabase dashboard, so a database built
-- from these migrations had none. This replaces them with:
--
--   CommunityPost  read: active posts, your own posts, admins see all
--                  write: create / edit your own; deleting goes through
--                  delete_my_post (reported posts are kept for the admin)
--   PostComment    read: active comments, your own, admins see all
--                  write: comment as yourself on an active post, edit your
--                  own; deleting goes through delete_my_comment
--   PostLike       read: everyone logged in (like counts)
--                  write: like / unlike as yourself
--   PostSaved      read / write: only your own saves
--
-- Admins change posts and comments only through admin_remove_post /
-- admin_remove_comment / dismiss functions (security definer), and the
-- author lock triggers stop authors changing a status or the owner.
-- Restrictive rules (e.g. "community_post_drafts_private") are kept.
-- =====================================================================

-- Remove the old permissive rules (dashboard or earlier), since rules add
-- up: one left at `using (true)` would undo these.
do $$
declare
  r record;
begin
  for r in
    select tablename, policyname from pg_policies
    where schemaname = 'public'
      and tablename in ('CommunityPost', 'PostComment', 'PostLike', 'PostSaved')
      and permissive = 'PERMISSIVE'
  loop
    execute format('drop policy %I on public.%I', r.policyname, r.tablename);
  end loop;
end $$;

alter table public."CommunityPost" enable row level security;
alter table public."PostComment"   enable row level security;
alter table public."PostLike"      enable row level security;
alter table public."PostSaved"     enable row level security;

-- ---- CommunityPost ----------------------------------------------------
create policy "community_post_select" on public."CommunityPost"
  for select to authenticated
  using (
    "status" = 'active'
    or "authorID"::text = (select auth.uid())::text
    or (select public.app_is_admin())
  );

create policy "community_post_insert_own" on public."CommunityPost"
  for insert to authenticated
  with check ("authorID"::text = (select auth.uid())::text and "status" = 'active');

create policy "community_post_update_own" on public."CommunityPost"
  for update to authenticated
  using ("authorID"::text = (select auth.uid())::text)
  with check ("authorID"::text = (select auth.uid())::text);

-- ---- PostComment ------------------------------------------------------
create policy "post_comment_select" on public."PostComment"
  for select to authenticated
  using (
    "status" = 'active'
    or "userID"::text = (select auth.uid())::text
    or (select public.app_is_admin())
  );

create policy "post_comment_insert_own" on public."PostComment"
  for insert to authenticated
  with check (
    "userID"::text = (select auth.uid())::text
    and "status" = 'active'
    and exists (select 1 from public."CommunityPost" p
                where p."postID" = "PostComment"."postID" and p."status" = 'active')
  );

create policy "post_comment_update_own" on public."PostComment"
  for update to authenticated
  using ("userID"::text = (select auth.uid())::text)
  with check ("userID"::text = (select auth.uid())::text);

-- ---- PostLike ---------------------------------------------------------
create policy "post_like_select" on public."PostLike"
  for select to authenticated
  using (true);

create policy "post_like_insert_own" on public."PostLike"
  for insert to authenticated
  with check (
    "userID"::text = (select auth.uid())::text
    and exists (select 1 from public."CommunityPost" p
                where p."postID" = "PostLike"."postID" and p."status" = 'active')
  );

create policy "post_like_delete_own" on public."PostLike"
  for delete to authenticated
  using ("userID"::text = (select auth.uid())::text);

-- ---- PostSaved --------------------------------------------------------
create policy "post_saved_select_own" on public."PostSaved"
  for select to authenticated
  using ("userID"::text = (select auth.uid())::text);

create policy "post_saved_insert_own" on public."PostSaved"
  for insert to authenticated
  with check ("userID"::text = (select auth.uid())::text);

create policy "post_saved_delete_own" on public."PostSaved"
  for delete to authenticated
  using ("userID"::text = (select auth.uid())::text);
