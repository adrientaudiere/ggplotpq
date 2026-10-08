################################################################################
# Shared helpers ----------------------------------------------------------------

# Theme elements resized for each text category (regex on element names).
.rf_theme_patterns <- c(
  axis_text = "^axis\\.text",
  axis_title = "^axis\\.title",
  titles = "^plot\\.(title|subtitle|caption|tag)$",
  strip = "^strip\\.text",
  legend = "^legend\\.(text|title)$"
)

#' Names of every text element of the ggplot2 theme element tree
#' @noRd
.rf_text_elements <- function() {
  tree <- ggplot2::get_element_tree()
  is_text <- vapply(
    tree,
    function(el) {
      if (is.character(el$class)) {
        "element_text" %in% el$class
      } else {
        identical(el$class, ggplot2::element_text)
      }
    },
    logical(1)
  )
  names(tree)[is_text]
}

#' Convert a length to inches
#' @noRd
.rf_to_inches <- function(x, units, dpi) {
  switch(units, `in` = x, cm = x / 2.54, mm = x / 25.4, px = x / dpi)
}

#' Resolve the figure size (inches), from the arguments, the knitr chunk or
#' the open device
#' @noRd
.rf_resolve_dims <- function(width, height, units, dpi) {
  if (!is.null(width)) {
    width <- .rf_to_inches(width, units, dpi)
  }
  if (!is.null(height)) {
    height <- .rf_to_inches(height, units, dpi)
  }
  if (!is.null(width) && !is.null(height)) {
    return(c(width, height))
  }
  if (
    isTRUE(getOption("knitr.in.progress")) &&
      requireNamespace("knitr", quietly = TRUE)
  ) {
    width <- width %||% knitr::opts_current$get("fig.width")
    height <- height %||% knitr::opts_current$get("fig.height")
  } else if (grDevices::dev.cur() > 1) {
    dev_size <- grDevices::dev.size("in")
    width <- width %||% dev_size[1]
    height <- height %||% dev_size[2]
  }
  if (is.null(width) || is.null(height)) {
    width <- width %||% 7
    height <- height %||% 5
    cli::cli_inform(c(
      "i" = "No figure size given and no graphics device open: using {round(width, 2)} x {round(height, 2)} in.",
      " " = "Give {.arg width} and {.arg height} to fit another size."
    ))
  }
  c(width, height)
}

#' Choose the graphics device used to measure text
#'
#' Font metrics differ between devices (up to ~8 % in width), so text is
#' measured on the device type that renders the figure. Inside knitr the
#' chunk `dev` option decides.
#' @noRd
.rf_resolve_device <- function(device) {
  if (!is.null(device)) {
    device <- match.arg(device, c("png", "pdf", "ragg"))
    if (device == "ragg" && !requireNamespace("ragg", quietly = TRUE)) {
      cli::cli_abort(
        "Package {.pkg ragg} is required for {.code device = \"ragg\"}. Please install it."
      )
    }
    return(device)
  }
  dev <- if (
    isTRUE(getOption("knitr.in.progress")) &&
      requireNamespace("knitr", quietly = TRUE)
  ) {
    knitr::opts_current$get("dev")
  } else {
    NULL
  }
  dev <- if (length(dev) == 0) "png" else dev[1]
  if (grepl("ragg", dev) && requireNamespace("ragg", quietly = TRUE)) {
    "ragg"
  } else if (grepl("pdf", dev)) {
    "pdf"
  } else {
    "png"
  }
}

#' Open an off-screen device of the given size (inches)
#' @noRd
.rf_open_device <- function(device, width, height) {
  if (device == "pdf") {
    grDevices::pdf(NULL, width = width, height = height)
  } else if (device == "ragg") {
    ragg::agg_png(
      tempfile(fileext = ".png"),
      width = width,
      height = height,
      units = "in",
      res = 150
    )
  } else {
    grDevices::png(
      tempfile(fileext = ".png"),
      width = width,
      height = height,
      units = "in",
      res = 150
    )
  }
  grDevices::dev.cur()
}

