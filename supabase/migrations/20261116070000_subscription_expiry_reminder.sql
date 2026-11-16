-- =====================================================================
-- Premium plan "expires in 3 days" reminder over FCM (replaces OneSignal)
-- Run AFTER 20261102010000_push_notifications_fcm.sql (UserDevice,
-- send-push secret) and 20261101010000_deactivate_expired_jobs_cron.sql
-- (enables pg_cron).
--
-- Replaces the check-expirations Edge Function, which sent the reminder
-- through OneSignal using "Company"."notification_token".
--
-- Every day at 09:05 Malaysia time, for each company whose Premium plan
-- ends in 3 days (Malaysia date):
--   * a "Notification" row (type 'subscription_expiring') is added for the
--     employer who paid last (if still in the company) and for the company
--     owners: it shows in the
--     bell, and tapping it opens the Subscription screen;
--   * the phone gets a push through the send-push Edge Function (FCM),
--     unless a trigger on "Notification" already pushes new rows.
-- Each person gets the reminder once per plan end date.
--
-- AFTER RUNNING THIS: delete the old function and its schedule
--   supabase functions delete check-expirations
--   (and remove any cron job / dashboard schedule that called it)
-- Safe to run again.
-- =====================================================================

create or replace function public.app_send_subscription_expiry_reminders()
returns integer
language plpgsql
security definer
set search_path = public
as $$
declare
  v_today date := (now() at time zone 'Asia/Kuala_Lumpur')::date;
  v_push_by_trigger boolean;
  v_secret text;
  v_title constant text := 'Premium plan ending soon';
  v_body text;
  v_id uuid;
  v_sent integer := 0;
  r record;
begin
  -- A trigger on "Notification" that already calls send-push would send
  -- the push itself; then only the row is added here (no double push).
  select exists (
    select 1
    from pg_trigger t
    join pg_proc p on p.oid = t.tgfoid
    where t.tgrelid = 'public."Notification"'::regclass
      and not t.tgisinternal
      and (p.prosrc ilike '%send-push%' or p.prosrc ilike '%recruitment_event%')
  ) into v_push_by_trigger;

  if not v_push_by_trigger then
    begin
      select decrypted_secret into v_secret
      from vault.decrypted_secrets
      where name = 'push_webhook_secret'
      limit 1;
    exception when others then
      v_secret := null; -- push not set up: the bell still shows it
    end;
  end if;

  for r in
    select distinct c."companyID", c."name", c."subscriptionEndsAt", who."userID"
    from public."Company" c
    cross join lateral (
      -- the employer who paid for the plan that is ending (if still in
      -- the company) ...
      select payer."userID"
      from (select ps."paidByEmployerID" as "userID"
            from public."PaymentSubscription" ps
            where ps."companyID" = c."companyID"
            order by ps."endDate" desc
            limit 1) payer
      where exists (select 1 from public."CompanyMember" m
                    where m."companyID" = c."companyID"
                      and m."employerID" = payer."userID"
                      and m."status" = 'active')
      union
      -- ... and the company owners
      select cm."employerID"
      from public."CompanyMember" cm
      where cm."companyID" = c."companyID"
        and cm."companyRole" = 'owner'
        and cm."status" = 'active'
    ) who
    where upper(coalesce(c."currentPlanType", 'FREE')) <> 'FREE'
      and c."subscriptionEndsAt" is not null
      and (c."subscriptionEndsAt" at time zone 'Asia/Kuala_Lumpur')::date = v_today + 3
      and who."userID" is not null
  loop
    v_body := format(
      'The Premium plan of %s ends on %s. Renew it to keep the AI features.',
      r."name",
      to_char(r."subscriptionEndsAt" at time zone 'Asia/Kuala_Lumpur', 'FMDD Mon YYYY')
    );

    -- once per person and plan end date
    continue when exists (
      select 1 from public."Notification" n
      where n."userID" = r."userID"
        and n."type" = 'subscription_expiring'
        and n."body" = v_body
    );

    insert into public."Notification" ("userID", "type", "title", "body")
    values (r."userID", 'subscription_expiring', v_title, v_body)
    returning "notificationID" into v_id;
    v_sent := v_sent + 1;

    if not v_push_by_trigger and coalesce(v_secret, '') <> '' then
      begin
        perform net.http_post(
          url     := 'https://cysvjnefwrphplydjdxw.supabase.co/functions/v1/send-push',
          headers := jsonb_build_object(
                       'Content-Type',  'application/json',
                       'x-push-secret', v_secret
                     ),
          body    := jsonb_build_object(
                       'type',           'recruitment_event',
                       'notificationID', v_id,
                       'userID',         r."userID",
                       'eventType',      'subscription_expiring',
                       'title',          v_title,
                       'body',           v_body
                     )
        );
      exception when others then
        raise warning 'subscription reminder push failed: %', sqlerrm;
      end;
    end if;
  end loop;

  return v_sent;
end;
$$;

-- Only the scheduler (database owner) runs it, not app users through the API
revoke execute on function public.app_send_subscription_expiry_reminders() from public;
revoke execute on function public.app_send_subscription_expiry_reminders() from anon, authenticated;

-- Every day at 09:05 Malaysia time (01:05 UTC). Re-running this file keeps one job.
-- (pg_cron is enabled by 20261101010000_deactivate_expired_jobs_cron.sql.)
select cron.unschedule(jobid) from cron.job where jobname = 'subscription-expiry-reminder';
select cron.schedule(
  'subscription-expiry-reminder',
  '5 1 * * *',
  $$select public.app_send_subscription_expiry_reminders();$$
);
