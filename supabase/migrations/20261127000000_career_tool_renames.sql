-- =====================================================================
-- Career tools: clearer names, speech / camera numbers as JSON
-- Run AFTER every earlier migration.
--
-- DEPLOY TOGETHER: right after this file, deploy the three functions
--   supabase functions deploy mock-interview resume-review skill-gap-analysis
-- and install the updated app. They use the new names below; the old
-- versions stop working once this file has run.
--
-- 1. Names
--    MockInterviewRecord    -> MockInterviewSession  (one row per interview)
--    SkillGapAnalysisRecord -> SkillGapAnalysis
--    ResumeReviewRecord     -> ResumeReview
--    The AI's written feedback is "aiFeedback" in every career table
--    (was aiEvaluationReport / feedback / aiAdvice).
--    ReportedJob."reportJobID" -> "reportID" (like PostInterviewReport).
-- 2. MockInterviewAnswer: the 8 speech numbers are one "speechMetrics"
--    object and the 4 camera numbers one "faceMetrics" object (null when
--    the camera was off). The function already saved the speech numbers
--    inside the feedback as well; now they are kept once.
-- 3. MockInterviewSession."overallScore" is worked out by the database
--    from the content and delivery scores (60 / 40), so it always matches.
-- 4. SkillGapAnalysis."identifiedGaps" is dropped: it only repeated
--    "marketRequiredSkills" sorted by status. The app sorts them itself.
--
-- No data is lost: renamed columns keep their values and the old numbers
-- are copied into the new JSON columns before those columns are dropped.
-- Safe to run again.
-- =====================================================================

create or replace function pg_temp.has_column(p_table text, p_column text)
returns boolean language sql stable as $$
  select exists (select 1 from information_schema.columns
                 where table_schema = 'public' and table_name = p_table and column_name = p_column);
$$;

create or replace function pg_temp.rename_table(p_old text, p_new text)
returns void language plpgsql as $$
begin
  if to_regclass(format('public.%I', p_old)) is not null
     and to_regclass(format('public.%I', p_new)) is null then
    execute format('alter table public.%I rename to %I', p_old, p_new);
  end if;
end;
$$;

create or replace function pg_temp.rename_column(p_table text, p_old text, p_new text)
returns void language plpgsql as $$
begin
  if pg_temp.has_column(p_table, p_old) and not pg_temp.has_column(p_table, p_new) then
    execute format('alter table public.%I rename column %I to %I', p_table, p_old, p_new);
  end if;
end;
$$;

-- ---------------------------------------------------------------------
-- 1. Names
-- ---------------------------------------------------------------------
do $$
begin
  perform pg_temp.rename_table('MockInterviewRecord', 'MockInterviewSession');
  perform pg_temp.rename_table('SkillGapAnalysisRecord', 'SkillGapAnalysis');
  perform pg_temp.rename_table('ResumeReviewRecord', 'ResumeReview');

  perform pg_temp.rename_column('MockInterviewSession', 'aiEvaluationReport', 'aiFeedback');
  perform pg_temp.rename_column('MockInterviewAnswer', 'feedback', 'aiFeedback');
  perform pg_temp.rename_column('ResumeReview', 'feedback', 'aiFeedback');
  perform pg_temp.rename_column('SkillGapAnalysis', 'aiAdvice', 'aiFeedback');
  perform pg_temp.rename_column('ReportedJob', 'reportJobID', 'reportID');
end $$;

-- The daily clean-up (pg_cron calls it by name) reads the new table
create or replace function public.cleanup_stale_mock_interviews()
returns void language sql security definer set search_path = public as $$
  delete from "MockInterviewSession"
  where "status" = 'in_progress'
    and "createdAt" < now() - interval '1 day';
$$;
revoke execute on function public.cleanup_stale_mock_interviews() from public, anon, authenticated;

-- ---------------------------------------------------------------------
-- 2. MockInterviewAnswer: speech and camera numbers as JSON
-- ---------------------------------------------------------------------
alter table public."MockInterviewAnswer"
  add column if not exists "speechMetrics" jsonb not null default '{}'::jsonb,
  add column if not exists "faceMetrics"   jsonb;

comment on column public."MockInterviewAnswer"."speechMetrics" is
  'From the Deepgram word timestamps: durationSeconds, wordCount, wordsPerMinute, paceLabel, fillerWordCount, fillerRate, longPauseCount, hesitationCount, responseLatencySeconds, ...';
