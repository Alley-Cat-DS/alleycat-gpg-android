# Security Policy

## Project: AlleyCat GPG — Android

AlleyCat GPG Android is a Flutter-based OpenPGP encryption app for Android.
All cryptographic operations are handled by the open-source
[openpgp](https://pub.dev/packages/openpgp) Dart library.
Private keys are stored in Android's encrypted KeyStore via
flutter_secure_storage. This project takes security seriously and
appreciates responsible disclosure.

---

## Supported Versions

| Version | Supported |
|---------|-----------|
| 1.x (latest) | ✅ Active |

Always use the latest release from the
[Releases page](../../releases).

---

## Reporting a Vulnerability

**Do not open a public GitHub issue for security vulnerabilities.**

Report privately to:

📧 **alleycat.elite337@passmail.net**

Please include:

- A clear description of the vulnerability
- Steps to reproduce
- Potential impact
- Your suggested fix (if any)
- Android version and device if relevant

You will receive an acknowledgment within **48 hours** and a status
update within **7 days**.

If a fix is warranted, we will:

1. Develop and test a patch
2. Release a patched version APK and update the Releases page
3. Credit you in the release notes (unless you prefer anonymity)
4. Publish a GitHub Security Advisory

---

## Security Design

### What it does

- Encrypts and decrypts text messages and files using OpenPGP
- All crypto via the [openpgp](https://pub.dev/packages/openpgp)
  Dart library — open source, no native code, auditable
- Private keys stored in Android's encrypted KeyStore via
  `flutter_secure_storage` with `encryptedSharedPreferences: true`
- Supports PGP public-key encryption and symmetric passphrase encryption
- QR code key exchange for easy contact onboarding

### What it does not do

- Does not implement custom cryptography
- Does not store plaintext messages or decrypted content
- Does not log passphrases, key material, or message contents
- Does not make network requests of any kind
- Does not send telemetry or analytics
- Does not sync keys to any server or cloud service
- Does not auto-copy plaintext to clipboard

### Known limitations

- **Not safe if your device is compromised.** Root access, malicious
  apps with elevated permissions, or a compromised Android kernel can
  defeat any app-level security.

- **Not a Signal replacement.** AlleyCat GPG encrypts content for
  delivery over any channel (SMS, email, etc.). It does not provide
  forward secrecy, metadata protection, or disappearing messages.

- **Key trust is your responsibility.** Always verify fingerprints
  out-of-band before trusting a contact's key.

- **iOS not yet supported.** Android only at this time.

---

## Threat Model

See [THREAT_MODEL.md](THREAT_MODEL.md) for a full threat model.

The desktop app's threat model also applies:
[gpg-messenger/THREAT_MODEL.md](https://github.com/Alley-Cat-DS/gpg-messenger/blob/main/THREAT_MODEL.md)
