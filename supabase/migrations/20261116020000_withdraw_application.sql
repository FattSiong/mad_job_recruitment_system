-- =====================================================================
-- Withdraw Application (FN-JAM-06)
-- Run AFTER 20261101000000_job_seeker_security_fixes.sql
--
-- * A job seeker can withdraw their own application while it is still
--   'pending'. The record is kept with status 'withdrawn'; applying for
--   the same job again stays blocked (submit_job_application already
--   refuses a second application).
-- * Employers no longer see withdrawn applications (lists, counts,
--   details). The seeker still sees it in My Jobs as WITHDRAWN.
-- * Notifications about a withdrawn application are removed for the
--   employer and the seeker, and none are created for it later.
-- * A withdrawn application can't be changed again, and a seeker can no
--   longer delete their application row directly.
--
-- Nothing in the employer app needs to change. Safe to run again.
-- =====================================================================

-- ---------------------------------------------------------------------
-- 1. Allow the 'withdrawn' value if a check rule limits the statuses
-- ---------------------------------------------------------------------
do $$
declare
  c record;
  new_def text;
begin
  for c in
    select con.conname, pg_get_constraintdef(con.oid) as def
    from pg_constraint con
    where con.conrelid = 'public."JobApplicant"'::regclass
      and con.contype = 'c'
      and pg_get_constraintdef(con.oid) like '%applicationStatus%'
      and pg_get_constraintdef(con.oid) not like '%withdrawn%'
  loop
    new_def := regexp_replace(c.def, 'ARRAY\[', 'ARRAY[''withdrawn''::text, ');
    if new_def = c.def then
      raise notice 'Check rule "%" limits applicationStatus but could not be updated: add ''withdrawn'' to it by hand (%).',
                   c.conname, c.def;
    else
      execute format('alter table public."JobApplicant" drop constraint %I', c.conname);
      execute format('alter table public."JobApplicant" add constraint %I %s', c.conname, new_def);
      raise notice 'Check rule "%" now also allows ''withdrawn''', c.conname;
    end if;
  end loop;
end $$;

