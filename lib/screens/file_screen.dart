import 'dart:io';
import 'package:flutter/material.dart';
import 'package:file_picker/file_picker.dart';
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';
import '../services/key_service.dart';
import '../models/pgp_key.dart';
import '../widgets/passphrase_dialog.dart';
import '../widgets/section_header.dart';

class FileScreen extends StatefulWidget {
  const FileScreen({super.key});

  @override
  State<FileScreen> createState() => _FileScreenState();
}

class _FileScreenState extends State<FileScreen> {
  PlatformFile? _selectedFile;
  String _method = 'Passphrase';
  PgpKey? _selectedRecipient;
  bool _loading = false;
  String? _statusMessage;
  bool _statusError = false;

  List<PgpKey> get _publicKeys => KeyService.instance.publicKeys;

  Future<void> _pickFile() async {
    final result = await FilePicker.platform.pickFiles(
      allowMultiple: false,
      withData: true,
    );
    if (result != null && result.files.isNotEmpty) {
      setState(() {
        _selectedFile = result.files.first;
        _statusMessage = null;
      });
    }
  }

  Future<void> _encryptFile() async {
    if (_selectedFile == null || _selectedFile!.bytes == null) {
      _setStatus('Select a file first.', error: true);
      return;
    }

    setState(() => _loading = true);

    try {
      List<int> encrypted;

      if (_method == 'Passphrase') {
        final passphrase = await showPassphraseDialog(context, confirm: true);
        if (passphrase == null) {
          setState(() => _loading = false);
          return;
        }
        encrypted = await KeyService.instance.encryptFileSymmetric(
          fileBytes: _selectedFile!.bytes!,
          passphrase: passphrase,
        );
      } else {
        if (_selectedRecipient == null) {
          _setStatus('Select a recipient.', error: true);
          setState(() => _loading = false);
          return;
        }
        encrypted = await KeyService.instance.encryptFile(
          fileBytes: _selectedFile!.bytes!,
          recipient: _selectedRecipient!,
        );
      }

      // Save to temp directory and share
      final dir = await getTemporaryDirectory();
      final outName = '${_selectedFile!.name}.gpg';
      final outFile = File('${dir.path}/$outName');
      await outFile.writeAsBytes(encrypted);

      await Share.shareXFiles(
        [XFile(outFile.path)],
        text: 'Encrypted file: $outName',
      );

      _setStatus('✓ Encrypted: $outName\nFile ready to share.');
    } catch (e) {
      _setStatus('Encryption failed: $e', error: true);
    } finally {
      setState(() => _loading = false);
    }
  }

  Future<void> _decryptFile() async {
    if (_selectedFile == null || _selectedFile!.bytes == null) {
      _setStatus('Select a .gpg file to decrypt.', error: true);
      return;
    }

    if (!(_selectedFile!.name.endsWith('.gpg'))) {
      _setStatus('Select a file ending in .gpg to decrypt.', error: true);
      return;
    }

    setState(() => _loading = true);

    try {
      List<int> decrypted;

      if (_method == 'Passphrase') {
        final passphrase = await showPassphraseDialog(context, confirm: false);
        if (passphrase == null) {
          setState(() => _loading = false);
          return;
        }
        decrypted = await KeyService.instance.decryptFileSymmetric(
          encryptedBytes: _selectedFile!.bytes!,
          passphrase: passphrase,
        );
      } else {
        final keys = KeyService.instance.secretKeys;
        if (keys.isEmpty) {
          _setStatus('No private keys found. Generate or import one in the Keys tab.', error: true);
          setState(() => _loading = false);
          return;
        }
        final passphrase = await showPassphraseDialog(context, confirm: false);
        if (passphrase == null) {
          setState(() => _loading = false);
          return;
        }
        // Try each secret key until one works
        Exception? lastError;
        List<int>? result;
        for (final key in keys) {
          try {
            result = await KeyService.instance.decryptFile(
              encryptedBytes: _selectedFile!.bytes!,
              identity: key,
              passphrase: passphrase,
            );
            break;
          } catch (e) {
            lastError = Exception(e.toString());
          }
        }
        if (result == null) {
          throw lastError ?? Exception('Decryption failed for all keys.');
        }
        decrypted = result;
      }

      // Strip .gpg extension
      final outName = _selectedFile!.name.replaceAll(RegExp(r'\.gpg$'), '');
      final dir = await getTemporaryDirectory();
      final outFile = File('${dir.path}/$outName');
      await outFile.writeAsBytes(decrypted);

      await Share.shareXFiles(
        [XFile(outFile.path)],
        text: 'Decrypted: $outName',
      );

      _setStatus('✓ Decrypted: $outName\nFile ready.');
    } catch (e) {
      String msg = e.toString();
      if (msg.contains('passphrase') || msg.contains('password')) {
        msg = 'Wrong passphrase.';
      }
      _setStatus('Decryption failed: $msg', error: true);
    } finally {
      setState(() => _loading = false);
    }
  }

