import 'package:flutter/material.dart';
import '../theme/colors.dart';

Widget primaryBtn(
  String label,
  VoidCallback onTap, {
  IconData? icon,
}) => SizedBox(
  width: double.infinity,
  child: FilledButton(
    onPressed: onTap,
    style: FilledButton.styleFrom(
      backgroundColor: C.primary,
      foregroundColor: Colors.black,
      minimumSize: const Size.fromHeight(48),
      padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 16),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(C.radiusMd),
      ),
      textStyle: TextStyle(fontSize: 14, fontWeight: FontWeight.w900),
    ),
    child: Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        if (icon != null) ...[Icon(icon, size: 18), const SizedBox(width: 8)],
        Flexible(child: Text(label, overflow: TextOverflow.ellipsis)),
      ],
    ),
  ),
);

Widget ghostBtn(String label, VoidCallback onTap, {IconData? icon}) => SizedBox(
  width: double.infinity,
  child: OutlinedButton(
    onPressed: onTap,
    style: OutlinedButton.styleFrom(
      foregroundColor: C.t1,
      side: BorderSide(color: C.border),
      minimumSize: const Size.fromHeight(48),
      padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 16),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(C.radiusMd),
      ),
      backgroundColor: C.bgSurface,
      textStyle: TextStyle(fontSize: 14, fontWeight: FontWeight.w800),
    ),
    child: Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        if (icon != null) ...[
          Icon(icon, size: 18, color: C.t2),
          const SizedBox(width: 8),
        ],
        Flexible(child: Text(label, overflow: TextOverflow.ellipsis)),
      ],
    ),
  ),
);

Widget smallBtn(
  String label,
  VoidCallback onTap, {
  Color? color,
  IconData? icon,
}) => TextButton(
  onPressed: onTap,
  style: TextButton.styleFrom(
    foregroundColor: color ?? C.primary,
    minimumSize: const Size(44, 36),
    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
    shape: RoundedRectangleBorder(
      borderRadius: BorderRadius.circular(C.radiusSm),
    ),
    backgroundColor: (color ?? C.primary).withValues(alpha: 0.12),
    textStyle: TextStyle(fontSize: 12, fontWeight: FontWeight.w900),
  ),
  child: Row(
    mainAxisSize: MainAxisSize.min,
    children: [
      if (icon != null) ...[Icon(icon, size: 15), const SizedBox(width: 5)],
      Flexible(child: Text(label, overflow: TextOverflow.ellipsis)),
    ],
  ),
);

Widget iconBtn(
  IconData icon,
  VoidCallback onTap, {
  Color? color,
  double size = 40,
}) => SizedBox(
  width: size,
  height: size,
  child: Material(
    color: (color ?? C.primary).withValues(alpha: 0.12),
    shape: RoundedRectangleBorder(
      borderRadius: BorderRadius.circular(C.radiusMd),
      side: BorderSide(color: (color ?? C.primary).withValues(alpha: 0.20)),
    ),
    clipBehavior: Clip.antiAlias,
    child: InkWell(
      onTap: onTap,
      child: Icon(icon, color: color ?? C.primary, size: size * 0.48),
    ),
  ),
);
