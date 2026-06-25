################################################################################
# Shared helpers ----------------------------------------------------------------

#' Extract finite axis values from all built ggplot2 layers
#' @noRd
.pq_extract_axis_values <- function(built, axis) {
  col_names <- if (axis == "y") c("y", "ymax") else c("x", "xmax")
  vals <- c()
  for (layer in built$data) {
    for (col in col_names) {
      if (col %in% names(layer)) {
        v <- layer[[col]]
        vals <- c(vals, v[is.finite(v)])
      }
    }
  }
  vals
}

#' Find the main data cluster and outlier gaps
#'
#' Sorts unique positive values, computes consecutive ratios, and identifies
#' gaps where ratio > cutoff. Returns the segment with the most unique values
#' as the "main cluster", plus the list of gaps.
#'
#' @return A list with `main_min`, `main_max`, and `gaps` (list of
#'   two-element numeric vectors), or `NULL` when no gap exceeds `cutoff`.
#' @noRd
.pq_find_main_cluster <- function(values, cutoff) {
  pos_vals <- values[values > 0]
  if (length(pos_vals) < 2) {
    return(NULL)
  }
  sorted <- sort(unique(pos_vals))
  if (length(sorted) < 2) {
    return(NULL)
  }
  ratios <- sorted[-1] / sorted[-length(sorted)]
  gap_idx <- which(ratios > cutoff)
  if (length(gap_idx) == 0) {
    return(NULL)
  }
  boundaries <- c(0L, gap_idx, length(sorted))
  segments <- lapply(seq_along(boundaries[-1]), function(i) {
    sorted[(boundaries[i] + 1L):boundaries[i + 1L]]
  })
  main_idx <- which.max(vapply(segments, length, integer(1L)))
  main_seg <- segments[[main_idx]]
  # Offset gap boundaries by 0.5 % of the gap so that:
  # - the cluster-max value stays in the lower panel (below gap start)
  # - the first outlier value stays in the upper panel (above gap end)
  gaps <- lapply(gap_idx, function(i) {
    lo <- sorted[i]
    hi <- sorted[i + 1L]
    off <- (hi - lo) * 0.005
    c(lo + off, hi - off)
  })
  list(
    main_min = min(main_seg),
    main_max = max(main_seg),
    gaps = gaps
  )
}

#' Extract (position, value, direction) of outlier data points
#'
#' @param main_min Lower bound of the main cluster.
#' @param main_max Upper bound of the main cluster.
#' @return A data.frame with columns `pos` (position on the other axis),
#'   `val` (outlier value), and `direction` ("high" or "low").
#' @noRd
.pq_extract_outlier_pts <- function(built, axis, main_min, main_max) {
  other <- if (axis == "y") "x" else "y"
  res <- data.frame(
    pos = numeric(0), val = numeric(0), direction = character(0),
    stringsAsFactors = FALSE
  )
  for (layer in built$data) {
    if (!axis %in% names(layer) || !other %in% names(layer)) {
      next
    }
    vals <- layer[[axis]]
    pos <- layer[[other]]
    cases <- list(
      list(mask = is.finite(vals) & vals > main_max, dir = "high"),
      list(mask = is.finite(vals) & vals < main_min, dir = "low")
    )
    for (case in cases) {
      if (any(case$mask)) {
        res <- rbind(res, data.frame(
          pos = pos[case$mask],
          val = vals[case$mask],
          direction = case$dir,
          stringsAsFactors = FALSE
        ))
      }
    }
  }
  if (nrow(res) > 0) unique(res) else res
}

