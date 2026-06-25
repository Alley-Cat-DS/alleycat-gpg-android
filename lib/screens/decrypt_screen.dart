import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../services/key_service.dart';
import '../models/pgp_key.dart';
import '../widgets/passphrase_dialog.dart';
import '../widgets/section_header.dart';

class DecryptScreen extends StatefulWidget {
  const DecryptScreen({super.key});

  @override
  State<DecryptScreen> createState() => _DecryptScreenState();
}

class _DecryptScreenState extends State<DecryptScreen> {
  final _ciphertextController = TextEditingController();
  final _plaintextController = TextEditingController();

  String _method = 'Auto';
  PgpKey? _selectedIdentity;
  bool _loading = false;
  String? _sigStatus;
  Color? _sigColor;

  @override
  void dispose() {
    _ciphertextController.dispose();
    _plaintextController.dispose();
    super.dispose();
  }

  List<PgpKey> get _secretKeys => KeyService.instance.secretKeys;

  Future<void> _pasteFromClipboard() async {
    final data = await Clipboard.getData('text/plain');
    if (data?.text != null) {
      setState(() => _ciphertextController.text = data!.text!);
    }
  }

  Future<void> _decrypt() async {
    final ct = _ciphertextController.text.trim();
    if (ct.isEmpty) {
      _showSnack('Paste a PGP message to decrypt.');
      return;
    }

    setState(() {
      _loading = true;
      _sigStatus = null;
      _sigColor = null;
    });

    final scheme = Theme.of(context).colorScheme;

    try {
      String plaintext;

      final isSymmetric = _method == 'Passphrase' ||
          (_method == 'Auto' && !ct.contains('BEGIN PGP MESSAGE'));

      if (_method == 'Passphrase' || isSymmetric) {
        final passphrase = await showPassphraseDialog(context, confirm: false);
        if (passphrase == null) {
          setState(() => _loading = false);
          return;
        }
        plaintext = await KeyService.instance.decryptSymmetric(
          ciphertext: ct,
          passphrase: passphrase,
        );
        setState(() {
          _sigStatus = 'Symmetric — no signature';
          _sigColor = scheme.onSurfaceVariant;
        });
      } else {
        if (_selectedIdentity == null && _secretKeys.isEmpty) {
          _showSnack('No private keys. Generate or import one in the Keys tab.', error: true);
          setState(() => _loading = false);
          return;
        }
        final identity = _selectedIdentity ?? _secretKeys.first;
        final passphrase = await showPassphraseDialog(context, confirm: false);
        if (passphrase == null) {
          setState(() => _loading = false);
          return;
        }
        final result = await KeyService.instance.decryptText(
          ciphertext: ct,
          identity: identity,
          passphrase: passphrase,
        );
        plaintext = result.plaintext;
        setState(() {
          switch (result.signatureStatus) {
            case SignatureStatus.good:
              _sigStatus = '✓ Good signature from ${result.signerUid ?? "known key"}';
              _sigColor = Colors.green;
            case SignatureStatus.bad:
              _sigStatus = '✗ BAD SIGNATURE — do not trust this message';
              _sigColor = scheme.error;
            case SignatureStatus.unknownKey:
              _sigStatus = '? Signed by unknown key — import sender\'s public key';
              _sigColor = Colors.orange;
            case SignatureStatus.none:
              _sigStatus = 'No signature detected';
              _sigColor = scheme.onSurfaceVariant;
          }
        });
      }

      setState(() => _plaintextController.text = plaintext);
    } catch (e) {
      String msg = e.toString();
      if (msg.contains('passphrase') || msg.contains('password')) {
        msg = 'Wrong passphrase.';
      } else if (msg.contains('no valid')) {
        msg = 'Not a valid PGP message. Make sure you copied the full block.';
      } else if (msg.contains('secret key')) {
        msg = 'This message was not encrypted to any key on this device.';
      }
      _showSnack(msg, error: true);
    } finally {
      setState(() => _loading = false);
    }
  }

