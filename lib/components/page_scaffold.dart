import 'package:flutter/material.dart';
import '../theme/colors.dart';

/// ═══════════════════════════════════════════════
/// 页面骨架（暗黑科技风）
/// ═══════════════════════════════════════════════
class PageScaffold extends StatelessWidget {
  final Widget child;
  final Widget? title;
  final Widget? subtitle;
  final Widget? action;
  final bool hasGridBg;

  const PageScaffold({
    Key? key,
    required this.child,
    this.title,
    this.subtitle,
    this.action,
    this.hasGridBg = true,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) => Stack(
    children: [
      // 网格背景
      if (hasGridBg) const _GridBackground(),
      // 内容
      SafeArea(
        child: ListView(
          padding: const EdgeInsets.only(top: C.sp8, bottom: C.sp24 + 80),
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
      ),
    ],
  );
}

/// 网格背景装饰
class _GridBackground extends StatelessWidget {
  const _GridBackground();

  @override
  Widget build(BuildContext context) => IgnorePointer(
    child: Container(
      decoration: BoxDecoration(
        color: C.bgDeep,
        image: DecorationImage(
          image: const AssetImage('assets/grid.png'),
          repeat: ImageRepeat.repeat,
          opacity: 0.03,
        ),
      ),
      child: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            colors: [
              C.bgDeep.withOpacity(0.3),
              C.bgDeep.withOpacity(0.1),
              C.bgDeep.withOpacity(0.3),
            ],
            stops: const [0.0, 0.5, 1.0],
          ),
        ),
      ),
    ),
  );
}

/// ═══════════════════════════════════════════════
/// 子页面骨架（带返回按钮的 AppBar）
/// ═══════════════════════════════════════════════
Widget appScaffold(BuildContext context, String title, Widget body, {Widget? trailing}) => Scaffold(
  backgroundColor: C.bgDeep,
  appBar: AppBar(
    backgroundColor: C.nav,
    elevation: 0,
    scrolledUnderElevation: 0,
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
              color: C.cyan.withOpacity(0.06),
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: C.cyan.withOpacity(0.1)),
            ),
            child: const Icon(Icons.chevron_left, color: C.cyan, size: 22),
          ),
        ),
      ),
    ),
    title: Text(
      title,
      style: const TextStyle(
        fontSize: 17,
        fontWeight: FontWeight.w800,
        color: C.t1,
        letterSpacing: 0.2,
      ),
    ),
    centerTitle: true,
    surfaceTintColor: Colors.transparent,
    actions: trailing != null ? [trailing] : null,
    shape: const Border(bottom: BorderSide(color: C.border, width: 0.8)),
  ),
  body: SafeArea(child: body),
);

/// ═══════════════════════════════════════════════
/// 霓虹卡片（带发光边框）
/// ═══════════════════════════════════════════════
class NeonCard extends StatelessWidget {
  final Widget child;
  final EdgeInsetsGeometry padding;
  final Color? glowColor;
  final double borderWidth;
  final VoidCallback? onTap;

  const NeonCard({
    Key? key,
    required this.child,
    this.padding = const EdgeInsets.all(16),
    this.glowColor,
    this.borderWidth = 0.8,
    this.onTap,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    final color = glowColor ?? C.cyan;
    final card = Container(
      padding: padding,
      decoration: BoxDecoration(
        color: C.bgCard,
        borderRadius: BorderRadius.circular(C.radiusMd),
        border: Border.all(color: color.withOpacity(0.15), width: borderWidth),
        boxShadow: [
          BoxShadow(
            color: color.withOpacity(0.05),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: child,
    );
    if (onTap != null) {
      return GestureDetector(onTap: onTap, child: card);
    }
    return card;
  }
}