################################################################################
#' Add axis breaks to show outlier values
#'
#' @description
#'
#' <a href="https://adrientaudiere.github.io/MiscMetabar/articles/Rules.html#lifecycle">
#' <img src="https://img.shields.io/badge/lifecycle-experimental-orange" alt="lifecycle-experimental"></a>
#'
#' A thin, opinionated wrapper around [ggbreak::scale_y_break()] and
#' [ggbreak::scale_x_break()] that auto-detects outlier gaps from plot data.
#' A gap is defined by a consecutive ratio: if the ratio of a sorted value to
#' the next smaller value exceeds `cutoff`, the region between them is cut from
#' the axis and replaced by a zigzag break symbol. Multiple gaps produce
#' multiple breaks.
#'
#' The main data cluster (the segment with the most unique values) is shown at
#' full scale; outlier values appear in a compressed secondary panel joined by
#' the break symbol.
#'
#' @param p A [ggplot2::ggplot] object to modify. When `NULL`, returns a spec
#'   object that can be added to a ggplot with `+`.
#' @param cutoff (numeric, default `5`) Ratio threshold for gap detection.
#'   Consecutive sorted positive values `v[i]` and `v[i+1]` define a gap when
#'   `v[i+1] / v[i] > cutoff`. Increase to detect only extreme outliers.
#' @param axis (character, default `"y"`) Which axis to break: `"y"`, `"x"`,
#'   or `"both"`.
#' @param space (numeric, default `0.2`) Relative width of the break gap symbol
#'   as a fraction of the figure dimension. Ignored when `space_proportional =
#'   TRUE`.
#' @param space_proportional (logical, default `FALSE`) When `TRUE`, the visual
#'   width of each break gap symbol is made proportional to the data gap size
#'   relative to the total data range, so the folded axis represents the actual
#'   scale of the gap. The result is clamped to `[0.05, 0.75]`.
#' @param scales (character or numeric, default `"proportional"`) Panel-size
#'   policy. `"proportional"` (default) automatically sizes each outlier panel
#'   proportionally to the data range it contains relative to the lower panel's
#'   display range, so the axis is visually to scale. `"free"` lets ggbreak
#'   choose equal-height panels independently. A positive numeric value sets the
#'   height (width for x) ratio of the outlier panel to the main panel directly.
#' @param expand (logical, default `TRUE`) Whether to let ggplot2 add its
#'   default 5 % expansion to each panel's axis range. Setting to `TRUE`
#'   (default) prevents points and bars right at the panel boundary from being
#'   clipped; set to `FALSE` for exact data-range panels.
#' @param expand_cluster (numeric, default `0.10`) Extra space added above
#'   (y-axis) or to the right of (x-axis) the cluster maximum before the break
#'   starts, as a fraction of the cluster range. Prevents data points right at
#'   the cluster boundary from being clipped.
#'
#' @return A modified ggplot object with axis breaks, or a spec object (when
#'   `p = NULL`). Note: [ggbreak] wraps the plot in a custom grid layout;
#'   adding further ggplot2 layers after `break_outlier_axis()` may behave
#'   unexpectedly.
#'
#' @section Limitations:
#'   - Outlier detection operates on all data values across all layers
#'     collectively (positive values only).
#'   - Works best with linear scales; log-transformed scales may produce
#'     unexpected break positions.
#'   - Requires the **ggbreak** package (listed under `Suggests`).
#'   - Line geoms that cross a break are visually cut at the break boundary
#'     but no additional break symbol is drawn on the line itself.
#'
#' @author Adrien Taudière
#' @seealso [zoom_outlier_axis()], [ggbreak::scale_y_break()],
#'   [ggbreak::scale_x_break()]
#' @export
#'
#' @examples
#' \donttest{
#' df <- data.frame(
#'   sample = c("A", "B", "C", "D", "E"),
#'   reads  = c(120, 145, 110, 130, 5000)
#' )
#' p <- ggplot2::ggplot(df, ggplot2::aes(x = sample, y = reads)) +
#'   ggplot2::geom_col()
#'
#' # Via direct call
#' break_outlier_axis(p, cutoff = 5, axis = "y")
#'
#' # Via + operator
#' p + break_outlier_axis(cutoff = 5)
#'
#' # Proportional break gap (gap symbol sized to the actual data gap)
#' p + break_outlier_axis(cutoff = 5, space_proportional = TRUE)
#' }
#'
#' \dontrun{
#' # With phyloseq — first build the count bar chart, then add the break
#' data(data_fungi_sp_known, package = "MiscMetabar")
#' p_pq <- plot_tax_count_pq(
#'   data_fungi_sp_known, "Time",
#'   merge_sample_by = "Time", taxa_fill = "Class"
#' )
#' p_pq + break_outlier_axis(cutoff = 2)
#' }
break_outlier_axis <- function(
  p = NULL,
  cutoff = 5,
  axis = c("y", "x", "both"),
  space = 0.2,
  space_proportional = FALSE,
  scales = "proportional",
  expand = TRUE,
  expand_cluster = 0.10
) {
  axis <- match.arg(axis, c("y", "x", "both"))
  spec <- structure(
    list(
      cutoff = cutoff, axis = axis,
      space = space, space_proportional = space_proportional,
      scales = scales, expand = expand,
      expand_cluster = expand_cluster
    ),
    class = "break_outlier_axis_spec"
  )
  if (is.null(p)) {
    return(spec)
  }
  if (!inherits(p, "gg")) {
    cli::cli_abort("{.arg p} must be a ggplot object.")
  }

  built <- ggplot2::ggplot_build(p)
  p <- .pq_apply_axis_breaks(
    p, built, axis, cutoff, space, space_proportional, scales, expand, expand_cluster
  )
  p
}

