import 'package:flutter/material.dart';

import '../../services/auto_update_service.dart';

/// Диалог с предложением установить обновление.
class UpdateAvailableDialog extends StatelessWidget {
  final UpdateInfo updateInfo;

  const UpdateAvailableDialog({super.key, required this.updateInfo});

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      backgroundColor: const Color(0xFF0a1f14),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(20),
        side: const BorderSide(color: Color(0x2E00ff88)),
      ),
      title: const Row(
        children: [
          Icon(Icons.system_update, color: Color(0xFF00ff88)),
          SizedBox(width: 12),
          Text(
            'Доступно обновление',
            style: TextStyle(color: Colors.white, fontSize: 18),
          ),
        ],
      ),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Текущая версия будет заменена на ${updateInfo.version}.',
            style: const TextStyle(color: Color(0xFF88b89a)),
          ),
          const SizedBox(height: 12),
          if (updateInfo.releaseNotes.isNotEmpty)
            Container(
              constraints: const BoxConstraints(maxHeight: 200),
              decoration: BoxDecoration(
                color: const Color(0x08FFFFFF),
                borderRadius: BorderRadius.circular(12),
              ),
              padding: const EdgeInsets.all(12),
              child: SingleChildScrollView(
                child: Text(
                  updateInfo.releaseNotes,
                  style: const TextStyle(
                    color: Color(0xFF88b89a),
                    fontSize: 13,
                    height: 1.4,
                  ),
                ),
              ),
            ),
        ],
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(false),
          child: const Text(
            'Позже',
            style: TextStyle(color: Color(0xFF88b89a)),
          ),
        ),
        ElevatedButton(
          onPressed: () => Navigator.of(context).pop(true),
          style: ElevatedButton.styleFrom(
            backgroundColor: const Color(0xFF00ff88),
            foregroundColor: const Color(0xFF0a1f14),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
            ),
          ),
          child: const Text('Обновить сейчас'),
        ),
      ],
    );
  }
}
