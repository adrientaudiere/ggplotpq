################################################################################
# The `pq_palette` class.
#
# A pq_palette *is* a named character vector - `scale_fill_manual(values = pal)`
# works on it unchanged - carrying the provenance needed to rebuild or extend
# it in its attributes. The `ggplot_add` method is what lets `p + pal` colour a
# plot produced by any function, inside ggplotpq or outside it, without that
# function knowing anything about palettes.
################################################################################

#' Build a pq_palette object
#'
#' @param colors (character, required) Named vector of colours.
#' @param slot (character, default `NA`) `"tax_table"` or `"sam_data"`.
#' @param var (character, default `NA`) Rank or sample-variable name.
#' @param parent (character, default `NULL`) Parent rank or variable when the
#'   palette is nested.
#' @param parent_colors (character, default `NULL`) Named colours of the
#'   parents, needed to colour leaves added later.
#' @param leaf_parents (character, default `NULL`) Parent of each leaf, named
#'   by leaf key. Recorded at construction rather than inferred from the hues
#'   later, which two near-identical parent hues would defeat.
#' @param add (character, default `NULL`) The reserved entries.
#' @param na_value (character, default `"grey70"`) Colour for levels absent
#'   from the palette.
#'
#' @return An object of class `pq_palette`.
#' @noRd
.pq_new_palette <- function(
  colors,
  slot = NA_character_,
  var = NA_character_,
  parent = NULL,
  parent_colors = NULL,
  leaf_parents = NULL,
  add = NULL,
  na_value = "grey70"
) {
  structure(
    colors,
    pq_slot = slot,
    pq_var = var,
    pq_parent = parent,
    pq_parent_colors = parent_colors,
    pq_leaf_parents = leaf_parents,
    pq_add = add,
    pq_na_value = na_value,
    class = c("pq_palette", "character")
  )
}

#' Is this object a pq_palette?
#'
#' @param x Any object.
#'
#' @return A single logical.
#' @noRd
.pq_is_palette <- function(x) {
  inherits(x, "pq_palette")
}

#' Format a pq_palette for printing
#'
#' @param x (pq_palette, required) The palette to format.
#' @param ... Ignored.
#'
#' @return A character vector of lines.
#' @export
#' @author Adrien Taudière
#' @keywords internal
format.pq_palette <- function(x, ...) {
  var <- attr(x, "pq_var")
  parent <- attr(x, "pq_parent")
  add <- attr(x, "pq_add")
  n_add <- length(add)
  n_levels <- length(x) - n_add

  header <- if (is.null(parent)) {
    sprintf(
      "<pq_palette> %s: %d level%s",
      var,
      n_levels,
      if (n_levels == 1) {
        ""
      } else {
        "s"
      }
    )
  } else {
    sprintf(
      "<pq_palette> %s nested in %s: %d leaves, %d parent%s",
      var,
      parent,
      n_levels,
      length(attr(x, "pq_parent_colors")),
      if (length(attr(x, "pq_parent_colors")) == 1) "" else "s"
    )
  }

  body <- sprintf("  %s  %s", format(names(x)), unname(as.character(x)))
  c(header, body)
}

#' Print a pq_palette
#'
#' @param x (pq_palette, required) The palette to print.
#' @param ... Ignored.
#'
#' @return `x`, invisibly.
#' @export
#' @author Adrien Taudière
#' @keywords internal
print.pq_palette <- function(x, ...) {
  cat(format(x), sep = "\n")
  invisible(x)
}

#' Which discrete aesthetics does a plot map?
#'
#' @param plot (ggplot, required) The plot to inspect.
#'
#' @return A character vector, a subset of `c("fill", "colour")`.
#' @noRd
.pq_mapped_aesthetics <- function(plot) {
  mapped <- names(plot$mapping)
  for (layer in plot$layers) {
    mapped <- c(mapped, names(layer$mapping))
  }
  intersect(c("fill", "colour"), unique(mapped))
}

#' Add a pq_palette to a ggplot with `+`
#'
#' Applies the palette to whichever of `fill` and `colour` the plot maps, as a
#' single [ggplot2::scale_discrete_manual()] call. `drop = FALSE` and
#' `limits = force` keep the legend identical across figures that show
#' different subsets of the levels.
#'
#' @param object (pq_palette, required) The palette being added.
#' @param plot (ggplot, required) The plot it is added to.
#' @param ... Ignored.
#'
#' @return A ggplot object.
#' @exportS3Method ggplot2::ggplot_add
#' @author Adrien Taudière
#' @keywords internal
ggplot_add.pq_palette <- function(object, plot, ...) {
  aesthetics <- .pq_mapped_aesthetics(plot)

  if (length(aesthetics) == 0) {
    cli::cli_warn(c(
      "!" = "The plot maps neither {.field fill} nor {.field colour}; the palette was not applied.",
      "i" = "Map one of them, or apply the palette with {.fn scale_fill_tax_pq}."
    ))
    return(plot)
  }

  plot +
    ggplot2::scale_discrete_manual(
      aesthetics = aesthetics,
      values = stats::setNames(as.character(object), names(object)),
      drop = FALSE,
      limits = force,
      na.value = attr(object, "pq_na_value") %||% "grey70"
    )
}
