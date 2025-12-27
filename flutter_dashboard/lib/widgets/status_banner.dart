import 'package:flutter/material.dart';

/// Status banner widget for displaying system-wide alerts and status
class StatusBanner extends StatelessWidget {
  final StatusLevel level;
  final String message;
  final IconData? icon;
  final VoidCallback? onDismiss;

  const StatusBanner({
    super.key,
    required this.level,
    required this.message,
    this.icon,
    this.onDismiss,
  });

  @override
  Widget build(BuildContext context) {
    final theme = _getThemeForLevel(level);
    
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        color: theme.backgroundColor,
        border: Border(
          left: BorderSide(color: theme.borderColor, width: 4),
        ),
      ),
      child: Row(
        children: [
          Icon(
            icon ?? theme.icon,
            color: theme.iconColor,
            size: 24,
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              message,
              style: TextStyle(
                color: theme.textColor,
                fontWeight: FontWeight.w500,
                fontSize: 14,
              ),
            ),
          ),
          if (onDismiss != null)
            IconButton(
              icon: const Icon(Icons.close, size: 20),
              color: theme.iconColor,
              onPressed: onDismiss,
              padding: EdgeInsets.zero,
              constraints: const BoxConstraints(),
            ),
        ],
      ),
    );
  }

  _StatusTheme _getThemeForLevel(StatusLevel level) {
    switch (level) {
      case StatusLevel.success:
        return _StatusTheme(
          backgroundColor: Colors.green.shade50,
          borderColor: Colors.green,
          iconColor: Colors.green.shade700,
          textColor: Colors.green.shade900,
          icon: Icons.check_circle,
        );
      case StatusLevel.warning:
        return _StatusTheme(
          backgroundColor: Colors.orange.shade50,
          borderColor: Colors.orange,
          iconColor: Colors.orange.shade700,
          textColor: Colors.orange.shade900,
          icon: Icons.warning,
        );
      case StatusLevel.error:
        return _StatusTheme(
          backgroundColor: Colors.red.shade50,
          borderColor: Colors.red,
          iconColor: Colors.red.shade700,
          textColor: Colors.red.shade900,
          icon: Icons.error,
        );
      case StatusLevel.info:
        return _StatusTheme(
          backgroundColor: Colors.blue.shade50,
          borderColor: Colors.blue,
          iconColor: Colors.blue.shade700,
          textColor: Colors.blue.shade900,
          icon: Icons.info,
        );
    }
  }
}

enum StatusLevel {
  success,
  warning,
  error,
  info,
}

class _StatusTheme {
  final Color backgroundColor;
  final Color borderColor;
  final Color iconColor;
  final Color textColor;
  final IconData icon;

  _StatusTheme({
    required this.backgroundColor,
    required this.borderColor,
    required this.iconColor,
    required this.textColor,
    required this.icon,
  });
}

