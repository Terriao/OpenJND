# Liu et al. · TV-based decomposition for edge / texture separation

> **Lineage:** Decomposition era
> **Domain:** Pixel
> **Reference:** Liu, A., Lin, W., Paul, M., Deng, C., and Zhang, F., "Just noticeable difference for images with decomposition model for separating edge and textured regions," *IEEE Transactions on Circuits and Systems for Video Technology*, vol. 20, no. 11, pp. 1648–1652, November 2010.

This directory contains the OpenJND implementation of Liu et al.'s pixel-domain JND model, which addresses a long-standing misclassification problem in earlier contrast-masking estimators.

## What the model does

Earlier pixel-domain estimators lump strong gradients into a single "high-frequency" bucket and apply one contrast-masking (CM) gain to both edges and textures. This systematically underestimates the JND budget of texture regions — which the HVS in fact tolerates much more than edges, because textures carry higher **entropy masking**.

Liu et al. fix this by:

1. **Total-variation (TV) decomposition** of the image into a **structural component** `u` (cartoon-like, piecewise smooth with sharp edges) and a **textural component** `v` (fine-scale oscillations). The TV-L¹ formulation is used with a fixed regularisation `λ ≈ 0.8` averaged across natural images.
2. Running a Canny detector on `u` only, so edges are detected on a representation from which textures have already been removed.
3. Computing **edge masking (EM)** on `u` and **texture masking (TM)** on `v` independently:

```
   EM(x,y) = C_s(u; x,y) · β · W_e
   TM(x,y) = C_s(v; x,y) · β · W_t,    W_t > W_e
```

   with `W_t / W_e ≈ 3` reflecting that textures admit roughly three times the unnoticeable distortion of edges at equal spatial contrast.
4. Combining LA and `EM + TM` via Yang et al.'s NAMM with `C_lc = 0.3`.

## Behaviour of the JND map

- Textures recover their rightful, generous JND budget.
- Edges remain protected — the structural component preserves them sharply.
- Reports an average of ≈1.15 dB additional PSNR redundancy over earlier pixel-domain estimators at matched perceived quality.

## Directory layout

```
Liu et al/
├── MATLAB/          # reference implementation (TV-L¹ + Canny + NAMM)
├── Python/          # ported implementation (see note below)
├── C++/             # ported implementation (zip)
└── paper.pdf        # original paper
```

> **Port note.** The Python port substitutes a Gaussian-blur surrogate for the costly TV-L¹ decomposition. This is a deliberate simplification documented in the OpenJND runtime analysis — the resulting JND maps remain qualitatively similar but are much faster to compute.

## Unified calling convention

```
INPUT  : grayscale image  (uint8 / float, H × W)
         optional config struct (lambda_tv, w_e, w_t, beta, canny_threshold)
OUTPUT : JND map of the same H × W shape  (float)
```

## Minimal usage example

**MATLAB**
```matlab
addpath('MATLAB');
img = imread('../test_data/barbara.png');
jnd = liu_jnd(img);
imshow(mat2gray(jnd));
```

**Python**
```bash
cd Python
python main.py
```

**C++**
```bash
cd C++
unzip cpp_source.zip -d build_src
cd build_src && cmake -S . -B build && cmake --build build -j
./build/liu ../test_data/barbara.png
```

## Default parameters

| Parameter | Default | Meaning |
|-----------|---------|---------|
| `lambda_tv` | 0.8 | TV-L¹ regularisation weight |
| `W_e` | 1 | Weight applied to edge masking |
| `W_t` | 3 | Weight applied to texture masking |
| `beta` | 0.117 | Inherited spatial-contrast scale (from Yang et al.) |
| `C_lc` | 0.3 | NAMM gain-reduction factor |

## Citation

```bibtex
@article{liu2010just,
  title   = {Just noticeable difference for images with decomposition model for separating edge and textured regions},
  author  = {Liu, Anmin and Lin, Weisi and Paul, Manoranjan and Deng, Chenwei and Zhang, Fan},
  journal = {IEEE Transactions on Circuits and Systems for Video Technology},
  volume  = {20}, number = {11}, pages = {1648--1652}, year = {2010}
}
```
