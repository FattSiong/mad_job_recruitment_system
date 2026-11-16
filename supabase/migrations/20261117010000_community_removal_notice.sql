-- =====================================================================
-- Admin > Community: tell the author when their post or comment is
-- removed (17 Nov 2026). Run AFTER 20261117000000_admin_community_moderation.sql
-- (and 20261102010000_push_notifications_fcm.sql for the phone push).
--
-- admin_remove_post / admin_remove_comment get a third input, p_notify
-- (default true). When the content is visible and gets removed, its
-- author gets a "Notification" row (type 'community_post_removed' /
-- 'community_comment_removed'): it shows in the bell, and the phone gets
-- a push through send-push, unless a trigger on "Notification" already
-- pushes new rows. The message names the report reasons; the admin's
-- note stays private. No message when the author had already deleted
-- it, it was already removed, or the admin removes their own content.
-- Safe to run again.
-- =====================================================================

-- ---------------------------------------------------------------------
-- Bell row + push for one user (used by database functions only)
-- ---------------------------------------------------------------------
create or replace function public.app_notify_user(
  p_user uuid,
  p_type text,
  p_title text,
  p_body text
)
returns uuid
language plpgsql
security definer
set search_path = public
as $$
declare
  v_id uuid;
  v_push_by_trigger boolean;
  v_secret text;
begin
  insert into public."Notification" ("userID", "type", "title", "body")
  values (p_user, p_type, p_title, p_body)
  returning "notificationID" into v_id;

  -- A trigger on "Notification" that already calls send-push sends it
  select exists (
    select 1
    from pg_trigger t
    join pg_proc p on p.oid = t.tgfoid
    where t.tgrelid = 'public."Notification"'::regclass
      and not t.tgisinternal
      and (p.prosrc ilike '%send-push%' or p.prosrc ilike '%recruitment_event%')
  ) into v_push_by_trigger;
  if v_push_by_trigger then
    return v_id;
  end if;

  begin
    select decrypted_secret into v_secret
    from vault.decrypted_secrets
    where name = 'push_webhook_secret'
    limit 1;

    if coalesce(v_secret, '') <> '' then
      perform net.http_post(
        url     := 'https://cysvjnefwrphplydjdxw.supabase.co/functions/v1/send-push',
        headers := jsonb_build_object('Content-Type', 'application/json', 'x-push-secret', v_secret),
        body    := jsonb_build_object(
                     'type',           'recruitment_event',
                     'notificationID', v_id,
                     'userID',         p_user,
                     'eventType',      p_type,
                     'title',          p_title,
                     'body',           p_body
                   )
      );
    end if;
  exception when others then
    -- push not set up (or failed): the bell still shows it
    raise warning 'community notice push failed: %', sqlerrm;
  end;
  return v_id;
end;
$$;

-- Only other database functions call it, not app users through the API
revoke execute on function public.app_notify_user(uuid, text, text, text) from public, anon, authenticated;

-- "Spam, Harassment" (most given first), or null when nobody reported it
create or replace function public.app_report_reasons(p_kind text, p_id uuid)
returns text
language sql
stable
security definer
set search_path = public
as $$
  select string_agg(reason, ', ' order by n desc, reason)
  from (
    select "reportCategory" as reason, count(*) as n
    from "ReportedPost"
    where p_kind = 'post' and "postID" = p_id and "status" = 'pending'
    group by 1
    union all
    select "reportCategory", count(*)
    from "ReportedComment"
    where p_kind = 'comment' and "commentID" = p_id and "status" = 'pending'
    group by 1
  ) r;
$$;

revoke execute on function public.app_report_reasons(text, uuid) from public, anon, authenticated;

-- "Buy cheap followers here…" (first 60 characters, one line)
create or replace function public.app_short_preview(p_text text)
returns text
language sql
immutable
as $$
  select case
    when length(t) > 60 then rtrim(left(t, 60)) || '…'
    else t
  end
  from (select btrim(regexp_replace(coalesce(p_text, ''), '\s+', ' ', 'g')) as t) x;
$$;

-- The message sent to the author
create or replace function public.app_removal_message(p_what text, p_content text, p_reasons text)
returns text
language sql
immutable
as $$
  select format(
    'Your %s%s was removed by an admin because it does not follow the community guidelines%s. '
    'Please keep your posts and comments respectful and on topic.',
    p_what,
    case when public.app_short_preview(p_content) = '' then ''
         else ' "' || public.app_short_preview(p_content) || '"' end,
    case when coalesce(p_reasons, '') = '' then '' else ' (reported for: ' || p_reasons || ')' end
  );
$$;

-- ---------------------------------------------------------------------
-- Admin actions with the notice (replace the two-input versions)
-- ---------------------------------------------------------------------
drop function if exists public.admin_remove_post(uuid, text);
drop function if exists public.admin_remove_comment(uuid, text);

-- Hides a post. Returns how many open reports were closed.
create or replace function public.admin_remove_post(
  p_post_id uuid,
  p_note text default null,
  p_notify boolean default true
)
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
  if not found then
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

-- Hides a comment and every reply under it. Returns how many comments.
create or replace function public.admin_remove_comment(
  p_comment_id uuid,
  p_note text default null,
  p_notify boolean default true
)
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

  select "status", "userID", "content" into v_status, v_author, v_content
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

revoke all on function public.admin_remove_post(uuid, text, boolean) from public, anon;
revoke all on function public.admin_remove_comment(uuid, text, boolean) from public, anon;
grant execute on function public.admin_remove_post(uuid, text, boolean) to authenticated;
grant execute on function public.admin_remove_comment(uuid, text, boolean) to authenticated;
