# Wu et al. (pattern complexity) · Pattern-aware JND with orientation diversity

> **Lineage:** Pattern-aware
> **Domain:** Pixel
> **Reference:** Wu, J., Li, L., Dong, W., Shi, G., Lin, W., and Kuo, C.-C. J., "Enhanced just noticeable difference model for images with pattern complexity," *IEEE Transactions on Image Processing*, vol. 26, no. 6, pp. 2682–2693, June 2017.

This directory contains the OpenJND implementation of Wu et al.'s pattern-complexity JND model — a natural successor to texture-masking models for high-resolution natural imagery. The model captures the observation that two regions with identical contrast can mask very different amounts of distortion depending on whether their local patterns are *regular* (e.g. a brick wall) or *irregular* (e.g. crumpled fabric).

## What the model does

The final JND map combines a **luminance-adaptation** branch with a **visual-masking** branch via the nonlinear additive masking model. The visual-masking branch is itself the dominance of two transducers — a classical luminance-contrast transducer and a new pattern-masking transducer driven by orientation diversity. Edge protection is applied to the pattern-masking branch only.

1. **Luminance adaptation `jnd_LA`.** A 5×5 weighted lowpass on the image gives the local background luminance `bg`; a dark-region adjuster lifts very-low-luminance pixels (`min_lum = 32`) to avoid runaway JND in shadows. The per-pixel threshold is the Chou-style piecewise formula

```
   bg_jnd(L) = { T₀ · (1 − √(L/127)) + 3      if L ≤ 127
               { γ · (L − 127) + 3              if L > 127
```

   with `T₀ = 17` and `γ = 3/128`, then scaled globally by `α = 0.7`:

```
   jnd_LA(x,y) = α · bg_jnd( adjusted_bg(x,y) )
```

2. **Luminance contrast `L_c`.** Computed as the local standard deviation over a 5×5 window (R = 2). It feeds two downstream transducers.

3. **Luminance-contrast transducer `jnd_LC`.** A classical Watson-style gain-control form:

```
   jnd_LC = (a1 · L_c^2.4) / (L_c² + a2²),    a1 = 1.84,  a2 = 26
```

4. **Pattern complexity `P_c`.** This is the model's distinctive contribution. For each pixel, an 8-neighbour ring (radius `r = 1`) plus the centre supplies 9 local gradient orientations. Orientations are computed from a 3×3 box-difference operator and quantised at a half-width of `otr = 6°` (giving 16 bins over `[0°, 180°]` plus one invalid bin for low-gradient pixels). `P_c` is the **number of distinct orientation bins present** in the ring (the L₀ norm of the orientation histogram). A 3×3 Gaussian (σ = 1) then smooths the complexity map.

5. **Pattern-masking transducer.** Combines local contrast with complexity:

```
   C_t    = (a3 · P_c^a4) / (P_c² + a5²),     a3 = 0.3,  a4 = 2.7,  a5 = 1
   jnd_PM = L_c · C_t
```

6. **Edge protection.** A Canny-based mask (adaptive threshold ≤ 0.8, disk-3 dilation, 5×5 Gaussian σ = 0.8) suppresses the pattern-masking budget along edges:

```
   jnd_PM_p = jnd_PM · edge_protect
```

7. **Visual-masking dominance and NAMM combiner.** The visual-masking branch is the stronger of the two transducers; the final JND combines it with luminance adaptation via Yang et al.'s NAMM:

```
   jnd_VM  = max( jnd_LC, jnd_PM_p )
   jnd_map = jnd_LA + jnd_VM − 0.3 · min( jnd_LA, jnd_VM )
```

The demo script also performs a JND-guided noise injection (`adjuster = 0.7`) to produce a contaminated image `img_jnd` for visual evaluation; this is a convenience for the demo, not part of the JND estimator proper.

## Behaviour of the JND map

