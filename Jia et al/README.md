# Jia et al. · DCT-domain JND with spatio-temporal CSF and eye-movement compensation

> **Lineage:** DCT formulation
> **Domain:** Transform (DCT) · video-aware
> **Reference:** Jia, Y., Lin, W., and Kassim, A. A., "Estimating just-noticeable distortion for video," *IEEE Transactions on Circuits and Systems for Video Technology*, vol. 16, no. 7, pp. 820–829, July 2006.

This directory contains the OpenJND implementation of Jia et al.'s JND estimator, the first model in the catalogue designed natively in the DCT domain that block-based video codecs operate on.

## What the model does

The model produces a per-coefficient JND threshold by combining:

1. **A spatio-temporal contrast sensitivity function (CSF).** Built on Kelly's stabilised threshold surface and Daly's natural-viewing extension, the CSF expresses sensitivity as a joint function of spatial frequency (cy/deg) and retinal image velocity (deg/s).
2. **Eye-movement compensation.** Smooth-pursuit eye movements partially cancel image-plane motion, so the retinal velocity is computed as `ν_retinal = ν_image − ν_eye`, with the eye velocity capped between a natural drift floor (≈0.15 deg/s) and a saccadic ceiling (≈80 deg/s). This is the key device that lets the model travel from images to video without over-penalising motion.
3. **Luminance adaptation.** A parabolic LA factor centred at mid-grey, with elevated thresholds in dark and bright regions.
4. **Intra- and inter-band contrast masking.** Each 8×8 block is classified into Texture / Edge / Plain, and masking is scaled per class; intra-band masking is excluded in LF and MF subbands of non-textured blocks.

The result is a per-coefficient threshold that can be applied to both still frames (when ν is set to its drift-floor value) and frame pairs with motion.

## Behaviour of the JND map

- When applied to a frame pair with translation, the JND map cleanly reflects both the motion field and the underlying 8×8 block structure — a useful diagnostic property.
- For still images the model reduces to a spatial-CSF JND with LA and CM, in the spirit of DCTune but with sharper LA modelling.

## Directory layout

```
Jia et al/
├── MATLAB/          # reference implementation
├── Python/          # ported implementation
└── paper.pdf        # original paper
```

> The C++ port is currently in progress for this method.

## Unified calling convention

```
INPUT  : grayscale image                          (uint8 / float, H × W)
         optional motion vectors per 8×8 block    (H/8 × W/8 × 2, defaults to zero)
         optional config struct (block_size, c0, c1, viewing_distance, frame_rate)
OUTPUT : JND map of the same H × W shape          (float)
```

When motion vectors are not supplied, the model falls back to still-image mode with `ν_retinal = 0.15 deg/s`.

## Minimal usage example

**MATLAB**
```matlab
addpath('MATLAB');
img = imread('../test_data/lena.png');
jnd = jia_jnd(img);              % still-image mode
imshow(mat2gray(jnd));
```

**Python**
```bash
cd Python
python main.py
```

## Default parameters

| Parameter | Default | Meaning |
|-----------|---------|---------|
| `block_size` | 8 | DCT block side length |
| `c0` | 7.126 | CSF magnitude (fitted by LMS to Ahumada–Peterson thresholds) |
| `c1` | 0.565 | CSF bandwidth |
| `ν_drift` | 0.15 deg/s | Eye-movement floor used in still-image mode |
| `ν_max` | 80 deg/s | Saccadic ceiling |
| `g` | 0.92 | SPEM efficiency |
| `viewing_distance` | as per paper | 17-inch monitor, 50 cm distance |
| `frame_rate` | 30 fps | Used to convert pixel/frame motion to deg/s |

## Citation

```bibtex
@article{jia2006estimating,
  title   = {Estimating just-noticeable distortion for video},
  author  = {Jia, Yuting and Lin, Weisi and Kassim, Ashraf A.},
  journal = {IEEE Transactions on Circuits and Systems for Video Technology},
  volume  = {16}, number = {7}, pages = {820--829}, year = {2006}
}
```
