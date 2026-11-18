-- =====================================================================
-- Skill limit: a job seeker can have at most 20 skills on their profile.
-- The app checks this too (SkillController.maxSkills); this trigger stops
-- other clients, or two adds at the same moment, from going over it.
-- Existing profiles that already have more keep them; only new adds stop.
-- =====================================================================

create or replace function public.app_skill_limit()
returns trigger
language plpgsql
set search_path = public
as $$
begin
  -- One add at a time per seeker, so two quick adds can't both pass the count
  perform pg_advisory_xact_lock(hashtext('skill_limit:' || new."seekerID"::text));

  if (select count(*) from "Skill" where "seekerID" = new."seekerID") >= 20 then
    raise exception 'skill_limit: a profile can have up to 20 skills'
      using errcode = 'P0001';
  end if;
  return new;
end;
$$;

drop trigger if exists skill_limit on "Skill";
create trigger skill_limit
  before insert on "Skill"
  for each row execute function public.app_skill_limit();
