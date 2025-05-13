import 'package:flutter/material.dart';

/// A failsafe widget wrapper that catches rendering errors
/// Use this to wrap widgets that might cause overflow, layout issues, or other errors
class FailsafeWidget extends StatelessWidget {
  final Widget child;
  final double? minHeight;
  final double? maxHeight;
  final Widget? fallbackWidget;
  final String fallbackMessage;

  const FailsafeWidget({
    Key? key,
    required this.child,
    this.minHeight,
    this.maxHeight,
    this.fallbackWidget,
    this.fallbackMessage = 'Unable to display content',
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        // Apply min/max height constraints if provided
        BoxConstraints effectiveConstraints = constraints;
        if (minHeight != null || maxHeight != null) {
          effectiveConstraints = constraints.copyWith(
            minHeight: minHeight ?? constraints.minHeight,
            maxHeight: maxHeight ?? constraints.maxHeight,
          );
        }

        return SafeArea(
          child: SizedBox(
            width: effectiveConstraints.maxWidth,
            height: minHeight,
            child: Builder(
              builder: (context) {
                try {
                  // Try to build and return the child widget
                  return child;
                } catch (e, stackTrace) {
                  // Log the error
                  debugPrint('⚠️ Widget rendering error: $e');
                  debugPrint('Stack trace: $stackTrace');

                  // Return fallback widget on error
                  return fallbackWidget ?? _buildDefaultFallback(context);
                }
              },
            ),
          ),
        );
      },
    );
  }

  Widget _buildDefaultFallback(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.grey[200],
        borderRadius: BorderRadius.circular(12.0),
      ),
      padding: const EdgeInsets.all(16.0),
      child: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              Icons.warning_amber_rounded,
              size: 32,
              color: Colors.orange[700],
            ),
            const SizedBox(height: 8),
            Text(
              fallbackMessage,
              style: TextStyle(
                color: Colors.grey[700],
                fontWeight: FontWeight.bold,
              ),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }
}
