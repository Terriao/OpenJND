<div align="center">

<img src="openjnd.png" alt="OpenJND" width="620"/>


**A Cross-Language Reference Library for Visual Just-Noticeable-Difference Estimation**

[![License](https://img.shields.io/badge/license-MIT-green.svg)](#license)
[![MATLAB](https://img.shields.io/badge/MATLAB-supported-0076A8?logo=mathworks&logoColor=white)](#)
[![Python](https://img.shields.io/badge/Python-supported-3776AB?logo=python&logoColor=white)](#)
[![C++](https://img.shields.io/badge/C%2B%2B-supported-00599C?logo=cplusplus&logoColor=white)](#)
[![Methods](https://img.shields.io/badge/methods-8-blueviolet)](#method-index)
[![Mirror](https://img.shields.io/badge/mirror-OpenI-success)](https://openi.pcl.ac.cn/OpenDatasets/OpenJND?lang=en-US)
[![Issues](https://img.shields.io/badge/issues-welcome-orange.svg)](https://github.com/Terriao/OpenJND/issues)

**🔗 GitHub:** <https://github.com/Terriao/OpenJND>

**🪞 OpenI Mirror:** <https://openi.pcl.ac.cn/OpenDatasets/OpenJND?lang=en-US>

</div>

---

## What this library is

OpenJND is a **reference implementation collection** of eight representative Just-Noticeable-Difference (JND) models for visual content, made available under a single calling convention in **MATLAB**, **Python**, and **C++**.

The library is built around three observations the field has tolerated for too long:

1. **JND code lives where its author put it.** Reference code typically ships as a single MATLAB folder bundled with the original publication. Re-running it later, or porting it into a Python/C++ pipeline, is each user's private headache.
2. **There is no shared yardstick.** Different works report on different test images at different resolutions, sometimes with bespoke metrics. Reading them in sequence does not give a consistent picture of which method does what.
3. **Method choice is more nuanced than "newest wins".** Pixel-domain and transform-domain models answer different questions, and the right choice depends on the downstream task (codec, watermarking, rendering, IQA). Foundational models are often still the right answer in production pipelines.

OpenJND addresses all three by re-implementing each method against a fixed I/O contract, evaluating the eight models on the same input, and documenting both the *idea* and the *cost* of every model.

> **Open-source dependency note.** Every method in OpenJND has a Python implementation that runs end-to-end on the open-source SciPy / NumPy / OpenCV stack with **no MATLAB required**. The MATLAB and C++ ports are provided alongside as authoritative reference implementations and as building blocks for performance-sensitive integrations.

> The library accompanies the paper *"OpenJND: A Comprehensive Open Source Library for Just Noticeable Difference"* (ACM MM 2026, Open Source Software Track, under review). See [Citation](#citation).

---

## Contents

1. [Concept primer](#concept-primer)
2. [Methodological lineage](#methodological-lineage)
3. [Method index](#method-index)
4. [Unified calling convention](#unified-calling-convention)
5. [Method catalogue](#method-catalogue)
6. [Evaluation protocol](#evaluation-protocol)
7. [Qualitative comparison](#qualitative-comparison)
8. [Runtime analysis](#runtime-analysis)
9. [Choosing a method](#choosing-a-method)
10. [Getting started](#getting-started)
11. [Extending the library](#extending-the-library)
12. [Roadmap](#roadmap)
13. [Frequently asked questions](#frequently-asked-questions)
14. [Citation](#citation)
15. [Community](#community)
16. [License](#license)
17. [Acknowledgements](#acknowledgements)
18. [Contributors and contact](#contributors-and-contact)

---

## Concept primer

A **Just-Noticeable-Difference (JND)** threshold is the minimum signal change that a human observer can reliably detect. In the visual domain, it is determined by the Human Visual System (HVS) reacting to factors such as background luminance, local contrast, edge structure, texture density, pattern regularity, and (for video) motion. Below the threshold, modifications are perceptually invisible; above it, they become noticeable distortions.

Computational JND modelling produces a **JND map** — one threshold per pixel (pixel-domain models) or per transform coefficient (transform-domain models) — that downstream systems can use as a *budget* for invisible modification:

- **Compression** spends bitrate first where the JND budget is smallest.
- **Watermarking** embeds energy just below the JND boundary: invisible, but hard to remove.
- **Quality assessment** weights distortions by their visibility instead of their raw magnitude.
- **Rendering** (VR/AR, HDR) allocates compute where the eye actually looks.

Two methodological families dominate the literature:

| Family | Operating domain | Strengths | Typical limitations |
|--------|------------------|-----------|---------------------|
| Pixel-domain | Original image plane | Intuitive, edge/texture-aware, codec-agnostic | Edges and textures can be conflated; no native frequency story |
| Transform-domain | DCT / DWT / KLT coefficients | Plugs directly into block-based codecs, principled CSF | Block artefacts in the JND map; harder to interpret pixel-wise |

OpenJND covers both — five pixel-domain models and three transform-domain models.

---

## Methodological lineage

JND modelling has matured along a clear intellectual trajectory. Each model in the library answers a question that the previous generation could not — and being part of an established lineage is precisely why these models continue to anchor modern perceptual codecs, watermarking schemes, and IQA systems. The library presents them as a working catalogue rather than a chronology:

```
Foundational           →  Chou & Li
   ├─ Temporal extension  →  Yang et al.
   ├─ Subband refinement  →  Zhang et al.
   └─ DCT formulation     →  Jia et al.

Decomposition era       →  Liu et al.            (separates edge / texture)

Cognitive-inspired      →  Wu et al. (free energy)   (predicts ordered content)

Pattern-aware           →  Wu et al. (pattern complexity)  (orientation diversity)

Top-down learning       →  Jiang et al.          (data-driven CPL boundary)
```

The lineage is **converging, not branching**: later models do not invalidate earlier ones, they sharpen specific aspects. Several state-of-the-art codecs in production today still call into Chou-style or Zhang-style estimators for their simplicity and codec-locality, while research pipelines combine them with the cognitive- and pattern-aware refinements. OpenJND ships all generations so the user can pick the right tool, not the most recent one.

---

## Method index

| # | Method | Lineage | Domain | Distinguishing idea | MATLAB | Python | C++ |
|---|--------|---------|--------|---------------------|:------:|:------:|:---:|
| 5.1 | [Chou & Li](#51-chou--li) · [📂](Chou%20and%20Li) | Foundational | Pixel | Luminance adaptation + texture masking; introduces PSPNR | ● | ◐ | ◐ |
| 5.2 | [Yang et al.](#52-yang-et-al) · [📂](Yang%20et%20al) | Temporal extension · NAMM | Pixel · YCbCr | NAMM combiner with edge/non-edge weighting and temporal pathway | ● | ◐ | ◐ |
| 5.3 | [Zhang et al.](#53-zhang-et-al) · [📂](Zhang%20et%20al) | Subband refinement | Transform (DCT) | Parabolic LA + block-classified CM (PLAIN/EDGE/TEXTURE) | ● | ◐ | ◐ |
| 5.4 | [Jia et al.](#54-jia-et-al) · [📂](Jia%20et%20al) | DCT formulation | Transform (DCT) | Spatio-temporal CSF with eye-movement compensation | ◐ | ◐ | — |
| 5.5 | [Liu et al.](#55-liu-et-al) · [📂](Liu%20et%20al) | Decomposition era | Pixel | TV decomposition separating edge and texture masking | ● | ◐ | ◐ |
| 5.6 | [Wu et al. (free energy)](#56-wu-et-al-free-energy) · [📂](Wu%20et%20al%20%28TMM%29) | Cognitive-inspired | Pixel | AR prediction splits ordered vs. disordered regions | ● | — | — |
| 5.7 | [Wu et al. (pattern complexity)](#57-wu-et-al-pattern-complexity) · [📂](Wu%20et%20al%20%28TIP%29) | Pattern-aware | Pixel | Orientation diversity as masking strength | ● | ◐ | ◐ |
| 5.8 | [Jiang et al.](#58-jiang-et-al) · [📂](Jiang%20et%20al) | Top-down learning | Transform (KLT) | Data-driven CPL prediction | ● | ◐ | ◐ |

Legend — ● upstream open-source reference; ◐ this repository's ported implementation; — not yet implemented.

---

## Unified calling convention

Every method in the library exposes the same minimal interface across all three languages:

```
INPUT  : grayscale image            (uint8 / float, H × W)
         optional config dictionary (struct in MATLAB, dict in Python, std::map in C++)
OUTPUT : JND map of the same H × W shape (float, same range as input)
```

A method-specific config exposes only the parameters that genuinely matter for that method (e.g. `theta` for Chou's masking, `block_size` for DCT-based methods). Default values reproduce the numbers reported in the original publication.

This design lets you swap methods by changing a single function name — invaluable for ablations and downstream-task benchmarking.

---

## Method catalogue

For each method we give the context that motivated it, the modelling step that distinguishes it from its predecessors, and a one-line characterisation of the JND map it produces. Bibliographic details (including publication year) are listed at the end of each entry for citation.

### 5.1 Chou & Li

> **Foundational pixel-domain model** · luminance adaptation + texture masking
> 🔗 Subproject: <https://github.com/Terriao/OpenJND/tree/main/Chou%20and%20Li>

The cornerstone pixel-domain JND model around which the rest of the catalogue is organised. It estimates a per-pixel visibility budget from two HVS factors — how bright the background is (luminance adaptation), and how busy the local neighbourhood is (texture masking) — and uses the maximum of the two as the local JND threshold. The companion paper also introduces **PSPNR**, a fidelity metric that ignores distortion components falling below the threshold.

Behaviour of the resulting map: large budgets on dark and on busy regions; relatively conservative near isolated edges, where the max-rule tends to over-allocate.

```bibtex
@article{chou1995perceptually,
  title   = {A perceptually tuned subband image coder based on the measure of just-noticeable-distortion profile},
  author  = {Chou, Chun-Hsien and Li, Yun-Chin},
  journal = {IEEE Transactions on Circuits and Systems for Video Technology},
  volume  = {5}, number = {6}, pages = {467--476}, year = {1995}
}
```

### 5.2 Yang et al.

> **Nonlinear additive masking (NAMM)** · YCbCr full-colour · video-aware
> 🔗 Subproject: <https://github.com/Terriao/OpenJND/tree/main/Yang%20et%20al>

Replaces the foundational max-rule with a **nonlinear additive masking model (NAMM)**: `JND = LA + TM − C_lt · min(LA, TM)`. `C_lt` recovers the Chou–Li max-rule at `C_lt = 1` and pure addition at `C_lt = 0`; the paper sets it per channel (`C_lt_Y = 0.30`, `C_lt_Cb = 0.25`, `C_lt_Cr = 0.20`), reflecting that the Y luminance and Y texture branches share more information than the chroma branches do. Two further refinements lift the model from grayscale-still-image to colour-video: an **edge-adaptive weight map** (Canny on Y followed by a 7×7 Gaussian, σ = 0.8) suppresses the masking budget along visible edges, and a **temporal-masking** factor `f(ild)` scales the spatial JND by a bowl-shaped function of the inter-frame luminance difference.

Behaviour: smoother handling of edges than the foundational max-rule; recovers chroma-channel JND budget (≈2 dB additional perceptually-lossless PSNR redundancy in the paper's tests); the only model in the catalogue with both native colour and a native temporal pathway.

```bibtex
@article{yang2005just,
  title   = {Just noticeable distortion model and its applications in video coding},
  author  = {Yang, Xiaokang and Lin, Weisi and Lu, Zhongkang and Ong, Ee Ping and Yao, Susu},
  journal = {Signal Processing: Image Communication},
  volume  = {20}, number = {7}, pages = {662--680}, year = {2005}
}
```

### 5.3 Zhang et al.

> **DCT-domain subband refinement** · parabolic luminance adaptation · block-classified contrast masking
> 🔗 Subproject: <https://github.com/Terriao/OpenJND/tree/main/Zhang%20et%20al>

Builds on the Ahumada–Peterson spatial-CSF model and Watson's DCTune, and sharpens two specific weaknesses of those estimators. The luminance-adaptation base threshold is recast as a **parabolic** two-branch function of the block DC coefficient — higher in very dark *and* very bright regions, lowest around mid-grey — which mainly improves accuracy below gray level 128 where DCTune is least faithful. The contrast-masking elevation factor is then conditioned on an explicit **block classification** step (PLAIN / EDGE / TEXTURE) derived from the texture energy of the medium- and high-frequency DCT bands; LF/MF coefficients of EDGE blocks are excluded from intra-band masking, which is precisely what prevents the JND over-estimation that DCTune produces around edges. The same JND profile drives a perceptual distortion metric (subband error normalised by the per-coefficient threshold) and a JPEG-compatible quantizer.

Behaviour: the map carries the imprint of the 8×8 block grid by construction — well-matched to block-based codecs (JPEG, HEVC, AVS), and noticeably better aligned with subjective scores than DCTune in dark regions and around object boundaries.

```bibtex
@article{zhang2005improved,
  title   = {Improved estimation for just-noticeable visual distortion},
  author  = {Zhang, X. H. and Lin, W. S. and Xue, P.},
  journal = {Signal Processing},
  volume  = {85}, number = {4}, pages = {795--808}, year = {2005}
}
```

### 5.4 Jia et al.

> **DCT-domain formulation** · spatio-temporal CSF · eye-movement-aware
> 🔗 Subproject: <https://github.com/Terriao/OpenJND/tree/main/Jia%20et%20al>

The first model in the catalogue designed natively in the DCT domain that the codecs themselves use. Combines **spatial and temporal contrast sensitivity functions** with corrections for the smooth-pursuit eye movements a viewer makes when tracking moving content. The output is a per-coefficient threshold map applicable to both still frames and frame pairs with motion.

Behaviour: when applied to a frame pair with translation, the JND map cleanly reflects both the motion field and the underlying 8×8 block structure — a useful diagnostic property.

```bibtex
@article{jia2006estimating,
  title   = {Estimating just-noticeable distortion for video},
  author  = {Jia, Yuting and Lin, Weisi and Kassim, Ashraf A.},
  journal = {IEEE Transactions on Circuits and Systems for Video Technology},
  volume  = {16}, number = {7}, pages = {820--829}, year = {2006}
}
```

### 5.5 Liu et al.

> **Decomposition era** · TV-based edge/texture separation
> 🔗 Subproject: <https://github.com/Terriao/OpenJND/tree/main/Liu%20et%20al>

Earlier contrast-masking estimators tend to lump strong gradients into a single "high-frequency" bucket, so textured regions are routinely *misclassified as edges* and assigned an artificially low budget. Liu et al. propose a clean fix: split the image into a **structural component** (used for edge masking) and a **textural component** (used for texture masking) via **total-variation decomposition**, then estimate the two masking terms from the two components independently.

Behaviour: textures recover their rightful, generous JND budget; edges remain protected. The cost is a non-trivial decomposition step — see the runtime section for how each language port handles it.

```bibtex
@article{liu2010just,
  title   = {Just noticeable difference for images with decomposition model for separating edge and textured regions},
  author  = {Liu, Anmin and Lin, Weisi and Paul, Manoranjan and Deng, Chenwei and Zhang, Fan},
  journal = {IEEE Transactions on Circuits and Systems for Video Technology},
  volume  = {20}, number = {11}, pages = {1648--1652}, year = {2010}
}
```

### 5.6 Wu et al. (free energy)

> **Cognitive-inspired** · free-energy principle · ordered vs. disordered split
> 🔗 Subproject: <https://github.com/Terriao/OpenJND/tree/main/Wu%20et%20al%20%28TMM%29>

A conceptually distinct entry in the catalogue. Drawing on the free-energy framework from theoretical neuroscience, the HVS is modelled as attempting to *predict* the orderly content of an image; whatever cannot be predicted is **disordered** content that the eye tolerates much more freely. An **autoregressive predictor** over an 11×11 neighbourhood fits the image, the residual is treated as disorder, and JND is computed separately for ordered and disordered components, then combined via NAMM.

Behaviour: substantially elevated JND in disordered regions (foliage, fabric, noise), while ordered regions stay conservative. Currently MATLAB-only in this repository (see directory `Wu et al (TMM)`).

```bibtex
@article{wu2013just,
  title   = {Just noticeable difference estimation for images with free-energy principle},
  author  = {Wu, Jinjian and Shi, Guangming and Lin, Weisi and Liu, Anmin and Qi, Fei},
  journal = {IEEE Transactions on Multimedia},
  volume  = {15}, number = {7}, pages = {1705--1710}, year = {2013}
}
```

### 5.7 Wu et al. (pattern complexity)

> **Pattern-aware** · orientation diversity
> 🔗 Subproject: <https://github.com/Terriao/OpenJND/tree/main/Wu%20et%20al%20%28TIP%29>

Contrast alone is a poor predictor of masking strength: two regions with identical contrast can mask very different amounts of distortion depending on whether their local patterns are *regular* (e.g. a brick wall) or *irregular* (e.g. crumpled fabric). **Pattern complexity** is quantified here as the *number of distinct local orientation bins* (L₀ norm of an orientation histogram, with bin width 12°) and combined with luminance contrast in a new spatial-masking estimator. Code lives in `Wu et al (TIP)`.

Behaviour: irregular-pattern regions receive a higher JND budget than regular-pattern regions of the same contrast. A natural successor to texture-masking models for high-resolution natural imagery.

```bibtex
@article{wu2017enhanced,
  title   = {Enhanced just noticeable difference model for images with pattern complexity},
  author  = {Wu, Jinjian and Li, Leida and Dong, Weisheng and Shi, Guangming and Lin, Weisi and Kuo, C.-C. Jay},
  journal = {IEEE Transactions on Image Processing},
  volume  = {26}, number = {6}, pages = {2682--2693}, year = {2017}
}
```

### 5.8 Jiang et al.

> **Top-down learning** · data-driven CPL prediction · KLT-domain
> 🔗 Subproject: <https://github.com/Terriao/OpenJND/tree/main/Jiang%20et%20al>

The catalogue's only *top-down* model. Instead of summing low-level masking factors, the model asks the more direct question: *at what point does distortion start to be noticed?* Subjective experiments on 500 natural images locate this **critical perceptually-lossless (CPL)** point for each image; the cumulative normalised KLT-coefficient energy at the CPL is well approximated by a Weibull distribution. For a new image, the model predicts its CPL counterpart and reports the difference map as JND.

Behaviour: low budgets near edges (where humans really do notice distortion early) and high budgets in busy textured regions — qualitatively consistent with the bottom-up models, but reached by a completely different route.

```bibtex
@article{jiang2022toward,
  title   = {Toward top-down just noticeable difference estimation of natural images},
  author  = {Jiang, Qiuping and Liu, Zhentao and Wang, Shiqi and Shao, Feng and Lin, Weisi},
  journal = {IEEE Transactions on Image Processing},
  volume  = {31}, pages = {3697--3712}, year = {2022}
}
```

---

## Evaluation protocol

To keep the comparison reproducible:

- **Image pool.** The 24 colour images of the **Kodak** photographic dataset, converted to grayscale, together with three classical grayscale test images (`Lena`, `Actor`, `Lighthouse`). All images are resized to 512 × 512 when their native resolution differs. The bundled `test_data/` directory contains enough imagery to reproduce every figure in this README.
- **Aggregation.** Runtime is reported as the **mean over the full pool**, on a fixed hardware platform.
- **Visualisation.** A single image — grayscale `Actor` (512 × 512) — is shown for every method, side by side, so the reader can compare maps at a glance.
- **Defaults.** Every method is run with the parameter settings reported in its original publication.

We deliberately do *not* report a single "winner" metric: JND maps are intermediate signals, and the right yardstick depends on the downstream application (compression bitrate, watermark robustness, IQA correlation, …).

---

## Qualitative comparison

The figure below tiles the JND maps produced by all eight methods on the same `Actor` input. A few reading notes:

- Bottom-up pixel-domain models tend to agree on the *shape* of the map but disagree on the *amplitude* in edge and texture regions.
- The two transform-domain bottom-up models (Zhang, Jia) carry the imprint of the underlying block grid by construction — a feature, not a bug, when the downstream consumer is a block-based codec.
- Jiang et al.'s top-down map looks qualitatively similar to the bottom-up consensus despite being derived without explicit masking decomposition — evidence that the two philosophies converge on broadly consistent perceptual budgets.

<p align="center"><img src="jnd_visualization.PNG" alt="JND maps comparison" width="800"/></p>

---

## Runtime analysis

Each method is run in MATLAB, Python, and C++ on the same hardware and the same image pool. The figure below shows the average per-image runtime for each (method × language) pair.

<p align="center"><img src="running_time.PNG" alt="Runtime comparison across MATLAB, Python, and C++" width="720"/></p>

The rankings vary across methods, which we attribute to the interaction between each method's dominant operation and the language stack it runs on. Five patterns emerge:

- **Chou and Yang** — `MATLAB ≪ Python ≲ C++`. These methods rely on explicit per-pixel iteration; MATLAB's JIT vectorises them automatically, whereas our ports do not, leaving Python and C++ roughly tied at the bottom.
- **Zhang** — `MATLAB < C++ < Python`. The bottleneck is DCT throughput. MATLAB's BLAS/MKL-backed DCT is markedly faster than SciPy's, and the C++ port sits between them by avoiding the Python interpreter overhead but lacking hand-tuned kernels.
- **Jia** — `MATLAB ≈ Python`. The workload is evenly distributed across linear-algebra primitives that NumPy and MATLAB invoke through similarly tuned backends, so the two stacks finish within margin of each other.
- **Liu and Jiang** — `Python ≪ C++ ≪ MATLAB`. Two different reasons converge on the same ordering. The Liu port replaces the original graph-cut decomposition with a Gaussian-blur surrogate, cutting algorithmic complexity. The Jiang port leans on heavily optimised OpenCV / NumPy primitives for PCA and convolution; the C++ port also uses OpenCV but its PCA and inner loops are not fully tuned.
- **Wu (pattern complexity)** — `Python < MATLAB < C++`. Python wins via vectorised orientation statistics; the C++ port loses ground to OpenMP synchronisation overhead and per-block dynamic allocation.

Two takeaways:

1. **"C++ is always fastest" is folklore.** For numerical-array workloads dominated by BLAS / DCT / image primitives, MATLAB or vectorised Python regularly beats hand-rolled C++.
2. **Port fidelity matters as much as language.** Where we deliberately simplified a costly step (graph-cut in Liu) we say so explicitly; the numbers are honest about the trade.

---

## Choosing a method

A rough decision tree for downstream users:

| If your application is … | Start with … |
|---|---|
| Still-image compression, codec-agnostic | Wu (pattern complexity) or Liu |
| Block-based codec (JPEG, HEVC, AVS) | Zhang or Jia |
| Video coding with motion compensation | Yang or Jia |
| Watermarking with imperceptibility constraint | Wu (free energy) or Wu (pattern complexity) |
| IQA / perceptual quality metric design | Jiang (top-down) for alignment with subjective tests |
| Colour-aware applications | Yang (the only catalogue entry with native YCbCr) |
| Teaching / first reproducible baseline | Chou (the most thoroughly documented foundational model) |

When in doubt, run the methods you are considering on a few of your own images and inspect the maps. Visual inspection at this stage saves a lot of downstream confusion.

---

## Getting started

OpenJND is organised as **one top-level directory per method**:

```
Chou and Li/
Yang et al/
Zhang et al/
Jia et al/
Liu et al/
Wu et al (TIP)/      # pattern complexity
Wu et al (TMM)/      # free-energy
Jiang et al/
```

Each method directory contains the available language ports (MATLAB / Python / C++) and a method-specific entry point.

### Clone

```bash
git clone https://github.com/Terriao/OpenJND.git
cd OpenJND
```

### Python

A typical Python run looks like this — example shown for Wu et al. (pattern complexity):

```bash
cd "Wu et al (TIP)/Python"
pip install numpy scipy opencv-python Pillow matplotlib
python main.py
```

Other Python ports follow the same pattern: open the method directory, install the standard scientific Python stack, run the entry script. Each method directory contains its own README with method-specific parameters.

### MATLAB

Open MATLAB, navigate to a method directory, and call its top-level function. For example:

```matlab
cd 'Chou and Li/MATLAB'
img  = imread('../../test_data/lena.png');
jnd  = chou_li_jnd(img);   % function name follows the method directory
imshow(mat2gray(jnd));
```

The MATLAB ports do not depend on the Python or C++ ports — each is independently runnable.

### C++

C++ ports ship as zipped sources inside each method directory (e.g. `Chou and Li/C++/cpp_source.zip`). Unpack the archive and build with CMake:

```bash
cd "Chou and Li/C++"
unzip cpp_source.zip -d build_src
cd build_src
cmake -S . -B build && cmake --build build -j
./build/openjnd_chou test_data/lena.png
```

Refer to the README inside each unpacked C++ source tree for the exact target name and CLI flags.

---

## Extending the library

The fastest path to a new method is the unified interface: implement a single function (or class) that takes an image plus a config struct and returns a JND map of the same shape. The boilerplate is identical to existing methods, so it can be copied from the closest cousin in the catalogue.

Suggested additions especially welcome:

- Learning-based JND models (deep-network predictors, perceptual GAN-style approaches)
- Colour-aware JND (the current catalogue is grayscale-first, with Yang et al. as the only YCbCr entry)
- 360-degree, light-field, or stereoscopic JND
- Faster GPU-resident reimplementations of the transform-domain methods

For non-trivial contributions please open an Issue first so we can align on the interface and integration. See [CONTRIBUTING.md](CONTRIBUTING.md) for the full workflow.

---

## Roadmap

- **Continually broaden the catalogue** with learning-based JND models (deep predictors, perceptual GAN-style approaches) as the field produces them
- Subjective validation harness (PSPNR; noise injection at the JND boundary; controlled user study scripts)
- Colour JND extensions (CIELAB, opponent-channel masking) beyond the YCbCr branch in Yang et al.
- Bridge to deep-learning IQA codebases (LPIPS, DISTS, PieAPP) for JND-weighted variants
- Mirrored Chinese-language documentation
- Tutorial notebooks walking through each method step by step

---

## Frequently asked questions

**Do the three language implementations produce identical maps?**
Visually equivalent, not bit-identical. Floating-point ordering, BLAS/DCT backends, and (in two cases) deliberate algorithmic simplifications introduce small differences that are documented in each subdirectory.

**Why does the catalogue include foundational models alongside recent ones?**
Because perceptual codecs and watermarking systems in active production still rely on foundational pixel-domain estimators for their simplicity, low latency, and codec-locality. JND is a domain where the newest model is rarely the right answer by default — different applications call for different generations of the lineage.

**Which language should I start with?**
For reproducing the numbers in the original papers, MATLAB. For integration into modern pipelines and for fully open-source dependencies, Python. C++ only when latency is the binding constraint.

**Why grayscale only?**
The classic JND literature is luminance-channel-first; sticking to grayscale keeps the comparison clean. Yang et al. is the catalogue's exception with a native YCbCr formulation; further colour-aware extensions are on the [roadmap](#roadmap).

**What is PSPNR and why is it not just PSNR?**
PSPNR (introduced by Chou & Li) counts only distortion above the per-pixel JND threshold. Two images can have identical PSNR yet very different PSPNR if one hides its distortion in regions of high JND budget.

**Is MATLAB required?**
No. Every method except the MATLAB-only Wu (free energy) also has a Python implementation that runs on the open-source SciPy / NumPy / OpenCV stack.

**Can I cite OpenJND independently of any specific method?**
Yes — see [Citation](#citation). Please *also* cite the original paper for each method you use.

---

## Citation

If OpenJND supports your research, please cite:

```bibtex
@misc{openjnd2026,
  title  = {OpenJND: A Comprehensive Open Source Library for Just Noticeable Difference},
  author = {Gao, Wenxu and Peng, Changhao and Su, Jingxuan and Gao, Wei},
  year   = {2026},
  howpublished = {\url{https://github.com/Terriao/OpenJND}}
}
```

When you use a specific method, please also cite the corresponding original paper, listed in the [Method catalogue](#method-catalogue).

---

## Community

OpenJND is released under the **MIT License** and hosted on [GitHub](https://github.com/Terriao/OpenJND), with a synchronised mirror on the [OpenI](https://openi.pcl.ac.cn/OpenDatasets/OpenJND?lang=en-US) platform maintained by Peng Cheng Laboratory.

The repository follows standard open-source engineering practice:

- **Contributor onboarding.** The repository ships a [CONTRIBUTING.md](CONTRIBUTING.md), structured issue templates (bug report, feature request, new-method proposal), and a pull-request template that prompts for the unified interface, validation against the original paper, and accompanying documentation.
- **Open governance of the catalogue.** New methods are proposed via the *"Propose a new JND method"* issue template and discussed in the open before any code is merged.
- **Documentation by method.** Beyond this top-level README, each method directory carries its own README explaining the implementation, parameters, and a worked example.

Contributions are welcomed on any of the items listed in the [Roadmap](#roadmap), and especially on porting methods to the language slots currently marked `—` in the [Method index](#method-index).

---

## License

Source code is released under the **MIT License**. Individual method subdirectories may carry additional notices inherited from their upstream reference implementations; please consult the respective `LICENSE` files before commercial use.

---

## Acknowledgements

OpenJND would not exist without the authors of the eight methods we re-implement here, who made their reference code available and patiently answered our reproduction questions. We thank the MATLAB, NumPy/SciPy, and OpenCV communities for the numerical primitives this work stands on, and **Peng Cheng Laboratory** together with the **[OpenI](https://openi.pcl.ac.cn/OpenDatasets/OpenJND?lang=en-US)** platform for compute resources and a public mirror of the repository.

We also acknowledge the broader psychophysics and HVS-modelling traditions — going back decades — that made any of this possible.

---

## Contributors and contact

| Role | Name | Affiliation |
|------|------|-------------|
| Coordinator | Asso. Prof. Wei Gao | Peking University & Peng Cheng Laboratory |
| Contributor | Wenxu Gao | Peking University & Peng Cheng Laboratory |
| Contributor | Changhao Peng | Peking University |
| Contributor | Jingxuan Su | Peking University |

For questions, suggestions, and access to push privileges on the OpenI mirror, please contact:

**Asso. Prof. Wei Gao** — `gaowei262@pku.edu.cn`

Bug reports and feature requests are tracked via [GitHub Issues](https://github.com/Terriao/OpenJND/issues).

---

<div align="center">
<sub>OpenJND · A reference library for visual JND, maintained by the Wei Gao group at Peking University and Peng Cheng Laboratory.</sub>
</div>
