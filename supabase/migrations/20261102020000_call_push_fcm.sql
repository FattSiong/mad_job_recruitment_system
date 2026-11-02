-- =====================================================================
-- Voice-call ringing over FCM (replaces the OneSignal call push).
--
-- * New "Calls" row with status 'ringing'  -> send-push {type:'call'}
--   (the receiver's phone shows a full-screen ringing notification)
-- * Status leaves 'ringing' (answered / declined / ended / missed)
--                                           -> send-push {type:'call_cancel'}
--   (the receiver's phone stops ringing)
--
-- Needs 20261102010000_push_notifications_fcm.sql first (pg_net and the
-- Vault secret 'push_webhook_secret'). Safe to re-run; a push problem never
-- stops a call from being created or updated.
-- =====================================================================

-- Shared sender used by the call triggers.
create or replace function public.app_send_push_request(p_body jsonb)
returns void
language plpgsql
security definer
set search_path = public
as $$
declare
  v_secret text;
begin
  select decrypted_secret into v_secret
  from vault.decrypted_secrets
  where name = 'push_webhook_secret'
  limit 1;

  if v_secret is null or v_secret = '' then
    return; -- push not set up yet
  end if;

  perform net.http_post(
    url     := 'https://cysvjnefwrphplydjdxw.supabase.co/functions/v1/send-push',
    headers := jsonb_build_object(
                 'Content-Type',  'application/json',
                 'x-push-secret', v_secret
               ),
    body    := p_body
  );
exception when others then
  raise warning 'app_send_push_request failed: %', sqlerrm;
end;
$$;

revoke all on function public.app_send_push_request(jsonb) from public, anon, authenticated;


create or replace function public.app_push_call_change()
returns trigger
language plpgsql
security definer
set search_path = public
as $$
begin
  if tg_op = 'INSERT' then
    if new."status" = 'ringing' then
      perform public.app_send_push_request(
        jsonb_build_object('type', 'call', 'callID', new."callID"));
    end if;
  elsif old."status" = 'ringing' and new."status" is distinct from 'ringing' then
    perform public.app_send_push_request(
      jsonb_build_object('type', 'call_cancel', 'callID', new."callID"));
  end if;
  return new;
exception when others then
  raise warning 'app_push_call_change failed: %', sqlerrm;
  return new;
end;
$$;

revoke all on function public.app_push_call_change() from public, anon, authenticated;

drop trigger if exists trg_push_call_insert on "Calls";
create trigger trg_push_call_insert
  after insert on "Calls"
  for each row
  execute function public.app_push_call_change();

drop trigger if exists trg_push_call_status on "Calls";
create trigger trg_push_call_status
  after update of "status" on "Calls"
  for each row
  execute function public.app_push_call_change();
