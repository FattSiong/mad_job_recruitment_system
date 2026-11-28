-- =====================================================================
-- Report tables: the key is called "reportID" in all of them
--   ReportedPost."reportPostID"       -> "reportID"
--   ReportedComment."reportCommentID" -> "reportID"
-- ReportedJob (20261127000000) and PostInterviewReport already use it.
-- Values, defaults, keys and indexes stay as they are.
--
-- DEPLOY TOGETHER with the updated app (Admin > Community sorts the
-- reports by this column). Safe to run again.
-- =====================================================================

do $$
begin
  if exists (select 1 from information_schema.columns
             where table_schema = 'public' and table_name = 'ReportedPost' and column_name = 'reportPostID')
     and not exists (select 1 from information_schema.columns
             where table_schema = 'public' and table_name = 'ReportedPost' and column_name = 'reportID') then
    alter table public."ReportedPost" rename column "reportPostID" to "reportID";
  end if;

  if exists (select 1 from information_schema.columns
             where table_schema = 'public' and table_name = 'ReportedComment' and column_name = 'reportCommentID')
     and not exists (select 1 from information_schema.columns
             where table_schema = 'public' and table_name = 'ReportedComment' and column_name = 'reportID') then
    alter table public."ReportedComment" rename column "reportCommentID" to "reportID";
  end if;
end $$;
