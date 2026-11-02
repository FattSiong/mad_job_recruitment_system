-- =====================================================================
-- AI Resume Assistant: saved resume reviews.
-- Rows are written only by the resume-review Edge Function (service role);
-- the job seeker can read and delete their own.
-- Safe to re-run; no existing data is changed.
-- =====================================================================

create table if not exists "ResumeReviewRecord" (
  "reviewID"      uuid primary key default gen_random_uuid(),
  "seekerID"      uuid not null references "JobSeeker"("seekerID") on delete cascade,
  -- 'uploaded' = the PDF/DOCX on the profile, 'builder' = the in-app resume
  "source"        text not null check ("source" in ('uploaded', 'builder')),
  "resumeName"    text not null default '',
  -- Optional job the user wants the resume to fit
  "targetJobRole" text,
  "overallScore"  int not null check ("overallScore" between 0 and 100),
  -- {"verdict","summary","categories":[...],"strengths":[...],"improvements":[...],
  --  "missingSections":[...],"keywordSuggestions":[...],"formattingNotes":[...]}
  "feedback"      jsonb not null,
  "createdAt"     timestamptz not null default now()
);

create index if not exists resume_review_seeker_idx
  on "ResumeReviewRecord" ("seekerID", "createdAt" desc);

alter table "ResumeReviewRecord" enable row level security;

drop policy if exists "resume_review_own_select" on "ResumeReviewRecord";
create policy "resume_review_own_select" on "ResumeReviewRecord"
  for select to authenticated using (auth.uid() = "seekerID");

drop policy if exists "resume_review_own_delete" on "ResumeReviewRecord";
create policy "resume_review_own_delete" on "ResumeReviewRecord"
  for delete to authenticated using (auth.uid() = "seekerID");