-- ---------------------------------------------------------------------
-- 2. The withdraw action (only the seeker's own, only while pending)
-- ---------------------------------------------------------------------
create or replace function public.withdraw_job_application(p_applicant_id text)
returns text
language plpgsql
volatile
security definer
set search_path = public
as $$
declare
  v_id text;
  v_has_interview boolean := false;
begin
  if auth.uid() is null then
    raise exception 'not_logged_in';
  end if;

  -- Checking "still pending" and changing it is one step, so an employer
  -- scheduling an interview at the same moment can't slip in between.
  -- An interview the employer is already arranging (it is saved just before
  -- the status changes to 'scheduled') also means it is no longer pending.
  if to_regclass('public."InterviewSchedule"') is not null then
    execute 'select exists (select 1 from public."InterviewSchedule" where "applicantID"::text = $1)'
      into v_has_interview using btrim(p_applicant_id);
  end if;

  update "JobApplicant"
  set "applicationStatus" = 'withdrawn'
  where "applicantID"::text = btrim(p_applicant_id)
    and "seekerID"::text = auth.uid()::text
    and lower(btrim("applicationStatus")) = 'pending'
    and not v_has_interview
  returning "applicantID"::text into v_id;

  if v_id is null then
    if exists (select 1 from "JobApplicant"
               where "applicantID"::text = btrim(p_applicant_id)
                 and "seekerID"::text = auth.uid()::text) then
      raise exception 'not_pending';
    end if;
    raise exception 'application_not_found';
  end if;

  -- Its notifications disappear for both the employer and the seeker
  if to_regclass('public."Notification"') is not null
     and exists (select 1 from information_schema.columns
                 where table_schema = 'public' and table_name = 'Notification'
                   and column_name = 'applicantID') then
    execute 'delete from public."Notification" where "applicantID"::text = $1' using v_id;
  end if;

  return 'withdrawn';
end;
$$;

revoke all on function public.withdraw_job_application(text) from public, anon;
grant execute on function public.withdraw_job_application(text) to authenticated;

-- ---------------------------------------------------------------------
-- 3. Employers don't see withdrawn applications
--    (restrictive rule: the existing rules stay as they are)
-- ---------------------------------------------------------------------
drop policy if exists "applicant_hide_withdrawn_from_staff" on public."JobApplicant";
create policy "applicant_hide_withdrawn_from_staff" on public."JobApplicant"
  as restrictive for select
  using (
    lower(btrim(coalesce("applicationStatus", ''))) <> 'withdrawn'
    or "seekerID"::text = auth.uid()::text
    or public.app_current_role() = 'admin'
  );

-- Seekers can't delete their application row (the record is kept)
drop policy if exists "applicant_no_delete_by_seeker" on public."JobApplicant";
create policy "applicant_no_delete_by_seeker" on public."JobApplicant"
  as restrictive for delete
  using ("seekerID"::text is distinct from auth.uid()::text);

-- ---------------------------------------------------------------------
-- 4. A withdrawn application stays as it is
--    (an update of it is skipped quietly, so bulk updates elsewhere,
--     e.g. closing a job, keep working)
-- ---------------------------------------------------------------------
create or replace function public.app_keep_withdrawn_application()
returns trigger
language plpgsql
as $$
begin
  if lower(btrim(coalesce(old."applicationStatus", ''))) = 'withdrawn' then
    return null;
  end if;
  return new;
end;
$$;

drop trigger if exists trg_keep_withdrawn_application on public."JobApplicant";
create trigger trg_keep_withdrawn_application
  before update on public."JobApplicant"
  for each row execute function public.app_keep_withdrawn_application();

-- ---------------------------------------------------------------------
-- 5. No new notifications about a withdrawn application
-- ---------------------------------------------------------------------
create or replace function public.app_skip_withdrawn_notification()
returns trigger
language plpgsql
security definer
set search_path = public
as $$
begin
  if new."applicantID" is not null and exists (
    select 1 from "JobApplicant" a
    where a."applicantID"::text = new."applicantID"::text
      and lower(btrim(coalesce(a."applicationStatus", ''))) = 'withdrawn'
  ) then
    return null; -- not saved, so it is not shown or pushed either
  end if;
  return new;
end;
$$;

do $$
begin
  if to_regclass('public."Notification"') is not null
     and exists (select 1 from information_schema.columns
                 where table_schema = 'public' and table_name = 'Notification'
                   and column_name = 'applicantID') then
    execute 'drop trigger if exists trg_skip_withdrawn_notification on public."Notification"';
    execute 'create trigger trg_skip_withdrawn_notification before insert on public."Notification" '
            'for each row execute function public.app_skip_withdrawn_notification()';
  else
    raise notice 'Table "Notification" (with applicantID) not found: skipped the notification rule';
  end if;
end $$;

-- ---------------------------------------------------------------------
-- 6. No interview can be scheduled for a withdrawn application
--    (an employer who still had the application open gets an error
--     instead of creating an interview the seeker would then see)
-- ---------------------------------------------------------------------
create or replace function public.app_no_interview_for_withdrawn()
returns trigger
language plpgsql
security definer
set search_path = public
as $$
begin
  if exists (
    select 1 from "JobApplicant" a
    where a."applicantID"::text = new."applicantID"::text
      and lower(btrim(coalesce(a."applicationStatus", ''))) = 'withdrawn'
  ) then
    raise exception 'application_withdrawn: the candidate withdrew this application';
  end if;
  return new;
end;
$$;

do $$
begin
  if to_regclass('public."InterviewSchedule"') is not null then
    execute 'drop trigger if exists trg_no_interview_for_withdrawn on public."InterviewSchedule"';
    execute 'create trigger trg_no_interview_for_withdrawn before insert or update on public."InterviewSchedule" '
            'for each row execute function public.app_no_interview_for_withdrawn()';
  else
    raise notice 'Table "InterviewSchedule" not found: skipped the interview rule';
  end if;
end $$;
