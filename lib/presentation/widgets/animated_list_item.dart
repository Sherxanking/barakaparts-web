/// AnimatedListItem - List itemlar uchun animatsiya widget
/// 
/// Bu widget list itemlariga fade-in va slide animatsiyalarini qo'shadi.
import 'package:flutter/material.dart';

class AnimatedListItem extends StatelessWidget {
  /// Child widget
  final Widget child;
  
  /// Animatsiya delay (milliseconds)
  final int delay;
  
  /// Animatsiya duration (milliseconds)
  final int duration;

  const AnimatedListItem({
    super.key,
    required this.child,
    this.delay = 0,
    this.duration = 300,
  });

  @override
  Widget build(BuildContext context) {
    return TweenAnimationBuilder<double>(
      tween: Tween(begin: 0.0, end: 1.0),
      duration: Duration(milliseconds: duration + delay),
      curve: Curves.easeOut,
      builder: (context, value, child) {
        return Opacity(
          opacity: value,
          child: Transform.translate(
            offset: Offset(0, 20 * (1 - value)),
            child: child,
          ),
        );
      },
      child: child,
    );
  }
}

