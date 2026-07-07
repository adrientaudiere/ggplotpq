# Compact distribution overview of tax_table columns (factor and numeric)

################################################################################
#' Plot a compact distribution overview of `tax_table` columns
#'
#' @description
#' <a href="https://adrientaudiere.github.io/MiscMetabar/articles/Rules.html#lifecycle">
#' <img src="https://img.shields.io/badge/lifecycle-experimental-orange" alt="lifecycle-experimental"></a>
#'
#' Build one compact horizontal row per column of a phyloseq's `tax_table`
#' (via [tidypq::tax_table_to_df()]), stacked into a single tight figure so
#' many columns can be scanned at a glance. Factor/character/logical columns
#' become a single stacked bar spanning the full row: each category is a
#' colored zone sized by its proportion of the total, `NA` is a dark grey
#' zone, and categories that individually represent less than `threshold` of
#' the total are drawn in grey with a stripe motif (via `ggpattern`, when
#' installed) and left unlabeled (only zones at or above `threshold` get a
#' small text label). A column is treated as boolean-like as soon as one of
#' its values reads `"true"` or `"false"` (case-insensitive, so logical
#' columns and mixes like `c(TRUE, FALSE, "uncertain")` both qualify): the
#' color scheme is then fixed across every such column (olive green for
#' true, brick red for false, a blue gradient for any other value), instead
#' of the arbitrary categorical palette used for other factor columns.
#' The last such bar row carries a shared `"Proportion"` x-axis (ticks at
#' 0, 0.25, 0.5, 0.75, 1) for the whole group; other bar rows have theirs
#' hidden to avoid repeating it. Numeric columns become a thin horizontal
#' raincloud (violin + boxplot + jittered points) with the number of
#' non-`NA` values annotated in the top-right corner (and the proportion
#' of `NA` values too, when there is at least one `NA`).
#'
#' @param physeq (required) A [phyloseq::phyloseq-class] or
#'   [phyloseq::taxonomyTable-class] object.
#' @param ranks (character, default `phyloseq::rank_names(physeq)`) Names of
#'   `tax_table` columns to plot.
#' @param na_equivalent (character vector or NULL, default `"-"`) Values
#'   found in character/factor columns that are treated as `NA` before
#'   summarizing (e.g. placeholder codes such as `"-"`). Set to `NULL` to
#'   disable.
#' @param threshold (numeric, default 0.02) For factor/character/logical
#'   columns, categories whose proportion of the total is below `threshold`
#'   are drawn in grey (with a stripe motif) and left unlabeled; `NA` is
#'   exempt (always dark grey, always labeled when non-zero), and so are
#'   `TRUE`/`FALSE` values in boolean-like columns.
#' @param discard_full_NA_column (logical, default TRUE) If TRUE, columns
#'   that are entirely `NA` (after `na_equivalent` conversion) are dropped
#'   with a message. If FALSE, they are kept and drawn as a single dark
#'   grey `"NA"` row (a numeric column that is entirely `NA` is drawn this
#'   way too, since a raincloud needs at least one value).
#' @param combine (logical, default TRUE) If TRUE, stack the per-column rows
#'   into a single [patchwork::patchwork] figure (or several, see
#'   `max_combined_ranks`). If FALSE, return a named list of
#'   [ggplot2::ggplot] objects (one per column).
#' @param max_combined_ranks (integer, default 25) Maximum number of rows
#'   per combined figure. If `combine = TRUE` and more than
#'   `max_combined_ranks` columns are selected, `ranks` is split into
#'   consecutive chunks of at most `max_combined_ranks` columns (with a
#'   message), each combined into its own [patchwork::patchwork] figure, so
#'   a named list of figures is returned instead of a single, too-dense one.
#'
#' @return A [patchwork::patchwork] object when `combine = TRUE` and
#'   `ranks` fits within `max_combined_ranks`; otherwise a named list, of
#'   [ggplot2::ggplot] objects (one per column) when `combine = FALSE`, or
#'   of [patchwork::patchwork] objects (one per chunk of at most
#'   `max_combined_ranks` columns) when `combine = TRUE` with more than
#'   `max_combined_ranks` columns selected.
#' @author Adrien Taudière
#' @export
#'
#' @examples
#' data(data_fungi_mini, package = "MiscMetabar")
#' plot_tax_table_pq(data_fungi_mini)
#'
#' # Restrict to a subset of columns
#' plot_tax_table_pq(data_fungi_mini, ranks = c("Class", "Guild"))
#'
#' data_fungi_mini <- tidypq::mutate_taxa_pq(
#'   data_fungi_mini,
#'   Mol_Abundance = phyloseq::taxa_sums(.)
#' )
#' plot_tax_table_pq(data_fungi_mini, ranks = c("Class", "Mol_Abundance"))
plot_tax_table_pq <- function(
  physeq,
  ranks = phyloseq::rank_names(physeq),
  na_equivalent = c("-", "NA_NA"),
  threshold = 0.02,
  discard_full_NA_column = TRUE,
  combine = TRUE,
  max_combined_ranks = 25
) {
  if (!requireNamespace("tidypq", quietly = TRUE)) {
    cli::cli_abort("Package {.pkg tidypq} is required.")
  }
  if (!requireNamespace("ggfittext", quietly = TRUE)) {
    cli::cli_abort(
      "Package {.pkg ggfittext} is required. Install it with {.code install.packages('ggfittext')}."
    )
  }

  tt_df <- tidypq::tax_table_to_df(physeq, taxa_names_col = NULL)

  if (!is.null(na_equivalent)) {
    tt_df[] <- lapply(tt_df, function(col) {
      if (is.character(col)) {
        col[col %in% na_equivalent] <- NA
      }
      col
    })
  }

  missing_ranks <- setdiff(ranks, names(tt_df))
  if (length(missing_ranks) > 0) {
    cli::cli_abort(
      "Rank{?s} {.val {missing_ranks}} not found in the {.field tax_table}."
    )
  }
  col_names <- ranks

  is_full_na <- vapply(
    col_names,
    function(col) all(is.na(tt_df[[col]])),
    logical(1)
  )

  if (discard_full_NA_column && any(is_full_na)) {
    cli::cli_alert_info(
      "{sum(is_full_na)} column{?s} fully {.val NA} discarded: {.val {col_names[is_full_na]}}."
    )
    col_names <- col_names[!is_full_na]
    is_full_na <- is_full_na[!is_full_na]
  }

  if (length(col_names) == 0) {
    cli::cli_abort(
      "{.arg ranks} must contain at least one column name (after discarding fully-NA columns)."
    )
  }

  is_numeric_col <- stats::setNames(
    vapply(col_names, function(col) is.numeric(tt_df[[col]]), logical(1)) &
      !is_full_na,
    col_names
  )

  plots <- stats::setNames(
    lapply(col_names, function(col) {
      values <- tt_df[[col]]
      if (is.numeric(values) && !all(is.na(values))) {
        plot_tax_table_numeric_row(values, col)
      } else {
        plot_tax_table_factor_row(values, col, threshold = threshold)
      }
    }),
    col_names
  )

  if (!combine) {
    factor_names <- col_names[!is_numeric_col]
    if (length(factor_names) > 0) {
      last_factor <- factor_names[length(factor_names)]
      plots[[last_factor]] <- tax_table_enable_x_axis(plots[[last_factor]])
    }
    return(plots)
  }

  if (length(col_names) > max_combined_ranks) {
    chunks <- split(
      col_names,
      ceiling(seq_along(col_names) / max_combined_ranks)
    )
    cli::cli_inform(c(
      "i" = "{length(col_names)} columns selected (> {max_combined_ranks}); splitting into {length(chunks)} combined figures of at most {max_combined_ranks} rows each.",
      "i" = "Set {.arg combine = FALSE} to get one plot per column instead, or raise {.arg max_combined_ranks}."
    ))
    return(
      stats::setNames(
        lapply(chunks, function(chunk_cols) {
          combine_tax_table_rows(
            plots[chunk_cols],
            is_numeric_col[chunk_cols]
          )
        }),
        vapply(
          chunks,
          function(chunk_cols) {
            sprintf("%s...%s", chunk_cols[1], chunk_cols[length(chunk_cols)])
          },
          character(1)
        )
      )
    )
  }

  combine_tax_table_rows(plots, is_numeric_col)
}

