################################################################################
# Slot-agnostic engine behind palette_tax_pq() and palette_sam_pq().
#
# The unit of exchange is a named character vector: level -> hex. Because
# ggplot2 matches manual scales by name, such a vector is inherently robust to
# subsetting - a plot showing 3 of 12 levels simply consumes 3 of the 12
# entries. That is what makes one anchoring usable across a whole document.
################################################################################

# Colourblind-safe IdEst palettes, smallest first. `palette = "auto"` walks
# this ladder and falls through to the OKLCH generator when no curated palette
# is large enough.
.pq_auto_ladder <- c(
  Hokusai3 = 6,
  Levine2 = 7,
  Rattner = 8,
  Picabia = 11
)

# How many leaves one parent's lightness ramp can carry before its shades stop
# being distinguishable. See the note in .pq_palette_engine().
.pq_max_leaves_per_parent <- 7

#' Resolve the `palette` argument to n concrete colours
#'
#' @param n (integer, required) Number of colours needed.
#' @param palette (character, default `"auto"`) `"auto"` walks
#'   [.pq_auto_ladder] then falls back to OKLCH; `"oklch"` forces the
#'   generator; a name in [idest_pal] forces that palette; any other character
#'   vector is taken as the colours themselves.
#' @param quiet (logical, default `FALSE`) Suppress the message naming the
#'   palette that was chosen.
#'
#' @return A character vector of `n` hex colours.
#' @noRd
.pq_resolve_palette <- function(n, palette = "auto", quiet = FALSE) {
  if (length(palette) > 1) {
    if (length(palette) < n) {
      cli::cli_abort(
        "{.arg palette} supplies {length(palette)} colour{?s} but {n} {?is/are} needed."
      )
    }
    return(as.character(palette[seq_len(n)]))
  }

  if (identical(palette, "auto")) {
    fits <- names(.pq_auto_ladder)[.pq_auto_ladder >= n]
    if (length(fits) > 0) {
      chosen <- fits[1]
      if (!quiet) {
        cli::cli_inform(
          "Using the colourblind-safe {.val {chosen}} IdEst palette for {n} level{?s}."
        )
      }
      return(as.character(idest_colors(chosen, n = n, type = "discrete")))
    }
    if (!quiet) {
      cli::cli_inform(
        "No curated IdEst palette holds {n} colours; generating them in OKLCH."
      )
    }
    return(.pq_pal_oklch(n))
  }

  if (identical(palette, "oklch")) {
    return(.pq_pal_oklch(n))
  }

  if (palette %in% names(idest_pal)) {
    available <- length(idest_pal[[palette]][[1]])
    if (n > available) {
      cli::cli_abort(c(
        "x" = "Palette {.val {palette}} holds {available} colours, but {n} are needed.",
        "i" = "Use {.code palette = \"oklch\"} or lower {.arg n}."
      ))
    }
    return(as.character(idest_colors(palette, n = n, type = "discrete")))
  }

  # A single colour is a legitimate palette when only one level is present.
  as.character(palette)[seq_len(n)]
}

#' Weight of every level of a taxonomic rank
#'
#' One number per level, used both to pick the levels that get a colour and to
#' order them.
#'
#' @param physeq (phyloseq, required) The object to measure.
#' @param rank (character, required) A name from `rank_names(physeq)`.
#' @param metric (character, required) `"abundance"` (total reads),
#'   `"n_taxa"` (number of taxa carrying the level), `"mean"` (reads per
#'   sample) or `"prevalence"` (number of samples where present).
#'
#' @return A named numeric vector, one element per non-missing level.
#' @noRd
.pq_tax_weight <- function(physeq, rank, metric) {
  metric <- rlang::arg_match0(
    metric,
    c("abundance", "n_taxa", "mean", "prevalence")
  )
  levels_vec <- as.character(physeq@tax_table@.Data[, rank])

  weight <- switch(
    metric,
    abundance = phyloseq::taxa_sums(physeq),
    mean = phyloseq::taxa_sums(physeq) / phyloseq::nsamples(physeq),
    prevalence = {
      mat <- as(phyloseq::otu_table(physeq), "matrix")
      if (!phyloseq::taxa_are_rows(physeq)) {
        mat <- t(mat)
      }
      rowSums(mat > 0)
    },
    n_taxa = rep(1, length(levels_vec))
  )

  keep <- !is.na(levels_vec)
  if (!any(keep)) {
    return(stats::setNames(numeric(0), character(0)))
  }
  agg <- tapply(weight[keep], levels_vec[keep], sum)
  stats::setNames(as.numeric(agg), names(agg))
}

