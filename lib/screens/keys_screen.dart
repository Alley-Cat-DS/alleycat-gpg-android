import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:qr_flutter/qr_flutter.dart';
import 'package:mobile_scanner/mobile_scanner.dart';
import '../services/key_service.dart';
import '../models/pgp_key.dart';
import '../widgets/passphrase_dialog.dart';
import '../widgets/section_header.dart';

class KeysScreen extends StatefulWidget {
  const KeysScreen({super.key});

  @override
  State<KeysScreen> createState() => _KeysScreenState();
}

class _KeysScreenState extends State<KeysScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Keys'),
        bottom: TabBar(
          controller: _tabController,
          tabs: const [
            Tab(text: 'My Keys'),
            Tab(text: 'Contacts'),
          ],
        ),
      ),
      body: TabBarView(
        controller: _tabController,
        children: const [
          _MyKeysTab(),
          _ContactsTab(),
        ],
      ),
    );
  }
}

// ── My Keys tab ───────────────────────────────────────────────────────────────

class _MyKeysTab extends StatefulWidget {
  const _MyKeysTab();

  @override
  State<_MyKeysTab> createState() => _MyKeysTabState();
}

class _MyKeysTabState extends State<_MyKeysTab> {
  @override
  Widget build(BuildContext context) {
    final keys = KeyService.instance.secretKeys;

    return Column(
      children: [
        Expanded(
          child: keys.isEmpty
              ? _EmptyState(
                  icon: Icons.key_off_outlined,
                  message: 'No private keys yet.\nGenerate your first keypair.',
                )
              : ListView.builder(
                  padding: const EdgeInsets.all(16),
                  itemCount: keys.length,
                  itemBuilder: (ctx, i) => _KeyCard(
                    pgpKey: keys[i],
                    showExport: true,
                    onDelete: () async {
                      await KeyService.instance.deleteSecretKey(keys[i].fingerprint);
                      setState(() {});
                    },
                  ),
                ),
        ),
        Padding(
          padding: const EdgeInsets.all(16),
          child: FilledButton.icon(
            onPressed: () => _showGenerateDialog(context),
            icon: const Icon(Icons.add),
            label: const Text('Generate New Keypair'),
          ),
        ),
      ],
    );
  }

  Future<void> _showGenerateDialog(BuildContext context) async {
    final nameCtrl = TextEditingController();
    final emailCtrl = TextEditingController();
    final commentCtrl = TextEditingController();
    String keyType = 'ed25519';
    String expiry = '2y';

    final result = await showDialog<bool>(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setS) => AlertDialog(
          title: const Text('Generate Keypair'),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextField(
                  controller: nameCtrl,
                  decoration: const InputDecoration(labelText: 'Full Name *'),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: emailCtrl,
                  decoration: const InputDecoration(labelText: 'Email *'),
                  keyboardType: TextInputType.emailAddress,
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: commentCtrl,
                  decoration: const InputDecoration(labelText: 'Comment (optional)'),
                ),
                const SizedBox(height: 16),
                DropdownButtonFormField<String>(
                  value: keyType,
                  decoration: const InputDecoration(labelText: 'Key Type'),
                  items: const [
                    DropdownMenuItem(value: 'ed25519', child: Text('Ed25519 (recommended)')),
                    DropdownMenuItem(value: 'rsa', child: Text('RSA 4096 (compatible)')),
                  ],
                  onChanged: (v) => setS(() => keyType = v!),
                ),
                const SizedBox(height: 12),
                DropdownButtonFormField<String>(
                  value: expiry,
                  decoration: const InputDecoration(labelText: 'Expires'),
                  items: const [
                    DropdownMenuItem(value: 'never', child: Text('Never')),
                    DropdownMenuItem(value: '1y', child: Text('1 year')),
                    DropdownMenuItem(value: '2y', child: Text('2 years')),
                    DropdownMenuItem(value: '5y', child: Text('5 years')),
                  ],
                  onChanged: (v) => setS(() => expiry = v!),
                ),
              ],
            ),
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancel')),
            FilledButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('Generate')),
          ],
        ),
      ),
    );

    if (result != true) return;

    final name = nameCtrl.text.trim();
    final email = emailCtrl.text.trim();
    if (name.isEmpty || email.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Name and email are required.')),
      );
      return;
    }

    final passphrase = await showPassphraseDialog(context, confirm: true,
        title: 'Set Key Passphrase',
        hint: 'Protects your private key on this device');
    if (passphrase == null) return;

    try {
      if (!mounted) return;
      showDialog(
        context: context,
        barrierDismissible: false,
        builder: (_) => const AlertDialog(
          content: Row(
            children: [
              CircularProgressIndicator(),
              SizedBox(width: 16),
              Text('Generating keypair…'),
            ],
          ),
        ),
      );

      final key = await KeyService.instance.generateKey(
        name: name,
        email: email,
        passphrase: passphrase,
        comment: commentCtrl.text.trim().isEmpty ? null : commentCtrl.text.trim(),
        keyType: keyType == 'ed25519' ? KeyType.ed25519 : KeyType.rsa,
      );

      if (!mounted) return;
      Navigator.pop(context); // close progress
      setState(() {});

      _showFingerprintDialog(context, key);
    } catch (e) {
      if (!mounted) return;
      Navigator.pop(context);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Key generation failed: $e'),
            backgroundColor: Theme.of(context).colorScheme.error),
      );
    }
  }

  void _showFingerprintDialog(BuildContext context, PgpKey key) {
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Keypair Generated ✓'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(key.primaryUid),
            const SizedBox(height: 12),
            const Text('Fingerprint:', style: TextStyle(fontWeight: FontWeight.bold)),
            const SizedBox(height: 4),
            SelectableText(
              key.formattedFingerprint,
              style: const TextStyle(fontFamily: 'monospace', fontSize: 13),
            ),
            const SizedBox(height: 12),
            const Text(
              '⚠  Verify this fingerprint with contacts through a trusted channel '
              'before they encrypt anything to you.',
              style: TextStyle(fontSize: 12),
            ),
          ],
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text('Done')),
        ],
      ),
    );
  }
}

