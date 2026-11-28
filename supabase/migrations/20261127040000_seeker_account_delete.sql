-- =====================================================================
-- Deleting a job seeker's account deletes all of their data
-- Run AFTER 20261127030000_job_seeker_indexes.sql
--
-- Before: deleting a job seeker in Authentication > Users failed
-- ("Database error deleting user"), because their profile, applications,
-- posts, chats ... still pointed at the account.
--
-- Now, when a job seeker's login (auth.users) is deleted:
--   auth.users -> "User" -> "JobSeeker" -> everything of the seeker
--   1. Their notifications, phones (push), calls and login lockouts go.
--   2. Their "User" row is deleted, which removes (on delete cascade):
--      the JobSeeker profile, Education, WorkExperience, Skill, bookmarks,
--      resume, Career Buddy chats, mock interviews, skill gap analyses,
--      resume reviews, job reports, Community Hub posts / comments /
--      likes / saves / reports, chat rooms and messages, blocks.
--   3. Deleting the JobSeeker row first removes their job applications
--      and what hangs off them: pre-screening answers, interview
--      schedules, interview rooms, post-interview reports and the
--      notifications about them (also the employer's). Those are the
--      employer side's tables: only rows of this seeker are deleted and
--      the tables themselves are not changed.
-- Employer and admin accounts are not affected by the account trigger.
-- Files in Storage (resume, photo, attachments) are not deleted by SQL.
-- Safe to run again.
-- =====================================================================

create or replace function pg_temp.has_column(p_table text, p_column text)
returns boolean language sql stable as $$
  select exists (select 1 from information_schema.columns
                 where table_schema = 'public' and table_name = p_table and column_name = p_column);
$$;

-- Makes p_table.p_column -> p_ref_table.p_ref_column one foreign key with
-- ON DELETE CASCADE (replacing the old one, whose name is kept). If old
-- rows point to a missing row it is added NOT VALID and they are counted.
create or replace function pg_temp.cascade_fk(
  p_table text, p_column text, p_ref_table text, p_ref_column text, p_name text)
returns void language plpgsql as $$
declare
  c record;
  v_name text;
  v_bad bigint;
begin
  if to_regclass(format('public.%I', p_table)) is null
     or to_regclass(format('public.%I', p_ref_table)) is null
     or not pg_temp.has_column(p_table, p_column) then
    raise notice 'Skipped %.% -> %: table or column not found', p_table, p_column, p_ref_table;
    return;
  end if;

  -- Already the only foreign key there, with cascade
  if (select count(*) = 1 and bool_and(con.confdeltype = 'c')
      from pg_constraint con
      join pg_attribute a on a.attrelid = con.conrelid and a.attnum = con.conkey[1]
      where con.conrelid = format('public.%I', p_table)::regclass and con.contype = 'f'
        and array_length(con.conkey, 1) = 1 and a.attname = p_column
        and con.confrelid = format('public.%I', p_ref_table)::regclass) then
    return;
  end if;

  for c in
    select con.conname
    from pg_constraint con
    join pg_attribute a on a.attrelid = con.conrelid and a.attnum = con.conkey[1]
    where con.conrelid = format('public.%I', p_table)::regclass and con.contype = 'f'
      and array_length(con.conkey, 1) = 1 and a.attname = p_column
      and con.confrelid = format('public.%I', p_ref_table)::regclass
    order by con.conname
  loop
    v_name := coalesce(v_name, c.conname);
    execute format('alter table public.%I drop constraint %I', p_table, c.conname);
  end loop;
  v_name := coalesce(v_name, p_name);

  execute format(
    'select count(*) from public.%I t where t.%I is not null
       and not exists (select 1 from public.%I r where r.%I = t.%I)',
    p_table, p_column, p_ref_table, p_ref_column, p_column) into v_bad;

  execute format('alter table public.%I add constraint %I foreign key (%I) references public.%I (%I) on delete cascade %s',
                 p_table, v_name, p_column, p_ref_table, p_ref_column,
                 case when v_bad > 0 then 'not valid' else '' end);
  if v_bad > 0 then
    raise notice '%.%: % row(s) point to a missing % row (checked for new rows only).',
                 p_table, p_column, v_bad, p_ref_table;
  end if;
end;
$$;

-- ---------------------------------------------------------------------
-- 1. Foreign keys of the job seeker module: removed with their owner
-- ---------------------------------------------------------------------
do $$
begin
  -- Profile
  perform pg_temp.cascade_fk('JobSeeker',      'seekerID', 'User',      'userID',   'JobSeeker_seekerID_fkey');
  perform pg_temp.cascade_fk('Education',      'seekerID', 'JobSeeker', 'seekerID', 'Education_seekerID_fkey');
  perform pg_temp.cascade_fk('WorkExperience', 'seekerID', 'JobSeeker', 'seekerID', 'WorkExperience_seekerID_fkey');
  perform pg_temp.cascade_fk('Skill',          'seekerID', 'JobSeeker', 'seekerID', 'Skill_seekerID_fkey');
  perform pg_temp.cascade_fk('BookmarkedJob',  'seekerID', 'JobSeeker', 'seekerID', 'BookmarkedJob_seekerID_fkey');
  perform pg_temp.cascade_fk('Resume',         'seekerID', 'JobSeeker', 'seekerID', 'Resume_seekerID_fkey');
  perform pg_temp.cascade_fk('ReportedJob',    'reporterID', 'JobSeeker', 'seekerID', 'ReportedJob_reporterID_fkey');

  -- Career tools
  perform pg_temp.cascade_fk('AdvisorConversation',  'seekerID',       'JobSeeker',            'seekerID',       'AdvisorConversation_seekerID_fkey');
  perform pg_temp.cascade_fk('AdvisorMessage',       'seekerID',       'JobSeeker',            'seekerID',       'AdvisorMessage_seekerID_fkey');
  perform pg_temp.cascade_fk('AdvisorMessage',       'conversationID', 'AdvisorConversation',  'conversationID', 'AdvisorMessage_conversationID_fkey');
  perform pg_temp.cascade_fk('MockInterviewSession', 'seekerID',       'JobSeeker',            'seekerID',       'MockInterviewSession_seekerID_fkey');
  perform pg_temp.cascade_fk('MockInterviewAnswer',  'sessionID',      'MockInterviewSession', 'sessionID',      'MockInterviewAnswer_sessionID_fkey');
  perform pg_temp.cascade_fk('SkillGapAnalysis',     'seekerID',       'JobSeeker',            'seekerID',       'SkillGapAnalysis_seekerID_fkey');
  perform pg_temp.cascade_fk('ResumeReview',         'seekerID',       'JobSeeker',            'seekerID',       'ResumeReview_seekerID_fkey');

  -- Community Hub (a removed post takes its comments, likes, saves and reports)
  perform pg_temp.cascade_fk('CommunityPost',   'authorID',        'User',          'userID',    'CommunityPost_authorID_fkey');
  perform pg_temp.cascade_fk('PostComment',     'userID',          'User',          'userID',    'PostComment_userID_fkey');
  perform pg_temp.cascade_fk('PostComment',     'postID',          'CommunityPost', 'postID',    'PostComment_postID_fkey');
  perform pg_temp.cascade_fk('PostComment',     'parentCommentID', 'PostComment',   'commentID', 'PostComment_parentCommentID_fkey');
  perform pg_temp.cascade_fk('PostLike',        'userID',          'User',          'userID',    'PostLike_userID_fkey');
  perform pg_temp.cascade_fk('PostLike',        'postID',          'CommunityPost', 'postID',    'PostLike_postID_fkey');
  perform pg_temp.cascade_fk('PostSaved',       'userID',          'User',          'userID',    'PostSaved_userID_fkey');
  perform pg_temp.cascade_fk('PostSaved',       'postID',          'CommunityPost', 'postID',    'PostSaved_postID_fkey');
  perform pg_temp.cascade_fk('ReportedPost',    'postID',          'CommunityPost', 'postID',    'ReportedPost_postID_fkey');
  perform pg_temp.cascade_fk('ReportedPost',    'reporterID',      'User',          'userID',    'ReportedPost_reporterID_fkey');
  perform pg_temp.cascade_fk('ReportedComment', 'commentID',       'PostComment',   'commentID', 'ReportedComment_commentID_fkey');
  perform pg_temp.cascade_fk('ReportedComment', 'reporterID',      'User',          'userID',    'ReportedComment_reporterID_fkey');

  -- Chat
  perform pg_temp.cascade_fk('ChatRoom',  'user1_ID',  'User',     'userID', 'ChatRoom_user1_ID_fkey');
  perform pg_temp.cascade_fk('ChatRoom',  'user2_ID',  'User',     'userID', 'ChatRoom_user2_ID_fkey');
  perform pg_temp.cascade_fk('Message',   'roomID',    'ChatRoom', 'roomID', 'Message_roomID_fkey');
  perform pg_temp.cascade_fk('Message',   'senderID',  'User',     'userID', 'Message_senderID_fkey');
  perform pg_temp.cascade_fk('UserBlock', 'blockerID', 'User',     'userID', 'UserBlock_blockerID_fkey');
  perform pg_temp.cascade_fk('UserBlock', 'blockedID', 'User',     'userID', 'UserBlock_blockedID_fkey');
end $$;

-- ---------------------------------------------------------------------
-- 2. Before a JobSeeker row is deleted: their applications and what
--    hangs off them (rows in the employer side's tables)
-- ---------------------------------------------------------------------
create or replace function public.app_before_job_seeker_delete()
returns trigger
language plpgsql
security definer
set search_path = public
as $$
declare
  v_apps uuid[];
  v_schedules uuid[];
  v_rooms uuid[];
begin
  select coalesce(array_agg("applicantID"), '{}') into v_apps
  from "JobApplicant" where "seekerID" = old."seekerID";

  select coalesce(array_agg("scheduleID"), '{}') into v_schedules
  from "InterviewSchedule" where "applicantID" = any (v_apps);

  select coalesce(array_agg("roomID"), '{}') into v_rooms
  from "InterviewRoom"
  where "scheduleID" = any (v_schedules) or "seekerID" = old."seekerID";

  delete from "PostInterviewReport"
  where "applicantID" = any (v_apps) or "scheduleID" = any (v_schedules) or "roomID" = any (v_rooms);

  delete from "Notification"
  where "applicantID" = any (v_apps) or "scheduleID" = any (v_schedules);

  delete from "InterviewRoom"     where "roomID" = any (v_rooms);
  delete from "InterviewSchedule" where "scheduleID" = any (v_schedules);
  delete from "ApplicationAnswer" where "applicantID" = any (v_apps);
  delete from "JobApplicant"      where "applicantID" = any (v_apps);

  return old;
end;
$$;

revoke all on function public.app_before_job_seeker_delete() from public, anon, authenticated;

drop trigger if exists trg_before_job_seeker_delete on public."JobSeeker";
create trigger trg_before_job_seeker_delete
  before delete on public."JobSeeker"
  for each row execute function public.app_before_job_seeker_delete();

-- ---------------------------------------------------------------------
-- 3. Before a job seeker's login is deleted: their rows, then "User"
--    (which removes the rest through the foreign keys above)
-- ---------------------------------------------------------------------
create or replace function public.app_before_auth_user_delete()
returns trigger
language plpgsql
security definer
set search_path = public
as $$
begin
  -- Job seekers only. Also a sign-up that stopped before the JobSeeker
  -- row was made ("User" says job_seeker, no employer / admin row).
  if not exists (select 1 from "JobSeeker" where "seekerID" = old.id)
     and not (
       exists (select 1 from "User" where "userID" = old.id and lower("role") = 'job_seeker')
       and not exists (select 1 from "Employer" where "employerID" = old.id)
       and not exists (select 1 from "Admin" where "adminID" = old.id)
     ) then
    return old;
  end if;

  delete from "Notification" where "userID" = old.id;
  delete from "UserDevice"   where "userID" = old.id;
  delete from "Calls"        where "callerID" = old.id or "receiverID" = old.id;
  if old.email is not null then
    delete from "LoginAttempt" where lower("email") = lower(old.email);
  end if;

  delete from "User" where "userID" = old.id;
  return old;
end;
$$;

revoke all on function public.app_before_auth_user_delete() from public, anon, authenticated;

drop trigger if exists trg_before_auth_user_delete on auth.users;
create trigger trg_before_auth_user_delete
  before delete on auth.users
  for each row execute function public.app_before_auth_user_delete();
