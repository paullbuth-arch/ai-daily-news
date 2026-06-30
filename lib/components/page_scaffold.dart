import 'package:flutter/material.dart';
import '../theme/colors.dart';

/// 页面骨架（标准页面包装器）
class PageScaffold extends StatelessWidget {
  final Widget child;
  final Widget? title;
  final Widget? subtitle;
  final Widget? action;

  const PageScaffold({
    Key? key,
    required this.child,
    this.title,
    this.subtitle,
    this.action,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) => SafeArea(
    child: ListView(
      padding: const EdgeInsets.only(top: C.sp8, bottom: C.sp24),
      children: [
        if (title != null || action != null)
          Padding(
            padding: const EdgeInsets.fromLTRB(C.sp16, 8, C.sp16, C.sp16),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      if (title != null) title!,
                      if (subtitle != null)
                        Padding(
                          padding: const EdgeInsets.only(top: 4),
                          child: subtitle!,
                        ),
                    ],
                  ),
                ),
                if (action != null) action!,
              ],
            ),
          ),
        child,
      ],
    ),
  );
}

/// 子页面骨架（带返回按钮的 AppBar）
Widget appScaffold(BuildContext context, String title, Widget body) => Scaffold(
  backgroundColor: C.bg,
  appBar: AppBar(
    backgroundColor: C.nav,
    elevation: 0,
    scrolledUnderElevation: 0.5,
    leading: Padding(
      padding: const EdgeInsets.only(left: 8),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: () => Navigator.pop(context),
          borderRadius: BorderRadius.circular(10),
          child: Container(
            width: 36,
            height: 36,
            decoration: BoxDecoration(
              color: C.primary.withOpacity(0.06),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(Icons.chevron_left, color: C.primary, size: 22),
          ),
        ),
      ),
    ),
    title: Text(
      title,
      style: TextStyle(
        fontSize: 17,
        fontWeight: FontWeight.w800,
        color: C.t1,
        letterSpacing: 0.2,
      ),
    ),
    centerTitle: true,
    surfaceTintColor: Colors.transparent,
    shape: Border(bottom: BorderSide(color: C.line, width: 0.8)),
  ),
  body: SafeArea(child: body),
);
