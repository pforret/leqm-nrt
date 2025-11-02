#!/bin/bash
# Docker-based cross-compilation script for leqm-nrt
# Builds binaries for Linux and Windows from macOS

set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
BUILD_DIR="$SCRIPT_DIR/build"

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

log() {
    echo -e "${GREEN}[INFO]${NC} $1"
}

warn() {
    echo -e "${YELLOW}[WARN]${NC} $1"
}

error() {
    echo -e "${RED}[ERROR]${NC} $1"
}

header() {
    echo -e "${BLUE}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
    echo -e "${BLUE}$1${NC}"
    echo -e "${BLUE}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
}

# Check if Docker is installed and running
check_docker() {
    if ! command -v docker &> /dev/null; then
        error "Docker is not installed. Please install Docker Desktop for macOS."
        echo "Visit: https://www.docker.com/products/docker-desktop"
        exit 1
    fi

    if ! docker info &> /dev/null; then
        error "Docker daemon is not running. Please start Docker Desktop."
        exit 1
    fi

    log "Docker is installed and running"
}

# Build for a specific platform
build_platform() {
    local platform=$1
    local dockerfile=$2
    local output_binary=$3

    header "Building for $platform"

    log "Building Docker image for $platform..."
    docker build \
        -f "docker/$dockerfile" \
        -t "leqm-nrt:$platform" \
        . || {
        error "Failed to build Docker image for $platform"
        return 1
    }

    log "Extracting binary from Docker container..."

    # Create a temporary container
    container_id=$(docker create "leqm-nrt:$platform")

    # Copy the binary from the container
    docker cp "$container_id:/build/build/$output_binary" "$BUILD_DIR/$output_binary" || {
        docker cp "$container_id:/build/src/build/$output_binary" "$BUILD_DIR/$output_binary" || {
            error "Failed to extract binary from container"
            docker rm "$container_id" > /dev/null
            return 1
        }
    }

    # Remove the temporary container
    docker rm "$container_id" > /dev/null

    # Verify the binary exists and get its size
    if [[ -f "$BUILD_DIR/$output_binary" ]]; then
        local size=$(ls -lh "$BUILD_DIR/$output_binary" | awk '{print $5}')
        log "✅ Successfully built $output_binary (${size})"
        return 0
    else
        error "Binary not found: $BUILD_DIR/$output_binary"
        return 1
    fi
}

# Main execution
main() {
    header "🐳 Docker Cross-Compilation for leqm-nrt"

    check_docker

    # Ensure build directory exists
    mkdir -p "$BUILD_DIR"

    # Parse command line arguments
    BUILD_LINUX=false
    BUILD_WINDOWS=false
    BUILD_ALL=false

    if [[ $# -eq 0 ]]; then
        BUILD_ALL=true
    else
        for arg in "$@"; do
            case $arg in
                linux)
                    BUILD_LINUX=true
                    ;;
                windows)
                    BUILD_WINDOWS=true
                    ;;
                all)
                    BUILD_ALL=true
                    ;;
                *)
                    warn "Unknown platform: $arg"
                    echo "Usage: $0 [linux|windows|all]"
                    echo "  No arguments = build all platforms"
                    exit 1
                    ;;
            esac
        done
    fi

    if [[ "$BUILD_ALL" == true ]]; then
        BUILD_LINUX=true
        BUILD_WINDOWS=true
    fi

    # Track build results
    BUILDS_SUCCEEDED=()
    BUILDS_FAILED=()

    # Build Linux
    if [[ "$BUILD_LINUX" == true ]]; then
        if build_platform "linux" "Dockerfile.linux" "leqm_linux"; then
            BUILDS_SUCCEEDED+=("Linux")
        else
            BUILDS_FAILED+=("Linux")
        fi
    fi

    # Build Windows
    if [[ "$BUILD_WINDOWS" == true ]]; then
        if build_platform "windows" "Dockerfile.windows" "leqm_win.exe"; then
            BUILDS_SUCCEEDED+=("Windows")
        else
            BUILDS_FAILED+=("Windows")
        fi
    fi

    # Summary
    header "📊 Build Summary"

    if [[ ${#BUILDS_SUCCEEDED[@]} -gt 0 ]]; then
        log "Successfully built for: ${BUILDS_SUCCEEDED[*]}"
        echo ""
        log "Binaries available in: $BUILD_DIR"
        ls -lh "$BUILD_DIR"/{leqm_linux,leqm_win.exe} 2>/dev/null || true
    fi

    if [[ ${#BUILDS_FAILED[@]} -gt 0 ]]; then
        echo ""
        error "Failed to build for: ${BUILDS_FAILED[*]}"
        exit 1
    fi

    echo ""
    header "✅ Docker Cross-Compilation Complete!"

    echo ""
    log "Next steps:"
    echo "  • Test Linux binary: docker run --rm -v \"\$PWD:/work\" ubuntu:22.04 /work/build/leqm_linux --help"
    echo "  • Test Windows binary: Use Wine or Windows VM"
    echo "  • macOS binary: Run ./compile.macos.sh"
}

# Run main function
main "$@"