# Stack per-column row plots into a single patchwork figure; the last
# barplot row (if any) gets a shared "Proportion" x-axis for the group
combine_tax_table_rows <- function(plots, is_numeric_col) {
  if (!requireNamespace("patchwork", quietly = TRUE)) {
    cli::cli_abort(
      "Package {.pkg patchwork} is required for {.arg combine = TRUE}. Install it with {.code install.packages('patchwork')}, or set {.arg combine = FALSE}."
    )
  }

  factor_idx <- which(!is_numeric_col)
  if (length(factor_idx) > 0) {
    last_factor <- names(is_numeric_col)[utils::tail(factor_idx, 1)]
    plots[[last_factor]] <- tax_table_enable_x_axis(plots[[last_factor]])
  }

  row_heights <- ifelse(is_numeric_col, 0.6, 1)

  patchwork::wrap_plots(plots, ncol = 1, heights = row_heights) &
    ggplot2::theme(
      plot.margin = ggplot2::margin(1, 4, 1, 4)
    )
}

# Overlay a visible "Proportion" x-axis (breaks at 0/.25/.5/.75/1) on a
# factor-row plot that was built with its x-axis hidden
tax_table_enable_x_axis <- function(p) {
  suppressMessages(
    p +
      ggplot2::scale_x_continuous(
        limits = c(0, 1),
        breaks = c(0, 0.25, 0.5, 0.75, 1),
        expand = c(0, 0)
      ) +
      ggplot2::labs(x = "Proportion") +
      ggplot2::theme(
        axis.text.x = ggplot2::element_text(size = 7),
        axis.title.x = ggplot2::element_text(size = 8),
        axis.ticks.x = ggplot2::element_line()
      )
  )
}

