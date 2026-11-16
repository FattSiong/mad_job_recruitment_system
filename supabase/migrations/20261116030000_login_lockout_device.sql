-- =====================================================================
-- Login lockout, version 2 (NF-SEC-02)
-- Run AFTER 20261116010000_login_lockout.sql
--
-- Version 1 locked the email for everyone, so a stranger typing wrong
-- passwords for your email could lock YOU out. Now:
--   * 5 wrong passwords in a row (within 15 minutes) lock that email
--     on THAT PHONE only, for 15 minutes. Other phones are not affected.
--   * 20 wrong passwords within an hour from any phones lock the email
--     everywhere for 1 hour (stops guessing from many phones).
--   * A successful login clears that phone's count.
--   * Resetting the password (Forgot Password) clears every lock on the
--     account, so the real owner can always get back in.
--
-- The app sends a random ID it keeps for each phone (not personal data).
-- Each function returns
--   {"locked": bool, "seconds_left": int, "attempts_left": int, "scope": "device" | "account"}
-- Safe to run again.
-- =====================================================================

-- ---------------------------------------------------------------------
-- 1. One row per email + phone ("*" = the whole account)
-- ---------------------------------------------------------------------
alter table public."LoginAttempt" add column if not exists "deviceID" text not null default '*';

do $$
declare
  pk_name text;
  pk_cols text;
begin
  select con.conname,
         (select string_agg(a.attname, ',' order by a.attnum)
          from pg_attribute a
          where a.attrelid = con.conrelid and a.attnum = any(con.conkey))
    into pk_name, pk_cols
  from pg_constraint con
  where con.conrelid = 'public."LoginAttempt"'::regclass and con.contype = 'p';

  if pk_cols is distinct from 'email,deviceID' then
    if pk_name is not null then
      execute format('alter table public."LoginAttempt" drop constraint %I', pk_name);
    end if;
    alter table public."LoginAttempt" add primary key ("email", "deviceID");
  end if;
end $$;

-- ---------------------------------------------------------------------
-- 2. Version 1 functions are replaced (they took only the email)
-- ---------------------------------------------------------------------
drop function if exists public.login_lock_status(text);
drop function if exists public.login_record_failure(text);
drop function if exists public.login_clear_failures();
drop function if exists public.app_login_status(text);

-- Settings
create or replace function public.app_login_max_attempts() returns integer
language sql immutable as $$ select 5 $$;            -- per phone
create or replace function public.app_login_lock_minutes() returns integer
language sql immutable as $$ select 15 $$;           -- per phone
create or replace function public.app_login_account_max_attempts() returns integer
language sql immutable as $$ select 20 $$;           -- all phones together
create or replace function public.app_login_account_lock_minutes() returns integer
language sql immutable as $$ select 60 $$;           -- window and lock for the account

create or replace function public.app_login_device(p_device text)
returns text
language sql
immutable
as $$
  select coalesce(nullif(left(btrim(coalesce(p_device, '')), 64), ''), 'unknown');
$$;

-- Wrong passwords that still count in one row
create or replace function public.app_login_failures(a "LoginAttempt", p_window_minutes integer)
returns integer
language sql
stable
as $$
  select case
    when a."email" is null or a."lockedUntil" is not null or a."lastFailedAt" is null then 0
    when a."lastFailedAt" <= now() - make_interval(mins => p_window_minutes) then 0
    else a."failedCount"
  end;
$$;

-- ---------------------------------------------------------------------
-- 3. Status for an email on one phone
-- ---------------------------------------------------------------------
create or replace function public.app_login_status(p_email text, p_device text)
returns jsonb
language plpgsql
stable
security definer
set search_path = public
as $$
declare
  acc "LoginAttempt";
  dev "LoginAttempt";
  acc_until timestamptz;
  dev_until timestamptz;
begin
  select * into acc from "LoginAttempt" where "email" = p_email and "deviceID" = '*';
  select * into dev from "LoginAttempt" where "email" = p_email and "deviceID" = p_device;
  acc_until := case when acc."lockedUntil" > now() then acc."lockedUntil" end;
  dev_until := case when dev."lockedUntil" > now() then dev."lockedUntil" end;

  if acc_until is not null or dev_until is not null then
    return jsonb_build_object(
      'locked', true,
      'seconds_left', ceil(extract(epoch from greatest(acc_until, dev_until) - now()))::integer,
      'attempts_left', 0,
      'scope', case when acc_until is not null and acc_until >= coalesce(dev_until, acc_until)
                    then 'account' else 'device' end);
  end if;

  return jsonb_build_object(
    'locked', false,
    'seconds_left', 0,
    'attempts_left', greatest(least(
        public.app_login_max_attempts()
          - public.app_login_failures(dev, public.app_login_lock_minutes()),
        public.app_login_account_max_attempts()
          - public.app_login_failures(acc, public.app_login_account_lock_minutes())), 0),
    'scope', 'device');
