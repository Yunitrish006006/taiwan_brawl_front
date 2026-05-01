import 'package:flutter/material.dart';
import '../utils/app_error.dart';

/// Default error fallback widget
class ErrorFallbackWidget extends StatelessWidget {
  const ErrorFallbackWidget({
    super.key,
    required this.error,
    required this.onRetry,
  });

  final AppError error;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              _getIconForErrorType(error.type),
              size: 64,
              color: Colors.grey[400],
            ),
            const SizedBox(height: 16),
            Text(
              error.userMessage,
              textAlign: TextAlign.center,
              style: Theme.of(context).textTheme.titleMedium,
            ),
            const SizedBox(height: 24),
            FilledButton.icon(
              onPressed: onRetry,
              icon: const Icon(Icons.refresh),
              label: const Text('Retry'),
            ),
          ],
        ),
      ),
    );
  }

  IconData _getIconForErrorType(AppErrorType type) {
    return switch (type) {
      AppErrorType.network => Icons.wifi_off,
      AppErrorType.server => Icons.error_outline,
      AppErrorType.auth => Icons.lock_outline,
      AppErrorType.validation => Icons.warning_amber,
      AppErrorType.unknown => Icons.bug_report,
    };
  }
}

/// Helper to wrap async builders with error handling
class AsyncErrorBoundary extends StatelessWidget {
  const AsyncErrorBoundary({
    super.key,
    required this.future,
    required this.builder,
    this.loadingBuilder,
    this.errorBuilder,
  });

  final Future<dynamic> future;
  final Widget Function(BuildContext, dynamic data) builder;
  final Widget Function(BuildContext)? loadingBuilder;
  final Widget Function(BuildContext, AppError)? errorBuilder;

  @override
  Widget build(BuildContext context) {
    return FutureBuilder(
      future: future,
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return loadingBuilder?.call(context) ??
              const Center(child: CircularProgressIndicator());
        }

        if (snapshot.hasError) {
          final error = AppError.generic(snapshot.error!, st: snapshot.stackTrace);
          return errorBuilder?.call(context, error) ??
              ErrorFallbackWidget(error: error, onRetry: () {});
        }

        return builder(context, snapshot.data);
      },
    );
  }
}
