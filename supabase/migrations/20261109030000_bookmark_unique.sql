-- =====================================================================
-- Saved jobs: one bookmark per job per job seeker
-- Run AFTER 20261101000000_job_seeker_security_fixes.sql
--
-- The app blocks double taps, but nothing in the database stopped the same
-- job being saved twice (two phones, or the card and the details screen at
-- the same moment), which showed the job twice under My Jobs > Bookmarked.
-- =====================================================================

-- 1. Remove existing duplicates, keeping the earliest bookmark of each pair
delete from "BookmarkedJob" a
using "BookmarkedJob" b
where a."seekerID" = b."seekerID"
  and a."jobID" = b."jobID"
  and (
    coalesce(a."savedAt", 'infinity'::timestamptz) > coalesce(b."savedAt", 'infinity'::timestamptz)
    or (coalesce(a."savedAt", 'infinity'::timestamptz) = coalesce(b."savedAt", 'infinity'::timestamptz)
        and a.ctid > b.ctid)
  );

-- 2. Block new duplicates
create unique index if not exists bookmarkedjob_seeker_job_uq
  on "BookmarkedJob" ("seekerID", "jobID");
