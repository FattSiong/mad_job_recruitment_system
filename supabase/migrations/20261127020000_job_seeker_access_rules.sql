-- =====================================================================
-- Job seeker module: access rules (RLS) rewritten
-- Run AFTER 20261127010000_job_seeker_data_rules.sql
--
-- Same access as before, written so the database can use its indexes
-- and works out each rule once per query instead of once per row:
--   * (select auth.uid()) instead of auth.uid() (evaluated once);
--   * no ::text casts (every ID column is a uuid), so indexes are used;
--   * no "for all" rule next to a read rule: each action has one rule.
-- Changes in what is allowed:
--   * ApplicationAnswer: answers are only added by submit_job_application()
--     (now security definer); the app never adds or deletes them directly.
--   * JobApplicant: applications are only created by submit_job_application()
--     and never deleted by the seeker (withdrawing keeps the record), so
--     the seeker's insert / delete rules are dropped.
--   * JobSeeker: the seeker can't delete their profile row on its own
--     (deleting the account removes it, see 20261127040000).
--   * ReportedJob: a new report must start as 'pending'.
-- Rules made in the dashboard by teammates for these tables (e.g. the
-- employer marking pre-screening answers) are not touched: only the rules
-- named here are replaced.
-- Safe to run again.
-- =====================================================================

-- ---- JobSeeker --------------------------------------------------------
drop policy if exists "jobseeker_select"     on public."JobSeeker";
drop policy if exists "jobseeker_insert_own" on public."JobSeeker";
drop policy if exists "jobseeker_update_own" on public."JobSeeker";
drop policy if exists "jobseeker_delete_own" on public."JobSeeker";

