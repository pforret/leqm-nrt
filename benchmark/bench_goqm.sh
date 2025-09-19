#!/bin/bash

# bench_leqm.sh - Benchmark script for leqm_macos
# Processes all .wav files in /benchmark/examples and generates a markdown report

set -euo pipefail

# Configuration
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(dirname "$SCRIPT_DIR")"
EXAMPLES_DIR="$SCRIPT_DIR/examples"
LEQM_EXECUTABLE="$PROJECT_ROOT/build/goqm_macos"
DATE=$(date +"%Y-%m-%d")
OUTPUT_FILE="$SCRIPT_DIR/$(basename "$LEQM_EXECUTABLE").$DATE.md"

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
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

# Check prerequisites
check_prerequisites() {
    log "Checking prerequisites..."

    if [[ ! -d "$EXAMPLES_DIR" ]]; then
        error "Examples directory not found: $EXAMPLES_DIR"
        exit 1
    fi

    if [[ ! -f "$LEQM_EXECUTABLE" ]]; then
        error "leqm_macos executable not found: $LEQM_EXECUTABLE"
        exit 1
    fi

    if [[ ! -x "$LEQM_EXECUTABLE" ]]; then
        error "Executable is not runnable: $LEQM_EXECUTABLE"
        exit 1
    fi

    # Count WAV files
    local wav_count
    wav_count=$(find "$EXAMPLES_DIR" -name "*.wav" -type f | wc -l)
    if [[ $wav_count -eq 0 ]]; then
        error "No .wav files found in $EXAMPLES_DIR"
        exit 1
    fi

    log "Found $wav_count .wav file(s) to process"
    log "Prerequisites check passed"
}

# Parse leqm_macos output to extract key information
parse_leqm_output() {
    local output="$1"
    local filename="$2"
    local fallback_ms="$3"

    LEQM_JSON="$output" FALLBACK_MS="$fallback_ms" python3 - "$filename" <<'PY'
import json
import os
import sys

filename = sys.argv[1]
raw_json = os.environ.get("LEQM_JSON", "")
fallback_ms = os.environ.get("FALLBACK_MS")

def print_result(row, proc_ms=None, duration=None, success=False):
    print(row)
    print("" if proc_ms is None else str(int(round(proc_ms))))
    print("" if duration is None else f"{duration:.6f}")
    print("1" if success else "0")

try:
    data = json.loads(raw_json)
except Exception:
    row = f"| {filename} | ERROR | - | - | - | - | - | - | JSON parse failed |"
    print_result(row)
    sys.exit(0)

measurements = data.get("measurements") or {}
execution = data.get("execution") or {}
metadata = data.get("metadata") or {}

leq_m = measurements.get("leq_m")
if leq_m is None:
    row = f"| {filename} | ERROR | - | - | - | - | - | - | Missing Leq(M) |"
    print_result(row)
    sys.exit(0)

sample_rate = metadata.get("original_sample_rate")
channels = metadata.get("channels")
frames = metadata.get("frames")
duration = metadata.get("duration_seconds")
if isinstance(duration, dict):
    duration = None

if duration is None and isinstance(sample_rate, (int, float)) and isinstance(frames, (int, float)) and sample_rate:
    try:
        duration = float(frames) / float(sample_rate)
    except Exception:
        duration = None

exec_seconds = execution.get("execution_seconds")
if exec_seconds is None and fallback_ms:
    try:
        exec_seconds = float(fallback_ms) / 1000.0
    except (TypeError, ValueError):
        exec_seconds = None

exec_ms = exec_seconds * 1000.0 if exec_seconds is not None else None

speed_index = execution.get("speed_index")
if speed_index is None and exec_seconds and duration:
    try:
        if exec_seconds > 0:
            speed_index = float(duration) / float(exec_seconds)
    except Exception:
        speed_index = None

def format_int(value):
    try:
        return str(int(value))
    except (TypeError, ValueError):
        return "N/A"

def format_float(value, digits):
    try:
        return f"{float(value):.{digits}f}"
    except (TypeError, ValueError):
        return "N/A"

sample_rate_str = format_int(sample_rate)
channels_str = format_int(channels)
frames_str = format_int(frames)
duration_str = format_float(duration, 2)
proc_ms_str = format_int(exec_ms)

if speed_index is not None:
    speed_str = f"{speed_index:.1f}x"
else:
    speed_str = "N/A"

row = (
    f"| {filename} | {leq_m:.6f} dB | {sample_rate_str if sample_rate_str != 'N/A' else 'N/A'} Hz | "
    f"{channels_str if channels_str != 'N/A' else 'N/A'} | {frames_str if frames_str != 'N/A' else 'N/A'} | "
    f"{duration_str if duration_str != 'N/A' else 'N/A'}s | {proc_ms_str if proc_ms_str != 'N/A' else 'N/A'}ms | {speed_str} | ✓ |"
)

print_result(row, exec_ms, duration, success=True)
PY
}