// ── Contacts tab ──────────────────────────────────────────────────────────────

class _ContactsTab extends StatefulWidget {
  const _ContactsTab();

  @override
  State<_ContactsTab> createState() => _ContactsTabState();
}

class _ContactsTabState extends State<_ContactsTab> {
  @override
  Widget build(BuildContext context) {
    final keys = KeyService.instance.publicKeys
        .where((k) => !KeyService.instance.secretKeys
            .any((s) => s.fingerprint == k.fingerprint))
        .toList();

    return Column(
      children: [
        Expanded(
          child: keys.isEmpty
              ? _EmptyState(
                  icon: Icons.people_outline,
                  message: 'No contacts yet.\nImport a public key or scan a QR code.',
                )
              : ListView.builder(
                  padding: const EdgeInsets.all(16),
                  itemCount: keys.length,
                  itemBuilder: (ctx, i) => _KeyCard(
                    pgpKey: keys[i],
                    showExport: false,
                    onDelete: () async {
                      await KeyService.instance.deletePublicKey(keys[i].fingerprint);
                      setState(() {});
                    },
                  ),
                ),
        ),
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
          child: Row(
            children: [
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: () => _showImportDialog(context),
                  icon: const Icon(Icons.paste),
                  label: const Text('Paste Key'),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: FilledButton.icon(
                  onPressed: () => _showQrScanner(context),
                  icon: const Icon(Icons.qr_code_scanner),
                  label: const Text('Scan QR'),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Future<void> _showImportDialog(BuildContext context) async {
    final ctrl = TextEditingController();
    final result = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Import Public Key'),
        content: TextField(
          controller: ctrl,
          maxLines: 8,
          style: const TextStyle(fontFamily: 'monospace', fontSize: 11),
          decoration: const InputDecoration(
            hintText: '-----BEGIN PGP PUBLIC KEY BLOCK-----\n…',
            alignLabelWithHint: true,
          ),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Cancel')),
          FilledButton(onPressed: () => Navigator.pop(context, true), child: const Text('Import')),
        ],
      ),
    );

    if (result != true || ctrl.text.trim().isEmpty) return;

    try {
      final key = await KeyService.instance.importPublicKey(ctrl.text.trim());
      if (!mounted) return;
      setState(() {});
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Imported: ${key.primaryUid}')),
      );
      _showFingerprintWarning(context, key);
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Import failed: $e'),
            backgroundColor: Theme.of(context).colorScheme.error),
      );
    }
  }

  Future<void> _showQrScanner(BuildContext context) async {
    final scanned = await Navigator.push<String>(
      context,
      MaterialPageRoute(builder: (_) => const _QrScannerScreen()),
    );
    if (scanned == null || !mounted) return;

    try {
      final key = await KeyService.instance.importPublicKey(scanned);
      setState(() {});
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Imported via QR: ${key.primaryUid}')),
      );
      _showFingerprintWarning(context, key);
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('QR import failed: $e'),
            backgroundColor: Theme.of(context).colorScheme.error),
      );
    }
  }

  void _showFingerprintWarning(BuildContext context, PgpKey key) {
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Verify Fingerprint'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Imported: ${key.primaryUid}'),
            const SizedBox(height: 12),
            SelectableText(
              key.formattedFingerprint,
              style: const TextStyle(fontFamily: 'monospace', fontSize: 13),
            ),
            const SizedBox(height: 12),
            const Text(
              '⚠  Verify this fingerprint with the contact through a trusted '
              'channel (phone call, in person) before sending encrypted messages.',
              style: TextStyle(fontSize: 12),
            ),
          ],
        ),
        actions: [
          FilledButton(onPressed: () => Navigator.pop(context), child: const Text('Understood')),
        ],
      ),
    );
  }
}

