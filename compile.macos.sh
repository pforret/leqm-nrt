#!/bin/bash
# Compile on macOS
set -e

echo "🍎 Setting up leqm-nrt build environment for macOS..."

# Check if Homebrew is installed
if ! command -v brew &> /dev/null; then
    echo "❌ Homebrew not found. Please install Homebrew first:"
    echo "   /bin/bash -c \"\$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)\""
    exit 1
fi

echo "📦 Updating Homebrew..."
brew update

echo "🔧 Installing build dependencies..."
# Install autotools if not present
brew install autoconf automake

# Install audio libraries - prefer FFmpeg over libsndfile for better format support
echo "🎵 Installing audio libraries..."
brew install ffmpeg
brew install libsndfile

# Optional: Install Dolby DI if available (typically not in Homebrew)
if brew list | grep -q "dolby"; then
    echo "🎬 Dolby DI library found"
else
    echo "⚠️  Dolby DI library not available via Homebrew (optional feature)"
fi

echo "🧹 Cleaning previous build artifacts..."
make clean 2>/dev/null || true
rm -rf temp
rm -f missing config.cache
rm -f src/Makefile src/Makefile.in

echo "🔨 Generating build configuration..."
autoreconf -f -i

echo "⚙️  Configuring for macOS..."
# Configure with macOS-specific paths
./configure \
    --prefix=/usr/local \
    CPPFLAGS="-I$(brew --prefix)/include" \
    LDFLAGS="-L$(brew --prefix)/lib"

echo "🏗️  Building leqm-nrt..."
make -j$(sysctl -n hw.ncpu)

echo "📦 Creating macOS binary build/leqm_macos..."
cd src && make leqm_macos && cd ..

echo "✅ Build completed successfully!"
echo ""
echo "📁 macOS binary created at: build/leqm_macos"
echo ""
echo "To test the binary:"
echo "   ./build/leqm_macos --help"
echo ""
echo "To install system-wide, run:"
echo "   sudo make install"