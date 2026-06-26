import 'dart:convert';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:openpgp/openpgp.dart';
import '../models/pgp_key.dart';

class KeyService {
  KeyService._();
  static final instance = KeyService._();

  static const _storage = FlutterSecureStorage(
    aOptions: AndroidOptions(encryptedSharedPreferences: true),
  );

  static const _secretKeysKey = 'secret_keys_v1';
  static const _publicKeysKey = 'public_keys_v1';

  List<PgpKey> _secretKeys = [];
  List<PgpKey> _publicKeys = [];

  List<PgpKey> get secretKeys => List.unmodifiable(_secretKeys);
  List<PgpKey> get publicKeys => List.unmodifiable(_publicKeys);

  Future<void> init() async {
    await _loadKeys();
  }

  Future<void> _loadKeys() async {
    try {
      final secretJson = await _storage.read(key: _secretKeysKey);
      final publicJson = await _storage.read(key: _publicKeysKey);
      if (secretJson != null) {
        final list = jsonDecode(secretJson) as List;
        _secretKeys = list.map((e) => PgpKey.fromJson(e as Map<String, dynamic>)).toList();
      }
      if (publicJson != null) {
        final list = jsonDecode(publicJson) as List;
        _publicKeys = list.map((e) => PgpKey.fromJson(e as Map<String, dynamic>)).toList();
      }
    } catch (e) {
      _secretKeys = [];
      _publicKeys = [];
    }
  }

  Future<void> _saveSecretKeys() async {
    await _storage.write(
      key: _secretKeysKey,
      value: jsonEncode(_secretKeys.map((k) => k.toJson()).toList()),
    );
  }

  Future<void> _savePublicKeys() async {
    await _storage.write(
      key: _publicKeysKey,
      value: jsonEncode(_publicKeys.map((k) => k.toJson()).toList()),
    );
  }

  Future<PgpKey> generateKey({
    required String name,
    required String email,
    required String passphrase,
    String? comment,
    KeyType keyType = KeyType.ed25519,
    int? expiryDays,
  }) async {
    final uid = comment != null && comment.isNotEmpty
        ? '\$name (\$comment) <\$email>'
        : '\$name <\$email>';

    final opts = Options()
      ..name = name
      ..comment = comment ?? ''
      ..email = email
      ..passphrase = passphrase
      ..keyOptions = (KeyOptions()
        ..rsaBits = keyType == KeyType.rsa ? 4096 : null);

    final result = await OpenPGP.generate(options: opts);

    final key = PgpKey(
      id: _extractKeyId(result.publicKey),
      fingerprint: await _extractFingerprint(result.publicKey),
      uids: [uid],
      armoredPublic: result.publicKey,
      armoredPrivate: result.privateKey,
      created: DateTime.now(),
      isSecret: true,
    );

    _secretKeys.add(key);
    _publicKeys.add(PgpKey(
      id: key.id,
      fingerprint: key.fingerprint,
      uids: key.uids,
      armoredPublic: key.armoredPublic,
      created: key.created,
      isSecret: false,
    ));

    await _saveSecretKeys();
    await _savePublicKeys();
    return key;
  }

  Future<PgpKey> importPublicKey(String armoredKey) async {
    final fingerprint = await _extractFingerprint(armoredKey);
    final uid = await _extractUid(armoredKey);

    if (_publicKeys.any((k) => k.fingerprint == fingerprint)) {
      throw Exception('This key is already in your contacts.');
    }

    final key = PgpKey(
      id: _extractKeyId(armoredKey),
      fingerprint: fingerprint,
      uids: [uid],
      armoredPublic: armoredKey,
      created: DateTime.now(),
      isSecret: false,
    );

    _publicKeys.add(key);
    await _savePublicKeys();
    return key;
  }

  Future<PgpKey> importPrivateKey(String armoredPrivate, String passphrase) async {
    final publicKey = await OpenPGP.convertPrivateKeyToPublicKey(armoredPrivate);
    final fingerprint = await _extractFingerprint(publicKey);
    final uid = await _extractUid(publicKey);

    if (_secretKeys.any((k) => k.fingerprint == fingerprint)) {
      throw Exception('This private key is already in your keyring.');
    }

    final key = PgpKey(
      id: _extractKeyId(publicKey),
      fingerprint: fingerprint,
      uids: [uid],
      armoredPublic: publicKey,
      armoredPrivate: armoredPrivate,
      created: DateTime.now(),
      isSecret: true,
    );

    _secretKeys.add(key);
    await _saveSecretKeys();
    return key;
  }

