# DIAGNOSIS.md: Reproduction & Root Cause Analysis

**Project**: ToufiqSec/music-app (Flutter Mobile Music App)  
**Backend**: Supabase (`pxyyzwxvqrbedvlbtltq`, Region: `ap-northeast-1`)  
**Audit Date**: Nov 21, 2026  
**Auditor**: Antigravity Core Agent

---

## 1. Phase 0: Captured Real Errors & Log Entries

### 1.1 Problem 1: Email Sign-In & Sign-Up Failure
* **User Symptom**: User enters email and password, taps Sign In / Sign Up, but the app does not advance past the login screen or session is lost.
* **Reproduction Steps**:
  1. Submit email sign-up/sign-in via `login_screen.dart` to Supabase backend `https://pxyyzwxvqrbedvlbtltq.supabase.co`.
  2. Inspect ClickHouse unified logs (`auth_logs` where `source = 'auth_logs'`).
* **Captured Supabase Auth Log Entries**:
  - **Log Entry A (Sign-In Failure - HTTP 400)**:
    ```json
    {
      "component": "api",
      "method": "POST",
      "path": "/token",
      "grant_type": "password",
      "referer": "http://localhost:3000",
      "status": 400,
      "error": "400: Invalid login credentials",
      "error_code": "invalid_credentials",
      "remote_addr": "122.183.39.102",
      "time": "2026-11-20T20:03:02Z"
    }
    ```
  - **Log Entry B (Sign-Up Rate Limit - HTTP 429)**:
    ```json
    {
      "component": "api",
      "method": "POST",
      "path": "/signup",
      "status": 429,
      "error": "429: email rate limit exceeded",
      "error_code": "over_email_send_rate_limit",
      "actor_username": "testmusictoufiq999@gmail.com",
      "referer": "http://localhost:3000",
      "remote_addr": "122.183.39.102",
      "time": "2026-11-20T20:05:46Z"
    }
    ```
  - **Log Entry C (Sign-Up Confirmation Redirect Misconfiguration - HTTP 200 with localhost referer)**:
    ```json
    {
      "event": "mail.send",
      "mail_to": "asif999busy@gmail.com",
      "mail_type": "confirmation",
      "referer": "http://localhost:3000",
      "time": "2026-11-20T16:40:57Z"
    }
    ```
* **Exact Root Causes**:
  1. **Site URL Misconfiguration (`localhost:3000`)**: In Supabase Dashboard (`Authentication > URL Configuration`), the Site URL is still set to `http://localhost:3000`. When a confirmation email is dispatched to the user's inbox, the embedded verification link points to `http://localhost:3000/#access_token=...`. On an Android mobile device, `localhost:3000` does not exist, so tapping the email confirmation link produces a `Connection Refused` browser error and never redirects into the mobile app.
  2. **Unconfirmed Email Blocking Login**: When users try to log into an account whose email confirmation link failed, Supabase rejects the password grant with HTTP 400 `invalid_credentials` or `email_not_confirmed`.
  3. **SMTP Rate Limit Exhaustion (`over_email_send_rate_limit`)**: Supabase's default shared SMTP server allows only 3 confirmation emails per hour. Repeated signup tests quickly hit HTTP 429, which was previously shown as generic "Registration failed" without explaining the SMTP cooldown.
  4. **Deep Link Scheme Missing for Email Confirmation**: The app's `AndroidManifest.xml` lacked intent filters for `myapp://auth-callback` or `musicapp://auth-callback`, and Supabase Email Templates redirect was not set to the mobile deep link scheme.

---

### 1.2 Problem 2: Google Sign-In Failure
* **User Symptom**: User taps "Continue with Google", a browser window opens, but after authentication the app does not advance or throws an error.
* **Reproduction Steps**:
  1. Tap "Continue with Google" on `LoginScreen`.
  2. Supabase initiates OAuth flow to `/authorize?provider=google`.
  3. Inspect Supabase Auth logs.
* **Captured Supabase Auth Log Entries**:
  - **Log Entry A (Google OAuth Initiation - HTTP 302 to external provider)**:
    ```json
    {
      "component": "api",
      "method": "GET",
      "path": "/authorize",
      "provider": "google",
      "referer": "http://localhost:3000",
      "status": 302,
      "msg": "Redirecting to external provider",
      "remote_addr": "115.96.129.151",
      "time": "2026-11-21T10:07:20Z"
    }
    ```
* **Exact Root Causes**:
  1. **Missing Deep Link Redirect URL in Supabase Allowlist**: In Supabase Dashboard (`Authentication > URL Configuration > Redirect URLs`), the app deep link scheme (`io.supabase.musicapp://login-callback`, `myapp://auth-callback`, `musicapp://auth-callback`) has not been added to the redirect allowlist. Because the scheme is not allowlisted, Supabase falls back to redirecting to the Site URL (`http://localhost:3000`), abandoning the session in the web browser.
  2. **Google Cloud Console Authorized Redirect URI Misalignment**: In `lib/screens/login_screen.dart:145`, the setup dialog was displaying an outdated Supabase project ref (`wcztbsbcfjoxlypghjil` instead of the active `pxyyzwxvqrbedvlbtltq`). If the user configured Google Cloud with the old ref, Google Cloud Console rejects the OAuth request with `Error 400: redirect_uri_mismatch`. The authorized redirect URI in Google Cloud Console must be:
     `https://pxyyzwxvqrbedvlbtltq.supabase.co/auth/v1/callback`
  3. **Incomplete Android Intent Filters**: `android/app/src/main/AndroidManifest.xml` only registered `io.supabase.musicapp://login-callback`. It did not register standard schemes like `myapp://auth-callback` or `musicapp://auth-callback`.
  4. **Missing PKCE Session Code Exchange Handler**: When returning from an external custom tab via deep link callback, the app must explicitly capture `AuthState` changes or parse `Uri` parameters, exchange the PKCE `code` for an active auth session, persist tokens securely, and pop/advance to `HomeScreen`.

