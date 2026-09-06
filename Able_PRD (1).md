# Able — Product Requirements Document

**Author:** Boluwatife Odepe
**Version:** 1.0 (MVP)
**Platform:** React Native (Expo) — Android & iOS
**Build partner:** Kimi (AI coding agent)

---

## 1. Overview

Able is a mobile app that lets users paste a link to a public social media post (TikTok, Instagram, Facebook, Twitter/X, and YouTube) and download the video and/or audio, without the platform's watermark.

**Core value proposition:** one app, multiple platforms, clean downloads, no cost to the user.

**Cost model:** Zero AI/generation cost. The app does not create content — it extracts and serves existing public media. All infrastructure cost is limited to lightweight server bandwidth/compute, kept low by design.

**Monetization:** No ads in this build. Ads will be added later by Boluwatife once the app is stable — not part of MVP scope.

---

## 2. Goals

- Let a user download a clean (no watermark) copy of a public video/audio post in under 10 seconds from link paste to saved file.
- Support the most-used platforms first; expand platform coverage over time.
- Generate revenue purely from ad impressions — no subscriptions, no paid tiers, no per-download cost to Boluwatife.
- Ship a working MVP fast, then iterate based on real usage.

## 3. Non-goals (for MVP)

- No user accounts / login (keeps it frictionless and avoids unnecessary backend complexity).
- No re-uploading, editing, or repurposing content inside the app — Able is a download utility, not a content editor.
- No private/login-gated content — public links only.

---

## 4. Target Users

- Everyday social media users who want to save a video/audio they like.
- Content creators/YouTube automation-style users who repost or reference clips (with the legal caveat in Section 10).
- Nigerian and broader global mobile users on Android first (larger market share locally), iOS as a fast-follow.

---

## 5. Core Features (MVP)

### 5.1 Paste & Detect
- Home screen: single input field — "Paste link here."
- Auto-detects platform from the URL (TikTok / Instagram / Facebook / Twitter/X).
- Also supports the OS share sheet: user can share a link directly from TikTok/Instagram/etc. into Able, skipping copy-paste.

### 5.2 Preview
- After link is submitted, show a preview card: thumbnail, caption/title (if available), duration, and platform icon.
- Options shown: **Download Video (no watermark)**, **Download Audio only**.

### 5.3 Download
- Quality selector where available (e.g., SD/HD).
- Progress indicator during download.
- File saved to device (Downloads/Able folder), with a success toast + "Open" / "Share" actions.

### 5.4 Download History / Library
- In-app list of everything downloaded via Able (thumbnail, platform, date, file size).
- Tap to re-open, share, or delete.
- Local-only (SQLite/Hive) — no cloud sync in MVP.

### 5.5 Ads
- Not included in this build. Ads (AdMob) will be integrated later, once the app is stable and Boluwatife decides to add them — not an MVP requirement.

---

## 6. Technical Architecture

**Why a backend is required:** the app cannot reliably extract clean source URLs from social platforms directly inside the app client — platforms change their page structure/APIs often, and this logic needs to live somewhere you can update quickly without an app store release cycle.

```
React Native App (Expo, Android/iOS)
      |
      | link + platform
      v
Backend API (Node.js/Express, hosted on Railway — same pattern as Bulker)
      |
      | extraction logic per platform
      v
Platform's public content delivery (video/audio source file)
```

- **Frontend:** React Native (Expo) + TypeScript, React Navigation (screen navigation), Zustand or React Context (state management), Axios (networking), AsyncStorage or Expo SQLite (local download history), Expo Notifications (download complete alerts), Expo Sharing (share downloaded files), Expo FileSystem (handling downloaded media), Expo Clipboard (paste-from-clipboard support).
- **Builds:** EAS Build (Expo's cloud build service) — builds run in the cloud, so local machine specs/OS version are not a blocker, similar to how Codemagic was being used for the Flutter build.
- **Backend:** Node.js/Express on Railway. Responsibilities:
  - Receives a link, identifies platform, extracts the direct clean media URL.
  - Uses per-platform extraction methods (open-source libraries/approaches exist for TikTok, Instagram, Facebook, Twitter — these need regular maintenance as platforms update).
  - Returns a direct download URL (or streams the file) to the app — the backend should avoid storing/hosting the media itself long-term, to keep bandwidth/storage cost near zero and reduce copyright exposure (Able is a pass-through, not a media host).
- **Hosting cost:** Railway free/low tier should comfortably handle MVP traffic since there's no AI compute involved — this is the same low-cost pattern as Bulker's backend.

---

## 7. Data & Privacy

- No user accounts, no personal data collection beyond standard AdMob analytics.
- Download history stored locally on-device only.
- No server-side storage of downloaded media (pass-through architecture, not a media library).

---

## 8. Legal & Risk Notes (read before building)

- **Personal use vs. redistribution:** downloading public content for personal/offline use is broadly tolerated across these platforms; the app should include a short in-app notice reminding users not to redistribute others' content commercially without permission (protects the user and reduces Able's liability exposure).
- **App store risk:** Apple App Store and Google Play periodically remove "downloader" apps citing third-party ToS violations. Mitigation: keep the app's public description framed around "save your own posts / backup content," avoid marketing language that encourages piracy, and be prepared for possible removal/resubmission cycles — this is a known risk in this app category industry-wide, not unique to Able.
- **Platform changes will break extraction logic periodically** — budget ongoing maintenance time (this is normal for this category, not a sign of doing something wrong).
- **YouTube is included at launch, by deliberate decision.** This is the highest-risk platform in scope: Google/YouTube pursues downloader tools more aggressively than TikTok, Instagram, Facebook, or X — through app store takedown requests, cease-and-desist notices, and legal action against tools and services that facilitate downloading. Known consequences to be prepared for:
  - Higher chance of Google Play removing the app, or requiring resubmission without YouTube support to stay listed.
  - Possible cease-and-desist correspondence if the app gains visibility.
  - The YouTube extraction logic will need the most frequent maintenance of all supported platforms.
  - Recommendation: keep YouTube extraction in its own isolated backend module so it can be disabled quickly (via a remote config flag) without needing an app store update, if it becomes the reason for a takedown — this protects the rest of the app (TikTok/IG/FB/X) from being pulled down with it.

---

## 9. Phased Rollout

**Phase 1 (MVP / Launch):**
- TikTok, Instagram, Facebook, Twitter/X, and YouTube — video + audio extraction, no watermark.
- YouTube module built isolated/toggleable (see Section 10) so it can be switched off remotely without an app update if it triggers store issues.
- Ads (AdMob) live from day one.
- Android first, iOS fast-follow.

**Phase 2 (post-launch, based on traction):**
- Batch download (multiple links at once).
- Ads (AdMob) added in by Boluwatife once the app is stable.
- If YouTube support gets the app flagged/removed, a fallback "Able Lite" build (TikTok/IG/FB/X only, no YouTube) should be ready to resubmit quickly.

**Phase 3 (growth):**
- Possibly a lightweight web version (dodges app-store risk, wider reach).
- Localization (Nigerian languages) if user base justifies it.

---

## 10. Success Metrics (MVP)

- App installs and daily active users.
- Downloads completed per user per week (engagement signal).
- Crash-free rate and extraction success rate per platform (reliability signal — track which platforms break most often).

---

## 11. Open Questions for Build Phase

- Exact extraction approach per platform (to be handled during backend implementation — will require ongoing adjustment as platforms change).
- App store submission strategy — Android (Google Play) first is lower-risk; iOS submission timing to be decided after seeing how Android review goes.