-- Full row: the seeker, employers (applicants' contact details) and admins.
-- Other seekers use public_seeker_profiles() (20261122000000).
create policy "jobseeker_select" on public."JobSeeker"
  for select to authenticated
  using (
    "seekerID" = (select auth.uid())
    or (select public.app_is_employer())
    or (select public.app_is_admin())
  );
create policy "jobseeker_insert_own" on public."JobSeeker"
  for insert to authenticated
  with check ("seekerID" = (select auth.uid()));
create policy "jobseeker_update_own" on public."JobSeeker"
  for update to authenticated
  using ("seekerID" = (select auth.uid()))
  with check ("seekerID" = (select auth.uid()));

-- ---- Education / WorkExperience / Skill -------------------------------
-- Read: everyone logged in (employers, public profile). Write: the owner.
do $$
declare
  t record;
begin
  for t in
    select * from (values
      ('Education',      'education',      'education_write_own'),
      ('WorkExperience', 'workexperience', 'workexperience_write_own'),
      ('Skill',          'skill',          'skill_own_all')
    ) as v(tbl, prefix, old_rule)
  loop
    execute format('drop policy if exists %I on public.%I', t.old_rule, t.tbl);
    execute format('drop policy if exists %I on public.%I', t.prefix || '_insert_own', t.tbl);
    execute format('drop policy if exists %I on public.%I', t.prefix || '_update_own', t.tbl);
    execute format('drop policy if exists %I on public.%I', t.prefix || '_delete_own', t.tbl);

    execute format($f$create policy %I on public.%I for insert to authenticated
                      with check ("seekerID" = (select auth.uid()))$f$, t.prefix || '_insert_own', t.tbl);
    execute format($f$create policy %I on public.%I for update to authenticated
                      using ("seekerID" = (select auth.uid()))
                      with check ("seekerID" = (select auth.uid()))$f$, t.prefix || '_update_own', t.tbl);
    execute format($f$create policy %I on public.%I for delete to authenticated
                      using ("seekerID" = (select auth.uid()))$f$, t.prefix || '_delete_own', t.tbl);
  end loop;
end $$;

-- The read rules stay "everyone logged in"; made again in case one is missing
drop policy if exists "education_select" on public."Education";
create policy "education_select" on public."Education" for select to authenticated using (true);
drop policy if exists "workexperience_select" on public."WorkExperience";
create policy "workexperience_select" on public."WorkExperience" for select to authenticated using (true);
drop policy if exists "skill_select_authenticated" on public."Skill";
create policy "skill_select_authenticated" on public."Skill" for select to authenticated using (true);

-- ---- BookmarkedJob (private) ------------------------------------------
drop policy if exists "bookmark_own"        on public."BookmarkedJob";
drop policy if exists "bookmark_select_own" on public."BookmarkedJob";
drop policy if exists "bookmark_insert_own" on public."BookmarkedJob";
drop policy if exists "bookmark_delete_own" on public."BookmarkedJob";
create policy "bookmark_select_own" on public."BookmarkedJob"
  for select to authenticated using ("seekerID" = (select auth.uid()));
create policy "bookmark_insert_own" on public."BookmarkedJob"
  for insert to authenticated with check ("seekerID" = (select auth.uid()));
create policy "bookmark_delete_own" on public."BookmarkedJob"
  for delete to authenticated using ("seekerID" = (select auth.uid()));

-- ---- Resume (the in-app resume builder) -------------------------------
drop policy if exists "resume_own_all"    on public."Resume";
drop policy if exists "resume_select_own" on public."Resume";
drop policy if exists "resume_insert_own" on public."Resume";
drop policy if exists "resume_update_own" on public."Resume";
drop policy if exists "resume_delete_own" on public."Resume";
create policy "resume_select_own" on public."Resume"
  for select to authenticated using ("seekerID" = (select auth.uid()));
create policy "resume_insert_own" on public."Resume"
  for insert to authenticated with check ("seekerID" = (select auth.uid()));
create policy "resume_update_own" on public."Resume"
  for update to authenticated
  using ("seekerID" = (select auth.uid())) with check ("seekerID" = (select auth.uid()));
create policy "resume_delete_own" on public."Resume"
  for delete to authenticated using ("seekerID" = (select auth.uid()));

-- ---- JobApplicant -----------------------------------------------------
drop policy if exists "applicant_select"                    on public."JobApplicant";
drop policy if exists "applicant_insert_own"                on public."JobApplicant";
drop policy if exists "applicant_update_staff"              on public."JobApplicant";
drop policy if exists "applicant_delete_own_or_staff"       on public."JobApplicant";
drop policy if exists "applicant_delete_staff"              on public."JobApplicant";
drop policy if exists "applicant_no_delete_by_seeker"       on public."JobApplicant";
drop policy if exists "applicant_hide_withdrawn_from_staff" on public."JobApplicant";

-- The applicant, the job's employer / company members, and admins
create policy "applicant_select" on public."JobApplicant"
  for select to authenticated
  using (
    "seekerID" = (select auth.uid())
    or public.app_is_job_staff("jobID")
    or (select public.app_is_admin())
  );
-- Employers update status, offers and AI ranking of their job's applicants
create policy "applicant_update_staff" on public."JobApplicant"
  for update to authenticated
  using (public.app_is_job_staff("jobID"))
  with check (public.app_is_job_staff("jobID"));
create policy "applicant_delete_staff" on public."JobApplicant"
  for delete to authenticated
  using (public.app_is_job_staff("jobID"));
-- Employers don't see withdrawn applications (restrictive: applies on top)
create policy "applicant_hide_withdrawn_from_staff" on public."JobApplicant"
  as restrictive for select to authenticated
  using (
    lower(btrim("applicationStatus")) <> 'withdrawn'
    or "seekerID" = (select auth.uid())
    or (select public.app_is_admin())
  );

-- ---- ApplicationAnswer ------------------------------------------------
drop policy if exists "answer_select"     on public."ApplicationAnswer";
drop policy if exists "answer_insert_own" on public."ApplicationAnswer";
drop policy if exists "answer_delete_own" on public."ApplicationAnswer";
create policy "answer_select" on public."ApplicationAnswer"
  for select to authenticated
  using (public.app_can_view_application("applicantID"));

-- ---- ReportedJob ------------------------------------------------------
drop policy if exists "report_insert_own"          on public."ReportedJob";
drop policy if exists "report_select_own_or_admin" on public."ReportedJob";
drop policy if exists "report_update_admin"        on public."ReportedJob";
drop policy if exists "report_delete_admin"        on public."ReportedJob";
create policy "report_insert_own" on public."ReportedJob"
  for insert to authenticated
  with check ("reporterID" = (select auth.uid()) and "status" = 'pending');
create policy "report_select_own_or_admin" on public."ReportedJob"
  for select to authenticated
  using ("reporterID" = (select auth.uid()) or (select public.app_is_admin()));
create policy "report_update_admin" on public."ReportedJob"
  for update to authenticated
  using ((select public.app_is_admin())) with check ((select public.app_is_admin()));
create policy "report_delete_admin" on public."ReportedJob"
  for delete to authenticated
  using ((select public.app_is_admin()));

-- ---- Career tools: read and delete own (only the functions write) ----
drop policy if exists "mock_own_select" on public."MockInterviewSession";
drop policy if exists "mock_own_delete" on public."MockInterviewSession";
create policy "mock_own_select" on public."MockInterviewSession"
  for select to authenticated using ("seekerID" = (select auth.uid()));
create policy "mock_own_delete" on public."MockInterviewSession"
  for delete to authenticated using ("seekerID" = (select auth.uid()));

drop policy if exists "mock_answer_own_select" on public."MockInterviewAnswer";
create policy "mock_answer_own_select" on public."MockInterviewAnswer"
  for select to authenticated
  using (exists (select 1 from public."MockInterviewSession" s
                 where s."sessionID" = "MockInterviewAnswer"."sessionID"
                   and s."seekerID" = (select auth.uid())));

drop policy if exists "skillgap_own_select" on public."SkillGapAnalysis";
drop policy if exists "skillgap_own_delete" on public."SkillGapAnalysis";
create policy "skillgap_own_select" on public."SkillGapAnalysis"
  for select to authenticated using ("seekerID" = (select auth.uid()));
create policy "skillgap_own_delete" on public."SkillGapAnalysis"
  for delete to authenticated using ("seekerID" = (select auth.uid()));

drop policy if exists "resume_review_own_select" on public."ResumeReview";
drop policy if exists "resume_review_own_delete" on public."ResumeReview";
create policy "resume_review_own_select" on public."ResumeReview"
  for select to authenticated using ("seekerID" = (select auth.uid()));
create policy "resume_review_own_delete" on public."ResumeReview"
  for delete to authenticated using ("seekerID" = (select auth.uid()));

drop policy if exists "conv_own_select" on public."AdvisorConversation";
drop policy if exists "conv_own_update" on public."AdvisorConversation";
drop policy if exists "conv_own_delete" on public."AdvisorConversation";
create policy "conv_own_select" on public."AdvisorConversation"
  for select to authenticated using ("seekerID" = (select auth.uid()));
create policy "conv_own_update" on public."AdvisorConversation"
  for update to authenticated
  using ("seekerID" = (select auth.uid())) with check ("seekerID" = (select auth.uid()));
create policy "conv_own_delete" on public."AdvisorConversation"
  for delete to authenticated using ("seekerID" = (select auth.uid()));

drop policy if exists "msg_own_select" on public."AdvisorMessage";
create policy "msg_own_select" on public."AdvisorMessage"
  for select to authenticated using ("seekerID" = (select auth.uid()));

-- Every table above keeps RLS switched on
alter table public."JobSeeker"            enable row level security;
alter table public."Education"            enable row level security;
alter table public."WorkExperience"       enable row level security;
alter table public."Skill"                enable row level security;
alter table public."BookmarkedJob"        enable row level security;
alter table public."Resume"               enable row level security;
alter table public."JobApplicant"         enable row level security;
alter table public."ApplicationAnswer"    enable row level security;
alter table public."ReportedJob"          enable row level security;
alter table public."MockInterviewSession" enable row level security;
alter table public."MockInterviewAnswer"  enable row level security;
alter table public."SkillGapAnalysis"     enable row level security;
alter table public."ResumeReview"         enable row level security;
alter table public."AdvisorConversation"  enable row level security;
alter table public."AdvisorMessage"       enable row level security;
