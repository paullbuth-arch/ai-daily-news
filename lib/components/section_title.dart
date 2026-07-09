import 'package:flutter/material.dart';
import '../theme/colors.dart';

class SectionTitle extends StatelessWidget {
  final String title;
  final String? trailing;
  final VoidCallback? onTap;
  final IconData? icon;

  const SectionTitle(
    this.title, {
    Key? key,
    this.trailing,
    this.onTap,
    this.icon,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) => Padding(
    padding: EdgeInsets.only(bottom: C.sp8),
    child: Row(
      children: [
        if (icon != null) ...[
          Container(
            width: 30,
            height: 30,
            decoration: BoxDecoration(
              color: C.isLight ? C.hudDark : C.bgSurface,
              borderRadius: BorderRadius.circular(C.radiusSm),
              border: Border.all(
                color: C.isLight ? C.purple.withValues(alpha: 0.30) : C.border,
              ),
              boxShadow: C.isLight ? C.glowPurple : null,
            ),
            child: Icon(
              icon,
              color: C.isLight ? C.purple : C.primary,
              size: 16,
            ),
          ),
          const SizedBox(width: 9),
        ],
        Expanded(
          child: Text(
            title,
            style: TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w900,
              color: C.t1,
            ),
          ),
        ),
        if (trailing != null)
          TextButton(
            onPressed: onTap,
            style: TextButton.styleFrom(
              foregroundColor: C.primary,
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(C.radiusSm),
              ),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  trailing!,
                  style: TextStyle(fontSize: 12, fontWeight: FontWeight.w900),
                ),
                const SizedBox(width: 2),
                Icon(Icons.chevron_right_rounded, size: 16),
              ],
            ),
          ),
      ],
    ),
  );
}
