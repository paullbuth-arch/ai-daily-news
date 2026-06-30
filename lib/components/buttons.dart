import 'package:flutter/material.dart';
import '../theme/colors.dart';

/// 主按钮（实心，渐变背景）
Widget primaryBtn(String label, VoidCallback onTap, {IconData? icon}) =>
    SizedBox(
      width: double.infinity,
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(C.radiusMd),
          child: Ink(
            decoration: BoxDecoration(
              gradient: C.metricGradient,
              borderRadius: BorderRadius.circular(C.radiusMd),
              boxShadow: [
                BoxShadow(
                  color: C.primary.withOpacity(0.25),
                  blurRadius: 8,
                  offset: const Offset(0, 3),
                ),
              ],
            ),
            child: Container(
              padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 20),
              alignment: Alignment.center,
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  if (icon != null) ...[
                    Icon(icon, color: Colors.white, size: 18),
                    const SizedBox(width: 8),
                  ],
                  Text(
                    label,
                    style: const TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w700,
                      color: Colors.white,
                      letterSpacing: 0.3,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );

/// 幽灵按钮（透明背景，细边框）
Widget ghostBtn(String label, VoidCallback onTap, {IconData? icon}) =>
    SizedBox(
      width: double.infinity,
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(C.radiusMd),
          child: Ink(
            decoration: BoxDecoration(
              color: Colors.transparent,
              borderRadius: BorderRadius.circular(C.radiusMd),
              border: Border.all(color: C.line, width: 1.2),
            ),
            child: Container(
              padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 20),
              alignment: Alignment.center,
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  if (icon != null) ...[
                    Icon(icon, color: C.t2, size: 18),
                    const SizedBox(width: 8),
                  ],
                  Text(
                    label,
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w700,
                      color: C.t1,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );

/// 小型按钮（用于卡片内操作）
Widget smallBtn(String label, VoidCallback onTap, {Color? color, IconData? icon}) =>
    Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(C.radiusSm),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (icon != null) ...[
                Icon(icon, color: color ?? C.primary, size: 15),
                const SizedBox(width: 5),
              ],
              Text(
                label,
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w700,
                  color: color ?? C.primary,
                ),
              ),
            ],
          ),
        ),
      ),
    );

/// 图标按钮（圆形背景）
Widget iconBtn(IconData icon, VoidCallback onTap, {Color? color, double size = 36}) =>
    Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(size / 2),
        child: Container(
          width: size,
          height: size,
          decoration: BoxDecoration(
            color: (color ?? C.primary).withOpacity(0.08),
            borderRadius: BorderRadius.circular(size / 2),
          ),
          child: Icon(icon, color: color ?? C.primary, size: size * 0.5),
        ),
      ),
    );
