-- =====================================================================
-- Chat and community: rules the database now enforces itself
-- (code review, 16 Nov 2026). Run AFTER 20261116050000_chat_edit_messages.sql.
--
-- 1. New messages: the database sets the time ("sentAt") and starts every
--    message as unread, not edited and not deleted. Before, a changed app
--    could send its own time (e.g. one in the future, which kept the
--    2-minute edit window open for good) or a fake "Edited" / "Read".
-- 2. Message updates (replaces the rule from 20261116050000):
--    - a deleted (unsent) message can't be brought back
--    - only the other person can mark a message as read
-- 3. Community: the author of a post or comment can't change what admins
--    control (a removed post / comment can't be made visible again) and a
--    comment can't be moved to another post. Admins are not limited.
--    "Edited" times are only set by the database.
-- Old data is not changed. Safe to run again.
-- =====================================================================

alter table public."Message" add column if not exists "editedAt" timestamptz;
alter table public."PostComment" add column if not exists "updateAt" timestamptz;

-- True if the logged-in user is an admin. SECURITY DEFINER so it works
-- whatever the access rules on "Admin" / "User" are.
create or replace function public.app_is_admin()
returns boolean
language plpgsql
stable
security definer
set search_path = public
as $$
begin
  if exists (select 1 from public."User"
             where "userID" = auth.uid() and lower("role") = 'admin') then
    return true;
  end if;
  if to_regclass('public."Admin"') is not null then
    return exists (select 1 from public."Admin" where "adminID" = auth.uid());
  end if;
  return false;
end;
$$;

-- ---------------------------------------------------------------------
-- 1. New messages
-- ---------------------------------------------------------------------
create or replace function public.app_message_before_insert()
returns trigger
language plpgsql
set search_path = public
as $$
begin
  -- Server-side code (service role, SQL editor) is not restricted.
  if auth.uid() is null then
    return new;
  end if;
  new."sentAt" := now();
  new."isRead" := false;
  new."isDeleted" := false;
  new."editedAt" := null;
  return new;
end;
$$;

drop trigger if exists trg_message_before_insert on public."Message";
create trigger trg_message_before_insert
  before insert on public."Message"
  for each row
  execute function public.app_message_before_insert();

-- ---------------------------------------------------------------------
-- 2. Message updates
-- ---------------------------------------------------------------------
create or replace function public.app_guard_message_update()
returns trigger
language plpgsql
set search_path = public
as $$
begin
  -- Server-side code (service role, SQL editor) is not restricted.
  if auth.uid() is null then
    return new;
  end if;

  if new."roomID" is distinct from old."roomID"
     or new."senderID" is distinct from old."senderID"
     or new."sentAt" is distinct from old."sentAt" then
    raise exception 'message_locked: room, sender and time cannot be changed';
  end if;

  -- The other person's message: only "read"
  if old."senderID" <> auth.uid() then
    if new."content"   is distinct from old."content"
       or new."mediaURL"  is distinct from old."mediaURL"
       or new."mediaType" is distinct from old."mediaType"
       or new."isDeleted" is distinct from old."isDeleted"
       or new."editedAt"  is distinct from old."editedAt" then
      raise exception 'message_locked: you can only mark other people''s messages as read';
    end if;
    return new;
  end if;

  -- Your own message ----------------------------------------------------

  -- Only the other person marks it as read
  new."isRead" := old."isRead";

  if coalesce(old."isDeleted", false) and not coalesce(new."isDeleted", false) then
    raise exception 'message_locked: a deleted message cannot be restored';
  end if;

  -- Delete (unsend): may clear the text and the file
  if coalesce(new."isDeleted", false) and not coalesce(old."isDeleted", false) then
    new."editedAt" := old."editedAt";
    return new;
  end if;

  if new."mediaURL" is distinct from old."mediaURL"
     or new."mediaType" is distinct from old."mediaType" then
    raise exception 'message_locked: a photo, file or voice note cannot be changed';
  end if;

  if new."content" is distinct from old."content" then
    if coalesce(old."isDeleted", false) then
      raise exception 'message_locked: a deleted message cannot be edited';
    end if;
    if coalesce(old."mediaType", 'text') <> 'text' then
      raise exception 'message_locked: only text messages can be edited';
    end if;
    if now() - old."sentAt" > interval '2 minutes 30 seconds' then
      raise exception 'edit_window_closed: messages can only be edited within 2 minutes';
    end if;
    if public.app_room_is_blocked(old."roomID") then
      raise exception 'chat_blocked: messages cannot be edited in a blocked chat';
    end if;
    if length(btrim(coalesce(new."content", ''))) = 0 or length(new."content") > 4000 then
      raise exception 'message_invalid: a message must have 1 to 4000 characters';
    end if;
    new."editedAt" := now();
  else
    -- only the database sets the edit time
    new."editedAt" := old."editedAt";
  end if;

  return new;
end;
$$;

drop trigger if exists trg_guard_message_update on public."Message";
create trigger trg_guard_message_update
  before update on public."Message"
  for each row
  execute function public.app_guard_message_update();

-- ---------------------------------------------------------------------
-- 3. Community posts and comments
-- ---------------------------------------------------------------------

-- Posts: same as 20261116000000 (drafts, "Edited"), plus the author lock
create or replace function public.app_community_post_before_update()
returns trigger
language plpgsql
set search_path = public
as $$
begin
  -- The author (not an admin) can't change the status or the owner
  if auth.uid() is not null
     and old."authorID"::text = auth.uid()::text
     and not public.app_is_admin() then
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

drop trigger if exists trg_community_post_before_update on public."CommunityPost";
create trigger trg_community_post_before_update
  before update on public."CommunityPost"
  for each row execute function public.app_community_post_before_update();

-- Comments: "Edited" time (from 20261116040000), plus the author lock
create or replace function public.app_post_comment_before_update()
returns trigger
language plpgsql
set search_path = public
as $$
begin
  if auth.uid() is not null
     and old."userID"::text = auth.uid()::text
     and not public.app_is_admin() then
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

drop trigger if exists trg_post_comment_before_update on public."PostComment";
create trigger trg_post_comment_before_update
  before update on public."PostComment"
  for each row execute function public.app_post_comment_before_update();
