-- =====================================================================
-- Job Seeker module: security & data-integrity fixes
--   #1 one application per job       -> unique index + check in submit function
--   #2 all-or-nothing applications    -> submit_job_application() function
--   #3 ownership rules (RLS)          -> JobSeeker, Education, WorkExperience,
--                                        BookmarkedJob, JobApplicant, ApplicationAnswer
--   #7 private resumes / answer files -> private buckets + storage policies
--
-- NOT changed on purpose: the "Job" table policies (the seeker app still marks
-- expired jobs as inactive, see job_discovery_controller.dart).
--
-- Run once in the Supabase SQL Editor (or `supabase db push`).
-- =====================================================================


-- ---------------------------------------------------------------------
-- 0. Helper functions (SECURITY DEFINER so policies don't loop on each other)
-- ---------------------------------------------------------------------

-- Role of the logged-in user: 'job_seeker' | 'employer' | 'admin' | null
create or replace function public.app_current_role()
returns text
language sql stable security definer set search_path = public
as $$
  select "role" from "User" where "userID" = auth.uid();
$$;

-- True if the logged-in user posted the job or is an active member of its company
create or replace function public.app_is_job_staff(p_job_id uuid)
returns boolean
language sql stable security definer set search_path = public
as $$
  select exists (
    select 1
    from "Job" j
    where j."jobID" = p_job_id
      and (
        j."employerID" = auth.uid()
        or exists (
          select 1 from "CompanyMember" cm
          where cm."companyID" = j."companyID"
            and cm."employerID" = auth.uid()
            and cm."status" = 'active'
        )
      )
  );
$$;

-- True if the logged-in user can see this application (owner, job staff or admin)
create or replace function public.app_can_view_application(p_applicant_id uuid)
returns boolean
language sql stable security definer set search_path = public
as $$
  select exists (
    select 1 from "JobApplicant" a
    where a."applicantID" = p_applicant_id
      and (
        a."seekerID" = auth.uid()
        or public.app_is_job_staff(a."jobID")
        or public.app_current_role() = 'admin'
      )
  );
$$;

grant execute on function public.app_current_role() to authenticated;
grant execute on function public.app_is_job_staff(uuid) to authenticated;
grant execute on function public.app_can_view_application(uuid) to authenticated;


-- ---------------------------------------------------------------------
-- 1. One application per job and seeker
--    If duplicates already exist, the index is skipped (with a NOTICE) so the
--    rest of this file still runs. submit_job_application() blocks new ones anyway.
-- ---------------------------------------------------------------------
do $$
declare
  dup_count int;
begin
  select count(*) into dup_count
  from (
    select 1 from "JobApplicant"
    group by "jobID", "seekerID"
    having count(*) > 1
  ) d;

  if dup_count = 0 then
    create unique index if not exists jobapplicant_job_seeker_uq
      on "JobApplicant" ("jobID", "seekerID");
  else
    raise notice
      'Skipped unique index: % job/seeker pair(s) already have duplicate applications. '
      'Find them with: select "jobID","seekerID",count(*) from "JobApplicant" group by 1,2 having count(*)>1; '
      'delete the extra rows (and their ApplicationAnswer rows), then run this block again.', dup_count;
  end if;
end $$;


-- ---------------------------------------------------------------------
-- 2. Submit an application in ONE transaction (application + all answers)
--    p_answers: [{"questionID":"...","answerText":"..."}, {"questionID":"...","answerFileURL":"..."}]
--    Raises (message is the code the app checks):
--      not_authenticated | not_job_seeker | job_unavailable | already_applied
--      resume_required | invalid_question | missing_answers
-- ---------------------------------------------------------------------
create or replace function public.submit_job_application(
  p_job_id     uuid,
  p_resume_url text,
  p_answers    jsonb default '[]'::jsonb
)
returns uuid
language plpgsql
security invoker              -- runs as the user, so the RLS policies below still apply
set search_path = public
as $$
declare
  v_uid          uuid := auth.uid();
  v_applicant_id uuid;
  v_answer       jsonb;
  v_question_id  uuid;
  v_text         text;
  v_file         text;
  v_missing      int;
begin
  if v_uid is null then
    raise exception 'not_authenticated';
  end if;

  if not exists (select 1 from "JobSeeker" where "seekerID" = v_uid) then
    raise exception 'not_job_seeker';
  end if;

  if not exists (
    select 1 from "Job"
    where "jobID" = p_job_id
      and "status" = 'active'
      and ("expiresAt" is null or "expiresAt" > now())
  ) then
    raise exception 'job_unavailable';
  end if;

  if exists (select 1 from "JobApplicant" where "jobID" = p_job_id and "seekerID" = v_uid) then
    raise exception 'already_applied';
  end if;

  if p_resume_url is null or btrim(p_resume_url) = '' then
    raise exception 'resume_required';
  end if;

  insert into "JobApplicant" ("jobID", "seekerID", "submittedResumeURL", "applicationStatus", "appliedAt")
  values (p_job_id, v_uid, btrim(p_resume_url), 'pending', now())
  returning "applicantID" into v_applicant_id;

  for v_answer in select * from jsonb_array_elements(coalesce(p_answers, '[]'::jsonb))
  loop
    v_question_id := (v_answer ->> 'questionID')::uuid;
    v_text := nullif(btrim(coalesce(v_answer ->> 'answerText', '')), '');
    v_file := nullif(btrim(coalesce(v_answer ->> 'answerFileURL', '')), '');

    if not exists (
      select 1 from "PreScreeningQuestion"
      where "questionID" = v_question_id and "jobID" = p_job_id
    ) then
      raise exception 'invalid_question';
    end if;

    insert into "ApplicationAnswer" ("questionID", "applicantID", "answerText", "answerFileURL")
    values (v_question_id, v_applicant_id, v_text, v_file);
  end loop;

  -- Every question of the job must have a text or file answer
  select count(*) into v_missing
  from "PreScreeningQuestion" q
  where q."jobID" = p_job_id
    and not exists (
      select 1 from "ApplicationAnswer" aa
      where aa."applicantID" = v_applicant_id
        and aa."questionID" = q."questionID"
        and (aa."answerText" is not null or aa."answerFileURL" is not null)
    );
  if v_missing > 0 then
    raise exception 'missing_answers';
  end if;

  return v_applicant_id;
  -- Any exception above rolls back the whole function: no half-saved application.
end;
$$;

grant execute on function public.submit_job_application(uuid, text, jsonb) to authenticated;


-- ---------------------------------------------------------------------
-- 3. Ownership rules (RLS)
-- ---------------------------------------------------------------------

-- JobSeeker: everyone logged in can read profiles (employers, chat, community);
-- only the owner can create/edit/delete their own row.
drop policy if exists "Allow manage" on "JobSeeker";
drop policy if exists "jobseeker_select" on "JobSeeker";
drop policy if exists "jobseeker_insert_own" on "JobSeeker";
drop policy if exists "jobseeker_update_own" on "JobSeeker";
drop policy if exists "jobseeker_delete_own" on "JobSeeker";
alter table "JobSeeker" enable row level security;
create policy "jobseeker_select"     on "JobSeeker" for select to authenticated using (true);
create policy "jobseeker_insert_own" on "JobSeeker" for insert to authenticated with check (auth.uid() = "seekerID");
create policy "jobseeker_update_own" on "JobSeeker" for update to authenticated
  using (auth.uid() = "seekerID") with check (auth.uid() = "seekerID");
create policy "jobseeker_delete_own" on "JobSeeker" for delete to authenticated using (auth.uid() = "seekerID");

-- Education / WorkExperience: readable by logged-in users (shown to employers), owner-only writes
drop policy if exists "Allow manage" on "Education";
drop policy if exists "education_select" on "Education";
drop policy if exists "education_write_own" on "Education";
alter table "Education" enable row level security;
create policy "education_select"    on "Education" for select to authenticated using (true);
create policy "education_write_own" on "Education" for all to authenticated
  using (auth.uid() = "seekerID") with check (auth.uid() = "seekerID");

drop policy if exists "Allow manage" on "WorkExperience";
drop policy if exists "workexperience_select" on "WorkExperience";
drop policy if exists "workexperience_write_own" on "WorkExperience";
alter table "WorkExperience" enable row level security;
create policy "workexperience_select"    on "WorkExperience" for select to authenticated using (true);
create policy "workexperience_write_own" on "WorkExperience" for all to authenticated
  using (auth.uid() = "seekerID") with check (auth.uid() = "seekerID");

-- BookmarkedJob: private to the owner
drop policy if exists "Allow manage" on "BookmarkedJob";
drop policy if exists "bookmark_own" on "BookmarkedJob";
alter table "BookmarkedJob" enable row level security;
create policy "bookmark_own" on "BookmarkedJob" for all to authenticated
  using (auth.uid() = "seekerID") with check (auth.uid() = "seekerID");

-- JobApplicant: the applicant, the job's employer/company members, and admins can read.
-- Seekers create their own; employers of the job update status / AI ranking.
drop policy if exists "Allow manage" on "JobApplicant";
drop policy if exists "applicant_select" on "JobApplicant";
drop policy if exists "applicant_insert_own" on "JobApplicant";
drop policy if exists "applicant_update_staff" on "JobApplicant";
drop policy if exists "applicant_delete_own_or_staff" on "JobApplicant";
alter table "JobApplicant" enable row level security;
create policy "applicant_select" on "JobApplicant" for select to authenticated
  using (
    auth.uid() = "seekerID"
    or public.app_is_job_staff("jobID")
    or public.app_current_role() = 'admin'
  );
create policy "applicant_insert_own" on "JobApplicant" for insert to authenticated
  with check (auth.uid() = "seekerID");
create policy "applicant_update_staff" on "JobApplicant" for update to authenticated
  using (public.app_is_job_staff("jobID")) with check (public.app_is_job_staff("jobID"));
create policy "applicant_delete_own_or_staff" on "JobApplicant" for delete to authenticated
  using (auth.uid() = "seekerID" or public.app_is_job_staff("jobID"));

-- ApplicationAnswer: same visibility as its application; only the applicant can add answers
drop policy if exists "Allow manage" on "ApplicationAnswer";
drop policy if exists "answer_select" on "ApplicationAnswer";
drop policy if exists "answer_insert_own" on "ApplicationAnswer";
drop policy if exists "answer_delete_own" on "ApplicationAnswer";
alter table "ApplicationAnswer" enable row level security;
create policy "answer_select" on "ApplicationAnswer" for select to authenticated
  using (public.app_can_view_application("applicantID"));
create policy "answer_insert_own" on "ApplicationAnswer" for insert to authenticated
  with check (exists (
    select 1 from "JobApplicant" a
    where a."applicantID" = "ApplicationAnswer"."applicantID" and a."seekerID" = auth.uid()
  ));
create policy "answer_delete_own" on "ApplicationAnswer" for delete to authenticated
  using (exists (
    select 1 from "JobApplicant" a
    where a."applicantID" = "ApplicationAnswer"."applicantID" and a."seekerID" = auth.uid()
  ));


-- ---------------------------------------------------------------------
-- 7. Private resumes and answer files
--    Files stay at "<userId>/<file>". The app now opens them with short-lived signed URLs.
--    Read access: the owner, employers and admins.
-- ---------------------------------------------------------------------
update storage.buckets set public = false where id in ('resumes', 'answer_files');

drop policy if exists "seeker_files_owner_read" on storage.objects;
drop policy if exists "seeker_files_staff_read" on storage.objects;
drop policy if exists "seeker_files_owner_insert" on storage.objects;
drop policy if exists "seeker_files_owner_update" on storage.objects;
drop policy if exists "seeker_files_owner_delete" on storage.objects;

create policy "seeker_files_owner_read" on storage.objects for select to authenticated
  using (bucket_id in ('resumes', 'answer_files')
         and (storage.foldername(name))[1] = auth.uid()::text);

create policy "seeker_files_staff_read" on storage.objects for select to authenticated
  using (bucket_id in ('resumes', 'answer_files')
         and public.app_current_role() in ('employer', 'admin'));

create policy "seeker_files_owner_insert" on storage.objects for insert to authenticated
  with check (bucket_id in ('resumes', 'answer_files')
              and (storage.foldername(name))[1] = auth.uid()::text);

create policy "seeker_files_owner_update" on storage.objects for update to authenticated
  using (bucket_id in ('resumes', 'answer_files')
         and (storage.foldername(name))[1] = auth.uid()::text);

create policy "seeker_files_owner_delete" on storage.objects for delete to authenticated
  using (bucket_id in ('resumes', 'answer_files')
         and (storage.foldername(name))[1] = auth.uid()::text);

-- Older, broader storage policies (e.g. "allow all") would still let anyone read these files,
-- because policies are combined with OR. List them so you can review / remove them:
do $$
declare r record;
begin
  for r in
    select policyname, cmd, coalesce(qual, '') as qual
    from pg_policies
    where schemaname = 'storage' and tablename = 'objects'
      and policyname not like 'seeker_files_%'
      and cmd in ('SELECT', 'ALL')
  loop
    raise notice 'Review storage policy "%" (%): %', r.policyname, r.cmd, r.qual;
  end loop;
end $$;
