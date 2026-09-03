#' Apply a stored palette to any ggplot
#'
#' @description
#'
#' <a href="https://adrientaudiere.github.io/MiscMetabar/articles/Rules.html#lifecycle">
#' <img src="https://img.shields.io/badge/lifecycle-experimental-orange" alt="lifecycle-experimental"></a>
#'
#' Reads the palette a phyloseq object carries and turns it into a discrete
#' scale, whatever function produced the plot -- inside ggplotpq or outside it.
#' No plotting function needs to know that palettes exist.
#'
#' @details
#'
#' # Which column is used
#'
#' With the default `suffix`, the scale looks for `<var>_color`. If that column
#' is missing but the object carries exactly one other `<var>_color_*` column,
#' that one is used and a message says so; if several exist, the call fails and
#' lists them, because guessing would silently pick a palette. Passing `suffix`
#' explicitly always requires that exact column.
#'
#' # `identity = TRUE`
#'
#' Normally the plot maps the *level* (`aes(fill = Order)`) and the scale
#' translates it into a colour. Some functions outside ggplotpq only let you
#' map an arbitrary column, in which case you map the colour column itself
#' (`aes(fill = Order_color)`) and the values are already hex strings. Set
#' `identity = TRUE` and the scale switches to
#' [ggplot2::scale_fill_identity()], repairing the legend so it shows level
#' names rather than hex codes.
#'
#' # No stored palette
#'
#' These functions never build a palette on the fly. Recomputing one per figure
#' is exactly the instability the anchoring exists to prevent, so an object
#' without a colour column raises an error naming the two correct fixes: store
#' the palette with `add_to_phyloseq = TRUE`, or add it to the plot directly
#' with `p + palette_tax_pq(...)`.
#'
#' @param physeq (phyloseq, required) An object carrying a colour column.
#' @param rank (character, required) A rank name from
#'   [phyloseq::rank_names()]. For the `tax` scales.
#' @param var (character, required) A variable name from
#'   [phyloseq::sample_variables()]. For the `sam` scales.
#' @param suffix (character, default `"_color"`) Column-name suffix, as passed
#'   to [palette_tax_pq()] or [palette_sam_pq()].
#' @param identity (logical, default `FALSE`) The plot maps the colour column
#'   itself rather than the level. See Details.
#' @param drop (logical, default `FALSE`) Keep unused factor levels in the
#'   legend, so figures showing different subsets share one legend.
#' @param limits Passed to the underlying scale. The default `force` keeps
#'   every level of the data, including those a subset does not use.
#' @param na.value (character, default `"grey70"`) Colour for levels absent
#'   from the palette.
#' @param ... Passed to the underlying \pkg{ggplot2} scale.
#'
#' @return A \pkg{ggplot2} scale, to be added to a plot with `+`.
#' @export
#' @author Adrien Taudière
#' @seealso [palette_tax_pq()], [palette_sam_pq()], [show_palette_pq()].
#'
#' @examples
#' \donttest{
#' library(ggplot2)
#' data(data_fungi_mini, package = "MiscMetabar")
#'
#' ps <- palette_tax_pq(
#'   data_fungi_mini, "Order",
#'   n = 8, add_to_phyloseq = TRUE
#' )
#'
#' df <- as.data.frame(table(ps@tax_table@.Data[, "Order"]))
#' names(df) <- c("Order", "n")
#'
#' ggplot(df, aes(Order, n, fill = Order)) +
#'   geom_col() +
#'   scale_fill_tax_pq(ps, "Order")
#' }
#'
#' \dontrun{
#' # A plot built elsewhere that maps the colour column itself
#' df$Order_color <- ps@tax_table@.Data[
#'   match(df$Order, ps@tax_table@.Data[, "Order"]), "Order_color"
#' ]
#' ggplot(df, aes(Order, n, fill = Order_color)) +
#'   geom_col() +
#'   scale_fill_tax_pq(ps, "Order", identity = TRUE)
#' }
scale_fill_tax_pq <- function(
  physeq,
  rank,
  suffix = "_color",
  identity = FALSE,
  drop = FALSE,
  limits = force,
  na.value = "grey70",
  ...
) {
  .pq_scale_from_object(
    physeq = physeq,
    var = rank,
    slot = "tax_table",
    aesthetic = "fill",
    suffix = suffix,
    suffix_given = !missing(suffix),
    identity = identity,
    drop = drop,
    limits = limits,
    na.value = na.value,
    ...
  )
}

#' @rdname scale_fill_tax_pq
#' @export
scale_color_tax_pq <- function(
  physeq,
  rank,
  suffix = "_color",
  identity = FALSE,
  drop = FALSE,
  limits = force,
  na.value = "grey70",
  ...
) {
  .pq_scale_from_object(
    physeq = physeq,
    var = rank,
    slot = "tax_table",
    aesthetic = "colour",
    suffix = suffix,
    suffix_given = !missing(suffix),
    identity = identity,
    drop = drop,
    limits = limits,
    na.value = na.value,
    ...
  )
}

