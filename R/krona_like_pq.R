utils::globalVariables(c(
  "x0",
  "x1",
  "y0",
  "y1",
  "depth",
  "color",
  "name",
  "xmid",
  "ymid"
))

# ---- weights ---------------------------------------------------------------
.resolve_weights <- function(physeq, weight_by) {
  tn <- phyloseq::taxa_names(physeq)
  if (is.character(weight_by) && length(weight_by) == 1) {
    if (weight_by == "sequences") {
      w <- as.numeric(phyloseq::taxa_sums(physeq))
      names(w) <- tn
      return(w)
    } else if (weight_by == "asv") {
      w <- rep(1, length(tn))
      names(w) <- tn
      return(w)
    } else {
      cli::cli_abort(
        "{.arg weight_by} string must be {.val sequences} or {.val asv}, not {.val {weight_by}}."
      )
    }
  }
  if (is.function(weight_by)) {
    raw <- phyloseq::taxa_sums(physeq)
    w <- as.numeric(weight_by(raw))
    if (length(w) != length(raw)) {
      cli::cli_abort(
        "{.arg weight_by} function must return a vector of length ntaxa ({length(raw)}), not {length(w)}."
      )
    }
    if (anyNA(w) || any(w < 0)) {
      cli::cli_warn(
        "{.arg weight_by} function produced NA or negative values; clamped to 0."
      )
      w[is.na(w) | w < 0] <- 0
    }
    names(w) <- tn
    return(w)
  }
  if (is.numeric(weight_by)) {
    if (length(weight_by) != length(tn)) {
      cli::cli_abort(
        "{.arg weight_by} numeric vector must have length ntaxa ({length(tn)}), not {length(weight_by)}."
      )
    }
    if (anyNA(weight_by) || any(weight_by < 0)) {
      cli::cli_warn(
        "{.arg weight_by} contains NA or negative values; clamped to 0."
      )
    }
    w <- pmax(0, weight_by, na.rm = FALSE)
    w[is.na(w)] <- 0
    names(w) <- tn
    return(w)
  }
  cli::cli_abort(
    "{.arg weight_by} must be {.val sequences}, {.val asv}, a function, or a numeric vector."
  )
}

# ---- HSL -> hex (no deps) --------------------------------------------------
.hsl_to_hex <- function(h, s, l) {
  h <- (h %% 360) / 360
  if (s == 0) {
    v <- round(l * 255)
    return(sprintf("#%02X%02X%02X", v, v, v))
  }
  q <- if (l < 0.5) {
    l * (1 + s)
  } else {
    l + s - l * s
  }
  p <- 2 * l - q
  hue2rgb <- function(p, q, t) {
    if (t < 0) {
      t <- t + 1
    }
    if (t > 1) {
      t <- t - 1
    }
    if (t < 1 / 6) {
      return(p + (q - p) * 6 * t)
    }
    if (t < 1 / 2) {
      return(q)
    }
    if (t < 2 / 3) {
      return(p + (q - p) * (2 / 3 - t) * 6)
    }
    p
  }
  r <- hue2rgb(p, q, h + 1 / 3)
  g <- hue2rgb(p, q, h)
  b <- hue2rgb(p, q, h - 1 / 3)
  sprintf("#%02X%02X%02X", round(r * 255), round(g * 255), round(b * 255))
}

# ---- Build nested hierarchy from tax_table + weights -----------------------
.build_tax_hierarchy <- function(
  df,
  ranks,
  weights,
  depth,
  add_unassigned_rank
) {
  if (nrow(df) == 0) {
    return(NULL)
  }
  rank_idx <- depth + 1
  rank_col <- ranks[rank_idx]
  values <- as.vector(df[[rank_col]])
  na_mask <- is.na(values) | values == ""
  show_unassigned <- (add_unassigned_rank == 0) ||
    (rank_idx <= add_unassigned_rank)

  if (!show_unassigned) {
    keep <- !na_mask
    df <- df[keep, , drop = FALSE]
    weights <- weights[keep]
    values <- values[keep]
    if (nrow(df) == 0) return(NULL)
  } else {
    values[na_mask] <- "unassigned"
  }

  groups <- split(seq_len(nrow(df)), values, drop = TRUE)

  children <- vector("list", length(groups))
  for (i in seq_along(groups)) {
    gname <- names(groups)[i]
    idx <- groups[[i]]
    sub_w <- weights[idx]

    if (gname == "unassigned" || rank_idx == length(ranks)) {
      children[[i]] <- list(
        name = gname,
        value = as.numeric(sum(sub_w)),
        depth = depth + 1,
        children = list()
      )
    } else {
      sub <- .build_tax_hierarchy(
        df[idx, , drop = FALSE],
        ranks,
        sub_w,
        depth + 1,
        add_unassigned_rank
      )
      if (is.null(sub)) {
        children[[i]] <- list(
          name = gname,
          value = as.numeric(sum(sub_w)),
          depth = depth + 1,
          children = list()
        )
      } else {
        sub$name <- gname
        children[[i]] <- sub
      }
    }
  }

  children <- children[!vapply(children, is.null, logical(1))]
  if (length(children) == 0) {
    return(NULL)
  }
  total <- sum(vapply(children, function(x) x$value, numeric(1)))
  list(name = "node", value = total, depth = depth, children = children)
}

