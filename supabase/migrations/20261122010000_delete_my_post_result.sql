-- =====================================================================
-- delete_my_post tells the app what it did
--
-- A post with a pending report is only hidden ('author_deleted') so the
-- admin can still review it, attachment included. The app used to delete
-- the attachment file in both cases, so the admin saw a broken file.
-- Now the function returns:
--   'deleted' -> the post is gone: the app deletes its file
--   'hidden'  -> kept for the admin: the file is kept
--   'gone'    -> it was already deleted
-- Same checks and steps as before (20261117000000_admin_community_moderation).
-- =====================================================================

-- The return type changes, so the old function is dropped first
drop function if exists public.delete_my_post;

create function public.delete_my_post(p_post_id "CommunityPost"."postID"%type)
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

  delete from "PostComment" where "postID" = p_post_id;
  delete from "PostLike"    where "postID" = p_post_id;
  delete from "PostSaved"   where "postID" = p_post_id;
  delete from "ReportedPost" where "postID" = p_post_id;

  delete from "CommunityPost" where "postID" = p_post_id;
  return 'deleted';
end;
$$;

revoke all on function public.delete_my_post from public, anon;
grant execute on function public.delete_my_post to authenticated;
