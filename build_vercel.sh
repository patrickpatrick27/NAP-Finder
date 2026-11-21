#!/bin/bash
set -e

echo "🚀 Starting Flutter Web Build on Vercel..."

# 1. Install Flutter if not present
if [ -d "$HOME/flutter" ]; then
  export PATH="$HOME/flutter/bin:$PATH"
elif [ -d "/Users/davepatrickbulaso/Documents/flutter" ]; then
  export PATH="/Users/davepatrickbulaso/Documents/flutter/bin:$PATH"
elif [ ! -d "flutter" ]; then
  echo "📥 Cloning Flutter stable..."
  git clone https://github.com/flutter/flutter.git --depth 1 -b stable flutter
  export PATH="$PWD/flutter/bin:$PATH"
else
  export PATH="$PWD/flutter/bin:$PATH"
fi

echo "🔧 Flutter version:"
flutter --version

# 2. Ensure assets/credentials.json exists
mkdir -p assets
if [ -n "$CREDENTIALS_JSON" ]; then
  echo "🔐 Using CREDENTIALS_JSON environment variable..."
  echo "$CREDENTIALS_JSON" > assets/credentials.json
elif [ ! -f "assets/credentials.json" ]; then
  echo "📄 Creating fallback credentials..."
  echo '{"type": "service_account"}' > assets/credentials.json
fi

# 3. Enable web and install packages
flutter config --no-analytics
flutter config --enable-web
flutter pub get

# 4. Build release web
echo "🛠 Compiling Flutter Web..."
flutter build web --release --no-tree-shake-icons

echo "✅ Build complete! Assets in build/web:"
ls -la build/web
