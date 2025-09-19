package main

import (
	"bytes"
	"encoding/binary"
	"encoding/json"
	"errors"
	"fmt"
	"io"
	"math"
	"os"
	"os/exec"
	"path/filepath"
	"runtime/debug"
	"strconv"
	"strings"
	"time"
)

const (
	referenceOffsetDB = 108.010299957
	decimalDigits     = 4
)

var supportedExtensions = map[string]struct{}{
	".wav": {},
	".mp3": {},
	".m4a": {},
}

type ffprobeOutput struct {
	Streams []struct {
		SampleRate string `json:"sample_rate"`
		Channels   int    `json:"channels"`
		Duration   string `json:"duration"`
	} `json:"streams"`
}

type audioMetadata struct {
	SampleRate int
	Channels   int
	Duration   float64
}

type loudnessMeasurements struct {
	LeqM              measurementFloat `json:"leq_m"`
	LeqNoW            measurementFloat `json:"leq_no_weight"`
	MeanPower         measurementFloat `json:"mean_power"`
	MeanPowerWeighted measurementFloat `json:"mean_power_weighted"`
}

type loudnessMetadata struct {
	File                string           `json:"file"`
	OriginalSampleRate  int              `json:"original_sample_rate"`
	EffectiveSampleRate int              `json:"effective_sample_rate"`
	Channels            int              `json:"channels"`
	Frames              int64            `json:"frames"`
	DurationSeconds     measurementFloat `json:"duration_seconds"`
}

type loudnessResult struct {
	Metadata             loudnessMetadata     `json:"metadata"`
	Measurements         loudnessMeasurements `json:"measurements"`
	ReferenceOffsetDB    float64              `json:"reference_offset_db"`
	ChannelStats         []channelStat        `json:"channel_stats"`
	Execution            executionInfo        `json:"execution"`
	ProcessingNotes      []string             `json:"processing_notes,omitempty"`
	AudioDurationSeconds float64              `json:"-"`
}

type channelStat struct {
	Channel   int              `json:"channel"`
	PeakDB    measurementFloat `json:"peak_db"`
	AverageDB measurementFloat `json:"average_db"`
}

type executionInfo struct {
	BinaryPath    string           `json:"binary_path"`
	BinaryVersion string           `json:"binary_version"`
	ExecSeconds   measurementFloat `json:"execution_seconds"`
	SpeedIndex    measurementFloat `json:"speed_index"`
	Mbps          measurementFloat `json:"mbps"`
}

type iirCoefficients struct {
	a []float64
	b []float64
}

type iirFilter struct {
	coeffs   iirCoefficients
	xHistory []float64
	yHistory []float64
}

type measurementFloat float64

func (m measurementFloat) MarshalJSON() ([]byte, error) {
	v := math.Round(float64(m)*1e4) / 1e4
	formatted := fmt.Sprintf("%.4f", v)
	if strings.Contains(formatted, ".") {
		formatted = strings.TrimRight(formatted, "0")
		if strings.HasSuffix(formatted, ".") {
			formatted += "0"
		}
	}
	return []byte(formatted), nil
}

func newIIRFilter(sampleRate int) (*iirFilter, error) {
	coeffs, ok := mWeightingCoefficients[sampleRate]
	if !ok {
		return nil, fmt.Errorf("unsupported sample rate %d for M-weighting filter", sampleRate)
	}
	filter := &iirFilter{
		coeffs:   coeffs,
		xHistory: make([]float64, len(coeffs.b)),
		yHistory: make([]float64, len(coeffs.a)-1),
	}
	return filter, nil
}

func (f *iirFilter) Process(sample float64) float64 {
	// shift input history
	for i := len(f.xHistory) - 1; i >= 1; i-- {
		f.xHistory[i] = f.xHistory[i-1]
	}
	f.xHistory[0] = sample

	// compute filter output
	var y float64
	for i := 0; i < len(f.coeffs.b); i++ {
		y += f.coeffs.b[i] * f.xHistory[i]
	}
	for i := 1; i < len(f.coeffs.a); i++ {
		y -= f.coeffs.a[i] * f.yHistory[i-1]
	}

	if len(f.yHistory) > 0 {
		for i := len(f.yHistory) - 1; i >= 1; i-- {
			f.yHistory[i] = f.yHistory[i-1]
		}
		f.yHistory[0] = y
	}

	return y
}

