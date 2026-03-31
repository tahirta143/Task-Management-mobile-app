import 'package:flutter/material.dart';
import 'package:loading_animation_widget/loading_animation_widget.dart';

class CustomLoader extends StatelessWidget {
  final double size;
  final Color? color;
  final bool fullScreen;

  const CustomLoader({
    super.key,
    this.size = 50,
    this.color,
    this.fullScreen = false,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final loaderColor = color ?? theme.colorScheme.primary;

    final loader = LoadingAnimationWidget.inkDrop(
      color: loaderColor,
      size: size,
    );

    if (fullScreen) {
      return Container(
        color: theme.scaffoldBackgroundColor.withAlpha(200),
        child: Center(child: loader),
      );
    }

    return Center(child: loader);
  }
}