// ── QR Scanner screen ─────────────────────────────────────────────────────────

class _QrScannerScreen extends StatefulWidget {
  const _QrScannerScreen();

  @override
  State<_QrScannerScreen> createState() => _QrScannerScreenState();
}

class _QrScannerScreenState extends State<_QrScannerScreen> {
  final _controller = MobileScannerController();
  bool _scanned = false;

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Scan QR Code')),
      body: MobileScanner(
        controller: _controller,
        onDetect: (capture) {
          if (_scanned) return;
          final barcode = capture.barcodes.firstOrNull;
          final value = barcode?.rawValue;
          if (value != null) {
            _scanned = true;
            Navigator.pop(context, value);
          }
        },
      ),
    );
  }
}

// ── Key card widget ───────────────────────────────────────────────────────────

class _KeyCard extends StatelessWidget {
  final PgpKey pgpKey;
  final bool showExport;
  final VoidCallback onDelete;

  const _KeyCard({
    required this.pgpKey,
    required this.showExport,
    required this.onDelete,
  });

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;

    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(pgpKey.primaryUid,
                style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 15)),
            const SizedBox(height: 4),
            Text(pgpKey.shortKeyId,
                style: TextStyle(fontFamily: 'monospace', color: scheme.primary, fontSize: 13)),
            if (pgpKey.isExpired)
              Padding(
                padding: const EdgeInsets.only(top: 4),
                child: Text('EXPIRED', style: TextStyle(color: scheme.error, fontSize: 12)),
              ),
            const SizedBox(height: 12),
            Row(
              children: [
                TextButton.icon(
                  onPressed: () => _showFingerprint(context),
                  icon: const Icon(Icons.fingerprint, size: 18),
                  label: const Text('Fingerprint'),
                ),
                if (showExport)
                  TextButton.icon(
                    onPressed: () => _showQrExport(context),
                    icon: const Icon(Icons.qr_code, size: 18),
                    label: const Text('Share QR'),
                  ),
                const Spacer(),
                IconButton(
                  icon: Icon(Icons.delete_outline, color: scheme.error),
                  onPressed: () => _confirmDelete(context),
                  tooltip: 'Delete',
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  void _showFingerprint(BuildContext context) {
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Key Fingerprint'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(pgpKey.primaryUid),
            const SizedBox(height: 12),
            SelectableText(
              pgpKey.formattedFingerprint,
              style: const TextStyle(fontFamily: 'monospace', fontSize: 14),
            ),
            const SizedBox(height: 12),
            const Text(
              'Verify this fingerprint with the person through a trusted channel '
              'before relying on this key.',
              style: TextStyle(fontSize: 12),
            ),
          ],
        ),
        actions: [
          FilledButton(onPressed: () => Navigator.pop(context), child: const Text('Close')),
        ],
      ),
    );
  }

  void _showQrExport(BuildContext context) {
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Share Public Key'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            QrImageView(
              data: pgpKey.armoredPublic,
              version: QrVersions.auto,
              size: 240,
              backgroundColor: Colors.white,
            ),
            const SizedBox(height: 12),
            const Text(
              'Have the other person scan this QR code in their AlleyCat GPG app '
              'to import your public key.',
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 12),
            ),
            const SizedBox(height: 8),
            OutlinedButton.icon(
              onPressed: () {
                Clipboard.setData(ClipboardData(text: pgpKey.armoredPublic));
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('Public key copied to clipboard.')),
                );
              },
              icon: const Icon(Icons.copy, size: 16),
              label: const Text('Copy Armored Key'),
            ),
          ],
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text('Close')),
        ],
      ),
    );
  }

  void _confirmDelete(BuildContext context) {
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Delete Key?'),
        content: Text('Delete ${pgpKey.primaryUid}?\n\nThis cannot be undone.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancel')),
          FilledButton(
            style: FilledButton.styleFrom(
              backgroundColor: Theme.of(context).colorScheme.error,
            ),
            onPressed: () {
              Navigator.pop(context);
              onDelete();
            },
            child: const Text('Delete'),
          ),
        ],
      ),
    );
  }
}

// ── Empty state widget ────────────────────────────────────────────────────────

class _EmptyState extends StatelessWidget {
  final IconData icon;
  final String message;

  const _EmptyState({required this.icon, required this.message});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(icon, size: 64, color: Theme.of(context).colorScheme.outlineVariant),
          const SizedBox(height: 16),
          Text(
            message,
            textAlign: TextAlign.center,
            style: TextStyle(color: Theme.of(context).colorScheme.onSurfaceVariant),
          ),
        ],
      ),
    );
  }
}
