-- =====================================================================
-- Mock Interview: delete abandoned interviews every day
-- Run AFTER 20261030000000_career_advisory_module.sql and
--           20261101010000_deactivate_expired_jobs_cron.sql (enables pg_cron)
--
-- An interview stays "in_progress" when the app crashed or was closed
-- mid-interview (Exit already deletes it). cleanup_stale_mock_interviews()
-- removes those older than 1 day (their answers go with them, ON DELETE
-- CASCADE). Completed interviews are never touched.
-- =====================================================================

-- pg_cron is already enabled by 20261101010000_deactivate_expired_jobs_cron.sql.
-- (Running "create extension pg_cron" again on Supabase fails with
--  "dependent privileges exist", so it is not repeated here. If pg_cron is
--  not enabled yet: Dashboard > Database > Extensions > pg_cron > Enable.)

-- Only the scheduler (database owner) runs it, not app users through the API
revoke execute on function public.cleanup_stale_mock_interviews() from public;
revoke execute on function public.cleanup_stale_mock_interviews() from anon, authenticated;

-- Every day at 03:15 Malaysia time (19:15 UTC). Re-running this file keeps one job.
select cron.unschedule(jobid) from cron.job where jobname = 'cleanup-stale-mock-interviews';
select cron.schedule(
  'cleanup-stale-mock-interviews',
  '15 19 * * *',
  $$select public.cleanup_stale_mock_interviews();$$
);

-- Clean up what is already there
select public.cleanup_stale_mock_interviews();
