# Wu et al. (free-energy) · Cognitive-inspired JND with ordered / disordered split

> **Lineage:** Cognitive-inspired
> **Domain:** Pixel
> **Reference:** Wu, J., Shi, G., Lin, W., Liu, A., and Qi, F., "Just noticeable difference estimation for images with free-energy principle," *IEEE Transactions on Multimedia*, vol. 15, no. 7, pp. 1705–1710, November 2013.

This directory contains the OpenJND implementation of Wu et al.'s free-energy-based JND model — a conceptually distinct entry in the OpenJND catalogue, derived from Friston's free-energy principle and the Bayesian-brain account of perception.

## What the model does

The HVS is modelled as an **internal generative mechanism (IGM)** that actively predicts the orderly content of an image and *avoids* the residual disorderly content, on the grounds that disorder carries more uncertainty than the brain can usefully process. This concealment of disorder is exactly what existing pixel-domain JND models miss — they only sum luminance adaptation and edge-based spatial masking, both of which are calibrated on orderly stimuli.

The implementation proceeds in five stages:

1. **Orderly-content prediction.** A non-local means (NL-means) reconstruction is used as the brain's predicted image `I_ar`. For each pixel, candidate values are drawn from a `21 × 21` search window (`R = 10`), and weighted by patch similarity over a `7 × 7` patch (`r = 3`):

```
   w(p, q) = exp( −‖patch(p) − patch(q)‖² / σ(p)² )
   I_ar(p) = Σ_q w(p, q) · I(q)  /  Σ_q w(p, q)
```

   The per-pixel adaptive `σ(p)` is set from the local luminance-adaptation threshold (lower-bounded at `min_sigma = 8`) so that smooth regions average more aggressively than busy ones.

2. **Free-energy residual.** Whatever the IGM cannot predict is treated as disorder:

```
   I_FE = | I − I_ar |
```

3. **JND on the orderly component (`jnd_LA + jnd_CM` via NAMM).** Two classical pixel-domain terms are evaluated on the *predicted* image `I_ar`:

   - **Luminance adaptation (`jnd_LA`):** Chou-style piecewise curve with a dark-region adjuster (`min_lum = 32`) lifting very dark backgrounds to keep `jnd_LA` finite in shadows.

```
     bg_jnd(L) = { 17 · (1 − √(L/127)) + 3      if L ≤ 127
                 { (3/128) · (L − 127) + 3       if L > 127
```

   - **Contrast masking (`jnd_CM`):** the four-direction gradient `lum_diff` is log-compressed and combined with luminance-dependent slope and intercept:

```
     lum_diff' = thre · log10(1 + lum_diff / thre) / log10(4),   thre = 80
     jnd_CM    = | lum_diff' · α(bg) + β(bg) |
     α(bg) = 0.0001 · bg + 0.115
     β(bg) = 0.5 − 0.01 · bg
```

   The two are merged via NAMM:

```
   jnd_order = jnd_LA + jnd_CM − 0.3 · min( jnd_LA, jnd_CM )
```

4. **JND on the disorderly component (`jnd_disorder`).** The free-energy residual `I_FE` is taken as the starting disorder budget. In *smooth* regions (local std-deviation < 10) the budget is replaced by the smaller of `I_FE` and its `7×7` Gaussian average, to suppress single-pixel spikes. An edge-protect mask (Canny threshold 0.7, disk-2 dilation, `5 × 5` Gaussian σ = 0.8) then multiplies it down along visible edges:

```
   jnd_disorder = I_FE  ⊳  smooth_suppress  ·  edge_protect
```

5. **Final NAMM merge.** The two branches are combined the same way as in stage 3:

```
   jnd_map = jnd_order + jnd_disorder − 0.3 · min( jnd_order, jnd_disorder )
```

   Pixels within `r = 3` of the boundary are zeroed to avoid edge-padding artefacts.

## Behaviour of the JND map

