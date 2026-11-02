-- =====================================================================
-- Intelligent Career Advisory Module - schema
-- Run in Supabase SQL Editor, or with `supabase db push`.
--
-- Write rule for AI result tables:
--   Seekers can READ (and DELETE) their own AI records, but cannot
--   INSERT/UPDATE them. Only Edge Functions (service role) write scores,
--   so a user can't fake an interview score from the app.
-- =====================================================================


-- ---------------------------------------------------------------------
-- 0. Small change to an existing table
-- ---------------------------------------------------------------------
-- Optional career goal, used as context for the AI Career Advisor.
alter table "JobSeeker"
  add column if not exists "careerGoal" text;


-- ---------------------------------------------------------------------
-- 1. Skill  (portfolio Table 4.17 + proficiency)
--    Needed by Skill Gap Analysis (precondition: profile has skills).
-- ---------------------------------------------------------------------
create table if not exists "Skill" (
  "skillID"     uuid primary key default gen_random_uuid(),
  "seekerID"    uuid not null references "JobSeeker"("seekerID") on delete cascade,
  "skillName"   text not null check (length(trim("skillName")) > 0),
  "proficiency" text check ("proficiency" in ('Beginner','Intermediate','Advanced')),
  "createdAt"   timestamptz not null default now()
);
-- No duplicate skills per seeker (case-insensitive)
create unique index if not exists skill_seeker_name_uq
  on "Skill" ("seekerID", lower("skillName"));


-- ---------------------------------------------------------------------
-- 2. AI Career Advisor chat history  (NEW - not in portfolio)
--    Use case 4.58: "saves the dialogue history to the database".
-- ---------------------------------------------------------------------
create table if not exists "AdvisorConversation" (
  "conversationID" uuid primary key default gen_random_uuid(),
  "seekerID"       uuid not null references "JobSeeker"("seekerID") on delete cascade,
  "title"          text not null default 'New conversation',
  "createdAt"      timestamptz not null default now(),
  "updatedAt"      timestamptz not null default now()
);
create index if not exists advisor_conv_seeker_idx
  on "AdvisorConversation" ("seekerID", "updatedAt" desc);

create table if not exists "AdvisorMessage" (
  "messageID"      uuid primary key default gen_random_uuid(),
  "conversationID" uuid not null references "AdvisorConversation"("conversationID") on delete cascade,
  "seekerID"       uuid not null references "JobSeeker"("seekerID") on delete cascade,
  -- 'user' / 'model' match Gemini's `contents[].role` exactly,
  -- so history rows map straight into the API request.
  "role"           text not null check ("role" in ('user','model')),
  "content"        text not null,
  "createdAt"      timestamptz not null default now()
);
create index if not exists advisor_msg_conv_idx
  on "AdvisorMessage" ("conversationID", "createdAt");


-- ---------------------------------------------------------------------
-- 3. Mock Interview  (portfolio Table 4.18, revised)
-- ---------------------------------------------------------------------
create table if not exists "MockInterviewRecord" (
  "sessionID"          uuid primary key default gen_random_uuid(),
  "seekerID"           uuid not null references "JobSeeker"("seekerID") on delete cascade,
  "targetJobRole"      text not null,
  "experienceLevel"    text,                                   -- e.g. 'Fresh Graduate'
  "status"             text not null default 'in_progress'
                         check ("status" in ('in_progress','completed')),
  -- Gemini-generated questions: [{"index":1,"question":"...","type":"behavioural"}]
  "questions"          jsonb not null default '[]'::jsonb,
  -- Filled in at the end (nullable while in progress)
  "transcriptText"     text,                                   -- all answers joined
  "overallScore"       int check ("overallScore" between 0 and 100),
  "contentScore"       int check ("contentScore" between 0 and 100),
  "deliveryScore"      int check ("deliveryScore" between 0 and 100),
  -- Scorecard: {"summary":"...","strengths":[],"improvements":[],"tips":[]}
  "aiEvaluationReport" jsonb,
  "createdAt"          timestamptz not null default now(),
  "completedAt"        timestamptz
);
create index if not exists mock_seeker_idx
  on "MockInterviewRecord" ("seekerID", "createdAt" desc);

-- One row per answered question (Deepgram + Gemini results)
create table if not exists "MockInterviewAnswer" (
  "answerID"         uuid primary key default gen_random_uuid(),
  "sessionID"        uuid not null references "MockInterviewRecord"("sessionID") on delete cascade,
  "questionIndex"    int  not null,
  "questionText"     text not null,
  -- From Deepgram
  "transcriptText"   text,
  "durationSeconds"  numeric(6,1),
  "wordsPerMinute"   numeric(5,1),
  "fillerWordCount"  int,
  "longPauseCount"   int,
  "confidence"       numeric(4,3),                             -- Deepgram transcript confidence
  -- From Gemini
  "contentScore"     int check ("contentScore" between 0 and 100),
  "deliveryScore"    int check ("deliveryScore" between 0 and 100),
  -- {"relevance":"...","clarity":"...","improvedAnswer":"...","tips":[]}
  "feedback"         jsonb,
  "createdAt"        timestamptz not null default now(),
  unique ("sessionID", "questionIndex")
);


