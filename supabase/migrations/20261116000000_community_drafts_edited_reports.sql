-- =====================================================================
-- Community Hub: drafts, "Edited" label, reported posts hidden
-- Run AFTER 20261102070000_community_topics_filters.sql
--
-- 1. Drafts: "CommunityPost"."isDraft". A draft is seen only by its author
--    (My Posts). Publishing it makes it a new post (createdAt = now).
--    A published post cannot go back to being a draft.
-- 2. "Edited": "CommunityPost"."editedAt" is set by the database whenever
--    the text, attachment or topic of a published post changes.
-- 3. A post you reported no longer shows in your feed or saved posts.
--
-- Run this BEFORE installing the app version that uses it (the app reads
-- the new columns). Safe to run again.
-- =====================================================================

-- ---------------------------------------------------------------------
-- 1. Columns
-- ---------------------------------------------------------------------
alter table public."CommunityPost" add column if not exists "isDraft" boolean not null default false;
alter table public."CommunityPost" add column if not exists "editedAt" timestamptz;

-- ---------------------------------------------------------------------
-- 2. Edited time + publishing drafts (set by the database, so every
--    screen that edits posts gets it right)
-- ---------------------------------------------------------------------
create or replace function public.app_community_post_before_update()
returns trigger
language plpgsql
as $$
begin
  if not old."isDraft" and new."isDraft" then
    raise exception 'post_published: a published post cannot become a draft again';
  end if;

  if old."isDraft" and not new."isDraft" then
    -- Publishing a draft: it appears as a new post
    new."createdAt" := now();
    new."editedAt" := null;
  elsif not new."isDraft"
        and (new."content"  is distinct from old."content"
          or new."mediaURL" is distinct from old."mediaURL"
          or new."category" is distinct from old."category") then
    new."editedAt" := now();
  end if;
  return new;
end;
$$;

drop trigger if exists trg_community_post_before_update on public."CommunityPost";
create trigger trg_community_post_before_update
  before update on public."CommunityPost"
  for each row execute function public.app_community_post_before_update();

-- ---------------------------------------------------------------------
-- 3. Drafts are private to their author
--    (a restrictive rule: it only takes access away, all other rules on
--     CommunityPost stay as they are)
-- ---------------------------------------------------------------------
drop policy if exists "community_post_drafts_private" on public."CommunityPost";
create policy "community_post_drafts_private" on public."CommunityPost"
  as restrictive for select
  using (not "isDraft" or "authorID"::text = auth.uid()::text);

do $$
begin
  if not (select relrowsecurity from pg_class where oid = 'public."CommunityPost"'::regclass) then
    raise notice 'Row level security is off on "CommunityPost": drafts are kept out of the feed by the app and search_community_posts only';
  end if;
end $$;

-- ---------------------------------------------------------------------
-- 4. Posts the logged-in user reported (to hide them from that user)
-- ---------------------------------------------------------------------
create or replace function public.my_reported_post_ids()
returns table (post_id "CommunityPost"."postID"%type)
language sql
stable
security definer
set search_path = public
as $$
  select distinct r."postID"
  from "ReportedPost" r
  where auth.uid() is not null
    and r."reporterID"::text = auth.uid()::text;
$$;

revoke all on function public.my_reported_post_ids() from public, anon;
grant execute on function public.my_reported_post_ids() to authenticated;

-- ---------------------------------------------------------------------
-- 5. Feed search: no drafts, and no posts the user reported
--    (same as 20261102070000 plus the two lines marked NEW)
-- ---------------------------------------------------------------------
create or replace function public.search_community_posts(
  p_search      text        default null,
  p_author_role text        default null,
  p_category    text        default null,
  p_since       timestamptz default null,
  p_media       text        default null,
  p_sort        text        default 'newest',
  p_limit       integer     default 15,
  p_offset      integer     default 0
)
returns table (post_id "CommunityPost"."postID"%type)
language sql
stable
security definer
set search_path = public
as $$
  with term as (
    select lower(nullif(btrim(p_search), '')) as q
  ),
  posts as (
    select
      p."postID",
      p."createdAt",
      (select count(*) from "PostLike" l where l."postID" = p."postID") as likes,
      (select count(*) from "PostComment" c
        where c."postID" = p."postID"
          and coalesce(c."status", 'active') <> 'deleted') as comments
    from "CommunityPost" p
    cross join term t
    left join "User"      u  on u."userID"::text      = p."authorID"::text
    left join "JobSeeker" js on js."seekerID"::text   = p."authorID"::text
    left join "Employer"  e  on e."employerID"::text  = p."authorID"::text
    where auth.uid() is not null
      and p."status" = 'active'
      and not p."isDraft"                                                   -- NEW
      and not exists (select 1 from "ReportedPost" r                        -- NEW
                      where r."postID" = p."postID"
                        and r."reporterID"::text = auth.uid()::text)
      and (p_category is null or p."category" = p_category)
      and (p_since is null or p."createdAt" >= p_since)
      and (p_author_role is null
           or coalesce(u."role",
                       case when e."employerID" is not null then 'employer' else 'job_seeker' end)
              = p_author_role)
      and (p_media is null
           or (p_media = 'image' and lower(coalesce(p."mediaURL", '')) ~ '\.(jpe?g|png|webp|gif)($|\?)')
           or (p_media = 'pdf'   and lower(coalesce(p."mediaURL", '')) ~ '\.pdf($|\?)'))
      and (t.q is null
           or strpos(lower(coalesce(p."content", '')), t.q) > 0
           or strpos(lower(coalesce(e."fullName", js."fullName", u."username", '')), t.q) > 0)
  )
  select "postID"
  from posts
  order by
    case p_sort
      when 'most_liked'     then likes
      when 'most_discussed' then comments
      else 0
    end desc,
    "createdAt" desc,
    "postID"
  limit least(greatest(coalesce(p_limit, 15), 1), 50)
  offset greatest(coalesce(p_offset, 0), 0);
$$;

revoke all on function public.search_community_posts(text, text, text, timestamptz, text, text, integer, integer)
  from public, anon;
grant execute on function public.search_community_posts(text, text, text, timestamptz, text, text, integer, integer)
  to authenticated;
