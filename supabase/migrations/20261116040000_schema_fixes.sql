-- =====================================================================
-- Schema fixes (review of the live schema, 16 Nov 2026)
-- Run AFTER every earlier migration.
--
-- BEFORE running this: deploy the updated mock-interview Edge Function
--   supabase functions deploy mock-interview
-- (it no longer writes the two columns dropped in part 2).
--
-- 1. Data safety: missing foreign keys / NOT NULL rules
--    Message.senderID -> User, Message.isDeleted not null,
--    Education.seekerID not null, UserBlock -> User,
--    ReportedPost / ReportedComment status + reportedAt not null.
-- 2. Unused columns dropped; PostComment."updateAt" is now set when a
--    comment is edited (the app shows "Edited").
-- 3. Indexes for the lookups the app runs most.
-- 4. ReportedComment defaults made the same as the other tables.
--
-- Old data is never deleted. A rule that old rows break is still added
-- for new rows (NOT VALID) and a NOTICE says which rows to check; after
-- fixing them, run this file again to switch the rule on fully.
-- Safe to run again.
-- =====================================================================

-- Small helpers in pg_temp: they only exist while this file runs
create or replace function pg_temp.has_column(p_table text, p_column text)
returns boolean language sql stable as $$
  select exists (select 1 from information_schema.columns
                 where table_schema = 'public' and table_name = p_table and column_name = p_column);
$$;

create or replace function pg_temp.has_constraint(p_table text, p_name text)
returns boolean language sql stable as $$
  select exists (select 1 from pg_constraint
                 where conrelid = to_regclass(format('public.%I', p_table)) and conname = p_name);
$$;

-- Adds a foreign key. If old rows break it, it is added NOT VALID (checked
-- for new rows only) and the number of rows to fix is reported.
create or replace function pg_temp.add_fk(
  p_table text, p_column text, p_name text, p_ref_table text, p_ref_column text, p_on_delete text)
returns void language plpgsql as $$
declare
  v_bad bigint;
begin
  if not pg_temp.has_column(p_table, p_column)
     or not pg_temp.has_column(p_ref_table, p_ref_column) then
    return;
  end if;
  -- Added earlier as NOT VALID: check it now if the old rows were fixed
  if pg_temp.has_constraint(p_table, p_name) then
    if exists (select 1 from pg_constraint
               where conrelid = format('public.%I', p_table)::regclass
                 and conname = p_name and not convalidated) then
      execute format(
        'select count(*) from public.%I t where t.%I is not null
           and not exists (select 1 from public.%I r where r.%I = t.%I)',
        p_table, p_column, p_ref_table, p_ref_column, p_column) into v_bad;
      if v_bad = 0 then
        execute format('alter table public.%I validate constraint %I', p_table, p_name);
      else
        raise notice '%: % row(s) still point to a missing % row.', p_name, v_bad, p_ref_table;
      end if;
    end if;
    return;
  end if;
  -- an equivalent foreign key under another name already exists
  if exists (
    select 1 from pg_constraint c
    join pg_attribute a on a.attrelid = c.conrelid and a.attnum = c.conkey[1]
    where c.conrelid = format('public.%I', p_table)::regclass and c.contype = 'f'
      and array_length(c.conkey, 1) = 1 and a.attname = p_column
      and c.confrelid = format('public.%I', p_ref_table)::regclass
  ) then
    return;
  end if;

  execute format(
    'select count(*) from public.%I t where t.%I is not null
       and not exists (select 1 from public.%I r where r.%I = t.%I)',
    p_table, p_column, p_ref_table, p_ref_column, p_column) into v_bad;

  execute format('alter table public.%I add constraint %I foreign key (%I) references public.%I (%I) on delete %s %s',
                 p_table, p_name, p_column, p_ref_table, p_ref_column, p_on_delete,
                 case when v_bad > 0 then 'not valid' else '' end);
  if v_bad > 0 then
    raise notice '%: % row(s) point to a missing % row. New rows are checked already; fix or delete those rows and run this file again.',
                 p_name, v_bad, p_ref_table;
  end if;
end;
$$;

-- Makes a column NOT NULL if no row is null; otherwise reports how many are.
create or replace function pg_temp.set_not_null(p_table text, p_column text)
returns void language plpgsql as $$
declare
  v_nulls bigint;
begin
  if not pg_temp.has_column(p_table, p_column) then return; end if;
  execute format('select count(*) from public.%I where %I is null', p_table, p_column) into v_nulls;
  if v_nulls = 0 then
    execute format('alter table public.%I alter column %I set not null', p_table, p_column);
  else
    raise notice '%.%: % row(s) are empty, so NOT NULL was not added. Fix or delete them and run this file again.',
                 p_table, p_column, v_nulls;
  end if;
end;
$$;

-- Creates an index unless one already starts with the same columns.
create or replace function pg_temp.ensure_index(p_table text, p_name text, p_columns text[], p_order text default '')
returns void language plpgsql as $$
declare
  v_nums int2[];
begin
  if to_regclass(format('public.%I', p_table)) is null then
    return; -- table not in this database
  end if;
  select array_agg(a.attnum order by x.ord) into v_nums
  from unnest(p_columns) with ordinality as x(col, ord)
  join pg_attribute a on a.attrelid = format('public.%I', p_table)::regclass and a.attname = x.col;
  if v_nums is null or array_length(v_nums, 1) <> array_length(p_columns, 1) then
    return; -- a column is missing
  end if;
  if exists (
    select 1 from pg_index i
    where i.indrelid = format('public.%I', p_table)::regclass
      and (i.indkey::int2[])[0:array_length(v_nums, 1) - 1] = v_nums
  ) then
    return;
  end if;
  execute format('create index if not exists %I on public.%I (%s)', p_name, p_table,
                 coalesce(nullif(p_order, ''),
                          (select string_agg(format('%I', c), ', ') from unnest(p_columns) c)));
