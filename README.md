# AlleyCat GPG — Android

Encrypt and decrypt messages and files for secure SMS communication.
No ISP or cell tower visibility into your message content.

Built with Flutter. All cryptography via the open-source [openpgp](https://pub.dev/packages/openpgp) Dart library.
Private keys stored in Android's encrypted KeyStore. No network requests. No telemetry.

---

## Download

### Direct (no Play Store needed)

Go to [Releases](../../releases) and download the APK for your device:

| File | Use when |
|------|---------|
| `AlleyCat-GPG-*-universal.apk` | Not sure — use this |
| `AlleyCat-GPG-*-arm64.apk` | Modern phone (2017+) |
| `AlleyCat-GPG-*-arm32.apk` | Older phone |

Enable "Install from unknown sources" in Settings → Security, then open the APK.

### F-Droid

Coming soon — submission in progress.

---

## Features

- **Compose** — encrypt messages to PGP key recipients or with passphrase only
- **Decrypt** — paste PGP blocks with full signature status display
- **File Encrypt** — encrypt/decrypt any file (PDF, image, zip, etc.)
- **Key Management** — generate Ed25519 or RSA 4096 keypairs on-device
- **QR Code** — share your public key as QR, scan contacts' keys
- **Import** — paste armored public keys to import contacts

---

## Building from Source

Requires Flutter 3.24+.

```bash
git clone https://github.com/Alley-Cat-DS/alleycat-gpg-android
cd alleycat-gpg-android
flutter pub get
flutter run          # run on connected device
flutter build apk    # build APK
```

---

## Desktop App

The desktop companion app (macOS, Windows, Linux) lives at:
[github.com/Alley-Cat-DS/gpg-messenger](https://github.com/Alley-Cat-DS/gpg-messenger)

Keys can be shared between desktop and mobile via QR code export.

---

## Security

See [THREAT_MODEL.md](../gpg-messenger/THREAT_MODEL.md) in the desktop repo for the full threat model.

Report security issues privately to: **alleycat.elite337@passmail.net**

---

## License

MIT