#' Horizontal and vertical justification of a text grob as numbers
#' @noRd
.rf_just_values <- function(just, hjust, vjust) {
  map_h <- c(left = 0, right = 1, centre = 0.5, center = 0.5)
  map_v <- c(bottom = 0, top = 1, centre = 0.5, center = 0.5)
  h <- 0.5
  v <- 0.5
  if (is.numeric(just)) {
    h <- just[1]
    v <- if (length(just) > 1) just[2] else 0.5
  } else if (is.character(just) && length(just) == 1) {
    if (just %in% names(map_h)) {
      h <- map_h[[just]]
    }
    if (just %in% names(map_v)) {
      v <- map_v[[just]]
    }
  } else if (is.character(just)) {
    h <- map_h[[just[1]]]
    v <- map_v[[just[2]]]
  }
  list(h = hjust %||% h, v = vjust %||% v)
}

#' Text category of a drawn text grob, from its grob path
#' @noRd
.rf_classify <- function(path) {
  if (grepl("guide\\.(title|label)|::guides", path)) {
    "legend"
  } else if (grepl("strip\\.text", path)) {
    "strip"
  } else if (grepl("axis\\.title", path)) {
    "axis_title"
  } else if (grepl("plot\\.(title|subtitle|caption|tag)", path)) {
    "titles"
  } else if (grepl("::axis::", path)) {
    "axis_text"
  } else {
    "geom_text"
  }
}

#' Bounding box of every label drawn by a ggplot or patchwork
#'
#' Draws the plot on the current device, forces the grob tree, then measures
#' each label of each text grob in device coordinates (inches).
#'
#' @return A data frame with one row per label: `category`, `label`, anchor
#'   (`x`, `y`), size (`w`, `h`), `hjust`, `vjust`, `rot` and `fontsize`.
#' @noRd
.rf_text_boxes <- function(p) {
  g <- if (inherits(p, "patchwork")) {
    patchwork::patchworkGrob(p)
  } else {
    ggplot2::ggplotGrob(p)
  }
  grid::grid.newpage()
  grid::grid.draw(g)
  grid::grid.force()
  hits <- grid::grid.grep("text", grep = TRUE, global = TRUE, viewports = TRUE)
  boxes <- lapply(hits, function(hit) {
    gr <- grid::grid.get(hit)
    if (!inherits(gr, "text") || length(gr$label) == 0) {
      return(NULL)
    }
    labels <- gr$label
    n <- length(labels)
    grid::upViewport(0)
    grid::downViewport(attr(hit, "vpPath"))
    if (!is.null(gr$vp)) {
      grid::pushViewport(gr$vp)
    }
    loc <- grid::deviceLoc(gr$x, gr$y, valueOnly = TRUE)
    grid::pushViewport(grid::viewport(gp = gr$gp))
    w <- grid::convertWidth(grid::stringWidth(labels), "in", valueOnly = TRUE)
    h <- grid::convertHeight(grid::stringHeight(labels), "in", valueOnly = TRUE)
    fontsize <- grid::get.gpar("fontsize")$fontsize
    grid::upViewport(0)
    just <- .rf_just_values(gr$just, gr$hjust, gr$vjust)
    data.frame(
      category = .rf_classify(as.character(hit)),
      label = if (is.character(labels)) labels else as.character(labels),
      x = rep_len(loc$x, n),
      y = rep_len(loc$y, n),
      w = w,
      h = h,
      hjust = rep_len(just$h, n),
      vjust = rep_len(just$v, n),
      rot = rep_len(gr$rot %||% 0, n),
      fontsize = fontsize
    )
  })
  boxes <- do.call(rbind, boxes)
  if (is.null(boxes)) {
    return(data.frame())
  }
  boxes[!is.na(boxes$label) & nzchar(boxes$label), , drop = FALSE]
}

#' Corners (4 x 2 matrix, inches) of a possibly rotated label box, enlarged
#' by `pad` on every side
#' @noRd
.rf_corners <- function(box, pad) {
  lx <- c(-box$hjust * box$w - pad, (1 - box$hjust) * box$w + pad)
  ly <- c(-box$vjust * box$h - pad, (1 - box$vjust) * box$h + pad)
  cx <- c(lx[1], lx[2], lx[2], lx[1])
  cy <- c(ly[1], ly[1], ly[2], ly[2])
  a <- box$rot * pi / 180
  cbind(
    x = box$x + cx * cos(a) - cy * sin(a),
    y = box$y + cx * sin(a) + cy * cos(a)
  )
}

