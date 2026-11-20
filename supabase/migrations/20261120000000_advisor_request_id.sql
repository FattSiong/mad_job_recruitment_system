-- =====================================================================
-- Career Buddy: one request ID per question
--
-- The app gives every question a random ID and sends it with the question.
-- If the app stops waiting (timeout, lost connection) after the server has
-- already saved the answer, sending the same question again returns the
-- saved answer instead of asking the AI again and saving it twice.
-- The unique index also stops two attempts that run at the same time from
-- both being saved.
-- =====================================================================

alter table "AdvisorMessage" add column if not exists "requestID" uuid;

create unique index if not exists advisor_message_request_uq
  on "AdvisorMessage" ("seekerID", "requestID")
  where "requestID" is not null;
