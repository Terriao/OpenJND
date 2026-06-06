# Wu et al. (pattern complexity) · Pattern-aware JND with orientation diversity

> **Lineage:** Pattern-aware
> **Domain:** Pixel
> **Reference:** Wu, J., Li, L., Dong, W., Shi, G., Lin, W., and Kuo, C.-C. J., "Enhanced just noticeable difference model for images with pattern complexity," *IEEE Transactions on Image Processing*, vol. 26, no. 6, pp. 2682–2693, June 2017.

This directory contains the OpenJND implementation of Wu et al.'s pattern-complexity JND model — a natural successor to texture-masking models for high-resolution natural imagery.

## What the model does

Contrast alone is a poor predictor of masking strength: two regions with identical contrast can mask very different amounts of distortion depending on whether their local patterns are *regular* (e.g. a brick wall) or *irregular* (e.g. crumpled fabric). The model captures this by:

1. **Orientation per pixel.** A Prewitt operator yields `G_v` and `G_h`; the local orientation is `θ(x) = arctan(G_v / G_h)`. The orientation is then quantised at an interval of **T = 12°** into `N = 15` bins (the 12° width follows the subjective masking experiment of Campbell & Kulikowski, beyond which orientation interactions drop sharply).
2. **Pattern complexity as histogram sparsity.** Over a local receptive field `R` (default **3×3**), the orientation histogram `H_k` is built. The pattern complexity is the L₀ norm of the histogram — i.e. the *number of distinct orientation bins present*:

```
   C_p(x) = Σ_k ‖H_k(x)‖₀
```

   A regular patch (e.g. parallel oblique bars) lights up only one or two bins; a disorderly patch lights up many.
3. **Luminance contrast.** The classical gradient magnitude `C_l(x) = √(G_v² + G_h²)`.
4. **Pattern masking term.** Combines `C_l` and `C_p` as

```
   M_P = log₂(1 + C_l) · f(C_p),     f(C_p) = a1 · C_p^a2 / (C_p² + a3²)
```

   with `a1 = 0.8`, `a2 = 2.7`, `a3 = 0.1`. The logarithmic dependence on `C_l` and the gain-control form on `C_p` are both motivated by Watson & Solomon's contrast-gain-control model.
5. **Classical contrast masking term.** Inherited from Chou & Li and re-fitted by Wu et al.:

```
   M_C = 0.115 · α · C_l^2.4 / (C_l² + β²),   α = 16,  β = 26
```
6. **Spatial masking by dominance.** Whichever term is stronger wins:

```
   M_S = max(M_P, M_C)
```

   In practice `M_C` dominates on regular high-contrast edges, while `M_P` dominates on irregular textured regions.
7. **Luminance adaptation + NAMM combination.** The final JND uses Yang et al.'s nonlinear additivity model for masking:

```
   JND(x) = L_A(x) + M_S(x) − C · min{L_A(x), M_S(x)},     C = 0.3
```

## Behaviour of the JND map

- Irregular-pattern regions receive a higher JND budget than regular-pattern regions of the same contrast.
- Regular high-contrast edges are still protected — the `M_C` branch keeps them conservative even when `M_P` is small.
- One of the best-performing pixel-domain bottom-up models on natural imagery. In the OpenJND runtime analysis its Python port tends to be the fastest of the catalogue thanks to vectorised orientation statistics.

## Directory layout

```
Wu et al (TIP)/
├── MATLAB/          # reference implementation
├── Python/          # ported implementation
├── C++/             # ported implementation (zip)
└── paper.pdf        # original paper
```

## Unified calling convention

```
INPUT  : grayscale image  (uint8 / float, H × W)
         optional config struct (T_deg, R_size)
OUTPUT : JND map of the same H × W shape  (float)
```

## Minimal usage example

**MATLAB**
```matlab
addpath('MATLAB');
img = imread('../test_data/lena.png');
jnd = wu_pc_jnd(img);
imshow(mat2gray(jnd));
```

**Python**
```bash
cd Python
python main.py        # runs func_JND_modeling_pattern_complexity on lena.png
```

The Python entry point returns a tuple; the JND map is the second element. Treat the other elements as diagnostics (the LA term, the pattern-masking term, and the complexity map `C_p`).

**C++**
```bash
cd C++
unzip cpp_source.zip -d build_src
cd build_src && cmake -S . -B build && cmake --build build -j
./build/wu_pc ../test_data/lena.png
```

## Default parameters

| Parameter | Default | Meaning |
|-----------|---------|---------|
| `T_deg` | 12° | Orientation bin width; `N = 15` bins over [0°, 180°] |
| `R_size` | 3×3 | Local receptive field for histogram aggregation |
| `a1` | 0.8 | Magnitude constant of `f(C_p)` |
| `a2` | 2.7 | Exponent shaping the gain-control curve of `f(C_p)` |
| `a3` | 0.1 | Saturation constant of `f(C_p)` |
| `α` | 16 | Numerator constant of the classical `M_C` |
| `β` | 26 | Denominator constant of the classical `M_C` |
| `C` | 0.3 | NAMM gain-reduction factor |

All defaults reproduce the numbers reported in the original publication.

## Citation

```bibtex
@article{wu2017enhanced,
  title   = {Enhanced just noticeable difference model for images with pattern complexity},
  author  = {Wu, Jinjian and Li, Leida and Dong, Weisheng and Shi, Guangming and Lin, Weisi and Kuo, C.-C. Jay},
  journal = {IEEE Transactions on Image Processing},
  volume  = {26}, number = {6}, pages = {2682--2693}, year = {2017}
}
```
