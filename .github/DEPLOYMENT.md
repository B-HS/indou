# Deployment

- **CI** (`ci.yml`) — builds + tests on every push/PR to `dev` and `prod`.
- **Release** (`release.yml`) — on push to `prod` (or manual *Run workflow*): builds the
  `.app`, signs with Developer ID, notarizes, staples, and publishes a GitHub Release
  with a versioned `.zip` + `.sha256`. The version auto-bumps from the latest `vX.Y.Z` tag.

> Both run on a `macos-26` runner (Indou targets macOS 26 / Swift 6.2). If the hosted
> image is unavailable, point `runs-on` at a self-hosted Mac on macOS 26 with Xcode 26.

## Required GitHub secrets

Add these at **GitHub repo → Settings → Secrets and variables → Actions → New repository secret**.
Without them the release still builds, but ad-hoc signed (not notarized).

| Secret | What it is | How to get it |
|--------|-----------|---------------|
| `MACOS_CERTIFICATE` | Base64 of your **Developer ID Application** certificate exported as `.p12` (with private key) | See below |
| `MACOS_CERTIFICATE_PASSWORD` | The password you set when exporting the `.p12` | You choose it during export |
| `APPLE_ID` | Apple ID email of your developer account | — |
| `APPLE_TEAM_ID` | 10-character Team ID | Apple Developer → Membership (it is the `SN98P5V7J4` part shown in the cert name) |
| `APPLE_APP_PASSWORD` | App-specific password for `notarytool` | appleid.apple.com → Sign-In & Security → App-Specific Passwords → generate |

### Exporting the Developer ID certificate → `MACOS_CERTIFICATE`

1. Open **Keychain Access** → *login* keychain → *My Certificates*.
2. Find **`Developer ID Application: HYUNSEOK BYUN (SN98P5V7J4)`** and expand it so the
   private key is included.
3. Right-click → **Export "Developer ID Application…"** → save as `indou.p12`, set a
   password (this becomes `MACOS_CERTIFICATE_PASSWORD`).
4. Base64-encode and copy it:
   ```bash
   base64 -i indou.p12 | pbcopy
   ```
5. Paste as the `MACOS_CERTIFICATE` secret value. Then delete the local `indou.p12`.

That's it — push to `prod` (or run the Release workflow) and the signed, notarized
`Indou.zip` appears under **Releases**.