# ---- Collect (name, total value) at a given depth for the hue map ----------
.value_at_depth <- function(node, target, depth = 0) {
  if (depth == target) {
    return(setNames(node$value, node$name))
  }
  if (length(node$children) == 0) {
    return(NULL)
  }
  do.call(
    c,
    lapply(node$children, .value_at_depth, target = target, depth = depth + 1)
  )
}

.build_hue_map <- function(hier, color_depth) {
  vals <- .value_at_depth(hier, color_depth)
  if (is.null(vals) || length(vals) == 0) {
    return(list())
  }
  totals <- tapply(as.numeric(vals), names(vals), sum)
  totals <- sort(totals, decreasing = TRUE)
  n <- length(totals)
  hues <- ((seq_len(n) - 1) / n) * 360
  stats::setNames(as.list(hues), names(totals))
}

# ---- Krona-style palette: child inherits parent hue + lightness shift ------
.krona_palette <- function(
  node,
  color_depth,
  hue_map,
  hue = NULL,
  L = 0.55,
  depth = 0
) {
  if (depth == 0) {
    for (i in seq_along(node$children)) {
      node$children[[i]] <- .krona_palette(
        node$children[[i]],
        color_depth,
        hue_map,
        hue = NULL,
        L = 0.55,
        depth = 1
      )
    }
    return(node)
  }
  if (depth < color_depth) {
    node$color <- "#cccccc"
    for (i in seq_along(node$children)) {
      node$children[[i]] <- .krona_palette(
        node$children[[i]],
        color_depth,
        hue_map,
        hue = NULL,
        L = 0.55,
        depth = depth + 1
      )
    }
    return(node)
  }
  if (depth == color_depth) {
    hue <- hue_map[[node$name]]
    if (is.null(hue)) {
      hue <- 0
    }
    L <- 0.58
  }
  node$color <- .hsl_to_hex(hue, 0.65, L)
  n <- length(node$children)
  for (i in seq_len(n)) {
    h_child <- hue + ((i - 1) - (n - 1) / 2) * 7
    L_child <- max(0.22, min(0.75, L * 0.88))
    node$children[[i]] <- .krona_palette(
      node$children[[i]],
      color_depth,
      hue_map,
      hue = h_child,
      L = L_child,
      depth = depth + 1
    )
  }
  node
}

# ---- Flatten hierarchy to a data.frame of arcs (sunburst) ------------------
.flatten_hierarchy <- function(node, x0, x1, depth, rows) {
  rows[[length(rows) + 1]] <- list(
    name = node$name,
    value = node$value,
    depth = depth,
    x0 = x0,
    x1 = x1,
    color = if (is.null(node$color)) NA_character_ else node$color
  )
  kids <- node$children
  if (length(kids) == 0) {
    return(rows)
  }
  total <- sum(vapply(kids, function(k) k$value, numeric(1)))
  if (total <= 0) {
    return(rows)
  }
  span <- x1 - x0
  cum <- x0
  for (k in kids) {
    cx1 <- cum + span * (k$value / total)
    rows <- .flatten_hierarchy(k, cum, cx1, depth + 1, rows)
    cum <- cx1
  }
  rows
}