#' Do two convex polygons overlap? (separating axis theorem)
#' @noRd
.rf_polygons_overlap <- function(a, b) {
  for (poly in list(a, b)) {
    edges <- poly[c(2:nrow(poly), 1), , drop = FALSE] - poly
    for (i in seq_len(nrow(edges))) {
      axis <- c(-edges[i, 2], edges[i, 1])
      pa <- a %*% axis
      pb <- b %*% axis
      if (max(pa) <= min(pb) || max(pb) <= min(pa)) {
        return(FALSE)
      }
    }
  }
  TRUE
}

#' Find overlapping and out-of-canvas labels
#'
#' @return A named integer vector: number of overlapping label pairs and of
#'   labels leaving the canvas, per category (a pair counts for both of its
#'   categories).
#' @noRd
.rf_find_overlaps <- function(boxes, width, height, pad) {
  counts <- integer(0)
  add <- function(cat) {
    counts[cat] <<- (if (is.na(counts[cat])) 0L else counts[cat]) + 1L
  }
  if (nrow(boxes) == 0) {
    return(counts)
  }
  polys <- lapply(seq_len(nrow(boxes)), function(i) {
    .rf_corners(boxes[i, ], pad)
  })
  xmin <- vapply(polys, function(m) min(m[, "x"]), numeric(1))
  xmax <- vapply(polys, function(m) max(m[, "x"]), numeric(1))
  ymin <- vapply(polys, function(m) min(m[, "y"]), numeric(1))
  ymax <- vapply(polys, function(m) max(m[, "y"]), numeric(1))
  # Labels leaving the canvas (the padding is not counted here)
  out <- xmin + pad < 0 |
    ymin + pad < 0 |
    xmax - pad > width |
    ymax - pad > height
  for (cat in boxes$category[out]) {
    add(cat)
  }
  # Bounding-box prefilter, then exact test on rotated boxes
  cand <- which(
    outer(xmin, xmax, "<") &
      outer(xmax, xmin, ">") &
      outer(ymin, ymax, "<") &
      outer(ymax, ymin, ">"),
    arr.ind = TRUE
  )
  cand <- cand[cand[, 1] < cand[, 2], , drop = FALSE]
  for (k in seq_len(nrow(cand))) {
    i <- cand[k, 1]
    j <- cand[k, 2]
    if (.rf_polygons_overlap(polys[[i]], polys[[j]])) {
      add(boxes$category[i])
      add(boxes$category[j])
    }
  }
  counts
}

#' Complete theme of a plot: the plot theme added to the default theme
#'
#' Equivalent of `ggplot2::complete_theme()` (ggplot2 >= 4.0.0) that also
#' works on ggplot2 3.5.
#' @noRd
.rf_full_theme <- function(theme) {
  ggplot2::theme_get() + theme
}

#' Theme element `el_name` with its size multiplied by `k`
#'
#' A plain `element_text()` holding only the new size is returned, so that the
#' other properties keep inheriting from the theme. Text elements of another
#' class (e.g. `ggtext::element_markdown()`) cannot be merged with an
#' `element_text()`: the resolved element is returned with its size changed.
#' @return A theme element, or `NULL` when the element has no numeric size.
#' @noRd
.rf_resized_element <- function(el_name, th, k) {
  resolved <- ggplot2::calc_element(el_name, th)
  if (is.null(resolved) || !is.numeric(resolved$size)) {
    return(NULL)
  }
  current <- th[[el_name]]
  plain <- c("element_text", "ggplot2::element_text")
  if (is.null(current) || class(current)[1] %in% plain) {
    return(ggplot2::element_text(size = resolved$size * k))
  }
  resolved$size <- resolved$size * k
  resolved
}

