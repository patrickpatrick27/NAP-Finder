#!/bin/bash
set -e 

# 1. Extract Local Version
LOCAL_VERSION=$(grep 'version:' pubspec.yaml | sed 's/version: //')
LOCAL_BASE=$(echo $LOCAL_VERSION | cut -d '+' -f 1)
TAG="v$LOCAL_BASE"

# 2. Sync with GitHub metadata
echo "🔍 Checking GitHub for $TAG..."
git fetch origin --tags --quiet

# 3. Check if the Release/Tag already exists on the server
TAG_EXISTS=$(git ls-remote --tags origin | grep "$TAG" || true)

if [ -n "$TAG_EXISTS" ]; then
  echo "🛑 Release $TAG already exists on GitHub."
  read -p "❓ Do you want to DELETE and RE-UPLOAD this release? (y/n): " REFORCE
  if [ "$REFORCE" != "y" ]; then
    exit 1
  fi
  echo "🗑️  Removing old tag/release to overwrite..."
  gh release delete "$TAG" --yes || true
  git push --delete origin "$TAG" || true
  git tag -d "$TAG" || true
fi

# 4. Use Latest Commit ID as Notes
COMMIT_ID=$(git rev-parse --short HEAD)
RELEASE_NOTES="Build based on Commit ID: $COMMIT_ID"

echo "🚀 Starting Release Process for $TAG"

# 5. Push Code (In case you haven't)
echo "☁️  Pushing code to GitHub..."
git push origin HEAD --quiet || echo "Already pushed."

# 6. Tagging
echo "🏷  Tagging version $TAG..."
git tag "$TAG"
git push origin "$TAG"

# 7. Build APK
echo "🛠  Building Release APK..."
flutter build apk --release --no-tree-shake-icons

# 8. Check if Build Succeeded
APK_PATH="build/app/outputs/flutter-apk/app-release.apk"
if [ ! -f "$APK_PATH" ]; then
    echo "❌ Error: APK file not found."
    exit 1
fi

# 9. Rename and Upload
NEW_NAME="build/app/outputs/flutter-apk/NAP_Finder_$TAG.apk"
mv "$APK_PATH" "$NEW_NAME"

echo "📦 Uploading Release to GitHub..."
gh release create "$TAG" "$NEW_NAME" \
    --title "Version $LOCAL_BASE" \
    --notes "$RELEASE_NOTES" \
    --latest

echo "✅ DONE! Version $TAG is live."