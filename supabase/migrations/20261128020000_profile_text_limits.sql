-- =====================================================================
-- Length limits for the job seeker's profile text and job reports
--
-- These had no limit, so any API call could save pages of text, which
-- employers' screens and the AI tools (they read the profile) then load.
-- The app now stops longer text in the form; the database limits are
-- twice the app's (the app and the database count emoji differently):
--
--                                    app    database
--   Education  institutionName        100     200
--              degree (a list)          -     200
--              fieldOfStudy           100     200
--              description           1000    2000
--   WorkExperience companyName        100     200
--              jobTitle               100     200
--              description           1000    2000
--   JobSeeker  location               100     200
--   Skill      skillName               50     100
--   ReportedJob additionalDetails     500    1000
--
-- Old rows: if some are already longer, that rule is not added and a
-- NOTICE shows how to find them; shorten them and run this file again.
-- Safe to run again.
-- =====================================================================

create or replace function pg_temp.add_check(p_table text, p_name text, p_expr text)
returns boolean language plpgsql as $$
declare
  v_bad bigint;
begin
  if to_regclass(format('public.%I', p_table)) is null then
    return false;
  end if;
  execute format('alter table public.%I drop constraint if exists %I', p_table, p_name);
  execute format('select count(*) from public.%I where not coalesce((%s), true)', p_table, p_expr)
    into v_bad;
  if v_bad > 0 then
    raise notice '% rule "%" not added: % row(s) break it. Find them with: select * from public."%" where not (%);',
      p_table, p_name, v_bad, p_table, p_expr;
    return false;
  end if;
  execute format('alter table public.%I add constraint %I check (%s)', p_table, p_name, p_expr);
  return true;
end;
$$;

do $$
begin
  perform pg_temp.add_check('Education', 'education_text_length',
    'char_length("institutionName") <= 200 and char_length("degree") <= 200 '
    'and char_length("fieldOfStudy") <= 200 and char_length("description") <= 2000');
  perform pg_temp.add_check('WorkExperience', 'work_experience_text_length',
    'char_length("companyName") <= 200 and char_length("jobTitle") <= 200 '
    'and char_length("description") <= 2000');
  perform pg_temp.add_check('JobSeeker', 'job_seeker_location_length',
    'char_length("location") <= 200');
  perform pg_temp.add_check('Skill', 'skill_name_length',
    'btrim("skillName") <> '''' and char_length("skillName") <= 100');
  perform pg_temp.add_check('ReportedJob', 'reported_job_details_length',
    'char_length("additionalDetails") <= 1000');
end $$;
