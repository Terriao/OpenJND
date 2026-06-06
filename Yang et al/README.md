# Yang et al. · Nonlinear additive masking (NAMM) for color video

> **Lineage:** Temporal extension of the foundational model · NAMM combiner
> **Domain:** Pixel · YCbCr · video-aware
> **Reference:** Yang, X., Lin, W., Lu, Z., Ong, E. P., and Yao, S., "Just noticeable distortion model and its applications in video coding," *Signal Processing: Image Communication*, vol. 20, no. 7, pp. 662–680, August 2005.

This directory contains the OpenJND implementation of Yang et al.'s JND model, which generalises the foundational Chou–Li max-rule into a **nonlinear additive masking model (NAMM)**, extends estimation to all three colour components, distinguishes edge from non-edge regions, and adds a temporal-masking pathway for video.

## What the model does

The NAMM combines the per-pixel luminance-adaptation threshold `L_a` and the texture-masking threshold `T_θ` not by the max-rule, but by an addition with an overlap correction:

```
JND_S_θ(x,y) = L_a(x,y) + T_θ(x,y) − C_lt_θ · min{ L_a(x,y), T_θ(x,y) }
```

`C_lt_θ` is the **overlap-reduction factor**. `C_lt_θ = 1` recovers the Chou–Li max-rule; `C_lt_θ = 0` recovers pure linear addition. The paper sets:

| Channel | `C_lt_θ` | `β_θ` (texture-masking gain) |
|---------|----------|-------------------------------|
| Y       | 0.30     | 0.117 |
| Cb      | 0.25     | 0.65  |
| Cr      | 0.20     | 0.45  |

The Y channel uses the strongest overlap reduction because the luminance and texture branches share the same Y data; the chroma channels are more independent and use weaker reduction.

**Texture masking.** With four 5×5 directional high-pass kernels `g₁, …, g₄` (Chou's operators):

```
G_θ(x,y) = max_{k=1..4}  | conv(I_θ, g_k) at (x,y) |
T_θ(x,y) = β_θ · G_θ(x,y) · W_θ(x,y)
```

`W_θ` is an **edge-adaptive weight map**. It is computed by running a Canny detector on the Y channel (threshold 0.5), down-weighting edge pixels by a factor of 0.1 (and non-edge pixels by 1), then convolving with a 7×7 Gaussian (σ = 0.8). Distortion on edges is more visible than in textured regions, so `W` suppresses the masking budget along edges.

**Luminance adaptation.** Inherited from Chou & Li:

```
L_a(x,y) = { 17 · (1 − √(B(x,y)/127)) + 3       if B(x,y) ≤ 127
           { (3/128) · (B(x,y) − 127) + 3        if B(x,y) > 127
```

`B(x,y)` is the local mean luminance.

**Temporal masking (video).** For video, the spatial JND is scaled by an empirical function `f` of the average inter-frame luminance difference `ild`:

```
JND_θ(x,y,t) = f( ild_θ(x,y,t) ) · JND_S_θ(x,y)
ild_θ(x,y,t) = 0.5 · ( I_θ(x,y,t) − I_θ(x,y,t−1) + B_θ(x,y,t) − B_θ(x,y,t−1) )
```

`f(ild)` is the bowl-shaped curve from the original paper: it rises to ~3.5–6× on either side as `|ild|` approaches ±255, and equals 1 for `ild = 0`. Larger inter-frame motion means more temporal masking, hence a larger tolerated JND.

## Behaviour of the JND map

- Smoother handling of edges than the Chou–Li max-rule, because the additive-with-overlap combination avoids both double counting and over-suppression.
- The chrominance channels recover their own JND budgets — a source of perceptually-lossless data redundancy of ~2 dB PSNR on average in the original paper's tests, beyond the grayscale-only baseline.
- The **only model** in the OpenJND catalogue with a native temporal pathway and native colour support.

## Directory layout

```
Yang et al/
├── MATLAB/          # reference implementation
├── Python/          # ported implementation
├── C++/             # ported implementation (zip)
└── paper.pdf        # original paper
```

## Unified calling convention

```
INPUT  : grayscale image (or video frame stack)  (uint8 / float, H × W or H × W × T)
         optional config struct (channel, C_lt, beta, canny_threshold)
OUTPUT : JND map of the same shape  (float)
```

For a single grayscale frame the temporal factor `f(ild)` reduces to 1 and the output is the spatial NAMM JND on the Y channel.

## Minimal usage example

**MATLAB**
```matlab
addpath('MATLAB');
img = imread('../test_data/lena.png');
jnd = yang_jnd(img);
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
./build/yang ../test_data/lena.png
```

## Default parameters

| Parameter | Default | Meaning |
|-----------|---------|---------|
| `C_lt_Y` | 0.30 | NAMM overlap-reduction factor on Y |
| `C_lt_Cb` | 0.25 | NAMM overlap-reduction factor on Cb |
| `C_lt_Cr` | 0.20 | NAMM overlap-reduction factor on Cr |
| `β_Y` | 0.117 | Texture-masking gain on Y |
| `β_Cb` | 0.65 | Texture-masking gain on Cb |
| `β_Cr` | 0.45 | Texture-masking gain on Cr |
| Canny threshold | 0.5 | Edge detection on Y |
| Gaussian kernel | 7×7, σ = 0.8 | Smoothing of the edge weight map `W` |

All defaults reproduce the numbers reported in the original publication.

## Citation

```bibtex
@article{yang2005just,
  title   = {Just noticeable distortion model and its applications in video coding},
  author  = {Yang, Xiaokang and Lin, Weisi and Lu, Zhongkang and Ong, Ee Ping and Yao, Susu},
  journal = {Signal Processing: Image Communication},
  volume  = {20}, number = {7}, pages = {662--680}, year = {2005}
}
```