  Future<String> encryptText({
    required String plaintext,
    required PgpKey recipient,
    PgpKey? sender,
    String? senderPassphrase,
  }) async {
    return await OpenPGP.encrypt(plaintext, recipient.armoredPublic);
  }

  Future<String> encryptSymmetric({
    required String plaintext,
    required String passphrase,
  }) async {
    return await OpenPGP.encryptSymmetric(plaintext, passphrase);
  }

  Future<DecryptResult> decryptText({
    required String ciphertext,
    required PgpKey identity,
    required String passphrase,
  }) async {
    if (identity.armoredPrivate == null) {
      throw Exception('No private key available for this identity.');
    }
    try {
      final plaintext = await OpenPGP.decrypt(
        ciphertext,
        identity.armoredPrivate!,
        passphrase,
      );
      return DecryptResult(plaintext: plaintext, signatureStatus: SignatureStatus.none);
    } catch (e) {
      if (e.toString().contains('passphrase')) {
        throw Exception('Wrong passphrase.');
      }
      rethrow;
    }
  }

  Future<String> decryptSymmetric({
    required String ciphertext,
    required String passphrase,
  }) async {
    return await OpenPGP.decryptSymmetric(ciphertext, passphrase);
  }

  Future<List<int>> encryptFile({
    required List<int> fileBytes,
    required PgpKey recipient,
  }) async {
    final b64 = base64Encode(fileBytes);
    final encrypted = await OpenPGP.encrypt(b64, recipient.armoredPublic);
    return utf8.encode(encrypted);
  }

  Future<List<int>> encryptFileSymmetric({
    required List<int> fileBytes,
    required String passphrase,
  }) async {
    final b64 = base64Encode(fileBytes);
    final encrypted = await OpenPGP.encryptSymmetric(b64, passphrase);
    return utf8.encode(encrypted);
  }

  Future<List<int>> decryptFile({
    required List<int> encryptedBytes,
    required PgpKey identity,
    required String passphrase,
  }) async {
    if (identity.armoredPrivate == null) {
      throw Exception('No private key for this identity.');
    }
    final armored = utf8.decode(encryptedBytes);
    final b64 = await OpenPGP.decrypt(armored, identity.armoredPrivate!, passphrase);
    return base64Decode(b64);
  }

  Future<List<int>> decryptFileSymmetric({
    required List<int> encryptedBytes,
    required String passphrase,
  }) async {
    final armored = utf8.decode(encryptedBytes);
    final b64 = await OpenPGP.decryptSymmetric(armored, passphrase);
    return base64Decode(b64);
  }

  Future<void> deletePublicKey(String fingerprint) async {
    _publicKeys.removeWhere((k) => k.fingerprint == fingerprint);
    await _savePublicKeys();
  }

  Future<void> deleteSecretKey(String fingerprint) async {
    _secretKeys.removeWhere((k) => k.fingerprint == fingerprint);
    await _saveSecretKeys();
  }

  String _extractKeyId(String armoredKey) {
    return armoredKey.hashCode.toRadixString(16).padLeft(8, '0').toUpperCase();
  }

  Future<String> _extractFingerprint(String armoredKey) async {
    try {
      final info = await OpenPGP.getPublicKeyMetadata(armoredKey);
      return info.fingerprint ?? armoredKey.hashCode.toRadixString(16).toUpperCase();
    } catch (_) {
      return armoredKey.hashCode.toRadixString(16).toUpperCase();
    }
  }

  Future<String> _extractUid(String armoredKey) async {
    try {
      final info = await OpenPGP.getPublicKeyMetadata(armoredKey);
      return info.keyId ?? 'Unknown';
    } catch (_) {
      return 'Unknown';
    }
  }
}

enum SignatureStatus { none, good, bad, unknownKey }

class DecryptResult {
  final String plaintext;
  final SignatureStatus signatureStatus;
  final String? signerUid;

  const DecryptResult({
    required this.plaintext,
    required this.signatureStatus,
    this.signerUid,
  });
}

enum KeyType { ed25519, rsa }
