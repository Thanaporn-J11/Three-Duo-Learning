import 'package:flutter/material.dart';

class VocabularyApiStatusView extends StatelessWidget {
  const VocabularyApiStatusView({
    required this.title,
    required this.message,
    required this.loading,
    this.onRetry,
    this.onUseLocal,
    super.key,
  });

  final String title;
  final String message;
  final bool loading;
  final VoidCallback? onRetry;
  final VoidCallback? onUseLocal;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text(title)),
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (loading)
                const CircularProgressIndicator()
              else
                const Icon(
                  Icons.cloud_off_rounded,
                  size: 48,
                  color: Color(0xFF64748B),
                ),
              const SizedBox(height: 16),
              Text(message, textAlign: TextAlign.center),
              if (onRetry != null) ...[
                const SizedBox(height: 16),
                FilledButton.icon(
                  onPressed: onRetry,
                  icon: const Icon(Icons.refresh_rounded),
                  label: const Text('ลองอีกครั้ง'),
                ),
              ],
              if (onUseLocal != null) ...[
                const SizedBox(height: 8),
                TextButton(
                  onPressed: onUseLocal,
                  child: const Text('ใช้ข้อมูลเดิมในเครื่อง'),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}
