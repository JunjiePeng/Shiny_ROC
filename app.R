# app.R
# Elegant ROC + stats + boxplots Shiny app (single-file)

suppressPackageStartupMessages({
  library(shiny)
  library(bslib)
  library(dplyr)
  library(tidyr)
  library(ggplot2)
  library(ggprism)
  library(pROC)
  library(readxl)
  library(readr)
})

# ----------------------------
# Helpers
# ----------------------------

safe_read_data <- function(path, ext, sheet = NULL, delim = "\t") {
  ext <- tolower(ext)
  if (ext %in% c("xlsx", "xls")) {
    if (is.null(sheet) || sheet == "") {
      readxl::read_excel(path)
    } else {
      readxl::read_excel(path, sheet = sheet)
    }
  } else if (ext %in% c("csv")) {
    readr::read_csv(path, show_col_types = FALSE, progress = FALSE)
  } else if (ext %in% c("txt", "tsv")) {
    # treat txt as delimited text; user can choose delimiter
    readr::read_delim(path, delim = delim, show_col_types = FALSE, progress = FALSE)
  } else {
    stop("Unsupported file type: ", ext)
  }
}

coerce_binary_group <- function(x) {
  # Accept factor/character/numeric; enforce 2-level
  if (is.logical(x)) x <- as.integer(x)
  if (is.character(x)) x <- as.factor(x)
  if (is.factor(x)) {
    if (nlevels(x) != 2) stop("Group column must have exactly 2 levels.")
    # Convert to 0/1 using factor order
    return(as.numeric(x) - 1)
  }
  if (is.numeric(x) || is.integer(x)) {
    ux <- sort(unique(x[!is.na(x)]))
    if (length(ux) != 2) stop("Group column must have exactly 2 unique values.")
    # Map smallest -> 0, largest -> 1
    out <- ifelse(x == ux[1], 0L, ifelse(x == ux[2], 1L, NA_integer_))
    return(out)
  }
  stop("Unsupported group column type.")
}

fmt_p <- function(p) {
  if (is.na(p)) return("NA")
  if (p < 1e-4) return("<1e-4")
  formatC(p, format = "f", digits = 4)
}

compute_univariate_tests <- function(df, group_col, vars, test = c("t", "wilcox"), adjust_fdr = TRUE) {
  test <- match.arg(test)

  g <- df[[group_col]]
  stopifnot(all(g %in% c(0, 1, NA)))

  res <- lapply(vars, function(v) {
    x <- df[[v]]
    if (!is.numeric(x)) {
      return(tibble(
        variable = v,
        n0 = sum(!is.na(x) & g == 0),
        n1 = sum(!is.na(x) & g == 1),
        statistic = NA_real_,
        p_value = NA_real_,
        note = "Non-numeric (skipped)"
      ))
    }

    x0 <- x[g == 0]
    x1 <- x[g == 1]

    # require at least 2 non-missing per group
    if (sum(!is.na(x0)) < 2 || sum(!is.na(x1)) < 2) {
      return(tibble(
        variable = v,
        n0 = sum(!is.na(x0)),
        n1 = sum(!is.na(x1)),
        statistic = NA_real_,
        p_value = NA_real_,
        note = "Insufficient data"
      ))
    }

    out <- tryCatch({
      if (test == "t") {
        tt <- t.test(x ~ g)
        tibble(
          variable = v,
          n0 = sum(!is.na(x0)),
          n1 = sum(!is.na(x1)),
          statistic = unname(tt$statistic),
          p_value = unname(tt$p.value),
          note = "t-test"
        )
      } else {
        wt <- wilcox.test(x ~ g, exact = FALSE)
        tibble(
          variable = v,
          n0 = sum(!is.na(x0)),
          n1 = sum(!is.na(x1)),
          statistic = unname(wt$statistic),
          p_value = unname(wt$p.value),
          note = "Mann-Whitney (Wilcoxon rank-sum)"
        )
      }
    }, error = function(e) {
      tibble(
        variable = v,
        n0 = sum(!is.na(x0)),
        n1 = sum(!is.na(x1)),
        statistic = NA_real_,
        p_value = NA_real_,
        note = paste0("Error: ", e$message)
      )
    })
    out
  })

  res <- bind_rows(res)
  if (adjust_fdr) {
    res <- res %>% mutate(p_adj_fdr = p.adjust(p_value, method = "fdr"))
  } else {
    res <- res %>% mutate(p_adj_fdr = NA_real_)
  }
  res
}

