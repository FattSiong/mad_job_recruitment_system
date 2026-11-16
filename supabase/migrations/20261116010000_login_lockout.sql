-- =====================================================================
-- Login lockout (NF-SEC-02)
-- After 5 wrong passwords in a row (within 15 minutes) the account's
-- email is locked for 15 minutes. While locked, even the right password
-- is refused. A successful login clears the count.
--
-- The app calls these before / after Supabase sign-in:
--   login_lock_status(email)     -> is it locked? how many tries left?
--   login_record_failure(email)  -> after a wrong password
--   login_clear_failures()       -> after a successful login (own email only)
-- Each returns {"locked": bool, "seconds_left": int, "attempts_left": int}.
--
-- Safe to run again.
-- =====================================================================

create table if not exists public."LoginAttempt" (
  "email"        text primary key,
  "failedCount"  integer not null default 0,
  "lastFailedAt" timestamptz,
  "lockedUntil"  timestamptz
);

-- Only the functions below read or change it (no direct access from the app)
alter table public."LoginAttempt" enable row level security;
revoke all on public."LoginAttempt" from anon, authenticated;

-- Settings in one place
create or replace function public.app_login_max_attempts() returns integer
language sql immutable as $$ select 5 $$;

create or replace function public.app_login_lock_minutes() returns integer
language sql immutable as $$ select 15 $$;

-- Status of one (already normalised) email
create or replace function public.app_login_status(p_email text)
returns jsonb
language plpgsql
stable
security definer
set search_path = public
as $$
declare
  a "LoginAttempt";
  failures integer := 0;
begin
  select * into a from "LoginAttempt" where "email" = p_email;

  if a."lockedUntil" is not null and a."lockedUntil" > now() then
    return jsonb_build_object(
      'locked', true,
      'seconds_left', ceil(extract(epoch from a."lockedUntil" - now()))::integer,
      'attempts_left', 0);
  end if;

  -- Wrong passwords only count if they were in the last 15 minutes
  -- (and not before a lock that has now ended)
  if a."lockedUntil" is null
     and a."lastFailedAt" is not null
     and a."lastFailedAt" > now() - make_interval(mins => public.app_login_lock_minutes()) then
    failures := a."failedCount";
  end if;

  return jsonb_build_object(
    'locked', false,
    'seconds_left', 0,
    'attempts_left', greatest(public.app_login_max_attempts() - failures, 0));
end;
$$;

create or replace function public.app_login_email(p_email text)
returns text
language sql
immutable
as $$
  select nullif(left(lower(btrim(coalesce(p_email, ''))), 320), '');
$$;

-- Before signing in
create or replace function public.login_lock_status(p_email text)
returns jsonb
language sql
stable
security definer
set search_path = public
as $$
  select case
    when public.app_login_email(p_email) is null
      then jsonb_build_object('locked', false, 'seconds_left', 0,
                              'attempts_left', public.app_login_max_attempts())
    else public.app_login_status(public.app_login_email(p_email))
  end;
$$;

-- After a wrong password
create or replace function public.login_record_failure(p_email text)
returns jsonb
language plpgsql
volatile
security definer
set search_path = public
as $$
declare
  v_email text := public.app_login_email(p_email);
  a "LoginAttempt";
  v_count integer;
begin
  if v_email is null then
    return public.login_lock_status(p_email);
  end if;

  -- Tidy up old rows now and then (nothing else needs them)
  delete from "LoginAttempt"
  where coalesce("lockedUntil", "lastFailedAt") < now() - interval '1 day';

  select * into a from "LoginAttempt" where "email" = v_email for update;

  -- Already locked: the lock is not made longer
  if a."lockedUntil" is not null and a."lockedUntil" > now() then
    return public.app_login_status(v_email);
  end if;

  -- Count this failure; older ones (over 15 minutes, or before a lock) start again
  if a."email" is null
     or a."lastFailedAt" is null
     or a."lastFailedAt" <= now() - make_interval(mins => public.app_login_lock_minutes())
     or a."lockedUntil" is not null then
    v_count := 1;
  else
    v_count := a."failedCount" + 1;
  end if;

  insert into "LoginAttempt" ("email", "failedCount", "lastFailedAt", "lockedUntil")
  values (v_email, v_count, now(),
          case when v_count >= public.app_login_max_attempts()
               then now() + make_interval(mins => public.app_login_lock_minutes()) end)
  on conflict ("email") do update
    set "failedCount"  = excluded."failedCount",
        "lastFailedAt" = excluded."lastFailedAt",
        "lockedUntil"  = excluded."lockedUntil";

  return public.app_login_status(v_email);
end;
$$;

-- After a successful login: clears the logged-in user's own count only
create or replace function public.login_clear_failures()
returns void
language sql
volatile
security definer
set search_path = public
as $$
  delete from "LoginAttempt"
  where auth.uid() is not null
    and "email" = public.app_login_email(auth.jwt() ->> 'email')
    and ("lockedUntil" is null or "lockedUntil" <= now());
$$;

revoke all on function public.app_login_status(text) from public, anon, authenticated;
revoke all on function public.login_lock_status(text) from public;
revoke all on function public.login_record_failure(text) from public;
revoke all on function public.login_clear_failures() from public, anon;
grant execute on function public.login_lock_status(text) to anon, authenticated;
grant execute on function public.login_record_failure(text) to anon, authenticated;
grant execute on function public.login_clear_failures() to authenticated;
