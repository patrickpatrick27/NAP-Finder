#!/bin/bash
set -e 

# 1. Check for uncommitted changes
if [[ -n $(git status --porcelain) ]]; then
  echo "❌ Error: You have uncommitted changes. Commit them first."
  exit 1
fi

# 2. Extract Local Version
LOCAL_VERSION=$(grep 'version:' pubspec.yaml | sed 's/version: //')
LOCAL_BASE=$(echo $LOCAL_VERSION | cut -d '+' -f 1)

# 3. Fetch Remote Version from GitHub (origin/main)
echo "🔍 Checking version on GitHub..."
git fetch origin main --quiet
REMOTE_VERSION=$(git show origin/main:pubspec.yaml | grep 'version:' | sed 's/version: //')
REMOTE_BASE=$(echo $REMOTE_VERSION | cut -d '+' -f 1)

echo "📊 Local: $LOCAL_BASE | GitHub: $REMOTE_BASE"

# 4. Compare Versions
if [ "$LOCAL_BASE" == "$REMOTE_BASE" ]; then
  echo "🛑 Error: Version $LOCAL_BASE is already on GitHub."
  echo "👉 Please increment the version in pubspec.yaml before releasing."
  exit 1
fi

TAG="v$LOCAL_BASE"
COMMIT_ID=$(git rev-parse --short HEAD)

# 5. Set Release Notes to Commit ID
RELEASE_NOTES="Build based on Commit ID: $COMMIT_ID"

echo "🚀 Starting Release Process for $TAG"
echo "📝 Notes: $RELEASE_NOTES"

# 6. Push Code to GitHub
echo "☁️  Pushing code to GitHub..."
git push origin HEAD

# 7. Tag and Push Tag
if git ls-remote --exit-code --tags origin "$TAG" >/dev/null 2>&1; then
    echo "⚠️  Tag $TAG already exists. Deleting remote tag to overwrite..."
    git push --delete origin "$TAG" || true
    git tag -d "$TAG" || true
fi

git tag "$TAG"
git push origin "$TAG"

# 8. Build APK
echo "🛠  Building Release APK..."
flutter build apk --release --no-tree-shake-icons

# 9. Check if Build Succeeded
APK_PATH="build/app/outputs/flutter-apk/app-release.apk"
if [ ! -f "$APK_PATH" ]; then
    echo "❌ Error: APK file not found."
    exit 1
fi

# 10. Rename and Upload
NEW_NAME="build/app/outputs/flutter-apk/NAP_Finder_$TAG.apk"
mv "$APK_PATH" "$NEW_NAME"

echo "📦 Uploading Release to GitHub..."
# Use --overwrite if the release already exists
gh release create "$TAG" "$NEW_NAME" \
    --title "Version $LOCAL_BASE" \
    --notes "$RELEASE_NOTES" \
    --latest

echo "✅ DONE! Version $TAG is live."