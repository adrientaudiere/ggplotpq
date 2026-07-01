#' Plot per-sample read depth (number of sequences)
#'
#' @description
#'
#' <a href="https://adrientaudiere.github.io/MiscMetabar/articles/Rules.html#lifecycle">
#' <img src="https://img.shields.io/badge/lifecycle-experimental-orange" alt="lifecycle-experimental"></a>
#'
#' Draw a bar or density plot of per-sample sequencing depth
#' ([phyloseq::sample_sums()]) for a phyloseq object. Useful as a quick
#' QA plot to identify low-depth samples before downstream analyses.
#' A reference line at `threshold` (when supplied) is drawn to make the
#' cutoff visible.
#'
#' When `add_violin = TRUE` and `color_fac` is supplied, a marginal
#' violin plot is placed to the right of the bar plot. Both panels share
#' the y-axis (sequencing depth): panel A shows the vertical per-sample
#' bars, panel B shows a vertical violin of depth by `color_fac` with
#' jittered points (`alpha = 0.5`) for individual samples. This makes it
#' easy to judge, at a glance, whether sequencing depth differs between
#' groups of samples.
#'
#' @param physeq (required) A [phyloseq::phyloseq-class] object.
#' @param geom (character, default "bar") One of `"bar"` (a single
#'   bar per sample) or `"density"` (a smoothed density estimate).
#' @param color_fac (character, default NULL) Optional name of a column
#'   in [phyloseq::sample_data()] to fill the bars/violin/density by.
#'   Non-categorical columns are coerced to factor. When `geom = "density"`,
#'   one overlapping density curve is drawn per level of `color_fac`.
#' @param threshold (numeric, default NULL) Optional horizontal
#'   reference line drawn at this depth value. Common use: the
#'   rarefaction cutoff.
#' @param log10 (logical, default FALSE) If TRUE, the y-axis (or the
#'   density's x-axis) is log10-transformed.
#' @param sort (logical, default FALSE) If TRUE, samples are sorted
#'   from highest to lowest depth. Useful for bar plots to spot
#'   outliers at a glance.
#' @param add_violin (logical, default FALSE) If TRUE, a marginal violin
#'   plot of depth by `color_fac` (with jittered points, `alpha = 0.5`)
#'   is placed to the right of the bar plot. Both panels share the
#'   y-axis (depth). Requires `color_fac` to be non-NULL and
#'   `geom = "bar"`; otherwise a warning is issued and the parameter is
#'   ignored.
#'
#' @return A [ggplot2::ggplot] object, or a [patchwork::patchwork]
#'   object when `add_violin = TRUE`.
#' @author Adrien Taudière
#' @export
#'
#' @examples
#' \donttest{
#' data(data_fungi_mini, package = "MiscMetabar")
#' plot_sample_depth_pq(data_fungi_mini)
#' plot_sample_depth_pq(data_fungi_mini, geom = "density", log10 = TRUE)
#' plot_sample_depth_pq(data_fungi_mini, color_fac = "Height", sort = TRUE)
#' plot_sample_depth_pq(data_fungi_mini, color_fac = "Height",
#'   add_violin = TRUE, log10 = TRUE, threshold = 8000)
#' plot_sample_depth_pq(data_fungi_mini, color_fac = "Time",
#'   geom = "density", log10 = TRUE)
#' }
plot_sample_depth_pq <- function(
  physeq,
  geom = c("bar", "density"),
  color_fac = NULL,
  threshold = NULL,
  log10 = FALSE,
  sort = FALSE,
  add_violin = FALSE
) {
  if (!requireNamespace("phyloseq", quietly = TRUE)) {
    cli::cli_abort("Package {.pkg phyloseq} is required.")
  }

  geom <- match.arg(geom)

  if (add_violin && is.null(color_fac)) {
    cli::cli_warn(
      "{.arg add_violin} is ignored when {.arg color_fac} is NULL \
      (no grouping factor for the violin)."
    )
    add_violin <- FALSE
  }
  if (add_violin && identical(geom, "density")) {
    cli::cli_warn(
      "{.arg add_violin} is ignored when {.code geom = \"density\"} \
      (the violin is redundant with the density)."
    )
    add_violin <- FALSE
  }

  sums <- phyloseq::sample_sums(physeq)
  if (any(is.na(sums))) {
    cli::cli_warn(
      "{sum(is.na(sums))} sample{?s} returned NA for sample_sums(); dropping them."
    )
    sums <- sums[!is.na(sums)]
  }

  df <- data.frame(
    Sample = names(sums),
    Depth = as.numeric(sums),
    stringsAsFactors = FALSE
  )

  if (!is.null(color_fac)) {
    if (!color_fac %in% colnames(phyloseq::sample_data(physeq))) {
      cli::cli_abort(
        "{.arg color_fac} = {.val {color_fac}} not found in sample_data."
      )
    }
    color_vec <- phyloseq::sample_data(physeq)[[color_fac]]
    color_vec <- color_vec[match(
      df$Sample,
      rownames(phyloseq::sample_data(physeq))
    )]
    if (!is.factor(color_vec) && !is.character(color_vec)) {
      cli::cli_inform(
        "{.val {color_fac}} is not categorical \
        (class {paste(class(color_vec), collapse = '/')}); coercing to factor."
      )
    }
    df[[color_fac]] <- as.factor(color_vec)
  }

  if (sort) {
    df$Sample <- factor(df$Sample, levels = df$Sample[order(-df$Depth)])
  } else {
    df$Sample <- factor(df$Sample, levels = df$Sample)
  }

  y_lab <- "Sequencing depth (number of sequences)"

  if (identical(geom, "density")) {
    if (!is.null(color_fac)) {
      p <- ggplot(
        df,
        aes(
          x = .data[["Depth"]],
          fill = .data[[color_fac]]
        )
      ) +
        geom_density(alpha = 0.5) +
        labs(
          x = "Sequencing depth",
          y = "Density",
          fill = color_fac,
          title = "Distribution of per-sample sequencing depth"
        ) +
        theme_minimal()
    } else {
      p <- ggplot(df, aes(x = .data[["Depth"]])) +
        geom_density(fill = "steelblue", alpha = 0.6) +
        labs(
          x = "Sequencing depth",
          y = "Density",
          title = "Distribution of per-sample sequencing depth"
        ) +
        theme_minimal()
    }
    if (log10) {
      p <- p + ggplot2::scale_x_log10()
    }
    if (!is.null(threshold)) {
      p <- p +
        ggplot2::geom_vline(
          xintercept = threshold,
          color = "red",
          linetype = "dashed"
        )
    }
    return(p)
  }

  # bar
  if (is.null(color_fac)) {
    p_bar <- ggplot(
      df,
      aes(
        x = .data[["Sample"]],
        y = .data[["Depth"]]
      )
    ) +
      geom_col(fill = "steelblue") +
      labs(
        x = NULL,
        y = y_lab,
        title = "Per-sample sequencing depth"
      ) +
      theme_minimal() +
      theme(axis.text.x = element_text(angle = 45, hjust = 1))
  } else {
    p_bar <- ggplot(
      df,
      aes(
        x = .data[["Sample"]],
        y = .data[["Depth"]],
        fill = .data[[color_fac]]
      )
    ) +
      geom_col() +
      labs(
        x = NULL,
        y = y_lab,
        fill = color_fac,
        title = "Per-sample sequencing depth"
      ) +
      theme_minimal() +
      theme(axis.text.x = element_text(angle = 45, hjust = 1))
  }

  # --- standalone bar plot (no violin) ---
  if (!add_violin) {
    if (log10) {
      p_bar <- p_bar + ggplot2::scale_y_log10()
    }
    if (!is.null(threshold)) {
      p_bar <- p_bar +
        ggplot2::geom_hline(
          yintercept = threshold,
          color = "red",
          linetype = "dashed"
        )
    }
    return(p_bar)
  }

  # --- bar plot (A) + marginal violin (B), side by side (patchwork) ---
  # Panel A is the vertical bar plot (x = Sample, y = Depth, fill =
  # color_fac) built above. Panel B is a vertical violin (x = color_fac,
  # y = Depth) showing the marginal distribution of depth by factor,
  # with jittered points (alpha = 0.5). Both panels share the y-axis
  # (depth): panel B's y-axis is hidden and both use the same limits.
  if (!requireNamespace("patchwork", quietly = TRUE)) {
    cli::cli_abort(
      "Package {.pkg patchwork} is required for {.arg add_violin}."
    )
  }

  # Add threshold to the bar plot (log10 is handled below, shared
  # with the violin so both y-axes align).
  if (!is.null(threshold)) {
    p_bar <- p_bar +
      ggplot2::geom_hline(
        yintercept = threshold,
        color = "red",
        linetype = "dashed"
      )
  }

  # Marginal violin: x = color_fac, y = Depth, fill = color_fac.
  # Jittered points (alpha = 0.5) show individual sample depths.
  p_violin <- ggplot(
    df,
    aes(
      x = .data[[color_fac]],
      y = .data[["Depth"]],
      fill = .data[[color_fac]]
    )
  ) +
    geom_violin(alpha = 0.6) +
    geom_point(
      aes(color = .data[[color_fac]]),
      alpha = 0.5,
      position = position_jitter(width = 0.15, seed = 42)
    ) +
    labs(x = color_fac, y = NULL, fill = color_fac) +
    guides(color = "none") +
    theme_minimal() +
    theme(
      axis.text.y = element_blank(),
      axis.ticks.y = element_blank(),
      axis.title.y = element_blank(),
      legend.position = "none"
    )

  # Shared y-scale so the depth axis aligns across both panels.
  # For log10, scale_y_log10() is added to both so they share the same
  # transformed limits. For linear, coord_cartesian zooms without
  # dropping data (no "removed rows" warning from the violin kernel
  # tails) and both panels use the same y limits.
  if (log10) {
    p_bar <- p_bar + ggplot2::scale_y_log10()
    p_violin <- p_violin + ggplot2::scale_y_log10()
  } else {
    y_lim <- c(0, max(df$Depth, na.rm = TRUE) * 1.1)
    p_bar <- p_bar + ggplot2::coord_cartesian(ylim = y_lim)
    p_violin <- p_violin + ggplot2::coord_cartesian(ylim = y_lim)
  }

  if (!is.null(threshold)) {
    p_violin <- p_violin +
      ggplot2::geom_hline(
        yintercept = threshold,
        color = "red",
        linetype = "dashed"
      )
  }

  p_bar +
    p_violin +
    patchwork::plot_layout(
      nrow = 1,
      guides = "collect",
      widths = c(3, 1)
    ) +
    patchwork::plot_annotation(
      title = paste("Per-sample sequencing depth by", color_fac),
      tag_levels = "A"
    )
}