- Irregular-pattern regions receive a higher JND budget than regular-pattern regions of the same contrast, because `P_c` is higher there and the pattern transducer wins over the plain luminance-contrast transducer.
- Regular high-contrast edges are still protected — both because `jnd_LC` dominates there (the pattern-complexity branch is small near simple edges) and because `edge_protect` actively suppresses the pattern-masking term on detected edges.
- One of the best-performing pixel-domain bottom-up models on natural imagery, and in the OpenJND runtime analysis its Python port tends to be the fastest of the catalogue thanks to vectorised orientation statistics.

## Directory layout

```
Wu et al (TIP)/
├── MATLAB/
│   ├── demo_pattern_complexity_based_JND_modeling.m   # entry-point demo
│   └── func_JND_modeling_pattern_complexity.m         # core algorithm
├── Python/
│   └── main.py
└── paper.pdf
```

## Unified calling convention

```
INPUT  : grayscale image  (uint8 / float, H × W)
OUTPUT : 5-tuple (img_jnd, jnd_map, jnd_LA, jnd_VM, P_c)
         where jnd_map is the JND profile used by the OpenJND benchmarks
         and the other elements are intermediate diagnostics.
```

## Minimal usage example

**MATLAB**
```matlab
addpath('MATLAB');
img = imread('../test_data/lena.png');
if size(img, 3) == 3, img = rgb2gray(img); end
[img_jnd, jnd_map, jnd_LA, jnd_VM, P_c] = func_JND_modeling_pattern_complexity(img);
imshow(mat2gray(jnd_map));
```

**Python**
```bash
cd Python
pip install numpy scipy opencv-python matplotlib
python main.py
```

Programmatic call:
```python
from main import func_JND_modeling_pattern_complexity
import cv2
img = cv2.imread('../test_data/lena.png', cv2.IMREAD_GRAYSCALE)
img_jnd, jnd_map, jnd_LA, jnd_VM, P_c = func_JND_modeling_pattern_complexity(img)
```

## Default parameters

| Parameter | Default | Meaning |
|-----------|---------|---------|
| `T₀, γ` (LA) | 17, 3/128 | Chou-style luminance adaptation curve |
| `min_lum` | 32 | Dark-region adjuster to keep `jnd_LA` finite in shadows |
| `α` (LA scale) | 0.7 | Global scale of `jnd_LA` |
| `R` (variance window) | 2 → 5×5 | Window for the local std-deviation that defines `L_c` |
| `a1, a2` (jnd_LC) | 1.84, 26 | Constants of the luminance-contrast transducer |
| `r` (neighbour ring) | 1 → 8 neighbours | Ring radius for orientation sampling |
| `otr` | 6° | Half-width of an orientation bin (≈12° centre-to-centre, 16 bins + 1 invalid) |
| `a3, a4, a5` (C_t) | 0.3, 2.7, 1 | Constants of the complexity transducer |
| Gaussian on `P_c` | 3×3, σ = 1 | Smoothing of the complexity map |
| Edge-protect Canny | adaptive, ≤ 0.8 | Threshold from `edge_h = 60 / max(edge_height)`, capped at 0.8 |
| Edge-protect kernels | disk(3), 5×5 Gauss σ = 0.8 | Dilation and smoothing of the edge mask |
| `C` (NAMM) | 0.3 | NAMM overlap-reduction factor |
| `adjuster` (noise demo) | 0.7 | Magnitude of the demo's JND-guided noise injection |

All defaults reproduce the configuration used in the reference implementation.

## Citation

```bibtex
@article{wu2017enhanced,
  title   = {Enhanced just noticeable difference model for images with pattern complexity},
  author  = {Wu, Jinjian and Li, Leida and Dong, Weisheng and Shi, Guangming and Lin, Weisi and Kuo, C.-C. Jay},
  journal = {IEEE Transactions on Image Processing},
  volume  = {26}, number = {6}, pages = {2682--2693}, year = {2017}
}
```
