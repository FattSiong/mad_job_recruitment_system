-- =====================================================================
-- "User" table: proper access rules
--
-- The dashboard rule "Allow users to insert their own profile" was for
-- every action, for everyone, with `using (true)`. So anyone, even
-- without logging in, could read every user's email and delete any
-- "User" row. Since 20261127040000 deleting a job seeker's "User" row
-- also removes their profile, applications, posts and chats.
--
-- Now:
--   read:   logged-in users (the app shows other people's username and
--           role in chat, Community Hub, profiles and the admin screens)
--   insert: your own row only (sign-up)
--   update: your own row only (the role guard trigger still stops role
--           changes)
--   delete: nobody through the API. Deleting the account in
--           Authentication > Users still works (its trigger runs with
--           the database's own rights).
-- Edge functions with the service key and the database functions that
-- check roles are not affected. Safe to run again.
-- =====================================================================

-- Remove every other rule on "User" (the dashboard one and any like it),
-- since rules add up: one left at `using (true)` would keep it open.
do $$
declare
  r record;
begin
  for r in
    select policyname from pg_policies
    where schemaname = 'public' and tablename = 'User'
      and policyname not in ('user_select_authenticated', 'user_insert_own', 'user_update_own')
  loop
    execute format('drop policy %I on public."User"', r.policyname);
    raise notice 'Removed rule "%" on "User"', r.policyname;
  end loop;
end $$;

alter table public."User" enable row level security;

drop policy if exists "user_select_authenticated" on public."User";
create policy "user_select_authenticated" on public."User"
  for select to authenticated
  using (true);

drop policy if exists "user_insert_own" on public."User";
create policy "user_insert_own" on public."User"
  for insert to authenticated
  with check ("userID" = (select auth.uid()));

drop policy if exists "user_update_own" on public."User";
create policy "user_update_own" on public."User"
  for update to authenticated
  using ("userID" = (select auth.uid()))
  with check ("userID" = (select auth.uid()));