#' Pick the levels of a taxonomic rank that deserve a colour
#'
#' Ties are broken alphabetically so that the selection - and therefore which
#' levels end up grey - does not depend on the row order of the object.
#'
#' @param physeq (phyloseq, required) The object to rank.
#' @param rank (character, required) A name from `rank_names(physeq)`.
#' @param n (integer, default `NULL`) How many levels to keep. `NULL` keeps
#'   every level, in which case `by` is never consulted.
#' @param by (character, default `"abundance"`) A metric from
#'   [.pq_tax_weight()]. Only reached when `n` filters.
#'
#' @return A character vector of at most `n` level names, heaviest first.
#'   `NA` levels are never returned: they are handled by the reserved colours.
#' @noRd
.pq_tax_top <- function(physeq, rank, n = NULL, by = "abundance") {
  if (is.null(n)) {
    # Nothing to rank: every level is kept, so the metric is irrelevant and
    # asking for one that does not exist should not fail here.
    levels_vec <- as.character(physeq@tax_table@.Data[, rank])
    return(sort(unique(levels_vec[!is.na(levels_vec)])))
  }
  agg <- .pq_tax_weight(physeq, rank, by)
  if (length(agg) == 0) {
    return(character(0))
  }
  utils::head(names(agg)[order(-agg, names(agg))], n)
}

#' Order a set of levels for colour assignment
#'
#' Selection and ordering are deliberately separate. Selection keeps the
#' levels worth colouring - normally the abundant ones - while ordering
#' decides which colour each gets and how the legend reads. Alphabetical
#' ordering is the default because it does not move when abundances change,
#' so the same taxon keeps the same colour across datasets.
#'
#' @param physeq (phyloseq, required) The object to measure.
#' @param rank (character, required) A name from `rank_names(physeq)`.
#' @param levels (character, required) The levels to order.
#' @param order_by (character, required) `"alpha"`, `"abundance"` (molecular
#'   abundance) or `"n_taxa"` (number of taxa carrying the level).
#'
#' @return `levels`, reordered.
#' @noRd
.pq_tax_order <- function(physeq, rank, levels, order_by) {
  order_by <- rlang::arg_match0(order_by, c("alpha", "abundance", "n_taxa"))
  if (identical(order_by, "alpha")) {
    return(sort(levels))
  }
  agg <- .pq_tax_weight(physeq, rank, order_by)[levels]
  levels[order(-agg, levels)]
}

#' Order the levels of a sample variable
#'
#' @param physeq (phyloseq, required) The object to read.
#' @param var (character, required) A name from `sample_variables(physeq)`.
#' @param order_by (character, default `"levels"`) `"levels"` follows the
#'   variable's own order: the declared levels of a factor, the numeric order
#'   of a numeric column, alphabetical otherwise. `"frequency"` sorts by
#'   decreasing sample count. `"alpha"` always sorts alphabetically, which for
#'   a numeric column means `10` before `5`.
#'
#' @return A character vector of level names, `NA` excluded.
#' @noRd
.pq_sam_levels <- function(physeq, var, order_by = "levels") {
  order_by <- rlang::arg_match0(order_by, c("levels", "frequency", "alpha"))
  values <- as(phyloseq::sample_data(physeq), "data.frame")[[var]]

  if (identical(order_by, "levels")) {
    if (is.factor(values)) {
      lv <- levels(values)
      return(lv[lv %in% as.character(values)])
    }
    if (is.numeric(values)) {
      # Sorting the character form would put 10 before 5 and scramble the
      # sequential ramp this ordering exists to feed.
      return(as.character(sort(unique(values[!is.na(values)]))))
    }
  }

  present <- as.character(values)
  present <- present[!is.na(present)]
  if (identical(order_by, "frequency")) {
    tab <- table(present)
    return(names(tab)[order(-as.integer(tab), names(tab))])
  }
  sort(unique(present))
}

