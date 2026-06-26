#' Formattable view of track_wkflow output with nesting tree
#'
#' @description
#'
#' <a href="https://adrientaudiere.github.io/MiscMetabar/articles/Rules.html#lifecycle">
#' <img src="https://img.shields.io/badge/lifecycle-experimental-orange" alt="lifecycle-experimental"></a>
#'
#' Wraps the output of [MiscMetabar::track_wkflow()] into a
#' [formattable::formattable()] HTML widget with proportional color bars on
#' count columns (`nb_sequences`, `nb_clusters`, `nb_samples`).
#'
#' When a `parent` mapping is supplied, an ASCII tree is drawn in the first
#' column to visualise which phyloseq object is nested in which, rows are
#' reordered to reflect the hierarchy (depth-first), and two extra columns
#' are appended:
#'
#' * `retention` — child sequences divided by parent sequences, as a
#'   percentage.
#' * `Δ_sequences` / `Δ_clusters` — the true-value difference (not a
#'   percentage) with the parent, shown as a colored arrow: red `↓` for
#'   reductions (pink for small, deep red for large), green `↑` for
#'   augmentations (light green for small, deep green for large).
#'
#' @param track_df (data.frame, required) A data.frame returned by
#'   [MiscMetabar::track_wkflow()].
#' @param parent (named character vector or data.frame, default: NULL) A
#'   named character vector mapping each row name to the row name of its
#'   parent. Use `NA` for roots. Alternatively, a data.frame whose first
#'   column holds object names and second column holds parent names (`NA`
#'   for roots). When `NULL`, no tree or diff columns are produced.
#' @param bar_color (character, default: "lightblue") Color used for the
#'   proportional bars on `nb_sequences`, `nb_clusters`, and `nb_samples`.
#' @param tile_low,tile_high (character, default: "white"/"steelblue")
#'   Colors for the gradient tile applied to any extra numeric columns
#'   (e.g. taxonomy-rank columns added by
#'   `track_wkflow(taxonomy_rank = ...)`).
#' @param show_diff (logical, default: TRUE) If `TRUE` and `parent` is
#'   supplied, insert mini columns after `nb_sequences` and `nb_clusters`
#'   showing the true-value difference with the parent.
#' @param .interp_size (numeric, default: 0.7) Font-size multiplier (in
#'   `em` units) for the diff value text.
#' @param .arrow_size (numeric, default: 1.0) Font-size multiplier (in
#'   `em` units) for the directional arrow in the diff columns.
#' @param big_mark (character, default: "\U2009") Character used to group
#'   digits every 3 places in numeric columns and diff values (e.g.
#'   `19000` becomes `19\U2009000`). Set to `NULL` or `""` to disable
#'   grouping.
#' @param ... Additional arguments passed to [formattable::formattable()].
#'
#' @return A `formattable` object (HTML widget).
#'
#' @author Adrien Taudière
#' @export
#'
#' @examples
#' \donttest{
#' data(data_fungi_mini, package = "MiscMetabar")
#' d_filt <- prune_taxa(taxa_sums(data_fungi_mini) > 10, data_fungi_mini)
#' track <- track_wkflow(list("raw" = data_fungi_mini, "filt" = d_filt))
#' parent <- c(raw = NA, filt = "raw")
#' track_wkflow_formattable(track, parent)
#' }
track_wkflow_formattable <- function(track_df,
                                     parent = NULL,
                                     bar_color = "lightblue",
                                     tile_low = "white",
                                     tile_high = "steelblue",
                                     show_diff = TRUE,
                                     .interp_size = 0.7,
                                     .arrow_size = 1.0,
                                     big_mark = "\u2009",
                                     ...) {
  if (!requireNamespace("formattable", quietly = TRUE)) {
    cli::cli_abort(c(
      "Package {.pkg formattable} is required.",
      "i" = "Install it with {.code install.packages(\"formattable\")}."
    ))
  }
  if (!requireNamespace("htmltools", quietly = TRUE)) {
    cli::cli_abort(c(
      "Package {.pkg htmltools} is required.",
      "i" = "Install it with {.code install.packages(\"htmltools\")}."
    ))
  }

  obj_names <- rownames(track_df)
  if (is.null(obj_names)) {
    obj_names <- as.character(seq_len(nrow(track_df)))
    rownames(track_df) <- obj_names
  }

  # Coerce parent to a named character vector aligned to obj_names ----------
  if (!is.null(parent)) {
    if (is.data.frame(parent)) {
      parent <- stats::setNames(as.character(parent[[2]]),
                                as.character(parent[[1]]))
    }
    parent <- parent[obj_names]
  }

  # Build tree labels and reorder -------------------------------------------
  if (!is.null(parent)) {
    tree <- .build_ascii_tree(obj_names, parent)
    display_order <- tree$order
    tree_labels <- tree$labels
  } else {
    display_order <- obj_names
    tree_labels <- stats::setNames(obj_names, obj_names)
  }

  # Assemble display data.frame (reordered to tree order) -------------------
  out <- data.frame(Object = tree_labels[display_order],
                    stringsAsFactors = FALSE,
                    row.names = NULL)
  out <- cbind(out, track_df[display_order, , drop = FALSE], row.names = NULL)

  # Retention column (child seqs / parent seqs) -----------------------------
  count_cols <- c("nb_sequences", "nb_clusters", "nb_samples")
  count_cols <- intersect(count_cols, names(out))

  if (!is.null(parent) && "nb_sequences" %in% names(out)) {
    retention <- rep(NA_real_, nrow(out))
    for (i in seq_len(nrow(out))) {
      nm <- display_order[i]
      p <- parent[nm]
      if (!is.na(p) && p %in% obj_names) {
        p_val <- track_df[p, "nb_sequences"]
        c_val <- track_df[nm, "nb_sequences"]
        if (!is.na(p_val) && !is.na(c_val) && p_val > 0) {
          retention[i] <- c_val / p_val
        }
      }
    }
    out$retention <- formattable::percent(retention, digits = 1)
  }

  # Diff columns (true value diff with parent) ------------------------------
  diff_col_names <- character(0)
  if (show_diff && !is.null(parent)) {
    new_list <- list()
    for (nm in names(out)) {
      new_list[[nm]] <- out[[nm]]
      if (nm %in% c("nb_sequences", "nb_clusters")) {
        diff_name <- paste0("\u0394_", sub("nb_", "", nm))
        diff_vals <- rep(NA_real_, length(display_order))
        for (i in seq_along(display_order)) {
          nm_row <- display_order[i]
          p <- parent[nm_row]
          if (!is.na(p) && p %in% obj_names) {
            c_val <- track_df[nm_row, nm]
            p_val <- track_df[p, nm]
            if (!is.na(c_val) && !is.na(p_val)) {
              diff_vals[i] <- c_val - p_val
            }
          }
        }
        new_list[[diff_name]] <- diff_vals
        diff_col_names <- c(diff_col_names, diff_name)
      }
    }
    out <- as.data.frame(new_list, check.names = FALSE)
  }

  # Formatter list ----------------------------------------------------------
  fmt <- list()

  if (!is.null(parent)) {
    fmt[["Object"]] <- formattable::formatter(
      "span",
      style = x ~ formattable::style(
        display = "block",
        `white-space` = "pre",
        `font-family` = "monospace",
        `text-align` = "left"
      ),
      x ~ x
    )
  }

  for (cc in count_cols) {
    fmt[[cc]] <- formattable::formatter(
      "span",
      style = x ~ formattable::style(
        display = "block",
        `text-align` = "right",
        `border-radius` = "4px",
        `padding-right` = "2px",
        `white-space` = "nowrap",
        background = vapply(x, function(v) {
          p <- round(ifelse(is.na(v), 0, v / max(x, na.rm = TRUE)) * 100, 2)
          paste0("linear-gradient(to left, ", bar_color, " ", p,
                 "%, transparent ", p, "%)")
        }, character(1), USE.NAMES = FALSE)
      ),
      x ~ .format_grouped(x, big_mark)
    )
  }

  tax_cols <- setdiff(names(out), c("Object", count_cols, "retention", diff_col_names))
  for (tc in tax_cols) {
    if (is.numeric(out[[tc]])) {
      fmt[[tc]] <- formattable::color_tile(tile_low, tile_high)
    }
  }

  for (dc in diff_col_names) {
    fmt[[dc]] <- formattable::formatter(
      "span",
      style = x ~ formattable::style(
        color = .diff_colors(x),
        `font-weight` = "bold",
        `vertical-align` = "top",
        display = "inline-block"
      ),
      x ~ .diff_display_html(x, .arrow_size, .interp_size, big_mark)
    )
  }

  formattable::formattable(out, fmt, ...)
}


