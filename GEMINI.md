# leqm

## Project Overview

`leqm-nrt` is a non-real-time implementation of Leq(M) measurement for motion picture audio according to ISO 21727:2004 and ISO 21727:2016 standards. The project measures perceived loudness of audio material using specialized frequency weighting and time integration algorithms.

**Key Features:**
- Supports both ISO 21727:2004 (full-length content) and ISO 21727:2016 (short duration, ≤3 minutes)
- Multi-platform support (Linux, macOS, Windows)
- Multiple audio backend support (FFmpeg, libsndfile)
- Optional Dolby Dialogue Intelligence (DI) integration
- Multithreaded processing architecture

## Build System & Architecture

### Build System
The project uses GNU Autotools (autoconf/automake) for cross-platform builds:

```bash
# Full build process
autoreconf -f -i
./configure
make
sudo make install
```

### Ubuntu/Debian Build
Use the provided script for Ubuntu/WSL environments:
```bash
./compile.ubuntu.sh
```

### Debug Build
For development with debugging symbols:
```bash
make debug
```

### Dependencies
The build system automatically detects and configures:
- **Audio backends**: FFmpeg (preferred) or libsndfile (fallback)
- **Optional**: Dolby DI library (`libdi`) for dialogue intelligence
- **Required**: libm (math), libpthread (threading)
- **Linux only**: librt (real-time extensions)

### Configuration Detection
The `configure.ac` script automatically:
- Detects target OS (Linux/macOS/Windows) and sets conditional compilation
- Searches for FFmpeg libraries (`libavcodec`, `libavformat`, `libavutil`)
- Falls back to `libsndfile` if FFmpeg not found
- Locates Dolby DI library in multiple standard paths
- Sets appropriate compiler flags and library paths

## Code Architecture

### Single-File Architecture
The entire application is contained in `src/leqm-nrt.c` (~3000+ lines), structured as:

1. **Headers and Conditional Compilation** (lines 1-150)
   - Platform-specific includes
   - Feature detection macros (`FFMPEG`, `SNDFILELIB`, `DI`)
   - Library compatibility handling

2. **Data Structures** (lines 150-350)
   - Audio processing contexts
   - Filter coefficient structures
   - Threading context definitions

3. **Core Processing Functions**
   - Filter coefficient calculation
   - Audio decoding (FFmpeg or libsndfile)
   - Leq(M) measurement algorithms
   - Multi-channel processing

4. **Threading Implementation**
   - Worker thread management
   - Lock-free data structures where possible
   - Cross-platform thread handling

### Audio Backend Abstraction
The code supports two audio backends through conditional compilation:
- **FFmpeg**: Full-featured, supports many formats, used when `HAVE_LIBAVFORMAT` + `HAVE_LIBAVCODEC` + `HAVE_LIBAVUTIL` are defined
- **libsndfile**: Simpler, fewer formats, used as fallback when `HAVE_LIBSNDFILE` is defined

### Platform-Specific Code
Conditional compilation handles:
- **Windows**: Uses `windows.h`, different threading primitives
- **macOS**: Uses BSD-style system calls (`sys/param.h`, `sys/sysctl.h`)
- **Linux**: Requires real-time extensions (`librt`)

## Development Commands

### Building
```bash
# Clean rebuild
make clean && make

# Debug build with symbols
make debug

# Install system-wide
sudo make install
```

### Testing
The project doesn't include automated tests. Manual testing involves:
- Processing reference audio files
- Comparing output against known Leq(M) values
- Validating against ISO standard requirements

### Documentation
Documentation is built using MkDocs Material:
```bash
# Install dependencies (if needed)
pip install mkdocs-material mkdocs-awesome-pages-plugin

# Serve locally
mkdocs serve

# Build static site
mkdocs build
```

## Key Implementation Notes

### Multi-threading Design
- Uses pthread-based worker threads for parallel processing
- Implements custom synchronization for audio buffer management
- Thread-safe filter coefficient sharing across workers

### Standards Compliance
- Implements both ISO 21727:2004 and ISO 21727:2016 measurement methods
- Handles different integration times and frequency weightings
- Supports multi-channel audio with proper channel summation

### Memory Management
- Custom buffer management for audio samples
- Careful handling of large audio files to prevent memory exhaustion
- Platform-specific optimizations for memory allocation

### Error Handling
- Comprehensive error checking for audio file operations
- Graceful fallbacks when optional libraries unavailable
- Detailed error reporting for debugging

## Important Files

- `src/leqm-nrt.c`: Main application source (single file architecture)
- `configure.ac`: Autotools configuration script
- `Makefile.am`: Build system configuration
- `src/Makefile.am`: Source-specific build rules
- `compile.ubuntu.sh`: Ubuntu/Debian build script
- `docs/leqm/`: ISO standard documentation and technical references