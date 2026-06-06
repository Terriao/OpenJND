# Jia et al. · DCT-domain JND with spatio-temporal CSF and eye-movement compensation

> **Lineage:** DCT formulation
> **Domain:** Transform (DCT) · video-aware
> **Reference:** Jia, Y., Lin, W., and Kassim, A. A., "Estimating just-noticeable distortion for video," *IEEE Transactions on Circuits and Systems for Video Technology*, vol. 16, no. 7, pp. 820–829, July 2006.

This directory contains the OpenJND implementation of Jia et al.'s DCT-domain JND estimator. The estimator extends a Zhang-style DCT-domain JND framework (CSF + luminance adaptation + block-classified contrast masking, see `Zhang et al/`) with two distinctive Jia-2006 components — a **spatio-temporal contrast sensitivity function (CSF)** and an **eye-movement compensation** stage — so that the same machinery handles still frames and frame pairs with motion through a single code path.

## What the model does

For each 8×8 block the JND of each DCT coefficient is the product of a base threshold (from the spatio-temporal CSF, with luminance adaptation) and an elevation factor (from contrast masking):

```
t_JND(n1, n2, i, j) = 0.4 · f_csf_lum(·) · a_CM(·)
```

The four building blocks:

1. **Spatio-temporal CSF.** Built on Kelly's stabilised threshold surface and Daly's natural-viewing extension, the CSF expresses sensitivity as a joint function of spatial frequency `f` (cy/deg) and retinal image velocity `v_R` (deg/s):

```
   csf(v_R, f) = c4 · k · c0 · c2 · |v_R| · (2π f c1)²  ·  exp( −4π c1 f / (f_max · c3) )
```

   with `f_max = 45.9 / (c2 · |v_R| + 2)` and `k = 6.1 + 7.3 · |log10(c2 · v_R / 3)|³`. The constants used are `c0 = 1.14, c1 = 0.67, c2 = 1.7, c3 = 1.186, c4 = 3.677`. The per-coefficient base threshold is `csf_max0 / csf(v_R, f)`, with an orientation correction `1 / (r + (1 − r) · cos²(θ))` (`r = 0.6, b = 2`) applied so that off-axis DCT frequencies are not over-sensitised.

2. **Eye-movement compensation.** Smooth-pursuit eye movements partially cancel image-plane motion, so the retinal velocity is

```
   v_R = v_I − min(s · v_I + v_min, v_max),     s = 0.92,  v_min = 0.15 deg/s,  v_max = 80 deg/s
```

   `v_I` is converted from the per-block displacement (in pixels per frame) via the viewing geometry (`pixels_per_degree = ceil(1/wx) ≈ 30`) and the frame rate. A 5×5 median filter is applied to the displacement field to suppress motion-vector outliers before computing `v_R`. In still-image mode (no motion supplied), `v_R = 0` and the CSF reduces to the spatial-only branch.

3. **Luminance adaptation (quasi-parabolic, on the block DC).** Driven by the DC DCT coefficient `C(n1, n2, 0, 0)` of the current block:

```
   a_lum = { k_T · (1 − C/C00)^a_T + 1     if C ≤ C00
           { k_Q · (C/C00 − 1)^a_Q + 1     otherwise
```

   with `k_T = 2, a_T = 3, k_Q = 0.8, a_Q = 2, C00 = 1024`. This is the Zhang-2005 parabolic LA branch — higher thresholds in very dark and very bright regions, lowest around mid-grey.

4. **Contrast masking via block classification.** Each 8×8 block is labelled PLAIN / EDGE / TEXTURE from sums of absolute DCT coefficients in the low-frequency (`L`), edge-frequency (`edg`) and high-frequency (`H`) groups, with empirical thresholds `u1 = 125`, `u2 = 900`, `k1 = 290`. The texture-masking elevation is then assigned per class — `1` for PLAIN, `1.125` or `1.25` for EDGE (depending on edge energy), and a linearly-ramped factor up to `FmaxT = 2.5` for TEXTURE. Inside a TEXTURE block, intra-band masking additionally raises the elevation by `max(1, |C/threshold|^0.36)`; in EDGE / PLAIN blocks the LF/MF coefficients are kept at the per-block texture-mask value only, which keeps edges sharply protected.

## Behaviour of the JND map