var mWeightingCoefficients = map[int]iirCoefficients{
	44100: {
		a: []float64{1.0, -1.5224995723629664, 1.3617953870010380, -0.7794603877415162, 0.2773974331876455, -0.0477648119172564},
		b: []float64{0.4034108659797224, 0.0675046624145518, -0.3122917473135974, -0.1471391464872613, -0.0173711282192394, 0.0101026340442429},
	},
	48000: {
		a: []float64{1.0, -1.6391291074367320, 1.5160386192837869, -0.8555167646249104, 0.2870466545317107, -0.0428951718612053},
		b: []float64{0.31837346242469328, 0.10800452155339044, -0.21106344349319428, -0.15438275853192485, -0.05130596901975942, -0.00518224535906041},
	},
}

func main() {
	if len(os.Args) < 2 {
		fmt.Fprintln(os.Stderr, "usage: leqm-go <audiofile>")
		os.Exit(1)
	}

	start := time.Now()

	inputPath := os.Args[1]
	if err := validateExtension(inputPath); err != nil {
		fmt.Fprintln(os.Stderr, err)
		os.Exit(1)
	}

	meta, err := probeAudio(inputPath)
	if err != nil {
		fmt.Fprintln(os.Stderr, "ffprobe error:", err)
		os.Exit(1)
	}
	if meta.Channels <= 0 {
		fmt.Fprintln(os.Stderr, "no audio stream detected")
		os.Exit(1)
	}

	targetSampleRate := meta.SampleRate
	notes := []string{}
	if _, ok := mWeightingCoefficients[targetSampleRate]; !ok {
		targetSampleRate = 48000
		notes = append(notes, fmt.Sprintf("resampled to %d Hz for M-weighting filter", targetSampleRate))
	}

	result, err := measureLoudness(inputPath, meta, targetSampleRate)
	if err != nil {
		fmt.Fprintln(os.Stderr, "processing error:", err)
		os.Exit(1)
	}
	result.ProcessingNotes = append(result.ProcessingNotes, notes...)

	info, err := gatherExecutionInfo(inputPath, start, result.AudioDurationSeconds)
	if err != nil {
		fmt.Fprintln(os.Stderr, "execution info error:", err)
		os.Exit(1)
	}
	result.Execution = info

	payload, err := json.MarshalIndent(result, "", "  ")
	if err != nil {
		fmt.Fprintln(os.Stderr, "cannot serialize result:", err)
		os.Exit(1)
	}

	fmt.Println(string(payload))
}

func validateExtension(path string) error {
	ext := strings.ToLower(filepath.Ext(path))
	if _, ok := supportedExtensions[ext]; !ok {
		return fmt.Errorf("unsupported file extension %s: allowed extensions are .wav, .mp3, .m4a", ext)
	}
	return nil
}

func probeAudio(path string) (audioMetadata, error) {
	cmd := exec.Command("ffprobe",
		"-v", "error",
		"-select_streams", "a:0",
		"-show_entries", "stream=sample_rate,channels,duration",
		"-of", "json",
		path,
	)

	var stdout bytes.Buffer
	var stderr bytes.Buffer
	cmd.Stdout = &stdout
	cmd.Stderr = &stderr

	if err := cmd.Run(); err != nil {
		return audioMetadata{}, fmt.Errorf("ffprobe failed: %w (%s)", err, strings.TrimSpace(stderr.String()))
	}

	var parsed ffprobeOutput
	if err := json.Unmarshal(stdout.Bytes(), &parsed); err != nil {
		return audioMetadata{}, fmt.Errorf("cannot parse ffprobe output: %w", err)
	}
	if len(parsed.Streams) == 0 {
		return audioMetadata{}, errors.New("ffprobe returned no audio streams")
	}

	sr, err := strconv.Atoi(parsed.Streams[0].SampleRate)
	if err != nil {
		return audioMetadata{}, fmt.Errorf("invalid sample rate in ffprobe output: %w", err)
	}

	dur := 0.0
	if parsed.Streams[0].Duration != "" {
		if val, err := strconv.ParseFloat(parsed.Streams[0].Duration, 64); err == nil {
			dur = val
		}
	}

	return audioMetadata{
		SampleRate: sr,
		Channels:   parsed.Streams[0].Channels,
		Duration:   dur,
	}, nil
}