compute_roc_table <- function(df, group_col, vars) {
  g <- df[[group_col]]

  roc_rows <- list()

  for (v in vars) {
    x <- df[[v]]
    if (!is.numeric(x)) {
      roc_rows[[v]] <- tibble(
        model = v,
        predictors = v,
        auc = NA_real_,
        auc_ci_low = NA_real_,
        auc_ci_high = NA_real_,
        best_threshold = NA_real_,
        sensitivity = NA_real_,
        specificity = NA_real_,
        n = sum(!is.na(g) & !is.na(x)),
        note = "Non-numeric (skipped)"
      )
      next
    }

    dd <- df %>% select(all_of(group_col), all_of(v)) %>% filter(!is.na(.data[[group_col]]), !is.na(.data[[v]]))
    if (nrow(dd) < 10) {
      roc_rows[[v]] <- tibble(
        model = v,
        predictors = v,
        auc = NA_real_,
        auc_ci_low = NA_real_,
        auc_ci_high = NA_real_,
        best_threshold = NA_real_,
        sensitivity = NA_real_,
        specificity = NA_real_,
        n = nrow(dd),
        note = "Too few complete cases"
      )
      next
    }

    fit <- glm(as.formula(paste0(group_col, " ~ `", v, "`")), data = dd, family = binomial())
    prob <- as.numeric(predict(fit, type = "response"))
    r <- pROC::roc(dd[[group_col]], prob, quiet = TRUE)

    ci <- tryCatch(as.numeric(pROC::ci.auc(r)), error = function(e) c(NA_real_, NA_real_, NA_real_))
    best <- tryCatch(pROC::coords(r, x = "best", best.method = "youden", transpose = FALSE), error = function(e) NULL)

    roc_rows[[v]] <- tibble(
      model = v,
      predictors = v,
      auc = as.numeric(pROC::auc(r)),
      auc_ci_low = ci[1],
      auc_ci_high = ci[3],
      best_threshold = if (is.null(best)) NA_real_ else as.numeric(best["threshold"]),
      sensitivity = if (is.null(best)) NA_real_ else as.numeric(best["sensitivity"]),
      specificity = if (is.null(best)) NA_real_ else as.numeric(best["specificity"]),
      n = nrow(dd),
      note = "Univariate"
    )
  }

  # Combined model if >=2 numeric vars
  numeric_vars <- vars[vapply(df[vars], is.numeric, logical(1))]
  if (length(numeric_vars) >= 2) {
    dd <- df %>%
      select(all_of(group_col), all_of(numeric_vars)) %>%
      filter(if_all(all_of(c(group_col, numeric_vars)), ~ !is.na(.)))

    if (nrow(dd) >= 10) {
      form <- as.formula(paste0(group_col, " ~ ", paste(sprintf("`%s`", numeric_vars), collapse = " + ")))
      fit <- glm(form, data = dd, family = binomial())
      prob <- as.numeric(predict(fit, type = "response"))
      r <- pROC::roc(dd[[group_col]], prob, quiet = TRUE)
      ci <- tryCatch(as.numeric(pROC::ci.auc(r)), error = function(e) c(NA_real_, NA_real_, NA_real_))
      best <- tryCatch(pROC::coords(r, x = "best", best.method = "youden", transpose = FALSE), error = function(e) NULL)

      roc_rows[["Combined"]] <- tibble(
        model = "Combined",
        predictors = paste(numeric_vars, collapse = "+"),
        auc = as.numeric(pROC::auc(r)),
        auc_ci_low = ci[1],
        auc_ci_high = ci[3],
        best_threshold = if (is.null(best)) NA_real_ else as.numeric(best["threshold"]),
        sensitivity = if (is.null(best)) NA_real_ else as.numeric(best["sensitivity"]),
        specificity = if (is.null(best)) NA_real_ else as.numeric(best["specificity"]),
        n = nrow(dd),
        note = "Multivariable"
      )
    }
  }

  bind_rows(roc_rows)
}

