# Contributing to OpenJND

Thank you for considering a contribution to OpenJND. This document explains how to propose changes, add new methods, and what we expect from a pull request. 

## Table of contents

1. [Code of conduct](#code-of-conduct)
2. [Ways to contribute](#ways-to-contribute)
3. [Repository layout](#repository-layout)
4. [Adding a new JND method](#adding-a-new-jnd-method)
5. [Coding conventions](#coding-conventions)
6. [Validating your contribution](#validating-your-contribution)
7. [Submitting a pull request](#submitting-a-pull-request)
8. [Reporting bugs](#reporting-bugs)
9. [Maintainers and contact](#maintainers-and-contact)

---

## Code of conduct

We expect contributors to behave professionally, respectfully, and inclusively in all project spaces (issues, pull requests, code review, email). Personal attacks, harassment, and discriminatory language are not tolerated. Concerns may be reported privately to the maintainer listed at the bottom of this file.

---

## Ways to contribute

Contributions of any size are welcome:

- **New methods.** Add a JND model that is not yet in the catalogue.
- **New language ports.** Port an existing method into MATLAB, Python, or C++ where the table in the [README](README.md#method-index) marks the slot as `—` (not yet implemented).
- **Performance improvements.** Vectorise a loop, switch to a faster backend, reduce memory footprint.
- **Bug fixes.** Numerical mismatches, edge-case crashes, regressions against the reference paper.
- **Documentation.** Better explanations, more examples, translations, fixed typos.
- **Tooling.** Packaging, benchmarking scripts, tutorial notebooks.

If you are unsure where to start, look at the [Roadmap](README.md#roadmap) section of the README, or open an issue describing what you would like to do.

---

## Repository layout

Every method ships in its own top-level directory. The current set is:

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

Inside each method directory you will find sub-folders for the three language ports (MATLAB / Python / C++) and a method-specific README. Test images live in `test_data/`.

---

## Adding a new JND method

The fastest path to a new method is to copy the closest cousin in the catalogue and modify it. Concretely:

1. **Create the directory.** Use the convention `<First-Author> et al/`, or `<First-Author> and <Second-Author>/` for two-author papers.
2. **Implement the unified interface in at least one language.** The interface is described in the [README](README.md#unified-calling-convention):

```
   INPUT  : grayscale image (uint8 / float, H × W)
            optional config dictionary
   OUTPUT : JND map of the same H × W shape (float)
```
3. **Match the original paper's reported numbers** on a public test image (Actor, Lena, Kodak, or one of the images shipped in `test_data/`). Document the deviation if any.
4. **Add a method-specific README** in the new directory containing:
   - One-paragraph background and motivation
   - The unified interface signature in your language
   - A minimal worked example (5–10 lines)
   - The BibTeX of the original paper
5. **Update the top-level README** — add a row to the [Method index](README.md#method-index) table and a method card to the [Method catalogue](README.md#method-catalogue).

If your method introduces a new methodological lineage (e.g. deep-learning-based JND), please open an Issue *before* opening a PR so we can discuss whether to extend the [Methodological lineage](README.md#methodological-lineage) diagram.

---

## Coding conventions

We do not enforce strict style across all three languages, but consistency within a method directory matters.

### Python
- Target Python 3.8 or above.
- Stick to the standard scientific stack: `numpy`, `scipy`, `opencv-python`, `Pillow`. Avoid uncommon or commercial dependencies.
- Document parameters and return shapes in the docstring.

### MATLAB
- Function name = file name. Use lower_snake_case for files.
- Top-of-file comment block: one-line summary, then a *Usage* block, then the BibTeX of the reference paper.
- Prefer vectorised code over explicit `for` loops where readability is not hurt.

### C++
- Target C++17. Build with CMake.
- Header + implementation split. Public API in `include/`, internals in `src/`.
- Depend only on OpenCV and the C++ standard library, unless you have a strong reason otherwise.

---

## Validating your contribution

A pull request that adds or modifies a method should be accompanied by some form of validation. Acceptable forms include:

- **Visual.** A side-by-side figure showing the new method's JND map next to the closest existing baseline on a shared test image (`test_data/`).
- **Numerical.** A short table comparing the new method's output against the original paper's reported numbers on one common test image, with the deviation explained.
- **Sanity checks.** For new language ports, a small script that confirms the port and the MATLAB reference agree to within a stated tolerance on a chosen image.

Attach the validation figure or table to the pull request description.

---

## Submitting a pull request

1. **Fork** the repository on GitHub and create a feature branch:
```bash
   git checkout -b feat/<short-description>
```
2. **Make focused commits.** One concern per commit; clear commit messages (imperative mood: *"Add Yang pattern-complexity Python port"*).
3. **Update documentation** — README rows, method-specific README, this file if you introduced new conventions.
4. **Open the PR** using the [pull request template](.github/PULL_REQUEST_TEMPLATE.md). Link to any related issues and attach validation outputs where helpful.
5. **Respond to review comments** as soon as you reasonably can. We aim to give a first response within one week.

We squash-merge to keep the history readable.

---

## Reporting bugs

Please open a [GitHub Issue](https://github.com/Terriao/OpenJND/issues/new/choose) using the **Bug report** template. A good bug report contains:

- Method and language (e.g. *"Liu et al — Python"*)
- OS and version, Python / MATLAB / compiler version
- A minimal reproduction (input image dimensions, parameters, observed output)
- Expected behaviour and how it differs from the original paper if relevant

Security-sensitive issues should be reported privately to the maintainer instead of via a public issue.

---

## Maintainers and contact

**Coordinator:** Asso. Prof. Wei Gao — `gaowei262@pku.edu.cn`
*Peking University & Peng Cheng Laboratory*

Active contributors are listed in the [Contributors](README.md#contributors-and-contact) section of the README. Joining the list is automatic on your first merged PR — no separate action required.

Thank you again for helping make OpenJND more useful to the community.