#' Internal: apply ggbreak scales after gap detection
#' @noRd
.pq_apply_axis_breaks <- function(
  plt, built, axis, cutoff, space, space_proportional, scales, expand, expand_cluster
) {
  apply_one_axis <- function(p2, ax) {
    vals <- .pq_extract_axis_values(built, ax)
    cluster <- .pq_find_main_cluster(vals, cutoff)
    if (is.null(cluster)) {
      cli::cli_inform(
        "No {ax}-axis outliers detected with {.arg cutoff} = {cutoff}."
      )
      return(p2)
    }
    if (!requireNamespace("ggbreak", quietly = TRUE)) {
      cli::cli_abort(c(
        "Package {.pkg ggbreak} is required for {.fn break_outlier_axis}.",
        "i" = "Install with {.code install.packages('ggbreak')}."
      ))
    }
    cluster_range <- cluster$main_max - cluster$main_min
    if (cluster_range <= 0) {
      cluster_range <- abs(cluster$main_max) * 0.1 + 1
    }
    total_range <- max(vals) - min(vals[vals > 0])
    pos_vals <- vals[vals > 0 & is.finite(vals)]
    use_proportional <- identical(scales, "proportional")

    if (ax == "y") {
      # Collect all gap lower-boundaries to add as explicit axis ticks, so the
      # break boundary value is always readable at the top of the lower panel.
      boundary_ticks <- numeric(0)
      for (gap in cluster$gaps) {
        adjusted_gap <- c(
          gap[1] + cluster_range * expand_cluster,
          gap[2]
        )
        boundary_ticks <- c(boundary_ticks, adjusted_gap[1])
        sp <- if (space_proportional) {
          gap_sz <- gap[2] - gap[1]
          max(0.05, min(0.75, gap_sz / max(total_range, 1)))
        } else {
          space
        }
        sc <- if (use_proportional) {
          upper_vals <- pos_vals[pos_vals > adjusted_gap[2]]
          upper_range <- if (length(upper_vals) > 0) {
            max(upper_vals) - adjusted_gap[2]
          } else {
            adjusted_gap[2] * 0.1
          }
          lower_range <- max(adjusted_gap[1], 1)
          max(0.05, min(0.5, upper_range / lower_range))
        } else if (is.null(scales)) {
          "free"
        } else {
          scales
        }
        # Upper panel shows exactly 2 tick values: one nice round value just
        # above the gap boundary and the outlier maximum.
        upper_vals <- pos_vals[pos_vals > adjusted_gap[2]]
        upper_max <- if (length(upper_vals) > 0) max(upper_vals) else adjusted_gap[2]
        nice_up <- pretty(c(adjusted_gap[2], upper_max), n = 2)
        tick_lo <- nice_up[nice_up >= adjusted_gap[2]]
        tick_lo <- if (length(tick_lo) > 0) tick_lo[1] else adjusted_gap[2]
        tick_labels <- unique(c(tick_lo, upper_max))
        p2 <- p2 + ggbreak::scale_y_break(
          adjusted_gap,
          space = sp,
          scales = sc,
          expand = expand,
          ticklabels = tick_labels
        )
      }
      # Ensure the break-boundary value appears on the y-axis of the lower panel
      bnd <- boundary_ticks
      p2 <- p2 + ggplot2::scale_y_continuous(
        breaks = function(x) sort(unique(c(scales::breaks_pretty(n = 5)(x), bnd)))
      )
      p2 <- p2 + ggplot2::theme(
        axis.line.y = ggplot2::element_line(color = "black", linewidth = 0.5)
      )
    } else {
      boundary_ticks <- numeric(0)
      for (gap in cluster$gaps) {
        adjusted_gap <- c(
          gap[1] + cluster_range * expand_cluster,
          gap[2]
        )
        boundary_ticks <- c(boundary_ticks, adjusted_gap[1])
        sp <- if (space_proportional) {
          gap_sz <- gap[2] - gap[1]
          max(0.05, min(0.75, gap_sz / max(total_range, 1)))
        } else {
          space
        }
        sc <- if (use_proportional) {
          right_vals <- pos_vals[pos_vals > adjusted_gap[2]]
          right_range <- if (length(right_vals) > 0) {
            max(right_vals) - adjusted_gap[2]
          } else {
            adjusted_gap[2] * 0.1
          }
          left_range <- max(adjusted_gap[1], 1)
          max(0.05, min(0.5, right_range / left_range))
        } else if (is.null(scales)) {
          "free"
        } else {
          scales
        }
        right_vals <- pos_vals[pos_vals > adjusted_gap[2]]
        right_max <- if (length(right_vals) > 0) max(right_vals) else adjusted_gap[2]
        nice_up <- pretty(c(adjusted_gap[2], right_max), n = 2)
        tick_lo <- nice_up[nice_up >= adjusted_gap[2]]
        tick_lo <- if (length(tick_lo) > 0) tick_lo[1] else adjusted_gap[2]
        tick_labels <- unique(c(tick_lo, right_max))
        p2 <- p2 + ggbreak::scale_x_break(
          adjusted_gap,
          space = sp,
          scales = sc,
          expand = expand,
          ticklabels = tick_labels
        )
      }
      bnd <- boundary_ticks
      p2 <- p2 + ggplot2::scale_x_continuous(
        breaks = function(x) sort(unique(c(scales::breaks_pretty(n = 5)(x), bnd)))
      )
      p2 <- p2 + ggplot2::theme(
        axis.line.x = ggplot2::element_line(color = "black", linewidth = 0.5)
      )
    }
    p2
  }

  if (axis %in% c("y", "both")) plt <- apply_one_axis(plt, "y")
  if (axis %in% c("x", "both")) plt <- apply_one_axis(plt, "x")
  plt
}