#' Multiply the text sizes of one ggplot (not its patches)
#' @noRd
.rf_scale_ggplot <- function(p, k, categories) {
  if (!inherits(p, "ggplot")) {
    return(p)
  }
  th <- .rf_full_theme(p$theme)
  elements <- .rf_text_elements()
  new_els <- list()
  for (cat in intersect(categories, names(.rf_theme_patterns))) {
    for (el_name in grep(.rf_theme_patterns[[cat]], elements, value = TRUE)) {
      new_els[[el_name]] <- .rf_resized_element(el_name, th, k)
    }
  }
  if (length(new_els) > 0) {
    p <- p + do.call(ggplot2::theme, new_els)
  }
  if ("geom_text" %in% categories) {
    p <- .rf_scale_text_layers(p, k)
  }
  p
}

#' Multiply the size of the text and label layers of one ggplot
#'
#' Layers are cloned before being modified: they are environments shared with
#' the input plot. Layers mapping `size` to a variable are left untouched.
#' @noRd
.rf_scale_text_layers <- function(p, k) {
  layers <- p$layers
  for (i in seq_along(layers)) {
    layer <- layers[[i]]
    if (!any(grepl("^Geom(Text|Label)", class(layer$geom)))) {
      next
    }
    mapped <- "size" %in%
      names(layer$mapping) ||
      (isTRUE(layer$inherit.aes) && "size" %in% names(p$mapping))
    if (mapped) {
      next
    }
    size <- layer$aes_params$size %||% .rf_default_size(layer$geom)
    if (!is.numeric(size)) {
      next
    }
    new_layer <- ggplot2::ggproto(NULL, layer)
    new_layer$aes_params <- utils::modifyList(
      layer$aes_params,
      list(size = size * k)
    )
    layers[[i]] <- new_layer
  }
  p$layers <- layers
  p
}

#' Default size of a geom (`get_geom_defaults()` needs ggplot2 >= 3.5.2)
#' @noRd
.rf_default_size <- function(geom) {
  if (exists("get_geom_defaults", envir = asNamespace("ggplot2"))) {
    ggplot2::get_geom_defaults(geom)$size
  } else {
    geom$default_aes$size
  }
}

#' Multiply the text sizes of a ggplot or of every plot of a patchwork
#' @noRd
.rf_scale_plot <- function(p, k, categories) {
  if (inherits(p, "patchwork")) {
    p$patches$plots <- lapply(
      p$patches$plots,
      .rf_scale_plot,
      k = k,
      categories = categories
    )
    annot_theme <- p$patches$annotation$theme
    if ("titles" %in% categories && inherits(annot_theme, "theme")) {
      th <- .rf_full_theme(annot_theme)
      new_els <- lapply(
        c(
          plot.title = "plot.title",
          plot.subtitle = "plot.subtitle",
          plot.caption = "plot.caption"
        ),
        .rf_resized_element,
        th = th,
        k = k
      )
      p$patches$annotation$theme <- annot_theme +
        do.call(ggplot2::theme, new_els)
    }
  }
  .rf_scale_ggplot(p, k, categories)
}

