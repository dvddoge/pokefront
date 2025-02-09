import 'package:flutter/material.dart';

class AnimatedCounter extends StatelessWidget {
  final int value;
  final TextStyle? style;

  const AnimatedCounter({
    Key? key,
    required this.value,
    this.style,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return TweenAnimationBuilder<double>(
      duration: Duration(milliseconds: 500),
      tween: Tween<double>(begin: 0, end: value.toDouble()),
      builder: (context, value, child) {
        return Text(
          value.toInt().toString(),
          style: style,
        );
      },
    );
  }
}