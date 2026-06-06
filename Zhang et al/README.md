# Zhang et al. · DCT-domain JND with parabolic luminance adaptation and block-classified contrast masking

> **Lineage:** Subband refinement
> **Domain:** Transform (DCT)
> **Reference:** Zhang, X. H., Lin, W. S., and Xue, P., "Improved estimation for just-noticeable visual distortion," *Signal Processing*, vol. 85, no. 4, pp. 795–808, 2005.

This directory contains the OpenJND implementation of Zhang et al.'s DCT-domain JND model. Building directly on the Ahumada–Peterson spatial-CSF model and Watson's DCTune, it sharpens two specific weaknesses of those estimators: an inaccurate luminance-adaptation base threshold at dark and bright extremes, and an over-estimated contrast-masking elevation factor around edges.

## What the model does

For each 8×8 block, the JND of each DCT coefficient is expressed, as in DCTune, as the product of a **base threshold** `t_b` (spatial CSF × luminance adaptation) and an **elevation factor** `a_CM` (contrast masking), with a final global scale `tfac`:

```
t_JND(n1, n2, i, j) = tfac · t_ij(i, j) · a_lum(n1, n2) · a_CM(n1, n2, i, j),    tfac = 0.3
```

The four building blocks:

1. **Spatial CSF (Ahumada–Peterson 1992).** Per-coefficient base thresholds `t_ij(i, j)` are computed from spatial frequency, orientation, and an assumed mean display luminance `LB`. The CSF parameters used by the reference implementation are the standard Ahumada–Peterson fit:

```
   LT = 13.45,  S0 = 94.7,  aT = 0.649,        % threshold lifting
   f0 = 6.78,   af = 0.182, Lf = 300,           % peak-frequency curve
   K0 = 3.125,  aK = 0.0706, LK = 300,          % bandwidth
   s  = 0.25,   r  = 0.6,    LB = 65 cd/m²      % overall scale & orientation
```

   An orientation correction `1 / (r + (1 − r) · cos²(θ))` (`r = 0.6`) is applied to off-axis DCT frequencies. The DC threshold is set to `min(t_ij(0,1), t_ij(1,0))` to avoid a singular value at zero frequency.

2. **Parabolic luminance adaptation.** Driven by the block DC coefficient `C(n1, n2, 0, 0)`, the LA factor is a two-branch function around `C00 = 1024`:

```
   a_lum = { k_T · (1 − C/C00)^a_T + 1     if C ≤ C00
           { k_Q · (C/C00 − 1)^a_Q + 1     otherwise
```

   with `k_T = 2, a_T = 3, k_Q = 0.8, a_Q = 2`. This is higher in very dark *and* very bright regions, lowest around mid-grey — the parabolic correction that mainly improves accuracy below gray level 128 where DCTune is least faithful.

3. **Block classification.** Every 8×8 block is assigned to PLAIN / EDGE / TEXTURE from sums of absolute DCT coefficients in the low-frequency `lowf`, edge-frequency `edg` and high-frequency `highf` groups, with the empirical thresholds from the paper:

   | Symbol | Value | Role |
   |--------|-------|------|
   | u1, u2 | 125, 900 | Cutoffs on `edg + highf` for PLAIN / mixed / TEXTURE |
   | k1 | 290 | Secondary PLAIN-vs-TEXTURE cutoff in the mixed range |
   | a1, b1 | 6.9, 4.8 | High-energy edge ratios (`a1 = 2.3·3, b1 = 1.6·3`) |
   | a2, b2 | 1, 1.6 | Low-energy edge ratios |
   | y1, y | 2.0, 16 | Cutoffs on `(lowf + edg) / highf` |

4. **Contrast masking with block-class-dependent elevation.** Inside TEXTURE blocks, each AC coefficient picks up an intra-band masking factor `max(1, |C / t_b|^0.36)` further multiplied by a texture-amplification `TexMask`:

