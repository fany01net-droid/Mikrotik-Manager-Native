import 'package:flutter/material.dart';
import 'package:m3e_loading_indicator/m3e_loading_indicator.dart';

/// Material 3 Expressive Loading Indicator wrapper
/// providing unified [size] and [color] configuration.
class LoadingIndicatorM3E extends StatelessWidget {
  final double size;
  final Color? color;

  const LoadingIndicatorM3E({
    super.key,
    this.size = 40.0,
    this.color,
  });

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: size,
      height: size,
      child: Center(
        child: M3ELoadingIndicator(
          color: color,
          constraints: BoxConstraints.tightFor(width: size, height: size),
        ),
      ),
    );
  }
}