end;
$$;

-- Adds one wrong password to a row; locks it when the limit is reached
create or replace function public.app_login_bump(
  p_email text, p_device text, p_max integer, p_window_minutes integer, p_lock_minutes integer)
returns void
language plpgsql
volatile
security definer
set search_path = public
as $$
declare
  a "LoginAttempt";
  v_count integer;
begin
  select * into a from "LoginAttempt"
  where "email" = p_email and "deviceID" = p_device
  for update;

  v_count := public.app_login_failures(a, p_window_minutes) + 1;

  insert into "LoginAttempt" ("email", "deviceID", "failedCount", "lastFailedAt", "lockedUntil")
  values (p_email, p_device, v_count, now(),
          case when v_count >= p_max then now() + make_interval(mins => p_lock_minutes) end)
  on conflict ("email", "deviceID") do update
    set "failedCount"  = excluded."failedCount",
        "lastFailedAt" = excluded."lastFailedAt",
        "lockedUntil"  = excluded."lockedUntil";
end;
$$;

-- ---------------------------------------------------------------------
-- 4. What the app calls
-- ---------------------------------------------------------------------
-- Before signing in
create or replace function public.login_lock_status(p_email text, p_device text)
returns jsonb
language sql
stable
security definer
set search_path = public
as $$
  select case
    when public.app_login_email(p_email) is null
      then jsonb_build_object('locked', false, 'seconds_left', 0,
                              'attempts_left', public.app_login_max_attempts(), 'scope', 'device')
    else public.app_login_status(public.app_login_email(p_email), public.app_login_device(p_device))
  end;
$$;

-- After a wrong password
create or replace function public.login_record_failure(p_email text, p_device text)
returns jsonb
language plpgsql
volatile
security definer
set search_path = public
as $$
declare
  v_email  text := public.app_login_email(p_email);
  v_device text := public.app_login_device(p_device);
begin
  if v_email is null then
    return public.login_lock_status(p_email, p_device);
  end if;

  -- Tidy up old rows now and then (nothing else needs them)
  delete from "LoginAttempt"
  where coalesce("lockedUntil", "lastFailedAt") < now() - interval '1 day';

  -- Already locked: the lock is not made longer
  if (public.app_login_status(v_email, v_device) ->> 'locked')::boolean then
    return public.app_login_status(v_email, v_device);
  end if;

  perform public.app_login_bump(v_email, v_device,
    public.app_login_max_attempts(), public.app_login_lock_minutes(), public.app_login_lock_minutes());
  perform public.app_login_bump(v_email, '*',
    public.app_login_account_max_attempts(), public.app_login_account_lock_minutes(),
    public.app_login_account_lock_minutes());

  return public.app_login_status(v_email, v_device);
end;
$$;

-- After a successful login: clears this phone's count (own email only)
create or replace function public.login_clear_failures(p_device text)
returns void
language sql
volatile
security definer
set search_path = public
as $$
  delete from "LoginAttempt"
  where auth.uid() is not null
    and "email" = public.app_login_email(auth.jwt() ->> 'email')
    and "deviceID" = public.app_login_device(p_device);
$$;

-- After resetting the password: clears every lock on the account (own email only).
-- Only the account's owner can be logged in to call this, so it is safe.
create or replace function public.login_clear_all_failures()
returns void
language sql
volatile
security definer
set search_path = public
as $$
  delete from "LoginAttempt"
  where auth.uid() is not null
    and "email" = public.app_login_email(auth.jwt() ->> 'email');
$$;

revoke all on function public.app_login_status(text, text) from public, anon, authenticated;
revoke all on function public.app_login_bump(text, text, integer, integer, integer) from public, anon, authenticated;
revoke all on function public.login_lock_status(text, text) from public;
revoke all on function public.login_record_failure(text, text) from public;
revoke all on function public.login_clear_failures(text) from public, anon;
revoke all on function public.login_clear_all_failures() from public, anon;
grant execute on function public.login_lock_status(text, text) to anon, authenticated;
grant execute on function public.login_record_failure(text, text) to anon, authenticated;
grant execute on function public.login_clear_failures(text) to authenticated;
grant execute on function public.login_clear_all_failures() to authenticated;
