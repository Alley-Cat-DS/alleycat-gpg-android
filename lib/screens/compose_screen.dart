import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../services/key_service.dart';
import '../models/pgp_key.dart';
import '../widgets/passphrase_dialog.dart';
import '../widgets/section_header.dart';

class ComposeScreen extends StatefulWidget {
  const ComposeScreen({super.key});

  @override
  State<ComposeScreen> createState() => _ComposeScreenState();
}

class _ComposeScreenState extends State<ComposeScreen> {
  final _messageController = TextEditingController();
  final _ciphertextController = TextEditingController();

  String _method = 'PGP Key';
  PgpKey? _selectedRecipient;
  PgpKey? _selectedSender;
  bool _sign = false;
  bool _loading = false;

  @override
  void dispose() {
    _messageController.dispose();
    _ciphertextController.dispose();
    super.dispose();
  }

  List<PgpKey> get _publicKeys => KeyService.instance.publicKeys;
  List<PgpKey> get _secretKeys => KeyService.instance.secretKeys;

  Future<void> _encrypt() async {
    final message = _messageController.text.trim();
    if (message.isEmpty) {
      _showSnack('Enter a message to encrypt.');
      return;
    }

    setState(() => _loading = true);

    try {
      String ciphertext;

      if (_method == 'Passphrase') {
        final passphrase = await showPassphraseDialog(context, confirm: true);
        if (passphrase == null || passphrase.isEmpty) {
          setState(() => _loading = false);
          return;
        }
        ciphertext = await KeyService.instance.encryptSymmetric(
          plaintext: message,
          passphrase: passphrase,
        );
      } else {
        if (_selectedRecipient == null) {
          _showSnack('Select a recipient.');
          setState(() => _loading = false);
          return;
        }
        String? passphrase;
        if (_sign && _selectedSender != null) {
          passphrase = await showPassphraseDialog(context, confirm: false);
          if (passphrase == null) {
            setState(() => _loading = false);
            return;
          }
        }
        ciphertext = await KeyService.instance.encryptText(
          plaintext: message,
          recipient: _selectedRecipient!,
          sender: _sign ? _selectedSender : null,
          senderPassphrase: passphrase,
        );
      }

      setState(() => _ciphertextController.text = ciphertext);
    } catch (e) {
      _showSnack('Encryption failed: $e', error: true);
    } finally {
      setState(() => _loading = false);
    }
  }

  void _copyToClipboard() {
    final ct = _ciphertextController.text;
    if (ct.isEmpty) {
      _showSnack('Nothing to copy — encrypt a message first.');
      return;
    }
    Clipboard.setData(ClipboardData(text: ct));
    _showSnack('Ciphertext copied. Paste it into your SMS app.');
  }

  void _clear() {
    _messageController.clear();
    _ciphertextController.clear();
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
        title: const Text('Compose'),
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
          // ── Method selector ────────────────────────────────────────────────
          const SectionHeader('Encryption Method'),
          const SizedBox(height: 8),
          SegmentedButton<String>(
            segments: const [
              ButtonSegment(value: 'PGP Key', label: Text('PGP Key')),
              ButtonSegment(value: 'Passphrase', label: Text('Passphrase Only')),
            ],
            selected: {_method},
            onSelectionChanged: (s) => setState(() => _method = s.first),
          ),
          const SizedBox(height: 16),

          // ── PGP Key options ───────────────────────────────────────────────
          if (_method == 'PGP Key') ...[
            const SectionHeader('Recipient'),
            const SizedBox(height: 8),
            _publicKeys.isEmpty
                ? _emptyKeyCard('No contacts yet. Import a public key in the Keys tab.')
                : DropdownButtonFormField<PgpKey>(
                    value: _selectedRecipient,
                    hint: const Text('Select recipient'),
                    decoration: const InputDecoration(),
                    items: _publicKeys.map((k) => DropdownMenuItem(
                      value: k,
                      child: Text(k.displayLabel, overflow: TextOverflow.ellipsis),
                    )).toList(),
                    onChanged: (k) => setState(() => _selectedRecipient = k),
                  ),
            const SizedBox(height: 16),

            // Sign toggle
            SwitchListTile(
              title: const Text('Sign message'),
              subtitle: const Text('Prove this message is from you'),
              value: _sign,
              onChanged: (v) => setState(() => _sign = v),
              contentPadding: EdgeInsets.zero,
            ),

            if (_sign) ...[
              const SizedBox(height: 8),
              const SectionHeader('Your Identity (sender)'),
              const SizedBox(height: 8),
              _secretKeys.isEmpty
                  ? _emptyKeyCard('No private keys. Generate one in the Keys tab.')
                  : DropdownButtonFormField<PgpKey>(
                      value: _selectedSender,
                      hint: const Text('Select your identity'),
                      decoration: const InputDecoration(),
                      items: _secretKeys.map((k) => DropdownMenuItem(
                        value: k,
                        child: Text(k.displayLabel, overflow: TextOverflow.ellipsis),
                      )).toList(),
                      onChanged: (k) => setState(() => _selectedSender = k),
                    ),
            ],
            const SizedBox(height: 16),
          ],

          // ── Passphrase note ───────────────────────────────────────────────
          if (_method == 'Passphrase') ...[
            Card(
              color: scheme.tertiaryContainer,
              child: Padding(
                padding: const EdgeInsets.all(12),
                child: Row(
                  children: [
                    Icon(Icons.info_outline, color: scheme.onTertiaryContainer),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Text(
                        'You will be prompted to enter a passphrase. '
                        'Share it with the recipient through a separate secure channel.',
                        style: TextStyle(color: scheme.onTertiaryContainer),
                      ),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 16),
          ],

          // ── Message input ─────────────────────────────────────────────────
          const SectionHeader('Message'),
          const SizedBox(height: 8),
          TextField(
            controller: _messageController,
            maxLines: 6,
            decoration: const InputDecoration(
              hintText: 'Type your message here…',
              alignLabelWithHint: true,
            ),
          ),
          const SizedBox(height: 16),

          // ── Encrypt button ─────────────────────────────────────────────────
          FilledButton.icon(
            onPressed: _loading ? null : _encrypt,
            icon: _loading
                ? const SizedBox(
                    width: 18,
                    height: 18,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : const Icon(Icons.lock),
            label: Text(_loading ? 'Encrypting…' : 'Encrypt'),
          ),
          const SizedBox(height: 24),

          // ── Ciphertext output ──────────────────────────────────────────────
          if (_ciphertextController.text.isNotEmpty) ...[
            const SectionHeader('Ciphertext — Copy and send via SMS'),
            const SizedBox(height: 8),
            Container(
              decoration: BoxDecoration(
                color: scheme.surfaceContainerHighest,
                borderRadius: BorderRadius.circular(12),
              ),
              padding: const EdgeInsets.all(12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  SelectableText(
                    _ciphertextController.text,
                    style: const TextStyle(fontFamily: 'monospace', fontSize: 12),
                  ),
                  const SizedBox(height: 8),
                  FilledButton.tonalIcon(
                    onPressed: _copyToClipboard,
                    icon: const Icon(Icons.copy, size: 18),
                    label: const Text('Copy to Clipboard'),
                  ),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _emptyKeyCard(String msg) => Card(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Text(msg, style: TextStyle(color: Theme.of(context).colorScheme.onSurfaceVariant)),
        ),
      );
}