  void _clear() {
    _ciphertextController.clear();
    _plaintextController.clear();
    setState(() {
      _sigStatus = null;
      _sigColor = null;
    });
  }

  void _showSnack(String msg, {bool error = false}) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content: Text(msg),
      backgroundColor: error ? Theme.of(context).colorScheme.error : null,
    ));
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Decrypt'),
        actions: [
          IconButton(
            icon: const Icon(Icons.delete_sweep_outlined),
            tooltip: 'Clear all',
            onPressed: _clear,
          ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          // ── Method ────────────────────────────────────────────────────────
          const SectionHeader('Encryption Method'),
          const SizedBox(height: 8),
          SegmentedButton<String>(
            segments: const [
              ButtonSegment(value: 'Auto', label: Text('Auto')),
              ButtonSegment(value: 'PGP Key', label: Text('PGP Key')),
              ButtonSegment(value: 'Passphrase', label: Text('Passphrase')),
            ],
            selected: {_method},
            onSelectionChanged: (s) => setState(() => _method = s.first),
          ),
          const SizedBox(height: 16),

          // ── Identity selector (PGP mode) ──────────────────────────────────
          if (_method == 'PGP Key' && _secretKeys.length > 1) ...[
            const SectionHeader('Your Identity'),
            const SizedBox(height: 8),
            DropdownButtonFormField<PgpKey>(
              value: _selectedIdentity,
              hint: const Text('Auto-detect (try all keys)'),
              decoration: const InputDecoration(),
              items: _secretKeys.map((k) => DropdownMenuItem(
                value: k,
                child: Text(k.displayLabel, overflow: TextOverflow.ellipsis),
              )).toList(),
              onChanged: (k) => setState(() => _selectedIdentity = k),
            ),
            const SizedBox(height: 16),
          ],

          // ── PGP message input ─────────────────────────────────────────────
          const SectionHeader('Paste PGP Message'),
          const SizedBox(height: 8),
          TextField(
            controller: _ciphertextController,
            maxLines: 6,
            style: const TextStyle(fontFamily: 'monospace', fontSize: 12),
            decoration: const InputDecoration(
              hintText: '-----BEGIN PGP MESSAGE-----\n…\n-----END PGP MESSAGE-----',
              alignLabelWithHint: true,
            ),
          ),
          const SizedBox(height: 8),
          OutlinedButton.icon(
            onPressed: _pasteFromClipboard,
            icon: const Icon(Icons.paste, size: 18),
            label: const Text('Paste from Clipboard'),
          ),
          const SizedBox(height: 16),

          // ── Decrypt button ────────────────────────────────────────────────
          FilledButton.icon(
            onPressed: _loading ? null : _decrypt,
            icon: _loading
                ? const SizedBox(
                    width: 18,
                    height: 18,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : const Icon(Icons.lock_open),
            label: Text(_loading ? 'Decrypting…' : 'Decrypt'),
          ),
          const SizedBox(height: 16),

          // ── Signature status ──────────────────────────────────────────────
          if (_sigStatus != null) ...[
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: scheme.surfaceContainerHighest,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: _sigColor ?? scheme.outline),
              ),
              child: Row(
                children: [
                  Icon(Icons.verified_outlined, color: _sigColor, size: 20),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      _sigStatus!,
                      style: TextStyle(color: _sigColor),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),
          ],

          // ── Plaintext output ──────────────────────────────────────────────
          if (_plaintextController.text.isNotEmpty) ...[
            const SectionHeader('Decrypted Message'),
            const SizedBox(height: 8),
            Container(
              decoration: BoxDecoration(
                color: scheme.surfaceContainerHighest,
                borderRadius: BorderRadius.circular(12),
              ),
              padding: const EdgeInsets.all(12),
              child: SelectableText(
                _plaintextController.text,
                style: const TextStyle(fontSize: 15),
              ),
            ),
            const SizedBox(height: 8),
            Text(
              '⚠  Decrypted text is displayed only. It is never saved or logged.',
              style: TextStyle(
                fontSize: 12,
                color: scheme.onSurfaceVariant,
              ),
            ),
          ],
        ],
      ),
    );
  }
}