- Carries the imprint of the 8×8 block grid by construction (appropriate for block-based codecs).
- TEXTURE blocks get the largest budget; EDGE blocks stay conservative, especially in their LF/MF bands.
- When real motion vectors are supplied, the budget increases on moving regions in proportion to the residual retinal velocity left after eye-movement compensation; on stationary regions the map matches the still-image branch.

## Directory layout

```
Jia et al/
├── MATLAB/          # reference implementation (main.m + JND_VIDEO.m)
├── Python/          # ported implementation (main.py)
└── paper.pdf        # original paper
```

> **Coverage note.** A C++ port is currently in progress for this method.
>
> **Motion vector note.** The bundled implementation ships with a placeholder `motionvector(Y1, Y2)` that returns a zero motion field, so by default the JND reduces to the spatial-only branch. Drop in any standard block-matching or optical-flow estimator (returning a `H/8 × W/8 × 2` array of pixel-per-frame vectors) to enable the full motion-aware behaviour. The CSF, the eye-movement compensation, the LA branch, and the block-classified masking all run unchanged.

## Unified calling convention

```
INPUT  : Y1, Y2 — two grayscale frames     (uint8 / float, H × W; H and W multiples of 8)
OUTPUT : JND map of the same H × W shape   (float)
```

If only a single frame is available, pass it as both `Y1` and `Y2`; the CSF will then evaluate at `v_R = 0` (still-image mode).

## Minimal usage example

**MATLAB**
```matlab
addpath('MATLAB');
Y1 = imread('../test_data/actor.png');
Y2 = imread('../test_data/actor_shifted.png');     % or just Y2 = Y1 for still-image mode
if size(Y1, 3) == 3, Y1 = rgb2gray(Y1); end
if size(Y2, 3) == 3, Y2 = rgb2gray(Y2); end
JND = JND_video(Y1, Y2);
imshow(JND, []);
```

**Python**
```bash
cd Python
pip install numpy scipy opencv-python
python main.py
```

Programmatic call:
```python
from main import JND_video
import cv2
Y1 = cv2.imread('../test_data/actor.png',         cv2.IMREAD_GRAYSCALE)
Y2 = cv2.imread('../test_data/actor_shifted.png', cv2.IMREAD_GRAYSCALE)
jnd = JND_video(Y1, Y2)
```

Both frames must be the same size and dimensions divisible by 8; crop or pad upstream if needed.

## Default parameters

| Parameter | Default | Meaning |
|-----------|---------|---------|
| `bsize` | 8 | DCT block side length |
| `wx`, `wy` | 0.0342, 0.0342 | Horizontal / vertical pixel size in degrees of visual angle |
| `fps` | 30 | Frame rate, used to convert pixel/frame displacement to deg/s |
| `c0, c1, c2, c3, c4` | 1.14, 0.67, 1.7, 1.186, 3.677 | Spatio-temporal CSF shape constants |
| `s` | 0.92 | Smooth-pursuit eye-movement gain |
| `v_min` | 0.15 deg/s | Eye-movement drift floor (also still-image fallback velocity) |
| `v_max` | 80 deg/s | Saccadic ceiling |
| `r`, `b` | 0.6, 2 | Orientation-correction shape constants |
| `k_T, a_T, k_Q, a_Q, C00` | 2, 3, 0.8, 2, 1024 | Parabolic luminance-adaptation parameters |
| `u1, u2, k1` | 125, 900, 290 | Block-classification thresholds on `edg + highf` |
| `FmaxT` | 2.5 | Maximum texture-masking factor (TEXTURE blocks) |
| EDGE-block factor | 1.125 / 1.25 | Below / above 400 in edge energy |
| Intra-band exponent | 0.36 | `max(1, |C/threshold|^0.36)` inside TEXTURE blocks |
| `Lmax, Lmin, M` | 130, 0, 256 | Display luminance range and gray-level resolution |

All defaults reproduce the configuration used in the reference implementation.

## Citation

```bibtex
@article{jia2006estimating,
  title   = {Estimating just-noticeable distortion for video},
  author  = {Jia, Yuting and Lin, Weisi and Kassim, Ashraf A.},
  journal = {IEEE Transactions on Circuits and Systems for Video Technology},
  volume  = {16}, number = {7}, pages = {820--829}, year = {2006}
}
```