#' Parent level of each leaf level
#'
#' A leaf normally sits under a single parent, but inconsistent taxonomies,
#' missing ranks and free-text sample variables all produce leaves spanning
#' several parents. The most frequent parent wins, and the ambiguity is
#' reported rather than silently resolved.
#'
#' @param df (data.frame, required) A slot rendered by [.pq_slot_df()].
#' @param var (character, required) The leaf column.
#' @param parent_var (character, required) The parent column.
#' @param levels (character, required) Leaf levels to resolve.
#'
#' @return A character vector of parent names, same length as `levels`.
#' @noRd
.pq_parents_of <- function(df, var, parent_var, levels) {
  ambiguous <- character(0)

  out <- vapply(
    levels,
    function(lv) {
      par <- as.character(df[[parent_var]])[as.character(df[[var]]) %in% lv]
      par <- par[!is.na(par)]
      if (length(par) == 0) {
        return(NA_character_)
      }
      tab <- table(par)
      if (length(tab) > 1) {
        ambiguous <<- c(ambiguous, lv)
      }
      names(tab)[which.max(tab)]
    },
    character(1)
  )

  if (length(ambiguous) > 0) {
    cli::cli_warn(c(
      "!" = "{length(ambiguous)} level{?s} of {.val {var}} span{?s/} several {.val {parent_var}} values: {.val {ambiguous}}.",
      "i" = "The most frequent parent was used for each."
    ))
  }
  unname(out)
}

#' Disambiguate leaf names that occur under several parents
#'
#' Leaf keys are short and readable, but a leaf name is not guaranteed unique
#' across parents - `Incertae_sedis` under two phyla is the common case.
#'
#' @param levels (character, required) Leaf names.
#' @param parents (character, required) Parent of each leaf, same length.
#' @param on_duplicate (character, required) `"parent"` appends the parent in
#'   parentheses to the duplicated entries only; `"first"` keeps the first
#'   occurrence and drops the rest; `"error"` aborts.
#'
#' @return A character vector of keys, or a list with `keys` and `drop` when
#'   `on_duplicate = "first"` removes entries.
#' @noRd
.pq_dedup_levels <- function(levels, parents, on_duplicate) {
  on_duplicate <- rlang::arg_match0(on_duplicate, c("parent", "first", "error"))
  dup <- duplicated(levels) | duplicated(levels, fromLast = TRUE)
  if (!any(dup)) {
    return(list(keys = levels, keep = rep(TRUE, length(levels))))
  }

  offenders <- unique(levels[dup])
  if (identical(on_duplicate, "error")) {
    cli::cli_abort(c(
      "x" = "{length(offenders)} leaf name{?s} occur{?s/} under several parents: {.val {offenders}}.",
      "i" = "Use {.code on_duplicate = \"parent\"} to disambiguate them, or {.code \"first\"} to drop the repeats."
    ))
  }

  if (identical(on_duplicate, "first")) {
    keep <- !duplicated(levels)
    cli::cli_warn(
      "Dropped {sum(!keep)} repeated leaf name{?s}: {.val {offenders}}."
    )
    return(list(keys = levels, keep = keep))
  }

  keys <- levels
  keys[dup] <- paste0(levels[dup], " (", parents[dup], ")")
  list(keys = keys, keep = rep(TRUE, length(levels)))
}

