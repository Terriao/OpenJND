# Wu et al. (free-energy) · Cognitive-inspired JND with ordered / disordered split

> **Lineage:** Cognitive-inspired
> **Domain:** Pixel
> **Reference:** Wu, J., Shi, G., Lin, W., Liu, A., and Qi, F., "Just noticeable difference estimation for images with free-energy principle," *IEEE Transactions on Multimedia*, vol. 15, no. 7, pp. 1705–1710, November 2013.

This directory contains the OpenJND implementation of Wu et al.'s free-energy-based JND model — a conceptually distinct entry in the OpenJND catalogue, derived from Friston's free-energy principle and the Bayesian-brain account of perception.

## What the model does

The HVS is modelled as an **internal generative mechanism (IGM)** that actively predicts the orderly content of an image and *avoids* the residual disorderly content, on the grounds that disorder carries more uncertainty than the brain can usefully process. This concealment of disorder is exactly what existing pixel-domain JND models miss — they only sum luminance adaptation and edge-based spatial masking, both of which are calibrated on orderly stimuli.

The model proceeds in four steps:

1. **Bayesian-brain prediction via an AR model.** Each pixel `x` is predicted from its 11×11 neighbourhood `X = {x_1, …, x_120}` (the central pixel excluded). Starting from `p(x|X) ∝ p(x) · p(X|x) / p(X)` and decomposing the mutual information `I(x; X)`, the autoregressive coefficients are taken as the per-neighbour mutual information, normalised:

```
   F'(x) = Σ_{x_k ∈ X}  C_k · F(x_k) + ε,
   C_k   = I(x; x_k) / Σ_i I(x; x_i)
```

   `F'` is the **orderly component** — the part of the image the IGM can predict.

2. **Disorderly residual.** Whatever the IGM cannot predict is treated as disorder:

```
   D = |F − F'|
```

3. **JND on the orderly component.** Because `F'` is orderly by construction, the classical pixel-domain machinery applies. Using Chou-style luminance adaptation `L_A` and Yang et al.'s spatial masking `S_M`, combined via NAMM:

```
   L_A(x) = { 17·(1 − √(B(x)/127))                    if B(x) ≤ 127
            { (3/128)·(B(x) − 127) + 3                if B(x) > 127
   S_M(x) = [0.01·B(x) + 11.5] · [0.01·G(x) − 1] − 12
   JND_p(x) = L_A(x) + S_M(x) − C^{gr} · min{L_A(x), S_M(x)},   C^{gr} = 0.3
```

   where `B(x)` is the local background luminance and `G(x)` is the maximum weighted gradient in the 5×5 neighbourhood.

4. **JND from the disorderly concealment effect.** Disordered content can absorb more noise than ordered content of the same contrast, so the disorderly JND is taken proportional to the residual:

```
   JND_d(x) = α · D(x),    α = 1.125
```

5. **Overall JND.** NAMM again merges the two branches:

```
   JND(x) = JND_p(x) + JND_d(x) − C^{gr} · min{JND_p(x), JND_d(x)}
```

## Behaviour of the JND map

- Substantially elevated JND on disordered regions — foliage, fabric, water surfaces, noise patches.
- Conservative on ordered regions — smooth gradients, regular textures, sharp edges.
- Captures a masking phenomenon that no purely contrast-based model can reach: the *unpredictability* of local content, not just its energy, sets the budget.
- In Wu et al.'s subjective study a JND-shaped JPEG pre-filter saved roughly 13–16% of bit rate at unchanged perceptual quality.

## Directory layout

```
Wu et al (TMM)/
├── MATLAB/          # reference implementation
└── paper.pdf        # original paper
```

> **Coverage note.** This method is currently MATLAB-only in OpenJND. Python and C++ ports are on the OpenJND roadmap; the AR-coefficient estimation step is the heaviest part of the algorithm and would benefit most from a vectorised port. Contributions are welcome — see the top-level `CONTRIBUTING.md`.

## Unified calling convention (MATLAB)

```
INPUT  : grayscale image  (uint8 / float, H × W)
         optional config struct (alpha_dce, neighbourhood)
OUTPUT : JND map of the same H × W shape  (float)
```

## Minimal usage example

**MATLAB**
```matlab
addpath('MATLAB');
img = imread('../test_data/lena.png');
jnd = wu_freeenergy_jnd(img);
imshow(mat2gray(jnd));
```

## Default parameters

| Parameter | Default | Meaning |
|-----------|---------|---------|
| `neighbourhood` | 11 × 11 | AR prediction window (central pixel excluded → 120 regressors) |
| `α` | 1.125 | Scaling of the disorderly-concealment JND `JND_d = α · D` |
| `C^{gr}` | 0.3 | NAMM gain-reduction factor (used twice: once inside `JND_p`, once when merging `JND_p` and `JND_d`) |

All defaults reproduce the numbers reported in the original publication.

## Citation

```bibtex
@article{wu2013just,
  title   = {Just noticeable difference estimation for images with free-energy principle},
  author  = {Wu, Jinjian and Shi, Guangming and Lin, Weisi and Liu, Anmin and Qi, Fei},
  journal = {IEEE Transactions on Multimedia},
  volume  = {15}, number = {7}, pages = {1705--1710}, year = {2013}
}
```
