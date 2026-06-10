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
#' @param physeq (required) A [phyloseq::phyloseq-class] object.
#' @param geom (character, default "bar") One of `"bar"` (a single
#'   bar per sample) or `"density"` (a smoothed density estimate).
#' @param color_by (character, default NULL) Optional name of a column
#'   in [phyloseq::sample_data()] to color the bars by. Ignored when
#'   `geom = "density"`.
#' @param threshold (numeric, default NULL) Optional horizontal
#'   reference line drawn at this depth value. Common use: the
#'   rarefaction cutoff.
#' @param log10 (logical, default FALSE) If TRUE, the y-axis (or the
#'   density's x-axis) is log10-transformed.
#' @param sort (logical, default FALSE) If TRUE, samples are sorted
#'   from highest to lowest depth. Useful for bar plots to spot
#'   outliers at a glance.
#'
#' @return A [ggplot2::ggplot] object.
#' @author Adrien Taudière
#' @export
#'
#' @examples
#' \donttest{
#' data(data_fungi_mini, package = "MiscMetabar")
#' plot_sample_depth_pq(data_fungi_mini)
#' plot_sample_depth_pq(data_fungi_mini, geom = "density", log10 = TRUE)
#' plot_sample_depth_pq(data_fungi_mini, color_by = "Height", sort = TRUE)
#' }
plot_sample_depth_pq <- function(
  physeq,
  geom = c("bar", "density"),
  color_by = NULL,
  threshold = NULL,
  log10 = FALSE,
  sort = FALSE
) {
  if (!requireNamespace("phyloseq", quietly = TRUE)) {
    cli::cli_abort("Package {.pkg phyloseq} is required.")
  }

  geom <- match.arg(geom)

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

  if (!is.null(color_by)) {
    if (!color_by %in% colnames(phyloseq::sample_data(physeq))) {
      cli::cli_abort(
        "{.arg color_by} = {.val {color_by}} not found in sample_data."
      )
    }
    color_vec <- phyloseq::sample_data(physeq)[[color_by]]
    color_vec <- color_vec[match(
      df$Sample,
      rownames(phyloseq::sample_data(physeq))
    )]
    df[[color_by]] <- color_vec
  }

  if (sort) {
    df$Sample <- factor(df$Sample, levels = df$Sample[order(-df$Depth)])
  } else {
    df$Sample <- factor(df$Sample, levels = df$Sample)
  }

  if (identical(geom, "density")) {
    p <- ggplot(df, aes(x = .data[["Depth"]])) +
      geom_density(fill = "steelblue", alpha = 0.6) +
      labs(
        x = "Sequencing depth",
        y = "Density",
        title = "Distribution of per-sample sequencing depth"
      ) +
      theme_minimal()
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
  p <- ggplot(
    df,
    aes(
      x = .data[["Sample"]],
      y = .data[["Depth"]]
    )
  ) +
    geom_col(
      fill = if (is.null(color_by)) "steelblue" else NULL
    ) +
    labs(
      x = NULL,
      y = "Sequencing depth (number of sequences)",
      title = "Per-sample sequencing depth"
    ) +
    theme_minimal() +
    theme(axis.text.x = element_text(angle = 45, hjust = 1))

  if (!is.null(color_by)) {
    p <- p +
      ggplot2::aes(fill = .data[[color_by]]) +
      ggplot2::geom_col() +
      ggplot2::labs(fill = color_by)
  }

  if (log10) {
    p <- p + ggplot2::scale_y_log10()
  }
  if (!is.null(threshold)) {
    p <- p +
      ggplot2::geom_hline(
        yintercept = threshold,
        color = "red",
        linetype = "dashed"
      )
  }

  p
}
