import 'package:flutter/material.dart';
import '../theme/colors.dart';

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
      color: outline ? Colors.transparent : color.withValues(alpha: 0.16),
      borderRadius: BorderRadius.circular(20),
      border: Border.all(color: color.withValues(alpha: 0.28), width: 1),
    ),
    child: Text(
      text,
      style: TextStyle(fontSize: 11, color: color, fontWeight: FontWeight.w900),
    ),
  );
}

class TrendChip extends StatelessWidget {
  final bool positive;
  final String text;

  const TrendChip({Key? key, required this.positive, required this.text})
    : super(key: key);

  @override
  Widget build(BuildContext context) {
    final color = positive ? C.green : C.red;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 5),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.16),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: color.withValues(alpha: 0.28)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            positive ? Icons.trending_up_rounded : Icons.trending_down_rounded,
            color: color,
            size: 14,
          ),
          const SizedBox(width: 3),
          Text(
            text,
            style: TextStyle(
              fontSize: 11,
              color: color,
              fontWeight: FontWeight.w900,
            ),
          ),
        ],
      ),
    );
  }
}
