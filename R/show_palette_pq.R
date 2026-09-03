#' Look at a palette before trusting it to a figure
#'
#' @description
#'
#' <a href="https://adrientaudiere.github.io/MiscMetabar/articles/Rules.html#lifecycle">
#' <img src="https://img.shields.io/badge/lifecycle-experimental-orange" alt="lifecycle-experimental"></a>
#'
#' Renders a palette as swatches, as points, or both -- the default, because
#' the two views answer different questions and a palette should pass both.
#' Given a phyloseq object instead of a palette, it lists every palette the
#' object carries, which answers the question a long document eventually
#' raises: *which colours has this object already been given?*
#'
#' @details
#'
#' # Why a point view
#'
#' Two colours that are obviously different as large flat swatches can be
#' indistinguishable as 3-pixel dots. A palette destined for an ordination or a
#' scatter plot has to be judged at the size it will actually be drawn, which
#' `geom = "point"` does and `geom = "tile"` cannot.
#'
#' `n_preview` goes further and repeats each level as a small cloud, so
#' overplotting is visible too. The scatter is deterministic, not random: the
#' same palette always draws the same preview.
#'
#' # Nested palettes
#'
#' A palette built with `nested` is faceted by parent, so each parent's
#' gradient can be read on its own. This is the fastest way to see that a
#' parent holds more leaves than its lightness ramp can carry.
#'
#' @param x (pq_palette, phyloseq or named character, required) The palette to
#'   draw, or an object whose palettes should be listed.
#' @param geom (character, default `"both"`) `"both"`, `"tile"` or `"point"`.
#'   The default puts the swatch view and the point view side by side.
#' @param point_size (numeric, default `2.5`) Point size for the point view.
#'   Set it to the size the real figure will use; the default is about what an
#'   ordination draws.
#' @param n_preview (integer, default `25`) Number of points drawn per level
#'   in the point view. Above 1, each level becomes a small cloud, showing what
#'   overplotting will look like. Ignored by the swatch view.
#' @param label (logical, default `TRUE`) Show the level names.
#'
#' @return A [ggplot2::ggplot] object, or a \pkg{patchwork} object when
#'   `geom = "both"`.
#' @export
#' @author Adrien Taudière
#' @seealso [palette_tax_pq()], [palette_sam_pq()].
#'
#' @examples
#' \donttest{
#' data(data_fungi_mini, package = "MiscMetabar")
#'
#' pal <- palette_tax_pq(data_fungi_mini, "Order", n = 8)
#'
#' # Both views at once: swatches, and a cloud at ordination point size
#' show_palette_pq(pal)
#'
#' # One view only
#' show_palette_pq(pal, geom = "tile")
#' show_palette_pq(pal, geom = "point", point_size = 4, n_preview = 1)
#' }
#'
#' \dontrun{
#' # Every palette the object carries
#' ps <- palette_tax_pq(data_fungi_mini, "Order", n = 8, add_to_phyloseq = TRUE)
#' show_palette_pq(ps)
#' }
show_palette_pq <- function(
  x,
  geom = "both",
  point_size = 2.5,
  n_preview = 25,
  label = TRUE
) {
  geom <- rlang::arg_match0(geom, c("both", "tile", "point"))
  if (!rlang::is_scalar_integerish(n_preview) || n_preview < 1) {
    cli::cli_abort("{.arg n_preview} must be a single positive integer.")
  }

  df <- .pq_palette_plot_df(x)

  if (identical(geom, "both")) {
    # The swatch view carries the labels; repeating them next to the cloud
    # would only take space away from the points.
    return(patchwork::wrap_plots(
      list(
        .pq_palette_tiles(df, label),
        .pq_palette_points(df, point_size, n_preview, label = FALSE)
      ),
      nrow = 1
    ))
  }
  if (identical(geom, "tile")) {
    return(.pq_palette_tiles(df, label))
  }
  .pq_palette_points(df, point_size, n_preview, label)
}

#' Turn any accepted input into a plotting data.frame
#'
#' @param x (pq_palette, phyloseq or named character, required) The input.
#'
#' @return A data.frame with `level` (an ordered factor), `color` and `facet`.
#' @noRd
.pq_palette_plot_df <- function(x) {
  if (methods::is(x, "phyloseq")) {
    return(.pq_object_palettes_df(x))
  }

  if (!is.character(x) || is.null(names(x))) {
    cli::cli_abort(
      "{.arg x} must be a {.cls pq_palette}, a phyloseq object, or a named character vector of colours."
    )
  }

  # A nested palette records each leaf's parent at construction. A palette
  # read back from a stored colour column does not carry it, and is drawn
  # unfaceted.
  leaf_parents <- attr(x, "pq_leaf_parents")
  facet <- NA_character_
  if (!is.null(leaf_parents)) {
    facet <- unname(leaf_parents[names(x)])
    facet[is.na(facet)] <- "reserved"
  }

  .pq_plot_df(names(x), as.character(x), facet)
}

