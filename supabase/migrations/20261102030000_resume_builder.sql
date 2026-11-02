-- =====================================================================
-- In-app resume builder: one saved resume per job seeker.
-- The resume is its own copy (JSON), so editing it never changes the profile.
-- Safe to re-run; no existing data is changed.
-- =====================================================================

create table if not exists "Resume" (
  "seekerID"  uuid primary key references "JobSeeker"("seekerID") on delete cascade,
  "content"   jsonb not null default '{}'::jsonb,
  "updatedAt" timestamptz not null default now()
);

alter table "Resume" enable row level security;

drop policy if exists "resume_own_all" on "Resume";
create policy "resume_own_all" on "Resume"
  for all to authenticated
  using ("seekerID" = auth.uid())
  with check ("seekerID" = auth.uid());

-- Keep "updatedAt" current on every save.
create or replace function public.app_touch_resume()
returns trigger
language plpgsql
as $$
begin
  new."updatedAt" := now();
  return new;
end;
$$;

drop trigger if exists trg_touch_resume on "Resume";
create trigger trg_touch_resume
  before update on "Resume"
  for each row
  execute function public.app_touch_resume();