################################################################################
#' Shrink the text of a ggplot so that it fits a given figure size
#'
#' @description
#'
#' <a href="https://adrientaudiere.github.io/MiscMetabar/articles/Rules.html#lifecycle">
#' <img src="https://img.shields.io/badge/lifecycle-experimental-orange" alt="lifecycle-experimental"></a>
#'
#' Finds the largest font scale at which no text of a ggplot (or of a
#' patchwork assembly of ggplots) overlaps another text or leaves the canvas,
#' once the figure is drawn at `width` x `height`, and returns the plot with
#' its text resized by that scale.
#'
#' Text sizes in ggplot2 are absolute (points), so whether labels overlap
#' depends on the final figure size. `resize_fonts()` draws the figure
#' off-screen at that size, measures the box of every label (rotated labels
#' included), and searches the scale by bisection between `min_scale` and
#' `max_scale`. Inside a knitr or Quarto chunk, `width` and `height` default
#' to the chunk's `fig-width` and `fig-height`.
#'
#' @param p A [ggplot2::ggplot] object or a [patchwork][patchwork::patchwork]
#'   assembly.
#' @param width,height (numeric, default `NULL`) Figure size in `units`. When
#'   `NULL`, the size is taken from the current knitr/Quarto chunk
#'   (`fig.width` / `fig-width`, in inches), or else from the open graphics
#'   device, or else defaults to 7 x 5 inches (with a message).
#' @param units (character, default `"in"`) Units of `width` and `height`:
#'   one of `"in"`, `"cm"`, `"mm"` or `"px"`.
#' @param dpi (numeric, default `300`) Resolution used to convert `"px"`.
#' @param axis_text (logical, default `TRUE`) Check the axis tick labels for
#'   overlaps (and resize them, see `resize_all`).
#' @param axis_title (logical, default `TRUE`) Check the axis titles for
#'   overlaps (and resize them).
#' @param titles (logical, default `TRUE`) Check the plot title, subtitle,
#'   caption and tag, including a patchwork annotation, for overlaps (and
#'   resize them).
#' @param strip (logical, default `TRUE`) Check the facet strip text for
#'   overlaps (and resize it).
#' @param legend (logical, default `TRUE`) Check the legend titles and labels
#'   for overlaps (and resize them).
#' @param geom_text (logical, default `FALSE`) Check the text drawn by text
#'   and label layers (`geom_text()`, `geom_label()`, `ggrepel` geoms) for
#'   overlaps (and resize it). Layers mapping `size` to a variable are never
#'   resized.
#' @param resize_all (logical, default `FALSE`) When `FALSE`, only the
#'   categories set to `TRUE` above are resized, and the others keep their
#'   size. When `TRUE`, every text of the plot (all the categories above,
#'   `geom_text` included) is shrunk by the same scale, and the category
#'   arguments only choose which text is checked for overlaps.
#' @param min_scale,max_scale (numeric, default `0.3` and `1`) Range of the
#'   font scale searched. Set `max_scale` above 1 to also let text grow.
#' @param padding (numeric, default `1`) Minimum gap, in points, required
#'   between two labels.
#' @param tolerance (numeric, default `0.02`) Precision of the scale search.
#' @param device (character, default `NULL`) Device used to measure text:
#'   `"png"`, `"pdf"` or `"ragg"`. Font metrics differ slightly between
#'   devices. When `NULL`, the device of the current knitr chunk (`dev`
#'   option) is used, or else `"png"`.
#' @param verbose (logical, default `FALSE`) Print the chosen scale and the
#'   number of overlaps found at full size.
#'
#' @return The plot `p` with its text resized, with the chosen scale stored in
#'   the `"font_scale"` attribute. A category set to `FALSE` is never checked,
#'   and is resized only when `resize_all = TRUE`.
#'
#' @section Limitations:
#'   - Only text drawn as plain grid text is measured: rich text from
#'     'ggtext' or 'marquee' is resized but not checked for overlaps.
#'   - A single scale is applied to every selected category, which keeps the
#'     relative hierarchy of the text sizes; one crowded axis therefore
#'     shrinks all the selected text.
#'   - When some text still overlaps at `min_scale` (e.g. two labels at the
#'     same position), a warning is raised and the plot is returned at
#'     `min_scale`. Consider [ggplot2::guide_axis()] (`n.dodge`, `angle`) or
#'     wrapping labels instead.
#'   - Each step draws the whole figure, so large plots take a few seconds.
#'
#' @author Adrien Taudière
#' @seealso [MiscMetabar::reshape_ggplot()] to wrap long titles before
#'   resizing, [ggplot2::guide_axis()], [ggplot2::ggsave()]
#' @export
#'
#' @examples
#' df <- data.frame(
#'   sample = paste0("Site_forest_", sprintf("%02d", 1:12)),
#'   reads = c(120, 145, 110, 130, 150, 90, 160, 135, 128, 142, 99, 117)
#' )
#' p <- ggplot2::ggplot(df, ggplot2::aes(x = sample, y = reads)) +
#'   ggplot2::geom_col()
#'
#' p_fit <- resize_fonts(p, width = 150, height = 80, units = "mm")
#' attr(p_fit, "font_scale")
#'
#' \dontrun{
#' # In a Quarto chunk, the size comes from the chunk options:
#' #| fig-width: 6
#' #| fig-height: 4
#' resize_fonts(p)
#'
#' # A patchwork, also counting the overlaps of geom_text() labels
#' library(patchwork)
#' resize_fonts(p / p, width = 6, height = 6, geom_text = TRUE)
#'
#' # Shrink every text by the same amount, but only check the axis labels
#' resize_fonts(
#'   p,
#'   width = 4,
#'   height = 3,
#'   axis_title = FALSE,
#'   titles = FALSE,
#'   strip = FALSE,
#'   legend = FALSE,
#'   resize_all = TRUE
#' )
#' }
resize_fonts <- function(
  p,
  width = NULL,
  height = NULL,
  units = c("in", "cm", "mm", "px"),
  dpi = 300,
  axis_text = TRUE,
  axis_title = TRUE,
  titles = TRUE,
  strip = TRUE,
  legend = TRUE,
  geom_text = FALSE,
  resize_all = FALSE,
  min_scale = 0.3,
  max_scale = 1,
  padding = 1,
  tolerance = 0.02,
  device = NULL,
  verbose = FALSE
) {
  if (!inherits(p, "ggplot")) {
    cli::cli_abort(
      "{.arg p} must be a ggplot or a patchwork, not {.obj_type_friendly {p}}."
    )
  }
  units <- match.arg(units)
  if (
    !is.numeric(min_scale) ||
      !is.numeric(max_scale) ||
      min_scale <= 0 ||
      min_scale >= max_scale
  ) {
    cli::cli_abort(
      "{.arg min_scale} and {.arg max_scale} must be positive numbers with {.code min_scale < max_scale}."
    )
  }
  categories <- c(
    axis_text = axis_text,
    axis_title = axis_title,
    titles = titles,
    strip = strip,
    legend = legend,
    geom_text = geom_text
  )
  scaled_categories <- if (isTRUE(resize_all)) {
    names(categories)
  } else {
    names(categories)[categories]
  }
  categories <- names(categories)[categories]
  if (length(categories) == 0) {
    return(p)
  }
  dims <- .rf_resolve_dims(width, height, units, dpi)
  device <- .rf_resolve_device(device)
  pad <- padding / 2 / 72

  old_dev <- grDevices::dev.cur()
  dev <- .rf_open_device(device, dims[1], dims[2])
  on.exit(
    {
      grDevices::dev.off(dev)
      if (old_dev > 1) {
        grDevices::dev.set(old_dev)
      }
    },
    add = TRUE
  )

  overlaps_at <- function(k) {
    scaled <- .rf_scale_plot(p, k, scaled_categories)
    boxes <- suppressMessages(suppressWarnings(.rf_text_boxes(scaled)))
    boxes <- boxes[boxes$category %in% categories, , drop = FALSE]
    .rf_find_overlaps(boxes, dims[1], dims[2], pad)
  }

  first <- overlaps_at(max_scale)
  if (length(first) == 0) {
    scale <- max_scale
  } else {
    last <- overlaps_at(min_scale)
    if (length(last) > 0) {
      cli::cli_warn(c(
        "Some text still overlaps or leaves the canvas at {.code min_scale = {min_scale}}.",
        "i" = "Categories concerned: {.val {names(last)}}.",
        "i" = "Try {.fn ggplot2::guide_axis} ({.arg n.dodge}, {.arg angle}), shorter labels or a larger figure."
      ))
      scale <- min_scale
    } else {
      lo <- min_scale
      hi <- max_scale
      while (hi - lo > tolerance) {
        mid <- (lo + hi) / 2
        if (length(overlaps_at(mid)) == 0) {
          lo <- mid
        } else {
          hi <- mid
        }
      }
      scale <- lo
    }
  }

  if (verbose) {
    n_first <- sum(first)
    cli::cli_inform(c(
      "Figure size: {round(dims[1], 2)} x {round(dims[2], 2)} in, measured on the {.val {device}} device.",
      "Overlapping or out-of-canvas labels at full size: {n_first}.",
      "Font scale: {round(scale, 3)}."
    ))
  }
  res <- if (scale == 1) p else .rf_scale_plot(p, scale, scaled_categories)
  attr(res, "font_scale") <- scale
  res
}
