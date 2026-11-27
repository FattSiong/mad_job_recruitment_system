-- =====================================================================
-- Job seeker module: data rules in the database
-- Run AFTER 20261127000000_career_tool_renames.sql
--
-- The app already checks all of these on the phone; the database now
-- refuses the same bad values when they come from anywhere else.
--
--  1. Education / WorkExperience: current = no end date; otherwise an end
--     date on or after the start date.
--  2. JobApplicant."applicationStatus": one of the 9 statuses the app uses.
--  3. ReportedJob: status pending / deleted / dismissed, and one of the
--     5 reasons on the Report Job screen.
--  4. ApplicationAnswer: one answer per question, never empty.
--     submit_job_application() leaves out empty answers (the question
--     then counts as unanswered) and now runs with its own rights, so
--     answers can only be added through it.
--  5. MockInterviewSession: a completed interview has its scores and end time.
--  6. JobSeeker: name, bio and career goal lengths (as in the app);
--     LinkedIn / GitHub links are saved as https:// links.
--  7. Lengths of AI tool inputs (job role, conversation title).
--  8. Defaults for the "saved / applied / created at" times.
--  9. BookmarkedJob: the key is (seekerID, jobID); "bookmarkedID" is dropped.
--
-- Old rows: values that can be fixed safely are fixed first (letter case,
-- spaces, http -> https, end date of a current entry). If some old rows
-- still break a rule, that rule is NOT added and a NOTICE says which rows
-- to look at. Fix them and run this file again. Nothing else is deleted.
-- Safe to run again.
-- =====================================================================

create or replace function pg_temp.has_column(p_table text, p_column text)
returns boolean language sql stable as $$
  select exists (select 1 from information_schema.columns
                 where table_schema = 'public' and table_name = p_table and column_name = p_column);
$$;

-- Adds check rule p_name (p_expr) to p_table when every row passes it.
-- Otherwise the rule is skipped and the rows that break it are counted.
create or replace function pg_temp.add_check(p_table text, p_name text, p_expr text)
returns boolean language plpgsql as $$
declare
  v_bad bigint;
begin
  if to_regclass(format('public.%I', p_table)) is null then
    return false;
  end if;
  execute format('alter table public.%I drop constraint if exists %I', p_table, p_name);
  execute format('select count(*) from public.%I where not coalesce((%s), true)', p_table, p_expr)
    into v_bad;
  if v_bad > 0 then
    raise notice '% rule "%" not added: % row(s) break it. Find them with: select * from public."%" where not (%);',
      p_table, p_name, v_bad, p_table, p_expr;
    return false;
  end if;
  execute format('alter table public.%I add constraint %I check (%s)', p_table, p_name, p_expr);
  return true;
end;
$$;

-- ---------------------------------------------------------------------
-- 1. Education / WorkExperience dates
-- ---------------------------------------------------------------------
-- A current entry has no end date (the app never shows or saves one)
update public."Education"      set "endDate" = null where "isCurrent" and "endDate" is not null;
update public."WorkExperience" set "endDate" = null where "isCurrent" and "endDate" is not null;

do $$
declare
  v_rule constant text :=
    '("isCurrent" and "endDate" is null) or (not "isCurrent" and "endDate" is not null and "endDate" >= "startDate")';
begin
  perform pg_temp.add_check('Education', 'education_dates_check', v_rule);
  perform pg_temp.add_check('WorkExperience', 'work_experience_dates_check', v_rule);
end $$;

-- ---------------------------------------------------------------------
-- 2. Application status
-- ---------------------------------------------------------------------
-- Same spelling everywhere ('Pending ' -> 'pending'). The trigger that
-- keeps withdrawn applications unchanged is paused for this one update.
do $$
begin
  if exists (select 1 from public."JobApplicant"
             where "applicationStatus" <> lower(btrim("applicationStatus"))) then
    alter table public."JobApplicant" disable trigger user;
    update public."JobApplicant"
    set "applicationStatus" = lower(btrim("applicationStatus"))
    where "applicationStatus" <> lower(btrim("applicationStatus"));
    alter table public."JobApplicant" enable trigger user;
  end if;
end $$;

-- Any older status rule (e.g. the one 20261116020000 added 'withdrawn' to)
-- is replaced by this one.
do $$
declare
  c record;