#' Build a named colour vector from levels, flat or nested
#'
#' @param levels (character, required) Level names, most important first.
#' @param parents (character, default `NULL`) Parent of each level. When
#'   supplied, hue encodes the parent and lightness the rank of the level
#'   within its parent.
#' @param palette (character, default `"auto"`) Passed to
#'   [.pq_resolve_palette()]. In the nested case it colours the *parents*.
#' @param add (character, default `c(other = "grey85")`) Reserved entries
#'   appended after the levels.
#' @param reorder,alternate_lightness,lightness_amount Passed to
#'   [.pq_reorder_colors_vec()]. `reorder` is refused in the nested case: the
#'   permutation maximises contrast between consecutive levels, which is
#'   exactly the parent grouping the nesting exists to show.
#' @param l_range (numeric, default `c(0.35, 0.82)`) Lightness bounds of each
#'   parent's gradient.
#' @param on_duplicate (character, default `"parent"`) See
#'   [.pq_dedup_levels()].
#' @param quiet (logical, default `FALSE`) Suppress palette-choice messages.
#'
#' @return A list with `colors` (the named vector, reserved entries included),
#'   `parent_colors` (named vector, or `NULL` when flat) and `leaf_parents`
#'   (the parent of each key, or `NULL` when flat).
#' @noRd
.pq_palette_engine <- function(
  levels,
  parents = NULL,
  palette = "auto",
  add = c(other = "grey85"),
  reorder = FALSE,
  alternate_lightness = FALSE,
  lightness_amount = 0.15,
  l_range = c(0.35, 0.82),
  on_duplicate = "parent",
  quiet = FALSE
) {
  if (!is.null(add) && length(add) > 0 && is.null(names(add))) {
    cli::cli_abort("{.arg add} must be a named vector of colours.")
  }

  if (is.null(parents)) {
    if (length(levels) == 0) {
      return(list(colors = add, parent_colors = NULL, leaf_parents = NULL))
    }
    cols <- .pq_resolve_palette(length(levels), palette, quiet = quiet)
    named <- stats::setNames(cols, levels)
    # Two independent effects: the permutation maximises contrast between
    # consecutive levels, the alternation adds a luminance cue on top. Either
    # can be asked for on its own.
    if (reorder) {
      named <- .pq_reorder_colors_vec(named, space = "oklch")
    }
    if (alternate_lightness) {
      named <- stats::setNames(
        .pq_alternate_lightness(unname(named), lightness_amount, "oklch"),
        names(named)
      )
    }
    return(list(
      colors = c(named, add),
      parent_colors = NULL,
      leaf_parents = NULL
    ))
  }

  if (reorder || alternate_lightness) {
    offender <- if (reorder) "reorder" else "alternate_lightness"
    cli::cli_abort(c(
      "x" = "{.arg {offender}} cannot be combined with a nested palette.",
      "i" = "Nesting encodes the parent in the hue and the leaf in the lightness; both options overwrite one of those channels."
    ))
  }
  if (length(parents) != length(levels)) {
    cli::cli_abort(
      "{.arg parents} has length {length(parents)} but {.arg levels} has length {length(levels)}."
    )
  }
  if (length(levels) == 0) {
    return(list(colors = add, parent_colors = NULL, leaf_parents = NULL))
  }

  parents <- as.character(parents)
  parents[is.na(parents)] <- "NA"

  dedup <- .pq_dedup_levels(levels, parents, on_duplicate)
  keys <- dedup$keys[dedup$keep]
  parents <- parents[dedup$keep]

  parent_levels <- unique(parents)
  parent_cols <- stats::setNames(
    .pq_resolve_palette(length(parent_levels), palette, quiet = quiet),
    parent_levels
  )

  # Each parent's leaves are told apart by lightness alone. `l_range` spans
  # about 0.47, and two OKLCH lightnesses need roughly 0.07 between them to be
  # told apart, so a parent holding more than ~7 leaves produces a ramp nobody
  # can read. Unbalanced taxonomies hit this constantly: 19 of the 20 Families
  # of `data_fungi_mini` sit in a single Class.
  max_leaves <- .pq_max_leaves_per_parent
  crowded <- table(parents)
  crowded <- crowded[crowded > max_leaves]
  if (length(crowded) > 0 && !quiet) {
    counts <- as.integer(crowded)
    cli::cli_warn(c(
      "!" = "{length(crowded)} parent{?s} hold{?s/} more than {max_leaves} leaves: {.val {names(crowded)}} ({counts}).",
      "i" = "Their shades will be hard to tell apart. Lower {.arg n}, or nest under a finer parent rank."
    ))
  }

  out <- character(length(keys))
  for (p in parent_levels) {
    idx <- which(parents == p)
    out[idx] <- .pq_gradient_oklch(
      parent_cols[[p]],
      positions = seq_along(idx),
      n_total = length(idx),
      l_range = l_range
    )
  }

  list(
    colors = c(stats::setNames(out, keys), add),
    parent_colors = parent_cols,
    leaf_parents = stats::setNames(parents, keys)
  )
}

