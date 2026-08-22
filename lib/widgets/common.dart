import 'package:flutter/material.dart';
import '../theme/app_theme.dart';

/// Rounded, bordered dark card used for every "section" on every screen.
class SectionCard extends StatelessWidget {
  final Widget child;
  final EdgeInsetsGeometry padding;

  const SectionCard({
    super.key,
    required this.child,
    this.padding = const EdgeInsets.all(16),
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: padding,
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppColors.border),
      ),
      child: child,
    );
  }
}

class SectionHeading extends StatelessWidget {
  final String title;
  final Widget? trailing;

  const SectionHeading({super.key, required this.title, this.trailing});

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(
          title,
          style: const TextStyle(
            fontSize: 15,
            fontWeight: FontWeight.w600,
            color: AppColors.textPrimary,
          ),
        ),
        if (trailing != null) trailing!,
      ],
    );
  }
}

/// Small circular avatar with initials, used top-right of every app bar.
class InitialsAvatar extends StatelessWidget {
  final String initials;
  final Color color;

  const InitialsAvatar({
    super.key,
    required this.initials,
    this.color = AppColors.accent,
  });

  @override
  Widget build(BuildContext context) {
    return CircleAvatar(
      radius: 17,
      backgroundColor: color,
      child: Text(
        initials,
        style: const TextStyle(
          color: Colors.white,
          fontSize: 13,
          fontWeight: FontWeight.w700,
        ),
      ),
    );
  }
}

/// Shared AppBar builder so every screen has the same icon + title +
/// notification bell + avatar layout seen in the wireframes.
PreferredSizeWidget buildCsdoAppBar({
  required IconData leadingIcon,
  required String title,
  bool showNotification = true,
}) {
  return AppBar(
    leadingWidth: 46,
    leading: Padding(
      padding: const EdgeInsets.only(left: 16),
      child: Icon(leadingIcon, color: AppColors.accent, size: 22),
    ),
    title: Text(title),
    actions: [
      if (showNotification)
        const Padding(
          padding: EdgeInsets.only(right: 8),
          child: Icon(Icons.notifications_none,
              color: AppColors.textSecondary),
        ),
      const Padding(
        padding: EdgeInsets.only(right: 16),
        child: InitialsAvatar(initials: 'AD'),
      ),
    ],
  );
}

class InfoBullet extends StatelessWidget {
  final String text;

  const InfoBullet({super.key, required this.text});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Padding(
            padding: EdgeInsets.only(top: 2),
            child: Icon(Icons.info_outline, size: 16, color: AppColors.blue),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              text,
              style: const TextStyle(
                color: AppColors.textSecondary,
                fontSize: 13,
                height: 1.4,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
