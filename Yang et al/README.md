# Yang et al. · Nonlinear additive masking (NAMM) with edge-adaptive weighting

> **Lineage:** Temporal extension of the foundational model · NAMM combiner
> **Domain:** Pixel
> **Reference:** Yang, X., Lin, W., Lu, Z., Ong, E. P., and Yao, S., "Just noticeable distortion model and its applications in video coding," *Signal Processing: Image Communication*, vol. 20, no. 7, pp. 662–680, August 2005.

This directory contains the OpenJND implementation of Yang et al.'s JND model, which replaces the foundational Chou–Li max-rule combiner with a **nonlinear additive masking model (NAMM)** and adds an **edge-adaptive weight map** so that edges are not over-allocated JND budget.

## What the model does

Two HVS factors are estimated per pixel and then combined under NAMM:

1. **Background luminance adaptation `JNDl`.** Chou-style piecewise curve on the local mean luminance:

```
   JNDl(x,y) = { T₀ · (1 − √(bg/127)) + 3      if bg ≤ 127
               { γ · (bg − 127) + 3              if bg > 127
```

   with `T₀ = 17`, `γ = 3/128`, and `bg(x,y)` from the 5×5 weighted lowpass operator (weights summing to 32, centre excluded).

2. **Edge-adaptive texture masking `JNDt`.** The maximum weighted gradient `Gm(x,y)` over four directions (`G1..G4`, 5×5, normalised by 16) drives a luminance-dependent linear masking term:

```
   JNDt(x,y) = Gm(x,y) · W(x,y) · α(bg)  +  β(bg)
   α(bg) = 0.0001 · bg + 0.115
   β(bg) = λ − 0.01 · bg,    λ = 0.5
```

   `W(x,y)` is the **edge-adaptive weight map**, computed by:

```
   1. Canny edge detection on the input (threshold = 0.5)
   2. Morphological dilation with a disk of radius 6
   3. Scaling: W_raw = 1 − 0.95 · dilated_edges
   4. 7×7 Gaussian blur (σ = 0.8)
```

   `W` drops to roughly 0.05 along visible edges and stays near 1 elsewhere, so the masking budget is actively suppressed along edges (where distortion is most visible) and preserved on smooth and textured regions.

3. **NAMM combiner.** The two terms are merged with an additive form that explicitly subtracts their overlap:

```
   JND(x,y) = JNDl(x,y) + JNDt(x,y) − C_TG · min{ JNDl(x,y), JNDt(x,y) },    C_TG = 0.3
```

   `C_TG = 1` recovers the foundational Chou–Li max-rule; `C_TG = 0` is pure addition. The chosen `C_TG = 0.3` reflects the partial overlap that holds between luminance and texture masking on the Y channel.

## Behaviour of the JND map

- Smoother handling of edges than the Chou–Li max-rule, because `W` suppresses the texture-masking budget exactly where the HVS is most sensitive.
- The additive-with-overlap combination gives a larger overall JND budget than the max-rule in regions where both `JNDl` and `JNDt` are comparable in magnitude, which translates into more perceptually-lossless redundancy at matched visual quality.
- Serves as the spatial masking baseline reused by Liu et al. (`Liu et al/`) and Wu et al. (`Wu et al (TIP)`, `Wu et al (TMM)`).

## Directory layout

```
Yang et al/
├── MATLAB/          # reference implementation (main.m)
├── Python/          # ported implementation (main.py)
└── paper.pdf        # original paper
```

> **Coverage note.** The OpenJND release covers the NAMM combiner and the edge-adaptive weight map of Yang et al., evaluated on the Y/luminance channel. Two further branches discussed in the original paper — independent JND estimation on the Cb and Cr chrominance channels, and the inter-frame temporal-masking pathway `f(ild)` for video — are on the OpenJND roadmap. Contributions to extend the catalogue to colour and video are welcome (see the top-level `CONTRIBUTING.md`).

## Unified calling convention

```
INPUT  : grayscale image       (uint8 / float, H × W)
         mode flag             ('Chou' or 'Yang', default 'Yang')
OUTPUT : JND map of the same H × W shape (float)
```

The `'Yang'` mode applies the edge-adaptive weight `W` to the texture-masking term. The `'Chou'` mode disables `W` and reproduces the configuration of the foundational `Chou and Li/` model — useful as an ablation baseline.

## Minimal usage example

**MATLAB**
```matlab
addpath('MATLAB');
img = imread('../test_data/lena.png');
if size(img, 3) == 3, img = rgb2gray(img); end
jnd = JND_pixel(img, 'Yang');
imshow(mat2gray(jnd));
```

**Python**
```bash
cd Python
pip install numpy scipy opencv-python matplotlib
python main.py
```

Programmatic call:
```python
from main import jnd_pixel
import cv2
img = cv2.imread('../test_data/lena.png', cv2.IMREAD_GRAYSCALE)
jnd = jnd_pixel(img, 'Yang')
```

> The Python `'Yang'` branch uses a Canny edge-detection threshold of 0.3 (lower than the MATLAB default of 0.5) to compensate for the different Canny implementation in OpenCV vs MATLAB. The two ports therefore produce visually equivalent but not bit-identical maps; in `'Chou'` mode the only differences are floating-point ordering and the convolution-boundary convention.

## Default parameters

| Parameter | Default | Meaning |
|-----------|---------|---------|
| `T₀` | 17 | Base threshold at zero background luminance |
| `γ` | 3/128 | Slope of the bright branch of `JNDl` |
| `λ` | 0.5 | Constant term of `β(bg)` |
| `C_TG` | 0.3 | NAMM overlap-reduction factor (Y-channel value from the paper) |
| Canny threshold | 0.5 (MATLAB) / 0.3 (Python) | Edge cutoff for the edge-adaptive weight `W` |
| Dilation kernel | disk, radius 6 | Morphological dilation of the edge map |
| Edge attenuation | 0.95 | How strongly `W` drops on detected edges (`W_raw = 1 − 0.95·E`) |
| Gaussian smoothing | 7×7, σ = 0.8 | Smoothing of the edge-weight map `W` |

All defaults reproduce the configuration used in the reference implementation.

## Citation

```bibtex
@article{yang2005just,
  title   = {Just noticeable distortion model and its applications in video coding},
  author  = {Yang, Xiaokang and Lin, Weisi and Lu, Zhongkang and Ong, Ee Ping and Yao, Susu},
  journal = {Signal Processing: Image Communication},
  volume  = {20}, number = {7}, pages = {662--680}, year = {2005}
}
```