#' Build the plotting data.frame from parallel vectors
#'
#' @param level,color,facet (character, required) Parallel vectors.
#'
#' @return A data.frame ready for the geoms.
#' @noRd
.pq_plot_df <- function(level, color, facet) {
  df <- data.frame(
    level = level,
    color = color,
    facet = facet,
    stringsAsFactors = FALSE
  )
  # Reversed, so the first entry of the palette sits at the top of the panel.
  df$level <- factor(df$level, levels = rev(unique(df$level)))
  df
}

#' Every palette an object carries
#'
#' @param physeq (phyloseq, required) The object to inspect.
#'
#' @return A data.frame, one block of rows per colour column found.
#' @noRd
.pq_object_palettes_df <- function(physeq) {
  found <- .pq_find_color_cols(physeq)
  if (nrow(found) == 0) {
    cli::cli_abort(c(
      "x" = "{.arg x} carries no colour column.",
      "i" = "Build one with {.fn palette_tax_pq} or {.fn palette_sam_pq} and {.code add_to_phyloseq = TRUE}."
    ))
  }

  blocks <- lapply(seq_len(nrow(found)), function(i) {
    pal <- .pq_read_color_col(
      physeq,
      found$var[i],
      found$slot[i],
      found$suffix[i]
    )
    if (is.null(pal)) {
      return(NULL)
    }
    .pq_plot_df(names(pal), unname(pal), found$column[i])
  })

  out <- do.call(rbind, Filter(Negate(is.null), blocks))
  out$level <- factor(out$level, levels = rev(unique(as.character(out$level))))
  out
}

#' Add faceting when the data.frame carries a facet variable
#'
#' @param p (ggplot, required) The plot to complete.
#' @param df (data.frame, required) The plotting data.
#'
#' @return A ggplot object.
#' @noRd
.pq_maybe_facet <- function(p, df) {
  if (all(is.na(df$facet))) {
    return(p)
  }
  p + ggplot2::facet_wrap(~facet, scales = "free_y")
}

#' Swatch view of a palette
#'
#' @param df (data.frame, required) From [.pq_palette_plot_df()].
#' @param label (logical, required) Show level names.
#'
#' @return A ggplot object.
#' @noRd
.pq_palette_tiles <- function(df, label) {
  p <- ggplot2::ggplot(
    df,
    ggplot2::aes(x = 1, y = .data[["level"]], fill = .data[["color"]])
  ) +
    ggplot2::geom_tile(colour = "white", linewidth = 0.4) +
    ggplot2::scale_fill_identity() +
    ggplot2::scale_x_continuous(expand = c(0, 0)) +
    ggplot2::labs(x = NULL, y = NULL) +
    ggplot2::theme_minimal() +
    ggplot2::theme(
      axis.text.x = ggplot2::element_blank(),
      panel.grid = ggplot2::element_blank()
    )
  if (!label) {
    p <- p + ggplot2::theme(axis.text.y = ggplot2::element_blank())
  }
  .pq_maybe_facet(p, df)
}

#' Point view of a palette, at the size a real figure would draw it
#'
#' @param df (data.frame, required) From [.pq_palette_plot_df()].
#' @param point_size (numeric, required) Point size.
#' @param n_preview (integer, required) Points per level.
#' @param label (logical, required) Show level names.
#'
#' @return A ggplot object.
#' @noRd
.pq_palette_points <- function(df, point_size, n_preview, label) {
  if (n_preview > 1) {
    # A deterministic scatter: incommensurable multipliers spread the points
    # without repeating, and without touching the RNG.
    k <- seq_len(n_preview)
    dx <- 0.42 * sin(k * 2.399963)
    dy <- 0.30 * cos(k * 1.618034)
    df <- do.call(
      rbind,
      lapply(k, function(i) {
        block <- df
        block$x <- 1 + dx[i]
        block$jitter <- dy[i]
        block
      })
    )
  } else {
    df$x <- 1
    df$jitter <- 0
  }

  p <- ggplot2::ggplot(
    df,
    ggplot2::aes(
      x = .data[["x"]],
      y = as.integer(.data[["level"]]) + .data[["jitter"]],
      colour = .data[["color"]]
    )
  ) +
    ggplot2::geom_point(size = point_size) +
    ggplot2::scale_colour_identity() +
    ggplot2::scale_x_continuous(expand = ggplot2::expansion(mult = 0.35)) +
    ggplot2::scale_y_continuous(
      breaks = seq_along(levels(df$level)),
      labels = levels(df$level),
      expand = ggplot2::expansion(mult = 0.05)
    ) +
    ggplot2::labs(x = NULL, y = NULL) +
    ggplot2::theme_minimal() +
    ggplot2::theme(
      axis.text.x = ggplot2::element_blank(),
      panel.grid.minor = ggplot2::element_blank()
    )
  if (!label) {
    p <- p + ggplot2::theme(axis.text.y = ggplot2::element_blank())
  }
  .pq_maybe_facet(p, df)
}
