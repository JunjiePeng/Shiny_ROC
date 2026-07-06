# multiROCplot

[![DOI](https://zenodo.org/badge/817356264.svg)](https://doi.org/10.5281/zenodo.21226310)

**An R/Shiny app for plotting and comparing multiple ROC curves, with companion group-comparison statistics and boxplots.**

`multiROCplot` is an interactive tool for exploratory diagnostic-accuracy analysis. You upload a table of predictors and a binary outcome, and the app fits per-variable logistic models, draws overlaid ROC curves with AUCs, computes univariate group-comparison tests, and renders publication-style boxplots — all exportable as figures and CSVs. It is aimed at biostatisticians, bioinformaticians, and clinical/translational researchers who want to screen candidate biomarkers quickly without writing analysis code each time.

- **Version:** 1.2.0
- **Author:** Junjie Peng ([ORCID 0000-0002-3532-8431](https://orcid.org/0000-0002-3532-8431))
- **License:** GPL-3 (see [Licensing](#licensing))

---

## Features

- **Multiple ROC curves on one plot.** Each selected predictor is fitted with a univariate logistic model; predicted probabilities are used to build a ROC curve (via `pROC`) and the curves are overlaid with AUCs shown in the legend.
- **Combined multivariable model.** When two or more numeric predictors are selected, an additional multivariable logistic model is fitted and its ROC curve is added as `Combined`.
- **AUC with confidence intervals** and Youden-optimal thresholds (sensitivity/specificity) reported in a results table.
- **Univariate group comparisons.** Choose a *t*-test or Mann–Whitney (Wilcoxon rank-sum) test per variable, with optional Benjamini–Hochberg (FDR) adjustment.
- **Boxplots** faceted by variable, annotated with (adjusted) p-values.
- **Flexible input.** Reads `.xlsx`/`.xls` (with sheet selection), `.csv`, and `.txt`/`.tsv` (with delimiter selection).
- **Exports.** Download ROC and boxplot figures as PDF, or a ZIP bundle of results tables plus figures.

## Data format

Provide a rectangular table where:

- one column is a **binary outcome / group** (2 levels — factor, character, logical, or numeric are all accepted and coerced to 0/1), and
- one or more columns are **numeric predictors**.

By default the first five numeric columns are pre-selected as predictors; you can add or remove any. Rows with missing values in the relevant columns are dropped per analysis. Predictors need at least 10 complete cases to be modelled.

> **Note:** This repository ships **no example data**. Use your own dataset. Do not commit real patient data to the repository.

## Installation

The app requires R (≥ 4.1 recommended) and the packages below. Install them from CRAN:

```r
install.packages(c(
  "shiny", "bslib", "dplyr", "tidyr", "ggplot2",
  "ggprism", "pROC", "readxl", "readr", "zip"
))
```

## Usage

From the repository root:

```r
shiny::runApp("app.R")
```

or open `app.R` in RStudio and click **Run App**. Then:

1. Upload a data file.
2. Select the binary outcome/group column.
3. Select predictor variables (first five numeric columns are pre-selected).
4. Choose the per-variable test and whether to FDR-adjust.
5. Click **Run analysis**, review the **ROC**, **Stats**, and **Boxplots** tabs, and export as needed.

## Dependencies and licensing rationale

`multiROCplot` depends on the following CRAN packages:

| Package | Role | License |
| --- | --- | --- |
| shiny | Application framework | GPL-3 |
| pROC | ROC curves, AUC, thresholds | GPL (≥ 3) |
| ggprism | Publication-style ggplot theme | GPL (≥ 3) |
| bslib | UI theming | MIT |
| dplyr, tidyr | Data manipulation | MIT |
| ggplot2 | Plotting | MIT |
| readxl, readr | File import | MIT |
| zip | ZIP export | MIT |

Because the app depends on `shiny` (GPL-3) as well as `pROC` and `ggprism` (GPL ≥ 3), the combined distributed work is licensed under **GPL-3**. The permissive (MIT) dependencies are compatible with, and combine into, a GPL-3 work.

## Roadmap

This repository is the archived, citable form of the application. A planned next step is to refactor the ROC-fitting, AUC, and plotting logic out of the Shiny server into a standalone, documented, and tested R package, with the Shiny app becoming a thin UI layer on top of that package API. A first-draft `DESCRIPTION` is included to support that transition.

## Citing this software

If you use `multiROCplot` in your research, please cite it. See [`CITATION.cff`](CITATION.cff), or use the "Cite this repository" button on GitHub. The archived version is available on Zenodo:

> Peng, J. (2026). *multiROCplot: An R/Shiny app for plotting and comparing multiple ROC curves* (Version 1.2.0) [Computer software]. Zenodo. https://doi.org/10.5281/zenodo.21226310

The DOI [10.5281/zenodo.21226310](https://doi.org/10.5281/zenodo.21226310) is the concept DOI and always resolves to the latest version.

## Licensing

Distributed under the **GNU General Public License v3.0**. See [`LICENSE`](LICENSE) for the full text.