# ---- Recursive slice-and-dice treemap layout (no dep) ----------------------
.layout_treemap <- function(node, x0, x1, y0, y1, depth, rows, horizontal) {
  rows[[length(rows) + 1]] <- list(
    name = node$name,
    value = node$value,
    depth = depth,
    x0 = x0,
    x1 = x1,
    y0 = y0,
    y1 = y1,
    color = if (is.null(node$color)) NA_character_ else node$color
  )
  kids <- node$children
  if (length(kids) == 0) {
    return(rows)
  }
  total <- sum(vapply(kids, function(k) k$value, numeric(1)))
  if (total <= 0) {
    return(rows)
  }
  if (horizontal) {
    cum <- x0
    for (k in kids) {
      nx1 <- cum + (x1 - x0) * (k$value / total)
      rows <- .layout_treemap(k, cum, nx1, y0, y1, depth + 1, rows, FALSE)
      cum <- nx1
    }
  } else {
    cum <- y0
    for (k in kids) {
      ny1 <- cum + (y1 - y0) * (k$value / total)
      rows <- .layout_treemap(k, x0, x1, cum, ny1, depth + 1, rows, TRUE)
      cum <- ny1
    }
  }
  rows
}

# ---- Static ggplot path ----------------------------------------------------
.krona_static <- function(hier, layout, title) {
  if (layout == "sunburst") {
    rows <- .flatten_hierarchy(hier, 0, 2 * pi, 0, list())
    df <- do.call(
      rbind,
      lapply(rows, function(r) {
        as.data.frame(r, stringsAsFactors = FALSE)
      })
    )
    df <- df[df$depth > 0, , drop = FALSE]
    if (nrow(df) == 0) {
      cli::cli_abort("No data to plot after filtering zero-weight taxa.")
    }
    max_depth <- max(df$depth)
    p <- ggplot2::ggplot() +
      ggplot2::geom_rect(
        data = df,
        ggplot2::aes(
          xmin = x0,
          xmax = x1,
          ymin = depth,
          ymax = depth + 1,
          fill = color
        ),
        color = "white",
        linewidth = 0.3
      ) +
      ggplot2::scale_fill_identity() +
      ggplot2::coord_polar(theta = "x", start = -pi / 2) +
      ggplot2::scale_y_continuous(limits = c(0, max_depth + 1)) +
      ggplot2::theme_void() +
      ggplot2::theme(legend.position = "none") +
      ggplot2::labs(title = title)

    label_df <- df[(df$x1 - df$x0) > 0.25 & df$depth <= 3, , drop = FALSE]
    if (nrow(label_df) > 0) {
      label_df$xmid <- (label_df$x0 + label_df$x1) / 2
      label_df$ymid <- label_df$depth + 0.5
      p <- p +
        ggplot2::geom_text(
          data = label_df,
          ggplot2::aes(x = xmid, y = ymid, label = name),
          size = 3,
          color = "white",
          fontface = "bold"
        )
    }
    return(p)
  }

  rows <- .layout_treemap(hier, 0, 1, 0, 1, 0, list(), TRUE)
  df <- do.call(
    rbind,
    lapply(rows, function(r) {
      as.data.frame(r, stringsAsFactors = FALSE)
    })
  )
  df <- df[df$depth > 0, , drop = FALSE]
  if (nrow(df) == 0) {
    cli::cli_abort("No data to plot after filtering zero-weight taxa.")
  }
  p <- ggplot2::ggplot() +
    ggplot2::geom_rect(
      data = df,
      ggplot2::aes(
        xmin = x0,
        xmax = x1,
        ymin = y0,
        ymax = y1,
        fill = color
      ),
      color = "white",
      linewidth = 0.3
    ) +
    ggplot2::scale_fill_identity() +
    ggplot2::scale_x_continuous(expand = c(0, 0)) +
    ggplot2::scale_y_continuous(expand = c(0, 0)) +
    ggplot2::coord_fixed() +
    ggplot2::theme_void() +
    ggplot2::theme(legend.position = "none") +
    ggplot2::labs(title = title)

  label_df <- df[
    (df$x1 - df$x0) > 0.05 & (df$y1 - df$y0) > 0.06 & df$depth <= 3,
    ,
    drop = FALSE
  ]
  if (nrow(label_df) > 0) {
    label_df$xmid <- (label_df$x0 + label_df$x1) / 2
    label_df$ymid <- (label_df$y0 + label_df$y1) / 2
    p <- p +
      ggplot2::geom_text(
        data = label_df,
        ggplot2::aes(x = xmid, y = ymid, label = name),
        size = 3,
        color = "white",
        fontface = "bold"
      )
  }
  p
}

