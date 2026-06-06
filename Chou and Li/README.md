# Chou & Li · Foundational pixel-domain JND model

> **Lineage:** Foundational
> **Domain:** Pixel
> **Reference:** Chou, C.-H. and Li, Y.-C., "A perceptually tuned subband image coder based on the measure of just-noticeable-distortion profile," *IEEE Transactions on Circuits and Systems for Video Technology*, vol. 5, no. 6, pp. 467–476, December 1995.

This directory contains the OpenJND implementation of the foundational pixel-domain JND model proposed by Chou and Li. It is the cornerstone model around which the rest of the OpenJND catalogue is organised.

## What the model does

Chou & Li estimate a per-pixel visibility threshold from two Human Visual System (HVS) factors:

1. **Background luminance adaptation.** The HVS is more tolerant to distortion in very dark and very bright regions and most sensitive around mid-grey (≈127). The luminance term is modelled as a piecewise function — a square-root rise in dark regions and a linear ramp in bright regions, both anchored at a base threshold T₀ = 17 with a viewing distance of approximately six times the image height.
2. **Texture masking.** The maximum weighted average of luminance changes over a 5×5 neighbourhood is computed in four directions using gradient operators G₁–G₄. The resulting `mg(x,y)` modulates the visibility threshold linearly, with slope and intercept that depend on the local background luminance.

The two factors are combined with a **max-rule** — the JND threshold at each pixel is the larger of the two predictions:

```
JND_fb(x,y) = max{ f₁(bg, mg), f₂(bg) }
```

The companion paper also introduces **PSPNR** (Peak Signal-to-Perceptible-Noise Ratio), a fidelity metric that counts only the distortion above the JND threshold.

## Behaviour of the JND map

- Large budgets on dark and on busy regions.
- Relatively conservative near isolated edges, where the max-rule tends to over-allocate.
- An MND profile of arbitrary "distortion index" `d ∈ [1, 4]` can be obtained by multiplying every JND value by `d`, useful for graceful quality degradation at tight bit-rate budgets.

## Directory layout

```
Chou and Li/
├── MATLAB/          # reference implementation
├── Python/          # ported implementation
├── C++/             # ported implementation (zip)
└── paper.pdf        # original paper
```

## Unified calling convention

```
INPUT  : grayscale image       (uint8 / float, H × W)
         optional config struct (T0, gamma, lambda, viewing_distance)
OUTPUT : JND map of the same H × W shape (float)
```

## Minimal usage example

**MATLAB**
```matlab
addpath('MATLAB');
img = imread('../test_data/lena.png');
jnd = chou_li_jnd(img);
imshow(mat2gray(jnd));
```

**Python**
```bash
cd Python
python main.py        # default input: ../test_data/lena.png
```

**C++**
```bash
cd C++
unzip cpp_source.zip -d build_src
cd build_src && cmake -S . -B build && cmake --build build -j
./build/chou_li ../test_data/lena.png
```

## Default parameters

| Parameter | Default | Meaning |
|-----------|---------|---------|
| `T0` | 17 | Base threshold at zero background luminance |
| `gamma` | 3/128 | Slope of the luminance term for bright regions |
| `lambda` | 0.5 | Average amplitude factor for the texture term |
| `viewing_distance` | 6 × image height | Distance assumed when computing thresholds |

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
