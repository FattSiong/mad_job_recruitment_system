-- =====================================================================
-- Report Job: ownership rules + default status
-- Found in testing (test cases JR-02 .. JR-05):
--   * The old "Allow manage" policy (ALL, true) let any logged-in user read,
--     change or delete everyone's reports, and file reports under another
--     user's name.
--   * New reports had status NULL, so the admin dashboard
--     (status ilike '%pending%') did not count them.
--
-- After this file:
--   job seeker  -> create reports as themselves, read their own reports
--   admin       -> read / update / delete all reports
--   others      -> nothing
-- =====================================================================

-- 1. New reports start as 'pending' (and fix the ones already saved)
alter table "ReportedJob" alter column "status" set default 'pending';
update "ReportedJob" set "status" = 'pending' where "status" is null or btrim("status") = '';

-- 2. Replace every existing policy on ReportedJob
do $$
declare
  pol record;
begin
  for pol in
    select policyname from pg_policies where schemaname = 'public' and tablename = 'ReportedJob'
  loop
    execute format('drop policy if exists %I on public."ReportedJob"', pol.policyname);
  end loop;
end $$;

alter table "ReportedJob" enable row level security;

-- ::text comparisons work whether reporterID is uuid or text
create policy "report_insert_own" on "ReportedJob"
  for insert to authenticated
  with check ("reporterID"::text = auth.uid()::text);

create policy "report_select_own_or_admin" on "ReportedJob"
  for select to authenticated
  using ("reporterID"::text = auth.uid()::text or public.app_current_role() = 'admin');

create policy "report_update_admin" on "ReportedJob"
  for update to authenticated
  using (public.app_current_role() = 'admin')
  with check (public.app_current_role() = 'admin');

create policy "report_delete_admin" on "ReportedJob"
  for delete to authenticated
  using (public.app_current_role() = 'admin');

-- 3. One open report per job and user (the app checks this too)
do $$
begin
  if exists (
    select 1 from "ReportedJob" where "status" = 'pending'
    group by "jobID", "reporterID" having count(*) > 1
  ) then
    raise notice 'Skipped unique index: some users have several pending reports on the same job. '
                 'Find them with: select "jobID","reporterID",count(*) from "ReportedJob" '
                 'where status = ''pending'' group by 1,2 having count(*) > 1;';
  else
    create unique index if not exists reportedjob_open_uq
      on "ReportedJob" ("jobID", "reporterID") where "status" = 'pending';
  end if;
end $$;
