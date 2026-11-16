-- =====================================================================
-- Chat: block a user
-- Run AFTER 20261102000000_chat_module.sql
--
-- * "UserBlock" holds who blocked whom. You only see (and can remove)
--   your own blocks.
-- * While either of two people has blocked the other, neither can send a
--   message in their chat or start a voice call. Old messages stay.
-- * chat_block_status(other) tells the app which side blocked, so it can
--   show "You blocked ..." or "You can't reply to this conversation".
--
-- Safe to run again.
-- =====================================================================

-- ---------------------------------------------------------------------
-- 1. Table
-- ---------------------------------------------------------------------
create table if not exists public."UserBlock" (
  "blockerID" uuid not null,
  "blockedID" uuid not null,
  "createdAt" timestamptz not null default now(),
  primary key ("blockerID", "blockedID"),
  constraint userblock_not_self check ("blockerID" <> "blockedID")
);

create index if not exists userblock_blocked_idx on public."UserBlock" ("blockedID");

alter table public."UserBlock" enable row level security;

drop policy if exists "userblock_select_own" on public."UserBlock";
drop policy if exists "userblock_insert_own" on public."UserBlock";
drop policy if exists "userblock_delete_own" on public."UserBlock";

create policy "userblock_select_own" on public."UserBlock"
  for select to authenticated using ("blockerID" = auth.uid());

create policy "userblock_insert_own" on public."UserBlock"
  for insert to authenticated with check ("blockerID" = auth.uid());

create policy "userblock_delete_own" on public."UserBlock"
  for delete to authenticated using ("blockerID" = auth.uid());

grant select, insert, delete on public."UserBlock" to authenticated;

-- ---------------------------------------------------------------------
-- 2. Helpers
-- ---------------------------------------------------------------------
-- True if one of the two people in this room has blocked the other
-- (only answers for rooms the logged-in user is in).
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
      on (b."blockerID" = r."user1_ID" and b."blockedID" = r."user2_ID")
      or (b."blockerID" = r."user2_ID" and b."blockedID" = r."user1_ID")
    where r."roomID" = p_room_id
      and auth.uid() in (r."user1_ID", r."user2_ID")
  );
$$;

revoke all on function public.app_room_is_blocked(uuid) from public, anon;
grant execute on function public.app_room_is_blocked(uuid) to authenticated;

-- 'you_blocked', 'blocked_you' or 'none' between the logged-in user and p_other
create or replace function public.chat_block_status(p_other uuid)
returns text
language sql
stable
security definer
set search_path = public
as $$
  select case
    when exists (select 1 from "UserBlock"
                 where "blockerID" = auth.uid() and "blockedID" = p_other) then 'you_blocked'
    when exists (select 1 from "UserBlock"
                 where "blockerID" = p_other and "blockedID" = auth.uid()) then 'blocked_you'
    else 'none'
  end;
$$;

revoke all on function public.chat_block_status(uuid) from public, anon;
grant execute on function public.chat_block_status(uuid) to authenticated;

-- ---------------------------------------------------------------------
-- 3. No new messages while blocked (replaces the rule from the chat module)
-- ---------------------------------------------------------------------
drop policy if exists "message_insert_own" on "Message";
create policy "message_insert_own" on "Message"
  for insert to authenticated
  with check (
    "senderID" = auth.uid()
    and public.app_is_chat_member("roomID")
    and not public.app_room_is_blocked("roomID")
  );

-- ---------------------------------------------------------------------
-- 4. No voice calls while blocked ("Calls" table of the call feature)
-- ---------------------------------------------------------------------
create or replace function public.app_guard_blocked_call()
returns trigger
language plpgsql
security definer
set search_path = public
as $$
begin
  if exists (
    select 1 from "UserBlock" b
    where (b."blockerID"::text = new."callerID"::text and b."blockedID"::text = new."receiverID"::text)
       or (b."blockerID"::text = new."receiverID"::text and b."blockedID"::text = new."callerID"::text)
  ) then
    raise exception 'user_blocked: calls are not possible between these users';
  end if;
  return new;
end;
$$;

do $$
begin
  if to_regclass('public."Calls"') is not null then
    execute 'drop trigger if exists trg_guard_blocked_call on public."Calls"';
    execute 'create trigger trg_guard_blocked_call before insert on public."Calls" '
            'for each row execute function public.app_guard_blocked_call()';
  else
    raise notice 'Table "Calls" not found: calls are not checked for blocks';
  end if;
end $$;
