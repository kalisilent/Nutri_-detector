# Google Play Store Release Guide

End-to-end process for publishing NutriScan to Google Play.

## 1. Pre-Release Checklist

### Code
- [ ] Final QA on a physical device (camera permissions, image upload, OCR on real packets)
- [ ] Crashlytics integrated and tested (force a crash to verify reports land)
- [ ] Analytics events firing for: register, login, scan_start, scan_success, scan_fail
- [ ] `kDebugMode` flags removed from production code paths
- [ ] All API URLs in release builds point to your Cloud Run production URL (via `--dart-define=API_BASE_URL=...`)

### Configuration
- [ ] `applicationId` set to a unique value you own (`com.yourcompany.nutriscan`)
- [ ] `versionCode` incremented vs. the previous release
- [ ] `minSdkVersion` 23+ (Android 6.0 — covers ~99% of active devices)
- [ ] `targetSdkVersion` 35 (Play Store requirement as of August 2025)
- [ ] Network security config disables cleartext (already set in AndroidManifest)
- [ ] Removed any test users / debug shortcuts

### Legal & Privacy
- [ ] Privacy policy published at a stable HTTPS URL (template in `docs/PRIVACY_POLICY.md`)
- [ ] Terms of service published (template in `docs/TERMS.md`)
- [ ] Both URLs linked from the Profile screen of the app
- [ ] Data safety form completed (see Section 4 below)

## 2. App Signing

Google Play uses Play App Signing — you generate an **upload key** locally, sign
the bundle with it, and Google re-signs with the app signing key they hold.

### Generate the upload keystore (one time only)

```bash
keytool -genkey -v -keystore ~/upload-keystore.jks \
    -keyalg RSA -keysize 2048 -validity 10000 \
    -alias upload
```

Store the keystore + passwords in a **password manager**. Losing this key means
you cannot publish updates to the same listing.

### Wire it into the project

Create `mobile/android/key.properties` (do NOT commit):

```properties
storePassword=<your store password>
keyPassword=<your key password>
keyAlias=upload
storeFile=<absolute path to upload-keystore.jks>
```

The release signing block in `mobile/android/app/build.gradle.snippet` reads this
file. Merge that snippet into your real `build.gradle`.

### For CI

Base64-encode the keystore and add it to GitHub Secrets:

```bash
base64 -w0 upload-keystore.jks > keystore.b64
# Paste contents into GitHub secret ANDROID_KEYSTORE_BASE64
```

Add the matching `KEYSTORE_PASSWORD`, `KEY_ALIAS`, `KEY_PASSWORD`,
`API_BASE_URL`, and `PLAY_SERVICE_ACCOUNT_JSON` secrets.

## 3. Building the Release Bundle

```bash
cd mobile
flutter build appbundle --release \
    --dart-define=API_BASE_URL=https://nutriscan-api-xxx.a.run.app/api/v1
```

Output: `build/app/outputs/bundle/release/app-release.aab`

Or trigger the GitHub Action — `Mobile Release` workflow with track `internal`
builds, signs, and uploads automatically.

## 4. Play Console Setup

### Create the app
1. Go to [play.google.com/console](https://play.google.com/console) → **Create app**
2. App name: **NutriScan**
3. Default language: English (US)
4. App or game: App
5. Free or paid: Free
6. Accept declarations

### Store listing
- **Short description (80 chars):** Scan food labels. Understand ingredients. See a clear health grade.
- **Full description (4,000 chars):** see template below
- **Graphics:**
  - Feature graphic: 1024×500 px
  - App icon: 512×512 px (in addition to launcher icon)
  - Phone screenshots: at least 2, max 8, min 1080px on the long side
- **Categorization:** Health & Fitness or Food & Drink
- **Contact details:** support email, website URL

#### Full description template

```
NutriScan helps you understand what's really in your packaged food.

📷 SCAN ANY LABEL
Take a photo of an ingredient list or Nutrition Facts panel. NutriScan reads
the text automatically.

🅰️ NUTRI-SCORE GRADES
Get an instant A–E health grade based on the Nutri-Score system used across
Europe — calculated from sugar, salt, fat, fiber and protein content.

📖 INGREDIENT EXPLANATIONS
Confused by "E322" or "monosodium glutamate"? NutriScan explains every
ingredient in plain language, drawing on a database of food additives.

📊 TRACK YOUR PURCHASES
See your scan history and grade distribution over time. Notice patterns
in what you're buying.

🌙 BUILT FOR DAILY USE
Material 3 design, dark mode, offline cache, and fast scans.

NutriScan provides educational information based on Nutri-Score and the NOVA
classification system. It is not medical advice — consult a healthcare
professional for specific dietary needs.
```

## 5. Data Safety Form

This is required and audited by Google. Be honest — wrong answers can cause
your listing to be taken down.

| Question | Answer |
|---|---|
| Does your app collect or share user data? | **Yes** |
| **Personal info — Email address** | Collected, NOT shared. Purpose: account management. Required. Processed on server. Encrypted in transit. Users can request deletion. |
| **Personal info — Name** | Collected (optional), NOT shared. Purpose: account display. |
| **App activity — App interactions** | Collected via Firebase Analytics. Anonymized. Purpose: analytics. |
| **Photos** | Processed (NOT collected long-term unless user saves scan). Encrypted in transit. Users can delete via scan history. |
| **Crash logs / Diagnostics** | Collected via Crashlytics. Purpose: app functionality, debugging. |
| Is all data encrypted in transit? | **Yes** (HTTPS everywhere) |
| Do you provide a way to delete data? | **Yes** — account deletion endpoint + per-scan delete in the app |

## 6. Content Rating

Run the IARC questionnaire (in Play Console → Policy → Content rating):
- No violence, no sexual content, no profanity, no controlled substances,
  no gambling, no user-generated content.
- Result: **Everyone** / PEGI 3.

## 7. Testing Tracks

Use these in order — don't go straight to production:

1. **Internal testing** — up to 100 emails, your team only. Available in minutes.
2. **Closed alpha** — invite-only via email lists. ~24h review.
3. **Open beta** — public opt-in via Play Store. ~24h review.
4. **Production** — full release. First review may take 1–7 days. Subsequent updates usually < 24h.

Roll out to **10% → 25% → 50% → 100%** of users over a week so you can pause if
Crashlytics shows a regression.

## 8. Post-Release Monitoring

Watch for the first 72 hours:

- **Crashlytics** — crash-free users should stay > 99%
- **Cloud Run logs** — error rate < 1%; check `/scans` endpoint specifically
- **Cloud SQL** — CPU and connection count
- **Play Console "Android vitals"** — ANRs, slow rendering, bad behaviors
- **User reviews** — respond to negative reviews within 48 hours

Roll back by promoting the previous Cloud Run revision (one click in console)
and halting the staged rollout in Play Console.

## 9. Update Cadence

- **Bug fix releases:** as needed, can ship same day
- **Minor features:** weekly or biweekly
- **Major versions:** monthly, behind a feature flag for the first 24h

Always:
1. Bump `versionCode` in `pubspec.yaml`
2. Update `CHANGELOG.md`
3. Add release notes in Play Console (en-US + any localized languages)
