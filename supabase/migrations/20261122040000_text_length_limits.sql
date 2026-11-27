-- =====================================================================
-- Length limits for chat messages, posts and comments in the database
--
-- The app limits messages to 4,000, posts to 2,000 and comments to 1,000
-- characters, but only on the phone: anyone calling the API could store
-- megabytes of text that every phone then downloads.
--
-- These checks are a safety net, set at twice the app's limits. The app
-- counts characters the way the text box does (an emoji is one), while
-- the database counts code points (some emoji are several), and a reply
-- also gets "@Name " added in front.
--
-- NOT VALID: existing rows aren't checked, only new and edited ones.
-- =====================================================================

alter table public."Message" drop constraint if exists message_content_length;
alter table public."Message"
  add constraint message_content_length
  check (char_length(coalesce("content", '')) <= 8000) not valid;

alter table public."CommunityPost" drop constraint if exists community_post_content_length;
alter table public."CommunityPost"
  add constraint community_post_content_length
  check (char_length(coalesce("content", '')) <= 4000) not valid;

alter table public."PostComment" drop constraint if exists post_comment_content_length;
alter table public."PostComment"
  add constraint post_comment_content_length
  check (char_length(coalesce("content", '')) <= 2000) not valid;
