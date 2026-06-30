import 'package:flutter/material.dart';
import '../theme/colors.dart';

/// 段落标题（带可选右侧操作链接）
class SectionTitle extends StatelessWidget {
  final String title;
  final String? trailing;
  final VoidCallback? onTap;
  final IconData? icon;

  const SectionTitle(this.title, {Key? key, this.trailing, this.onTap, this.icon})
    : super(key: key);

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.symmetric(horizontal: C.sp16, vertical: C.sp8),
    child: Row(
      children: [
        if (icon != null) ...[
          Container(
            width: 24,
            height: 24,
            decoration: BoxDecoration(
              color: C.primary.withOpacity(0.1),
              borderRadius: BorderRadius.circular(6),
            ),
            child: Icon(icon, color: C.primary, size: 14),
          ),
          const SizedBox(width: 8),
        ],
        Text(
          title,
          style: TextStyle(
            fontSize: 15,
            fontWeight: FontWeight.w800,
            color: C.t1,
            letterSpacing: 0.2,
          ),
        ),
        const Spacer(),
        if (trailing != null)
          InkWell(
            onTap: onTap,
            borderRadius: BorderRadius.circular(C.radiusSm),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    trailing!,
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                      color: C.primary,
                    ),
                  ),
                  const SizedBox(width: 2),
                  Icon(Icons.chevron_right, color: C.primary, size: 16),
                ],
              ),
            ),
          ),
      ],
    ),
  );
}
