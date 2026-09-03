utils::globalVariables(c(
  "x0",
  "x1",
  "y0",
  "y1",
  "depth",
  "color",
  "name",
  "xmid",
  "ymid",
  "ang",
  "lab",
  "pattern_type",
  "parent_value",
  "numeric_attr",
  "y_anchor",
  "hj",
  "col",
  "hj_side",
  "ang_tang",
  "y_in",
  "y_lab",
  "y0",
  "y1",
  "marker",
  "y_out"
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
    # When named, align to taxa_names() rather than trusting positional order.
    # A names/taxa mismatch is almost always a silent bug, so abort.
    if (!is.null(names(weight_by))) {
      if (!setequal(names(weight_by), tn)) {
        cli::cli_abort(
          c(
            "{.arg weight_by} has names that do not match {.fn taxa_names}.",
            "i" = "Provide an unnamed vector aligned to {.fn taxa_names} order, or names covering exactly the taxa."
          )
        )
      }
      weight_by <- weight_by[tn]
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

# ---- Default to classical ranks when "All" is requested --------------------
# Returns the intersection of standard taxonomic ranks with the available ones.
# Falls back to all available ranks when fewer than 2 classical ranks are found.
.default_ranks <- function(all_ranks) {
  classical <- c(
    "Kingdom",
    "Phylum",
    "Class",
    "Order",
    "Family",
    "Genus",
    "Species"
  )
  found <- classical[classical %in% all_ranks]
  if (length(found) >= 2) {
    found
  } else {
    all_ranks
  }
}

# ---- Nestedness check: warn when a taxon appears under multiple parents -----
.check_nestedness <- function(df, ranks) {
  if (length(ranks) < 2) {
    return(invisible(NULL))
  }
  offenders <- character(0)
  for (i in seq(2, length(ranks))) {
    child_col <- ranks[i]
    parent_col <- ranks[i - 1]
    sub <- df[, c(parent_col, child_col), drop = FALSE]
    sub <- sub[
      !is.na(sub[[child_col]]) &
        sub[[child_col]] != "" &
        !is.na(sub[[parent_col]]) &
        sub[[parent_col]] != "",
      ,
      drop = FALSE
    ]
    if (nrow(sub) == 0) {
      next
    }
    n_parents <- tapply(
      sub[[parent_col]],
      sub[[child_col]],
      function(x) length(unique(x))
    )
    multi <- names(which(n_parents > 1))
    if (length(multi) > 0) {
      head5 <- utils::head(multi, 5)
      suffix <- if (length(multi) > 5) {
        paste0(" ... (", length(multi), " total)")
      } else {
        ""
      }
      offenders <- c(
        offenders,
        paste0(child_col, ": ", paste(head5, collapse = ", "), suffix)
      )
    }
  }
  if (length(offenders) > 0) {
    cli::cli_warn(
      c(
        "!" = "Taxonomy is not strictly nested; the following taxa appear under multiple parents:",
        stats::setNames(offenders, rep("*", length(offenders))),
        "i" = "A non-nested {.fn tax_table} may silently mis-aggregate sections."
      )
    )
  }
  invisible(NULL)
}

# ---- Extend a terminal section down to the deepest rank --------------------
# Builds a chain of identically-named nested nodes from `depth` to `max_depth`
# so that a section that terminates early (an "unassigned" taxon, or an
# aggregated "n more" group) visually fills every remaining ring out to the
# leaf rank. The repeated segments are merged into one borderless wedge with a
# single label at draw time (see `.merge_fill_chains` / the JS renderer).
.fill_chain <- function(
  name,
  value,
  depth,
  max_depth,
  numeric_attr,
  is_aggregate = FALSE
) {
  node <- list(
    name = name,
    value = value,
    depth = depth,
    children = list(),
    numeric_attr = numeric_attr,
    is_aggregate = is_aggregate
  )
  if (depth < max_depth) {
    node$children <- list(
      .fill_chain(name, value, depth + 1, max_depth, numeric_attr, is_aggregate)
    )
  }
  node
}

# ---- Build nested hierarchy from tax_table + weights -----------------------
.build_tax_hierarchy <- function(
  df,
  ranks,
  weights,
  depth,
  add_unassigned_rank,
  numeric_vals = NULL,
  fill_unassigned = TRUE
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
    if (!is.null(numeric_vals)) {
      numeric_vals <- numeric_vals[keep]
    }
    values <- values[keep]
    if (nrow(df) == 0) {
      return(NULL)
    }
  } else {
    values[na_mask] <- "unassigned"
  }

  groups <- split(seq_len(nrow(df)), values, drop = TRUE)

  children <- vector("list", length(groups))
  for (i in seq_along(groups)) {
    gname <- names(groups)[i]
    idx <- groups[[i]]
    sub_w <- weights[idx]
    sub_nv <- if (!is.null(numeric_vals)) numeric_vals[idx] else NULL

    group_numeric <- if (!is.null(sub_nv)) {
      non_na <- !is.na(sub_nv)
      if (any(non_na)) {
        sum(sub_nv[non_na] * sub_w[non_na]) / sum(sub_w[non_na])
      } else {
        NA_real_
      }
    } else {
      NULL
    }

    if (gname == "unassigned" || rank_idx == length(ranks)) {
      if (
        gname == "unassigned" && fill_unassigned && rank_idx < length(ranks)
      ) {
        # Fill the remaining ranks with a chain of "unassigned" nodes so the
        # arc reaches the leaf ring instead of stopping where assignment ended.
        children[[i]] <- .fill_chain(
          "unassigned",
          as.numeric(sum(sub_w)),
          depth + 1,
          length(ranks),
          group_numeric,
          is_aggregate = FALSE
        )
      } else {
        children[[i]] <- list(
          name = gname,
          value = as.numeric(sum(sub_w)),
          depth = depth + 1,
          children = list(),
          numeric_attr = group_numeric,
          is_aggregate = FALSE
        )
      }
    } else {
      sub <- .build_tax_hierarchy(
        df[idx, , drop = FALSE],
        ranks,
        sub_w,
        depth + 1,
        add_unassigned_rank,
        sub_nv,
        fill_unassigned
      )
      if (is.null(sub)) {
        children[[i]] <- list(
          name = gname,
          value = as.numeric(sum(sub_w)),
          depth = depth + 1,
          children = list(),
          numeric_attr = group_numeric,
          is_aggregate = FALSE
        )
      } else {
        sub$name <- gname
        sub$numeric_attr <- group_numeric
        children[[i]] <- sub
      }
    }
  }

  children <- children[!vapply(children, is.null, logical(1))]
  if (length(children) == 0) {
    return(NULL)
  }
  total <- sum(vapply(children, function(x) x$value, numeric(1)))

  total_numeric <- if (!is.null(numeric_vals)) {
    w_vals <- vapply(children, function(x) x$value, numeric(1))
    n_vals <- vapply(
      children,
      function(x) {
        if (!is.null(x$numeric_attr) && !is.na(x$numeric_attr)) {
          x$numeric_attr
        } else {
          NA_real_
        }
      },
      numeric(1)
    )
    non_na <- !is.na(n_vals)
    if (any(non_na)) {
      sum(n_vals[non_na] * w_vals[non_na]) / sum(w_vals[non_na])
    } else {
      NA_real_
    }
  } else {
    NULL
  }

  list(
    name = "node",
    value = total,
    depth = depth,
    children = children,
    numeric_attr = total_numeric,
    is_aggregate = FALSE
  )
}

# ---- Collapse uninformative single-child levels ----------------------------
# Removes internal nodes with exactly one child that itself has children.
# Leaf nodes are always kept. The layout functions use the passed depth
# parameter (not node$depth), so depths auto-correct after collapsing.
# Each surviving node records `collapsed_path`: the names of the ancestor
# ranks that were skipped to reach it (top-down, excluding its own name), so
# the full taxonomic path can be shown when `show_collapsed_path = TRUE`.
# Prepend the genus initial to each species-rank name ("muscaria" ->
# "A. muscaria"). `sp_depth` is the 1-based rank index of the "Species" rank;
# `parent_name` is the (unabbreviated) name of the node's parent, i.e. the
# genus for a species node. Placeholder parents/names ("unassigned") and names
# that already carry an initial are left untouched.
.abbrev_species_names <- function(node, sp_depth, parent_name = NULL) {
  is_species <- isTRUE(node$depth == sp_depth)
  if (
    is_species &&
      !is.null(parent_name) &&
      !is.na(parent_name) &&
      nzchar(parent_name) &&
      parent_name != "unassigned" &&
      !is.na(node$name) &&
      nzchar(node$name) &&
      node$name != "unassigned" &&
      !grepl("^[A-Za-z]\\. ", node$name)
  ) {
    node$name <- paste0(toupper(substr(parent_name, 1, 1)), ". ", node$name)
  }
  if (length(node$children) > 0) {
    node$children <- lapply(
      node$children,
      function(child) .abbrev_species_names(child, sp_depth, node$name)
    )
  }
  node
}

# Attach a `size_mult` (font-size multiplier) to every node. Three forms of
# `label_size` are supported, dispatched in `krona_like_pq()`:
#   * scalar        -> every node gets the same multiplier.
#   * one per rank  -> a node at rank depth `d` gets `sizes[d]`.
#   * one per taxon -> each leaf's multiplier is the mean of its constituent
#     taxa's values (positional, `taxa_names()` order); each internal node's is
#     the mean of all its descendant leaves' multipliers.
.assign_size_scalar <- function(node, mult) {
  node$size_mult <- mult
  if (length(node$children) > 0) {
    node$children <- lapply(node$children, function(ch) {
      .assign_size_scalar(ch, mult)
    })
  }
  node
}

.assign_size_by_rank <- function(node, sizes) {
  d <- node$depth
  node$size_mult <- if (!is.null(d) && d >= 1 && d <= length(sizes)) {
    sizes[d]
  } else {
    1
  }
  if (length(node$children) > 0) {
    node$children <- lapply(node$children, function(ch) {
      .assign_size_by_rank(ch, sizes)
    })
  }
  node
}

# Returns list(node = <node with size_mult set>, leaves = <descendant-leaf
# multipliers>). `path` is the sequence of rank values from the root down to
# (and including) this node, used to select the taxa that fall in a leaf.
.assign_size_by_taxon <- function(node, tt_norm, ranks, sizes, path) {
  if (length(node$children) == 0) {
    keep <- rep(TRUE, nrow(tt_norm))
    for (i in seq_along(path)) {
      keep <- keep & (tt_norm[[ranks[i]]] == path[i])
    }
    vals <- sizes[keep]
    sz <- if (length(vals) > 0) mean(vals, na.rm = TRUE) else NA_real_
    node$size_mult <- sz
    return(list(node = node, leaves = if (is.na(sz)) numeric(0) else sz))
  }
  all_leaves <- numeric(0)
  node$children <- lapply(node$children, function(ch) {
    res <- .assign_size_by_taxon(ch, tt_norm, ranks, sizes, c(path, ch$name))
    all_leaves <<- c(all_leaves, res$leaves)
    res$node
  })
  node$size_mult <- if (length(all_leaves) > 0) mean(all_leaves) else NA_real_
  list(node = node, leaves = all_leaves)
}

.collapse_single_children <- function(node) {
  if (length(node$children) == 0) {
    return(node)
  }
  node$children <- lapply(node$children, .collapse_single_children)
  new_children <- list()
  for (child in node$children) {
    only_child <- if (length(child$children) == 1) {
      child$children[[1]]
    } else {
      NULL
    }
    # Collapse single-child internal nodes, but never an identically-named
    # fill chain (e.g. unassigned/unassigned/...), which must keep spanning to
    # the leaf ring.
    if (
      !is.null(only_child) &&
        length(only_child$children) > 0 &&
        !identical(only_child$name, child$name)
    ) {
      only_child$collapsed_path <- c(
        child$collapsed_path,
        child$name,
        only_child$collapsed_path
      )
      new_children <- c(new_children, list(only_child))
    } else {
      new_children <- c(new_children, list(child))
    }
  }
  node$children <- new_children
  node
}

# ---- Merge low-abundance siblings into an "n more" aggregate ---------------
# When a section's proportion of its parent falls below min_prop, it is merged
# with other small siblings into a single "{n} more" node. Only merges when at
# least 2 siblings are below the threshold. When `fill` is TRUE the aggregate
# is extended as a chain out to `max_depth` (the leaf rank), matching
# `fill_unassigned`, so the whole circle is filled.
.merge_low_abundance <- function(
  node,
  min_prop,
  max_depth = NULL,
  fill = TRUE
) {
  if (length(node$children) == 0) {
    return(node)
  }
  node$children <- lapply(node$children, function(child) {
    .merge_low_abundance(child, min_prop, max_depth, fill)
  })
  total <- sum(vapply(node$children, function(x) x$value, numeric(1)))
  if (total <= 0) {
    return(node)
  }
  keep <- list()
  small <- list()
  for (child in node$children) {
    if (child$value / total < min_prop) {
      small <- c(small, list(child))
    } else {
      keep <- c(keep, list(child))
    }
  }
  if (length(small) >= 2) {
    small_total <- sum(vapply(small, function(x) x$value, numeric(1)))
    agg_name <- paste0(length(small), " more")
    agg_depth <- node$depth + 1
    if (fill && !is.null(max_depth) && agg_depth < max_depth) {
      aggregate <- .fill_chain(
        agg_name,
        as.numeric(small_total),
        agg_depth,
        max_depth,
        NULL,
        is_aggregate = TRUE
      )
    } else {
      aggregate <- list(
        name = agg_name,
        value = as.numeric(small_total),
        depth = agg_depth,
        children = list(),
        numeric_attr = NULL,
        is_aggregate = TRUE
      )
    }
    keep <- c(keep, list(aggregate))
  } else {
    keep <- c(keep, small)
  }
  node$children <- keep
  node
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

# ---- Wide-spread palette: siblings fan across a hue band -------------------
.krona_palette <- function(
  node,
  color_depth,
  hue_map,
  hue = NULL,
  band = 360,
  L = 0.58,
  depth = 0
) {
  if (depth < color_depth) {
    node$color <- "#cfcfcf"
    for (i in seq_along(node$children)) {
      node$children[[i]] <- .krona_palette(
        node$children[[i]],
        color_depth,
        hue_map,
        hue = NULL,
        band = 360,
        L = L,
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
    k <- length(hue_map)
    band <- if (k <= 1) {
      320
    } else {
      (360 / k) * 0.82
    }
  }
  node$color <- .hsl_to_hex(hue, 0.7, max(0.42, min(0.66, L)))
  n <- length(node$children)
  if (n > 0) {
    child_band <- band * 0.72
    l_child <- max(0.42, min(0.66, L - 0.03))
    for (i in seq_len(n)) {
      frac <- if (n == 1) {
        0
      } else {
        (i - 1) / (n - 1) - 0.5
      }
      node$children[[i]] <- .krona_palette(
        node$children[[i]],
        color_depth,
        hue_map,
        hue = hue + frac * child_band,
        band = child_band,
        L = l_child,
        depth = depth + 1
      )
    }
  }
  node
}

# ---- Gradient palette for numeric color_by attributes ----------------------
# Maps each node's numeric_attr to a continuous colour via scale_fn.
.krona_gradient_palette <- function(node, scale_fn, depth = 0) {
  if (!is.null(node$numeric_attr) && !is.na(node$numeric_attr)) {
    node$color <- scale_fn(node$numeric_attr)
  } else {
    node$color <- "#cfcfcf"
  }
  if (length(node$children) > 0) {
    node$children <- lapply(node$children, function(child) {
      .krona_gradient_palette(child, scale_fn, depth + 1)
    })
  }
  node
}

# ---- Override colors for nodes matching grey_terms -------------------------
.krona_grey_terms <- function(node, grey_terms) {
  na_in_terms <- any(is.na(grey_terms))
  str_terms <- grey_terms[!is.na(grey_terms)]
  name_is_na <- is.null(node$name) || is.na(node$name)
  if (
    (name_is_na && na_in_terms) || (!name_is_na && node$name %in% str_terms)
  ) {
    node$color <- "#c8c8c8"
  }
  if (length(node$children) > 0) {
    node$children <- lapply(node$children, function(child) {
      .krona_grey_terms(child, grey_terms)
    })
  }
  node
}

# ---- Attach per-rank color options to every node for the JS color selector --
# Walks `node` and a parallel list of same-structure colored hierarchies in
# lock-step, storing a named list `colorsByRank` on each node.
.add_color_options <- function(node, colored_list) {
  node$colorsByRank <- lapply(colored_list, function(cn) cn$color)
  if (length(node$children) > 0) {
    for (i in seq_along(node$children)) {
      sub_colored <- lapply(colored_list, function(cn) {
        if (i <= length(cn$children)) cn$children[[i]] else cn
      })
      node$children[[i]] <- .add_color_options(node$children[[i]], sub_colored)
    }
  }
  node
}

# ---- Flatten hierarchy to a data.frame of arcs (sunburst) ------------------
.flatten_hierarchy <- function(
  node,
  x0,
  x1,
  depth,
  rows,
  parent_value = NA_real_
) {
  rows[[length(rows) + 1]] <- list(
    name = node$name,
    value = node$value,
    depth = depth,
    x0 = x0,
    x1 = x1,
    color = if (is.null(node$color)) NA_character_ else node$color,
    numeric_attr = if (
      is.null(node$numeric_attr) || length(node$numeric_attr) == 0
    ) {
      NA_real_
    } else {
      node$numeric_attr
    },
    is_aggregate = isTRUE(node$is_aggregate),
    parent_value = parent_value,
    size_mult = if (is.null(node$size_mult) || length(node$size_mult) == 0) {
      NA_real_
    } else {
      node$size_mult
    },
    collapsed_path = if (is.null(node$collapsed_path)) {
      NA_character_
    } else {
      paste(node$collapsed_path, collapse = " / ")
    }
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
    rows <- .flatten_hierarchy(
      k,
      cum,
      cx1,
      depth + 1,
      rows,
      parent_value = node$value
    )
    cum <- cx1
  }
  rows
}

# ---- Recursive slice-and-dice treemap layout (no dep) ----------------------
.layout_treemap <- function(
  node,
  x0,
  x1,
  y0,
  y1,
  depth,
  rows,
  horizontal,
  parent_value = NA_real_
) {
  rows[[length(rows) + 1]] <- list(
    name = node$name,
    value = node$value,
    depth = depth,
    x0 = x0,
    x1 = x1,
    y0 = y0,
    y1 = y1,
    leaf = length(node$children) == 0,
    color = if (is.null(node$color)) NA_character_ else node$color,
    numeric_attr = if (
      is.null(node$numeric_attr) || length(node$numeric_attr) == 0
    ) {
      NA_real_
    } else {
      node$numeric_attr
    },
    is_aggregate = isTRUE(node$is_aggregate),
    parent_value = parent_value,
    size_mult = if (is.null(node$size_mult) || length(node$size_mult) == 0) {
      NA_real_
    } else {
      node$size_mult
    },
    collapsed_path = if (is.null(node$collapsed_path)) {
      NA_character_
    } else {
      paste(node$collapsed_path, collapse = " / ")
    }
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
      rows <- .layout_treemap(
        k,
        cum,
        nx1,
        y0,
        y1,
        depth + 1,
        rows,
        FALSE,
        parent_value = node$value
      )
      cum <- nx1
    }
  } else {
    cum <- y0
    for (k in kids) {
      ny1 <- cum + (y1 - y0) * (k$value / total)
      rows <- .layout_treemap(
        k,
        x0,
        x1,
        cum,
        ny1,
        depth + 1,
        rows,
        TRUE,
        parent_value = node$value
      )
      cum <- ny1
    }
  }
  rows
}

# ---- Helpers for the static path -------------------------------------------

# Shorten a label with a middle ellipsis so both the start and end are visible.
# `n` may be a single cap or one cap per element of `x`.
.truncate_label_middle <- function(x, n = 24) {
  n <- rep_len(n, length(x))
  long <- !is.na(x) & nchar(x) > n
  if (any(long)) {
    xl <- x[long]
    half <- pmax(1L, floor((n[long] - 3) / 2))
    x[long] <- paste0(
      substr(xl, 1, half),
      "...",
      substr(xl, nchar(xl) - half + 1, nchar(xl))
    )
  }
  x
}

# Truncate arc-following labels to the number of characters that fit their arc.
# `avail_chars` is the per-label room (arc length / per-character width). Labels
# that already fit are returned unchanged; labels longer than the room are
# middle-truncated ("Stro...aceae") when at least `min_keep` characters of room
# remain, and set to NA (hidden -> fallback marker) when the arc is too narrow
# for even a readable truncation.
.fit_truncate <- function(labels, avail_chars, min_keep = 8L) {
  n_fit <- floor(avail_chars)
  out <- labels
  long <- !is.na(labels) & nchar(labels) > n_fit
  hide <- long & n_fit < min_keep
  trunc <- long & !hide
  if (any(trunc)) {
    out[trunc] <- .truncate_label_middle(labels[trunc], n_fit[trunc])
  }
  out[hide] <- NA_character_
  out
}

# Alternate sections ("one on two") within each ring/level so neighbours can
# be told apart by a subtle motif. Parity is assigned left-to-right per depth.
.alternate_pattern <- function(df) {
  patt <- rep("none", nrow(df))
  for (d in unique(df$depth)) {
    idx <- which(df$depth == d)
    idx <- idx[order(df$x0[idx])]
    patt[idx[seq_along(idx) %% 2 == 0]] <- "dot"
  }
  patt
}

# Rectangle layer with optional dot motif and mandatory crosshatch for aggregate
# "n more" sections (both via ggpattern when available).
.krona_rect_layer <- function(
  df,
  ymin_col,
  ymax_col,
  pattern,
  spacing,
  fill_col = "color"
) {
  has_agg <- "is_aggregate" %in% names(df) && any(df$is_aggregate, na.rm = TRUE)
  needs_ggpattern <- pattern || has_agg

  base_aes <- ggplot2::aes(
    xmin = x0,
    xmax = x1,
    ymin = .data[[ymin_col]],
    ymax = .data[[ymax_col]],
    fill = .data[[fill_col]]
  )

  if (!needs_ggpattern) {
    return(ggplot2::geom_rect(
      data = df,
      mapping = base_aes,
      color = "white",
      linewidth = 0.3
    ))
  }

  if (!requireNamespace("ggpattern", quietly = TRUE)) {
    if (pattern) {
      cli::cli_abort(
        "Package {.pkg ggpattern} is required for {.code pattern = TRUE}. Install it with {.code install.packages('ggpattern')} or use {.code pattern = FALSE}."
      )
    }
    cli::cli_inform(
      c(
        "!" = "Package {.pkg ggpattern} is not installed; {.val n more} aggregate sections will be shown without crosshatch."
      )
    )
    return(ggplot2::geom_rect(
      data = df,
      mapping = base_aes,
      color = "white",
      linewidth = 0.3
    ))
  }

  df$pattern_type <- if (pattern) {
    .alternate_pattern(df)
  } else {
    rep("none", nrow(df))
  }
  if (has_agg) {
    df$pattern_type[df$is_aggregate] <- "crosshatch"
  }

  list(
    ggpattern::geom_rect_pattern(
      data = df,
      mapping = utils::modifyList(
        base_aes,
        ggplot2::aes(pattern = pattern_type)
      ),
      color = "white",
      linewidth = 0.3,
      pattern_fill = "grey20",
      pattern_colour = NA,
      pattern_density = 0.12,
      pattern_spacing = spacing,
      pattern_alpha = 0.55
    ),
    ggpattern::scale_pattern_manual(
      values = c(none = "none", dot = "circle", crosshatch = "crosshatch"),
      guide = "none"
    )
  )
}

# ---- Merge identical fill-chain rows into one spanning rect ----------------
# Runs of identically-named arcs that share the same angular span (the
# unassigned / "n more" fill chains) are collapsed into a single rect spanning
# from the chain's innermost depth out to its outermost, so they render as one
# borderless wedge carrying a single label. Adds `depthmax` (outer radius of
# each rect) and `spanning` (TRUE for merged chain rects).
.merge_fill_chains <- function(df) {
  depthmax <- df$depth + 1
  spanning <- rep(FALSE, nrow(df))
  if (nrow(df) == 0) {
    df$depthmax <- depthmax
    df$spanning <- spanning
    return(df)
  }
  key <- paste(
    formatC(df$x0, format = "f", digits = 10),
    formatC(df$x1, format = "f", digits = 10),
    df$name,
    sep = "\r"
  )
  keep_idx <- integer(0)
  for (k in unique(key)) {
    idx <- which(key == k)
    if (length(idx) == 1) {
      keep_idx <- c(keep_idx, idx)
    } else {
      inner <- idx[which.min(df$depth[idx])]
      depthmax[inner] <- max(df$depth[idx]) + 1
      spanning[inner] <- TRUE
      keep_idx <- c(keep_idx, inner)
    }
  }
  keep_idx <- sort(keep_idx)
  out <- df[keep_idx, , drop = FALSE]
  out$depthmax <- depthmax[keep_idx]
  out$spanning <- spanning[keep_idx]
  out
}

# ---- Thin out radially-oriented labels that would visually collide --------
# Radially-reading labels are anchored at a single point and read outward
# along their own ray; two anchors close together in angle crowd their glyphs,
# because neither is bounded by a wedge wall in the reading direction.
# `min_gap` is a flat angular budget (radians). Collisions are only possible
# between labels that share the same starting radius -- pass `group` (e.g. the
# originating ring/depth) so a parent and child that happen to share almost
# the same angle (a dominant single-child lineage) are never compared, since
# they are drawn on physically different rings and cannot visually collide.
# Greedily keeps the highest-value label first, within each group, so bigger
# sections win crowded neighbourhoods.
.dismiss_overlapping_labels <- function(df, min_gap = 0.26, group = NULL) {
  df$overlap_dismissed <- rep(FALSE, nrow(df))
  if (nrow(df) <= 1) {
    return(df)
  }
  if (is.null(group)) {
    group <- rep(1L, nrow(df))
  }
  ord <- order(-df$value)
  kept_ang <- list()
  keep <- rep(FALSE, nrow(df))
  for (i in ord) {
    g <- as.character(group[i])
    ang_i <- df$xmid[i]
    prev <- kept_ang[[g]]
    ok <- is.null(prev) ||
      all(abs(((prev - ang_i + pi) %% (2 * pi)) - pi) >= min_gap)
    if (ok) {
      keep[i] <- TRUE
      kept_ang[[g]] <- c(prev, ang_i)
    }
  }
  df$overlap_dismissed <- !keep
  df
}

# ---- Marker shown in place of a label that could not be drawn -------------
# `style`: "dot" (a single, customisable glyph), "initials" (the first
# `nchar_cap` characters of the name), or "none" (nothing -- caller drops the
# row). Vectorised over `name`.
.fallback_marker_label <- function(name, style, symbol, nchar_cap) {
  if (style == "none") {
    return(rep(NA_character_, length(name)))
  }
  if (style == "initials") {
    out <- substr(ifelse(is.na(name), "", name), 1, nchar_cap)
    out[out == ""] <- symbol
    return(out)
  }
  rep(symbol, length(name))
}

# ---- Unique short codes for the "legend" fallback style --------------------
# For each name (processed in order), try successive nchar_cap-length
# substring windows sliding across the (alphanumeric-only) name; the first
# window not already assigned to an earlier name is used. If every window is
# taken (short or duplicate names), fall back to the first window plus a
# numeric suffix. Always returns codes unique within the call.
.assign_unique_codes <- function(name, nchar_cap) {
  used <- character(0)
  vapply(
    name,
    function(nm) {
      clean <- gsub("[^A-Za-z0-9]", "", ifelse(is.na(nm), "", nm))
      if (nchar(clean) == 0) {
        clean <- "X"
      }
      n_windows <- max(1, nchar(clean) - nchar_cap + 1)
      code <- NA_character_
      for (start in seq_len(n_windows)) {
        candidate <- substr(clean, start, start + nchar_cap - 1)
        if (!(candidate %in% used)) {
          code <- candidate
          break
        }
      }
      if (is.na(code)) {
        base <- substr(clean, 1, nchar_cap)
        suffix <- 2L
        repeat {
          candidate <- paste0(base, suffix)
          if (!(candidate %in% used)) {
            code <- candidate
            break
          }
          suffix <- suffix + 1L
        }
      }
      used[[length(used) + 1]] <<- code
      code
    },
    character(1)
  )
}

# ---- "legend" fallback: unique code, else a number, else discard ----------
# `df` must carry `name`, `arcw`, and `ymid` (the anchor radius each row will
# render at). Tries a unique `nchar_cap`-length code per row (own-wedge fit
# test at that radius); rows for which the code doesn't fit try the shortest
# unused integer instead (narrower than a fixed-width code); rows for which
# not even a single digit fits get no marker at all. Returns a list with
# `marker` (NA for discarded rows) and `legend` (a `key`/`name` data frame of
# every row that got a code or a number).
.legend_fallback <- function(df, nchar_cap, cw) {
  codes <- .assign_unique_codes(df$name, nchar_cap)
  code_fits <- nchar(codes) * cw <= df$arcw * df$ymid
  marker <- rep(NA_character_, nrow(df))
  marker[code_fits] <- codes[code_fits]

  need_number <- which(!code_fits)
  if (length(need_number) > 0) {
    numbers <- as.character(seq_along(need_number))
    number_fits <- nchar(numbers) * cw <=
      df$arcw[need_number] * df$ymid[need_number]
    marker[need_number[number_fits]] <- numbers[number_fits]
  }

  used <- !is.na(marker)
  list(
    marker = marker,
    legend = data.frame(
      key = marker[used],
      name = df$name[used],
      stringsAsFactors = FALSE
    )
  )
}

# ---- Static ggplot path ----------------------------------------------------
.krona_static <- function(
  hier,
  layout,
  title,
  pattern = FALSE,
  show_center_count = TRUE,
  label_pct = "none",
  label_orientation = "auto",
  truncate_labels = FALSE,
  dismiss_overlaps = TRUE,
  label_fallback = "dot",
  fallback_symbol = "\u00b7",
  fallback_nchar = 3,
  leaf_label_padding = 0.08,
  use_gradient = FALSE,
  val_range = NULL,
  gradient_name = NULL,
  show_collapsed_path = FALSE
) {
  if (pattern && !requireNamespace("ggpattern", quietly = TRUE)) {
    cli::cli_abort(
      "Package {.pkg ggpattern} is required for {.code pattern = TRUE}. Install it with {.code install.packages('ggpattern')} or use {.code pattern = FALSE}."
    )
  }

  # The three documented ROADMAP options map onto the historical internal mode
  # names; normalise here so every downstream branch sees a canonical value.
  #   option1 -> "tangential" (every label arc-following)
  #   option2 -> "mixed"      (internal arc-following, leaf spoke)
  #   option3 -> "auto"       (default: internal arc-following, leaf spoke with
  #                            overlap dismissal)
  label_orientation <- switch(
    label_orientation,
    option1 = "tangential",
    option2 = "mixed",
    option3 = "auto",
    label_orientation
  )

  total_weight <- hier$value

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
    # Merge identical fill chains (unassigned / "n more") into single spanning,
    # borderless rects. Adds `depthmax` and `spanning`.
    df <- .merge_fill_chains(df)
    max_depth <- max(df$depthmax) - 1
    # Leaf labels sit OUTSIDE the rim by default in every mode except pure
    # "tangential" (which never tries the radial-outside placement), so
    # reserve a ring of radial room beyond the outer wedge for them, sized
    # from the padding plus a fixed label-length allowance. Very negative
    # padding (pulling labels back inside) needs no reserved room at all.
    leaf_outside <- label_orientation != "tangential"
    outer_room <- if (leaf_outside) max(0, leaf_label_padding + 1.0) else 0.0
    p <- ggplot2::ggplot() +
      .krona_rect_layer(
        df,
        "depth",
        "depthmax",
        pattern,
        spacing = 0.012,
        fill_col = if (use_gradient && !is.null(val_range)) {
          "numeric_attr"
        } else {
          "color"
        }
      ) +
      # clip = "off" lets radial leaf labels extend past the rim into the plot
      # margin (added below) instead of being clipped at the cardinal edges,
      # where the outer circle touches the panel boundary.
      ggplot2::coord_polar(theta = "x", start = -pi / 2, clip = "off") +
      ggplot2::scale_y_continuous(
        limits = c(0, max_depth + 1 + outer_room)
      ) +
      # Label layers map their per-row point size directly (base size times the
      # `label_size` multiplier), so the size scale must pass values through.
      ggplot2::scale_size_identity() +
      ggplot2::theme_void() +
      ggplot2::theme(
        plot.margin = ggplot2::margin(24, 24, 24, 24, "pt")
      ) +
      ggplot2::labs(title = title)
    if (use_gradient && !is.null(val_range)) {
      p <- p +
        ggplot2::scale_fill_gradientn(
          colors = scales::viridis_pal()(256),
          limits = val_range,
          name = gradient_name,
          na.value = "#cfcfcf"
        ) +
        ggplot2::theme(
          legend.position = "right",
          legend.key.width = ggplot2::unit(0.35, "cm"),
          legend.key.height = ggplot2::unit(2, "cm"),
          legend.title = ggplot2::element_text(size = 8),
          legend.text = ggplot2::element_text(size = 7)
        )
    } else {
      p <- p +
        ggplot2::scale_fill_identity() +
        ggplot2::theme(legend.position = "none")
    }

    if (show_center_count) {
      # x = 0, y = 0 → the exact pole of coord_polar regardless of angle.
      # Thousands separator: NARROW NO-BREAK SPACE (U+202F) per CGPM 2003.
      p <- p +
        ggplot2::annotate(
          "text",
          x = 0,
          y = 0,
          label = paste0(
            "n = ",
            format(round(total_weight), big.mark = " ", scientific = FALSE)
          ),
          size = 3,
          color = "#333333",
          fontface = "bold"
        )
    }

    # ---- Section labels -----------------------------------------------------
    # `label_orientation`:
    #   "auto" (default): internal labels run along their own ring band
    #     (arc-following, centred); leaf labels are placed OUTSIDE the rim as
    #     a spoke reading straight outward, each linked to its wedge by a
    #     short grey leader line.
    #   "radial": same visual result as "auto" (see ang_tang_of/ang_radial_of
    #     naming note below -- the names read backwards from the geometry
    #     under this chart's coord_polar(start = -pi/2)).
    #   "tangential": every label runs along its arc, centred in the band,
    #     shown only when it fits.
    #   "mixed": internal labels are tangential (circular); leaf labels are
    #     radial, anchored at the band inner edge (never outside the rim).
    #   "adaptive": every label tries radial first, falls back to tangential
    #     when it does not fit the arc, and is hidden (fallback marker) when
    #     neither fits.
    # Merged fill chains (one spanning rect) are labelled once, as a leaf.
    # Rotation is normalised to [-90, 90] so text is never upside-down.
    # Regardless of mode, any radially-oriented label (internal or leaf) can
    # additionally be thinned by `dismiss_overlaps` when it would visually
    # collide with a denser neighbour; wedges with no room, and labels
    # dismissed for overlap, get the `label_fallback` marker instead.
    mode <- label_orientation
    rim <- max_depth + 1
    internal_style <- if (mode %in% c("tangential", "mixed")) {
      "tangential"
    } else if (mode == "adaptive") {
      "adaptive"
    } else {
      "radial"
    }
    # Leaf-radial placement (outside the rim, at rim + leaf_label_padding) is
    # now a single formula regardless of mode -- only whether tangential is
    # tried at all, and in which order, differs by mode.
    leaf_style <- if (mode == "tangential") {
      "tangential"
    } else if (mode == "adaptive") {
      "adaptive"
    } else {
      "radial"
    }

    lab_df <- df
    lab_df$xmid <- (lab_df$x0 + lab_df$x1) / 2
    lab_df$arcw <- lab_df$x1 - lab_df$x0
    lab_df$is_leaf <- (lab_df$depth == max_depth) | lab_df$spanning

    if (label_pct != "none") {
      denom <- if (label_pct == "parent") lab_df$parent_value else total_weight
      pct <- round(lab_df$value / denom * 100, 1)
      pct[!is.finite(pct)] <- 0
      lab_df$lab <- paste0(lab_df$name, " (", pct, "%)")
    } else {
      lab_df$lab <- lab_df$name
    }

    lab_df$col <- ifelse(
      lab_df$is_leaf | lab_df$is_aggregate,
      "#111111",
      "white"
    )
    if (show_collapsed_path && "collapsed_path" %in% names(lab_df)) {
      has_path <- !is.na(lab_df$collapsed_path)
      if (any(has_path)) {
        lab_df$lab[has_path] <- paste0(
          lab_df$collapsed_path[has_path],
          " / ",
          lab_df$lab[has_path]
        )
        lab_df$col[has_path] <- "#555555"
      }
    }

    # NOTE on naming vs visual effect: under this chart's
    # coord_polar(start = -pi/2), data-x = 0 lands at the WEST cardinal point
    # (not north), so a rotation formula whose own flip threshold sits at
    # data-x = 0/pi (west/east) reads as running ALONG the ring (arc-following,
    # "tangential" in the everyday sense), while a formula flipping at
    # data-x = pi/2/3*pi/2 (north/south) reads as a spoke pointing straight out
    # from the centre ("radial" in the everyday sense). That is the OPPOSITE
    # of what the function names below suggest -- confirmed empirically by
    # rendering an 8-wedge test circle with each formula. The names are kept
    # (call sites already read naturally against them) but each `ang_*_of`
    # call below is chosen for its ACTUAL rendered look, not its name.
    ang_norm <- function(a) ((a + 90) %% 180) - 90
    ang_radial_of <- function(x) ang_norm(-(x / (2 * pi)) * 360 + 90)
    ang_tang_of <- function(x) ang_norm(-(x / (2 * pi)) * 360)
    # Internal labels stay centred (hjust = 0.5, see below) so they need no
    # side split. Leaf labels anchored at the rim (see `use_rad` below) use
    # the spoke-look formula (`ang_tang_of`), whose own flip axis sits at
    # north/south (data-x = pi/2, 3*pi/2) -- the hjust split below matches
    # that SAME axis so the anchor/extension direction stays consistent with
    # the rotation (an axis mismatch here is what caused text to fold back
    # over its own wedge in earlier iterations).
    lab_df$hj_side <- ifelse(
      lab_df$xmid > pi / 2 & lab_df$xmid < 3 * pi / 2,
      0,
      1
    )

    sz_inner <- 1.7
    sz_leaf <- 1.85
    cw <- 0.135 # approx radius units per character (tangential fit test)
    # Per-row size = base size * `label_size` multiplier (1 when unset/NA).
    sz_of <- function(rows, base) {
      base * ifelse(is.na(rows$size_mult), 1, rows$size_mult)
    }

    inner_df <- lab_df[!lab_df$is_leaf, , drop = FALSE]
    leaf_df <- lab_df[lab_df$is_leaf, , drop = FALSE]
    dot_cols <- names(lab_df)
    fallback <- lab_df[0, dot_cols, drop = FALSE]
    fallback$leader <- logical(0)

    # ---- internal labels --------------------------------------------------
    if (nrow(inner_df) > 0) {
      # Internal (non-leaf) rows are always exactly one ring thick, so their
      # band centre and truncation room are both fixed regardless of depth.
      inner_df$ymid <- inner_df$depth + 0.5
      maxch <- pmax(4L, floor(1 / 0.072))
      # `truncate_labels` controls whether the middle ellipsis is EVER used.
      #   TRUE  -> shorten long names to fit ("Stro...aceae"), staying visible.
      #   FALSE -> show the full name (no ellipsis anywhere); a name that does
      #            not fit its arc is simply hidden (tangential) or left to run
      #            along its radial spoke (radial). Pair with `label_size` to
      #            shrink text so full names fit.
      rad_lab <- if (truncate_labels) {
        .truncate_label_middle(inner_df$lab, maxch)
      } else {
        inner_df$lab
      }
      inner_avail <- inner_df$arcw * inner_df$ymid / cw
      if (truncate_labels) {
        tang_lab <- .fit_truncate(inner_df$lab, inner_avail)
        tang_fits <- !is.na(tang_lab)
      } else {
        tang_lab <- inner_df$lab
        tang_fits <- nchar(tang_lab) * cw <= inner_df$arcw * inner_df$ymid
      }
      rad_fits <- inner_df$arcw * inner_df$ymid >= 0.25

      if (internal_style == "tangential") {
        use_tang <- tang_fits
        use_rad <- rep(FALSE, nrow(inner_df))
      } else if (internal_style == "adaptive") {
        use_rad <- rad_fits
        use_tang <- !rad_fits & tang_fits
      } else {
        use_tang <- rep(FALSE, nrow(inner_df))
        use_rad <- rad_fits
      }

      if (any(use_tang)) {
        show_tang <- inner_df[use_tang, , drop = FALSE]
        show_tang$lab <- tang_lab[use_tang]
        show_tang$ang <- ang_tang_of(show_tang$xmid)
        show_tang$sz <- sz_of(show_tang, sz_inner)
        p <- p +
          ggplot2::geom_text(
            data = show_tang,
            ggplot2::aes(
              x = xmid,
              y = ymid,
              label = lab,
              angle = ang,
              colour = col,
              size = sz
            ),
            hjust = 0.5,
            fontface = "bold"
          )
      }

      overlap_dismissed <- rep(FALSE, nrow(inner_df))
      if (any(use_rad)) {
        show_rad <- inner_df[use_rad, , drop = FALSE]
        show_rad$lab <- rad_lab[use_rad]
        if (dismiss_overlaps) {
          show_rad <- .dismiss_overlapping_labels(
            show_rad,
            group = show_rad$depth
          )
        } else {
          show_rad$overlap_dismissed <- FALSE
        }
        overlap_dismissed[use_rad] <- show_rad$overlap_dismissed
        drawn <- show_rad[!show_rad$overlap_dismissed, , drop = FALSE]
        if (nrow(drawn) > 0) {
          drawn$ang <- ang_radial_of(drawn$xmid)
          drawn$sz <- sz_of(drawn, sz_inner)
          # Centred on the band (hjust = 0.5): unlike leaf labels, an internal
          # radial label doesn't need a hemisphere-based hjust switch -- only
          # the rotation angle still flips by hemisphere, to avoid upside-down
          # text.
          p <- p +
            ggplot2::geom_text(
              data = drawn,
              ggplot2::aes(
                x = xmid,
                y = ymid,
                label = lab,
                angle = ang,
                colour = col,
                size = sz
              ),
              hjust = 0.5,
              vjust = 0.5,
              fontface = "bold"
            )
        }
      }

      no_room <- !use_tang & !use_rad
      fb_idx <- (no_room | overlap_dismissed) & inner_df$arcw > 0.05
      if (any(fb_idx)) {
        fb_rows <- inner_df[fb_idx, dot_cols, drop = FALSE]
        fb_rows$leader <- FALSE
        fallback <- rbind(fallback, fb_rows)
      }
    }

    # ---- leaf labels ------------------------------------------------------
    if (nrow(leaf_df) > 0) {
      leaf_df$ymid <- (leaf_df$depth + leaf_df$depthmax) / 2
      leaf_avail <- leaf_df$arcw * leaf_df$ymid / cw
      if (truncate_labels) {
        tang_lab <- .fit_truncate(leaf_df$lab, leaf_avail)
        tang_fits <- !is.na(tang_lab)
      } else {
        tang_lab <- leaf_df$lab
        tang_fits <- nchar(tang_lab) * cw <= leaf_df$arcw * leaf_df$ymid
      }
      rad_fits <- leaf_df$arcw * rim >= 0.42

      if (leaf_style == "tangential") {
        use_tang <- tang_fits
        use_rad <- rep(FALSE, nrow(leaf_df))
      } else if (leaf_style == "adaptive") {
        use_rad <- rad_fits
        use_tang <- !rad_fits & tang_fits
      } else {
        use_tang <- rep(FALSE, nrow(leaf_df))
        use_rad <- rad_fits
      }

      if (any(use_tang)) {
        # tangential: centred along the arc, in the (spanning) leaf band
        show_tang <- leaf_df[use_tang, , drop = FALSE]
        show_tang$lab <- tang_lab[use_tang]
        show_tang$ang <- ang_tang_of(show_tang$xmid)
        show_tang$sz <- sz_of(show_tang, sz_leaf)
        p <- p +
          ggplot2::geom_text(
            data = show_tang,
            ggplot2::aes(
              x = xmid,
              y = ymid,
              label = lab,
              angle = ang,
              colour = col,
              size = sz
            ),
            hjust = 0.5,
            fontface = "bold"
          )
      }

      overlap_dismissed <- rep(FALSE, nrow(leaf_df))
      if (any(use_rad)) {
        # Every leaf row's depthmax equals the outer rim (both plain leaves
        # and merged fill chains reach it by construction), so the anchor
        # radius -- rim + leaf_label_padding -- is one constant regardless of
        # which depth the row originated from: one placement formula, and
        # dismiss_overlaps compares every leaf-radial label globally.
        show_rad <- leaf_df[use_rad, , drop = FALSE]
        if (truncate_labels) {
          show_rad$lab <- .truncate_label_middle(show_rad$lab, 40)
        }
        show_rad$y_out <- rim + leaf_label_padding
        if (dismiss_overlaps) {
          show_rad <- .dismiss_overlapping_labels(show_rad)
        } else {
          show_rad$overlap_dismissed <- FALSE
        }
        overlap_dismissed[use_rad] <- show_rad$overlap_dismissed
        drawn <- show_rad[!show_rad$overlap_dismissed, , drop = FALSE]
        if (nrow(drawn) > 0) {
          # ang_tang_of() is the spoke-look formula here (see the naming note
          # near hj_side above) -- leaf labels read as rays pointing straight
          # out from the centre, paired with the matching hj_side split.
          drawn$ang <- ang_tang_of(drawn$xmid)
          drawn$sz <- sz_of(drawn, sz_leaf)
          # A leader line only has something to visually bridge when the
          # label sits with a real gap past the border.
          if (leaf_label_padding > 0.03) {
            leader <- drawn
            leader$y0 <- rim
            leader$y1 <- drawn$y_out - 0.02
            p <- p +
              ggplot2::geom_segment(
                data = leader,
                ggplot2::aes(x = xmid, xend = xmid, y = y0, yend = y1),
                colour = "#999999",
                linewidth = 0.25
              )
          }
          p <- p +
            ggplot2::geom_text(
              data = drawn,
              ggplot2::aes(
                x = xmid,
                y = y_out,
                label = lab,
                angle = ang,
                hjust = hj_side,
                colour = col,
                size = sz
              ),
              vjust = 0.5,
              fontface = "bold"
            )
        }
      }

      no_room <- !use_tang & !use_rad
      fb_idx <- (no_room | overlap_dismissed) & leaf_df$arcw > 0.05
      if (any(fb_idx)) {
        fb_rows <- leaf_df[fb_idx, dot_cols, drop = FALSE]
        fb_rows$leader <- leaf_outside && leaf_label_padding > 0.03
        fallback <- rbind(fallback, fb_rows)
      }
    }

    # ---- fallback markers: no room, or dismissed for overlap ---------------
    legend_df <- NULL
    if (nrow(fallback) > 0) {
      fallback$ymid <- ifelse(
        fallback$leader,
        rim + leaf_label_padding,
        ifelse(fallback$is_leaf, rim - 0.5, fallback$depth + 0.5)
      )
      if (label_fallback == "legend") {
        legend_result <- .legend_fallback(fallback, fallback_nchar, cw)
        fallback$marker <- legend_result$marker
        legend_df <- legend_result$legend
      } else {
        fallback$marker <- .fallback_marker_label(
          fallback$name,
          label_fallback,
          fallback_symbol,
          fallback_nchar
        )
      }
      fallback <- fallback[!is.na(fallback$marker), , drop = FALSE]
    }
    if (nrow(fallback) > 0) {
      fallback$col <- ifelse(
        fallback$is_leaf | fallback$is_aggregate,
        "#444444",
        "white"
      )
      leader_rows <- fallback[fallback$leader, , drop = FALSE]
      if (nrow(leader_rows) > 0) {
        leader_rows$y0 <- rim
        leader_rows$y1 <- rim + 0.06
        p <- p +
          ggplot2::geom_segment(
            data = leader_rows,
            ggplot2::aes(x = xmid, xend = xmid, y = y0, yend = y1),
            colour = "#bbbbbb",
            linewidth = 0.2
          )
      }
      p <- p +
        ggplot2::geom_text(
          data = fallback,
          ggplot2::aes(x = xmid, y = ymid, label = marker, colour = col),
          size = if (label_fallback %in% c("initials", "legend")) 2 else 3
        )
    }

    # ---- legend for the "legend" fallback style ----------------------------
    # A single upright (non-rotated) multi-line annotation anchored at a fixed
    # diagonal angle and the outer edge of the already-reserved scale range;
    # clip = "off" lets it extend into the corner margin without needing any
    # extra scale room. annotation_custom() cannot be used here -- ggplot2
    # only supports it under coord_cartesian, not coord_polar.
    if (!is.null(legend_df) && nrow(legend_df) > 0) {
      legend_df <- legend_df[order(legend_df$name), , drop = FALSE]
      legend_text <- paste(
        paste(legend_df$key, legend_df$name, sep = " \u2014 "),
        collapse = "\n"
      )
      p <- p +
        ggplot2::annotate(
          "text",
          x = 7 * pi / 4,
          y = rim + outer_room,
          label = legend_text,
          hjust = 0.5,
          vjust = 1,
          size = 2,
          colour = "#333333"
        )
    }

    p <- p + ggplot2::scale_colour_identity()
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
    .krona_rect_layer(
      df,
      "y0",
      "y1",
      pattern,
      spacing = 0.03,
      fill_col = if (use_gradient && !is.null(val_range)) {
        "numeric_attr"
      } else {
        "color"
      }
    ) +
    ggplot2::scale_x_continuous(expand = c(0, 0)) +
    ggplot2::scale_y_continuous(expand = c(0, 0)) +
    ggplot2::coord_fixed() +
    ggplot2::theme_void() +
    ggplot2::labs(title = title)
  if (use_gradient && !is.null(val_range)) {
    p <- p +
      ggplot2::scale_fill_gradientn(
        colors = scales::viridis_pal()(256),
        limits = val_range,
        name = gradient_name,
        na.value = "#cfcfcf"
      ) +
      ggplot2::theme(
        legend.position = "right",
        legend.key.width = ggplot2::unit(0.35, "cm"),
        legend.key.height = ggplot2::unit(2, "cm"),
        legend.title = ggplot2::element_text(size = 8),
        legend.text = ggplot2::element_text(size = 7)
      )
  } else {
    p <- p +
      ggplot2::scale_fill_identity() +
      ggplot2::theme(legend.position = "none")
  }

  label_df <- df[
    df$leaf & (df$x1 - df$x0) > 0.05 & (df$y1 - df$y0) > 0.035,
    ,
    drop = FALSE
  ]
  if (nrow(label_df) > 0) {
    if (label_pct != "none") {
      denom <- if (label_pct == "parent") {
        label_df$parent_value
      } else {
        total_weight
      }
      pct <- round(label_df$value / denom * 100, 1)
      pct[!is.finite(pct)] <- 0
      label_df$lab <- paste0(
        .truncate_label_middle(label_df$name),
        " (",
        pct,
        "%)"
      )
    } else {
      label_df$lab <- .truncate_label_middle(label_df$name)
    }
    p <- p +
      ggplot2::geom_text(
        data = label_df,
        ggplot2::aes(x = x0 + 0.004, y = y1 - 0.004, label = lab),
        hjust = 0,
        vjust = 1,
        size = 2.5,
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
#' Colours: each distinct value at the `color_by` rank receives its own
#' evenly spaced hue; its descendants then fan out across a hue band centred
#' on that hue (and grow slightly darker with depth), so nested sections are
#' clearly distinct colours rather than near-identical shades. Set
#' `pattern = TRUE` (static plots only) to overlay a faint grey dotted motif
#' on every other section, an extra channel to tell neighbours apart.
#'
#' This function is a drop-in alternative to [MiscMetabar::krona()], which
#' shells out to KronaTools and does not work on Windows. `krona_like_pq()`
#' works on all platforms because it bundles D3.js locally.
#'
#' @param physeq (required) A [phyloseq::phyloseq-class] object.
#' @param ranks (character or integer, default `"All"`) Taxonomic ranks to
#'   include. `"All"` (default) first tries to select only the seven standard
#'   ranks Kingdom, Phylum, Class, Order, Family, Genus, Species (in that order)
#'   if at least two of them are present — this avoids cluttering the chart with
#'   non-hierarchical annotation columns. Falls back to every column of
#'   `tax_table()` only when fewer than two classical ranks are found. An
#'   integer vector selects columns by position; a character vector selects
#'   columns by name (must all be present in [phyloseq::rank_names()]).
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
#' @param fill_unassigned (logical, default `TRUE`) When `TRUE`, a section that
#'   terminates before the deepest rank -- an `"unassigned"` taxon, or a
#'   `min_prop` `"n more"` aggregate -- is extended with a chain of identical
#'   nested nodes down to the deepest selected rank, so its arc reaches the
#'   outer ring (e.g. a taxon unidentified from Class onwards still spans Class,
#'   Order, ..., Species; the whole circle is filled). The repeated segments
#'   render as a single borderless wedge carrying one label at the leaf. When
#'   `FALSE`, the section stops at the rank where it ended, leaving an inner
#'   wedge with no outer rings.
#' @param layout (character, default `"sunburst"`) One of `"sunburst"` (angle
#'   = value, Krona pie) or `"treemap"` (area = value).
#' @param interactive (logical, default `TRUE`) If `TRUE`, returns a D3.js
#'   `htmlwidget` (requires the **htmlwidgets** package). If `FALSE`, returns
#'   a static [ggplot2::ggplot] object with no extra dependency.
#' @param title (character, default `NULL`) Chart title. When `NULL`, defaults
#'   to `"Taxonomy"`.
#' @param color_by (character, default `NULL`) Name of the rank (must be in
#'   `ranks` for categorical coloring, or any `tax_table()` column when
#'   `color_as_numeric = TRUE`) whose values drive the colour assignment.
#'   When `NULL`, defaults to the first selected rank. Tip: when the first
#'   rank has only one value (e.g. a single phylum), set `color_by` to a more
#'   diverse rank to spread colour earlier.
#' @param color_as_numeric (logical, default `FALSE`) When `TRUE`, `color_by`
#'   may be any column of `tax_table()` (not just a rank in `ranks`). Its
#'   values are coerced to numeric and mapped to a continuous sequential
#'   gradient (viridis palette via **scales**). Numeric values are aggregated
#'   up the tree by weighted mean using `weight_by`, so internal sections
#'   receive a meaningful colour. Requires the **scales** package.
#' @param pattern (logical, default `FALSE`) Static plots only. When `TRUE`,
#'   overlays a faint grey dotted motif on every other section (alternating
#'   within each ring/level) so neighbouring sections of similar colour can
#'   still be told apart. Requires the **ggpattern** package. Ignored when
#'   `interactive = TRUE`.
#' @param label_pct (character, default `"none"`) Whether to append a
#'   proportion to each section label. One of `"none"` (no percentage),
#'   `"total"` (percentage of the overall total, following `weight_by`), or
#'   `"parent"` (percentage of the immediate parent section). Applies to static
#'   plots only.
#' @param show_center_count (logical, default `TRUE`) Static sunburst only.
#'   When `TRUE`, the total count (following `weight_by`) is shown in the
#'   centre hole as `n = <x>`, mirroring the original Krona display. Set to
#'   `FALSE` to suppress. For the interactive widget the centre count updates
#'   to the focused node when zooming; controlled by `show_center_count` as
#'   well.
#' @param min_prop (numeric, default `NULL`) When a positive number, siblings
#'   within the same parent whose proportion of that parent falls below this
#'   threshold are merged into a single `"<n> more"` aggregate section
#'   (crosshatch motif via **ggpattern**; plain grey if **ggpattern** is not
#'   available). `NULL` (default) disables merging. A typical value is `0.02`
#'   (2%). Aggregation recurs at every depth. When `fill_unassigned = TRUE`
#'   (the default) the aggregate also spans out to the leaf ring as one
#'   borderless wedge, so the whole circle stays filled.
#' @param collapse_single (logical, default `FALSE`) When `TRUE`, internal
#'   nodes that have exactly one child (and that child is not a leaf) are
#'   removed from the hierarchy; the grandchildren attach directly to the
#'   grandparent. This trims redundant intermediate ranks (e.g. a Family
#'   containing a single Genus) from both static and interactive views.
#'   Leaf nodes are never collapsed.
#' @param show_collapsed_path (logical, default `FALSE`) Static plots only, and
#'   only meaningful together with `collapse_single = TRUE`. When `TRUE`, each
#'   collapsed section is labelled with its full taxonomic path -- the names of
#'   the skipped intermediate ranks joined by `" / "` and prefixed to the node
#'   name (e.g. `"Stereaceae / Stereum"`) -- drawn in grey so the merged ranks
#'   remain visible.
#' @param abbrev_species (logical, default `FALSE`) When `TRUE`, each name at
#'   the `"Species"` rank is prefixed with the initial of its parent genus, so
#'   a species epithet reads as an abbreviated binomial (e.g. `"muscaria"`
#'   under genus `"Amanita"` becomes `"A. muscaria"`). Applies to both the
#'   static and interactive plots. Placeholder names (`"unassigned"`) and names
#'   already carrying an initial are left untouched; if no `"Species"` rank is
#'   among `ranks`, a warning is issued and names are unchanged.
#' @param label_size (numeric, default `NULL`) A positive multiplier on the
#'   base label font size, applied to both the static and interactive plots.
#'   Its length selects the mode:
#'   * length `1` -- a single multiplier for every label.
#'   * length `length(ranks)` -- one multiplier per rank; a label at rank `i`
#'     uses `label_size[i]`.
#'   * length `ntaxa(physeq)` -- one value per taxon, positional in
#'     `taxa_names()` order. Each leaf's multiplier is the mean of its
#'     constituent taxa's values, and each internal node's is the mean of all
#'     its descendant leaves' multipliers.
#'   `NULL` keeps the default sizing. Values must be finite and `> 0`.
#' @param grey_terms (character, default `c(NA, "unassigned", "unknown")`)
#'   Section names whose colour is overridden to grey, used to visually mute
#'   uninformative taxa. `NA` matches sections with a missing name. Pass
#'   `character(0)` to disable.
#' @param label_orientation (character, default `"auto"`) Static sunburst
#'   only. Controls how section labels are placed. The three documented modes
#'   are `"option1"`, `"option2"`, and `"option3"`; the older names are kept
#'   as aliases.
#'   * `"option3"` / `"auto"` (default): **internal** labels run **along their
#'     own ring band** (arc-following, never upside-down), centred; **leaf**
#'     labels are **radial**, a spoke reading straight outward from the
#'     centre, placed outside the coloured arc by `leaf_label_padding`, with
#'     crowded leaves thinned by `dismiss_overlaps`. `"radial"` is a further
#'     alias of this mode.
#'   * `"option1"` / `"tangential"`: **every** label (internal and leaf) runs
#'     along its arc, centred in the band. Long labels are shortened to fit
#'     with `truncate_labels`; a name still too wide for its arc is hidden
#'     (replaced by the `label_fallback` marker).
#'   * `"option2"` / `"mixed"`: **internal** labels are tangential (circular);
#'     **leaf** labels are radial, outside the rim like `"option3"`.
#'   * `"adaptive"`: every label tries the radial placement first and falls
#'     back to tangential only when radial does not fit the arc.
#'   In every mode, a label with nowhere to go gets the `label_fallback`
#'   marker; see `dismiss_overlaps` for thinning crowded radial labels and
#'   `leaf_label_padding` for how far outside the rim leaf labels sit.
#'   The interactive widget mirrors the default styling (internal
#'   arc-following, leaf radial), but does not expose these modes.
#' @param truncate_labels (logical, default `FALSE`) Applies to the static
#'   sunburst and the interactive widget. Controls whether labels may be
#'   abbreviated with a middle ellipsis. When `TRUE`, a label too long for its
#'   space is shortened so it still fits and stays visible (e.g.
#'   `"Strophariaceae"` becomes `"Stro...aceae"`). When `FALSE` (the default),
#'   labels are never abbreviated: a name is shown in full when it fits, and an
#'   arc-following name too long for its arc is hidden (its wedge gets the
#'   `label_fallback` marker) rather than truncated. Pair `FALSE` with
#'   `label_size` to shrink the text until full names fit.
#' @param dismiss_overlaps (logical, default `TRUE`) Static sunburst only.
#'   Radially-oriented labels are anchored at a single point and can visually
#'   crowd a neighbour when their wedges are angularly close, even though each
#'   individually "fits" its own wedge. When `TRUE`, such collisions are
#'   detected and the lower-value label of the pair is replaced by the
#'   `label_fallback` marker instead of being drawn overlapping. Has no effect
#'   on purely tangential labels, which are already confined to their own arc.
#'   Set to `FALSE` to restore the unfiltered placement.
#' @param label_fallback (character, default `"dot"`) Static sunburst only.
#'   What to draw instead of a label that has no room, or that
#'   `dismiss_overlaps` removed for overlapping a neighbour. `"dot"` draws the
#'   single glyph in `fallback_symbol`. `"initials"` draws the first
#'   `fallback_nchar` characters of the section name. `"none"` draws nothing.
#'   `"legend"` tries a unique `fallback_nchar`-letter code derived from the
#'   name first (disambiguated on collision), then the shortest unused number
#'   if even the code does not fit, then nothing; every assigned code/number
#'   is listed in an on-canvas legend (`"code -- name"`, bottom-left corner).
#'   With many small sections the legend can be long enough to extend past a
#'   typical device size -- increase the plot height when using
#'   `label_fallback = "legend"` on high-diversity data. Leaf labels replaced
#'   by a marker keep a short leader line stub pointing to it whenever
#'   `leaf_label_padding` places leaf labels with a real gap past the rim.
#' @param fallback_symbol (character, default `"·"` i.e. a middle dot)
#'   Static sunburst only. The glyph drawn when `label_fallback = "dot"`; pass
#'   e.g. `"*"` or `"+"` for a different marker.
#' @param fallback_nchar (integer, default `3`) Static sunburst only. Number
#'   of leading characters of the section name shown when
#'   `label_fallback = "initials"`; length of the derived code when
#'   `label_fallback = "legend"`.
#' @param leaf_label_padding (numeric, default `0.08`) Static sunburst only.
#'   How far past a leaf wedge's outer border its radial label starts, in the
#'   same depth units as one ring. `0` places the label right at the border;
#'   negative values pull it back inside the wedge (recreating the pre-session
#'   "inside the rim" look); larger positive values push it further out and
#'   draw a connecting leader line. Ignored for tangential leaf labels (which
#'   stay centred inside their own coloured band) and for
#'   `label_orientation = "tangential"`, which never places leaf labels
#'   outside the rim.
#' @param show_search (logical, default `FALSE`) Interactive widget only.
#'   Deprecated: the search box is now always shown in the widget toolbar (for
#'   both layouts); this argument is retained for backward compatibility and
#'   has no effect.
#' @param show_info_panel (logical, default `FALSE`) Interactive widget only.
#'   When `TRUE`, a top-left info panel shows the hovered node's name, count,
#'   and percentages of parent and total, plus a list of sibling nodes.
#' @param check_nestedness (logical, default `TRUE`) When `TRUE`, the function
#'   checks that `tax_table()` is strictly nested (each value at rank `i+1`
#'   appears under only one parent at rank `i`) and issues a [cli::cli_warn()]
#'   for any offending rank pair. Set to `FALSE` to suppress this check, e.g.
#'   when annotation columns are intentionally non-hierarchical.
#' @param file_path (character, default `NULL`) When `interactive = TRUE` and
#'   this is set, the widget is also saved as a self-contained `.html` file
#'   via [htmlwidgets::saveWidget()]. The widget is then returned invisibly.
#'   Ignored when `interactive = FALSE`.
#' @param width,height (numeric, default `NULL`) Widget dimensions in pixels.
#'   Both default to `NULL`, in which case the widget **fills its container**:
#'   the whole browser window for a standalone `.html`, the whole RStudio
#'   viewer pane, and the full viewport height elsewhere -- the widget is meant
#'   to be viewed full-screen and the dense label layout needs the room. Pass
#'   explicit pixel values to fix the size instead. Ignored when
#'   `interactive = FALSE`.
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
#' pq5 <- phyloseq::prune_samples(
#'   phyloseq::sample_names(data_fungi_mini)[1:5],
#'   data_fungi_mini
#' )
#'
#' # Static sunburst (no extra dependency needed)
#' krona_like_pq(pq5, interactive = FALSE)
#' }
#'
#' \dontrun{
#' # Static treemap
#' krona_like_pq(data_fungi_mini, layout = "treemap", interactive = FALSE)
#'
#' # Show proportion of total on labels
#' krona_like_pq(data_fungi_mini, interactive = FALSE, label_pct = "total")
#'
#' # Show proportion of parent on labels
#' krona_like_pq(data_fungi_mini, interactive = FALSE, label_pct = "parent")
#'
#' # Merge low-abundance sections (< 2 percent of parent) into "n more"
#' krona_like_pq(data_fungi_mini, interactive = FALSE, min_prop = 0.02)
#'
#' # Collapse single-child intermediate levels
#' krona_like_pq(data_fungi_mini, interactive = FALSE, collapse_single = TRUE)
#'
#' # Internal labels circular, leaf labels radial (outside the rim)
#' krona_like_pq(data_fungi_mini, interactive = FALSE, label_orientation = "mixed")
#'
#' # Radial where it fits, circular otherwise, for every label
#' krona_like_pq(data_fungi_mini, interactive = FALSE, label_orientation = "adaptive")
#'
#' # Show the first 3 letters instead of a dot for labels with no room
#' krona_like_pq(data_fungi_mini, interactive = FALSE, label_fallback = "initials")
#'
#' # Unique code/number ladder with an on-canvas legend for labels with no room
#' krona_like_pq(
#'   data_fungi_mini,
#'   interactive = FALSE,
#'   label_orientation = "adaptive",
#'   label_fallback = "legend"
#' )
#'
#' # Pull leaf labels back inside the rim instead of the outside-border default
#' krona_like_pq(data_fungi_mini, interactive = FALSE, leaf_label_padding = -0.5)
#'
#' # Add a faint dotted motif on alternate sections (needs ggpattern)
#' if (requireNamespace("ggpattern", quietly = TRUE)) {
#'   krona_like_pq(data_fungi_mini, interactive = FALSE, pattern = TRUE)
#' }
#'
#' # Colour by a numeric tax_table attribute (e.g. a confidence score column)
#' if (requireNamespace("scales", quietly = TRUE)) {
#'   pq_num <- data_fungi_mini
#'   phyloseq::tax_table(pq_num) <- cbind(
#'     phyloseq::tax_table(pq_num),
#'     conf_score = taxa_sums(pq_num)
#'   )
#'   krona_like_pq(
#'     pq_num,
#'     interactive = FALSE,
#'     color_by = "conf_score",
#'     color_as_numeric = TRUE
#'   )
#' }
#'
#' # Weight by ASV count instead of read count
#' krona_like_pq(data_fungi_mini, weight_by = "asv", interactive = FALSE)
#'
#' # Subset of ranks and a custom title
#' krona_like_pq(
#'   data_fungi_mini,
#'   ranks = c("Phylum", "Class", "Order"),
#'   title = "Fungi -- top 3 ranks",
#'   interactive = FALSE
#' )
#'
#' # Interactive D3 widget (requires the htmlwidgets package)
#' krona_like_pq(data_fungi_mini)
#'
#' # Interactive widget with search box and info panel
#' krona_like_pq(
#'   data_fungi_mini,
#'   show_search = TRUE,
#'   show_info_panel = TRUE
#' )
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
  fill_unassigned = TRUE,
  layout = c("sunburst", "treemap"),
  interactive = TRUE,
  title = NULL,
  color_by = NULL,
  color_as_numeric = FALSE,
  pattern = FALSE,
  label_pct = c("none", "total", "parent"),
  show_center_count = TRUE,
  min_prop = NULL,
  collapse_single = FALSE,
  show_collapsed_path = FALSE,
  abbrev_species = FALSE,
  label_size = NULL,
  grey_terms = c(NA_character_, "unassigned", "unknown"),
  label_orientation = c(
    "auto",
    "option1",
    "option2",
    "option3",
    "tangential",
    "radial",
    "mixed",
    "adaptive"
  ),
  truncate_labels = FALSE,
  dismiss_overlaps = TRUE,
  label_fallback = c("dot", "initials", "none", "legend"),
  fallback_symbol = "\u00b7",
  fallback_nchar = 3,
  leaf_label_padding = 0.08,
  show_search = FALSE,
  show_info_panel = FALSE,
  check_nestedness = TRUE,
  file_path = NULL,
  width = NULL,
  height = NULL
) {
  verify_pq(physeq)
  layout <- match.arg(layout)
  label_pct <- match.arg(label_pct)
  label_orientation <- match.arg(label_orientation)
  label_fallback <- match.arg(label_fallback)
  if (!is.logical(truncate_labels) || length(truncate_labels) != 1L) {
    cli::cli_abort(
      "{.arg truncate_labels} must be a single {.code TRUE} or {.code FALSE}."
    )
  }
  if (!is.logical(abbrev_species) || length(abbrev_species) != 1L) {
    cli::cli_abort(
      "{.arg abbrev_species} must be a single {.code TRUE} or {.code FALSE}."
    )
  }
  if (
    !is.character(fallback_symbol) ||
      length(fallback_symbol) != 1 ||
      nchar(fallback_symbol) == 0
  ) {
    cli::cli_abort(
      "{.arg fallback_symbol} must be a single, non-empty character string."
    )
  }
  if (
    !is.numeric(fallback_nchar) ||
      length(fallback_nchar) != 1 ||
      fallback_nchar < 1
  ) {
    cli::cli_abort(
      "{.arg fallback_nchar} must be a single number >= 1."
    )
  }
  fallback_nchar <- as.integer(fallback_nchar)
  if (!is.numeric(leaf_label_padding) || length(leaf_label_padding) != 1) {
    cli::cli_abort(
      "{.arg leaf_label_padding} must be a single number."
    )
  }

  if (pattern && interactive) {
    cli::cli_warn(
      "{.arg pattern} only applies to static plots and is ignored when {.code interactive = TRUE}. Set {.code interactive = FALSE} to use it."
    )
  }
  if (
    !is.null(min_prop) &&
      (!is.numeric(min_prop) ||
        length(min_prop) != 1 ||
        min_prop < 0 ||
        min_prop >= 1)
  ) {
    cli::cli_abort(
      "{.arg min_prop} must be a single number in [0, 1) or {.code NULL}."
    )
  }

  all_ranks <- phyloseq::rank_names(physeq)
  if (length(ranks) == 1 && ranks == "All") {
    ranks <- .default_ranks(all_ranks)
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

  # Classify `label_size` by its length: scalar, one per selected rank, or one
  # per taxon (positional in `taxa_names()` order). The per-taxon vector is
  # aligned to `taxa_names()`, so it must ride along the same zero-weight
  # filtering as the taxa themselves (done just below).
  label_size_mode <- "none"
  if (!is.null(label_size)) {
    if (
      !is.numeric(label_size) ||
        anyNA(label_size) ||
        any(!is.finite(label_size)) ||
        any(label_size <= 0)
    ) {
      cli::cli_abort(
        "{.arg label_size} must be positive, finite number(s)."
      )
    }
    n_taxa_all <- phyloseq::ntaxa(physeq)
    if (length(label_size) == 1L) {
      label_size_mode <- "scalar"
    } else if (length(label_size) == length(ranks)) {
      label_size_mode <- "rank"
    } else if (length(label_size) == n_taxa_all) {
      label_size_mode <- "taxon"
    } else {
      cli::cli_abort(c(
        "{.arg label_size} has an unsupported length ({length(label_size)}).",
        i = "Use a single value, one per rank ({length(ranks)}), or one per taxon ({n_taxa_all})."
      ))
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
  if (label_size_mode == "taxon") {
    label_size <- label_size[keep]
  }

  if (nrow(tt) == 0) {
    cli::cli_abort("No taxa with positive weight remain to plot.")
  }

  if (check_nestedness) {
    .check_nestedness(tt, ranks)
  }

  # Resolve color_by and extract numeric attribute when color_as_numeric = TRUE
  if (is.null(color_by)) {
    color_by <- ranks[1]
  }

  numeric_vals <- NULL
  use_gradient <- FALSE

  if (color_as_numeric) {
    if (!requireNamespace("scales", quietly = TRUE)) {
      cli::cli_abort(
        "Package {.pkg scales} is required for {.code color_as_numeric = TRUE}. Install it with {.code install.packages('scales')}."
      )
    }
    if (!color_by %in% all_ranks) {
      cli::cli_abort(
        "{.arg color_by} column {.val {color_by}} not found in tax_table."
      )
    }
    raw_vals <- as.vector(phyloseq::tax_table(physeq)[, color_by])
    numeric_vals_all <- suppressWarnings(as.numeric(as.character(raw_vals)))
    names(numeric_vals_all) <- phyloseq::taxa_names(physeq)
    if (all(is.na(numeric_vals_all))) {
      cli::cli_abort(
        "{.arg color_by} column {.val {color_by}} cannot be coerced to numeric. Use {.code color_as_numeric = FALSE} for categorical coloring."
      )
    }
    numeric_vals <- numeric_vals_all[keep]
    use_gradient <- TRUE
    color_depth <- NULL
  } else {
    color_depth <- match(color_by, ranks)
    if (is.na(color_depth)) {
      cli::cli_abort(
        "{.arg color_by} rank {.val {color_by}} is not in {.arg ranks}."
      )
    }
  }

  hier <- .build_tax_hierarchy(
    tt,
    ranks,
    weights,
    0,
    add_unassigned_rank,
    numeric_vals,
    fill_unassigned
  )
  if (is.null(hier)) {
    cli::cli_abort("Could not build a taxonomy hierarchy from the data.")
  }
  hier$name <- "All"

  # Attach per-node font-size multipliers from `label_size`. Done before
  # `abbrev_species`/`collapse_single` so the per-taxon path matches raw rank
  # values, and so both the static and interactive paths share one hierarchy.
  if (label_size_mode == "scalar") {
    hier <- .assign_size_scalar(hier, label_size)
  } else if (label_size_mode == "rank") {
    hier <- .assign_size_by_rank(hier, label_size)
  } else if (label_size_mode == "taxon") {
    tt_norm <- tt
    for (rk in ranks) {
      v <- as.character(tt_norm[[rk]])
      v[is.na(v) | v == ""] <- "unassigned"
      tt_norm[[rk]] <- v
    }
    hier <- .assign_size_by_taxon(
      hier,
      tt_norm,
      ranks,
      label_size,
      character()
    )$node
  }

  # Prepend the genus initial to species names ("muscaria" -> "A. muscaria").
  # Done before `collapse_single` while `node$depth` still matches the rank
  # index (collapsing invalidates it), so both the static and interactive
  # paths inherit the abbreviated names from this single hierarchy.
  if (abbrev_species) {
    sp_idx <- which(tolower(ranks) == "species")
    if (length(sp_idx) == 1L) {
      hier <- .abbrev_species_names(hier, sp_idx)
    } else {
      cli::cli_warn(
        "{.arg abbrev_species} is {.code TRUE} but no {.val Species} rank is in {.arg ranks}; names left unchanged."
      )
    }
  }

  if (collapse_single) {
    hier <- .collapse_single_children(hier)
  }

  if (!is.null(min_prop) && min_prop > 0) {
    hier <- .merge_low_abundance(
      hier,
      min_prop,
      max_depth = length(ranks),
      fill = fill_unassigned
    )
  }

  if (use_gradient) {
    val_range <- range(numeric_vals, na.rm = TRUE)
    if (diff(val_range) == 0) {
      val_range <- val_range + c(-1, 1)
    }
    scale_fn <- scales::col_numeric(palette = "viridis", domain = val_range)
    hier <- .krona_gradient_palette(hier, scale_fn)
  } else {
    hue_map <- .build_hue_map(hier, color_depth)
    hier <- .krona_palette(hier, color_depth, hue_map)

    # Pre-compute one colored copy per rank for the JS color-by selector.
    if (interactive) {
      color_sets <- stats::setNames(
        lapply(seq_along(ranks), function(i) {
          hm_i <- .build_hue_map(hier, i)
          .krona_palette(hier, i, hm_i)
        }),
        ranks
      )
      hier <- .add_color_options(hier, color_sets)
    }
  }

  if (!is.null(grey_terms) && length(grey_terms) > 0) {
    hier <- .krona_grey_terms(hier, grey_terms)
  }

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
        options = list(
          showCenterCount = show_center_count,
          showSearch = show_search,
          showInfoPanel = show_info_panel,
          truncateLabels = truncate_labels,
          labelPct = label_pct,
          totalWeight = hier$value,
          ranks = as.list(ranks),
          defaultColorBy = color_by,
          collapseEnabled = collapse_single,
          showCollapsedPath = show_collapsed_path
        )
      ),
      width = width,
      height = height,
      # Meant to be viewed full-screen (labels are dense). By default the
      # widget fills its container: the whole browser window for a standalone
      # `.html` (`browser.fill`), the whole viewer pane in RStudio
      # (`viewer.fill`), and the full viewport height (`100vh`) otherwise, with
      # no surrounding padding. Explicit `width`/`height` still override this.
      sizingPolicy = htmlwidgets::sizingPolicy(
        padding = 0,
        browser.fill = TRUE,
        browser.padding = 0,
        viewer.fill = TRUE,
        viewer.padding = 0,
        knitr.figure = FALSE,
        knitr.defaultWidth = "100%",
        knitr.defaultHeight = "700px",
        defaultWidth = "100%",
        defaultHeight = "100vh"
      ),
      package = "ggplotpq"
    )
    if (!is.null(file_path)) {
      htmlwidgets::saveWidget(widget, file = file_path, selfcontained = TRUE)
      return(invisible(widget))
    }
    return(widget)
  }

  .krona_static(
    hier,
    layout,
    title,
    pattern = pattern,
    show_center_count = show_center_count,
    label_pct = label_pct,
    label_orientation = label_orientation,
    truncate_labels = truncate_labels,
    dismiss_overlaps = dismiss_overlaps,
    label_fallback = label_fallback,
    fallback_symbol = fallback_symbol,
    fallback_nchar = fallback_nchar,
    leaf_label_padding = leaf_label_padding,
    use_gradient = use_gradient,
    val_range = if (use_gradient) val_range else NULL,
    gradient_name = if (use_gradient) color_by else NULL,
    show_collapsed_path = show_collapsed_path
  )
}
