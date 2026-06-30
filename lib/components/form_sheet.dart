import 'package:flutter/material.dart';
import '../theme/colors.dart';
import 'page_scaffold.dart';

Future<T?> showAppFormSheet<T>({
  required BuildContext context,
  required String title,
  String? subtitle,
  required Widget child,
  double initialChildSize = 0.7,
  double maxChildSize = 0.92,
}) {
  return showModalBottomSheet<T>(
    context: context,
    isScrollControlled: true,
    useSafeArea: true,
    backgroundColor: Colors.transparent,
    barrierColor: Colors.black.withOpacity(0.54),
    builder: (ctx) {
      final viewInsets = MediaQuery.viewInsetsOf(ctx);
      return Padding(
        padding: EdgeInsets.only(bottom: viewInsets.bottom),
        child: DraggableScrollableSheet(
          expand: false,
          initialChildSize: initialChildSize,
          minChildSize: 0.38,
          maxChildSize: maxChildSize,
          builder:
              (context, scrollController) => GlassPanel(
                margin: const EdgeInsets.fromLTRB(12, 0, 12, 12),
                padding: EdgeInsets.zero,
                radius: 30,
                color: const Color(0xF20B1018),
                borderColor: Colors.white.withOpacity(0.13),
                child: Column(
                  children: [
                    const SizedBox(height: 10),
                    Container(
                      width: 46,
                      height: 4,
                      decoration: BoxDecoration(
                        color: Colors.white.withOpacity(0.20),
                        borderRadius: BorderRadius.circular(99),
                      ),
                    ),
                    Padding(
                      padding: const EdgeInsets.fromLTRB(18, 18, 18, 12),
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  title,
                                  style: const TextStyle(
                                    color: C.t1,
                                    fontSize: 20,
                                    fontWeight: FontWeight.w900,
                                  ),
                                ),
                                if (subtitle != null) ...[
                                  const SizedBox(height: 5),
                                  Text(
                                    subtitle,
                                    style: const TextStyle(
                                      color: C.t2,
                                      fontSize: 12,
                                      fontWeight: FontWeight.w700,
                                    ),
                                  ),
                                ],
                              ],
                            ),
                          ),
                          RoundIconButton(
                            icon: Icons.close_rounded,
                            onTap: () => Navigator.pop(ctx),
                            size: 38,
                            color: C.t2,
                          ),
                        ],
                      ),
                    ),
                    Expanded(
                      child: SingleChildScrollView(
                        controller: scrollController,
                        padding: const EdgeInsets.fromLTRB(18, 0, 18, 18),
                        child: child,
                      ),
                    ),
                  ],
                ),
              ),
        ),
      );
    },
  );
}

Future<T?> showAppFormDialog<T>({
  required BuildContext context,
  required String title,
  String? subtitle,
  required Widget child,
  double maxWidth = 430,
  double maxHeightFactor = 0.82,
}) {
  return showDialog<T>(
    context: context,
    barrierColor: Colors.black.withOpacity(0.58),
    builder: (ctx) {
      final media = MediaQuery.of(ctx);
      final viewInsets = media.viewInsets;
      final maxHeight = media.size.height * maxHeightFactor;
      return AnimatedPadding(
        duration: C.fast,
        curve: Curves.easeOutCubic,
        padding: EdgeInsets.fromLTRB(18, 22, 18, 22 + viewInsets.bottom),
        child: Center(
          child: ConstrainedBox(
            constraints: BoxConstraints(
              maxWidth: maxWidth,
              maxHeight: maxHeight,
            ),
            child: Material(
              color: Colors.transparent,
              child: GlassPanel(
                padding: EdgeInsets.zero,
                radius: 26,
                color: const Color(0xF20B1018),
                borderColor: Colors.white.withOpacity(0.13),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Padding(
                      padding: const EdgeInsets.fromLTRB(18, 18, 14, 12),
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  title,
                                  style: const TextStyle(
                                    color: C.t1,
                                    fontSize: 19,
                                    fontWeight: FontWeight.w900,
                                  ),
                                ),
                                if (subtitle != null) ...[
                                  const SizedBox(height: 5),
                                  Text(
                                    subtitle,
                                    style: const TextStyle(
                                      color: C.t2,
                                      fontSize: 12,
                                      fontWeight: FontWeight.w700,
                                      height: 1.35,
                                    ),
                                  ),
                                ],
                              ],
                            ),
                          ),
                          RoundIconButton(
                            icon: Icons.close_rounded,
                            onTap: () => Navigator.pop(ctx),
                            size: 36,
                            color: C.t2,
                          ),
                        ],
                      ),
                    ),
                    Flexible(
                      fit: FlexFit.loose,
                      child: SingleChildScrollView(
                        padding: const EdgeInsets.fromLTRB(18, 0, 18, 18),
                        keyboardDismissBehavior:
                            ScrollViewKeyboardDismissBehavior.onDrag,
                        child: child,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      );
    },
  );
}

