# Zhang et al. · Subband refinement with block-classified contrast masking

> **Lineage:** Subband refinement
> **Domain:** Transform (subband)
> **Reference:** Zhang, X., Lin, W., and Xue, P., "Improved estimation for just-noticeable visual distortion," *Signal Processing*, vol. 85, no. 4, pp. 795–808, April 2005.

This directory contains the OpenJND implementation of Zhang et al.'s subband JND model, which sharpens two long-standing weaknesses of earlier subband estimators.

## What the model does

The model addresses:

1. **An inaccurate luminance-adaptation curve at the dark/bright extremes.** A refined LA formula replaces the simple piecewise approximation, giving a better empirical fit to subjective sensitivity at very low and very high background luminance.
2. **An over-aggressive contrast-masking gain in edge blocks.** Subband coders that lump strong gradients into "high-frequency" lose protection on edges. Zhang et al. introduce an explicit **block classification** step — every block is labelled as **edge**, **texture**, or **smooth** — and the masking gain is scaled differently per category.

The resulting JND profile is markedly more conservative near edges, eliminating a class of visible artefacts that earlier subband coders produced.

## Behaviour of the JND map

- Carries the imprint of the underlying block grid by construction (a feature, not a bug, for block-based codecs).
- Edge blocks receive lower JND budgets than texture blocks of the same energy.
- Suitable for codecs that already operate block-wise (JPEG, HEVC, AVS).

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
         optional config struct (block_size, classification_thresholds)
OUTPUT : JND map of the same H × W shape  (float)
```

Internally the input is partitioned into non-overlapping blocks, classified, transformed, and a per-coefficient threshold is derived. The map is returned in the spatial domain for cross-method comparability.

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
| `block_size` | 8 | Block side length used for classification and DCT |
| `edge_threshold` | per-paper | Energy cutoff above which a block is labelled "edge" |
| `texture_threshold` | per-paper | Energy cutoff for texture vs. smooth |

## Citation

```bibtex
@article{zhang2005improved,
  title   = {Improved estimation for just-noticeable visual distortion},
  author  = {Zhang, Xiaohui and Lin, Weisi and Xue, Ping},
  journal = {Signal Processing},
  volume  = {85}, number = {4}, pages = {795--808}, year = {2005}
}
```