# Process a single WAV file
process_wav_file() {
    local wav_file="$1"
    local filename
    filename=$(basename "$wav_file")

    log "Processing: $filename" >&2

    local start_time end_time processing_time_ms
    start_time=$(python3 -c "import time; print(int(time.time() * 1000))" 2>/dev/null || echo "$(date +%s)000")

    local output
    local exit_code=0
    output=$("$LEQM_EXECUTABLE" "$wav_file" 2>&1) || exit_code=$?

    end_time=$(python3 -c "import time; print(int(time.time() * 1000))" 2>/dev/null || echo "$(date +%s)000")
    processing_time_ms=$((end_time - start_time))

    if [[ $exit_code -ne 0 ]]; then
        warn "leqm_macos returned exit code $exit_code for $filename" >&2
        printf '| %s | ERROR | - | - | - | - | - | - | Exit code: %s |\n__META__|%s|%s|0\n' \
            "$filename" "$exit_code" "$processing_time_ms" ""
        return
    fi

    local parsed
    parsed=$(parse_leqm_output "$output" "$filename" "$processing_time_ms") || parsed=""

    if [[ -z "$parsed" ]]; then
        printf '| %s | ERROR | - | - | - | - | - | - | Parsing failed |\n__META__|%s|%s|0\n' \
            "$filename" "$processing_time_ms" ""
        return
    fi

    local row proc_ms duration success
    local parsed_lines=()
    while IFS= read -r line || [[ -n "$line" ]]; do
        parsed_lines+=("$line")
    done <<< "$parsed"
    row="${parsed_lines[0]}"
    proc_ms="${parsed_lines[1]}"
    duration="${parsed_lines[2]}"
    success="${parsed_lines[3]}"
    printf '%s\n__META__|%s|%s|%s\n' "$row" "${proc_ms}" "${duration}" "${success:-0}"
}

# Generate markdown report
generate_report() {
    log "Generating markdown report: $OUTPUT_FILE"

    cat > "$OUTPUT_FILE" << EOF
# Leq(M) Benchmark Results

**Date:** $DATE
**Tool:** leqm_macos
**Directory:** \`$(basename "$EXAMPLES_DIR")\`
**Generated by:** benchmark.sh

## Summary

This report contains Leq(M) measurements for all WAV files in the examples directory.

## Results

| File | Leq(M) | Sample Rate | Channels | Frames | Duration | Processing Time | Speed Index | Status |
|------|--------|-------------|----------|--------|----------|-----------------|-------------|--------|
EOF

    # Process all WAV files
    local processed_count=0
    local success_count=0
    local total_processing_time=0
    local total_audio_duration=0
    binary_version=$("$LEQM_EXECUTABLE" --version 2>&1 | tail -1 || echo "Version info not available")

    while IFS= read -r -d '' wav_file; do
        result=$(process_wav_file "$wav_file")
        local row meta
        row=$(echo "$result" | sed -n '1p')
        meta=$(echo "$result" | sed -n '2p')

        echo "$row" >> "$OUTPUT_FILE"
        ((processed_count++))

        local proc_time_ms=""
        local duration_s=""
        local success_flag="0"

        if [[ "$meta" == __META__* ]]; then
            IFS='|' read -r _ proc_time_ms duration_s success_flag <<< "$meta"
        fi

        if [[ "$success_flag" == "1" ]]; then
            ((success_count++))

            if [[ "$proc_time_ms" =~ ^[0-9]+$ ]]; then
                total_processing_time=$((total_processing_time + proc_time_ms))
            fi

            if [[ "$duration_s" =~ ^[0-9]+(\.[0-9]+)?$ ]]; then
                total_audio_duration=$(echo "$total_audio_duration + $duration_s" | bc -l 2>/dev/null || echo "$total_audio_duration")
            fi
        fi
    done < <(find "$EXAMPLES_DIR" -name "*.wav" -type f -print0 | sort -z)

    # Calculate overall speed index
    local overall_speed_index="N/A"
    if [[ $total_processing_time -gt 0 && $(echo "$total_audio_duration > 0" | bc -l 2>/dev/null) == "1" ]]; then
        local total_processing_sec=$(echo "scale=3; $total_processing_time / 1000" | bc -l 2>/dev/null || echo "0")
        if [[ $(echo "$total_processing_sec > 0" | bc -l 2>/dev/null) == "1" ]]; then
            overall_speed_index=$(echo "scale=1; $total_audio_duration / $total_processing_sec" | bc -l 2>/dev/null || echo "N/A")
            overall_speed_index="${overall_speed_index}x"
        fi
    fi

    # Add footer to report
    cat >> "$OUTPUT_FILE" << EOF

## Statistics

- **Total files processed:** $processed_count
- **Successful measurements:** $success_count
- **Failed measurements:** $((processed_count - success_count))

### Performance

- **Total audio duration:** $(printf "%.2f" "$total_audio_duration")s
- **Total processing time:** ${total_processing_time}ms ($(echo "scale=2; $total_processing_time / 1000" | bc -l 2>/dev/null || echo "N/A")s)
- **Overall speed index:** $overall_speed_index

## Technical Details

### Measurement Standard
- **ISO 21727:2004** - Motion-picture audio measurement
- **ISO 21727:2016** - Short duration content (≤3 minutes)

### Tool Information

$binary_version

### System Information
- **Platform:** $(uname -s)
- **Architecture:** $(uname -m)
- **Date:** $(date)
- **Working Directory:** $(pwd)

---
*Generated by benchmark.sh on $DATE*
EOF

    log "Report generated successfully: $OUTPUT_FILE"
    log "Processed $processed_count files with $success_count successful measurements"
}

# Main execution
main() {
    log "Starting Leq(M) benchmark..."
    log "Output file: $OUTPUT_FILE"

    check_prerequisites
    generate_report

    log "Benchmark completed successfully!"
    log "View the report: cat $OUTPUT_FILE"
}

# Check if bc (calculator) is available for duration calculations
if ! command -v bc >/dev/null 2>&1; then
    warn "bc (calculator) not found - duration calculations will show 'N/A'"
fi

# Run main function
main "$@"