---

### 1.3 Problem 3: Podcast Audio Playback Failure
* **User Symptom**: Podcast cards (e.g. *Sunday Suspense: Feluda*, *Byomkesh*, *Professor Shonku*) display their artwork and titles, but audio does not play, stalls at 0:00, or immediately skips.
* **Reproduction Steps**:
  1. Request playback for a podcast track (e.g. `ss_feluda_kathmandu`).
  2. Inspect the requested audio URL and network response.
* **Captured Audio URL & Network Response**:
  - **Requested URL**:
    `https://dts.podtrac.com/redirect.mp3/api.spreaker.com/download/episode/58582188/joto_kando_kathmandu_te.mp3`
  - **Network Multi-Hop Redirect Trace**:
    1. `https://dts.podtrac.com/...` -> HTTP 302 Found (Location: `https://api.spreaker.com/...`)
    2. `https://api.spreaker.com/...` -> HTTP 302 Found (Location: `https://d1bxy2pveef3fq.cloudfront.net/v1/...`)
    3. `https://d1bxy2pveef3fq.cloudfront.net/v1/...` -> HTTP 302 Found (Location: `https://d1bxy2pveef3fq.cloudfront.net/episodes/original/44544229?...`)
    4. `https://d1bxy2pveef3fq.cloudfront.net/episodes/...` -> HTTP 200 OK (`Content-Type: audio/mpeg`, Length: 157,178,534 bytes)
* **Exact Root Causes**:
  1. **Direct In-App RSS Scraping without Server-Side Caching**:
     The app was directly fetching Spreaker API/RSS on the client device inside `podcast_rss_service.dart`. When Spreaker rate-limits or the client has slow mobile connectivity, the client HTTP call times out (`Duration(seconds: 6)`). When that fails, it falls back to hardcoded items.
  2. **Missing Supabase Edge Function & Postgres Cache Table**:
     Per Phase 3 specifications, RSS feeds should not be parsed on device; they must be fetched and parsed by a Supabase Edge Function, cached in a Postgres table with a 6-hour refresh interval, and served with verified direct enclosure URLs (`audio/mpeg`). No Edge Function or Postgres table currently exists in the project.
  3. **Headless Player Error Logging & Error Skipping**:
     When audio resolution or ExoPlayer failed on mobile network hops, `audio_provider.dart:459` immediately advanced to the next track after 600ms without surfacing the exact player error code and URL.
  4. **Absence of "Audio not available for this episode" Graceful UI**:
     When an RSS episode lacked a playable enclosure URL, the app attempted to stream an invalid or null URL rather than showing the explicit prompt message `"Audio not available for this episode"`.

---

## 2. Remediation Strategy & Plan

| Phase | Target | Key Actions |
| :--- | :--- | :--- |
| **Phase 1: Email Login** | `lib/core/services/supabase_service.dart`<br>`lib/providers/auth_provider.dart`<br>`lib/screens/login_screen.dart`<br>`android/app/src/main/AndroidManifest.xml` | 1. Enable PKCE auth options in `Supabase.initialize()`.<br>2. Register intent filters for `io.supabase.musicapp://login-callback`, `myapp://auth-callback`, and `musicapp://auth-callback`.<br>3. Provide clear user-facing messages for `invalid_credentials`, `email_not_confirmed`, `over_email_send_rate_limit`, and token expiration.<br>4. Ensure auth state listener reliably saves session and advances to `HomeScreen`.<br>5. Document exact Supabase dashboard URL settings. |
| **Phase 2: Google Login** | `lib/core/services/supabase_service.dart`<br>`lib/screens/login_screen.dart` | 1. Ensure `signInWithGoogle` uses deep link redirection.<br>2. Fix outdated project ref in setup dialog to `https://pxyyzwxvqrbedvlbtltq.supabase.co/auth/v1/callback`.<br>3. Document required settings for Supabase Providers and Google Cloud Console OAuth Client (Package name `com.toufiqsec.music_app`, SHA-1). |
| **Phase 3: Podcast Audio** | Supabase Edge Function<br>Postgres table `podcast_episodes`<br>`lib/core/services/podcast_rss_service.dart`<br>`lib/core/services/playback_resolver.dart`<br>`lib/providers/audio_provider.dart`<br>`lib/services/audio_handler.dart` | 1. Propose and deploy `podcast_episodes` Postgres table with RLS and 6-hour TTL.<br>2. Create Supabase Edge Function `fetch-podcasts` to parse public RSS feeds, extract `audio/mpeg` enclosures, and update database.<br>3. Update `PodcastRssService` to read cached episodes from Supabase with resilient direct enclosure streaming.<br>4. Surface `"Audio not available for this episode"` when enclosure is absent.<br>5. Log player error code and URL upon playback failure. |

---
