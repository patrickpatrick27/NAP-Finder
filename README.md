# 📡 NAP Finder (Network Access Point / LCP Field Locator)

A high-performance, offline-first Flutter application (Web PWA & Android APK) designed for field technicians and dispatchers to locate and navigate to Network Access Points (NAP / LCP) using live Google Sheets data and OpenStreetMap GPS navigation.

---

## ✨ Core Features

* **📍 Offline Vector Maps**: Map tiles are dynamically cached for zero-network field navigation (in-memory for Web PWA, file-store for Android).
* **☁️ Live Google Sheets Sync**: Reads directly from live master fiber spreadsheets via Google Sheets API v4 across 18 target municipal OLT sheets (`TGY001` through `TNC001`).
* **🧠 Ragged Row Parsing**: Detects OLT blocks, ODF ports, distance metrics, and multi-column coordinate pairs with strict bounding box filtering.
* **🧭 Live Heading & Compass**: Real-time geolocation with digital compass heading to orient technicians directly to the physical pole/pedestal.
* **🔍 Search & Filter**: Instant filtering across thousands of LCP records by name, site, or OLT port.
* **🌐 Web PWA Support**: Fully standalone mobile web app deployed to Vercel with Google Sign-In and responsive mobile layouts.

---

## 🛠️ Architecture & Technology Stack

* **Frontend**: Flutter Multiplatform (Dart 3, Flutter 3.27+)
* **Platforms**: Android (APK) & Web PWA (Vercel)
* **Authentication**: Firebase Authentication (Google Sign-In)
* **Access Control**: Cloud Firestore Admin RBAC (`manage_admins.py`)
* **Database**: Google Sheets API v4 (`googleapis` / `googleapis_auth`)
* **Mapping**: `flutter_map`, `latlong2`, `flutter_map_marker_cluster`
* **Caching**: `shared_preferences` (LCP data) and `dio_cache_interceptor` (Map tiles)

---

## 🔐 Credentials & Environment Setup

### Google Service Account Configuration
Data ingestion uses a Google Cloud Service Account with `spreadsheets.readonly` scope.

* **Service Account Email**: `firebase-adminsdk-fbsvc@mtop-nap-finder.iam.gserviceaccount.com`
* **Google Cloud Project**: `mtop-nap-finder` (`364801125437`)
* **Target Spreadsheet ID**: `1x_IsBXD0Tky4lZwg9lrIgUVR7s_rbfnC0c2L9adOwdI`

#### Required Access Permissions:
1. **Google Sheets API**: Must be enabled in GCP project `mtop-nap-finder` (`364801125437`).
2. **Sheet Sharing**: The target spreadsheet must be shared with `firebase-adminsdk-fbsvc@mtop-nap-finder.iam.gserviceaccount.com` with **Viewer** permission (or set to "Anyone with the link can view").

---

## 🚀 Deployment

### 1. Web PWA Deployment (Vercel)
The web build is automated via `build_vercel.sh` and `vercel.json`.

* **Production URL**: `https://nap-finder.vercel.app`
* **Environment Variable**: Add `CREDENTIALS_JSON` in Vercel Project Settings -> Environment Variables containing the full JSON contents of the service account key.
* **Build Script**: `build_vercel.sh` automatically installs Flutter stable, injects `CREDENTIALS_JSON` into `assets/credentials.json`, and compiles the release web bundle (`flutter build web --release --no-tree-shake-icons`).

### 2. Android APK Release (GitHub Actions)
Tagged git releases (`v*`) automatically trigger `.github/workflows/release.yml`:
* Decodes repository secret `CREDENTIALS_JSON_BASE64` into `assets/credentials.json`.
* Signs with upload keystore from secrets.
* Publishes versioned APK to GitHub Releases.

---

## 💻 Local Development

1. Clone repository:
   ```bash
   git clone git@github.com:patrickpatrick27/NAP-Finder.git
   cd NAP-Finder
   ```
2. Place the valid service account key in `assets/credentials.json`.
3. Install dependencies:
   ```bash
   flutter pub get
   ```
4. Run locally:
   ```bash
   flutter run -d chrome     # Web
   flutter run -d <device>   # Android
   ```
