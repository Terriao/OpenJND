# Chou & Li · Foundational pixel-domain JND model

> **Lineage:** Foundational
> **Domain:** Pixel
> **Reference:** Chou, C.-H. and Li, Y.-C., "A perceptually tuned subband image coder based on the measure of just-noticeable-distortion profile," *IEEE Transactions on Circuits and Systems for Video Technology*, vol. 5, no. 6, pp. 467–476, December 1995.

This directory contains the OpenJND implementation of the foundational pixel-domain JND model proposed by Chou and Li. It is the cornerstone model around which the rest of the OpenJND catalogue is organised.

## What the model does

Chou & Li estimate a per-pixel visibility threshold from two HVS factors:

1. **Background luminance adaptation `JNDl`.** The HVS is more tolerant to distortion in very dark and very bright regions and most sensitive around mid-grey (≈127). The luminance term is modelled as a piecewise function — a square-root rise in dark regions and a linear ramp in bright regions:

```
   JNDl(x,y) = { T₀ · (1 − √(bg/127)) + 3      if bg ≤ 127
               { γ · (bg − 127) + 3              if bg > 127
```

   with `T₀ = 17` and `γ = 3/128`, where `bg(x,y)` is the local mean luminance computed with the 5×5 weighted lowpass operator from the original paper (centre pixel excluded; weights summing to 32).

2. **Texture / spatial masking `JNDt`.** The maximum weighted gradient `Gm(x,y)` over a 5×5 neighbourhood is computed in four directions using the operators `G1, G2, G3, G4` from the paper (normalised by 16). The masking term scales linearly with `Gm` through luminance-dependent slope `α` and intercept `β`:

```
   JNDt(x,y) = Gm(x,y) · α(bg)  +  β(bg)
   α(bg) = 0.0001 · bg + 0.115
   β(bg) = λ − 0.01 · bg,    λ = 0.5
```

The two terms are combined into the final pixel-wise JND as

```
JND(x,y) = JNDl(x,y) + JNDt(x,y) − C_TG · min{ JNDl(x,y), JNDt(x,y) },    C_TG = 0.3
```

The companion paper also introduces **PSPNR** (Peak Signal-to-Perceptible-Noise Ratio), a fidelity metric that counts only the distortion above the JND threshold.

## Behaviour of the JND map

- Large budgets on dark and on busy regions.
- Relatively conservative near isolated edges.
- The estimator is image-plane and grayscale by construction — it serves as the spatial baseline reused by Yang et al., Wu et al., and Liu et al.

## Directory layout

```
Chou and Li/
├── MATLAB/          # reference implementation (main.m)
├── Python/          # ported implementation (main.py)
└── paper.pdf        # original paper
```

## Unified calling convention

```
INPUT  : grayscale image       (uint8 / float, H × W)
         mode flag             ('Chou' or 'Yang')
OUTPUT : JND map of the same H × W shape (float)
```

The `'Chou'` mode reproduces the configuration described above. The `'Yang'` mode swaps the texture-masking term for a Canny-based edge-protect variant that is reused by `Yang et al/`; pass `'Chou'` to stay within the scope of the foundational model.

## Minimal usage example

**MATLAB**
```matlab
addpath('MATLAB');
img = imread('../test_data/lena.png');
jnd = JND_pixel(img, 'Chou');
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
jnd = jnd_pixel(img, 'Chou')
```

## Default parameters

| Parameter | Default | Meaning |
|-----------|---------|---------|
| `T₀` | 17 | Base threshold at zero background luminance (`JNDl` at bg = 0) |
| `γ` | 3/128 | Slope of the bright branch of `JNDl` |
| `λ` | 0.5 | Constant term of `β(bg)` in `JNDt` |
| `C_TG` | 0.3 | Combiner factor when merging `JNDl` and `JNDt` |

All defaults reproduce the numbers reported in the original publication.

## Citation

```bibtex
@article{chou1995perceptually,
  title   = {A perceptually tuned subband image coder based on the measure of just-noticeable-distortion profile},
  author  = {Chou, Chun-Hsien and Li, Yun-Chin},
  journal = {IEEE Transactions on Circuits and Systems for Video Technology},
  volume  = {5}, number = {6}, pages = {467--476}, year = {1995}
}
```