# ---- internal helpers -------------------------------------------------------

#' Build ASCII tree labels from a parent mapping
#'
#' Performs a depth-first traversal from each root and returns tree-drawn
#' labels plus the DFS ordering.
#'
#' @param names Character vector of node names (in original order).
#' @param parent Named character vector; `parent[name]` is the parent's name
#'   or `NA` for roots.
#' @return A list with elements `labels` (named character vector of
#'   tree-drawn labels) and `order` (character vector of names in DFS order).
#' @keywords internal
.build_ascii_tree <- function(names, parent) {
  # Validate parents --------------------------------------------------------
  for (nm in names) {
    p <- parent[nm]
    if (!is.na(p) && !(p %in% names)) {
      cli::cli_abort(c(
        "Parent {.val {p}} for {.val {nm}} not found in row names.",
        "i" = "Valid names are: {.val {names}}."
      ))
    }
  }

  # Detect cycles -----------------------------------------------------------
  for (nm in names) {
    seen <- character(0)
    cur <- nm
    while (!is.na(parent[cur]) && parent[cur] %in% names) {
      if (parent[cur] %in% seen) {
        cli::cli_abort(c(
          "Cycle detected in parent mapping involving {.val {nm}}.",
          "i" = "Check the {.arg parent} argument for circular references."
        ))
      }
      seen <- c(seen, cur)
      cur <- parent[cur]
    }
  }

  # Build children list (preserve original order) ---------------------------
  children <- stats::setNames(vector("list", length(names)), names)
  for (nm in names) {
    p <- parent[nm]
    if (!is.na(p) && p %in% names) {
      children[[p]] <- c(children[[p]], nm)
    }
  }

  # Roots: nodes with NA parent or parent not in names ----------------------
  roots <- names[is.na(parent) | !(parent %in% names)]

  # DFS to assign labels and ordering ---------------------------------------
  labels <- stats::setNames(character(length(names)), names)
  order <- character(0)

  .visit <- function(node, prefix, is_last) {
    connector <- if (is_last) "\u2514\u2500\u2500 " else "\u251c\u2500\u2500 "
    labels[node] <<- paste0(prefix, connector, node)
    order <<- c(order, node)
    kids <- children[[node]]
    if (length(kids) > 0) {
      for (i in seq_along(kids)) {
        kid_last <- i == length(kids)
        kid_prefix <- if (is_last) {
          paste0(prefix, "    ")
        } else {
          paste0(prefix, "\u2502   ")
        }
        .visit(kids[i], kid_prefix, kid_last)
      }
    }
  }

  for (r in roots) {
    labels[r] <- r
    order <- c(order, r)
    kids <- children[[r]]
    if (length(kids) > 0) {
      for (i in seq_along(kids)) {
        kid_last <- i == length(kids)
        .visit(kids[i], "", kid_last)
      }
    }
  }

  list(labels = labels, order = order)
}


