# 07 — Distribution: Sandbox, Entitlements, Mac App Store

Primary distribution is the **Mac App Store**, which mandates the **App
Sandbox**. Design signing/notarization in from day one so a direct-distribution
fallback is also possible.

## App Sandbox ✅

- Enable `com.apple.security.app-sandbox`.
- Request only what's needed:
  - `com.apple.security.network.client` — outgoing connections to the
    OpenSubsonic server (the only essential entitlement for v1).
  - Keychain access for stored credentials (see below).
  - **Not** requested: incoming network server, camera/mic, location, address
    book, etc. Add `com.apple.security.files.user-selected.read-only` +
    security-scoped bookmarks **only if** external-file drag import ships later
    (currently ⏳, see `04`/`06`).

## Keychain ✅

- Store the server base URL, username, and password (token+salt) or API key in
  the Keychain via the Security framework (`SecItem*`) or a thin wrapper.
- Use a Keychain access group / service identifier tied to the app's bundle ID.
- Never store the derived token or log credentials. Credentials are entered and
  updated only in the Settings window.

## App Store Connect / packaging ✅

- Bundle identifier, app category (Music), and app icon set.
- `Info.plist`: app name "Hydrophone", versioning (`CFBundleShortVersionString`
  + build), minimum system version (macOS 14.0), `LSApplicationCategoryType`
  = `public.app-category.music`.
- **Privacy:** the app sends credentials and stream requests only to the
  user-configured server. Provide an accurate App Privacy disclosure
  (no tracking, no analytics in v1). Add any usage-description strings only for
  capabilities actually used (none extra for v1).
- No private APIs; no Tahoe-only hard dependencies (availability-guarded — see
  `04`).

## Signing & notarization ✅ (pipeline implemented 2026-07-07)

`scripts/release.sh [developer-id|app-store]` archives the Release
configuration and exports a signed artifact (`scripts/ExportOptions-*.plist`).
Release build settings: Manual signing, Developer ID Application
(team 4HNWJ993V9), **Hardened Runtime on** — verified: no runtime exceptions
needed (playback, Keychain, networking all work in the exported app).

- **Developer ID path (working end-to-end):** archive → export → signature
  verification (`codesign --verify --strict` + Developer ID authority +
  `runtime` flag check) → notarize + staple + Gatekeeper assess (runs when a
  `hydrophone` notarytool keychain profile exists; skipped with instructions
  otherwise) → versioned zip. One-time setup for notarization:
  `xcrun notarytool store-credentials hydrophone --apple-id … --team-id
  4HNWJ993V9` (app-specific password or ASC API key).
- **Mac App Store path (working end-to-end, 2026-07-29):**
  `release.sh app-store` archives and uploads the signed `.pkg` straight to
  App Store Connect (`destination: upload` in
  `ExportOptions-app-store.plist`; altool's upload path is discontinued).
  The export passes `-allowProvisioningUpdates`, so the Mac App Store
  provisioning profile is created on demand from the signed-in Xcode
  account. One-time portal artifacts in place: Apple Distribution + Mac
  Installer Distribution certificates, App ID `app.hydrophone` (no extra
  capabilities), ASC app record. `ITSAppUsesNonExemptEncryption = NO` in
  Info.plist skips the per-upload export-compliance question.
- Debug still signs with Developer ID (hardened runtime off) for the stable
  Keychain designated requirement — see `PROGRESS.md`.
- **GitHub Releases:** `scripts/publish.sh <version>` bumps
  `MARKETING_VERSION` + build number, commits, runs the notarized
  Developer ID build, refuses to ship anything Gatekeeper rejects, tags
  `v<version>`, pushes, and creates the GitHub Release with the zip attached
  (`gh release create … --generate-notes`). The repository went public
  2026-07-15, so release downloads are public.
- **Website:** `site/` holds the landing page, deployed to GitHub Pages by
  `.github/workflows/pages.yml` (https://hydrophone.app/). It
  redeploys on every push touching `site/` **and on every published
  release**, stamping the latest release tag into the page's
  `app-version` spans — the public download front door stays current with
  zero manual steps.

## Review considerations ✅ (0.6.0 approved 2026-08-05, first submission)

- Functionality requires a user-supplied server — reviewer notes point at the
  **public Navidrome demo**: `https://demo.navidrome.org`, user `demo`,
  password `demo` (resets periodically). Settings → Connection also shows a
  one-click "Use Demo Server" button whenever no server is configured, so a
  reviewer can exercise the app without typing anything.
- Ensure graceful behavior with no server configured (onboarding to Settings)
  and on auth failure (re-auth prompt) — see `02`.

## Checklist
- [x] App Sandbox on; only `network.client` (+ Keychain) entitled — verified
      on the exported artifact (`codesign -d --entitlements`).
- [x] Hardened Runtime on (Release); no exceptions needed — exported app
      plays audio and reads the Keychain.
- [x] Credentials in Keychain; nothing sensitive logged.
- [x] Info.plist: min macOS 14, music category, versioning, icon (placeholder
      icon still to be replaced before submission).
- [x] No Tahoe-only API without `#available` guard (none used).
- [ ] App Privacy details accurate (no tracking/analytics v1) — fill in at
      App Store Connect submission time ("Data Not Collected"; privacy
      policy URL: https://hydrophone.app/privacy.html).
- [x] Reviewer notes / demo credentials prepared (public Navidrome demo +
      in-app "Use Demo Server" button when unconfigured).
- [x] Signing pipeline produces a verified Developer ID build
      (`scripts/release.sh`); MAS archive → upload verified end-to-end
      (0.6.0 build 10 uploaded 2026-07-29).
- [x] Notarization round-trip — Accepted, stapled, Gatekeeper
      `source=Notarized Developer ID` (2026-07-07).
