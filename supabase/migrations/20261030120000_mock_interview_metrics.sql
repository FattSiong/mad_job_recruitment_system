-- =====================================================================
-- Mock Interview: AI consent + speech metrics
-- Run AFTER 20261030000000_career_advisory_module.sql
-- =====================================================================

-- Session level
alter table "MockInterviewRecord"
  add column if not exists "consentGivenAt" timestamptz,     -- when the user accepted the AI consent
  add column if not exists "questionCount"  int not null default 5
                                              check ("questionCount" between 1 and 10);

-- Answer level (calculated in the Edge Function from Deepgram word timestamps)
alter table "MockInterviewAnswer"
  add column if not exists "wordCount"              int,           -- words excluding fillers
  add column if not exists "fillerRate"             numeric(5,2),  -- fillers per 100 words
  add column if not exists "hesitationCount"        int,           -- pauses >= 1s + repeated words
  add column if not exists "responseLatencySeconds" numeric(5,1);  -- silence before first word

comment on column "MockInterviewAnswer"."durationSeconds"  is 'Length of the recorded answer (Deepgram metadata.duration)';
comment on column "MockInterviewAnswer"."wordsPerMinute"   is 'Non-filler words / speaking time (first word start -> last word end)';
comment on column "MockInterviewAnswer"."longPauseCount"   is 'Gaps between words >= 2.5s';