make_boxplot_facets <- function(df, group_col, vars, p_tbl, use_adj = TRUE) {
  plot_df <- df %>%
    select(all_of(group_col), all_of(vars)) %>%
    pivot_longer(cols = all_of(vars), names_to = "variable", values_to = "value")

  plot_df <- plot_df %>%
    mutate(group = factor(.data[[group_col]], levels = c(0, 1), labels = c("Group 0", "Group 1")))

  # p labels
  p_tbl2 <- p_tbl %>%
    transmute(
      variable,
      p_label = if (use_adj) paste0("FDR p=", vapply(p_adj_fdr, fmt_p, character(1))) else paste0("p=", vapply(p_value, fmt_p, character(1)))
    )

  # y positions per facet
  y_pos <- plot_df %>%
    group_by(variable) %>%
    summarise(y = max(value, na.rm = TRUE), .groups = "drop") %>%
    mutate(y = ifelse(is.finite(y), y, 1))

  ann <- left_join(p_tbl2, y_pos, by = "variable") %>%
    mutate(y = y + 0.08 * abs(y))

  ggplot(plot_df, aes(x = group, y = value)) +
    geom_boxplot(outlier.shape = NA) +
    geom_jitter(width = 0.15, alpha = 0.7, size = 1.6) +
    facet_wrap(~variable, scales = "free_y") +
    geom_text(data = ann, aes(x = 1.5, y = y, label = p_label), inherit.aes = FALSE, size = 3.5) +
    labs(x = NULL, y = NULL) +
    theme_prism(base_size = 12) +
    theme(
      strip.text = element_text(face = "bold"),
      legend.position = "none"
    )
}

make_roc_plot <- function(df, group_col, vars) {
  # Build ROC curves from logistic predicted probs, like your current app
  curves <- list()

  for (v in vars) {
    if (!is.numeric(df[[v]])) next
    dd <- df %>% select(all_of(group_col), all_of(v)) %>% filter(!is.na(.data[[group_col]]), !is.na(.data[[v]]))
    if (nrow(dd) < 10) next
    fit <- glm(as.formula(paste0(group_col, " ~ `", v, "`")), data = dd, family = binomial())
    prob <- as.numeric(predict(fit, type = "response"))
    r <- pROC::roc(dd[[group_col]], prob, quiet = TRUE)
    curves[[paste0(v, " (AUC ", sprintf("%.2f", as.numeric(pROC::auc(r))), ")")]] <- r
  }

  numeric_vars <- vars[vapply(df[vars], is.numeric, logical(1))]
  if (length(numeric_vars) >= 2) {
    dd <- df %>%
      select(all_of(group_col), all_of(numeric_vars)) %>%
      filter(if_all(all_of(c(group_col, numeric_vars)), ~ !is.na(.)))

    if (nrow(dd) >= 10) {
      form <- as.formula(paste0(group_col, " ~ ", paste(sprintf("`%s`", numeric_vars), collapse = " + ")))
      fit <- glm(form, data = dd, family = binomial())
      prob <- as.numeric(predict(fit, type = "response"))
      r <- pROC::roc(dd[[group_col]], prob, quiet = TRUE)
      curves[[paste0("Combined (AUC ", sprintf("%.2f", as.numeric(pROC::auc(r))), ")")]] <- r
    }
  }

  if (length(curves) == 0) return(NULL)

  pROC::ggroc(curves, legacy.axes = TRUE) +
    geom_abline(linetype = "dotted") +
    coord_fixed() +
    labs(x = "False Positive Rate", y = "True Positive Rate") +
    theme_prism(base_size = 12) +
    theme(
      legend.position = "right",
      legend.title = element_blank()
    )
}

# ----------------------------
# UI
# ----------------------------

