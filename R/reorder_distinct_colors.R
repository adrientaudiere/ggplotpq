#' Reorder fill and color scales to maximize perceptual contrast between
#' adjacent segments
#'
#' @description
#'
#' <a href="https://adrientaudiere.github.io/MiscMetabar/articles/Rules.html#lifecycle">
#' <img src="https://img.shields.io/badge/lifecycle-experimental-orange" alt="lifecycle-experimental"></a>
#'
#' In stacked bar plots, ggplot2's default discrete palette assigns colors
#' using level ordered (sometimes alphabetically), which often places perceptually
#' similar colors next to
#' each other. This function reassigns the **same set of colors** to factor
#' levels so that visually adjacent segments receive maximally different
#' colors. Both the fill and color scales are updated so that direct
#' labels (e.g. from `label_taxa = TRUE`) stay in sync with the bars.
#'
#' Migrated from `MiscMetabar::reorder_distinct_colors()` and its
#' `ggplot_add` S3 method.
#'
#' @param p A ggplot object that uses a discrete fill aesthetic. Can be
#'   omitted when using the `+` operator (e.g.
#'   `p + reorder_distinct_colors()`).
#' @param alternate_lightness (logical, default FALSE) If TRUE, darken every
#'   other level to add a luminance alternation cue on top of hue
#'   differences.
#' @param lightness_amount (numeric, default 0.15) Intensity of the
#'   lightness alternation (proportion to darken). Only used when
#'   `alternate_lightness = TRUE`.
#' @param colorblind (logical, default FALSE) If TRUE, compute perceptual
#'   distances under simulated deuteranopia so that the reordering
#'   optimizes contrast for colorblind viewers.
#'
#' @return A new ggplot object with [ggplot2::scale_fill_manual()] and
#'   (if a color scale is present) [ggplot2::scale_color_manual()]
#'   replacing the original scales. When `p` is omitted, returns an
#'   object that can be added to a ggplot with `+`.
#' @export
#' @author Adrien Taudière
#' @importFrom grDevices convertColor
#' @importFrom stats dist
#' @examples
#' \donttest{
#' data(data_fungi_mini, package = "MiscMetabar")
#' p <- MiscMetabar::tax_bar_pq(data_fungi_mini, taxa = "Class", fact = "Time")
#' reorder_distinct_colors(p)
#' reorder_distinct_colors(p, colorblind = TRUE)
#' p + reorder_distinct_colors(alternate_lightness = TRUE)
#' }
reorder_distinct_colors <- function(
  p = NULL,
  alternate_lightness = FALSE,
  lightness_amount = 0.15,
  colorblind = FALSE
) {
  spec <- structure(
    list(
      alternate_lightness = alternate_lightness,
      lightness_amount = lightness_amount,
      colorblind = colorblind
    ),
    class = "reorder_distinct_colors_spec"
  )
  if (is.null(p)) {
    return(spec)
  }
  if (!inherits(p, "gg")) {
    cli::cli_abort("{.arg p} must be a ggplot object.")
  }

  pb <- ggplot_build(p)
  fill_scale <- pb$plot$scales$get_scales("fill")
  if (is.null(fill_scale) || !fill_scale$is_discrete()) {
    cli::cli_abort("The plot must have a discrete fill scale.")
  }

  levels <- fill_scale$get_limits()
  n <- length(levels)
  if (n <= 1) {
    return(p)
  }

  na_val <- fill_scale$na.value %||% "grey50"
  colors <- fill_scale$palette(n)
  if (is.null(names(colors))) {
    names(colors) <- levels
  }

  # Convert hex to sRGB matrix (rows = colors, cols = R/G/B in [0,1])
  rgb_mat <- t(col2rgb(colors)) / 255

  # Optionally simulate deuteranopia before computing distances
  if (colorblind) {
    # Brettel 1997 deuteranopia simulation matrix for sRGB
    deutan_mat <- matrix(
      c(
        0.625,
        0.375,
        0.0,
        0.7,
        0.3,
        0.0,
        0.0,
        0.3,
        0.7
      ),
      nrow = 3,
      byrow = TRUE
    )
    rgb_for_dist <- rgb_mat %*% t(deutan_mat)
  } else {
    rgb_for_dist <- rgb_mat
  }

  # Convert to CIE Lab for perceptual distance
  lab_mat <- grDevices::convertColor(rgb_for_dist, from = "sRGB", to = "Lab")

  # Pairwise Euclidean distances in Lab space
  dist_mat <- as.matrix(stats::dist(lab_mat))

  # Greedy reordering: start with the color having the largest mean distance
  avg_dist <- rowMeans(dist_mat)
  order_idx <- integer(n)
  order_idx[1] <- which.max(avg_dist)
  remaining <- setdiff(seq_len(n), order_idx[1])

  for (i in 2:n) {
    prev <- order_idx[i - 1]
    dists_to_prev <- dist_mat[prev, remaining]
    best <- which.max(dists_to_prev)
    order_idx[i] <- remaining[best]
    remaining <- setdiff(remaining, order_idx[i])
  }

  reordered_colors <- colors[order_idx]

  # Optional: alternate lightness (darken even, lighten odd)
  if (alternate_lightness) {
    rgb_reordered <- t(col2rgb(reordered_colors)) / 255
    for (i in seq_along(reordered_colors)) {
      if (i %% 2 == 0) {
        # Darken
        rgb_reordered[i, ] <- pmax(
          rgb_reordered[i, ] * (1 - lightness_amount),
          0
        )
      } else {
        # Lighten
        rgb_reordered[i, ] <- pmin(
          rgb_reordered[i, ] + (1 - rgb_reordered[i, ]) * lightness_amount,
          1
        )
      }
    }
    reordered_colors <- rgb(
      rgb_reordered[, 1],
      rgb_reordered[, 2],
      rgb_reordered[, 3]
    )
  }

  # Build named vector: level -> reordered color
  new_colors <- stats::setNames(reordered_colors, levels)

  # Remove existing fill scale and add the new one
  p$scales$scales <- p$scales$scales[
    !vapply(p$scales$scales, \(s) "fill" %in% s$aesthetics, logical(1))
  ]
  p <- p + scale_fill_manual(values = new_colors, na.value = na_val)

  # Also update the color scale if one exists
  color_scale <- pb$plot$scales$get_scales("colour")
  if (!is.null(color_scale) && color_scale$is_discrete()) {
    color_na_val <- color_scale$na.value %||% "grey50"
    p$scales$scales <- p$scales$scales[
      !vapply(
        p$scales$scales,
        \(s) "colour" %in% s$aesthetics,
        logical(1)
      )
    ]
    p <- p + scale_color_manual(values = new_colors, na.value = color_na_val)
  }

  p
}

#' @exportS3Method ggplot2::ggplot_add
#' @keywords internal
ggplot_add.reorder_distinct_colors_spec <- function(object, plot, ...) {
  reorder_distinct_colors(
    p = plot,
    alternate_lightness = object$alternate_lightness,
    lightness_amount = object$lightness_amount,
    colorblind = object$colorblind
  )
}