#' Interpolate between two hex colors
#'
#' @param low Hex color string for `t = 0`.
#' @param high Hex color string for `t = 1`.
#' @param t Numeric vector in `[0, 1]`.
#' @return Character vector of hex color strings.
#' @keywords internal
.interp_color <- function(low, high, t) {
  t <- pmin(pmax(t, 0), 1)
  rgb_low <- grDevices::col2rgb(low)
  rgb_high <- grDevices::col2rgb(high)
  rgb_out <- rgb_low + (rgb_high - rgb_low) * t
  grDevices::rgb(rgb_out[1, ], rgb_out[2, ], rgb_out[3, ],
                 maxColorValue = 255)
}


#' Compute text colors for diff values
#'
#' Negative diffs (reductions) range from pink (small) to dark red (large).
#' Positive diffs (augmentations) range from light green (small) to dark
#' green (large). `NA` is gray.
#'
#' @param diffs Numeric vector of differences.
#' @return Character vector of hex color strings.
#' @keywords internal
.diff_colors <- function(diffs) {
  negs <- diffs[diffs < 0 & !is.na(diffs)]
  poss <- diffs[diffs > 0 & !is.na(diffs)]
  max_neg <- if (length(negs) > 0) max(abs(negs)) else 1
  max_pos <- if (length(poss) > 0) max(poss) else 1

  colors <- rep("#808080", length(diffs))
  for (i in seq_along(diffs)) {
    d <- diffs[i]
    if (is.na(d)) {
      next
    } else if (d < 0) {
      colors[i] <- .interp_color("#FFB6C1", "#8B0000", abs(d) / max_neg)
    } else if (d > 0) {
      colors[i] <- .interp_color("#90EE90", "#006400", d / max_pos)
    } else {
      colors[i] <- "#000000"
    }
  }
  colors
}


