# Docker Cross-Compilation Quick Start

## ✅ What's Working

**Linux x86_64 cross-compilation from macOS is now fully operational!**

```bash
# Build Linux binary in one command
./compile.docker.sh linux

# Output: build/leqm_linux (137K)
```

## Quick Commands

### Build Linux Binary

```bash
./compile.docker.sh linux
```

### Test Linux Binary

```bash
# Test locally with Docker
docker run --rm -v "$PWD:/work" ubuntu:22.04 bash -c \
  "apt-get update -qq && apt-get install -y -qq libsndfile1 > /dev/null && \
   /work/build/leqm_linux --version"

# Run measurement
docker run --rm -v "$PWD:/work" ubuntu:22.04 bash -c \
  "apt-get update -qq && apt-get install -y -qq libsndfile1 > /dev/null && \
   /work/build/leqm_linux /work/examples/short.wav"
```

### Build All Platforms (macOS native + Linux Docker)

```bash
# macOS binary
./compile.macos.sh

# Linux binary
./compile.docker.sh linux
```

## Current Build Artifacts

```
build/
├── goqm_linux           # 3.2M - Go implementation (Linux)
├── goqm_macos           # 3.1M - Go implementation (macOS Intel)
├── goqm_macos_arm       # 3.1M - Go implementation (macOS ARM)
├── goqm_macos_stripped  # 2.1M - Go implementation (macOS ARM, stripped)
├── goqm_win.exe         # 3.3M - Go implementation (Windows)
├── leqm_linux           # 137K - C implementation (Linux) ✨ NEW
└── leqm_macos           # 89K - C implementation (macOS)
```

## Performance Comparison

From benchmark.md (234-second audio file):

| Binary | Processing Time | Speed Index | Winner |
|--------|-----------------|-------------|---------|
| **leqm_macos** (C) | 0.3s | **759.74x** | 🏆 |
| **leqm_linux** (C) | ~0.3s | **~760x** | 🥇 |
| goqm_macos_arm (Go) | 11.9s | 19.72x | - |
| goqm_linux (Go) | ~12s | ~20x | - |

**The C implementation is 38.5x faster than Go!**

## Windows Status

⚠️ **Windows cross-compilation**: In progress

The Windows Dockerfile is created but currently fails due to pthread compatibility issues with MinGW. Options:

1. **Use existing Go binary**: `build/goqm_win.exe` (already working)
2. **Compile on Windows**: Use native Windows + MinGW
3. **Use WSL**: Run Linux binary in Windows Subsystem for Linux
4. **Wait for fix**: pthread-win32 integration (future work)

## Documentation

- **Full docs**: `docker/README.md` - Comprehensive guide
- **Status**: `docker/STATUS.md` - Technical details and troubleshooting
- **Benchmarks**: `docs/benchmark.md` - Performance comparison

## Requirements

- Docker Desktop installed and running
- ~2 GB disk space for Docker images
- Internet connection (first build only)

## Build Times

- **First build**: ~30-60 seconds (downloads Ubuntu, installs packages)
- **Cached build**: ~5 seconds (Docker layer caching)
- **macOS native**: ~10 seconds

## Deployment

### Linux Server

```bash
# Copy binary to server
scp build/leqm_linux user@server:/usr/local/bin/

# Install dependency
ssh user@server "sudo apt install libsndfile1"

# Run
ssh user@server "leqm_linux /path/to/audio.wav"
```

### Docker Container

```dockerfile
FROM ubuntu:22.04
RUN apt-get update && apt-get install -y libsndfile1
COPY build/leqm_linux /usr/local/bin/
CMD ["leqm_linux"]
```

## Troubleshooting

### "Docker daemon not running"

```bash
# Start Docker Desktop
open -a Docker
```

### "No space left on device"

```bash
# Clean Docker cache
docker system prune -a
```

### "Binary requires libsndfile"

```bash
# On target system
sudo apt install libsndfile1  # Ubuntu/Debian
sudo yum install libsndfile   # CentOS/RHEL
```

## Next Steps

1. ✅ Linux cross-compilation working
2. ✅ Benchmark shows exceptional performance (760x real-time)
3. 📋 Add GitHub Actions for automated builds (optional)
4. 📋 Fix Windows pthread issues (future work)
5. 📋 Create universal macOS binary (Intel + ARM in one)

## Success! 🎉

You can now build Linux binaries from your macOS machine using Docker, achieving near-native performance with the C implementation processing audio **760x faster than real-time**.

---
*Created: 2025-11-02*
*Platform: macOS → Linux (via Docker)*
*Build time: ~5 seconds (cached)*
