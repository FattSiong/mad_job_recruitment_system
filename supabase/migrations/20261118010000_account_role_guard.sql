-- =====================================================================
-- Account roles: only the server can make someone an admin (18 Nov 2026)
--
-- The app creates the "User" row itself when someone signs up, and sends
-- the role ('job_seeker' or 'employer') from the phone. The admin checks
-- (app_is_admin, app_current_role, the access rules on reports, the admin
-- moderation functions) all trust "User"."role" and the "Admin" table, so
-- a changed app or a direct API call must not be able to write 'admin'
-- there. This file makes the database refuse that:
--   * "User" insert from the app: only your own row, role job_seeker or
--     employer.
--   * "User" update from the app: the role and userID can't change
--     (an admin can still change someone's role).
--   * "Admin" table: only admins can add, change or remove admins.
-- The SQL editor, the dashboard and server code (no logged-in user) are
-- not limited, so admins are still created there as before.
-- Existing rows are not changed. Safe to run again.
-- =====================================================================

-- Is the logged-in user an admin by role? (Only "User"."role": the
-- "Admin" table is what the guard below protects.)
create or replace function public.app_has_admin_role()
returns boolean
language sql
stable
security definer
set search_path = public
as $$
  select exists (
    select 1 from public."User"
    where "userID" = auth.uid() and lower("role") = 'admin'
  );
$$;

create or replace function public.app_user_role_guard()
returns trigger
language plpgsql
set search_path = public
as $$
begin
  -- Server-side code (service role, SQL editor) is not limited
  if auth.uid() is null then
    return new;
  end if;

  if tg_op = 'INSERT' then
    if new."userID" is distinct from auth.uid() then
      raise exception 'not_own_account: you can only create your own profile'
        using errcode = '42501';
    end if;
    if lower(coalesce(new."role", '')) not in ('job_seeker', 'employer') then
      raise exception 'invalid_role: an account can only be a job seeker or an employer'
        using errcode = '42501';
    end if;
    new."role" := lower(new."role");
    return new;
  end if;

  -- UPDATE
  if public.app_has_admin_role() then
    return new; -- admins may change roles
  end if;
  if new."userID" is distinct from old."userID"
     or lower(coalesce(new."role", '')) is distinct from lower(coalesce(old."role", '')) then
    raise exception 'role_locked: the account role can only be changed by an admin'
      using errcode = '42501';
  end if;
  return new;
end;
$$;

drop trigger if exists trg_user_role_guard on public."User";
create trigger trg_user_role_guard
  before insert or update on public."User"
  for each row execute function public.app_user_role_guard();

create or replace function public.app_admin_table_guard()
returns trigger
language plpgsql
set search_path = public
as $$
begin
  if auth.uid() is not null and not public.app_has_admin_role() then
    raise exception 'admins_only: only an admin can change the admin list'
      using errcode = '42501';
  end if;
  return case when tg_op = 'DELETE' then old else new end;
end;
$$;

do $$
begin
  if to_regclass('public."Admin"') is not null then
    execute 'drop trigger if exists trg_admin_table_guard on public."Admin"';
    execute 'create trigger trg_admin_table_guard
               before insert or update or delete on public."Admin"
               for each row execute function public.app_admin_table_guard()';
  end if;
end $$;
