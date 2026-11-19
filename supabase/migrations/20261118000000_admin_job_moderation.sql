-- =====================================================================
-- Admin > Jobs: handle reported job posts (18 Nov 2026)
-- Run AFTER 20261117010000_community_removal_notice.sql (app_notify_user)
-- and 20261109010000_reported_job_rls.sql (access rules on "ReportedJob").
--
-- Two admin actions as database functions (one transaction each; they
-- check the caller is an admin and say when nothing was changed):
--   admin_remove_job(job, note, notify)  the job is hidden ('deleted') and
--       its open reports are closed. With notify (default) the employer is
--       told why (the report reasons, not the admin's note), and everyone
--       with an open application is told the job is no longer available.
--   admin_dismiss_job_reports(job, note) the reports are closed, the job
--       stays as it is.
-- Each closed report gets "resolvedAt", "adminID" (when the admin is in
-- "Admin") and "adminNotes". Report status: 'pending' -> 'deleted'
-- (job removed) or 'dismissed'. A job that was already deleted keeps its
-- status; "remove" then only closes its leftover reports (no notices).
-- Safe to run again.
-- =====================================================================

-- "Fake job, Scam" (most given first), or null when nobody reported it
create or replace function public.app_job_report_reasons(p_job_id uuid)
returns text
language sql
stable
security definer
set search_path = public
as $$
  select string_agg(reason, ', ' order by n desc, reason)
  from (
    select "reportCategory" as reason, count(*) as n
    from "ReportedJob"
    where "jobID" = p_job_id and "status" = 'pending'
    group by 1
  ) r;
$$;

revoke execute on function public.app_job_report_reasons(uuid) from public, anon, authenticated;

-- ---------------------------------------------------------------------
-- Remove a job. Returns how many open reports were closed.
-- ---------------------------------------------------------------------
create or replace function public.admin_remove_job(
  p_job_id uuid,
  p_note text default null,
  p_notify boolean default true
)
returns integer
language plpgsql
security definer
set search_path = public
as $$
declare
  v_job record;
  v_company text;
  v_reasons text;
  v_note text := nullif(btrim(coalesce(p_note, '')), '');
  v_admin uuid := public.app_moderator_id();
  v_closed integer;
  v_id uuid;
  r record;
begin
  if not public.app_is_admin() then
    raise exception 'not_admin' using errcode = '42501';
  end if;

  select "jobID", "title", "status", "employerID", "companyID" into v_job
  from "Job" where "jobID" = p_job_id
  for update;
  if not found then
    raise exception 'not_found' using errcode = 'P0002';
  end if;

  v_reasons := public.app_job_report_reasons(p_job_id); -- before they are closed
  select "name" into v_company from "Company" where "companyID" = v_job."companyID";

  if v_job."status" <> 'deleted' then
    update "Job" set "status" = 'deleted' where "jobID" = p_job_id;
  end if;

  update "ReportedJob"
  set "status" = 'deleted', "resolvedAt" = now(), "adminID" = v_admin,
      "adminNotes" = coalesce(v_note, "adminNotes")
  where "jobID" = p_job_id and "status" = 'pending';
  get diagnostics v_closed = row_count;

  if p_notify and v_job."status" <> 'deleted' then
    -- The employer who posted it
    if v_job."employerID"::text <> coalesce(auth.uid()::text, '') then
      v_id := public.app_notify_user(
        v_job."employerID", 'job_removed', 'Your job post was removed',
        format('Your job post "%s" was removed by an admin because it does not follow the job posting rules%s. '
               'Job seekers can no longer see or apply for it.',
               public.app_short_preview(v_job."title"),
               case when coalesce(v_reasons, '') = '' then '' else ' (reported for: ' || v_reasons || ')' end));
      update "Notification" set "jobID" = p_job_id where "notificationID" = v_id;
    end if;

    -- Everyone still waiting on an application for it
    for r in
      select distinct a."seekerID"
      from "JobApplicant" a
      where a."jobID" = p_job_id
        and lower(coalesce(a."applicationStatus", '')) not in ('withdrawn', 'rejected')
    loop
      v_id := public.app_notify_user(
        r."seekerID", 'applied_job_removed', 'A job you applied for was removed',
        format('The job "%s"%s was removed by an admin and is no longer available.',
               public.app_short_preview(v_job."title"),
               case when coalesce(v_company, '') = '' then '' else ' at ' || v_company end));
      update "Notification" set "jobID" = p_job_id where "notificationID" = v_id;
    end loop;
  end if;

  return v_closed;
end;
$$;

-- ---------------------------------------------------------------------
-- Dismiss: close the open reports, keep the job. Returns how many.
-- ---------------------------------------------------------------------
create or replace function public.admin_dismiss_job_reports(
  p_job_id uuid,
  p_note text default null
)
returns integer
language plpgsql
security definer
set search_path = public
as $$
declare
  v_note text := nullif(btrim(coalesce(p_note, '')), '');
  v_count integer;
begin
  if not public.app_is_admin() then
    raise exception 'not_admin' using errcode = '42501';
  end if;

  update "ReportedJob"
  set "status" = 'dismissed', "resolvedAt" = now(), "adminID" = public.app_moderator_id(),
      "adminNotes" = coalesce(v_note, "adminNotes")
  where "jobID" = p_job_id and "status" = 'pending';
  get diagnostics v_count = row_count;
  return v_count;
end;
$$;

revoke all on function public.admin_remove_job(uuid, text, boolean) from public, anon;
revoke all on function public.admin_dismiss_job_reports(uuid, text) from public, anon;
grant execute on function public.admin_remove_job(uuid, text, boolean) to authenticated;
grant execute on function public.admin_dismiss_job_reports(uuid, text) to authenticated;

-- The admin lists read open reports newest first
create index if not exists reportedjob_pending_idx
  on "ReportedJob" ("reportedAt" desc) where "status" = 'pending';
