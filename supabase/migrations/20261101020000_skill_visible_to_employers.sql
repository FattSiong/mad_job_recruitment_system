-- =====================================================================
-- Let logged-in users read job seekers' skills (same rule as Education
-- and WorkExperience), so skills show on the public QR profile and on the
-- employer's applicant detail screen.
-- Only the owner can still add, change or delete their skills
-- (existing policy "skill_own_all").
-- Safe to re-run; no data is changed.
-- =====================================================================

drop policy if exists "skill_select_authenticated" on "Skill";
create policy "skill_select_authenticated" on "Skill"
  for select to authenticated
  using (true);
