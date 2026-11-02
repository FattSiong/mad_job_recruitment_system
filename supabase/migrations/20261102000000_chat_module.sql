-- =====================================================================
-- Chat module (lib/modules/chat): access rules, indexes and realtime
-- for the existing "ChatRoom" and "Message" tables.
--
-- * Keeps all existing rooms and messages (no data is changed or deleted).
-- * Only the two people in a room can see or send its messages.
-- * Other people's messages can only be marked as read; your own can be
--   soft-deleted. Nobody can rewrite someone else's message.
-- * Works for the old community chat screens as well.
--
-- Safe to re-run.
-- =====================================================================

-- ---------------------------------------------------------------------
-- 1. Indexes for the chat list and message history
-- ---------------------------------------------------------------------
create index if not exists chatroom_user1_idx   on "ChatRoom" ("user1_ID");
create index if not exists chatroom_user2_idx   on "ChatRoom" ("user2_ID");
create index if not exists message_room_sent_idx on "Message" ("roomID", "sentAt" desc);
create index if not exists message_room_unread_idx on "Message" ("roomID") where "isRead" = false;

-- One room per pair of users (only added if there are no duplicates yet).
do $$
begin
  if exists (
    select 1 from "ChatRoom"
    group by least("user1_ID", "user2_ID"), greatest("user1_ID", "user2_ID")
    having count(*) > 1
  ) then
    raise notice 'ChatRoom has duplicate rooms for the same two users; unique index not created. '
                 'Find them with: select least("user1_ID","user2_ID"), greatest("user1_ID","user2_ID"), count(*) '
                 'from "ChatRoom" group by 1,2 having count(*) > 1;';
  else
    create unique index if not exists chatroom_pair_uq
      on "ChatRoom" (least("user1_ID", "user2_ID"), greatest("user1_ID", "user2_ID"));
  end if;
end $$;


-- ---------------------------------------------------------------------
-- 2. Helper: is the logged-in user in this room?
-- ---------------------------------------------------------------------
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
      and auth.uid() in (r."user1_ID", r."user2_ID")
  );
$$;

revoke all on function public.app_is_chat_member(uuid) from public, anon;
grant execute on function public.app_is_chat_member(uuid) to authenticated;


-- ---------------------------------------------------------------------
-- 3. Access rules. Older policies on these two tables are replaced, because
--    any extra "allow" policy would let other users read private chats.
-- ---------------------------------------------------------------------
do $$
declare
  pol record;
begin
  for pol in
    select policyname, tablename from pg_policies
    where schemaname = 'public' and tablename in ('ChatRoom', 'Message')
  loop
    execute format('drop policy if exists %I on public.%I', pol.policyname, pol.tablename);
  end loop;
end $$;

alter table "ChatRoom" enable row level security;
alter table "Message"  enable row level security;

-- Rooms: see and create only rooms you are in.
create policy "chatroom_select_member" on "ChatRoom"
  for select to authenticated
  using (auth.uid() in ("user1_ID", "user2_ID"));

create policy "chatroom_insert_member" on "ChatRoom"
  for insert to authenticated
  with check (auth.uid() in ("user1_ID", "user2_ID") and "user1_ID" <> "user2_ID");

-- Messages: members read; you send as yourself; members may update
-- (column limits are enforced by the trigger below). No hard deletes.
create policy "message_select_member" on "Message"
  for select to authenticated
  using (public.app_is_chat_member("roomID"));

create policy "message_insert_own" on "Message"
  for insert to authenticated
  with check ("senderID" = auth.uid() and public.app_is_chat_member("roomID"));

create policy "message_update_member" on "Message"
  for update to authenticated
  using (public.app_is_chat_member("roomID"))
  with check (public.app_is_chat_member("roomID"));


-- ---------------------------------------------------------------------
-- 4. What an update may change
--    - the other person's message: only "isRead" (read receipts)
--    - your own message: soft delete (isDeleted / content / mediaURL)
--    - nobody can move a message to another room, sender or time
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

  if old."senderID" <> auth.uid() then
    if new."content"   is distinct from old."content"
       or new."mediaURL"  is distinct from old."mediaURL"
       or new."mediaType" is distinct from old."mediaType"
       or new."isDeleted" is distinct from old."isDeleted" then
      raise exception 'message_locked: you can only mark other people''s messages as read';
    end if;
  else
    -- Your own message: only a soft delete may change its content.
    if coalesce(new."isDeleted", false) = false
       and (new."content" is distinct from old."content"
            or new."mediaURL" is distinct from old."mediaURL") then
      raise exception 'message_locked: messages cannot be edited';
    end if;
  end if;

  return new;
end;
$$;

drop trigger if exists trg_guard_message_update on "Message";
create trigger trg_guard_message_update
  before update on "Message"
  for each row
  execute function public.app_guard_message_update();


-- ---------------------------------------------------------------------
-- 5. Realtime: new messages, read ticks and new rooms update the app live.
-- ---------------------------------------------------------------------
do $$
begin
  if exists (select 1 from pg_publication where pubname = 'supabase_realtime') then
    if not exists (select 1 from pg_publication_tables
                   where pubname = 'supabase_realtime' and schemaname = 'public' and tablename = 'Message') then
      execute 'alter publication supabase_realtime add table public."Message"';
    end if;
    if not exists (select 1 from pg_publication_tables
                   where pubname = 'supabase_realtime' and schemaname = 'public' and tablename = 'ChatRoom') then
      execute 'alter publication supabase_realtime add table public."ChatRoom"';
    end if;
  end if;
end $$;