# Pick black or white text for readable contrast against a fill color
tax_table_text_color <- function(fill) {
  rgb_mat <- t(grDevices::col2rgb(fill)) / 255
  lab_mat <- grDevices::convertColor(rgb_mat, from = "sRGB", to = "Lab")
  ifelse(lab_mat[, "L"] > 60, "black", "white")
}

# TRUE if some non-NA value looks like a logical, e.g. c(TRUE, FALSE,
# "uncertain") or c("false", "true", "unknown")
tax_table_is_boolean_like <- function(values_chr) {
  vals <- tolower(values_chr[!is.na(values_chr)])
  any(vals %in% c("true", "false"))
}

# Fill color per category: shared olivedrab/firebrick for true/false so the
# scheme is identical across boolean-like columns, a blue gradient for any
# other value, grey30 for NA, grey70 for below-threshold ("minor") values
tax_table_category_fill <- function(df, boolean_like) {
  fill <- rep("grey70", nrow(df))
  fill[df$is_na] <- "grey30"

  if (boolean_like) {
    value_lower <- tolower(df$value)
    is_true <- !df$is_na & value_lower == "true"
    is_false <- !df$is_na & value_lower == "false"
    fill[is_true] <- "olivedrab"
    fill[is_false] <- "firebrick"
    colorable <- !df$is_na & !is_true & !is_false & !df$below_threshold
    if (any(colorable)) {
      blue_ramp <- grDevices::colorRampPalette(c("#AED6F1", "#1B4F72"))
      fill[colorable] <- blue_ramp(sum(colorable))
    }
  } else {
    colorable <- !df$is_na & !df$below_threshold
    if (any(colorable)) {
      fill[colorable] <- grDevices::hcl.colors(sum(colorable), "Dark 3")
    }
  }

  fill
}

# Rectangle layer for the stacked bar; below-threshold ("minor") zones get a
# stripe motif (via ggpattern) when available, plain grey70 fill otherwise
tax_table_rect_layer <- function(df) {
  base_aes <- ggplot2::aes(
    xmin = .data[["xmin"]],
    xmax = .data[["xmax"]],
    ymin = 0,
    ymax = 1,
    fill = I(.data[["fill"]])
  )

  if (!requireNamespace("ggpattern", quietly = TRUE)) {
    return(
      ggplot2::geom_rect(
        data = df,
        mapping = base_aes,
        color = "white",
        linewidth = 0.3
      )
    )
  }

  df$pattern_type <- ifelse(df$below_threshold, "stripe", "none")

  list(
    ggpattern::geom_rect_pattern(
      data = df,
      mapping = utils::modifyList(
        base_aes,
        ggplot2::aes(pattern = pattern_type)
      ),
      color = "white",
      linewidth = 0.3,
      pattern_fill = "grey40",
      pattern_colour = NA,
      pattern_density = 0.15,
      pattern_spacing = 0.02,
      pattern_alpha = 0.6
    ),
    ggpattern::scale_pattern_manual(
      values = c(none = "none", stripe = "stripe"),
      guide = "none"
    )
  )
}

