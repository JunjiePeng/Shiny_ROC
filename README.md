# multiROCplot

[![Launch app](https://img.shields.io/badge/Shiny-launch%20app-2c3e50?logo=r)](https://junjiepeng-5h1ny.shinyapps.io/multiROCplot/)
[![DOI](https://zenodo.org/badge/817356264.svg)](https://doi.org/10.5281/zenodo.21226310)

**An R/Shiny app for plotting and comparing multiple ROC curves, with companion group-comparison statistics and boxplots.**

## ▶ Use it online (no installation)

**[Launch multiROCplot →](https://junjiepeng-5h1ny.shinyapps.io/multiROCplot/)**

The easiest way to use multiROCplot is the hosted app — just open the link, upload your data, and go. Nothing to install. Everything below (local install, the function API) is for users who want to run it offline, script it, or build on it.

> **Data privacy:** the hosted app processes uploaded files on shinyapps.io servers. Do not upload identifiable patient data to the public instance. If your data is sensitive, use the local install below, which runs entirely on your machine.

## What it does

`multiROCplot` is an interactive tool for exploratory diagnostic-accuracy analysis. You upload a table of predictors and a binary outcome, and the app fits per-variable logistic models, draws overlaid ROC curves with AUCs, computes univariate group-comparison tests, and renders publication-style boxplots — all exportable as figures and CSVs. It is aimed at biostatisticians, bioinformaticians, and clinical/translational researchers who want to screen candidate biomarkers quickly without writing analysis code each time.

- **Version:** 1.2.0
- **Author:** Junjie Peng ([ORCID 0000-0002-3532-8431](https://orcid.org/0000-0002-3532-8431))
- **License:** GPL-3 (see [Licensing](#licensing))

## Features

- **Multiple ROC curves on one plot.** Each selected predictor is fitted with a univariate logistic model; predicted probabilities are used to build a ROC curve (via `pROC`) and the curves are overlaid with AUCs shown in the legend.
- **Combined multivariable model.** When two or more numeric predictors are selected, an additional multivariable logistic model is fitted and its ROC curve is added as `Combined`.
- **AUC with confidence intervals** and Youden-optimal thresholds (sensitivity/specificity) reported in a results table.
- **Univariate group comparisons.** Choose a *t*-test or Mann-Whitney (Wilcoxon rank-sum) test per variable, with optional Benjamini-Hochberg (FDR) adjustment.
- **Boxplots** faceted by variable, annotated with (adjusted) p-values.
- **Flexible input.** Reads `.xlsx`/`.xls` (with sheet selection), `.csv`, and `.txt`/`.tsv` (with delimiter selection).
- **Exports.** Download ROC and boxplot figures as PDF, or a ZIP bundle of results tables plus figures.

## Data format

Provide a rectangular table where:

- one column is a **binary outcome / group** (2 levels — factor, character, logical, or numeric are all accepted and coerced to 0/1), and
- one or more columns are **numeric predictors**.

By default the first five numeric columns are pre-selected as predictors; you can add or remove any. Rows with missing values in the relevant columns are dropped per analysis. Predictors need at least 10 complete cases to be modelled.

> **Note:** This repository ships **no example data**. Use your own dataset. Do not commit real patient data to the repository.

## Run locally (optional)

If you prefer to run the app offline or on sensitive data that shouldn't leave
your machine, install the package from GitHub (R ≥ 4.1; dependencies install
automatically) and launch it locally:

```r
# install.packages("remotes")
remotes::install_github("JunjiePeng/multiROCplot")

multiROCplot::run_app()
```

The local app is identical to the hosted one. Once it's running:

1. Upload a data file.
2. Select the binary outcome/group column.
3. Select predictor variables (first five numeric columns are pre-selected).
4. Choose the per-variable test and whether to FDR-adjust.
5. Click **Run analysis**, review the **ROC**, **Stats**, and **Boxplots** tabs, and export as needed.

### Programmatic API

The same logic that powers the app is exported, so you can script analyses or
build them into reproducible pipelines:

```r
library(multiROCplot)

df <- read_data("my_data.xlsx", ext = "xlsx")
df$outcome <- coerce_binary_group(df$outcome)

vars <- c("marker1", "marker2", "marker3")

stats_tbl <- compute_univariate_tests(df, "outcome", vars, test = "wilcox")
roc_tbl   <- compute_roc_table(df, "outcome", vars)

roc_plot  <- plot_roc_curves(df, "outcome", vars)
box_plot  <- plot_group_boxplots(df, "outcome", vars, p_tbl = stats_tbl)
```

Exported functions: `read_data()`, `coerce_binary_group()`,
`compute_univariate_tests()`, `compute_roc_table()`, `roc_from_predictor()`,
`roc_combined()`, `plot_roc_curves()`, `plot_group_boxplots()`, `run_app()`.

## Dependencies and licensing rationale

`multiROCplot` depends on the following CRAN packages:

| Package | Role | License |
| --- | --- | --- |
| shiny | Application framework | GPL-3 |
| pROC | ROC curves, AUC, thresholds | GPL (>= 3) |
| ggprism | Publication-style ggplot theme | GPL (>= 3) |
| bslib | UI theming | MIT |
| dplyr, tidyr | Data manipulation | MIT |
| ggplot2 | Plotting | MIT |
| readxl, readr | File import | MIT |
| zip | ZIP export | MIT |

Because the app depends on `shiny` (GPL-3) as well as `pROC` and `ggprism` (GPL >= 3), the combined distributed work is licensed under **GPL-3**. The permissive (MIT) dependencies are compatible with, and combine into, a GPL-3 work.

## Package structure

The ROC/statistics/plotting logic lives in `R/` as documented, tested,
exported functions. The Shiny app (`inst/shiny-app/app.R`) is a thin UI layer
that calls those same functions, so the interactive tool and the programmatic
API share a single implementation.

```
multiROCplot/
├── DESCRIPTION            # package metadata, dependencies, GPL-3
├── NAMESPACE              # exports (regenerate with devtools::document())
├── R/
│   ├── data-io.R          # read_data(), coerce_binary_group()
│   ├── stats.R            # compute_univariate_tests()
│   ├── roc.R              # roc_from_predictor(), roc_combined(), compute_roc_table()
│   ├── plots.R            # plot_roc_curves(), plot_group_boxplots()
│   └── run_app.R          # run_app()
├── man/                   # help pages (?function); regenerated by devtools::document()
├── inst/shiny-app/app.R   # thin Shiny UI over the package API
├── tests/testthat/        # unit tests (synthetic data only)
├── app.R                  # deployment entry point (shinyapps.io); not built into the package
├── CITATION.cff           # citation metadata + Zenodo DOI
└── LICENSE                # GPL-3
```

## Development

The `man/*.Rd` help pages are generated from the roxygen comments in `R/`. After
cloning, regenerate docs and run the checks:

```r
# install.packages("devtools")
devtools::document()   # regenerate NAMESPACE + man/
devtools::test()       # run the testthat suite
devtools::check()      # full R CMD check
```

## Citing this software

If you use `multiROCplot` in your research, please cite it. See [`CITATION.cff`](CITATION.cff), or use the "Cite this repository" button on GitHub. The archived version is available on Zenodo:

> Peng, J. (2026). *multiROCplot: An R/Shiny app for plotting and comparing multiple ROC curves* (Version 1.2.0) [Computer software]. Zenodo. https://doi.org/10.5281/zenodo.21226310

The DOI [10.5281/zenodo.21226310](https://doi.org/10.5281/zenodo.21226310) is the concept DOI and always resolves to the latest version.

## Licensing

Distributed under the **GNU General Public License v3.0**. See [`LICENSE`](LICENSE) for the full text.