#' Format diff values with directional arrows
#'
#' @param diffs Numeric vector of differences.
#' @param big_mark Character used to group digits every 3 places.
#' @return Character vector: `"\u2193 N"` for reductions, `"\u2191 N"` for
#'   augmentations, `"0"` for zero, `"\u2014"` for `NA`.
#' @keywords internal
.diff_display <- function(diffs, big_mark = "\u2009") {
  vapply(diffs, function(d) {
    if (is.na(d)) {
      return("\u2014")
    }
    val <- .format_grouped(abs(d), big_mark)
    if (d < 0) {
      paste0("\u2193 ", val)
    } else if (d > 0) {
      paste0("\u2191 ", val)
    } else {
      "0"
    }
  }, character(1), USE.NAMES = FALSE)
}


#' Format diff values as HTML with separate arrow and value spans
#'
#' Returns a list of [htmltools::HTML()] objects so that nested `<span>`
#' elements are rendered without escaping. The arrow uses `arrow_size` and
#' the value uses `value_size`, allowing the arrow to be larger than the
#' number.
#'
#' @param diffs Numeric vector of differences.
#' @param arrow_size Font-size multiplier (`em`) for the arrow.
#' @param value_size Font-size multiplier (`em`) for the value text.
#' @param big_mark Character used to group digits every 3 places.
#' @return A list of `htmltools::HTML` objects.
#' @keywords internal
.diff_display_html <- function(diffs, arrow_size = 1.0, value_size = 0.7,
                               big_mark = "\u2009") {
  lapply(diffs, function(d) {
    if (is.na(d)) {
      return(htmltools::HTML("\u2014"))
    }
    arrow <- if (d < 0) "\u2193" else if (d > 0) "\u2191" else ""
    val_str <- if (d == 0) "0" else .format_grouped(abs(d), big_mark)
    htmltools::HTML(paste0(
      "<span style=\"font-size:", arrow_size, "em\">", arrow, "</span>",
      "<span style=\"font-size:", value_size, "em\"> ", val_str, "</span>"
    ))
  })
}


#' Format numbers with a digit-grouping mark
#'
#' @param x Numeric vector.
#' @param big_mark Character used to group digits every 3 places. `NULL` or
#'   `""` disables grouping.
#' @return Character vector of formatted strings. `NA` becomes `"\u2014"`.
#' @keywords internal
.format_grouped <- function(x, big_mark = "\u2009") {
  vapply(x, function(v) {
    if (is.na(v)) {
      return("\u2014")
    }
    if (is.null(big_mark) || big_mark == "") {
      return(format(v, scientific = FALSE, trim = TRUE))
    }
    format(v, big.mark = big_mark, scientific = FALSE, trim = TRUE)
  }, character(1), USE.NAMES = FALSE)
}
