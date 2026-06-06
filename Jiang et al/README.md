# Jiang et al. · Top-down JND from data-driven critical perceptual lossless (CPL) prediction

> **Lineage:** Top-down learning
> **Domain:** Transform (KLT)
> **Reference:** Jiang, Q., Liu, Z., Wang, S., Shao, F., and Lin, W., "Toward top-down just noticeable difference estimation of natural images," *IEEE Transactions on Image Processing*, vol. 31, pp. 3697–3712, 2022.

This directory contains the OpenJND implementation of Jiang et al.'s top-down JND model — the only top-down entry in the catalogue and the only one trained against subjective data.

## What the model does

All seven other methods in OpenJND are **bottom-up**: they list contributing masking factors (LA, CM, edge, texture, pattern, …) and combine them. Jiang et al. instead ask the more direct question: *at what point does distortion start to be noticed?* The model proceeds in three steps:

1. **Block-wise KLT.** The image is partitioned into non-overlapping 8×8 blocks (`kernel_size = K = 64`, side `√K = 8`). The covariance matrix of the vectorised blocks is eigen-decomposed (via PCA on the patch matrix) to give the KLT kernel and the per-coefficient energy distribution.

2. **Critical perceptually lossless (CPL) point.** The number `L` of leading spectral components needed for a perceptually-lossless reconstruction is *not* tuned per image; it is inferred from a pre-fitted **Weibull prior** over the cumulative normalised KLT-coefficient energy:

```
   weibull_pdf(x) = (β/η) · (x/η)^(β−1) · exp( −(x/η)^β ),   β = 894.16,  η = 0.99805
```

   The critical point is the prior-weighted expectation
```
   L = ceil( Σᵢ i · weibull(P_cum_i) / Σᵢ weibull(P_cum_i) )
```
   where `P_cum_i` is the cumulative normalised energy through the i-th spectral component. Users who already know the critical point for their setting can override this by passing `L > 0` explicitly.

3. **CPL reconstruction + edge-protect map.** Inverse-KLT is performed using only the first `L` spectral components to obtain the critical perceptually-lossless image `CPL`. The raw JND map is the absolute difference, then multiplied pixel-wise by an **edge-protect mask** so that edges (where humans really do notice distortion early) keep a near-zero budget:

```
   jnd_raw(x,y)  = | I(x,y) − I_CPL(x,y) |
   edge_protect  = gaussian5×5 ( 1 − dilate( Canny(I) ) )
   JND(x,y)      = jnd_raw(x,y) · edge_protect(x,y)
```

   The Canny threshold is set adaptively from the maximum gradient height (capped at 0.8); the dilation uses a disk of radius 3; the Gaussian smoothing uses σ = 0.8. The edge-protect step is on by default; pass `ed_pro = false` to disable it and recover the pure CPL-difference JND.

## Behaviour of the JND map

- Low budgets near edges — both by construction (KLT prior puts most energy in macro-structure, so the residual is small along edges) and by the explicit edge-protect post-multiplication.
- High budgets in busy textured regions, where the trailing KLT components contribute the most.
- Qualitatively consistent with the bottom-up consensus despite being derived from subjective data on 500 natural images rather than from explicit masking decomposition.
- Runs in roughly 0.3 s for a 1200 × 800 image in the reference MATLAB implementation; the Python port is comparable.

## Directory layout

```
Jiang et al/
├── MATLAB/          # reference implementation
│   ├── main.m              # entry-point script
│   ├── run_me.m            # short demo runner
│   ├── KLT_JND.m           # core algorithm
│   ├── patch_extract.m
│   ├── image_reshape.m
│   ├── weibull_com.m
│   ├── modcrop.m
│   └── img_scaled.m
├── Python/          # ported implementation (main.py)
└── paper.pdf        # original paper
```

The original authors' reference code is also hosted at <https://github.com/Zhentao-Liu/KLT-JND>.

## Unified calling convention

```
INPUT  : grayscale image  (double, H × W; H and W are auto-cropped to multiples of 8)
         ed_pro          (bool/0-1, default true in MATLAB) — apply the edge-protect mask
         L               (int, default 0) — override the Weibull-derived critical point
OUTPUT : jnd_map         (float, H' × W' where H',W' are post-crop dimensions)
         CPL             (float, the critical perceptually-lossless image)
         thre_final      (int, the critical point actually used)
```

Inputs must be single-channel (grayscale or a single colour-channel) and floating-point; the bundled drivers convert from RGB and from uint8 for you.

## Minimal usage example

**MATLAB**
```matlab
addpath('MATLAB');
img = imread('../test_data/lena.png');
img = modcrop(img, 8);
if size(img, 3) == 3, im = double(rgb2gray(img)); else, im = double(img); end
[jnd_map, CPL, thre_final] = KLT_JND(im, 1);     % ed_pro = 1, L derived from Weibull
imshow(jnd_map, []);
```

**Python**
```bash
cd Python
pip install numpy opencv-python
python main.py
```

Programmatic call:
```python
from main import KLT_JND
import cv2
img = cv2.imread('../test_data/lena.png', cv2.IMREAD_GRAYSCALE).astype(float)
jnd_map, CPL, thre_final = KLT_JND(im=img, ed_pro=True)
print('Critical point:', thre_final + 1)
```

> The Python port currently defaults to `ed_pro = False` in its `__main__` demo, while the MATLAB driver calls `KLT_JND(im, 1)`. Pass `ed_pro = True` (Python) or `1` (MATLAB) consistently if you want byte-comparable behaviour across the two ports.

## Default parameters

| Parameter | Default | Meaning |
|-----------|---------|---------|
| `kernel_size` | 64 | Number of spectral components per block (block side = √K = 8) |
| `β` (Weibull shape) | 894.16 | Shape parameter of the fitted CPL prior |
| `η` (Weibull scale) | 0.99805 | Scale parameter of the fitted CPL prior (called `γ` in the paper) |
| `ed_pro` | true | Apply the post-multiplication edge-protect mask |
| Canny edge ceiling | 0.8 | Upper cap on the adaptive Canny threshold inside `edge_protect` |
| Dilation kernel | disk, radius 3 | Morphological dilation applied to the Canny edge map |
| Gaussian smoothing | 5×5, σ = 0.8 | Smoothing of the edge-protect mask |

All defaults reproduce the configuration used in the reference implementation.

## Citation

```bibtex
@article{jiang2022toward,
  title   = {Toward top-down just noticeable difference estimation of natural images},
  author  = {Jiang, Qiuping and Liu, Zhentao and Wang, Shiqi and Shao, Feng and Lin, Weisi},
  journal = {IEEE Transactions on Image Processing},
  volume  = {31}, pages = {3697--3712}, year = {2022}
}
```
