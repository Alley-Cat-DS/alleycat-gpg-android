# AlleyCat GPG Android — Threat Model

## Purpose

This document describes what AlleyCat GPG Android protects against,
what it does not protect against, and what assumptions it makes about
the user's environment.

For the full threat model shared with the desktop app, see:
[gpg-messenger/THREAT_MODEL.md](https://github.com/Alley-Cat-DS/gpg-messenger/blob/main/THREAT_MODEL.md)

---

## Primary Threat: Passive Surveillance Over SMS

When you send an unencrypted SMS, the content is visible to:
- Your mobile carrier
- The recipient's carrier
- Any network infrastructure in between
- Law enforcement with a subpoena to any of the above

AlleyCat GPG encrypts the message **before** it leaves your device.
The carrier sees that you sent a message, but not what it says.

---

## What We Protect Against

**ISP and cell tower content interception** — encrypted ciphertext
is transmitted, not plaintext.

**Passive dragnet surveillance** — bulk interception programs see
only opaque PGP blocks.

**File and attachment confidentiality** — encrypted files sent as
MMS or email attachments are unreadable without the key or passphrase.

---

## What We Do NOT Protect Against

### Compromised Android device

If an attacker has root access to your device, they can:
- Read memory while plaintext is displayed on screen
- Access the Android KeyStore directly
- Log keystrokes including passphrases
- Intercept the openpgp library calls

**AlleyCat GPG provides no protection on a rooted or compromised device.**

### Metadata

We encrypt **content**, not **metadata**. Your carrier can still see:
- That you sent a message to a particular number
- When you sent it
- Approximately how long it was

### Recipient device compromise

Once the recipient decrypts on their device, the content is only as
secure as their device.

### Weak passphrases

Symmetric encryption is only as strong as the passphrase. Use long,
random passphrases and share them through a separate trusted channel.

### Key substitution (MITM on import)

If you import a public key that has been substituted by an attacker,
they can decrypt your messages. Always verify fingerprints out-of-band.

### Screen capture

Android allows apps and system features to capture the screen.
Treat the decrypted message view as sensitive — clear it when done.

---

## Android-Specific Notes

### Key storage

Private keys are encrypted using Android's `EncryptedSharedPreferences`,
which uses AES-256-GCM backed by the Android KeyStore hardware security
module where available. On devices with a dedicated secure element or
StrongBox, keys are hardware-protected.

### Backup

`android:allowBackup="false"` is set in the manifest. Keys and
encrypted storage are excluded from Android backups and Google Drive
backup. This means uninstalling the app deletes your keys — **export
your private key before uninstalling**.

### Screenshot prevention

Consider adding `FLAG_SECURE` to the decrypt screen in a future
update to prevent screenshots of decrypted content.

---

## Comparison: AlleyCat GPG vs Signal

| Property | AlleyCat GPG | Signal |
|----------|-------------|--------|
| Content encryption | ✅ OpenPGP | ✅ Signal Protocol |
| Forward secrecy | ❌ No | ✅ Yes |
| Metadata protection | ❌ No | ✅ Sealed sender |
| Works over SMS/email | ✅ Yes | ❌ No |
| No account required | ✅ Yes | ❌ Phone number |
| Open standard | ✅ OpenPGP RFC | ❌ Proprietary |
| File encryption | ✅ Yes | ✅ In-app only |

These tools are complementary. Use Signal where you can. Use
AlleyCat GPG when you need to encrypt content delivered over
channels you don't control.

---

## Reporting Security Issues

See [SECURITY.md](SECURITY.md).
