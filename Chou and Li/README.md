# Chou & Li · Foundational pixel-domain JND model

> **Lineage:** Foundational
> **Domain:** Pixel
> **Reference:** Chou, C.-H. and Li, Y.-C., "A perceptually tuned subband image coder based on the measure of just-noticeable-distortion profile," *IEEE Transactions on Circuits and Systems for Video Technology*, vol. 5, no. 6, pp. 467–476, December 1995.

This directory contains the OpenJND implementation of the foundational pixel-domain JND model proposed by Chou and Li. It is the cornerstone model around which the rest of the OpenJND catalogue is organised.

## What the model does

Chou & Li estimate a per-pixel visibility threshold from two HVS factors:

1. **Background luminance adaptation `f₂`.** The HVS is more tolerant to distortion in very dark and very bright regions and most sensitive around mid-grey (≈127). The luminance term is modelled as a piecewise function — a square-root rise in dark regions and a linear ramp in bright regions:

```
   f₂(bg) = { T₀ · (1 − √(bg/127)) + 3      if bg ≤ 127
            { γ · (bg − 127) + 3              if bg > 127
```

   with `T₀ = 17` and `γ = 3/128` at a viewing distance of approximately six times the image height.

2. **Texture / spatial masking `f₁`.** The maximum weighted average of luminance changes `mg(x,y)` over a 5×5 neighbourhood is computed in four directions using gradient operators G₁–G₄. The masking term scales linearly with `mg` through luminance-dependent slope `α` and intercept `β`:

```
   f₁(bg, mg) = mg · α(bg) + β(bg)
   α(bg) = bg · 0.0001 + 0.115
   β(bg) = λ − bg · 0.01,    λ = 0.5
```

The two factors are combined with a **max-rule** — the JND at each pixel is the larger of the two predictions:

```
JND_fb(x,y) = max{ f₁(bg, mg),  f₂(bg) }
```

The companion paper also introduces **PSPNR** (Peak Signal-to-Perceptible-Noise Ratio), a fidelity metric that counts only the distortion above the JND threshold. An MND profile of "distortion index" `d ∈ [1, 4]` is obtained by `MND_d = JND_fb · d`, useful for graceful quality degradation at tight bit-rate budgets.

## Behaviour of the JND map

- Large budgets on dark and on busy regions.
- Relatively conservative near isolated edges, where the max-rule tends to over-allocate.
- The estimator is image-plane and grayscale by construction — it serves as the spatial baseline reused by Yang et al., Wu et al., and Liu et al.

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
| `T₀` | 17 | Base threshold at zero background luminance (`f₂` at bg = 0) |
| `γ` | 3/128 | Slope of the bright branch of `f₂` |
| `λ` | 0.5 | Sets the average amplitude of `β(bg)` in `f₁` |
| `viewing_distance` | 6 × image height | Distance assumed when fitting `T₀, γ, λ` |

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
