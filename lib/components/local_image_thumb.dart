import 'dart:io';

import 'package:flutter/material.dart';

import '../theme/colors.dart';

class LocalImageThumb extends StatelessWidget {
  final String path;
  final double width;
  final double height;
  final double radius;
  final BoxFit fit;
  final Alignment alignment;
  final Widget? errorChild;

  const LocalImageThumb({
    Key? key,
    required this.path,
    required this.width,
    required this.height,
    this.radius = 8,
    this.fit = BoxFit.cover,
    this.alignment = Alignment.center,
    this.errorChild,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    final dpr = MediaQuery.of(context).devicePixelRatio;
    return LayoutBuilder(
      builder: (context, constraints) {
        final resolvedWidth =
            width.isFinite
                ? width
                : constraints.maxWidth.clamp(96.0, 900.0).toDouble();
        final resolvedHeight =
            height.isFinite
                ? height
                : constraints.maxHeight.clamp(96.0, 900.0).toDouble();
        final cacheWidth =
            (resolvedWidth * dpr).round().clamp(96, 1200).toInt();
        final cacheHeight =
            (resolvedHeight * dpr).round().clamp(96, 1200).toInt();
        final imageWidth = width.isFinite ? width : resolvedWidth;
        final imageHeight = height.isFinite ? height : resolvedHeight;
        return RepaintBoundary(
          child: ClipRRect(
            borderRadius: BorderRadius.circular(radius),
            child: Image.file(
              File(path),
              width: imageWidth,
              height: imageHeight,
              fit: fit,
              alignment: alignment,
              cacheWidth: cacheWidth,
              cacheHeight: cacheHeight,
              filterQuality: FilterQuality.low,
              errorBuilder:
                  (_, __, ___) =>
                      errorChild ??
                      Container(
                        width: resolvedWidth,
                        height: resolvedHeight,
                        color: C.bgCard,
                        child: Icon(Icons.broken_image_outlined, color: C.t3),
                      ),
            ),
          ),
        );
      },
    );
  }
}
