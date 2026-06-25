class PgpKey {
  final String id;
  final String fingerprint;
  final List<String> uids;
  final String armoredPublic;
  final String? armoredPrivate; // null for contact keys
  final DateTime? expires;
  final DateTime created;
  final bool isSecret;

  const PgpKey({
    required this.id,
    required this.fingerprint,
    required this.uids,
    required this.armoredPublic,
    this.armoredPrivate,
    this.expires,
    required this.created,
    required this.isSecret,
  });

  String get primaryUid => uids.isNotEmpty ? uids.first : '(no UID)';

  String get shortKeyId => fingerprint.length >= 8
      ? '…${fingerprint.substring(fingerprint.length - 8)}'
      : fingerprint;

  String get formattedFingerprint {
    final fp = fingerprint.replaceAll(' ', '');
    final groups = <String>[];
    for (var i = 0; i < fp.length; i += 4) {
      final end = (i + 4 < fp.length) ? i + 4 : fp.length;
      groups.add(fp.substring(i, end));
    }
    return groups.join('  ');
  }

  bool get isExpired {
    if (expires == null) return false;
    return expires!.isBefore(DateTime.now());
  }

  String get displayLabel => '$primaryUid  $shortKeyId';

  Map<String, dynamic> toJson() => {
        'id': id,
        'fingerprint': fingerprint,
        'uids': uids,
        'armoredPublic': armoredPublic,
        'armoredPrivate': armoredPrivate,
        'expires': expires?.toIso8601String(),
        'created': created.toIso8601String(),
        'isSecret': isSecret,
      };

  factory PgpKey.fromJson(Map<String, dynamic> json) => PgpKey(
        id: json['id'] as String,
        fingerprint: json['fingerprint'] as String,
        uids: List<String>.from(json['uids'] as List),
        armoredPublic: json['armoredPublic'] as String,
        armoredPrivate: json['armoredPrivate'] as String?,
        expires: json['expires'] != null
            ? DateTime.parse(json['expires'] as String)
            : null,
        created: DateTime.parse(json['created'] as String),
        isSecret: json['isSecret'] as bool,
      );
}
