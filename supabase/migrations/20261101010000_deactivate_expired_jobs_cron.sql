-- =====================================================================
-- Fix #4: mark expired jobs as inactive on the server (instead of in the seeker app)
--
-- The seeker app no longer updates the "Job" table. It simply skips expired jobs
-- in its query. This schedule keeps the "status" column correct for employers
-- and admins: every 15 minutes, active jobs whose expiresAt has passed become 'inactive'.
--
-- Run once in the Supabase SQL Editor (or `supabase db push`).
-- Nothing is deleted: only "status" changes from 'active' to 'inactive' for expired jobs.
-- =====================================================================

-- 1. Enable pg_cron (Supabase's recommended setup)
create extension if not exists pg_cron with schema pg_catalog;
grant usage on schema cron to postgres;
grant all privileges on all tables in schema cron to postgres;

-- 2. The work itself: returns how many jobs were deactivated
create or replace function public.deactivate_expired_jobs()
returns integer
language sql
security definer
set search_path = public
as $$
  with updated as (
    update "Job"
    set "status" = 'inactive'
    where "status" = 'active'
      and "expiresAt" is not null
      and "expiresAt" <= now()
    returning 1
  )
  select count(*)::int from updated;
$$;

-- Only the database (the cron schedule) runs this, not app users
revoke execute on function public.deactivate_expired_jobs() from public;
revoke execute on function public.deactivate_expired_jobs() from anon, authenticated;

-- 3. Schedule it every 15 minutes (re-running this file replaces the old schedule)
select cron.unschedule(jobid) from cron.job where jobname = 'deactivate-expired-jobs';
select cron.schedule(
  'deactivate-expired-jobs',
  '*/15 * * * *',
  $$select public.deactivate_expired_jobs();$$
);

-- 4. Clean up anything already expired right now (shows how many were updated)
select public.deactivate_expired_jobs() as jobs_deactivated_now;

-- Useful checks:
--   select * from cron.job where jobname = 'deactivate-expired-jobs';
--   select * from cron.job_run_details order by start_time desc limit 10;
-- To stop it:
--   select cron.unschedule('deactivate-expired-jobs');
