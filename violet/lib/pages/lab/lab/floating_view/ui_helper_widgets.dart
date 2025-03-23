import 'package:flutter/material.dart';

class ColoredContainer extends StatelessWidget {
  final Widget child;
  final Color color;
  final EdgeInsetsGeometry padding;
  final EdgeInsetsGeometry margin;
  final double borderRadius;

  const ColoredContainer({
    Key? key,
    required this.child,
    required this.color,
    this.padding = const EdgeInsets.all(8.0),
    this.margin = const EdgeInsets.all(4.0),
    this.borderRadius = 8.0,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: padding,
      margin: margin,
      decoration: BoxDecoration(
        color: color,
        borderRadius: BorderRadius.circular(borderRadius),
      ),
      child: child,
    );
  }
}

class CustomDivider extends StatelessWidget {
  final Color color;
  final double thickness;
  final double indent;
  final double endIndent;

  const CustomDivider({
    Key? key,
    this.color = Colors.white24,
    this.thickness = 1.0,
    this.indent = 0.0,
    this.endIndent = 0.0,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Divider(
      color: color,
      thickness: thickness,
      indent: indent,
      endIndent: endIndent,
    );
  }
}

// ... 필요한 추가 유틸리티 위젯 ...
