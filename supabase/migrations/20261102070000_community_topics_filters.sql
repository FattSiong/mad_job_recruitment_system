-- =====================================================================
-- Community Hub: post topics + feed filters.
--
-- 1. "CommunityPost"."category": the topic the author picks when posting.
--    Existing posts become 'general'.
-- 2. search_community_posts(...): filters, sorts and pages the Feed on the
--    server, returning rows of {post_id} (search text / author name, posted by, topic, date, attachment,
--    newest / most liked / most discussed). It returns only post IDs of
--    active posts; the app then loads those posts with its normal query,
--    so Row Level Security still applies to the post data.
--
-- Safe to re-run.
-- =====================================================================

-- ---------------------------------------------------------------------
-- 1. Topic column
-- ---------------------------------------------------------------------
alter table public."CommunityPost"
  add column if not exists "category" text not null default 'general';

do $$
begin
  if not exists (select 1 from pg_constraint where conname = 'CommunityPost_category_check') then
    alter table public."CommunityPost"
      add constraint "CommunityPost_category_check"
      check ("category" in ('general', 'job_tips', 'hiring', 'interview',
                            'question', 'career_advice', 'showcase'));
  end if;
end $$;

create index if not exists community_post_status_created_idx
  on public."CommunityPost" ("status", "createdAt" desc);
create index if not exists community_post_category_idx
  on public."CommunityPost" ("category");

-- ---------------------------------------------------------------------
-- 2. Feed search
--   p_search      text to find in the post or the author's name
--   p_author_role 'employer' | 'job_seeker' (null = everyone)
--   p_category    a topic value above (null = all topics)
--   p_since       only posts created at or after this time
--   p_media       'image' | 'pdf' (null = any)
--   p_sort        'newest' | 'most_liked' | 'most_discussed'
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