# Single stacked horizontal bar summarizing a factor/character/logical column
plot_tax_table_factor_row <- function(values, col_name, threshold = 0.02) {
  values_chr <- as.character(values)
  n_total <- length(values_chr)
  is_na <- is.na(values_chr)
  n_na <- sum(is_na)
  boolean_like <- tax_table_is_boolean_like(values_chr)

  tab <- sort(table(values_chr[!is_na]), decreasing = TRUE)
  df <- data.frame(
    value = names(tab),
    n = as.integer(tab),
    is_na = rep(FALSE, length(tab)),
    stringsAsFactors = FALSE
  )
  if (n_na > 0) {
    df <- rbind(
      df,
      data.frame(value = "NA", n = n_na, is_na = TRUE, stringsAsFactors = FALSE)
    )
  }

  df$prop <- df$n / n_total
  df$below_threshold <- df$prop < threshold & !df$is_na
  if (boolean_like) {
    value_lower <- tolower(df$value)
    df$below_threshold[value_lower %in% c("true", "false")] <- FALSE
  }
  df$fill <- tax_table_category_fill(df, boolean_like)

  df <- df[order(df$is_na, -df$n), ]
  df$xmax <- cumsum(df$prop)
  df$xmin <- df$xmax - df$prop
  df$xmid <- (df$xmin + df$xmax) / 2
  df$label <- ifelse(df$is_na | !df$below_threshold, df$value, "")
  df$text_color <- tax_table_text_color(df$fill)

  ggplot2::ggplot(df) +
    tax_table_rect_layer(df) +
    ggfittext::geom_fit_text(
      data = df[df$label != "", ],
      ggplot2::aes(
        xmin = .data[["xmin"]],
        xmax = .data[["xmax"]],
        ymin = 0,
        ymax = 1,
        label = .data[["label"]],
        color = I(.data[["text_color"]])
      ),
      grow = FALSE,
      reflow = FALSE,
      min.size = 0
    ) +
    ggplot2::scale_x_continuous(limits = c(0, 1), expand = c(0, 0)) +
    ggplot2::scale_y_continuous(
      limits = c(0, 1),
      breaks = 0.5,
      labels = col_name,
      expand = c(0, 0)
    ) +
    ggplot2::theme_minimal() +
    ggplot2::theme(
      axis.title = ggplot2::element_blank(),
      axis.text.x = ggplot2::element_blank(),
      axis.text.y = ggplot2::element_text(size = 8, face = "bold"),
      axis.ticks = ggplot2::element_blank(),
      panel.grid = ggplot2::element_blank()
    )
}

# Thin horizontal raincloud (violin + boxplot + jitter) for a numeric column
plot_tax_table_numeric_row <- function(values, col_name) {
  values_num <- as.numeric(values)
  clean <- values_num[!is.na(values_num)]
  na_prop <- sum(is.na(values_num)) / length(values_num)

  df <- data.frame(x = clean, y = rep(0, length(clean)))

  p <- ggplot2::ggplot(df, ggplot2::aes(x = .data[["x"]], y = .data[["y"]])) +
    ggplot2::geom_violin(
      orientation = "y",
      width = 0.8,
      fill = "#4C72B0",
      alpha = 0.4,
      color = NA,
      trim = FALSE,
      na.rm = TRUE
    ) +
    ggplot2::geom_boxplot(
      orientation = "y",
      width = 0.2,
      outlier.shape = NA,
      alpha = 0.7,
      na.rm = TRUE
    ) +
    ggplot2::geom_jitter(
      width = 0,
      height = 0.15,
      alpha = 0.3,
      size = 0.5,
      na.rm = TRUE
    ) +
    ggplot2::scale_y_continuous(
      limits = c(-0.5, 0.5),
      breaks = 0,
      labels = col_name,
      expand = c(0, 0)
    ) +
    ggplot2::theme_minimal() +
    ggplot2::theme(
      axis.title = ggplot2::element_blank(),
      axis.text.y = ggplot2::element_text(size = 8, face = "bold"),
      axis.ticks.y = ggplot2::element_blank(),
      axis.text.x = ggplot2::element_text(size = 7),
      panel.grid.major.y = ggplot2::element_blank(),
      panel.grid.minor.y = ggplot2::element_blank()
    )

  n_label <- if (na_prop > 0) {
    sprintf("n = %d (%.0f%% NA)", length(clean), 100 * na_prop)
  } else {
    sprintf("n = %d", length(clean))
  }

  p <- p +
    ggplot2::annotate(
      "label",
      x = Inf,
      y = 0.35,
      label = n_label,
      hjust = 1,
      vjust = 1,
      size = 3,
      color = "white",
      fill = "grey30",
      border.colour = NA,
      label.padding = ggplot2::unit(0.15, "lines"),
      fontface = "bold"
    ) +
    ggplot2::coord_cartesian(clip = "off")

  p
}