func measureLoudness(path string, meta audioMetadata, targetSampleRate int) (loudnessResult, error) {
	cmd := exec.Command("ffmpeg",
		"-v", "error",
		"-i", path,
		"-ac", strconv.Itoa(meta.Channels),
		"-ar", strconv.Itoa(targetSampleRate),
		"-f", "f32le",
		"-acodec", "pcm_f32le",
		"pipe:1",
	)

	var stderr bytes.Buffer
	cmd.Stderr = &stderr

	stdout, err := cmd.StdoutPipe()
	if err != nil {
		return loudnessResult{}, fmt.Errorf("cannot create ffmpeg stdout pipe: %w", err)
	}

	if err := cmd.Start(); err != nil {
		return loudnessResult{}, fmt.Errorf("ffmpeg start failed: %w (%s)", err, strings.TrimSpace(stderr.String()))
	}

	var raw []byte
	var rawErr error
	done := make(chan struct{})
	go func() {
		raw, rawErr = io.ReadAll(stdout)
		close(done)
	}()
	<-done
	if rawErr != nil {
		cmd.Wait()
		return loudnessResult{}, fmt.Errorf("cannot read decoded samples: %w", rawErr)
	}

	if err := cmd.Wait(); err != nil {
		return loudnessResult{}, fmt.Errorf("ffmpeg decoding failed: %w (%s)", err, strings.TrimSpace(stderr.String()))
	}

	if len(raw)%4 != 0 {
		return loudnessResult{}, fmt.Errorf("decoded byte stream not aligned to 32-bit float samples")
	}

	totalSamples := len(raw) / 4
	if totalSamples%meta.Channels != 0 {
		return loudnessResult{}, fmt.Errorf("decoded samples not divisible by channel count")
	}

	floatSamples := make([]float64, totalSamples)
	for i := 0; i < totalSamples; i++ {
		bits := binary.LittleEndian.Uint32(raw[i*4 : (i+1)*4])
		floatSamples[i] = float64(math.Float32frombits(bits))
	}

	frames := totalSamples / meta.Channels
	if frames == 0 {
		return loudnessResult{}, errors.New("audio stream contains no frames")
	}

	filters := make([]*iirFilter, meta.Channels)
	channelEnergy := make([]float64, meta.Channels)
	channelPeak := make([]float64, meta.Channels)
	for ch := 0; ch < meta.Channels; ch++ {
		filter, err := newIIRFilter(targetSampleRate)
		if err != nil {
			return loudnessResult{}, err
		}
		filters[ch] = filter
	}

	var sumEnergy float64
	var sumWeighted float64

	for frame := 0; frame < frames; frame++ {
		frameOffset := frame * meta.Channels
		var frameEnergy float64
		var frameWeighted float64
		for ch := 0; ch < meta.Channels; ch++ {
			sample := floatSamples[frameOffset+ch]
			frameEnergy += sample * sample
			channelEnergy[ch] += sample * sample
			absSample := math.Abs(sample)
			if absSample > channelPeak[ch] {
				channelPeak[ch] = absSample
			}
			filtered := filters[ch].Process(sample)
			frameWeighted += filtered * filtered
		}
		sumEnergy += frameEnergy
		sumWeighted += frameWeighted
	}

	frameCount := float64(frames)
	meanPower := sumEnergy / frameCount
	meanPowerWeighted := sumWeighted / frameCount

	rms := energyToLevel(meanPower)
	leqM := energyToLevel(meanPowerWeighted)

	duration := float64(frames) / float64(targetSampleRate)

	meanPower = roundToDecimals(meanPower, decimalDigits)
	meanPowerWeighted = roundToDecimals(meanPowerWeighted, decimalDigits)
	rms = roundToDecimals(rms, decimalDigits)
	leqM = roundToDecimals(leqM, decimalDigits)

	channelStats := make([]channelStat, meta.Channels)
	for ch := 0; ch < meta.Channels; ch++ {
		meanPowerCh := channelEnergy[ch] / frameCount
		peakPower := channelPeak[ch] * channelPeak[ch]
		channelStats[ch] = channelStat{
			Channel:   ch,
			PeakDB:    measurementFloat(energyToLevel(peakPower)),
			AverageDB: measurementFloat(energyToLevel(meanPowerCh)),
		}
	}

	metadataDuration := roundToDecimals(duration, decimalDigits)
	audioDuration := duration

	metadata := loudnessMetadata{
		File:                path,
		OriginalSampleRate:  meta.SampleRate,
		EffectiveSampleRate: targetSampleRate,
		Channels:            meta.Channels,
		Frames:              int64(frames),
		DurationSeconds:     measurementFloat(metadataDuration),
	}

	result := loudnessResult{
		Metadata: metadata,
		Measurements: loudnessMeasurements{
			LeqM:              measurementFloat(leqM),
			LeqNoW:            measurementFloat(rms),
			MeanPower:         measurementFloat(meanPower),
			MeanPowerWeighted: measurementFloat(meanPowerWeighted),
		},
		ReferenceOffsetDB:    referenceOffsetDB,
		ChannelStats:         channelStats,
		AudioDurationSeconds: audioDuration,
	}

	// Prefer measured duration when available from metadata, but only if close.
	if meta.Duration > 0 && math.Abs(meta.Duration-duration) < 0.5 {
		audioDuration = meta.Duration
		metadataDuration = roundToDecimals(meta.Duration, decimalDigits)
		result.Metadata.DurationSeconds = measurementFloat(metadataDuration)
		result.AudioDurationSeconds = audioDuration
	}

	return result, nil
}

