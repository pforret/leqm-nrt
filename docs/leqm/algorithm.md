# Leq(M) Computation Pipeline

This document summarises the mathematical steps the original C implementation (`src/leqm-nrt.c`) performs to derive the Leq(M) value defined in ISO 21727.  It tracks the code path taken by the default non–real‑time run (`worker_function`) and indicates where optional features (gating, Dolby DI, etc.) hook into the pipeline.

## 1. Signal preparation

1. **Decode to linear PCM.**  Depending on the build configuration the program uses either libsndfile or FFmpeg to decode the input stream to interleaved floating‑point samples (`sf_read_double` / `avcodec_receive_frame`).
2. **Channel calibration (`inputcalib`, `chconf`).**  Per-channel gain coefficients (normally unity) can be supplied to emulate cinema B-chain alignment.  They scale the sample amplitudes before further processing (see `worker_function`, around lines 4500–4540).
3. **Block segmentation.**  Audio is broken into blocks of `buffersizems` milliseconds (default 850 ms, cf. lines 638 and 1263).  Each worker thread receives `nsamples = samplerate * buffersizems / 1000 * nch` interleaved samples.
4. **Optional resampling.**  When libsndfile is used at non-48 kHz sample rates the code can invoke the convolutional filter bank to approximate the official transfer function.  Recent builds favour the IIR implementation in `M_filter` for the commonly used 48 kHz rate.

## 2. M-weighting filter (`M_filter`)

The [ISO 21727](iso_2016.md) M-weighting curve is implemented as a cascade of recursive biquads.  The C code stores pre-computed denominator (`a`) and numerator (`b`) coefficients for 44.1 kHz and 48 kHz sampling rates (see table starting at line ~7330).  For a sample sequence \(x[n]\) the filter output \(y[n]\) is computed by

$$
 y[n] = \sum_{k=0}^{5} b_k x[n-k] - \sum_{k=1}^{5} a_k y[n-k]
$$

The difference equation is realised inside `M_filter`, with explicit case handling for the first few samples until enough history is populated (lines 7350–7460).  This gives a weighted pressure signal \(p_M[n]\) that mimics the standard’s equal-loudness curve.

When `--convpoints` is enabled the program instead convolves each block with the published 21-tap impulse response (functions `convolv_buff` and `loadIR`), but both branches ultimately produce the weighted signal `convolvedbuffer` used in the subsequent energy computation.

## 3. Squaring and energy accumulation

Within each worker block, the code performs three accumulations (lines 4518–4550):

1. **Weighted energy.**  The weighted samples are squared (`rectify`) and accumulated per channel (`accumulatech`) into `chsumaccumulator_conv`.
2. **Unweighted energy.**  The unfiltered samples are squared and accumulated into `chsumaccumulator_norm` (used for the "Leq(noW)" diagnostic value).
3. **Total sums.**  After the block is processed, `sumsamples` adds the channel sums into a shared `Sum` struct (`totsum`).  The struct stores:
   - `sum` – cumulative unweighted energy \(\sum x^2\)
   - `csum` – cumulative weighted energy \(\sum p_M^2\)
   - `nsamples` – total number of mono samples accumulated (frames × channels)

These arrays are protected by a mutex when multiple threads run in parallel.

## 4. Converting to Leq(M)

Once all samples are processed, `meanoverduration` (lines 5856–5871) performs the ISO integration:

$$
 L_{\mathrm{eq(M)}} = 20 \log_{10} \left(\sqrt{\frac{\texttt{csum}}{\texttt{nsamples}}}\right) + 108.0103
$$

The same routine also produces the unweighted RMS level from `sum`.  The constant `108.010299957` is derived from the reference sound pressure (20 µPa) and the nominal calibration tone level (–20 dBFS), as documented in the inline comments around lines 5838–5869.

Because the accumulation is linear over sample squares, the discrete formulation faithfully approximates the continuous integral used by the standard:

$$
 L_{eq(M)} = 10 \log_{10}\left( \frac{1}{T} \int_0^T \frac{p_M(t)^2}{p_0^2}\, dt \right)
$$

where \(T\) is the total observation time and \(p_0 = 20\,\mu\text{Pa}\).  In the implementation \(p_M(t)\) is represented by the filtered discrete sequence and the integral is replaced by the sample mean of squared values.

## 5. Optional gating (LKFS/Dialogue Intelligence)

The alternative worker `worker_function_gated2` adds loudness gating similar to ITU-R BS.1770:

1. **Short-term windows.**  `calcSampleStepLG` derives the hop size `ops` from the configured overlap (default 75 %), yielding a 400 ms gating block as required by the standard (lines 1853–1895).
2. **Pre-filtering for gating.**  Each gate block is filtered with the K-weighting stages `K_filter_stage1/2` and rectified (lines 4573–4632).
3. **Relative and absolute gates.**  Level and dialogue gates are applied depending on `chgateconf`, `levelgate`, and `dolbydi` settings.  If a block energy falls below threshold it is discarded before the final mean is computed (see `lkfs_finalcomputation` and `dolbydifinalcomputation2`).

These gated sums feed either an LKFS measurement or a dialogue-specific variant, but the core Leq(M) channel is unaffected unless a level gate is explicitly enabled.

## 6. Output metrics

The program finally reports:

- `Leq(M)` – weighted level as described above.
- `Leq(noW)` – unweighted level derived from `sum`.
- `True Peak` (optional) – computed by the oversampling routine `truepeakcheck` which upsamples each channel (default ×4) and tracks the maximum squared sample.
- Logging arrays for `Leq(M,10m)` and time-varying loudness when the respective switches are set (see `logleqm` and `logleqm10`).

## Summary

The essential Leq(M) calculation in `leqm-nrt` can therefore be summarised as:

1. Decode audio, calibrate per channel, and break into manageable blocks.
2. Apply the M-weighting filter to each block (IIR or FIR implementation).
3. Square and accumulate both weighted and unweighted energies over all samples.
4. Divide by the total sample count and convert to dB SPL using the ISO reference offset.
5. Optionally perform gating before the final mean is formed if LKFS/DI modes are active.

Every step maps directly to well-documented functions in `src/leqm-nrt.c`, so the mathematical intent is visible and aligns with ISO 21727’s formal definition of Leq(M).