################################################################################
#' Krona-like interactive taxonomy plot from a phyloseq object
#'
#' @description
#'
#' <a href="https://adrientaudiere.github.io/MiscMetabar/articles/Rules.html#lifecycle">
#' <img src="https://img.shields.io/badge/lifecycle-experimental-orange" alt="lifecycle-experimental"></a>
#'
#' Build a [Krona](https://github.com/marbl/Krona)-style interactive taxonomy
#' explorer from a [phyloseq::phyloseq-class] object, **without** needing
#' KronaTools installed. The interactive version (default) is a D3.js
#' `htmlwidget` that renders in the RStudio viewer, in Shiny, and in R
#' Markdown documents, and can be saved as a self-contained `.html` file via
#' `file_path`. A static ggplot2 version is also available
#' (`interactive = FALSE`) for publication-ready output.
#'
#' Two layouts are supported:
#' - `"sunburst"` (default): concentric rings, one per taxonomic rank; the
#'   **angle** of each wedge is proportional to its value. This is the Krona
#'   pie. Click a wedge to zoom into that subtree (Krona's signature
#'   interaction).
#' - `"treemap"`: nested rectangles; the **area** of each rectangle is
#'   proportional to its value. Click a cell to zoom in.
#'
#' Colours follow the Krona convention: each distinct value at the
#' `color_by` rank receives its own hue, and descendants inherit the parent
#' hue with a progressive lightness shift (darker as you go deeper).
#'
#' This function is a drop-in alternative to [MiscMetabar::krona()], which
#' shells out to KronaTools and does not work on Windows. `krona_like_pq()`
#' works on all platforms because it bundles D3.js locally.
#'
#' @param physeq (required) A [phyloseq::phyloseq-class] object.
#' @param ranks (character or integer, default `"All"`) Taxonomic ranks to
#'   use. `"All"` selects every column of `tax_table(physeq)`; an integer
#'   vector selects columns by position; a character vector selects columns
#'   by name (must all be present in [phyloseq::rank_names()]).
#' @param weight_by Weight applied to each taxon when computing wedge/rectangle
#'   sizes. One of:
#'   - `"sequences"` (default): the total read count per taxon
#'     ([phyloseq::taxa_sums()]).
#'   - `"asv"`: each taxon counts as 1 (distribution of ASVs/OTUs).
#'   - a function: applied to the per-taxon read counts (e.g. `log1p`,
#'     `sqrt`); negative/NA results are clamped to 0 with a warning.
#'   - a numeric vector of length [phyloseq::ntaxa()], aligned to
#'     [phyloseq::taxa_names()]; negative/NA entries are clamped to 0.
#' @param add_unassigned_rank (integer, default 0) Controls how taxa with
#'   missing (`NA` or empty) taxonomic labels are handled. When `0` (default),
#'   `NA` values are relabelled `"unassigned"` at every rank and become a leaf
#'   at the rank where they first occur. When `> 0`, this relabelling only
#'   happens for the first `add_unassigned_rank` ranks (1-based, among the
#'   selected `ranks`); beyond that depth, taxa with `NA` at a rank are
#'   dropped.
#' @param layout (character, default `"sunburst"`) One of `"sunburst"` (angle
#'   = value, Krona pie) or `"treemap"` (area = value).
#' @param interactive (logical, default `TRUE`) If `TRUE`, returns a D3.js
#'   `htmlwidget` (requires the **htmlwidgets** package). If `FALSE`, returns
#'   a static [ggplot2::ggplot] object with no extra dependency.
#' @param title (character, default `NULL`) Chart title. When `NULL`, defaults
#'   to `"Taxonomy"`.
#' @param color_by (character, default `NULL`) Name of the rank whose
#'   distinct values receive distinct hues. Descendants inherit the parent
#'   hue with a lightness shift. When `NULL`, defaults to the first selected
#'   rank (the outermost ring) — the classic Krona look.
#' @param file_path (character, default `NULL`) When `interactive = TRUE` and
#'   this is set, the widget is also saved as a self-contained `.html` file
#'   via [htmlwidgets::saveWidget()]. The widget is then returned invisibly.
#'   Ignored when `interactive = FALSE`.
#' @param width, height (numeric, default `NULL`) Widget dimensions in pixels.
#'   When `NULL`, the widget fills its container (RStudio viewer / Shiny).
#'   Ignored when `interactive = FALSE`.
#'
#' @return When `interactive = TRUE`, an `htmlwidget` object (invisibly if
#'   `file_path` is set). When `interactive = FALSE`, a [ggplot2::ggplot]
#'   object.
#' @author Adrien Taudière
#' @seealso [MiscMetabar::krona()] for the legacy KronaTools wrapper (does
#'   not work on Windows); \url{https://github.com/marbl/Krona} for the
#'   original Krona project.
#' @export
#'
#' @examples
#' \donttest{
#' data(data_fungi_mini, package = "MiscMetabar")
#'
#' # Static sunburst (no extra dependency needed)
#' krona_like_pq(data_fungi_mini, interactive = FALSE)
#'
#' # Static treemap
#' krona_like_pq(data_fungi_mini, layout = "treemap", interactive = FALSE)
#'
#' # Weight by ASV count instead of read count
#' krona_like_pq(data_fungi_mini, weight_by = "asv", interactive = FALSE)
#'
#' # Weight by a transformation of read counts
#' krona_like_pq(data_fungi_mini, weight_by = log1p, interactive = FALSE)
#'
#' # Subset of ranks and a custom title
#' krona_like_pq(
#'   data_fungi_mini,
#'   ranks = c("Phylum", "Class", "Order"),
#'   title = "Fungi — top 3 ranks",
#'   interactive = FALSE
#' )
#' }
#'
#' \dontrun{
#' # Interactive D3 widget (requires the htmlwidgets package)
#' krona_like_pq(data_fungi_mini)
#'
#' # Save a self-contained HTML file to share
#' krona_like_pq(data_fungi_mini, file_path = "krona_fungi.html")
#'
#' # Interactive treemap
#' krona_like_pq(data_fungi_mini, layout = "treemap")
#' }
krona_like_pq <- function(
  physeq,
  ranks = "All",
  weight_by = "sequences",
  add_unassigned_rank = 0,
  layout = c("sunburst", "treemap"),
  interactive = TRUE,
  title = NULL,
  color_by = NULL,
  file_path = NULL,
  width = NULL,
  height = NULL
) {
  verify_pq(physeq)
  layout <- match.arg(layout)

  all_ranks <- phyloseq::rank_names(physeq)
  if (length(ranks) == 1 && ranks == "All") {
    ranks <- all_ranks
  } else if (is.numeric(ranks)) {
    ranks <- all_ranks[ranks]
  } else {
    bad <- setdiff(ranks, all_ranks)
    if (length(bad) > 0) {
      cli::cli_abort(
        "{.arg ranks} not found in tax_table: {.val {bad}}."
      )
    }
  }

  weights <- .resolve_weights(physeq, weight_by)

  tt <- as.data.frame(
    unclass(phyloseq::tax_table(physeq)[, ranks]),
    stringsAsFactors = FALSE
  )

  keep <- weights > 0
  if (sum(!keep) > 0) {
    cli::cli_warn(
      "{sum(!keep)} taxa with zero weight were dropped before plotting."
    )
  }
  tt <- tt[keep, , drop = FALSE]
  weights <- weights[keep]

  if (nrow(tt) == 0) {
    cli::cli_abort("No taxa with positive weight remain to plot.")
  }

  hier <- .build_tax_hierarchy(tt, ranks, weights, 0, add_unassigned_rank)
  if (is.null(hier)) {
    cli::cli_abort("Could not build a taxonomy hierarchy from the data.")
  }
  hier$name <- "All"

  if (is.null(color_by)) {
    color_by <- ranks[1]
  }
  color_depth <- match(color_by, ranks)
  if (is.na(color_depth)) {
    cli::cli_abort(
      "{.arg color_by} rank {.val {color_by}} is not in {.arg ranks}."
    )
  }
  hue_map <- .build_hue_map(hier, color_depth)
  hier <- .krona_palette(hier, color_depth, hue_map)

  if (is.null(title)) {
    title <- "Taxonomy"
  }

  if (interactive) {
    if (!requireNamespace("htmlwidgets", quietly = TRUE)) {
      cli::cli_abort(
        "Package {.pkg htmlwidgets} is required for {.code interactive = TRUE}. Install it with {.code install.packages('htmlwidgets')} or use {.code interactive = FALSE}."
      )
    }
    widget <- htmlwidgets::createWidget(
      name = "krona_like_pq",
      x = list(
        data = hier,
        layout = layout,
        title = title,
        options = list()
      ),
      width = width,
      height = height,
      package = "ggplotpq"
    )
    if (!is.null(file_path)) {
      htmlwidgets::saveWidget(widget, file = file_path, selfcontained = TRUE)
      return(invisible(widget))
    }
    return(widget)
  }

  .krona_static(hier, layout, title)
}