- Substantially elevated JND on disordered regions — foliage, fabric, water surfaces, noise patches — where the NL-means reconstruction cannot predict well.
- Conservative on ordered regions — smooth gradients, regular textures, sharp edges (edge-protect zeroes the disorder contribution on edges).
- Captures a masking phenomenon that no purely contrast-based model can reach: the *unpredictability* of local content, not just its energy, sets the budget.
- In Wu et al.'s subjective study a JND-shaped JPEG pre-filter saved roughly 13–16% of bit rate at unchanged perceptual quality.

## Directory layout

```
Wu et al (TMM)/
├── MATLAB/
│   ├── main.m                       # entry-point demo on actor.png
│   ├── demo_JND_estimation.m        # equivalent demo on 1.png
│   ├── func_ar_predict_decomp.m     # NL-means prediction
│   ├── func_bg_lum_jnd.m            # luminance adaptation
│   ├── func_contrast_mask_jnd.m     # contrast masking
│   ├── func_disorder_jnd.m          # disorder branch + edge protect
│   ├── func_statistic_value.m       # local std-deviation
│   └── func_randnum.m               # ±1 random matrix for noise injection demo
└── paper.pdf
```

> **Coverage note.** This method is currently MATLAB-only in OpenJND. Python and C++ ports are on the OpenJND roadmap; the NL-means prediction step is the heaviest part of the pipeline and would benefit most from a vectorised port. Contributions are welcome — see the top-level `CONTRIBUTING.md`.

## Unified calling convention

The MATLAB code is organised as a sequence of helper functions rather than a single entry-point. `main.m` chains them together; calling the pipeline programmatically is a five-line affair:

```matlab
img_ar       = func_ar_predict_decomp(img0, 8);              % min_sigma = 8
img_FE       = abs(double(img0) − double(img_ar));
jnd_LA       = func_bg_lum_jnd(img_ar, 32);                  % min_lum = 32
jnd_CM       = func_contrast_mask_jnd(img_ar);
jnd_Dis      = func_disorder_jnd(img0, img_FE, 3);           % r = 3
jnd_order    = jnd_LA + jnd_CM    − 0.3 * min(jnd_LA, jnd_CM);
jnd_map      = jnd_order + jnd_Dis − 0.3 * min(jnd_order, jnd_Dis);
```

## Minimal usage example

**MATLAB**
```matlab
cd MATLAB
addpath(genpath('.'));
main;            % runs the full pipeline on actor.png and shows the JND mask
```

To run on your own image, edit the `imread` line at the top of `main.m`.

## Default parameters

| Parameter | Default | Meaning |
|-----------|---------|---------|
| `R` (NL-means search) | 10 | Half-side of the search window (`21 × 21` pixels in total) |
| `r` (NL-means patch / disorder ker) | 3 | Half-side of the patch for similarity weighting; also the Gaussian radius in the disorder branch |
| `min_sigma` | 8 | Lower bound on the NL-means smoothing kernel `σ` |
| `min_lum` | 32 | Dark-region floor used by `func_bg_lum_jnd` |
| `T₀, γ` (LA) | 17, 3/128 | Chou-style luminance adaptation parameters |
| `thre` (CM log) | 80 | Log-compression cutoff on `lum_diff` in `jnd_CM` |
| `λ` (β intercept) | 0.5 | Constant term of `β(bg)` |
| Smooth-region cutoff | std-dev < 10 | Threshold below which the disorder budget is replaced by `min(local_mean, I_FE)` |
| Disorder edge Canny | 0.7 | Canny threshold inside the disorder-branch edge protect |
| Disorder edge kernels | disk(2), 5×5 Gauss σ = 0.8 | Dilation and smoothing of the edge mask |
| `C^{gr}` (NAMM) | 0.3 | NAMM overlap-reduction factor (used twice) |
| `α` (noise demo) | 1 | Magnitude of the demo's JND-guided noise injection |

All defaults reproduce the configuration used in the reference implementation.

## Citation

```bibtex
@article{wu2013just,
  title   = {Just noticeable difference estimation for images with free-energy principle},
  author  = {Wu, Jinjian and Shi, Guangming and Lin, Weisi and Liu, Anmin and Qi, Fei},
  journal = {IEEE Transactions on Multimedia},
  volume  = {15}, number = {7}, pages = {1705--1710}, year = {2013}
}
```