begin
  for c in
    select con.conname from pg_constraint con
    where con.conrelid = 'public."JobApplicant"'::regclass and con.contype = 'c'
      and pg_get_constraintdef(con.oid) like '%applicationStatus%'
      and con.conname <> 'job_applicant_status_check'
  loop
    execute format('alter table public."JobApplicant" drop constraint %I', c.conname);
  end loop;

  perform pg_temp.add_check('JobApplicant', 'job_applicant_status_check',
    '"applicationStatus" in (''pending'', ''reviewed'', ''scheduled'', ''interviewed'', ''offered'', '
    '''accepted'', ''offer_declined'', ''rejected'', ''withdrawn'')');
end $$;

-- ---------------------------------------------------------------------
-- 3. Job reports
-- ---------------------------------------------------------------------
update public."ReportedJob"
set "status" = coalesce(nullif(lower(btrim("status")), ''), 'pending')
where "status" is distinct from coalesce(nullif(lower(btrim("status")), ''), 'pending');

update public."ReportedJob"
set "reportCategory" = btrim("reportCategory")
where "reportCategory" <> btrim("reportCategory");

do $$
begin
  perform pg_temp.add_check('ReportedJob', 'reported_job_status_check',
    '"status" in (''pending'', ''deleted'', ''dismissed'')');
  -- The reasons on the Report Job screen (report_job_screen.dart)
  perform pg_temp.add_check('ReportedJob', 'reported_job_category_check',
    '"reportCategory" in ('
    '''It''''s offensive and/or discriminatory'', '
    '''Asking for money or seems like a fake job'', '
    '''Incorrect company, location, or job details'', '
    '''I think it''''s trying to sell something unrelated to the job'', '
    '''Other'')');
end $$;

-- ---------------------------------------------------------------------
-- 4. Pre-screening answers
-- ---------------------------------------------------------------------
do $$
begin
  if exists (
    select 1 from public."ApplicationAnswer"
    group by "applicantID", "questionID" having count(*) > 1
  ) then
    raise notice 'ApplicationAnswer: one answer per question not added: some applications answer a question twice. '
                 'Find them with: select "applicantID", "questionID", count(*) from "ApplicationAnswer" group by 1, 2 having count(*) > 1;';
  else
    create unique index if not exists application_answer_applicant_question_uq
      on public."ApplicationAnswer" ("applicantID", "questionID");
  end if;

  perform pg_temp.add_check('ApplicationAnswer', 'application_answer_not_empty',
    'nullif(btrim(coalesce("answerText", '''')), '''') is not null '
    'or nullif(btrim(coalesce("answerFileURL", '''')), '''') is not null');
end $$;

-- Same steps and error codes as before (20261101000000), except:
--   * an empty answer is left out, so its question counts as unanswered
--     (missing_answers) instead of saving an empty row;
--   * a question sent twice keeps the first answer;
--   * it runs with its own rights (security definer): it checks the user
--     itself, so the app can't add or delete answers directly any more.
create or replace function public.submit_job_application(
  p_job_id     uuid,
  p_resume_url text,
  p_answers    jsonb default '[]'::jsonb
)
returns uuid
language plpgsql
security definer
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

  for v_answer in
    select * from jsonb_array_elements(
      case when jsonb_typeof(p_answers) = 'array' then p_answers else '[]'::jsonb end)
  loop
    begin
      v_question_id := (v_answer ->> 'questionID')::uuid;
    exception when invalid_text_representation then
      raise exception 'invalid_question';
    end;
    v_text := nullif(btrim(coalesce(v_answer ->> 'answerText', '')), '');
    v_file := nullif(btrim(coalesce(v_answer ->> 'answerFileURL', '')), '');

    if v_question_id is null or not exists (
      select 1 from "PreScreeningQuestion"
      where "questionID" = v_question_id and "jobID" = p_job_id
    ) then
      raise exception 'invalid_question';
    end if;

    if v_text is not null or v_file is not null then
      insert into "ApplicationAnswer" ("questionID", "applicantID", "answerText", "answerFileURL")
      select v_question_id, v_applicant_id, v_text, v_file
      where not exists (select 1 from "ApplicationAnswer"
                        where "applicantID" = v_applicant_id and "questionID" = v_question_id);
    end if;
  end loop;

  -- Every question of the job must have an answer
  select count(*) into v_missing
  from "PreScreeningQuestion" q
  where q."jobID" = p_job_id
    and not exists (
      select 1 from "ApplicationAnswer" aa
      where aa."applicantID" = v_applicant_id
        and aa."questionID" = q."questionID"
    );
  if v_missing > 0 then
    raise exception 'missing_answers';
  end if;

  return v_applicant_id;
  -- Any exception above rolls back the whole function: no half-saved application.
end;
$$;

revoke all on function public.submit_job_application(uuid, text, jsonb) from public, anon;
grant execute on function public.submit_job_application(uuid, text, jsonb) to authenticated;

-- ---------------------------------------------------------------------
-- 5. Mock interviews
-- ---------------------------------------------------------------------
do $$
begin
  perform pg_temp.add_check('MockInterviewSession', 'mock_session_completed_check',
    '"status" <> ''completed'' or ("completedAt" is not null and "contentScore" is not null '
    'and "deliveryScore" is not null)');

  -- 1 to 10 questions (already a rule in most databases)
  if not exists (select 1 from pg_constraint
                 where conrelid = 'public."MockInterviewSession"'::regclass and contype = 'c'
                   and pg_get_constraintdef(oid) like '%questionCount%') then
    perform pg_temp.add_check('MockInterviewSession', 'mock_session_question_count_range',
      '"questionCount" between 1 and 10');
  end if;
