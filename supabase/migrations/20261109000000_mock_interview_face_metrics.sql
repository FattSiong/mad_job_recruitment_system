-- =====================================================================
-- Mock Interview: body language cues from the camera (optional)
-- Run AFTER 20261030120000_mock_interview_metrics.sql
--
-- The app estimates these on the phone with Google ML Kit face detection
-- while the user answers with the camera on. Video never leaves the phone:
-- only these numbers are sent with the answer.
-- They are feedback only and are NOT part of contentScore / deliveryScore /
-- overallScore. All columns stay null when the camera was off.
-- =====================================================================

-- Answer level
alter table "MockInterviewAnswer"
  add column if not exists "eyeContactPercent"  int
    constraint mock_answer_eye_contact_range  check ("eyeContactPercent"  between 0 and 100),
  add column if not exists "smilePercent"       int
    constraint mock_answer_smile_range        check ("smilePercent"       between 0 and 100),
  add column if not exists "facePresentPercent" int
    constraint mock_answer_face_present_range check ("facePresentPercent" between 0 and 100),
  add column if not exists "lookAwayCount"      int
    constraint mock_answer_look_away_min      check ("lookAwayCount" >= 0);

comment on column "MockInterviewAnswer"."eyeContactPercent"  is 'Share of camera samples (face visible) where the head faced the camera, 0-100. Null = camera off';
comment on column "MockInterviewAnswer"."smilePercent"       is 'Share of camera samples (face visible) with ML Kit smilingProbability > 0.5, 0-100';
comment on column "MockInterviewAnswer"."facePresentPercent" is 'Share of camera samples where a face was in the frame, 0-100';
comment on column "MockInterviewAnswer"."lookAwayCount"      is 'Times the user looked away or left the frame for 1s or longer';

-- Session level (averages of the answers that had the camera on)
alter table "MockInterviewRecord"
  add column if not exists "eyeContactPercent" int
    constraint mock_record_eye_contact_range check ("eyeContactPercent" between 0 and 100),
  add column if not exists "smilePercent"      int
    constraint mock_record_smile_range       check ("smilePercent"      between 0 and 100);

comment on column "MockInterviewRecord"."eyeContactPercent" is 'Average eyeContactPercent of answers with the camera on. Feedback only, not in overallScore';
comment on column "MockInterviewRecord"."smilePercent"      is 'Average smilePercent of answers with the camera on. Feedback only, not in overallScore';
