# Liu et al. · TV-based decomposition for edge / texture separation

> **Lineage:** Decomposition era
> **Domain:** Pixel
> **Reference:** Liu, A., Lin, W., Paul, M., Deng, C., and Zhang, F., "Just noticeable difference for images with decomposition model for separating edge and textured regions," *IEEE Transactions on Circuits and Systems for Video Technology*, vol. 20, no. 11, pp. 1648–1652, November 2010.

This directory contains the OpenJND implementation of Liu et al.'s pixel-domain JND model, which addresses a long-standing misclassification problem in earlier contrast-masking estimators by separating the image into structural and textural components before computing the masking budget.

## What the model does

Earlier pixel-domain estimators lump strong gradients into a single "high-frequency" bucket and apply one contrast-masking gain to both edges and textures. This systematically underestimates the JND budget of texture regions — which the HVS in fact tolerates much more than edges, because textures carry higher entropy masking.

Liu et al. fix this by:

1. **Image decomposition.** The input image `I` is split into a **structural component** `I_s` (cartoon-like, piecewise smooth with sharp edges) and a **textural component** `I_t = I − I_s` via **total-variation (TV-L¹) decomposition** with regularisation `λ = 0.8`. The reference implementation uses Wotao Yin's ParaMaxFlow code (Rice CAAM TR07-09) — a parametric max-flow solver for TV-L¹ — with 4-connected neighbours.

2. **Background-luminance branch `JNDl`.** Chou-style luminance adaptation on the 5×5-averaged background luminance:

```
   JNDl = { T₀ · (1 − √(bg/127)) + 3      if bg ≤ 127
          { γ · (bg − 127) + 3              if bg > 127
```

   with `T₀ = 17` and `γ = 3/128`.

3. **Edge-masking and texture-masking branches.** The same four-direction gradient operator from Chou & Li gives `Gm_e` on the structural component and `Gm_t` on the textural component. Both masking thresholds use the Chou-style luminance-dependent slope and intercept (after Chou & Chen 1996):

```
   JNDt_e = clip( Gm_e · α(bg) + β(bg),  0, 10 )
   JNDt_t = clip( Gm_t · α(bg) + β(bg),  0, 10 )
   α(bg) = 0.0001 · bg + 0.115
   β(bg) = 0.5 − 0.01 · bg
```

   The two branches are then combined with weights that reflect the higher tolerance of textures:

```
   JNDt = W_e · JNDt_e + W_t · JNDt_t,    W_e = 0.7,  W_t = 1.4
```

4. **NAMM combiner.** Following Yang et al. 2005, the luminance and masking branches are merged via the nonlinear-additive masking model:

```
   JND = JNDl + JNDt − C_TG · min(JNDl, JNDt),   C_TG = 0.3
```

## Behaviour of the JND map

- Textures recover a noticeably larger JND budget than they get from undecomposed contrast-masking models.
- Edges remain protected — the structural component preserves them sharply, and the `W_e < W_t` weighting keeps their masking contribution conservative.
- Reports an average of ≈1.15 dB additional PSNR redundancy over earlier pixel-domain estimators at matched perceived quality.

## Directory layout

```
Liu et al/
├── MATLAB/                          # reference implementation
│   ├── main.m                       # entry-point script
│   ├── JND_ID.m                     # core algorithm
│   ├── Graph_anisoTV_L1_v2.m        # wrapper for the TV-L¹ solver
│   └── mt_TV_L1_8bit.mexw64         # precompiled MEX (Windows-only)
├── Python/                          # ported implementation (main.py)
└── paper.pdf                        # original paper
```

> **Platform note (MATLAB).** The MATLAB port depends on Wotao Yin's ParaMaxFlow MEX library (`mt_TV_L1_8bit.mexw64`), which is provided here pre-compiled for **64-bit Windows**. Linux / macOS users need to obtain the corresponding `.mexa64` / `.mexmaci64` builds from <http://www.caam.rice.edu/~wy1/ParaMaxFlow/> or rebuild the library from the original source.
>
> **Port note (Python).** The Python port substitutes a **Gaussian-blur surrogate** for the TV-L¹ decomposition: `I_s = GaussianBlur(I, kernel=7×7, σ = λ)`. This is a deliberate simplification — the TV-L¹ solver carries a non-trivial dependency and is not straightforward to wrap from Python. Gaussian blur gives a qualitatively similar structural / textural split (low frequencies stay in `I_s`, high-frequency texture goes to `I_t`) but does *not* preserve sharp edges the way TV-L¹ does, so the two ports produce visually similar but numerically different JND maps. The runtime trade-off is what we report in the top-level Runtime Analysis.

## Unified calling convention

```
INPUT  : grayscale image  (uint8 / float, H × W)
         optional lambda  (default 0.8) — TV-L¹ regularisation (MATLAB)
                                          / Gaussian σ for the structural-component surrogate (Python)
OUTPUT : JND map of the same H × W shape  (float)
```

## Minimal usage example

**MATLAB**
```matlab
addpath('MATLAB');
img = imread('../test_data/barbara.png');
if size(img, 3) == 3, img = rgb2gray(img); end
jnd = JND_ID(img);                % default lambda = 0.8
imshow(jnd, []);
```

**Python**
```bash
cd Python
pip install numpy scipy opencv-python matplotlib
python main.py
```

Programmatic call:
```python
from main import jnd_id
import cv2
img = cv2.imread('../test_data/barbara.png', cv2.IMREAD_GRAYSCALE)
jnd = jnd_id(img, lambda_=0.8)
```

## Default parameters

| Parameter | Default | Meaning |
|-----------|---------|---------|
| `λ` (TV-L¹) | 0.8 | MATLAB: regularisation weight of the TV-L¹ structural extraction. Python: Gaussian σ for the surrogate. |
| `nNeighbors` | 4 | MATLAB only: 4-connected neighbourhood in the TV-L¹ solver |
| `biThread` | 2 | MATLAB only: ParaMaxFlow solver thread mode (UP-thread) |
| `T₀` | 17 | Base luminance-adaptation threshold |
| `γ` | 3/128 | Bright-branch slope of `JNDl` |
| `λ_β` | 0.5 | Constant term of `β(bg)` |
| `JNDt` clip | [0, 10] | Edge / texture masking thresholds are clipped before weighting |
| `W_e` | 0.7 | Weight on the edge-masking branch |
| `W_t` | 1.4 | Weight on the texture-masking branch |
| `C_TG` | 0.3 | NAMM overlap-reduction factor |

All defaults reproduce the configuration used in the reference implementation.

## Citation

```bibtex
@article{liu2010just,
  title   = {Just noticeable difference for images with decomposition model for separating edge and textured regions},
  author  = {Liu, Anmin and Lin, Weisi and Paul, Manoranjan and Deng, Chenwei and Zhang, Fan},
  journal = {IEEE Transactions on Circuits and Systems for Video Technology},
  volume  = {20}, number = {11}, pages = {1648--1652}, year = {2010}
}
```

If you use the TV-L¹ decomposition step, please also acknowledge:

> W. Yin, ParaMaxFlow toolbox, <http://www.caam.rice.edu/~wy1/ParaMaxFlow/>, Rice University CAAM TR07-09.
