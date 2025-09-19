#!/bin/bash
# Compile on Ubuntu (WSL)
set -e

echo "🐧 Setting up leqm-nrt build environment for Ubuntu..."

echo "📦 Updating package lists..."
sudo apt update

echo "🔧 Installing build dependencies..."
sudo apt install -y autoconf automake build-essential

echo "🎵 Installing audio libraries..."
sudo apt install -y libsndfile1 libsndfile1-dev

# Optional: Install FFmpeg for better format support
if apt list --installed 2>/dev/null | grep -q "ffmpeg"; then
    echo "🎬 FFmpeg already installed"
else
    echo "🎬 Installing FFmpeg..."
    sudo apt install -y ffmpeg libavcodec-dev libavformat-dev libavutil-dev
fi

echo "🧹 Cleaning previous build artifacts..."
make clean 2>/dev/null || true
rm -f missing config.cache
rm -f src/Makefile src/Makefile.in

echo "🔨 Generating build configuration..."
autoreconf -f -i

echo "⚙️  Configuring for Ubuntu..."
./configure

echo "🏗️  Building leqm-nrt..."
make -j$(nproc)

echo "📦 Creating Ubuntu binary build/leqm_ubuntu..."
cd src && make leqm_ubuntu && cd ..

echo "✅ Build completed successfully!"
echo ""
echo "📁 Ubuntu binary created at: build/leqm_ubuntu"
echo ""
echo "To test the binary:"
echo "   ./build/leqm_ubuntu --help"
echo ""
echo "To install system-wide, run:"
echo "   sudo make install"
