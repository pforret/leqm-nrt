#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_DIR="$(cd "$SCRIPT_DIR/.." && pwd)"
GO_PROJECT_DIR="$SCRIPT_DIR"
OUTPUT_DIR="$REPO_DIR/build"
GOCACHE_DIR="$GO_PROJECT_DIR/.gocache"

mkdir -p "$OUTPUT_DIR"
mkdir -p "$GOCACHE_DIR"
export GOCACHE="$GOCACHE_DIR"

VERSION=$(cat "$REPO_DIR/VERSION.md")
BUILD_DATE=$(date -u +%Y-%m-%d)

function build_target {
  local goos="$1"
  local goarch="$2"
  local output="$3"

  local output_path="$OUTPUT_DIR/$output"
  local temp_dir="$GO_PROJECT_DIR/.build"
  local temp_path="$temp_dir/$output"

  mkdir -p "$temp_dir"

  echo "building $output_path (GOOS=$goos GOARCH=$goarch)"
  rm -f "$temp_path"
  GOOS="$goos" GOARCH="$goarch" CGO_ENABLED=0 \
    go build -C "$GO_PROJECT_DIR" -ldflags="-X main.version=$VERSION -X main.buildDate=$BUILD_DATE" -o "$temp_path" .
  mv "$temp_path" "$output_path"
}

build_target darwin amd64 goqm_macos 
build_target darwin arm64 goqm_macos_arm
build_target linux amd64 goqm_linux
build_target windows amd64 goqm_win.exe 

echo "artifacts stored in $OUTPUT_DIR"
