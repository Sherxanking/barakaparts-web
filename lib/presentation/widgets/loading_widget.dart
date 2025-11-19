/// LoadingWidget - Yuklanish holatini ko'rsatish uchun reusable widget
/// 
/// Bu widget ma'lumotlar yuklanayotganda ko'rsatiladigan 
/// standart loading indicator.
import 'package:flutter/material.dart';

class LoadingWidget extends StatelessWidget {
  /// Loading matni
  final String? message;

  const LoadingWidget({
    super.key,
    this.message,
  });

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const CircularProgressIndicator(),
          if (message != null) ...[
            const SizedBox(height: 16),
            Text(
              message!,
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    color: Theme.of(context).colorScheme.onSurface.withOpacity(0.6),
                  ),
            ),
          ],
        ],
      ),
    );
  }
}

