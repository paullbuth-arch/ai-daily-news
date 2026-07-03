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
      backgroundColor: C.cyan,
      foregroundColor: Colors.black,
      padding: const EdgeInsets.symmetric(vertical: 15, horizontal: 18),
      shape: const StadiumBorder(),
      textStyle: const TextStyle(fontSize: 14, fontWeight: FontWeight.w900),
    ),
    child: Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        if (icon != null) ...[Icon(icon, size: 18), const SizedBox(width: 8)],
        Text(label),
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
      side: BorderSide(color: Colors.white.withValues(alpha: 0.12)),
      padding: const EdgeInsets.symmetric(vertical: 15, horizontal: 18),
      shape: const StadiumBorder(),
      backgroundColor: Colors.white.withValues(alpha: 0.05),
      textStyle: const TextStyle(fontSize: 14, fontWeight: FontWeight.w800),
    ),
    child: Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        if (icon != null) ...[
          Icon(icon, size: 18, color: C.t2),
          const SizedBox(width: 8),
        ],
        Text(label),
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
    foregroundColor: color ?? C.cyan,
    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
    shape: const StadiumBorder(),
    backgroundColor: (color ?? C.cyan).withValues(alpha: 0.10),
    textStyle: const TextStyle(fontSize: 12, fontWeight: FontWeight.w900),
  ),
  child: Row(
    mainAxisSize: MainAxisSize.min,
    children: [
      if (icon != null) ...[Icon(icon, size: 15), const SizedBox(width: 5)],
      Text(label),
    ],
  ),
);

Widget iconBtn(
  IconData icon,
  VoidCallback onTap, {
  Color? color,
  double size = 38,
}) => Material(
  color: Colors.transparent,
  child: InkWell(
    onTap: onTap,
    borderRadius: BorderRadius.circular(size / 2),
    child: Ink(
      width: size,
      height: size,
      decoration: BoxDecoration(
        color: (color ?? C.cyan).withValues(alpha: 0.12),
        shape: BoxShape.circle,
        border: Border.all(color: Colors.white.withValues(alpha: 0.09)),
      ),
      child: Icon(icon, color: color ?? C.cyan, size: size * 0.48),
    ),
  ),
);
