-- =====================================================================
-- Chat attachments: private bucket, only the two people in the chat.
--
-- Before: "chat_attachments" was a public bucket, so anyone with a file's
-- link could open a private chat photo, voice note or document - even
-- after the message was deleted.
-- After:  the bucket is private. The app opens files through short-lived
-- signed links, and storage only allows:
--   read   - members of that chat room
--   upload - members of that chat room, into that room's folder
--   delete - the person who uploaded the file (when deleting a message)
--
-- Files are stored as  chats/<roomID>/<timestamp>_<name>.
-- Old messages keep working: the app signs their stored links too.
-- Safe to re-run.
-- =====================================================================

update storage.buckets set public = false where id = 'chat_attachments';

-- True if the signed-in user is in the chat room this file belongs to.
-- (A plpgsql function so a badly formed path can never raise an error.)
create or replace function public.app_can_access_chat_file(p_name text)
returns boolean
language plpgsql
stable
security definer
set search_path = public
as $$
declare
  v_parts text[] := string_to_array(p_name, '/');
begin
  if auth.uid() is null
     or array_length(v_parts, 1) < 3
     or v_parts[1] <> 'chats'
     or v_parts[2] !~* '^[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}$' then
    return false;
  end if;
  return public.app_is_chat_member(v_parts[2]::uuid);
end;
$$;

revoke all on function public.app_can_access_chat_file(text) from public, anon;
grant execute on function public.app_can_access_chat_file(text) to authenticated;

-- Remove older policies that mention this bucket (e.g. "allow all"),
-- because policies are combined with OR and would keep files open.
do $$
declare
  pol record;
begin
  for pol in
    select policyname from pg_policies
    where schemaname = 'storage' and tablename = 'objects'
      and (coalesce(qual, '') ilike '%chat_attachments%'
           or coalesce(with_check, '') ilike '%chat_attachments%')
  loop
    execute format('drop policy if exists %I on storage.objects', pol.policyname);
    raise notice 'Removed old storage policy: %', pol.policyname;
  end loop;
end $$;

create policy "chat_files_member_read" on storage.objects for select to authenticated
  using (bucket_id = 'chat_attachments' and public.app_can_access_chat_file(name));

create policy "chat_files_member_insert" on storage.objects for insert to authenticated
  with check (bucket_id = 'chat_attachments' and public.app_can_access_chat_file(name));

create policy "chat_files_uploader_delete" on storage.objects for delete to authenticated
  using (bucket_id = 'chat_attachments'
         and owner_id = auth.uid()::text
         and public.app_can_access_chat_file(name));

-- Policies that allow every bucket (no bucket_id check) would also open chat
-- files. They are not removed automatically; review them if any are listed.
do $$
declare
  pol record;
begin
  for pol in
    select policyname, cmd from pg_policies
    where schemaname = 'storage' and tablename = 'objects'
      and policyname not like 'chat_files_%'
      and coalesce(qual, '') not ilike '%bucket_id%'
      and coalesce(with_check, '') not ilike '%bucket_id%'
  loop
    raise notice 'Review storage policy without a bucket check: % (%)', pol.policyname, pol.cmd;
  end loop;
end $$;