# ---- colour columns ----------------------------------------------------------

#' Name of the colour column for a variable
#'
#' @param var (character, required) Rank or sample-variable name.
#' @param suffix (character, required) Suffix appended to `var`.
#'
#' @return A single string.
#' @noRd
.pq_color_col <- function(var, suffix) {
  if (!is.character(suffix) || length(suffix) != 1 || is.na(suffix)) {
    cli::cli_abort("{.arg suffix} must be a single string.")
  }
  if (!startsWith(suffix, "_color")) {
    cli::cli_warn(c(
      "!" = "{.arg suffix} {.val {suffix}} does not start with {.val _color}.",
      "i" = "{.fn show_palette_pq} discovers palettes by that prefix and will miss this column."
    ))
  }
  paste0(var, suffix)
}

#' Which slot holds a variable?
#'
#' @param physeq (phyloseq, required) The object to search.
#' @param var (character, required) Rank or sample-variable name.
#'
#' @return `"tax_table"` or `"sam_data"`.
#' @noRd
.pq_slot_for_var <- function(physeq, var) {
  in_tax <- !is.null(physeq@tax_table) && var %in% phyloseq::rank_names(physeq)
  in_sam <- !is.null(physeq@sam_data) &&
    var %in% phyloseq::sample_variables(physeq)

  if (in_tax && in_sam) {
    cli::cli_abort(c(
      "x" = "{.val {var}} exists in both {.code tax_table} and {.code sam_data}.",
      "i" = "Call {.fn palette_tax_pq} or {.fn palette_sam_pq} directly to disambiguate."
    ))
  }
  if (in_tax) {
    return("tax_table")
  }
  if (in_sam) {
    return("sam_data")
  }
  cli::cli_abort(
    "{.val {var}} is neither a taxonomic rank nor a sample variable of {.arg physeq}."
  )
}

#' Read a slot as a plain data.frame
#'
#' @param physeq (phyloseq, required) The object to read.
#' @param slot (character, required) `"tax_table"` or `"sam_data"`.
#'
#' @return A data.frame with the slot's rownames.
#' @noRd
.pq_slot_df <- function(physeq, slot) {
  if (identical(slot, "tax_table")) {
    return(as.data.frame(
      physeq@tax_table@.Data,
      stringsAsFactors = FALSE
    ))
  }
  as(phyloseq::sample_data(physeq), "data.frame")
}