ui <- fluidPage(
  theme = bs_theme(version = 5, bootswatch = "flatly"),
  tags$style(HTML(".shiny-notification { position: fixed; top: 60px; right: 20px; }")),

  titlePanel("ROC Curve Plotter"),
  h5("(Version 1.2.0)"),
  h5("by Junjie:P"),
  tags$p("Upload data, select outcome group and variables, run ROC + tests + boxplots, then export results."),

  sidebarLayout(
    sidebarPanel(
      width = 4,
      fileInput(
        "dataFile",
        "Upload data file",
        accept = c(
          ".xlsx", ".xls",
          ".csv",
          ".txt", ".tsv"
        )
      ),
      uiOutput("excelSheetUI"),
      uiOutput("delimUI"),
      hr(),
      uiOutput("groupSelect"),
      uiOutput("varsSelect"),
      helpText("Tip: By default, the first 5 numeric variables are pre-selected. You can add more."),
      hr(),
      radioButtons(
        "testType",
        "Per-variable statistical test",
        choices = c("t-test" = "t", "Mann–Whitney (Wilcoxon)" = "wilcox"),
        selected = "wilcox"
      ),
      checkboxInput("useFDR", "FDR-adjust p-values", value = TRUE),
      actionButton("run", "Run analysis", class = "btn-primary"),
      hr(),
      h5("Downloads"),
      downloadButton("downloadResults", "Download results (ZIP)"),
      downloadButton("downloadROCPlot", "Download ROC plot"),
      downloadButton("downloadBoxPlot", "Download boxplots")
    ),
    mainPanel(
      width = 8,
      tabsetPanel(
        tabPanel("Preview", tableOutput("dataPreview")),
        tabPanel("ROC", plotOutput("rocPlot", height = 520), tableOutput("rocTable")),
        tabPanel("Stats", tableOutput("statsTable")),
        tabPanel("Boxplots", plotOutput("boxPlot", height = 700))
      )
    )
  )
)

# ----------------------------
# Server
# ----------------------------

