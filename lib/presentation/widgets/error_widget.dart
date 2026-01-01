/// Error Widget - Xatolik ko'rsatish uchun reusable widget
/// 
/// StreamBuilder va FutureBuilder'larda error handling uchun ishlatiladi

import 'package:flutter/material.dart';
import '../../core/services/error_handler_service.dart';
import '../../core/errors/failures.dart';
import '../../l10n/app_localizations.dart';

class ErrorDisplayWidget extends StatelessWidget {
  final Failure? failure;
  final Object? error;
  final VoidCallback? onRetry;
  final String? customMessage;

  const ErrorDisplayWidget({
    super.key,
    this.failure,
    this.error,
    this.onRetry,
    this.customMessage,
  });

  @override
  Widget build(BuildContext context) {
    String message;
    
    if (customMessage != null) {
      message = customMessage!;
    } else if (failure != null) {
      message = ErrorHandlerService.instance.getErrorMessage(failure!);
    } else if (error != null) {
      // SECURITY: Sanitize error before showing
      final errorString = error.toString();
      message = ErrorHandlerService.instance.getErrorMessage(
        UnknownFailure(errorString),
      );
    } else {
      message = AppLocalizations.of(context)?.translate('errorOccurred') ?? 
                'Xatolik yuz berdi';
    }

    return Center(
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(
              Icons.error_outline,
              size: 64,
              color: Colors.red,
            ),
            const SizedBox(height: 16),
            Text(
              message,
              textAlign: TextAlign.center,
              style: const TextStyle(
                fontSize: 16,
                color: Colors.red,
              ),
            ),
            if (onRetry != null) ...[
              const SizedBox(height: 24),
              ElevatedButton.icon(
                onPressed: onRetry,
                icon: const Icon(Icons.refresh),
                label: Text(
                  AppLocalizations.of(context)?.translate('retry') ?? 'Qayta urinish',
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
