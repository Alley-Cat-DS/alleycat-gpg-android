import 'package:flutter/material.dart';

/// Shows a passphrase entry dialog.
/// If [confirm] is true, shows a second field to confirm.
/// Returns the passphrase or null if cancelled.
Future<String?> showPassphraseDialog(
  BuildContext context, {
  required bool confirm,
  String title = 'Enter Passphrase',
  String? hint,
}) async {
  final ctrl1 = TextEditingController();
  final ctrl2 = TextEditingController();
  bool obscure1 = true;
  bool obscure2 = true;
  String? error;

  return showDialog<String>(
    context: context,
    barrierDismissible: false,
    builder: (ctx) => StatefulBuilder(
      builder: (ctx, setState) => AlertDialog(
        title: Text(title),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (hint != null) ...[
              Text(hint, style: TextStyle(
                fontSize: 13,
                color: Theme.of(ctx).colorScheme.onSurfaceVariant,
              )),
              const SizedBox(height: 12),
            ],
            TextField(
              controller: ctrl1,
              obscureText: obscure1,
              autofocus: true,
              decoration: InputDecoration(
                labelText: confirm ? 'Passphrase' : 'Passphrase',
                errorText: error,
                suffixIcon: IconButton(
                  icon: Icon(obscure1 ? Icons.visibility_off : Icons.visibility),
                  onPressed: () => setState(() => obscure1 = !obscure1),
                ),
              ),
            ),
            if (confirm) ...[
              const SizedBox(height: 12),
              TextField(
                controller: ctrl2,
                obscureText: obscure2,
                decoration: InputDecoration(
                  labelText: 'Confirm Passphrase',
                  suffixIcon: IconButton(
                    icon: Icon(obscure2 ? Icons.visibility_off : Icons.visibility),
                    onPressed: () => setState(() => obscure2 = !obscure2),
                  ),
                ),
              ),
            ],
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, null),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () {
              final p1 = ctrl1.text;
              if (p1.isEmpty) {
                setState(() => error = 'Passphrase cannot be empty.');
                return;
              }
              if (confirm && p1 != ctrl2.text) {
                setState(() => error = 'Passphrases do not match.');
                return;
              }
              Navigator.pop(ctx, p1);
            },
            child: const Text('OK'),
          ),
        ],
      ),
    ),
  );
}