#' @exportS3Method ggplot2::ggplot_add
#' @keywords internal
ggplot_add.break_outlier_axis_spec <- function(object, plot, ...) {
  if (!inherits(plot, "gg")) {
    cli::cli_abort("{.arg plot} must be a ggplot object.")
  }
  built <- ggplot2::ggplot_build(plot)
  .pq_apply_axis_breaks(
    plot, built,
    axis = object$axis,
    cutoff = object$cutoff,
    space = object$space,
    space_proportional = object$space_proportional,
    scales = object$scales,
    expand = object$expand,
    expand_cluster = object$expand_cluster
  )
}

################################################################################
#' Zoom into the non-outlier region and annotate outliers with arrows
#'
#' @description
#'
#' <a href="https://adrientaudiere.github.io/MiscMetabar/articles/Rules.html#lifecycle">
#' <img src="https://img.shields.io/badge/lifecycle-experimental-orange" alt="lifecycle-experimental"></a>
#'
#' Zooms the plot into the main data cluster by applying
#' [ggplot2::coord_cartesian()], then adds a small arrow with a value label
#' at the panel edge for each outlier data point. Outliers are auto-detected
#' using the same ratio-based approach as [break_outlier_axis()]: a gap
#' between consecutive sorted positive values is declared when their ratio
#' exceeds `cutoff`. The segment with the most unique values becomes the
#' "main cluster" (zoom region); everything outside it is annotated.
#'
#' Arrows for high y-outliers point upward at the top of the panel; low
#' y-outliers point downward at the bottom. The mirror logic applies to
#' x-axis outliers. A `margin` fraction is added beyond the cluster boundary
#' so data at the edge is not clipped. Plot margins are automatically enlarged
#' to prevent arrows and labels that extend beyond the panel from being cut by
#' the device boundary.
#'
#' @param p A [ggplot2::ggplot] object to modify. When `NULL`, returns a spec
#'   object that can be added to a ggplot with `+`.
#' @param cutoff (numeric, default `5`) Ratio threshold for gap/outlier
#'   detection. See [break_outlier_axis()] for details.
#' @param axis (character, default `"y"`) Which axis to process: `"y"`,
#'   `"x"`, or `"both"`.
#' @param arrow_color (character, default `"grey30"`) Colour of the arrows and
#'   value labels.
#' @param arrow_size (numeric, default `0.3`) Arrow head size in centimetres,
#'   passed to [ggplot2::arrow()].
#' @param label_size (numeric, default `3.5`) Text size for outlier value
#'   labels, passed to [ggplot2::annotate()].
#' @param label_format (character, default `NULL`) A `sprintf`-style format
#'   string for outlier values (e.g., `"%.0f"`, `"%.2e"`). When `NULL`,
#'   [base::format()] with `big.mark = ","` is used.
#' @param margin (numeric, default `0.05`) Fraction of the main-cluster range
#'   to add as padding beyond the zoom boundary. The arrow and label are
#'   placed within this margin so they remain visible.
#' @param extra_margin (numeric, default `50`) Additional plot margin in
#'   points (`"pt"`) added to the side(s) where outlier arrows and labels are
#'   drawn, so that `clip = "off"` annotations are not cut by the device
#'   boundary. Set to `0` to disable.
#' @param label_angle (numeric, default `0`) Angle in degrees for outlier value
#'   labels. Use e.g. `90` when many outliers are close together and labels
#'   overlap horizontally.
#'
#' @return A modified [ggplot2::ggplot] object with [ggplot2::coord_cartesian()]
#'   applied (overriding any existing coordinate system) and outlier arrows
#'   added as annotations. `clip = "off"` is set so arrows can extend slightly
#'   beyond the panel edge.
#'
#' @section Limitations:
#'   - Overrides any existing `coord_*` on the plot.
#'   - Outlier detection uses positive values only; negative-value outliers
#'     are not detected.
#'   - Works best with linear scales.
#'   - When multiple outlier points share the same position on the opposite
#'     axis, one arrow is drawn per unique position showing the extreme value.
#'
#' @author Adrien Taudière
#' @seealso [break_outlier_axis()], [ggplot2::coord_cartesian()]
#' @export
#'
#' @examples
#' \donttest{
#' df <- data.frame(
#'   sample = c("A", "B", "C", "D", "E"),
#'   reads  = c(120, 145, 110, 130, 5000)
#' )
#' p <- ggplot2::ggplot(df, ggplot2::aes(x = sample, y = reads)) +
#'   ggplot2::geom_col()
#'
#' # Via direct call
#' zoom_outlier_axis(p, cutoff = 5, axis = "y")
#'
#' # Via + operator with custom label format
#' p + zoom_outlier_axis(cutoff = 5, label_format = "%.0f reads")
#'
#' # Scatter plot with x-axis outlier
#' df2 <- data.frame(x = c(1, 2, 3, 4, 500), y = c(10, 12, 11, 13, 8))
#' p2 <- ggplot2::ggplot(df2, ggplot2::aes(x = x, y = y)) +
#'   ggplot2::geom_point()
#' p2 + zoom_outlier_axis(axis = "x")
#' }
#'
#' \dontrun{
#' data(data_fungi_sp_known, package = "MiscMetabar")
#' p_pq <- plot_tax_count_pq(
#'   data_fungi_sp_known, "Time",
#'   merge_sample_by = "Time", taxa_fill = "Class"
#' )
#' p_pq + zoom_outlier_axis(cutoff = 2)
#' }
zoom_outlier_axis <- function(
  p = NULL,
  cutoff = 5,
  axis = c("y", "x", "both"),
  arrow_color = "grey30",
  arrow_size = 0.3,
  label_size = 3.5,
  label_format = NULL,
  margin = 0.05,
  extra_margin = 50,
  label_angle = 0,
  bar_gradient = TRUE
) {
  axis <- match.arg(axis, c("y", "x", "both"))
  spec <- structure(
    list(
      cutoff = cutoff,
      axis = axis,
      arrow_color = arrow_color,
      arrow_size = arrow_size,
      label_size = label_size,
      label_format = label_format,
      margin = margin,
      extra_margin = extra_margin,
      label_angle = label_angle,
      bar_gradient = bar_gradient
    ),
    class = "zoom_outlier_axis_spec"
  )
  if (is.null(p)) {
    return(spec)
  }
  if (!inherits(p, "gg")) {
    cli::cli_abort("{.arg p} must be a ggplot object.")
  }

  built <- ggplot2::ggplot_build(p)

  fmt_val <- function(x) {
    if (!is.null(label_format)) {
      sprintf(label_format, x)
    } else {
      trimws(format(x, big.mark = " ", digits = 3, scientific = FALSE))
    }
  }

  process_axis <- function(ax) {
    vals <- .pq_extract_axis_values(built, ax)
    cluster <- .pq_find_main_cluster(vals, cutoff)
    if (is.null(cluster)) {
      cli::cli_inform(
        "No {ax}-axis outliers detected with {.arg cutoff} = {cutoff}."
      )
      return(NULL)
    }

    main_min <- cluster$main_min
    main_max <- cluster$main_max
    zoom_range <- main_max - main_min
    if (zoom_range == 0) {
      zoom_range <- abs(main_min) * 0.2 + 1
    }

    plot_min <- main_min - zoom_range * margin
    plot_max <- main_max + zoom_range * margin

    out_pts <- .pq_extract_outlier_pts(built, ax, main_min, main_max)

    annotations <- list()
    if (nrow(out_pts) > 0) {
      for (pos_val in unique(out_pts$pos)) {
        pts <- out_pts[out_pts$pos == pos_val, ]

        # High outlier: short arrow emerging from the panel top/right edge.
        # Arrow start is just inside the panel; tip and label are outside
        # (clip = "off" ensures they are visible beyond the panel boundary).
        high <- pts[pts$direction == "high", ]
        if (nrow(high) > 0) {
          extreme_val <- max(high$val)
          a_start <- plot_max - zoom_range * 0.04
          a_end <- plot_max + zoom_range * 0.06
          if (ax == "y") {
            annotations <- c(annotations, list(list(
              ax = "y", direction = "high",
              x = pos_val,
              y_start = a_start, y_end = a_end,
              label = fmt_val(extreme_val),
              label_coord = a_end + zoom_range * 0.02
            )))
          } else {
            annotations <- c(annotations, list(list(
              ax = "x", direction = "high",
              y = pos_val,
              x_start = a_start, x_end = a_end,
              label = fmt_val(extreme_val),
              label_coord = a_end + zoom_range * 0.02
            )))
          }
        }

        # Low outlier: short arrow at the bottom/left edge.
        low <- pts[pts$direction == "low", ]
        if (nrow(low) > 0) {
          extreme_val <- min(low$val)
          a_start <- plot_min + zoom_range * 0.04
          a_end <- plot_min - zoom_range * 0.06
          if (ax == "y") {
            annotations <- c(annotations, list(list(
              ax = "y", direction = "low",
              x = pos_val,
              y_start = a_start, y_end = a_end,
              label = fmt_val(extreme_val),
              label_coord = a_end - zoom_range * 0.02
            )))
          } else {
            annotations <- c(annotations, list(list(
              ax = "x", direction = "low",
              y = pos_val,
              x_start = a_start, x_end = a_end,
              label = fmt_val(extreme_val),
              label_coord = a_end - zoom_range * 0.02
            )))
          }
        }
      }
    }

    # Collect outlier bar extents for gradient fade-out overlay (y-axis only):
    # detect bar/col geoms from built data (they have xmin/xmax columns).
    bar_fades <- list()
    if (ax == "y" && bar_gradient) {
      a_start_hi <- plot_max - zoom_range * 0.04
      for (ld in built$data) {
        if (!("xmin" %in% names(ld) && "xmax" %in% names(ld))) next
        if (!("y" %in% names(ld))) next
        outlier_rows <- ld[is.finite(ld$y) & ld$y > main_max, , drop = FALSE]
        if (nrow(outlier_rows) == 0) next
        for (i in seq_len(nrow(outlier_rows))) {
          bar_fades <- c(bar_fades, list(list(
            xmin = outlier_rows$xmin[i],
            xmax = outlier_rows$xmax[i],
            # Gradient covers from arrow-start downward 20% of zoom range
            ymin = a_start_hi - zoom_range * 0.20,
            ymax = a_start_hi
          )))
        }
      }
    }

    list(
      lim = c(plot_min, plot_max),
      annotations = annotations,
      bar_fades = bar_fades
    )
  }

  xlim <- NULL
  ylim <- NULL
  all_ann <- list()
  all_bar_fades <- list()

  if (axis %in% c("y", "both")) {
    res <- process_axis("y")
    if (!is.null(res)) {
      ylim <- res$lim
      all_ann <- c(all_ann, res$annotations)
      all_bar_fades <- c(all_bar_fades, res$bar_fades)
    }
  }
  if (axis %in% c("x", "both")) {
    res <- process_axis("x")
    if (!is.null(res)) {
      xlim <- res$lim
      all_ann <- c(all_ann, res$annotations)
      all_bar_fades <- c(all_bar_fades, res$bar_fades)
    }
  }

  # When axis = "both", each arrow's position on the OTHER axis may be an
  # outlier value itself, placing it far outside the visible panel. Clip the
  # annotation position to the known limits so the arrow is always drawn at a
  # visible edge.
  if (!is.null(xlim) && !is.null(ylim)) {
    for (i in seq_along(all_ann)) {
      ann <- all_ann[[i]]
      if (ann$ax == "y") {
        all_ann[[i]]$x <- max(xlim[1], min(xlim[2], ann$x))
      } else {
        all_ann[[i]]$y <- max(ylim[1], min(ylim[2], ann$y))
      }
    }
  }

  if (!is.null(xlim) || !is.null(ylim)) {
    p <- p + ggplot2::coord_cartesian(xlim = xlim, ylim = ylim, clip = "off")
  }

  # Bar gradient fade-out: semi-transparent white rectangles covering the top
  # portion of each outlier bar to signal the bar continues beyond the panel.
  for (bf in all_bar_fades) {
    p <- p +
      ggplot2::annotate(
        "rect",
        xmin = bf$xmin, xmax = bf$xmax,
        ymin = bf$ymin, ymax = bf$ymax,
        fill = "white", alpha = 0.75, color = NA
      )
  }

  arrow_spec <- ggplot2::arrow(
    length = ggplot2::unit(arrow_size, "cm"),
    type = "closed"
  )

  for (ann in all_ann) {
    if (ann$ax == "y") {
      p <- p +
        ggplot2::annotate(
          "segment",
          x = ann$x, xend = ann$x,
          y = ann$y_start, yend = ann$y_end,
          colour = arrow_color,
          arrow = arrow_spec
        ) +
        ggplot2::annotate(
          "text",
          x = ann$x,
          y = ann$label_coord,
          label = ann$label,
          size = label_size,
          colour = arrow_color,
          angle = label_angle,
          vjust = if (ann$direction == "high") 0 else 1
        )
    } else {
      p <- p +
        ggplot2::annotate(
          "segment",
          x = ann$x_start, xend = ann$x_end,
          y = ann$y, yend = ann$y,
          colour = arrow_color,
          arrow = arrow_spec
        ) +
        ggplot2::annotate(
          "text",
          x = ann$label_coord,
          y = ann$y,
          label = ann$label,
          size = label_size,
          colour = arrow_color,
          angle = label_angle,
          hjust = if (ann$direction == "high") 0 else 1
        )
    }
  }

  # Automatically widen the plot margin on the sides that have outlier labels
  # drawn outside the panel (clip = "off"), so they are not cut by the device.
  if (extra_margin > 0 && length(all_ann) > 0) {
    has_high_y <- any(vapply(
      all_ann, function(a) a$ax == "y" && a$direction == "high", logical(1)
    ))
    has_low_y <- any(vapply(
      all_ann, function(a) a$ax == "y" && a$direction == "low", logical(1)
    ))
    has_high_x <- any(vapply(
      all_ann, function(a) a$ax == "x" && a$direction == "high", logical(1)
    ))
    has_low_x <- any(vapply(
      all_ann, function(a) a$ax == "x" && a$direction == "low", logical(1)
    ))
    p <- p + ggplot2::theme(plot.margin = ggplot2::margin(
      t = if (has_high_y) extra_margin else 5.5,
      r = if (has_high_x) extra_margin else 5.5,
      b = if (has_low_y) extra_margin else 5.5,
      l = if (has_low_x) extra_margin else 5.5,
      unit = "pt"
    ))
  }

  p
}

#' @exportS3Method ggplot2::ggplot_add
#' @keywords internal
ggplot_add.zoom_outlier_axis_spec <- function(object, plot, ...) {
  zoom_outlier_axis(
    p = plot,
    cutoff = object$cutoff,
    axis = object$axis,
    arrow_color = object$arrow_color,
    arrow_size = object$arrow_size,
    label_size = object$label_size,
    label_format = object$label_format,
    margin = object$margin,
    extra_margin = object$extra_margin,
    label_angle = object$label_angle,
    bar_gradient = object$bar_gradient
  )
}
################################################################################
