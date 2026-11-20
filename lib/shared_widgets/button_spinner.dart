import 'package:flutter/material.dart';

/// Small spinner shown inside a button (or next to a label) while it works.
class ButtonSpinner extends StatelessWidget {
  final double size;
  final Color color;

  const ButtonSpinner({super.key, this.size = 18, this.color = Colors.white});

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: size,
      height: size,
      child: CircularProgressIndicator(strokeWidth: 2, color: color),
    );
  }
}
