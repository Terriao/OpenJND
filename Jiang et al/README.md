# Jiang et al. · Top-down JND from data-driven critical perceptual lossless (CPL) prediction

> **Lineage:** Top-down learning
> **Domain:** Transform (KLT)
> **Reference:** Jiang, Q., Liu, Z., Wang, S., Shao, F., and Lin, W., "Toward top-down just noticeable difference estimation of natural images," *IEEE Transactions on Image Processing*, vol. 31, pp. 3697–3712, 2022.

This directory contains the OpenJND implementation of Jiang et al.'s top-down JND model — the only top-down entry in the catalogue and the only one trained against subjective data.

## What the model does

All seven other methods in OpenJND are **bottom-up**: they list contributing masking factors (LA, CM, edge, texture, pattern, …) and combine them. Jiang et al. instead ask the more direct question: *at what point does distortion start to be noticed?* The model proceeds in three steps:

1. **Block-wise KLT.** The image is partitioned into non-overlapping √K × √K blocks (K = 64 by default). The KLT kernel is derived from the covariance of the vectorised blocks, giving K data-driven spectral components ordered by energy.
2. **Critical perceptually lossless (CPL) point.** Subjective experiments on 500 natural images locate, for each image, the smallest number `L` of leading spectral components that, when used to reconstruct the image via inverse KLT, still looks indistinguishable from the original. The cumulative normalised KLT-coefficient energy `P_L` at the CPL collapses across image content to a tight distribution that is well approximated by a **Weibull distribution** with shape ≈ 894.16 and scale ≈ 0.998.
3. **JND map.** For a new test image, the expected critical point is computed under the fitted Weibull prior, the CPL image is reconstructed from the first `L` components, and

```
   JND(x,y) = |I(x,y) − I_CPL(x,y)|
```

## Behaviour of the JND map

- Low budgets near edges — humans really do notice distortion early there.
- High budgets in busy textured regions, by construction redundant under the KLT prior.
- Qualitatively consistent with the bottom-up consensus despite being derived without any explicit masking decomposition — evidence that the two philosophies converge on broadly consistent perceptual budgets.
- Runs in roughly 0.3 s for a 1200 × 800 image in the reference MATLAB implementation; the Python port is comparable.

## Directory layout

```
Jiang et al/
├── MATLAB/          # reference implementation
├── Python/          # ported implementation
├── C++/             # ported implementation (zip)
└── paper.pdf        # original paper
```

The original authors' reference code is also hosted at <https://github.com/Zhentao-Liu/KLT-JND>.

## Unified calling convention

```
INPUT  : grayscale image  (uint8 / float, H × W)
         optional config struct (block_K, weibull_beta, weibull_gamma)
OUTPUT : JND map of the same H × W shape  (float)
```

## Minimal usage example

**MATLAB**
```matlab
addpath('MATLAB');
img = imread('../test_data/lena.png');
jnd = jiang_jnd(img);
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
./build/jiang ../test_data/lena.png
```

## Default parameters

| Parameter | Default | Meaning |
|-----------|---------|---------|
| `block_K` | 64 | Number of spectral components per block (block side = √K = 8) |
| `weibull_beta` | 894.16 | Shape parameter of the fitted CPL prior |
| `weibull_gamma` | 0.998 | Scale parameter of the fitted CPL prior |

## Citation

```bibtex
@article{jiang2022toward,
  title   = {Toward top-down just noticeable difference estimation of natural images},
  author  = {Jiang, Qiuping and Liu, Zhentao and Wang, Shiqi and Shao, Feng and Lin, Weisi},
  journal = {IEEE Transactions on Image Processing},
  volume  = {31}, pages = {3697--3712}, year = {2022}
}
```
