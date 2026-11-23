# 📡 NAP Finder (Network Access Point / LCP Field Locator)

A high-performance, offline-first Flutter application (Web PWA & Android APK) designed for field technicians and dispatchers to locate and navigate to Network Access Points (NAP / LCP) using live Google Sheets data and OpenStreetMap GPS navigation.

---

## ✨ Core Features

* **📍 Offline Vector Maps**: Map tiles are dynamically cached for zero-network field navigation (in-memory for Web PWA, file-store for Android).
* **⚡ High-Performance Web Engine**: Zero-lag map gestures on web with throttled position handlers, instantaneous tile rendering, and native browser C++ tile fetching.
* **📱 iOS PWA Hardening**: Native status bar styling with solid safe-area anchors, zero WebKit blur scrims, and dynamic notch/Dynamic Island offsets.
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

#### ⚡ Web Performance & iOS PWA Architecture
* **Throttled Gesture Rebuilds**: `onPositionChanged` in `map_tab.dart` evaluates `_isFollowingUser` before invoking `setState()`, preventing continuous 60fps widget tree rebuilds during mouse scroll and trackpad pinch zooming.
* **Instantaneous Tile Rendering**: Uses `TileDisplay.instantaneous` on web to bypass the 400ms opacity rasterization pipeline across visible tiles during multi-level zooms.
* **Native Browser C++ Caching**: Uses `NetworkTileProvider()` on web to let Safari/Chrome handle HTTP tile caching and hardware-accelerated image decoding directly, eliminating Dart memory heap overhead.
* **Zero-Delay Cluster Expansion**: Configured `AnimationsOptions(zoom: Duration.zero)` on web to bypass 500ms main-thread clustering animations during rapid zoom transitions.
* **iOS Safari Status Bar & Elevated Search Card Layout**:
  * Configured `apple-mobile-web-app-status-bar-style: default` and `viewport-fit=cover` in `web/index.html`.
  * Positioned the floating search card directly up at `top: 44.0`, seating it immediately below the Dynamic Island / clock line to naturally cover the top transition space.
  * Eliminates artificial status bar strips and dead vertical margins, providing 100% full-screen map coverage while masking blur artifacts directly with the elevated search card.
  * Enforces `SystemUiOverlayStyle.dark` to keep status bar text and battery indicators crisp and legible.

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
