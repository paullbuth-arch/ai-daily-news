import 'package:flutter/material.dart';
import '../theme/colors.dart';

/// 状态标签（药丸形状）
class StatusChip extends StatelessWidget {
  final String text;
  final Color color;
  final bool outline;

  const StatusChip(this.text, this.color, {Key? key, this.outline = false})
    : super(key: key);

  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
    decoration: BoxDecoration(
      color: outline ? Colors.transparent : color.withOpacity(0.1),
      borderRadius: BorderRadius.circular(20),
      border: outline
          ? Border.all(color: color.withOpacity(0.3), width: 1)
          : null,
    ),
    child: Text(
      text,
      style: TextStyle(
        fontSize: 11,
        color: color,
        fontWeight: FontWeight.w700,
        letterSpacing: 0.2,
      ),
    ),
  );
}

/// 趋势标签（带箭头图标）
class TrendChip extends StatelessWidget {
  final bool positive;
  final String text;

  const TrendChip({Key? key, required this.positive, required this.text})
    : super(key: key);

  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
    decoration: BoxDecoration(
      color: (positive ? C.green : C.red).withOpacity(0.1),
      borderRadius: BorderRadius.circular(20),
    ),
    child: Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(
          positive ? Icons.trending_up : Icons.trending_down,
          color: positive ? C.green : C.red,
          size: 14,
        ),
        const SizedBox(width: 3),
        Text(
          text,
          style: TextStyle(
            fontSize: 11,
            color: positive ? C.green : C.red,
            fontWeight: FontWeight.w700,
          ),
        ),
      ],
    ),
  );
}
