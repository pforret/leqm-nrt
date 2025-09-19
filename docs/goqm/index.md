# goqm

golang version of Leq(m) algorithm. Output in JSON format.

```json
{
  "metadata": {
    "file": "examples/short.wav",
    "original_sample_rate": 48000,
    "effective_sample_rate": 48000,
    "channels": 2,
    "frames": 240000,
    "duration_seconds": 5.0
  },
  "measurements": {
    "leq_m": 74.75,
    "leq_no_weight": 80.77,
    "mean_power": 0.0019,
    "mean_power_weighted": 0.0005
  },
  "channel_stats": [
    {
      "channel": 0,
      "peak_db": 92.5495,
      "average_db": 77.0074
    },
    {
      "channel": 1,
      "peak_db": 92.5369,
      "average_db": 78.4061
    }
  ],
  "execution": {
    "binary_path": "(...)/leqm-nrt/build/goqm_macos",
    "binary_version": "development",
    "execution_seconds": 0.2582,
    "speed_index": 19.3644,
    "mbps": 3.7183
  }
}
```