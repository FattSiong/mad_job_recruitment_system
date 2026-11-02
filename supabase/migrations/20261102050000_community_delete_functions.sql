-- =====================================================================
-- Community: delete a post / comment on the server.
--
-- Before, the app deleted the likes, saves and comments of a post itself.
-- Row Level Security only lets a user delete their OWN likes and comments,
-- so other people's rows were left behind and the post delete could fail.
--
-- These functions check that the caller owns the post / comment, then
-- delete it together with everything attached to it, in one transaction.
-- They run with the owner's rights (SECURITY DEFINER), so RLS doesn't block
-- the clean-up, but they only ever delete the caller's own content.
--
-- Safe to re-run.
-- =====================================================================

-- ---------------------------------------------------------------------
-- delete_my_post(p_post_id): the post, its comments (and replies), likes,
-- saves and any reports about it. Returns true if the post was deleted.
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

-- ---------------------------------------------------------------------
-- delete_my_comment(p_comment_id): the comment, all replies under it and
-- reports about them. Returns the number of comments removed (0 if gone).
-- ---------------------------------------------------------------------
create or replace function public.delete_my_comment(p_comment_id "PostComment"."commentID"%type)
returns integer
language plpgsql
security definer
set search_path = public
as $$
declare
  v_owner "PostComment"."userID"%type;
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

  -- Reports about the comment and every reply below it (any depth),
  -- then the comments themselves.
  with recursive thread as (
    select "commentID" from "PostComment" where "commentID" = p_comment_id
    union all
    select c."commentID"
    from "PostComment" c
    join thread t on c."parentCommentID" = t."commentID"
  )
  delete from "ReportedComment" where "commentID" in (select "commentID" from thread);

  with recursive thread as (
    select "commentID" from "PostComment" where "commentID" = p_comment_id
    union all
    select c."commentID"
    from "PostComment" c
    join thread t on c."parentCommentID" = t."commentID"
  )
  delete from "PostComment" where "commentID" in (select "commentID" from thread);
  get diagnostics v_count = row_count;

  return v_count;
end;
$$;

-- Only signed-in users may call them.
revoke all on function public.delete_my_post from public, anon;
revoke all on function public.delete_my_comment from public, anon;
grant execute on function public.delete_my_post to authenticated;
grant execute on function public.delete_my_comment to authenticated;