server <- function(input, output, session) {
  raw_data <- reactive({
    req(input$dataFile)
    ext <- tools::file_ext(input$dataFile$name)

    delim <- input$txtDelim %||% "\t"
    sheet <- input$excelSheet %||% NULL

    tryCatch({
      safe_read_data(input$dataFile$datapath, ext = ext, sheet = sheet, delim = delim)
    }, error = function(e) {
      showNotification(paste0("Error reading file: ", e$message), type = "error")
      NULL
    })
  })

  output$excelSheetUI <- renderUI({
    req(input$dataFile)
    ext <- tolower(tools::file_ext(input$dataFile$name))
    if (!ext %in% c("xlsx", "xls")) return(NULL)

    sheets <- tryCatch(readxl::excel_sheets(input$dataFile$datapath), error = function(e) character(0))
    if (length(sheets) == 0) return(NULL)

    selectInput("excelSheet", "Excel sheet", choices = sheets, selected = sheets[1])
  })

  output$delimUI <- renderUI({
    req(input$dataFile)
    ext <- tolower(tools::file_ext(input$dataFile$name))
    if (!ext %in% c("txt", "tsv")) return(NULL)

    selectInput(
      "txtDelim",
      "Delimiter (for .txt/.tsv)",
      choices = c("Tab" = "\t", "Comma" = ",", "Semicolon" = ";", "Space" = " "),
      selected = "\t"
    )
  })

  # Preview
  output$dataPreview <- renderTable({
    req(raw_data())
    head(raw_data(), 15)
  })

  output$groupSelect <- renderUI({
    req(raw_data())
    selectInput("groupColumn", "Outcome / group column (binary)", choices = names(raw_data()), selected = names(raw_data())[1])
  })

  output$varsSelect <- renderUI({
    req(raw_data(), input$groupColumn)
    cols <- setdiff(names(raw_data()), input$groupColumn)

    # Pre-select first 5 numeric columns if available
    num_cols <- cols[vapply(raw_data()[cols], is.numeric, logical(1))]
    default <- head(num_cols, 5)

    selectizeInput(
      "vars",
      "Predictor variables (select 5 by default; you can add more)",
      choices = cols,
      selected = default,
      multiple = TRUE,
      options = list(plugins = list("remove_button"), placeholder = "Select variables…")
    )
  })

  analysis <- eventReactive(input$run, {
    req(raw_data(), input$groupColumn, input$vars)

    df <- raw_data()

    # Coerce group to 0/1
    df[[input$groupColumn]] <- tryCatch(coerce_binary_group(df[[input$groupColumn]]), error = function(e) {
      showNotification(e$message, type = "error")
      return(NULL)
    })
    req(!is.null(df[[input$groupColumn]]))

    vars <- unique(input$vars)
    if (length(vars) == 0) {
      showNotification("Please select at least one variable.", type = "error")
      return(NULL)
    }

    stats_tbl <- compute_univariate_tests(
      df = df,
      group_col = input$groupColumn,
      vars = vars,
      test = input$testType,
      adjust_fdr = isTRUE(input$useFDR)
    )

    roc_tbl <- compute_roc_table(
      df = df,
      group_col = input$groupColumn,
      vars = vars
    )

    roc_plot <- make_roc_plot(
      df = df,
      group_col = input$groupColumn,
      vars = vars
    )

    box_plot <- make_boxplot_facets(
      df = df,
      group_col = input$groupColumn,
      vars = vars,
      p_tbl = stats_tbl,
      use_adj = isTRUE(input$useFDR)
    )

    list(
      df = df,
      vars = vars,
      stats_tbl = stats_tbl,
      roc_tbl = roc_tbl,
      roc_plot = roc_plot,
      box_plot = box_plot
    )
  })

  output$statsTable <- renderTable({
    req(analysis())
    analysis()$stats_tbl %>%
      mutate(
        p_value = as.numeric(p_value),
        p_adj_fdr = as.numeric(p_adj_fdr)
      )
  }, digits = 4)

  output$rocTable <- renderTable({
    req(analysis())
    analysis()$roc_tbl
  }, digits = 4)

  output$rocPlot <- renderPlot({
    req(analysis())
    validate(need(!is.null(analysis()$roc_plot), "No ROC plot available (check variable types / missingness)."))
    analysis()$roc_plot
  })

  output$boxPlot <- renderPlot({
    req(analysis())
    analysis()$box_plot
  })

  output$downloadResults <- downloadHandler(
    filename = function() paste0("roc_stats_results_", Sys.Date(), ".zip"),
    content = function(file) {
      req(analysis())
      tmpdir <- tempfile("results_")
      dir.create(tmpdir)

      write.csv(analysis()$roc_tbl, file.path(tmpdir, "roc_results.csv"), row.names = FALSE)
      write.csv(analysis()$stats_tbl, file.path(tmpdir, "stat_tests.csv"), row.names = FALSE)

      # Also save plots as PDF
      if (!is.null(analysis()$roc_plot)) {
        ggsave(filename = file.path(tmpdir, "roc_plot.pdf"), plot = analysis()$roc_plot, width = 8, height = 6)
      }
      ggsave(filename = file.path(tmpdir, "boxplots.pdf"), plot = analysis()$box_plot, width = 11, height = 8)

      oldwd <- getwd()
      on.exit(setwd(oldwd), add = TRUE)
      setwd(tmpdir)
      zip::zip(zipfile = file, files = list.files(tmpdir))
    },
    contentType = "application/zip"
  )

  output$downloadROCPlot <- downloadHandler(
    filename = function() paste0("roc_plot_", Sys.Date(), ".pdf"),
    content = function(file) {
      req(analysis())
      validate(need(!is.null(analysis()$roc_plot), "No ROC plot available."))
      ggsave(file, plot = analysis()$roc_plot, width = 8, height = 6)
    },
    contentType = "application/pdf"
  )

  output$downloadBoxPlot <- downloadHandler(
    filename = function() paste0("boxplots_", Sys.Date(), ".pdf"),
    content = function(file) {
      req(analysis())
      ggsave(file, plot = analysis()$box_plot, width = 11, height = 8)
    },
    contentType = "application/pdf"
  )
}

shinyApp(ui, server)