  void _setStatus(String msg, {bool error = false}) {
    setState(() {
      _statusMessage = msg;
      _statusError = error;
    });
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;

    return Scaffold(
      appBar: AppBar(title: const Text('File Encrypt')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          // ── Method ────────────────────────────────────────────────────────
          const SectionHeader('Encryption Method'),
          const SizedBox(height: 8),
          SegmentedButton<String>(
            segments: const [
              ButtonSegment(value: 'Passphrase', label: Text('Passphrase')),
              ButtonSegment(value: 'PGP Key', label: Text('PGP Key')),
            ],
            selected: {_method},
            onSelectionChanged: (s) => setState(() => _method = s.first),
          ),
          const SizedBox(height: 16),

          // ── Recipient (PGP mode) ──────────────────────────────────────────
          if (_method == 'PGP Key') ...[
            const SectionHeader('Recipient'),
            const SizedBox(height: 8),
            _publicKeys.isEmpty
                ? Card(
                    child: Padding(
                      padding: const EdgeInsets.all(16),
                      child: Text('No contacts. Import a public key in the Keys tab.',
                          style: TextStyle(color: scheme.onSurfaceVariant)),
                    ),
                  )
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
          ],

          // ── File picker ───────────────────────────────────────────────────
          const SectionHeader('File'),
          const SizedBox(height: 8),
          OutlinedButton.icon(
            onPressed: _pickFile,
            icon: const Icon(Icons.folder_open),
            label: const Text('Choose File'),
          ),
          if (_selectedFile != null) ...[
            const SizedBox(height: 8),
            Card(
              child: ListTile(
                leading: const Icon(Icons.insert_drive_file_outlined),
                title: Text(_selectedFile!.name),
                subtitle: Text(_formatSize(_selectedFile!.size)),
              ),
            ),
          ],
          const SizedBox(height: 16),

          // ── Action buttons ────────────────────────────────────────────────
          Row(
            children: [
              Expanded(
                child: FilledButton.icon(
                  onPressed: _loading ? null : _encryptFile,
                  icon: const Icon(Icons.lock, size: 18),
                  label: const Text('Encrypt'),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: _loading ? null : _decryptFile,
                  icon: const Icon(Icons.lock_open, size: 18),
                  label: const Text('Decrypt'),
                ),
              ),
            ],
          ),

          if (_loading) ...[
            const SizedBox(height: 16),
            const LinearProgressIndicator(),
          ],

          // ── Status ────────────────────────────────────────────────────────
          if (_statusMessage != null) ...[
            const SizedBox(height: 16),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: _statusError
                    ? scheme.errorContainer
                    : scheme.secondaryContainer,
                borderRadius: BorderRadius.circular(12),
              ),
              child: Text(
                _statusMessage!,
                style: TextStyle(
                  color: _statusError
                      ? scheme.onErrorContainer
                      : scheme.onSecondaryContainer,
                ),
              ),
            ),
          ],

          const SizedBox(height: 16),
          Text(
            'Encrypted files are shared via the Android share sheet.\n'
            'Decrypted files are shared the same way — nothing is saved to storage without your action.',
            style: TextStyle(fontSize: 12, color: scheme.onSurfaceVariant),
          ),
        ],
      ),
    );
  }

  String _formatSize(int bytes) {
    if (bytes < 1024) return '$bytes B';
    if (bytes < 1048576) return '${(bytes / 1024).toStringAsFixed(1)} KB';
    return '${(bytes / 1048576).toStringAsFixed(1)} MB';
  }
}