comment on column public."MockInterviewAnswer"."faceMetrics" is
  'Camera cues measured on the phone (feedback only, not in any score): facePresentPercent, eyeContactPercent, smilePercent, lookAwayCount, sampleCount. Null = camera off';

do $$
begin
  if pg_temp.has_column('MockInterviewAnswer', 'wordsPerMinute') then
    -- The full set saved in the feedback ("metrics"), with the columns on top
    update public."MockInterviewAnswer"
    set "speechMetrics" =
          coalesce(case when jsonb_typeof("aiFeedback" -> 'metrics') = 'object'
                        then "aiFeedback" -> 'metrics' end, '{}'::jsonb)
          || jsonb_strip_nulls(jsonb_build_object(
               'durationSeconds',        "durationSeconds",
               'wordsPerMinute',         "wordsPerMinute",
               'wordCount',              "wordCount",
               'fillerWordCount',        "fillerWordCount",
               'fillerRate',             "fillerRate",
               'longPauseCount',         "longPauseCount",
               'hesitationCount',        "hesitationCount",
               'responseLatencySeconds', "responseLatencySeconds")),
        "faceMetrics" =
          case when "facePresentPercent" is not null then
            jsonb_build_object(
              'facePresentPercent', "facePresentPercent",
              'eyeContactPercent',  "eyeContactPercent",
              'smilePercent',       "smilePercent",
              'lookAwayCount',      coalesce("lookAwayCount", 0))
          end,
        "aiFeedback" = case when "aiFeedback" is null then null else "aiFeedback" - 'metrics' end;

    alter table public."MockInterviewAnswer"
      drop column "durationSeconds",
      drop column "wordsPerMinute",
      drop column "wordCount",
      drop column "fillerWordCount",
      drop column "fillerRate",
      drop column "longPauseCount",
      drop column "hesitationCount",
      drop column "responseLatencySeconds",
      drop column if exists "eyeContactPercent",
      drop column if exists "smilePercent",
      drop column if exists "facePresentPercent",
      drop column if exists "lookAwayCount";
  end if;
end $$;

alter table public."MockInterviewAnswer" drop constraint if exists mock_answer_speech_metrics_object;
alter table public."MockInterviewAnswer"
  add constraint mock_answer_speech_metrics_object
  check (jsonb_typeof("speechMetrics") = 'object');
alter table public."MockInterviewAnswer" drop constraint if exists mock_answer_face_metrics_object;
alter table public."MockInterviewAnswer"
  add constraint mock_answer_face_metrics_object
  check ("faceMetrics" is null or jsonb_typeof("faceMetrics") = 'object');

-- ---------------------------------------------------------------------
-- 3. overallScore = 60% content + 40% delivery, kept by the database
--    (null while the interview is in progress). The Guidance Reports
--    view reads the column, so it is made again around the change.
-- ---------------------------------------------------------------------
do $$
begin
  if not exists (
    select 1 from information_schema.columns
    where table_schema = 'public' and table_name = 'MockInterviewSession'
      and column_name = 'overallScore' and is_generated = 'ALWAYS'
  ) then
    drop view if exists public."GuidanceReport";
    alter table public."MockInterviewSession" drop column if exists "overallScore";
    alter table public."MockInterviewSession"
      add column "overallScore" integer
      generated always as (round("contentScore" * 0.6 + "deliveryScore" * 0.4)::integer) stored;
  end if;
end $$;

comment on column public."MockInterviewSession"."overallScore" is
  'round(contentScore * 0.6 + deliveryScore * 0.4), set by the database';

-- Guidance Reports (one list of interviews and skill gap analyses).
-- security_invoker: each user still only sees their own rows.
create or replace view public."GuidanceReport" with (security_invoker = true) as
  select "sessionID"  as "reportID", "seekerID", 'mock_interview' as "type",
         "targetJobRole", "overallScore" as "score", "completedAt" as "createdAt"
  from public."MockInterviewSession" where "status" = 'completed'
  union all
  select "analysisID", "seekerID", 'skill_gap',
         "targetJobRole", "matchScore", "createdAt"
  from public."SkillGapAnalysis";

revoke all on public."GuidanceReport" from anon;
grant select on public."GuidanceReport" to authenticated;

-- ---------------------------------------------------------------------
-- 4. SkillGapAnalysis: the matched / partial / missing lists come from
--    "marketRequiredSkills" (each skill has its status)
-- ---------------------------------------------------------------------
alter table public."SkillGapAnalysis" drop column if exists "identifiedGaps";
