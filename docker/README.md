# Docker Cross-Compilation for leqm-nrt

This directory contains Docker-based build configurations for cross-compiling leqm-nrt to multiple platforms from macOS.

## Prerequisites

- **Docker Desktop** installed and running
  - Download: https://www.docker.com/products/docker-desktop
- **Disk space**: ~2-3 GB for Docker images and build artifacts

## Quick Start

### Option 1: Using the Build Script (Recommended)

Build all platforms:
```bash
./compile.docker.sh
```

Build specific platform:
```bash
./compile.docker.sh linux      # Linux only
./compile.docker.sh windows    # Windows only
./compile.docker.sh all        # All platforms
```

### Option 2: Using Docker Compose

Build all platforms:
```bash
cd docker
docker-compose build
docker-compose up
```

Build specific platform:
```bash
cd docker
docker-compose build build-linux
docker-compose run --rm build-linux
```

### Option 3: Manual Docker Commands

**Linux build:**
```bash
docker build -f docker/Dockerfile.linux -t leqm-nrt:linux .
docker create --name temp-linux leqm-nrt:linux
docker cp temp-linux:/build/build/leqm_linux ./build/
docker rm temp-linux
```

**Windows build:**
```bash
docker build -f docker/Dockerfile.windows -t leqm-nrt:windows .
docker create --name temp-windows leqm-nrt:windows
docker cp temp-windows:/build/src/build/leqm_win.exe ./build/
docker rm temp-windows
```

## Output

Built binaries are placed in the `build/` directory:
- `build/leqm_linux` - Linux x86_64 binary
- `build/leqm_win.exe` - Windows x86_64 executable
- `build/leqm_macos` - macOS binary (built natively with `./compile.macos.sh`)

## Platform Details

### Linux (Dockerfile.linux)
- **Base image**: Ubuntu 22.04
- **Target**: x86_64 (64-bit Intel/AMD)
- **Libraries**:
  - libsndfile (audio file I/O)
  - FFmpeg (libavcodec, libavformat, libavutil)
- **Output**: Static-linked binary for maximum portability

### Windows (Dockerfile.windows)
- **Base image**: Debian Bullseye
- **Cross-compiler**: MinGW-w64 (x86_64-w64-mingw32)
- **Target**: Windows x86_64 (64-bit)
- **Libraries**:
  - libsndfile (cross-compiled from source)
  - Statically linked for standalone .exe
- **Output**: Self-contained Windows executable

## Testing Binaries

### Linux Binary
Test in Docker container:
```bash
docker run --rm -v "$PWD:/work" ubuntu:22.04 /work/build/leqm_linux --version
docker run --rm -v "$PWD:/work" ubuntu:22.04 /work/build/leqm_linux /work/examples/short.wav
```

Test in WSL2 or native Linux:
```bash
./build/leqm_linux --version
./build/leqm_linux examples/short.wav
```

### Windows Binary
Test with Wine (macOS/Linux):
```bash
brew install wine-stable  # macOS
wine build/leqm_win.exe --version
```

Test on Windows (VM or native):
```cmd
build\leqm_win.exe --version
build\leqm_win.exe examples\short.wav
```

## Troubleshooting

### Docker Build Fails

**Issue**: "Cannot connect to Docker daemon"
```bash
# Start Docker Desktop and wait for it to fully start
open -a Docker
```

**Issue**: "No space left on device"
```bash
# Clean up unused Docker resources
docker system prune -a
```

**Issue**: "Windows build fails to find libraries"
- The Windows build compiles libsndfile from source during image creation
- This takes longer (~5-10 minutes first time)
- Subsequent builds use cached layers

### Binary Doesn't Run

**Linux**: Check glibc version compatibility
```bash
ldd build/leqm_linux
# Should show library dependencies
```

**Windows**: Ensure Visual C++ Redistributable installed
- Download: https://aka.ms/vs/17/release/vc_redist.x64.exe
- Or use static build (already configured in Dockerfile)

### Performance Issues

Docker builds can be slow on first run due to:
1. Image download (~500 MB per platform)
2. Package installation
3. Library compilation (Windows: libsndfile from source)

**Optimization**: Docker caches build layers. Subsequent builds are much faster unless you modify dependencies.

## Advanced Usage

### Custom Build Options

Modify `configure` flags in Dockerfiles:

**Enable debug symbols:**
```dockerfile
RUN ./configure --prefix=/usr/local CFLAGS="-g -O0"
```

**Optimize for size:**
```dockerfile
RUN ./configure --prefix=/usr/local CFLAGS="-Os" LDFLAGS="-s"
```

### Add More Platforms

**Linux ARM64:**
```dockerfile
FROM arm64v8/ubuntu:22.04
# Same build process as Dockerfile.linux
```

**Alpine Linux (smaller images):**
```dockerfile
FROM alpine:3.18
RUN apk add --no-cache build-base autoconf automake
# Continue with build
```

## Architecture Overview

```
┌─────────────────────────────────────────────┐
│  macOS Host                                 │
│  ├─ compile.docker.sh (orchestrator)        │
│  ├─ Docker Engine                           │
│  │  ├─ Ubuntu container → leqm_linux        │
│  │  └─ Debian+MinGW → leqm_win.exe          │
│  └─ build/ (output directory)               │
└─────────────────────────────────────────────┘
```

## Comparison with Native Compilation

| Method | Speed | Complexity | Portability |
|--------|-------|------------|-------------|
| **Docker** | Medium (first build slow, cached builds fast) | Low (automated) | Excellent (works on any Docker host) |
| **Native** | Fast | Medium (platform-specific deps) | Low (requires matching OS) |
| **GitHub Actions** | Slow (cloud build) | Low (automated) | Excellent (runs in cloud) |

## Resources

- Docker Documentation: https://docs.docker.com/
- MinGW-w64 Project: https://www.mingw-w64.org/
- libsndfile: https://libsndfile.github.io/libsndfile/
- FFmpeg: https://ffmpeg.org/

## License

Same as leqm-nrt project (GPL-3.0)
