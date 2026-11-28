-- =====================================================================
-- Unread chat counts, counted in the database
--
-- The chat list used to download one row per unread message, every time
-- a message arrived. API replies stop at 1,000 rows (max_rows), so bigger
-- totals came out wrong. This returns one row per room instead.
-- Runs as the caller, so the chat rules (own rooms only) still apply.
-- =====================================================================

create or replace function public.my_unread_counts()
returns table (room_id text, unread bigint)
language sql
stable
security invoker
set search_path = public
as $$
  select m."roomID"::text, count(*)
  from public."Message" m
  join public."ChatRoom" r on r."roomID" = m."roomID"
  where (r."user1_ID"::text = auth.uid()::text or r."user2_ID"::text = auth.uid()::text)
    and m."isRead" = false
    and m."senderID"::text <> auth.uid()::text
    and not coalesce(m."isDeleted", false)
  group by m."roomID";
$$;

revoke all on function public.my_unread_counts() from public, anon;
grant execute on function public.my_unread_counts() to authenticated;