-- ---------------------------------------------------------------------
-- 4. Skill Gap Analysis  (portfolio Table 4.19, text -> jsonb)
-- ---------------------------------------------------------------------
create table if not exists "SkillGapAnalysisRecord" (
  "analysisID"           uuid primary key default gen_random_uuid(),
  "seekerID"             uuid not null references "JobSeeker"("seekerID") on delete cascade,
  "targetJobRole"        text not null,
  -- ["Flutter","SQL"]  snapshot at analysis time
  "userSkills"           jsonb not null,
  -- [{"skill":"Docker","importance":"high"}]
  "marketRequiredSkills" jsonb not null,
  -- {"matching":["Flutter"],"missing":[{"skill":"Docker","priority":"high","reason":"..."}]}
  "identifiedGaps"       jsonb not null,
  "matchScore"           int check ("matchScore" between 0 and 100),
  -- {"summary":"...","recommendations":[{"type":"certification","title":"...","why":"..."}]}
  "aiAdvice"             jsonb not null,
  -- How many of our own Job postings were used as market data (use case A2)
  "jobSampleSize"        int not null default 0,
  "createdAt"            timestamptz not null default now()
);
create index if not exists skillgap_seeker_idx
  on "SkillGapAnalysisRecord" ("seekerID", "createdAt" desc);


-- ---------------------------------------------------------------------
-- 5. Guidance Reports view (use case 4.61) - one list, both activity types
--    security_invoker => RLS of the underlying tables still applies.
-- ---------------------------------------------------------------------
create or replace view "GuidanceReport" with (security_invoker = true) as
  select "sessionID"  as "reportID", "seekerID", 'mock_interview' as "type",
         "targetJobRole", "overallScore" as "score", "completedAt" as "createdAt"
  from "MockInterviewRecord" where "status" = 'completed'
  union all
  select "analysisID", "seekerID", 'skill_gap',
         "targetJobRole", "matchScore", "createdAt"
  from "SkillGapAnalysisRecord";


-- ---------------------------------------------------------------------
-- 6. Row Level Security
-- ---------------------------------------------------------------------
alter table "Skill"                  enable row level security;
alter table "AdvisorConversation"    enable row level security;
alter table "AdvisorMessage"         enable row level security;
alter table "MockInterviewRecord"    enable row level security;
alter table "MockInterviewAnswer"    enable row level security;
alter table "SkillGapAnalysisRecord" enable row level security;

-- Skill: user fully manages their own skills
create policy "skill_own_all" on "Skill"
  for all to authenticated
  using (auth.uid() = "seekerID") with check (auth.uid() = "seekerID");

-- Conversations: user can list, rename, delete their own
create policy "conv_own_select" on "AdvisorConversation"
  for select to authenticated using (auth.uid() = "seekerID");
create policy "conv_own_update" on "AdvisorConversation"
  for update to authenticated
  using (auth.uid() = "seekerID") with check (auth.uid() = "seekerID");
create policy "conv_own_delete" on "AdvisorConversation"
  for delete to authenticated using (auth.uid() = "seekerID");

-- Messages: read only (Edge Function inserts both user + model turns)
create policy "msg_own_select" on "AdvisorMessage"
  for select to authenticated using (auth.uid() = "seekerID");

-- Mock interview: read + delete own (delete also used for "Exit Interview")
create policy "mock_own_select" on "MockInterviewRecord"
  for select to authenticated using (auth.uid() = "seekerID");
create policy "mock_own_delete" on "MockInterviewRecord"
  for delete to authenticated using (auth.uid() = "seekerID");

create policy "mock_answer_own_select" on "MockInterviewAnswer"
  for select to authenticated
  using (exists (select 1 from "MockInterviewRecord" r
                 where r."sessionID" = "MockInterviewAnswer"."sessionID"
                   and r."seekerID" = auth.uid()));

-- Skill gap: read + delete own
create policy "skillgap_own_select" on "SkillGapAnalysisRecord"
  for select to authenticated using (auth.uid() = "seekerID");
create policy "skillgap_own_delete" on "SkillGapAnalysisRecord"
  for delete to authenticated using (auth.uid() = "seekerID");


-- ---------------------------------------------------------------------
-- 7. Housekeeping: abandoned interviews (app crashed, no "Exit")
--    Call from a scheduled Edge Function / pg_cron if you want.
-- ---------------------------------------------------------------------
create or replace function cleanup_stale_mock_interviews()
returns void language sql security definer set search_path = public as $$
  delete from "MockInterviewRecord"
  where "status" = 'in_progress'
    and "createdAt" < now() - interval '1 day';
$$;
