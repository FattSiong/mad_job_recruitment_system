-- =====================================================================
-- Job seeker module: indexes for the lookups the app runs
-- Run AFTER 20261127020000_job_seeker_access_rules.sql
--
-- Foreign keys are not indexed automatically, and the job search filters
-- with "contains" (ilike '%word%'), which a normal index can't help with.
--   Job: newest active jobs (the job list and its pages), and pg_trgm
--        indexes for the keyword search (title / description) and the
--        location filter; companyID for the company-name search.
--   AdvisorMessage: the Career Buddy rate limit (a seeker's recent messages).
--   BookmarkedJob.jobID, Education.seekerID, WorkExperience.seekerID.
-- Indexes only: no data or app change. Safe to run again.
-- =====================================================================

-- pg_trgm ("contains" search). Supabase keeps extensions in "extensions";
-- an older database may already have it in another schema.
create extension if not exists pg_trgm with schema extensions;

do $$
declare
  v_schema text;
begin
  select n.nspname into v_schema
  from pg_extension e join pg_namespace n on n.oid = e.extnamespace
  where e.extname = 'pg_trgm';

  execute format('create index if not exists job_title_description_trgm_idx on public."Job" '
                 'using gin ("title" %1$I.gin_trgm_ops, "description" %1$I.gin_trgm_ops)', v_schema);
  execute format('create index if not exists job_location_trgm_idx on public."Job" '
                 'using gin ("locationName" %1$I.gin_trgm_ops)', v_schema);
end $$;

-- The job list: active jobs, newest first (same order as the app's pages)
create index if not exists job_active_created_idx
  on public."Job" ("createdAt" desc, "jobID") where "status" = 'active';

create index if not exists job_company_idx on public."Job" ("companyID");

create index if not exists advisor_msg_seeker_created_idx
  on public."AdvisorMessage" ("seekerID", "createdAt" desc);

create index if not exists bookmarkedjob_job_idx    on public."BookmarkedJob" ("jobID");
create index if not exists education_seeker_idx      on public."Education" ("seekerID");
create index if not exists workexperience_seeker_idx on public."WorkExperience" ("seekerID");
