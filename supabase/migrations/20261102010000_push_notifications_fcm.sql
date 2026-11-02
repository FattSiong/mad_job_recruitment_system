-- =====================================================================
-- Push notifications with Firebase Cloud Messaging (FCM)
--
-- 1. "UserDevice": the FCM token of each phone a user is logged in on.
-- 2. register/unregister RPCs used by the app (PushService).
-- 3. Trigger: a new chat "Message" calls the send-push Edge Function,
--    which sends the push to the receiver's phones.
--
-- ONE-TIME SETUP (SQL editor), using the SAME random string that you set
-- as the Edge Function secret PUSH_WEBHOOK_SECRET:
--   select vault.create_secret('<random-secret>', 'push_webhook_secret');
-- Until that secret exists the trigger does nothing.
--
-- Safe to re-run. Sending a message never fails because of a push problem.
-- =====================================================================

create extension if not exists pg_net with schema extensions;

-- ---------------------------------------------------------------------
-- 1. Device tokens
-- ---------------------------------------------------------------------
create table if not exists "UserDevice" (
  "token"     text primary key,
  "userID"    uuid not null references "User"("userID") on delete cascade,
  "platform"  text not null default 'android' check ("platform" in ('android', 'ios', 'web')),
  "updatedAt" timestamptz not null default now()
);
create index if not exists userdevice_user_idx on "UserDevice" ("userID");

alter table "UserDevice" enable row level security;

-- Users may see and remove their own devices; adding goes through the RPC.
drop policy if exists "userdevice_select_own" on "UserDevice";
create policy "userdevice_select_own" on "UserDevice"
  for select to authenticated using ("userID" = auth.uid());

drop policy if exists "userdevice_delete_own" on "UserDevice";
create policy "userdevice_delete_own" on "UserDevice"
  for delete to authenticated using ("userID" = auth.uid());


-- ---------------------------------------------------------------------
-- 2. RPCs for the app
-- ---------------------------------------------------------------------
-- Saves this phone's token for the logged-in user. If someone else was
-- logged in on the same phone before, the token moves to the new user.
create or replace function public.register_device_token(p_token text, p_platform text default 'android')
returns void
language plpgsql
security definer
set search_path = public
as $$
begin
  if auth.uid() is null then
    raise exception 'not_authenticated';
  end if;
  if p_token is null or length(p_token) < 20 or length(p_token) > 4096 then
    raise exception 'invalid_token';
  end if;

  insert into "UserDevice" ("token", "userID", "platform", "updatedAt")
  values (p_token, auth.uid(), coalesce(nullif(p_platform, ''), 'android'), now())
  on conflict ("token") do update
    set "userID" = excluded."userID",
        "platform" = excluded."platform",
        "updatedAt" = now();
end;
$$;

-- Called just before logout so the phone stops getting this user's pushes.
create or replace function public.unregister_device_token(p_token text)
returns void
language sql
security definer
set search_path = public
as $$
  delete from "UserDevice" where "token" = p_token and "userID" = auth.uid();
$$;

revoke all on function public.register_device_token(text, text) from public, anon;
revoke all on function public.unregister_device_token(text) from public, anon;
grant execute on function public.register_device_token(text, text) to authenticated;
grant execute on function public.unregister_device_token(text) to authenticated;


-- ---------------------------------------------------------------------
-- 3. New chat message -> send-push Edge Function
-- ---------------------------------------------------------------------
create or replace function public.app_push_new_message()
returns trigger
language plpgsql
security definer
set search_path = public
as $$
declare
  v_secret text;
begin
  if coalesce(new."isDeleted", false) or new."mediaType" = 'call_log' then
    return new;
  end if;

  select decrypted_secret into v_secret
  from vault.decrypted_secrets
  where name = 'push_webhook_secret'
  limit 1;

  if v_secret is null or v_secret = '' then
    return new; -- push not set up yet
  end if;

  perform net.http_post(
    url     := 'https://cysvjnefwrphplydjdxw.supabase.co/functions/v1/send-push',
    headers := jsonb_build_object(
                 'Content-Type',  'application/json',
                 'x-push-secret', v_secret
               ),
    body    := jsonb_build_object('type', 'chat_message', 'messageID', new."messageID")
  );
  return new;
exception when others then
  raise warning 'app_push_new_message failed: %', sqlerrm;
  return new;
end;
$$;

revoke all on function public.app_push_new_message() from public, anon, authenticated;

drop trigger if exists trg_push_new_message on "Message";
create trigger trg_push_new_message
  after insert on "Message"
  for each row
  execute function public.app_push_new_message();
