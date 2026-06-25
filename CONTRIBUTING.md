# Contributing to AlleyCat GPG Android

Thanks for your interest. AlleyCat GPG Android is a solo-maintained
project that welcomes pull requests from anyone.

---

## Ground Rules

1. **No new network permissions.** This app makes zero network requests
   and must stay that way. Do not add any networking, syncing, or
   cloud features.

2. **No custom cryptography.** All crypto must go through the
   [openpgp](https://pub.dev/packages/openpgp) Dart library or an
   equally well-audited open-source replacement. Do not implement
   cryptographic primitives.

3. **No plaintext storage.** Do not add any feature that saves,
   logs, or caches plaintext messages, passphrases, or decrypted
   content anywhere on the device.

4. **Open source dependencies only.** All packages must be available
   on pub.dev with open source licenses compatible with MIT. No
   proprietary SDKs, no ad networks, no analytics.

5. **Android only for now.** iOS support is planned but not yet
   started. Don't submit iOS-specific code until the iOS effort is
   coordinated.

6. **Must build on Android 7.0+ (API 24+).** Test on both old and
   new API levels where possible.

---

## What We Welcome

- Bug fixes
- UI/UX improvements following Material 3 guidelines
- Accessibility improvements
- Performance improvements
- Additional key management features
- Better error messages
- Localization / translations
- Security hardening (e.g. FLAG_SECURE on decrypt screen)
- Test coverage improvements

---

## How to Contribute

### 1. Set up the dev environment

```bash
# Install Flutter: https://docs.flutter.dev/get-started/install
git clone https://github.com/Alley-Cat-DS/alleycat-gpg-android
cd alleycat-gpg-android
flutter pub get
flutter run   # requires connected Android device or emulator
```

### 2. Make your changes

Keep changes focused — one fix or feature per PR.

### 3. Test

```bash
flutter test                    # unit tests
flutter analyze                 # static analysis
flutter build apk --debug       # make sure it builds
```

Test on a real device if possible, especially for:
- Key generation (can be slow on older hardware)
- QR scanner (requires camera)
- File encryption (requires file system access)

### 4. Open a pull request

- Describe what the change does and why
- Note which Android versions were tested
- Reference any related issues

---

## Reporting Bugs

Open a [GitHub Issue](../../issues/new/choose) using the Bug Report template.

Include:
- Android version
- Device model (or emulator)
- Flutter version (`flutter --version`)
- Steps to reproduce
- What you expected vs what happened

---

## Security Issues

**Do not open public issues for security vulnerabilities.**

Report privately to: **alleycat.elite337@passmail.net**

See [SECURITY.md](SECURITY.md) for the full policy.