```
   TEXTURE :  TexMask = 1 + (F_maxT − 1) · (TexE − 290) / (1800 − 290),     F_maxT = 2.5
   EDGE    :  TexMask = 1.125  if EdgE ≤ 400 else 1.25
   PLAIN   :  TexMask = 1
```

   Crucially, for EDGE blocks the LF and MF coefficients are **excluded from intra-band masking** — their `a_CM` is held at the per-block `TexMask` value only — which is exactly what prevents the JND over-estimation that DCTune produces around edges. The DC coefficient has `a_CM = 1` in all blocks.

## Behaviour of the JND map

- The map is per-coefficient in the DCT domain and carries the imprint of the 8×8 block grid by construction — appropriate for block-based codecs.
- EDGE blocks receive lower budgets than TEXTURE blocks of comparable energy, because their LF/MF bands are kept out of the masking elevation.
- Better matched to subjective scores than DCTune, especially in dark regions and around object boundaries (validated by subjective tests on Actor and Lena, and in JPEG-style compression).

## Directory layout

```
Zhang et al/
├── MATLAB/          # reference implementation (main.m)
├── Python/          # ported implementation (main.py)
└── paper.pdf        # original paper
```

## Unified calling convention

```
INPUT  : grayscale image  (uint8 / float, H × W; H and W are auto-cropped to multiples of 8)
OUTPUT : JND map  (float, H' × W' where H', W' are the post-crop dimensions)
```

Internally the input is partitioned into non-overlapping 8×8 blocks, each block is DCT-transformed and classified (PLAIN / EDGE / TEXTURE), and a per-coefficient threshold is derived from the base threshold and elevation factor. The output is the spatial-domain assembly of the per-coefficient thresholds (one threshold value per pixel position).

## Minimal usage example

**MATLAB**
```matlab
addpath('MATLAB');
img = imread('../test_data/lena.png');
if size(img, 3) == 3, img = rgb2gray(img); end
jnd = JND_dct(img);
imagesc(jnd); colormap gray; colorbar;
```

**Python**
```bash
cd Python
pip install numpy scipy imageio matplotlib
python main.py
```

Programmatic call:
```python
from main import JND_dct
import imageio.v2 as imageio
img = imageio.imread('../test_data/lena.png', mode='L')
jnd = JND_dct(img)
```

## Default parameters

| Parameter | Default | Meaning |
|-----------|---------|---------|
| `bsize` | 8 | DCT block side length |
| `wx, wy` | 0.0298, 0.0298 | Horizontal / vertical pixel size in degrees of visual angle |
| `tfac` | 0.3 | Global JND scaler applied at the very end |
| `Lmax, Lmin, M` | 130, 0, 256 | Display luminance range and gray-level resolution |
| `LB` | 65 cd/m² | Assumed mean display luminance |
| `r` (orientation) | 0.6 | Orientation-correction shape constant |
| `s` (CSF scale) | 0.25 | Spatial-CSF overall scale |
| `LT, S0, aT` | 13.45, 94.7, 0.649 | CSF threshold-lifting parameters |
| `f0, af, Lf` | 6.78, 0.182, 300 | CSF peak-frequency parameters |
| `K0, aK, LK` | 3.125, 0.0706, 300 | CSF bandwidth parameters |
| `k_T, a_T, k_Q, a_Q, C00` | 2, 3, 0.8, 2, 1024 | Parabolic luminance-adaptation parameters |
| `u1, u2, k1` | 125, 900, 290 | Block-classification thresholds on `edg + highf` |
| `a1, b1` | 6.9, 4.8 | High-energy edge ratios in block classification |
| `a2, b2, y1, y` | 1, 1.6, 2.0, 16 | Low-energy edge ratios in block classification |
| `F_maxT` | 2.5 | Maximum texture-masking factor (TEXTURE blocks) |
| EDGE-block factor | 1.125 / 1.25 | Below / above 400 in edge energy `EdgE = edg + lowf` |
| Intra-band exponent | 0.36 | `max(1, |C / t_b|^0.36)` inside TEXTURE blocks |

All defaults reproduce the configuration used in the reference implementation.

## Citation

```bibtex
@article{zhang2005improved,
  title   = {Improved estimation for just-noticeable visual distortion},
  author  = {Zhang, X. H. and Lin, W. S. and Xue, P.},
  journal = {Signal Processing},
  volume  = {85}, number = {4}, pages = {795--808}, year = {2005}
}
```
