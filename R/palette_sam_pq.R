#' Build a stable colour palette for a sample variable
#'
#' @description
#'
#' <a href="https://adrientaudiere.github.io/MiscMetabar/articles/Rules.html#lifecycle">
#' <img src="https://img.shields.io/badge/lifecycle-experimental-orange" alt="lifecycle-experimental"></a>
#'
#' The `sample_data` counterpart of [palette_tax_pq()]: assigns a colour to
#' each level of a sample variable, so that a modality keeps the same colour
#' across every figure of a document even when a subset does not contain it.
#'
#' @details
#'
#' # Two kinds of variable
#'
#' Sample variables split into two families that deserve different colours,
#' and `type = "auto"` tells them apart:
#'
#' - **qualitative** (default for unordered factors and character columns):
#'   distinct hues at constant lightness, drawn from the IdEst palettes.
#' - **sequential** (default for ordered factors and numeric columns): a single
#'   hue with increasing lightness, which reads as a gradient. Use it for
#'   sampling time, depth, pH -- anything where the order carries meaning and a
#'   rainbow would destroy it.
#'
#' # Level order
#'
#' `order_by = "levels"` honours the levels of a factor, so a variable declared
#' as `factor(x, levels = c("T0", "SS", "Inoc"))` colours in that order rather
#' than alphabetically. This matters most for `type = "sequential"`, where the
#' order *is* the message. Non-factor columns fall back to alphabetical order,
#' which has the advantage of being stable when a modality disappears.
#'
#' # Where the palette lives
#'
#' Exactly as in [palette_tax_pq()]: `add_to_phyloseq = TRUE` writes a
#' `<var><suffix>` column into `sample_data` and returns the phyloseq object,
#' an existing column is read back rather than recomputed, `suffix` lets a
#' second palette coexist, and `force` overwrites.
#'
#' @param physeq (phyloseq, required) A phyloseq object with `sample_data`.
#' @param var (character, required) A variable name from
#'   [phyloseq::sample_variables()].
#' @param type (character, default `"auto"`) `"auto"`, `"qualitative"` or
#'   `"sequential"`. See Details.
#' @param order_by (character, default `"levels"`) `"levels"` honours factor
#'   levels and falls back to alphabetical order otherwise, `"frequency"`
#'   sorts by decreasing number of samples, `"alpha"` sorts alphabetically.
#' @param nested (character, default `NULL`) Name of a parent sample variable
#'   (for instance `"Region"` for `var = "Site"`). Hue then encodes the parent
#'   and lightness the level within it.
#' @param palette (character, default `"auto"`) `"auto"` picks the smallest
#'   colourblind-safe IdEst palette that fits. For `type = "sequential"` only
#'   the first colour is used, as the hue of the ramp; pass a single hex value
#'   to choose that hue explicitly.
#' @param add (character, default `c("NA" = "grey85")`) Named reserved entries
#'   appended after the levels.
#' @param reorder (logical, default `FALSE`) Reassign the colours to maximise
#'   contrast between consecutive levels. Meaningless for
#'   `type = "sequential"`, where it is refused, and for `nested`.
#' @param alternate_lightness (logical, default `FALSE`) Alternately lighten
#'   and darken levels. Refused for `type = "sequential"` and for `nested`.
#' @param lightness_amount (numeric, default `0.15`) Size of that alternation.
#' @param l_range (numeric, default `c(0.35, 0.82)`) Lightness bounds of the
#'   sequential ramp, or of each parent's gradient when `nested` is supplied.
#' @param on_duplicate (character, default `"parent"`) See [palette_tax_pq()].
#'   Only used when `nested` is supplied.
#' @param add_to_phyloseq (logical, default `FALSE`) Write the colours into
#'   `sample_data` and return the phyloseq object instead of the palette.
#' @param suffix (character, default `"_color"`) Appended to `var` to build the
#'   column name.
#' @param force (logical, default `FALSE`) Overwrite an existing colour column.
#'
#' @return A `pq_palette` (a named character vector) when
#'   `add_to_phyloseq = FALSE`, or the modified phyloseq object when it is
#'   `TRUE`.
#' @export
#' @author Adrien Taudière
#' @seealso [palette_tax_pq()] for taxonomic ranks, [show_palette_pq()] to
#'   check a palette, [scale_fill_sam_pq()] to apply one.
#'
#' @examples
#' \donttest{
#' data(data_fungi_mini, package = "MiscMetabar")
#'
#' # Qualitative: one hue per modality
#' palette_sam_pq(data_fungi_mini, "Height")
#'
#' # Sequential: a single hue, lightness carrying the order
#' palette_sam_pq(data_fungi_mini, "Time", type = "sequential")
#' }
#'
#' \dontrun{
#' # Store the anchoring inside the object
#' ps <- palette_sam_pq(data_fungi_mini, "Height", add_to_phyloseq = TRUE)
#' }
palette_sam_pq <- function(
  physeq,
  var,
  type = "auto",
  order_by = "levels",
  nested = NULL,
  palette = "auto",
  add = c("NA" = "grey85"),
  reorder = FALSE,
  alternate_lightness = FALSE,
  lightness_amount = 0.15,
  l_range = c(0.35, 0.82),
  on_duplicate = "parent",
  add_to_phyloseq = FALSE,
  suffix = "_color",
  force = FALSE
) {
  MiscMetabar::verify_pq(physeq, check_order = FALSE)
  if (is.null(physeq@sam_data)) {
    cli::cli_abort("{.arg physeq} has no {.code sample_data}.")
  }

  vars <- phyloseq::sample_variables(physeq)
  if (!rlang::is_string(var) || !var %in% vars) {
    cli::cli_abort(c(
      "x" = "{.arg var} must be one of the sample variables of {.arg physeq}.",
      "i" = "Available: {.val {vars}}."
    ))
  }
  if (!is.null(nested)) {
    if (!rlang::is_string(nested) || !nested %in% vars) {
      cli::cli_abort(c(
        "x" = "{.arg nested} must be one of the sample variables of {.arg physeq}.",
        "i" = "Available: {.val {vars}}."
      ))
    }
    if (identical(nested, var)) {
      cli::cli_abort("{.arg nested} must differ from {.arg var}.")
    }
  }
  type <- rlang::arg_match0(type, c("auto", "qualitative", "sequential"))

  col <- .pq_color_col(var, suffix)

  if (!add_to_phyloseq) {
    stored <- .pq_read_color_col(physeq, var, "sam_data", suffix)
    if (!is.null(stored)) {
      cli::cli_inform(c(
        "v" = "Reusing the palette stored in {.field {col}} ({length(stored)} level{?s})."
      ))
      return(.pq_new_palette(
        c(stored, add),
        slot = "sam_data",
        var = var,
        parent = nested,
        add = add
      ))
    }
  }

  values <- .pq_slot_df(physeq, "sam_data")[[var]]
  if (identical(type, "auto")) {
    type <- if (is.ordered(values) || is.numeric(values)) {
      "sequential"
    } else {
      "qualitative"
    }
  }

  levels_vec <- .pq_sam_levels(physeq, var, order_by = order_by)
  if (length(levels_vec) == 0) {
    cli::cli_abort("Variable {.val {var}} holds no non-missing value.")
  }

  if (identical(type, "sequential")) {
    if (!is.null(nested)) {
      cli::cli_abort(
        "{.arg nested} and {.code type = \"sequential\"} both drive lightness; use one or the other."
      )
    }
    if (reorder || alternate_lightness) {
      offender <- if (reorder) "reorder" else "alternate_lightness"
      cli::cli_abort(c(
        "x" = "{.arg {offender}} cannot be combined with {.code type = \"sequential\"}.",
        "i" = "A sequential ramp reads as a gradient; permuting or alternating it destroys the order it encodes."
      ))
    }
    built <- list(
      colors = c(
        stats::setNames(
          .pq_sequential_oklch(length(levels_vec), palette, l_range),
          levels_vec
        ),
        add
      ),
      parent_colors = NULL
    )
  } else {
    parents <- NULL
    if (!is.null(nested)) {
      parents <- .pq_parents_of(
        .pq_slot_df(physeq, "sam_data"),
        var,
        nested,
        levels_vec
      )
    }
    built <- .pq_palette_engine(
      levels = levels_vec,
      parents = parents,
      palette = palette,
      add = add,
      reorder = reorder,
      alternate_lightness = alternate_lightness,
      lightness_amount = lightness_amount,
      l_range = l_range,
      on_duplicate = on_duplicate
    )
  }

  pal <- .pq_new_palette(
    built$colors,
    slot = "sam_data",
    var = var,
    parent = nested,
    parent_colors = built$parent_colors,
    leaf_parents = built$leaf_parents,
    add = add
  )

  if (!add_to_phyloseq) {
    return(pal)
  }

  physeq <- .pq_write_color_col(
    physeq,
    var,
    built$colors,
    "sam_data",
    suffix,
    force
  )
  if (!is.null(nested)) {
    physeq <- .pq_write_color_col(
      physeq,
      nested,
      c(built$parent_colors, add),
      "sam_data",
      suffix,
      force
    )
  }
  physeq
}

#' A single-hue lightness ramp for ordered variables
#'
#' The hue comes from the first colour of the resolved palette, so a
#' sequential scale stays inside the IdEst house style rather than
#' introducing an unrelated blue. Pass a single hex value as `palette` to
#' choose the hue explicitly.
#'
#' @param n (integer, required) Number of levels.
#' @param palette (character, required) Passed to [.pq_resolve_palette()];
#'   only its first colour is used.
#' @param l_range (numeric, required) Lightness bounds of the ramp.
#'
#' @return A character vector of `n` hex colours, darkest first.
#' @noRd
.pq_sequential_oklch <- function(n, palette, l_range) {
  base <- .pq_resolve_palette(1, palette, quiet = TRUE)
  .pq_gradient_oklch(
    base,
    positions = seq_len(n),
    n_total = n,
    l_range = l_range
  )
}