func roundToDecimals(val float64, decimals int) float64 {
	if decimals <= 0 || val == 0 {
		return 0
	}

	sign := 1.0
	if val < 0 {
		sign = -1
		val = -val
	}

	exponent := math.Floor(math.Log10(val))
	scale := math.Pow(10, exponent-float64(decimals)+1)
	if scale == 0 {
		return sign * val
	}

	truncated := math.Trunc(val/scale) * scale
	return sign * truncated
}

func gatherExecutionInfo(inputPath string, start time.Time, audioDuration float64) (executionInfo, error) {
	executable, execErr := os.Executable()
	if execErr != nil {
		executable = os.Args[0]
	} else {
		if resolved, err := filepath.EvalSymlinks(executable); err == nil {
			executable = resolved
		}
	}

	version := "development"
	if info, ok := debug.ReadBuildInfo(); ok && info != nil {
		if v := strings.TrimSpace(info.Main.Version); v != "" && v != "(devel)" {
			version = v
		}
	}

	fileInfo, err := os.Stat(inputPath)
	if err != nil {
		return executionInfo{}, err
	}

	execSeconds := time.Since(start).Seconds()
	if execSeconds < 0 {
		execSeconds = 0
	}

	speedIndex := 0.0
	if execSeconds > 0 {
		speedIndex = audioDuration / execSeconds
	}

	mbps := 0.0
	if execSeconds > 0 {
		mbps = (float64(fileInfo.Size()) / 1_000_000.0) / execSeconds
	}

	return executionInfo{
		BinaryPath:    executable,
		BinaryVersion: version,
		ExecSeconds:   measurementFloat(execSeconds),
		SpeedIndex:    measurementFloat(speedIndex),
		Mbps:          measurementFloat(mbps),
	}, nil
}

func energyToLevel(meanPower float64) float64 {
	if meanPower <= 0 {
		return 0.0
	}
	level := 20*math.Log10(math.Sqrt(meanPower)) + referenceOffsetDB
	if level < 0 {
		return 0.0
	}
	return level
}