end $$;

-- ---------------------------------------------------------------------
-- 6. Job seeker profile
-- ---------------------------------------------------------------------
-- Links are kept as https:// links, the same way the app now saves them
-- ("linkedin.com/in/x" -> "https://linkedin.com/in/x"); empty -> null.
create or replace function pg_temp.https_link(p text)
returns text language sql immutable as $$
  select case
    when nullif(btrim(p), '') is null then null
    when btrim(p) ~* '^https?://' then regexp_replace(btrim(p), '^https?://', 'https://', 'i')
    else 'https://' || btrim(p)
  end;
$$;

update public."JobSeeker"
set "linkedInURL" = pg_temp.https_link("linkedInURL"),
    "gitHubURL"   = pg_temp.https_link("gitHubURL")
where "linkedInURL" is distinct from pg_temp.https_link("linkedInURL")
   or "gitHubURL"   is distinct from pg_temp.https_link("gitHubURL");

-- Empty text is saved as null by the app
update public."JobSeeker" set "bio" = null where btrim("bio") = '';
update public."JobSeeker" set "careerGoal" = null where btrim("careerGoal") = '';

do $$
begin
  -- The profile form allows 100 characters; sign-up has no limit, so 200 here
  perform pg_temp.add_check('JobSeeker', 'job_seeker_full_name_check',
    'btrim("fullName") <> '''' and char_length("fullName") <= 200');
  perform pg_temp.add_check('JobSeeker', 'job_seeker_bio_length', 'char_length("bio") <= 600');
  perform pg_temp.add_check('JobSeeker', 'job_seeker_career_goal_length', 'char_length("careerGoal") <= 300');
  perform pg_temp.add_check('JobSeeker', 'job_seeker_linkedin_url_check',
    '"linkedInURL" ~ ''^https://[^\s/]+\.\S+$'' and char_length("linkedInURL") <= 300');
  perform pg_temp.add_check('JobSeeker', 'job_seeker_github_url_check',
    '"gitHubURL" ~ ''^https://[^\s/]+\.\S+$'' and char_length("gitHubURL") <= 300');
end $$;

-- ---------------------------------------------------------------------
-- 7. AI tool inputs (the functions allow 100 characters for a job role
--    and 50 for the experience level; titles are cut to about 50)
-- ---------------------------------------------------------------------
do $$
begin
  perform pg_temp.add_check('MockInterviewSession', 'mock_session_role_length',
    'btrim("targetJobRole") <> '''' and char_length("targetJobRole") <= 100');
  perform pg_temp.add_check('MockInterviewSession', 'mock_session_level_length',
    'char_length("experienceLevel") <= 50');
  perform pg_temp.add_check('SkillGapAnalysis', 'skill_gap_role_length',
    'btrim("targetJobRole") <> '''' and char_length("targetJobRole") <= 100');
  perform pg_temp.add_check('ResumeReview', 'resume_review_role_length',
    'char_length("targetJobRole") <= 100');
  perform pg_temp.add_check('AdvisorConversation', 'advisor_conversation_title_length',
    'btrim("title") <> '''' and char_length("title") <= 100');
end $$;

-- ---------------------------------------------------------------------
-- 8. Times filled in by the database when the app leaves them out
-- ---------------------------------------------------------------------
alter table public."BookmarkedJob" alter column "savedAt"   set default now();
alter table public."JobApplicant"  alter column "appliedAt" set default now();
alter table public."Skill"         alter column "createdAt" set default now();

-- ---------------------------------------------------------------------
-- 9. BookmarkedJob: a bookmark is identified by who saved which job
-- ---------------------------------------------------------------------
do $$
begin
  if pg_temp.has_column('BookmarkedJob', 'bookmarkedID') then
    -- Duplicates (if any came back): keep the earliest bookmark of each pair
    delete from public."BookmarkedJob" a
    using public."BookmarkedJob" b
    where a."seekerID" = b."seekerID"
      and a."jobID" = b."jobID"
      and (coalesce(a."savedAt", 'infinity'::timestamptz) > coalesce(b."savedAt", 'infinity'::timestamptz)
           or (coalesce(a."savedAt", 'infinity'::timestamptz) = coalesce(b."savedAt", 'infinity'::timestamptz)
               and a.ctid > b.ctid));

    alter table public."BookmarkedJob" drop column "bookmarkedID"; -- its key goes with it
    alter table public."BookmarkedJob" add constraint "BookmarkedJob_pkey" primary key ("seekerID", "jobID");
    drop index if exists public.bookmarkedjob_seeker_job_uq; -- the key does this now
  end if;
end $$;