#' @rdname scale_fill_tax_pq
#' @export
scale_fill_sam_pq <- function(
  physeq,
  var,
  suffix = "_color",
  identity = FALSE,
  drop = FALSE,
  limits = force,
  na.value = "grey70",
  ...
) {
  .pq_scale_from_object(
    physeq = physeq,
    var = var,
    slot = "sam_data",
    aesthetic = "fill",
    suffix = suffix,
    suffix_given = !missing(suffix),
    identity = identity,
    drop = drop,
    limits = limits,
    na.value = na.value,
    ...
  )
}

#' @rdname scale_fill_tax_pq
#' @export
scale_color_sam_pq <- function(
  physeq,
  var,
  suffix = "_color",
  identity = FALSE,
  drop = FALSE,
  limits = force,
  na.value = "grey70",
  ...
) {
  .pq_scale_from_object(
    physeq = physeq,
    var = var,
    slot = "sam_data",
    aesthetic = "colour",
    suffix = suffix,
    suffix_given = !missing(suffix),
    identity = identity,
    drop = drop,
    limits = limits,
    na.value = na.value,
    ...
  )
}

#' Decide which colour column a scale should read
#'
#' @param physeq (phyloseq, required) The object to search.
#' @param var (character, required) Rank or sample-variable name.
#' @param slot (character, required) `"tax_table"` or `"sam_data"`.
#' @param suffix (character, required) The requested suffix.
#' @param suffix_given (logical, required) Whether the caller passed `suffix`
#'   explicitly. When it did, only that exact column will do; when it did not,
#'   a single suffixed alternative is accepted.
#'
#' @return The suffix to read.
#' @noRd
.pq_resolve_color_col <- function(physeq, var, slot, suffix, suffix_given) {
  present <- colnames(.pq_slot_df(physeq, slot))
  if (paste0(var, suffix) %in% present) {
    return(suffix)
  }

  if (suffix_given) {
    cli::cli_abort(c(
      "x" = "Column {.field {paste0(var, suffix)}} is not in {.code {slot}}.",
      "i" = "Build it with {.code palette_*_pq(suffix = \"{suffix}\", add_to_phyloseq = TRUE)}."
    ))
  }

  alternatives <- grep(
    paste0("^", .pq_escape_regex(var), "_color"),
    present,
    value = TRUE
  )
  if (length(alternatives) == 1) {
    cli::cli_inform(
      "Using {.field {alternatives}}, the only palette stored for {.val {var}}."
    )
    return(substring(alternatives, nchar(var) + 1))
  }
  if (length(alternatives) > 1) {
    cli::cli_abort(c(
      "x" = "{.val {var}} carries {length(alternatives)} palettes: {.field {alternatives}}.",
      "i" = "Name the one you want with {.arg suffix}."
    ))
  }

  cli::cli_abort(c(
    "x" = "{.arg physeq} carries no palette for {.val {var}}.",
    "i" = "Store one with {.code palette_*_pq({.val {var}}, add_to_phyloseq = TRUE)}.",
    "i" = "Or add the palette straight to the plot: {.code p + palette_*_pq(physeq, {.val {var}})}."
  ))
}

#' Escape the regex metacharacters a column name may contain
#'
#' @param x (character, required) A literal string.
#'
#' @return The same string, safe to paste into a pattern.
#' @noRd
.pq_escape_regex <- function(x) {
  gsub("([.\\\\|()\\[\\]{}^$*+?])", "\\\\\\1", x, perl = TRUE)
}

#' Build the scale itself
#'
#' @inheritParams .pq_resolve_color_col
#' @param aesthetic (character, required) `"fill"` or `"colour"`.
#' @param identity,drop,limits,na.value,... Passed through, see
#'   [scale_fill_tax_pq()].
#'
#' @return A ggplot2 scale.
#' @noRd
.pq_scale_from_object <- function(
  physeq,
  var,
  slot,
  aesthetic,
  suffix,
  suffix_given,
  identity,
  drop,
  limits,
  na.value,
  ...
) {
  MiscMetabar::verify_pq(physeq, check_order = FALSE)
  suffix <- .pq_resolve_color_col(physeq, var, slot, suffix, suffix_given)
  pal <- .pq_read_color_col(physeq, var, slot, suffix)
  if (is.null(pal)) {
    cli::cli_abort(
      "Column {.field {paste0(var, suffix)}} holds no usable colour."
    )
  }

  if (identity) {
    # The plot maps hex strings; the scale only has to repair the legend.
    fun <- if (identical(aesthetic, "fill")) {
      ggplot2::scale_fill_identity
    } else {
      ggplot2::scale_colour_identity
    }
    return(fun(
      guide = "legend",
      breaks = unname(pal),
      labels = names(pal),
      ...
    ))
  }

  fun <- if (identical(aesthetic, "fill")) {
    ggplot2::scale_fill_manual
  } else {
    ggplot2::scale_colour_manual
  }
  fun(
    values = stats::setNames(unname(pal), names(pal)),
    drop = drop,
    limits = limits,
    na.value = na.value,
    ...
  )
}
