-- =====================================================================
-- Chat: edit a sent message within 2 minutes
-- Run AFTER 20261115000000_chat_block_users.sql (and the schema fixes).
--
-- * The sender can change the text of their own text message for
--   2 minutes after sending it (30 s extra is allowed for a slow
--   connection). Photos, files, voice notes and deleted messages can't
--   be edited, and nothing can be edited while the chat is blocked.
-- * "Message"."editedAt" is set by the database when the text changes;
--   the app shows "Edited".
-- * Everything else stays as before: the other person can only mark
--   messages as read, and the sender can still delete (unsend).
-- Safe to run again.
-- =====================================================================

alter table public."Message" add column if not exists "editedAt" timestamptz;

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
    if coalesce(old."isDeleted", false) or coalesce(new."isDeleted", false) then
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
