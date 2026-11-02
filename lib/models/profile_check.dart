/// Things the profile checklist looks for, in the order they are shown.
enum ProfileCheck {
  photo('Profile photo'),
  phone('Phone number'),
  location('Location'),
  bio('Bio'),
  careerGoal('Career goal'),
  resume('Resume'),
  experience('Work experience'),
  education('Education'),
  skills('Skills');

  const ProfileCheck(this.label);
  final String label;
}
