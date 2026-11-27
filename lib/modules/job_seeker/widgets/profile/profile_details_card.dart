import 'package:flutter/material.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../../core/utils/link_helper.dart';
import '../../../../models/job_seeker_model.dart';
import '../../../../shared_widgets/surface_card.dart';
import '../../controllers/my_profile_controller.dart';

/// The text boxes of the profile form. Owned by the screen (dispose them).
class ProfileFormFields {
  final name = TextEditingController();
  final email = TextEditingController();
  final phone = TextEditingController();
  final location = TextEditingController();
  final bio = TextEditingController();
  final careerGoal = TextEditingController();
  final linkedIn = TextEditingController();
  final gitHub = TextEditingController();

  /// Shows the saved profile (also used to throw away edits).
  void fill(JobSeekerModel profile) {
    name.text = profile.fullName;
    email.text = profile.email ?? '';
    phone.text = profile.phoneNumber ?? '';
    location.text = profile.location ?? '';
    bio.text = profile.bio ?? '';
    careerGoal.text = profile.careerGoal ?? '';
    linkedIn.text = profile.linkedInURL ?? '';
    gitHub.text = profile.gitHubURL ?? '';
  }

  /// What is typed in the form.
  ProfileEdits toEdits() {
    return ProfileEdits(
      fullName: name.text,
      phone: phone.text,
      location: location.text,
      bio: bio.text,
      careerGoal: careerGoal.text,
      linkedIn: linkedIn.text,
      gitHub: gitHub.text,
    );
  }

  void dispose() {
    for (final c in [name, email, phone, location, bio, careerGoal, linkedIn, gitHub]) {
      c.dispose();
    }
  }
}

/// Name, contact details, bio, career goal and links. Read-only rows in
/// view mode, a validated form in edit mode.
class ProfileDetailsCard extends StatelessWidget {
  final GlobalKey<FormState> formKey;
  final ProfileFormFields fields;
  final bool isEditing;

  /// Opens a LinkedIn / GitHub link (view mode).
  final ValueChanged<String> onOpenLink;

  const ProfileDetailsCard({
    super.key,
    required this.formKey,
    required this.fields,
    required this.isEditing,
    required this.onOpenLink,
  });

  static const _iconColor = AppColors.textMuted;

  @override
  Widget build(BuildContext context) {
    Widget field({
      required String label,
      required TextEditingController controller,
      required Widget icon,
      int maxLines = 1,
      bool readOnly = false,
      bool isLink = false,
      String? Function(String?)? validator,
    }) {
      return _ProfileField(
        isEditing: isEditing,
        label: label,
        controller: controller,
        icon: icon,
        maxLines: maxLines,
        readOnly: readOnly,
        validator: validator,
        onOpenLink: isLink ? onOpenLink : null,
      );
    }

    return SurfaceCard(
      child: Form(
        key: formKey,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (isEditing)
              field(
                label: 'Full Name',
                controller: fields.name,
                icon: const Icon(Icons.person_outline_rounded, color: _iconColor, size: 20),
                validator: (value) {
                  final name = value?.trim() ?? '';
                  if (name.isEmpty) return 'Name cannot be empty';
                  return name.length > 100 ? 'Keep your name under 100 characters' : null;
                },
              )
            else ...[
              Text(
                fields.name.text,
                style: const TextStyle(
                  fontSize: 26,
                  fontWeight: FontWeight.bold,
                  color: AppColors.textDark,
                ),
              ),
              const SizedBox(height: 20),
            ],
            field(
              label: 'Email',
              controller: fields.email,
              icon: const Icon(Icons.email_outlined, color: _iconColor, size: 20),
              readOnly: true,
            ),
            field(
              label: 'Phone Number',
              controller: fields.phone,
              icon: const Icon(Icons.phone_outlined, color: _iconColor, size: 20),
              validator: (value) {
                final text = value?.trim() ?? '';
                if (text.isEmpty) return null;
                return RegExp(r'^[0-9+\-\s]{8,20}$').hasMatch(text)
                    ? null
                    : 'Enter a valid phone number';
              },
            ),
            field(
              label: 'Location',
              controller: fields.location,
              icon: const Icon(Icons.location_on_outlined, color: _iconColor, size: 20),
            ),
            field(
              label: 'Bio / About Me',
              controller: fields.bio,
              icon: const Icon(Icons.menu_book_outlined, color: _iconColor, size: 20),
              maxLines: 4,
              // The AI tools read up to about 600 characters of the bio
              validator: (value) => (value?.trim().length ?? 0) > 600
                  ? 'Keep your bio under 600 characters'
                  : null,
            ),
            field(
              label: 'Career Goal',
              controller: fields.careerGoal,
              icon: const Icon(Icons.flag_outlined, color: _iconColor, size: 20),
              maxLines: 3,
              validator: (value) => (value?.trim().length ?? 0) > 300
                  ? 'Keep your career goal under 300 characters'
                  : null,
            ),
            field(
              label: 'LinkedIn URL',
              controller: fields.linkedIn,
              icon: const FaIcon(FontAwesomeIcons.linkedin, color: _iconColor, size: 18),
              isLink: true,
              validator: (value) =>
                  LinkHelper.validateSiteLink(value, site: 'linkedin.com', name: 'LinkedIn'),
            ),
            field(
              label: 'GitHub URL',
              controller: fields.gitHub,
              icon: const FaIcon(FontAwesomeIcons.github, color: _iconColor, size: 18),
              isLink: true,
              validator: (value) =>
                  LinkHelper.validateSiteLink(value, site: 'github.com', name: 'GitHub'),
            ),
          ],
        ),
      ),
    );
  }
}

