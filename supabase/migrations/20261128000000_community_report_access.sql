-- =====================================================================
-- Community reports: remove the leftover "allow manage" rules
--
-- ReportedPost and ReportedComment still had rules made in the dashboard:
--   "allow manage"                          (everything, for everyone)
--   "Users can submit their own reports"    (ReportedPost, any status)
--   "Allow users to submit comment reports" (ReportedComment, anything)
-- Rules add up, so these undid the moderation rules of 20261117000000:
-- anyone, even without logging in, could read, change or delete every
-- report, and file a report in someone else's name.
--
-- After this file only the 8 rules of 20261117000000 are left:
--   insert: your own report, as 'pending'
--   read:   your own reports; admins read all
--   change / delete: admins only
-- The app's Report button and the admin screens keep working (the admin
-- functions run with their own rights). Safe to run again.
-- =====================================================================

do $$
declare
  r record;
begin
  for r in
    select tablename, policyname from pg_policies
    where schemaname = 'public'
      and tablename in ('ReportedPost', 'ReportedComment')
      and policyname not in (
        'reported_post_insert_own', 'reported_post_select_own_or_admin',
        'reported_post_update_admin', 'reported_post_delete_admin',
        'reported_comment_insert_own', 'reported_comment_select_own_or_admin',
        'reported_comment_update_admin', 'reported_comment_delete_admin')
  loop
    execute format('drop policy %I on public.%I', r.policyname, r.tablename);
    raise notice 'Removed rule "%" on "%"', r.policyname, r.tablename;
  end loop;
end $$;

alter table public."ReportedPost"    enable row level security;
alter table public."ReportedComment" enable row level security;
