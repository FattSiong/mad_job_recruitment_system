-- =====================================================================
-- Storage: keep private files private, own-folder rules for photos
-- Run AFTER 20261101000000_job_seeker_security_fixes.sql and
--           20261102060000_chat_attachments_private.sql
-- (if they have not been run, this file stops with a message and changes nothing)
--
-- 1. Storage policies are combined with OR: one old catch-all policy (for
--    example "allow all", true) lets anyone open resumes, application
--    answer files and chat files, whatever the stricter rules say.
--    The same old policy also lets anyone delete other people's profile
--    photos and post attachments.
--    Every OTHER policy on storage.objects is narrowed so it no longer
--    applies to the five buckets that have their own rules below. For all
--    other buckets (company logos, verification documents, ...) it works
--    exactly as before, so employer / admin features are not affected.
--      resumes, answer_files -> seeker_files_* (owner; employers and admins read)
--      chat_attachments      -> chat_files_*   (the two people in the chat)
--      profile_pictures,
--      post_media            -> own_files_*    (below)
--    Restrictive policies are left as they are (they only take access away).
--
-- 2. profile_pictures and post_media: users upload, replace and delete
--    only their own files: "<userId>/..." (job seekers, community posts) or
--    "employer_<userId>_..." (employer profile photos). Anyone with the link
--    can still view them (public buckets).
--
-- Safe to run again.
-- =====================================================================

-- ---------------------------------------------------------------------
-- 0. The rules for resumes, answer files and chat files must exist first:
--    without them, step 2 would leave those buckets with no access at all.
-- ---------------------------------------------------------------------
do $$
declare
  missing text[] := '{}';
begin
  if not exists (select 1 from pg_policies
                 where schemaname = 'storage' and tablename = 'objects'
                   and policyname = 'seeker_files_owner_read') then
    missing := missing || '20261101000000_job_seeker_security_fixes.sql'::text;
  end if;
  if not exists (select 1 from pg_policies
                 where schemaname = 'storage' and tablename = 'objects'
                   and policyname = 'chat_files_member_read') then
    missing := missing || '20261102060000_chat_attachments_private.sql'::text;
  end if;
  if cardinality(missing) > 0 then
    raise exception 'Run % first, then run this file again. Nothing was changed.',
      array_to_string(missing, ' and ');
  end if;
end $$;

-- ---------------------------------------------------------------------
-- 1. Helpers
-- ---------------------------------------------------------------------
-- Buckets whose access is set only by the rules in this app's migrations
create or replace function public.app_bucket_has_own_rules(p_bucket text)
returns boolean
language sql immutable
as $$
  select p_bucket in ('resumes', 'answer_files', 'chat_attachments', 'profile_pictures', 'post_media');
$$;

-- True if [p_name] is the logged-in user's file in profile_pictures / post_media
create or replace function public.app_is_own_public_file(p_name text)
returns boolean
language sql stable
as $$
  select auth.uid() is not null
     and ((storage.foldername(p_name))[1] = auth.uid()::text
          or p_name like 'employer\_' || auth.uid()::text || '\_%');
$$;

-- ---------------------------------------------------------------------
-- 2. Narrow every other policy away from those five buckets
-- ---------------------------------------------------------------------
do $$
declare
  pol record;
  using_expr text;
  check_expr text;
begin
  for pol in
    select policyname, cmd, qual, with_check
    from pg_policies
    where schemaname = 'storage' and tablename = 'objects'
      and permissive = 'PERMISSIVE'                     -- restrictive ones only take access away
      and (qual is not null or with_check is not null)  -- one with neither allows nothing
      and policyname not like 'seeker\_files\_%'
      and policyname not like 'chat\_files\_%'
      and policyname not like 'own\_files\_%'
      and coalesce(qual, '') || coalesce(with_check, '') not like '%app_bucket_has_own_rules%' -- already done
  loop
    using_expr := format('(%s) and not public.app_bucket_has_own_rules(bucket_id)', pol.qual);
    check_expr := format('(%s) and not public.app_bucket_has_own_rules(bucket_id)',
                         coalesce(pol.with_check, pol.qual));

    if pol.cmd in ('SELECT', 'DELETE') then
      execute format('alter policy %I on storage.objects using (%s)', pol.policyname, using_expr);
    elsif pol.cmd = 'INSERT' or pol.qual is null then
      -- INSERT, or an UPDATE / ALL policy that only has a WITH CHECK
      -- (it gets no USING: that would let it see rows it never could)
      execute format('alter policy %I on storage.objects with check (%s)', pol.policyname, check_expr);
    else -- ALL, UPDATE
      execute format('alter policy %I on storage.objects using (%s) with check (%s)',
                     pol.policyname, using_expr, check_expr);
    end if;
    raise notice 'Storage policy "%" (%) no longer applies to resumes, answer_files, chat_attachments, profile_pictures, post_media',
                 pol.policyname, pol.cmd;
  end loop;

  for pol in
    select policyname from pg_policies
    where schemaname = 'storage' and tablename = 'objects' and permissive = 'RESTRICTIVE'
  loop
    raise notice 'Restrictive storage policy "%" left unchanged', pol.policyname;
  end loop;
end $$;

-- ---------------------------------------------------------------------
-- 3. Own-folder rules for profile photos and community post attachments
--    (both buckets are public: anyone with the link can view the file)
-- ---------------------------------------------------------------------
drop policy if exists "own_files_read"   on storage.objects;
drop policy if exists "own_files_insert" on storage.objects;
drop policy if exists "own_files_update" on storage.objects;
drop policy if exists "own_files_delete" on storage.objects;

create policy "own_files_read" on storage.objects for select to authenticated
  using (bucket_id in ('profile_pictures', 'post_media'));

create policy "own_files_insert" on storage.objects for insert to authenticated
  with check (bucket_id in ('profile_pictures', 'post_media') and public.app_is_own_public_file(name));

create policy "own_files_update" on storage.objects for update to authenticated
  using (bucket_id in ('profile_pictures', 'post_media') and public.app_is_own_public_file(name))
  with check (bucket_id in ('profile_pictures', 'post_media') and public.app_is_own_public_file(name));

create policy "own_files_delete" on storage.objects for delete to authenticated
  using (bucket_id in ('profile_pictures', 'post_media') and public.app_is_own_public_file(name));