class AppFormField extends StatelessWidget {
  final TextEditingController controller;
  final String label;
  final String? hint;
  final IconData? icon;
  final TextInputType? keyboardType;
  final int maxLines;
  final bool autofocus;
  final ValueChanged<String>? onChanged;

  const AppFormField({
    Key? key,
    required this.controller,
    required this.label,
    this.hint,
    this.icon,
    this.keyboardType,
    this.maxLines = 1,
    this.autofocus = false,
    this.onChanged,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) => TextField(
    controller: controller,
    keyboardType: keyboardType,
    maxLines: maxLines,
    autofocus: autofocus,
    onChanged: onChanged,
    style: const TextStyle(
      color: C.t1,
      fontSize: 15,
      fontWeight: FontWeight.w800,
    ),
    decoration: InputDecoration(
      labelText: label,
      hintText: hint,
      prefixIcon: icon == null ? null : Icon(icon, color: C.t3, size: 18),
      fillColor: C.bgSurface.withOpacity(0.62),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(20),
        borderSide: BorderSide(color: Colors.white.withOpacity(0.09)),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(20),
        borderSide: const BorderSide(color: C.cyan, width: 1.3),
      ),
    ),
  );
}

class AppSheetActions extends StatelessWidget {
  final String primaryLabel;
  final VoidCallback onPrimary;
  final String secondaryLabel;
  final VoidCallback? onSecondary;
  final Color primaryColor;

  const AppSheetActions({
    Key? key,
    required this.primaryLabel,
    required this.onPrimary,
    this.secondaryLabel = '取消',
    this.onSecondary,
    this.primaryColor = C.cyan,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) => Row(
    children: [
      Expanded(
        child: OutlinedButton(
          onPressed: onSecondary ?? () => Navigator.pop(context),
          child: Text(secondaryLabel),
        ),
      ),
      const SizedBox(width: 10),
      Expanded(
        child: FilledButton(
          onPressed: onPrimary,
          style: FilledButton.styleFrom(
            backgroundColor: primaryColor,
            foregroundColor: Colors.black,
          ),
          child: Text(primaryLabel),
        ),
      ),
    ],
  );
}

class AppChoicePill extends StatelessWidget {
  final String label;
  final bool selected;
  final VoidCallback onTap;
  final Color color;

  const AppChoicePill({
    Key? key,
    required this.label,
    required this.selected,
    required this.onTap,
    this.color = C.cyan,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) => GestureDetector(
    onTap: onTap,
    child: AnimatedContainer(
      duration: C.fast,
      padding: const EdgeInsets.symmetric(horizontal: 13, vertical: 9),
      decoration: BoxDecoration(
        color: selected ? color : Colors.white.withOpacity(0.06),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(
          color: selected ? color : Colors.white.withOpacity(0.09),
        ),
      ),
      child: Text(
        label,
        style: TextStyle(
          color: selected ? Colors.black : C.t2,
          fontSize: 12,
          fontWeight: FontWeight.w900,
        ),
      ),
    ),
  );
}

class AppSelectionTile extends StatelessWidget {
  final String title;
  final String? subtitle;
  final IconData icon;
  final bool selected;
  final VoidCallback onTap;
  final Color color;

  const AppSelectionTile({
    Key? key,
    required this.title,
    this.subtitle,
    required this.icon,
    required this.selected,
    required this.onTap,
    this.color = C.cyan,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) => GestureDetector(
    onTap: onTap,
    child: AnimatedContainer(
      duration: C.fast,
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color:
            selected ? color.withOpacity(0.16) : Colors.white.withOpacity(0.05),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(
          color: selected ? color : Colors.white.withOpacity(0.09),
        ),
      ),
      child: Row(
        children: [
          Container(
            width: 34,
            height: 34,
            decoration: BoxDecoration(
              color: selected ? color : Colors.white.withOpacity(0.07),
              shape: BoxShape.circle,
            ),
            child: Icon(icon, color: selected ? Colors.black : C.t2, size: 18),
          ),
          const SizedBox(width: 11),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    color: C.t1,
                    fontSize: 13,
                    fontWeight: FontWeight.w900,
                  ),
                ),
                if (subtitle != null) ...[
                  const SizedBox(height: 3),
                  Text(
                    subtitle!,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      color: C.t3,
                      fontSize: 11,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ],
              ],
            ),
          ),
          Icon(
            selected ? Icons.check_circle_rounded : Icons.circle_outlined,
            color: selected ? color : C.tMuted,
            size: 20,
          ),
        ],
      ),
    ),
  );
}
