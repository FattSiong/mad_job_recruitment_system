-- =====================================================================
-- Job seeker contact details are no longer readable by everyone
--
-- Before: "jobseeker_select" was `using (true)`, so any logged-in account
-- could call the API and read every job seeker's email, phone number and
-- resume link. The app only hid them on screen.
--
-- Now:
--   - A full JobSeeker row can be read by the seeker themselves, admins
--     and employers (employers see applicants' contact details, as before).
--   - Everyone else (other job seekers) gets only the public profile
--     fields, through public_seeker_profiles(). The app uses it for names
--     and photos in chat / Community Hub and for another seeker's public
--     profile (QR code).
--   - Education, WorkExperience and Skill are unchanged.
-- =====================================================================

-- Logged-in user is an employer
create or replace function public.app_is_employer()
returns boolean
language sql
stable
security definer
set search_path = public
as $$
  select exists (
    select 1 from public."User"
    where "userID"::text = auth.uid()::text and lower("role") = 'employer'
  );
$$;
revoke all on function public.app_is_employer() from public, anon;
grant execute on function public.app_is_employer() to authenticated;

-- Remove every read rule on JobSeeker (also any made in the dashboard),
-- since rules add up: one left at `using (true)` would keep it open.
do $$
declare
  r record;
begin
  for r in
    select policyname from pg_policies
    where schemaname = 'public' and tablename = 'JobSeeker' and cmd = 'SELECT'
  loop
    execute format('drop policy %I on public."JobSeeker"', r.policyname);
  end loop;
end $$;

alter table public."JobSeeker" enable row level security;

create policy "jobseeker_select" on public."JobSeeker"
  for select to authenticated
  using (
    "seekerID"::text = (select auth.uid())::text
    or (select public.app_is_employer())
    or (select public.app_is_admin())
  );

-- Public profile fields of job seekers (no email, phone or resume)
create or replace function public.public_seeker_profiles(p_ids uuid[])
returns table (
  "seekerID" uuid,
  "fullName" text,
  "profilePictureURL" text,
  "location" text,
  "bio" text,
  "careerGoal" text,
  "linkedInURL" text,
  "gitHubURL" text
)
language sql
stable
security definer
set search_path = public
as $$
  select s."seekerID"::uuid, s."fullName"::text, s."profilePictureURL"::text,
         s."location"::text, s."bio"::text, s."careerGoal"::text,
         s."linkedInURL"::text, s."gitHubURL"::text
  from public."JobSeeker" s
  where auth.uid() is not null
    and s."seekerID"::text = any (select unnest(p_ids[1:500])::text);
$$;
revoke all on function public.public_seeker_profiles(uuid[]) from public, anon;
grant execute on function public.public_seeker_profiles(uuid[]) to authenticated;

-- Any rule on JobSeeker for ALL commands (e.g. an old "Allow manage" made in
-- the dashboard) would still let people read rows: list them so they can be
-- checked.
do $$
declare
  r record;
begin
  for r in
    select policyname, qual from pg_policies
    where schemaname = 'public' and tablename = 'JobSeeker' and cmd = 'ALL'
  loop
    raise warning 'JobSeeker still has rule "%" for all commands (using: %). If it lets others read rows, drop it.',
      r.policyname, r.qual;
  end loop;
end $$;