/// One row: label and value in view mode, a text box in edit mode.
class _ProfileField extends StatelessWidget {
  final bool isEditing;
  final String label;
  final TextEditingController controller;
  final Widget icon;
  final int maxLines;
  final bool readOnly;
  final String? Function(String?)? validator;

  /// Set for links: the value is tappable in view mode.
  final ValueChanged<String>? onOpenLink;

  const _ProfileField({
    required this.isEditing,
    required this.label,
    required this.controller,
    required this.icon,
    required this.maxLines,
    required this.readOnly,
    required this.validator,
    required this.onOpenLink,
  });

  @override
  Widget build(BuildContext context) {
    if (!isEditing) {
      final value = controller.text.trim();
      return ProfileInfoRow(
        label: label,
        value: value.isEmpty ? '-' : controller.text,
        icon: icon,
        onTap: onOpenLink != null && value.isNotEmpty ? () => onOpenLink!(value) : null,
      );
    }

    final border = OutlineInputBorder(
      borderRadius: BorderRadius.circular(16),
      borderSide: const BorderSide(color: AppColors.border),
    );
    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: TextFormField(
        controller: controller,
        maxLines: maxLines,
        readOnly: readOnly,
        validator: validator,
        keyboardType: onOpenLink != null ? TextInputType.url : null,
        style: TextStyle(color: readOnly ? AppColors.textMuted : AppColors.textDark),
        decoration: InputDecoration(
          labelText: label,
          prefixIcon: Padding(padding: const EdgeInsets.all(12), child: icon),
          filled: true,
          fillColor: readOnly ? AppColors.border : AppColors.surfaceAlt,
          border: border,
          enabledBorder: border,
          focusedBorder: border.copyWith(
            borderSide: const BorderSide(color: AppColors.primary, width: 1.6),
          ),
        ),
      ),
    );
  }
}

/// Icon, label and value of a profile detail (view mode). With [onTap]
/// the value is shown as a link.
class ProfileInfoRow extends StatelessWidget {
  final String label;
  final String value;
  final Widget icon;
  final VoidCallback? onTap;

  const ProfileInfoRow({super.key, required this.label, required this.value, required this.icon, this.onTap});

  @override
  Widget build(BuildContext context) {
    final isLink = onTap != null;
    return Padding(
      padding: const EdgeInsets.only(bottom: 20),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 42,
            height: 42,
            decoration: BoxDecoration(
              color: AppColors.surfaceAlt,
              borderRadius: BorderRadius.circular(14),
            ),
            child: Center(child: icon),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label,
                  style: const TextStyle(fontSize: 13, color: AppColors.textMuted, fontWeight: FontWeight.w700),
                ),
                const SizedBox(height: 6),
                InkWell(
                  onTap: onTap,
                  borderRadius: BorderRadius.circular(8),
                  child: Text(
                    value,
                    style: TextStyle(
                      fontSize: 15,
                      height: 1.45,
                      color: isLink ? AppColors.primary : AppColors.textDark,
                      fontWeight: isLink ? FontWeight.w600 : FontWeight.w500,
                      decoration: isLink ? TextDecoration.underline : TextDecoration.none,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
