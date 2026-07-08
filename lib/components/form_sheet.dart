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
    barrierColor: Colors.black.withValues(alpha: 0.54),
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
                radius: 18,
                color: C.isLight ? null : C.bgCard,
                borderColor: C.border,
                child: Column(
                  children: [
                    const SizedBox(height: 10),
                    Container(
                      width: 46,
                      height: 4,
                      decoration: BoxDecoration(
                        color: C.borderGlow,
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
                                  style: TextStyle(
                                    color: C.t1,
                                    fontSize: 20,
                                    fontWeight: FontWeight.w900,
                                  ),
                                ),
                                if (subtitle != null) ...[
                                  const SizedBox(height: 5),
                                  Text(
                                    subtitle,
                                    style: TextStyle(
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
    barrierColor: Colors.black.withValues(alpha: 0.58),
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
                radius: 18,
                color: C.isLight ? null : C.bgCard,
                borderColor: C.border,
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
                                  style: TextStyle(
                                    color: C.t1,
                                    fontSize: 19,
                                    fontWeight: FontWeight.w900,
                                  ),
                                ),
                                if (subtitle != null) ...[
                                  const SizedBox(height: 5),
                                  Text(
                                    subtitle,
                                    style: TextStyle(
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
  final bool readOnly;
  final bool obscureText;
  final Widget? suffixIcon;
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
    this.readOnly = false,
    this.obscureText = false,
    this.suffixIcon,
    this.onChanged,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) => TextField(
    controller: controller,
    keyboardType: keyboardType,
    maxLines: maxLines,
    autofocus: autofocus,
    readOnly: readOnly,
    obscureText: obscureText,
    onChanged: onChanged,
    style: TextStyle(color: C.t1, fontSize: 14, fontWeight: FontWeight.w700),
    decoration: InputDecoration(
      labelText: label,
      hintText: hint,
      prefixIcon: icon == null ? null : Icon(icon, color: C.t3, size: 18),
      suffixIcon: suffixIcon,
      filled: true,
      fillColor: C.isLight ? C.bgCard.withValues(alpha: 0.86) : C.bgDeep,
      labelStyle: TextStyle(color: C.t2, fontSize: 12),
      hintStyle: TextStyle(color: C.t3, fontSize: 13),
      contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 14),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(10),
        borderSide: BorderSide(color: C.border),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(10),
        borderSide: BorderSide(
          color: C.isLight ? C.purple : C.cyan,
          width: 1.2,
        ),
      ),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(10),
        borderSide: BorderSide(color: C.border),
      ),
    ),
  );
}

class AppDropdownField<T> extends StatelessWidget {
  final T? value;
  final String hint;
  final List<T> options;
  final ValueChanged<T?> onChanged;
  final String Function(T value) labelBuilder;
  final double fontSize;

  const AppDropdownField({
    Key? key,
    required this.value,
    required this.hint,
    required this.options,
    required this.onChanged,
    required this.labelBuilder,
    this.fontSize = 14,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 12),
    constraints: const BoxConstraints(minHeight: 48),
    decoration: BoxDecoration(
      color: C.isLight ? C.bgCard.withValues(alpha: 0.86) : C.bgDeep,
      borderRadius: BorderRadius.circular(10),
      border: Border.all(color: C.border),
    ),
    child: DropdownButton<T>(
      value: value,
      isExpanded: true,
      underline: const SizedBox(),
      dropdownColor: C.bgCard,
      icon: Icon(Icons.keyboard_arrow_down_rounded, color: C.t3),
      hint: Text(hint, style: TextStyle(color: C.t3, fontSize: fontSize)),
      style: TextStyle(color: C.t1, fontSize: fontSize),
      items:
          options
              .map(
                (item) => DropdownMenuItem<T>(
                  value: item,
                  child: Text(
                    labelBuilder(item),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(fontSize: fontSize - 1),
                  ),
                ),
              )
              .toList(),
      onChanged: onChanged,
    ),
  );
}

class AppSheetActions extends StatelessWidget {
  final String primaryLabel;
  final VoidCallback onPrimary;
  final String secondaryLabel;
  final VoidCallback? onSecondary;
  final Color primaryColor;

  AppSheetActions({
    Key? key,
    required this.primaryLabel,
    required this.onPrimary,
    this.secondaryLabel = '取消',
    this.onSecondary,
    Color? primaryColor,
  }) : primaryColor = primaryColor ?? C.cyan,
       super(key: key);

  @override
  Widget build(BuildContext context) => Row(
    children: [
      Expanded(
        child: OutlinedButton(
          onPressed: onSecondary ?? () => Navigator.pop(context),
          style: OutlinedButton.styleFrom(
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(10),
            ),
            padding: const EdgeInsets.symmetric(vertical: 13),
          ),
          child: Text(secondaryLabel),
        ),
      ),
      const SizedBox(width: 10),
      Expanded(
        child: FilledButton(
          onPressed: onPrimary,
          style: FilledButton.styleFrom(
            backgroundColor: C.isLight ? C.hudDark : primaryColor,
            foregroundColor: C.isLight ? C.purple : Colors.black,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(10),
            ),
            padding: const EdgeInsets.symmetric(vertical: 13),
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

  AppChoicePill({
    Key? key,
    required this.label,
    required this.selected,
    required this.onTap,
    Color? color,
  }) : color = color ?? C.cyan,
       super(key: key);

  @override
  Widget build(BuildContext context) => GestureDetector(
    onTap: onTap,
    child: AnimatedContainer(
      duration: C.fast,
      padding: const EdgeInsets.symmetric(horizontal: 13, vertical: 9),
      decoration: BoxDecoration(
        color: selected ? color : C.bgDeep,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: selected ? color : C.border),
      ),
      child: Text(
        label,
        style: TextStyle(
          color: selected ? (C.isLight ? Colors.white : Colors.black) : C.t2,
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

  AppSelectionTile({
    Key? key,
    required this.title,
    this.subtitle,
    required this.icon,
    required this.selected,
    required this.onTap,
    Color? color,
  }) : color = color ?? C.cyan,
       super(key: key);

  @override
  Widget build(BuildContext context) => GestureDetector(
    onTap: onTap,
    child: AnimatedContainer(
      duration: C.fast,
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color:
            selected
                ? color.withValues(alpha: C.isLight ? 0.12 : 0.16)
                : C.isLight
                ? C.bgCard.withValues(alpha: 0.86)
                : C.bgDeep,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: selected ? color : C.border),
      ),
      child: Row(
        children: [
          Container(
            width: 34,
            height: 34,
            decoration: BoxDecoration(
              color:
                  selected
                      ? color
                      : C.isLight
                      ? C.bgCardMuted
                      : C.bgSurface,
              borderRadius: BorderRadius.circular(9),
            ),
            child: Icon(
              icon,
              color:
                  selected ? (C.isLight ? Colors.white : Colors.black) : C.t2,
              size: 18,
            ),
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
                  style: TextStyle(
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
                    style: TextStyle(
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