end;
$$;

-- ---------------------------------------------------------------------
-- 1. Data safety
-- ---------------------------------------------------------------------

-- Message: every message has a real sender; "deleted" is never empty
do $$
begin
  perform pg_temp.add_fk('Message', 'senderID', 'Message_senderID_fkey', 'User', 'userID', 'cascade');
  if pg_temp.has_column('Message', 'isDeleted') then
    update public."Message" set "isDeleted" = false where "isDeleted" is null;
    alter table public."Message" alter column "isDeleted" set default false;
    alter table public."Message" alter column "isDeleted" set not null;
  end if;
end $$;

-- Education: every entry belongs to a job seeker (like WorkExperience)
do $$ begin perform pg_temp.set_not_null('Education', 'seekerID'); end $$;

-- UserBlock: blocks are removed with the account
do $$
begin
  perform pg_temp.add_fk('UserBlock', 'blockerID', 'UserBlock_blockerID_fkey', 'User', 'userID', 'cascade');
  perform pg_temp.add_fk('UserBlock', 'blockedID', 'UserBlock_blockedID_fkey', 'User', 'userID', 'cascade');
  if to_regclass('public."UserBlock"') is not null
     and not pg_temp.has_constraint('UserBlock', 'userblock_not_self') then
    -- (created by 20261115000000 unless the table already existed)
    alter table public."UserBlock" add constraint userblock_not_self check ("blockerID" <> "blockedID") not valid;
    if not exists (select 1 from public."UserBlock" where "blockerID" = "blockedID") then
      alter table public."UserBlock" validate constraint userblock_not_self;
    end if;
  end if;
end $$;

-- Reports: always have a status and a time (like ReportedJob)
do $$
declare
  t text;
begin
  foreach t in array array['ReportedPost', 'ReportedComment'] loop
    if pg_temp.has_column(t, 'status') then
      execute format('update public.%I set status = ''pending'' where status is null', t);
      execute format('alter table public.%I alter column status set default ''pending''', t);
      perform pg_temp.set_not_null(t, 'status');
    end if;
    if pg_temp.has_column(t, 'reportedAt') then
      -- the real time is unknown for these few rows; "now" keeps them in the admin list
      execute format('update public.%I set "reportedAt" = now() where "reportedAt" is null', t);
      execute format('alter table public.%I alter column "reportedAt" set default now()', t);
      perform pg_temp.set_not_null(t, 'reportedAt');
    end if;
  end loop;
end $$;

-- ---------------------------------------------------------------------
-- 2. Unused columns
-- ---------------------------------------------------------------------
-- Never read or written by the app (CommunityPost uses "editedAt" instead).
-- No CASCADE: if a view still uses one, this stops with an error instead
-- of silently dropping the view.
alter table public."CommunityPost"       drop column if exists "updateAt";
alter table public."Message"             drop column if exists "updateAt";
alter table public."ChatRoom"            drop column if exists "jobID";
-- Written by the old mock-interview Edge Function, never shown:
-- the record's joined transcript (each answer keeps its own) and the
-- speech-to-text confidence.
alter table public."MockInterviewRecord" drop column if exists "transcriptText";
alter table public."MockInterviewAnswer" drop column if exists "confidence";

-- PostComment."updateAt": set by the database when a comment's text
-- changes, so the app can show "Edited".
create or replace function public.app_post_comment_before_update()
returns trigger
language plpgsql
as $$
begin
  if new."content" is distinct from old."content" then
    new."updateAt" := now();
  end if;
  return new;
end;
$$;

do $$
begin
  if pg_temp.has_column('PostComment', 'updateAt') then
    drop trigger if exists trg_post_comment_before_update on public."PostComment";
    create trigger trg_post_comment_before_update
      before update on public."PostComment"
      for each row execute function public.app_post_comment_before_update();
  end if;
end $$;

-- ---------------------------------------------------------------------
-- 3. Indexes (foreign keys are not indexed automatically)
-- ---------------------------------------------------------------------
do $$
begin
  perform pg_temp.ensure_index('JobApplicant',  'jobapplicant_seeker_idx',          array['seekerID']);
  perform pg_temp.ensure_index('Notification',  'notification_user_created_idx',    array['userID', 'createdAt'],
                               '"userID", "createdAt" desc');
  perform pg_temp.ensure_index('PostComment',   'postcomment_post_created_idx',     array['postID', 'createdAt']);
  perform pg_temp.ensure_index('CommunityPost', 'communitypost_author_created_idx', array['authorID', 'createdAt'],
                               '"authorID", "createdAt" desc');
  perform pg_temp.ensure_index('PostSaved',     'postsaved_user_idx',               array['userID']);
  perform pg_temp.ensure_index('ReportedPost',  'reportedpost_reporter_idx',        array['reporterID', 'postID']);
  perform pg_temp.ensure_index('Message',       'message_sender_idx',               array['senderID']);
end $$;

-- ---------------------------------------------------------------------
-- 4. ReportedComment defaults (same as every other table)
-- ---------------------------------------------------------------------
do $$
begin
  if pg_temp.has_column('ReportedComment', 'reportCommentID') then
    alter table public."ReportedComment" alter column "reportCommentID" set default gen_random_uuid();
  end if;
  if pg_temp.has_column('ReportedComment', 'reportedAt') then
    -- was timezone('utc', now()): a time without zone, read back in the
    -- server's zone; now() is the exact moment
    alter table public."ReportedComment" alter column "reportedAt" set default now();
  end if;
end $$;