#' Write a colour column into tax_table or sam_data
#'
#' Every row gets a colour, including those whose level is not in `colors`:
#' they take the reserved `other` entry. The column is therefore self
#' sufficient, and survives `subset_taxa()` / `subset_samples()` because it
#' travels with the rows it describes.
#'
#' @param physeq (phyloseq, required) The object to modify.
#' @param var (character, required) Rank or sample-variable name.
#' @param colors (character, required) Named palette vector.
#' @param slot (character, required) `"tax_table"` or `"sam_data"`.
#' @param suffix (character, required) Column-name suffix.
#' @param force (logical, required) Overwrite an existing column.
#'
#' @return The modified phyloseq object.
#' @noRd
.pq_write_color_col <- function(physeq, var, colors, slot, suffix, force) {
  col <- .pq_color_col(var, suffix)
  df <- .pq_slot_df(physeq, slot)

  if (col %in% colnames(df) && !force) {
    cli::cli_abort(c(
      "x" = "Column {.field {col}} already exists in {.code {slot}}.",
      "i" = "Use {.code suffix = \"{suffix}_<name>\"} to add a second palette alongside it.",
      "i" = "Or {.code force = TRUE} to overwrite it."
    ))
  }
  if (col %in% colnames(df) && force) {
    cli::cli_warn(
      "Overwriting {.field {col}}, which held {length(unique(df[[col]]))} distinct colour{?s}."
    )
  }

  other <- if ("other" %in% names(colors)) {
    unname(colors[["other"]])
  } else {
    "grey85"
  }
  na_col <- if ("NA" %in% names(colors)) {
    unname(colors[["NA"]])
  } else {
    other
  }

  values <- as.character(df[[var]])
  out <- unname(colors[values])
  out[is.na(values)] <- na_col
  out[is.na(out)] <- other

  if (identical(slot, "tax_table")) {
    df[[col]] <- out
    phyloseq::tax_table(physeq) <- phyloseq::tax_table(as.matrix(df))
  } else {
    phyloseq::sample_data(physeq)[[col]] <- out
  }
  physeq
}

#' Read a palette back from a colour column
#'
#' @param physeq (phyloseq, required) The object to read.
#' @param var (character, required) Rank or sample-variable name.
#' @param slot (character, required) `"tax_table"` or `"sam_data"`.
#' @param suffix (character, required) Column-name suffix.
#'
#' The returned vector maps only the levels actually present: it carries no
#' synthetic `other` entry. Reserved colours cannot be recovered from the
#' column, because a level folded into `other` is indistinguishable from a
#' level that was simply given that colour - and when a single minor level
#' exists, as in `data_fungi_mini` at rank Order, there is nothing to detect at
#' all. Callers re-attach their own `add` argument instead, which is both
#' simpler and always right.
#'
#' @return A named character vector of the levels present, or `NULL` when the
#'   column is absent.
#' @noRd
.pq_read_color_col <- function(physeq, var, slot, suffix) {
  col <- paste0(var, suffix)
  df <- .pq_slot_df(physeq, slot)
  if (!col %in% colnames(df)) {
    return(NULL)
  }

  levels_vec <- as.character(df[[var]])
  cols_vec <- as.character(df[[col]])
  keep <- !is.na(levels_vec) & !is.na(cols_vec)
  if (!any(keep)) {
    return(NULL)
  }

  pairs <- unique(data.frame(
    level = levels_vec[keep],
    color = cols_vec[keep],
    stringsAsFactors = FALSE
  ))
  stats::setNames(pairs$color, pairs$level)
}

#' List every colour column an object carries
#'
#' @param physeq (phyloseq, required) The object to inspect.
#'
#' @return A data.frame with columns `slot`, `var`, `suffix` and `column`, one
#'   row per palette found. Zero rows when the object carries none.
#' @noRd
.pq_find_color_cols <- function(physeq) {
  found <- list()
  for (slot in c("tax_table", "sam_data")) {
    present <- if (identical(slot, "tax_table")) {
      !is.null(physeq@tax_table)
    } else {
      !is.null(physeq@sam_data)
    }
    if (!present) {
      next
    }
    nms <- colnames(.pq_slot_df(physeq, slot))
    hits <- grep("_color", nms, fixed = TRUE, value = TRUE)
    for (h in hits) {
      var <- sub("_color.*$", "", h)
      if (!var %in% nms) {
        next
      }
      found[[length(found) + 1]] <- data.frame(
        slot = slot,
        var = var,
        suffix = substring(h, nchar(var) + 1),
        column = h,
        stringsAsFactors = FALSE
      )
    }
  }
  if (length(found) == 0) {
    return(data.frame(
      slot = character(0),
      var = character(0),
      suffix = character(0),
      column = character(0),
      stringsAsFactors = FALSE
    ))
  }
  do.call(rbind, found)
}
