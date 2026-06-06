# Zhang et al. · DCT-domain JND with parabolic luminance adaptation and block-classified contrast masking

> **Lineage:** Subband refinement
> **Domain:** Transform (DCT)
> **Reference:** Zhang, X. H., Lin, W. S., and Xue, P., "Improved estimation for just-noticeable visual distortion," *Signal Processing*, vol. 85, no. 4, pp. 795–808, 2005.

This directory contains the OpenJND implementation of Zhang et al.'s DCT-domain JND model. Building directly on the Ahumada–Peterson spatial-CSF model and Watson's DCTune, it sharpens two specific weaknesses of those estimators: an inaccurate luminance-adaptation base threshold at dark and bright extremes, and an over-estimated contrast-masking elevation factor around edges.

## What the model does

The JND for each DCT coefficient is expressed, as in DCTune, as the product of a **base threshold** `t_b` and an **elevation factor** `a_e`:

```
t_JND(n1, n2, i, j) = t_b(n1, n2, i, j) · a_e(n1, n2, i, j)
```

where `(n1, n2)` indexes the N×N block (N = 8) and `(i, j)` indexes the DCT subband. The base threshold accounts for the spatial CSF and luminance adaptation; the elevation factor accounts for contrast masking in the block's neighbourhood. The two contributions Zhang et al. add are:

1. **Parabolic luminance adaptation.** Earlier models assumed Weber–Fechner's law (or its power-law form), which over-simplifies real image viewing. The HVS visibility threshold against gray level is in fact approximately parabolic — higher in very dark *and* very bright regions, lowest at mid-grey. Driven by the block DC coefficient `C(n1, n2, 0, 0)`, the luminance-adaptation factor is a two-branch function around the mid-point `GN/2`:

```
   a_lum = k1 · (1 − 2C/GN)^λ1 + 1     if C ≤ GN/2
         = k2 · (2C/GN − 1)^λ2 + 1     otherwise
```

   with `k1 = 2, k2 = 0.8, λ1 = 3, λ2 = 2`. The main difference from DCTune appears below gray level 128 — i.e. the dark-region fix.

2. **Block classification for contrast masking.** Every DCT block is assigned to one of three classes in descending order of HVS sensitivity — **PLAIN**, **EDGE**, **TEXTURE** — using texture energy `TexE = M + H` (sums of absolute DCT coefficients in the medium- and high-frequency groups) and edge indicators `E1 = (L+M)/H` and `E2 = L/M`. Because the HVS is acutely sensitive at luminance edges, EDGE blocks get a lower elevation factor: the LF and MF coefficients of an EDGE block are **excluded from intra-band masking evaluation**, which is exactly what prevents the JND over-estimation that DCTune produces around edges.

The companion sections of the paper show how the resulting JND drives a perceptual distortion metric (subband error normalised by `t_JND`, pooled via Minkowski distance) and a JND-aided JPEG-compatible quantizer.

## Behaviour of the JND map

- The map is per-coefficient in the DCT domain and carries the imprint of the 8×8 block grid by construction — a feature, not a bug, when the downstream consumer is a block-based codec.
- EDGE blocks receive lower budgets than TEXTURE blocks of comparable energy, because their LF/MF bands are kept out of the masking elevation.
- Better matched to subjective scores than DCTune, especially in dark regions and around object boundaries (validated by subjective tests on Actor and Lena, and in JPEG-style compression).

## Directory layout

```
Zhang et al/
├── MATLAB/          # reference implementation
├── Python/          # ported implementation
├── C++/             # ported implementation (zip)
└── paper.pdf        # original paper
```

## Unified calling convention

```
INPUT  : grayscale image  (uint8 / float, H × W)
         optional config struct (block_size, classification_thresholds, viewing_distance)
OUTPUT : JND map  (float)
```

Internally the input is partitioned into non-overlapping 8×8 blocks, each block is DCT-transformed and classified (PLAIN / EDGE / TEXTURE), and a per-coefficient threshold `t_JND(n1, n2, i, j)` is derived from the base threshold and elevation factor.

## Minimal usage example

**MATLAB**
```matlab
addpath('MATLAB');
img = imread('../test_data/lena.png');
jnd = zhang_jnd(img);
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
./build/zhang ../test_data/lena.png
```

## Default parameters

| Parameter | Default | Meaning |
|-----------|---------|---------|
| `N` (block size) | 8 | DCT block side length |
| `k1`, `k2` | 2, 0.8 | Amplitude constants of the dark / bright LA branches |
| `λ1`, `λ2` | 3, 2 | Exponents of the dark / bright LA branches |
| `m1`, `m2`, `m3` | 125, 290, 900 | Texture-energy thresholds for block classification |
| `a1`, `b1` | 7, 5 | Edge-indicator thresholds in classification |
| `k` | 0.1 | Scaling of edge thresholds for high-`TexE` blocks |
| `u` | 16 | `E1` cutoff for the EDGE class |
| `δ1`, `δ2` | 1.25, 1.125 | Inter-band masking factors (TEXTURE / EDGE) |
| `ε` | 0.36 | Intra-band masking exponent |
| `viewing_distance` | 50 cm | Distance used in the spatial-CSF (per the paper's subjective setup) |

All defaults reproduce the numbers reported in the original publication.

## Citation

```bibtex
@article{zhang2005improved,
  title   = {Improved estimation for just-noticeable visual distortion},
  author  = {Zhang, X. H. and Lin, W. S. and Xue, P.},
  journal = {Signal Processing},
  volume  = {85}, number = {4}, pages = {795--808}, year = {2005}
}
```
