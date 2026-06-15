utils::globalVariables(c(
  "name",
  "n",
  "x",
  "y",
  "label_r",
  "x_label",
  "y_label",
  "hjust",
  "vjust",
  "node_label",
  "from",
  "to",
  "metric",
  "label",
  "color",
  "fmt",
  "curvature",
  "bounds",
  "raw_value",
  "x_from",
  "y_from",
  "x_to",
  "y_to",
  "met_idx",
  "pair_flip",
  "curvature_pair",
  "lw",
  "value",
  "vmin",
  "vmean",
  "vmax",
  "stats_label",
  "xend",
  "yend",
  "count",
  "prop",
  "modality",
  "significant",
  "pval",
  "sig",
  "pair",
  "metric_label"
))

# Internal helper: aggregate an OTU table by modality (sum of reads per group).
# Returns a matrix with taxa as rows and modalities as columns.
.agg_by_mod <- function(ps, fact, mods) {
  otu <- as.data.frame(as.matrix(
    if (phyloseq::taxa_are_rows(ps)) {
      phyloseq::otu_table(ps)
    } else {
      t(phyloseq::otu_table(ps))
    }
  ))
  sd <- as.data.frame(phyloseq::sample_data(ps))
  sapply(mods, function(mod) {
    samps <- intersect(rownames(sd)[sd[[fact]] == mod], colnames(otu))
    rowSums(otu[, samps, drop = FALSE])
  })
}

# Default node angles (degrees) for 2-4 modalities.
.sharing_angles <- function(n) {
  switch(
    as.character(n),
    "2" = c(180, 0),
    "3" = c(90, 210, 330),
    "4" = c(135, 225, 315, 45)
  )
}

################################################################################
#' Build a single metric definition for `community_sharing_plot()`
#'
#' @description
#'
#' <a href="https://adrientaudiere.github.io/MiscMetabar/articles/Rules.html#lifecycle">
#' <img src="https://img.shields.io/badge/lifecycle-experimental-orange" alt="lifecycle-experimental"></a>
#'
#' Helper constructor that packages one community-similarity metric for use by
#' [community_sharing_plot()] and [community_sharing_barplot()]. All metrics
#' should be expressed as **similarities** (higher value = more similar
#' communities = thicker link).
#'
#' @param label (character) Human-readable label used in the legend.
#' @param color (character) Colour of the curve connecting modalities.
#' @param fn (function) Function with signature
#'   `function(a, b, otu_sp, cache)` returning a single numeric value. `a`, `b`
#'   are modality names; `otu_sp` is the species-level OTU table aggregated by
#'   modality; `cache` is the object returned by `prep` (or `NULL`).
#' @param fmt (character, default `"%.2f"`) `sprintf` format string for legend
#'   stats (min / mean / max). Use `"%.0f"` for integer counts.
#' @param prep (function, default `NULL`) Optional function
#'   `function(physeq, fact, modalities)` called once to precompute helper data
#'   shared across all pairs (e.g. genus-level aggregation). Returns an object
#'   passed as `cache` to `fn`.
#' @param bounds (numeric vector of length 2, default `NULL`) Theoretical range
#'   `c(lower, upper)` of the metric. When non-`NULL`, linewidth is scaled to
#'   `linewidth_range` using these fixed bounds, so the same metric value always
#'   maps to the same linewidth regardless of the observed data. When `NULL`,
#'   linewidth is rescaled within the observed range of values. Use
#'   `bounds = c(0, 1)` for proportions or similarities (e.g. Jaccard,
#'   Bray-Curtis).
#'
#' @return A named list with the metric definition.
#' @author Adrien Taudière
#' @seealso [default_sharing_metrics()], [community_sharing_plot()]
#' @export
#'
#' @examples
#' \dontrun{
#' # Custom metric: number of unique (non-shared) species
#' unique_sp <- make_sharing_metric(
#'   label = "Unique species count",
#'   color = "#A65628",
#'   fmt   = "%.0f",
#'   fn    = function(a, b, otu_sp, cache) {
#'     sum(xor(otu_sp[, a] > 0, otu_sp[, b] > 0))
#'   }
#' )
#'
#' # Custom metric with prep step: Sorensen similarity at Family rank
#' sor_family <- make_sharing_metric(
#'   label = "Sorensen at Family rank",
#'   color = "#F781BF",
#'   prep  = function(physeq, fact, modalities) {
#'     d_fam <- phyloseq::tax_glom(physeq, "Family", NArm = FALSE)
#'     .agg_by_mod(d_fam, fact, modalities)
#'   },
#'   fn    = function(a, b, otu_sp, cache) {
#'     1 - as.numeric(vegan::vegdist(
#'       t(cache[, c(a, b)]),
#'       method = "bray", binary = TRUE
#'     ))
#'   }
#' )
#' }
make_sharing_metric <- function(
  label,
  color,
  fn,
  fmt = "%.2f",
  prep = NULL,
  bounds = NULL
) {
  list(
    label = label,
    color = color,
    fn = fn,
    fmt = fmt,
    prep = prep,
    bounds = bounds
  )
}

################################################################################
#' Default metrics for `community_sharing_plot()`
#'
#' @description
#'
#' <a href="https://adrientaudiere.github.io/MiscMetabar/articles/Rules.html#lifecycle">
#' <img src="https://img.shields.io/badge/lifecycle-experimental-orange" alt="lifecycle-experimental"></a>
#'
#' Returns the four default metrics used by [community_sharing_plot()]: shared
#' species count, Bray-Curtis similarity, Jaccard binary similarity, and
#' proportion of shared genera.
#'
#' `bray_sim`, `jac_sim`, and `genus_prop` use `bounds = c(0, 1)` for globally
#' consistent linewidth scaling. `shared_sp` uses `bounds = NULL` (count metric
#' without a fixed upper bound; rescaled within the observed range).
#'
#' The Bray-Curtis and Jaccard metrics call \pkg{vegan}; it must be installed
#' for the default metric set.
#'
#' @return A named list of metric definitions.
#' @author Adrien Taudière
#' @seealso [make_sharing_metric()], [community_sharing_plot()]
#' @export
#'
#' @examples
#' \dontrun{
#' # Keep only a subset of the defaults
#' community_sharing_plot(
#'   data_fungi,
#'   fact    = "Height",
#'   metrics = default_sharing_metrics()[c("shared_sp", "bray_sim")]
#' )
#' }
default_sharing_metrics <- function() {
  list(
    shared_sp = make_sharing_metric(
      label = "Shared species",
      color = "#E41A1C",
      fmt = "%.0f",
      bounds = NULL,
      fn = function(a, b, otu_sp, cache) {
        sum(otu_sp[, a] > 0 & otu_sp[, b] > 0)
      }
    ),
    bray_sim = make_sharing_metric(
      label = "Bray-Curtis similarity",
      color = "#377EB8",
      fmt = "%.2f",
      bounds = c(0, 1),
      fn = function(a, b, otu_sp, cache) {
        if (!requireNamespace("vegan", quietly = TRUE)) {
          cli::cli_abort(
            "Package {.pkg vegan} is required for the Bray-Curtis metric."
          )
        }
        1 - as.numeric(vegan::vegdist(t(otu_sp[, c(a, b)]), method = "bray"))
      }
    ),
    jac_sim = make_sharing_metric(
      label = "Jaccard similarity",
      color = "#4DAF4A",
      fmt = "%.2f",
      bounds = c(0, 1),
      fn = function(a, b, otu_sp, cache) {
        if (!requireNamespace("vegan", quietly = TRUE)) {
          cli::cli_abort(
            "Package {.pkg vegan} is required for the Jaccard metric."
          )
        }
        1 -
          as.numeric(vegan::vegdist(
            t(otu_sp[, c(a, b)]),
            method = "jaccard",
            binary = TRUE
          ))
      }
    ),
    genus_prop = make_sharing_metric(
      label = "Shared genera (prop.)",
      color = "#984EA3",
      fmt = "%.2f",
      bounds = c(0, 1),
      prep = function(physeq, fact, modalities) {
        d_gen <- phyloseq::tax_glom(physeq, "Genus", NArm = FALSE)
        .agg_by_mod(d_gen, fact, modalities)
      },
      fn = function(a, b, otu_sp, cache) {
        ga <- rownames(cache)[cache[, a] > 0]
        gb <- rownames(cache)[cache[, b] > 0]
        length(intersect(ga, gb)) / length(union(ga, gb))
      }
    )
  )
}

# Internal helper: compute pairwise metrics for a given physeq + modalities.
# Returns a list with $pairs_df, $otu_sp, $caches.
.compute_pairs_df <- function(physeq, fact, modalities, metrics) {
  otu_sp <- .agg_by_mod(physeq, fact, modalities)
  caches <- lapply(metrics, function(m) {
    if (is.null(m$prep)) {
      NULL
    } else {
      m$prep(physeq, fact, modalities)
    }
  })
  pairs_df <- purrr::map_dfr(
    utils::combn(modalities, 2, simplify = FALSE),
    function(pair) {
      row <- dplyr::tibble(from = pair[1], to = pair[2])
      for (nm in names(metrics)) {
        row[[nm]] <- metrics[[nm]]$fn(pair[1], pair[2], otu_sp, caches[[nm]])
      }
      row
    }
  )
  list(pairs_df = pairs_df, otu_sp = otu_sp, caches = caches)
}

################################################################################
#' Community sharing plot: modalities as pie nodes with multi-metric links
#'
#' @description
#'
#' <a href="https://adrientaudiere.github.io/MiscMetabar/articles/Rules.html#lifecycle">
#' <img src="https://img.shields.io/badge/lifecycle-experimental-orange" alt="lifecycle-experimental"></a>
#'
#' Draws a figure with one node per modality of `fact` (2 to 4 supported),
#' positioned on a regular polygon. Each node is a pie chart showing the
#' taxonomic composition at rank `pie_taxrank`. Between each pair of nodes, one
#' curved link per metric is drawn; linewidth is rescaled within each metric to
#' `linewidth_range`. A legend below the figure gives each metric's min / mean /
#' max over all pairs.
#'
#' @param physeq (required) A [phyloseq::phyloseq-class] object.
#' @param fact (required, character) Name of a `sample_data(physeq)` column used
#'   to group samples into modalities. Must have 2 to 4 unique values.
#' @param metrics (named list, default [default_sharing_metrics()]) Metric
#'   definitions. See [default_sharing_metrics()] and [make_sharing_metric()].
#' @param pie_taxrank (character, default `"Class"`) Taxonomic rank for the pie
#'   charts.
#' @param pie_r (numeric, default `0.28`) Pie radius in data units.
#' @param label_offset (numeric, default `0.18`) Distance between pie edge and
#'   node label.
#' @param curvature_range (numeric of length 2, default `c(-0.35, 0.35)`) Range
#'   of [ggplot2::geom_curve()] curvatures used to fan out metrics between a
#'   pair of nodes. The sign is flipped per pair so that the first metric always
#'   fans toward the plot centre (and the last toward the border).
#' @param linewidth_range (numeric of length 2, default `c(0.8, 4.5)`)
#'   `linewidth_range[1]` corresponds to the weakest similarity,
#'   `linewidth_range[2]` to the strongest. For bounded metrics
#'   (`bounds = c(0, 1)`), the mapping is global across runs; for unbounded
#'   metrics it is scaled within the observed range.
#' @param n_perm (integer, default `0`) Number of label-permutation iterations
#'   for significance testing. `0` disables the test. See Details.
#' @param sig_threshold (numeric in `(0, 1)`, default `0.05`) p-value threshold
#'   below which a link is considered significant. Only used when `n_perm > 0`.
#' @param nonsig_alpha (numeric in `[0, 1]`, default `0.15`) Alpha applied to
#'   non-significant links. Significant links keep alpha `0.75`. Only used when
#'   `n_perm > 0`.
#' @param seed (integer or `NULL`, default `NULL`) Passed to [set.seed()] before
#'   the permutation loop for reproducibility.
#' @param palette (character, default `"Set3"`) Either the name of an
#'   RColorBrewer qualitative palette or a character vector of fill colours for
#'   the top taxa.
#' @param max_taxa (integer, default `12`) Keep colours for the `max_taxa` most
#'   abundant taxa (summed across modalities) and collapse the rest into an
#'   `"Other"` category filled with `other_color`.
#' @param other_color (character, default `"grey70"`) Fill colour for `"Other"`.
#' @param show_na_modality (logical, default `FALSE`) If `TRUE`, samples whose
#'   `fact` value is `NA` are grouped into an extra `"NA"` modality. The total
#'   number of modalities (including `"NA"`) must still be between 2 and 4.
#' @param show_na (logical, default `TRUE`) If `TRUE`, taxa with an `NA`/empty
#'   value at `pie_taxrank` are shown as a dedicated `"NA"` category filled with
#'   `na_color`. If `FALSE`, they are dropped.
#' @param na_color (character, default `"grey40"`) Fill colour for the `"NA"`
#'   taxonomic category.
#' @param pie_border_color (character, default `"black"`) Colour of the circle
#'   drawn around each pie.
#' @param pie_border_width (numeric, default `0.6`) Linewidth of the pie border.
#' @param title (character, default `NULL`) Plot title.
#' @param base_size (numeric, default `12`) Base font size.
#'
#' @details
#' **Permutation null model.** When `n_perm > 0`, significance is assessed by
#' label permutation: the `fact` column in `sample_data(physeq)` is shuffled
#' uniformly at random among samples (preserving group sizes), then all `prep()`
#' functions and metric computations are re-run on the permuted data. This is
#' repeated `n_perm` times. The empirical p-value for each pair x metric
#' combination is the proportion of permuted values greater than or equal to the
#' observed value (one-sided upper-tail test). Non-significant links are drawn
#' with alpha `nonsig_alpha` (faded); significant links use alpha `0.75`.
#'
#' **Performance.** Each permutation re-runs all `prep()` functions. For metrics
#' that call [phyloseq::tax_glom()] (e.g. `genus_prop`), this can be slow on
#' large datasets. Recommended range: `n_perm = 99` to `n_perm = 199`.
#'
#' @return A [ggplot2::ggplot] object.
#' @author Adrien Taudière
#' @seealso [community_sharing_barplot()], [make_sharing_metric()],
#'   [default_sharing_metrics()]
#' @export
#'
#' @examples
#' \donttest{
#' data(data_fungi_mini, package = "MiscMetabar")
#' pkgs <- c("ggforce", "purrr", "tidyr", "scales", "RColorBrewer", "vegan")
#' if (all(vapply(pkgs, requireNamespace, logical(1), quietly = TRUE))) {
#'   # Default: 4 metrics, pie charts at Class rank, Height has 3 modalities
#'   community_sharing_plot(data_fungi_mini, fact = "Height")
#' }
#' }
#' \dontrun{
#' # Only show a single metric (Jaccard)
#' community_sharing_plot(
#'   data_fungi_mini,
#'   fact    = "Height",
#'   metrics = default_sharing_metrics()["jac_sim"]
#' )
#'
#' # Use Phylum rank for the pie charts and a different palette
#' community_sharing_plot(
#'   data_fungi_mini,
#'   fact        = "Height",
#'   pie_taxrank = "Phylum",
#'   palette     = "Set2",
#'   max_taxa    = 8
#' )
#'
#' # Include samples with NA height as a fourth modality
#' community_sharing_plot(data_fungi_mini, fact = "Height", show_na_modality = TRUE)
#'
#' # Permutation significance test (99 permutations, faded non-sig links)
#' community_sharing_plot(data_fungi_mini, fact = "Height", n_perm = 99, seed = 42)
#' }
community_sharing_plot <- function(
  physeq,
  fact,
  metrics = default_sharing_metrics(),
  pie_taxrank = "Class",
  pie_r = 0.28,
  label_offset = 0.18,
  curvature_range = c(-0.35, 0.35),
  linewidth_range = c(0.8, 4.5),
  n_perm = 0,
  sig_threshold = 0.05,
  nonsig_alpha = 0.15,
  seed = NULL,
  palette = "Set3",
  max_taxa = 12,
  other_color = "grey70",
  show_na_modality = FALSE,
  show_na = TRUE,
  na_color = "grey40",
  pie_border_color = "black",
  pie_border_width = 0.6,
  title = NULL,
  base_size = 12
) {
  for (pkg in c("ggforce", "purrr", "tidyr", "scales", "RColorBrewer")) {
    if (!requireNamespace(pkg, quietly = TRUE)) {
      cli::cli_abort(
        "Package {.pkg {pkg}} is required for {.fn community_sharing_plot}."
      )
    }
  }

  sd <- as.data.frame(phyloseq::sample_data(physeq))
  if (!fact %in% colnames(sd)) {
    cli::cli_abort(
      "Column {.val {fact}} not found in {.code sample_data(physeq)}."
    )
  }

  fact_values <- sd[[fact]]

  # Promote NA samples to an explicit "NA" modality when requested
  if (show_na_modality && anyNA(fact_values)) {
    fact_values <- ifelse(is.na(fact_values), "NA", as.character(fact_values))
    sd[[fact]] <- fact_values
    phyloseq::sample_data(physeq) <- phyloseq::sample_data(sd)
  }

  modalities <- if (is.factor(fact_values)) {
    levels(droplevels(fact_values))
  } else {
    sort(unique(stats::na.omit(fact_values)))
  }
  n_mod <- length(modalities)
  if (n_mod < 2 || n_mod > 4) {
    cli::cli_abort("Number of modalities must be between 2 and 4, not {n_mod}.")
  }

  # -- Node positions ---------------------------------------------------------
  angles <- .sharing_angles(n_mod) * pi / 180
  n_per_mod <- as.data.frame(table(fact_values))
  colnames(n_per_mod) <- c("name", "n")
  n_per_mod$name <- as.character(n_per_mod$name)

  nodes <- dplyr::tibble(
    name = modalities,
    x = cos(angles),
    y = sin(angles)
  ) |>
    dplyr::left_join(n_per_mod, by = "name") |>
    dplyr::mutate(
      label_r = 1 + pie_r + label_offset,
      x_label = x * label_r,
      y_label = y * label_r,
      hjust = dplyr::case_when(abs(x) < 0.1 ~ 0.5, x > 0 ~ 0, TRUE ~ 1),
      vjust = dplyr::case_when(y > 0.3 ~ 0, y < -0.3 ~ 1, TRUE ~ 0.5),
      node_label = paste0(name, "\n(n=", n, ")")
    )

  # -- Pairwise metric computation --------------------------------------------
  res <- .compute_pairs_df(physeq, fact, modalities, metrics)
  pairs_df <- res$pairs_df

  # -- Permutation significance test ------------------------------------------
  if (n_perm > 0) {
    if (!is.null(seed)) {
      set.seed(seed)
    }
    obs_mat <- as.matrix(pairs_df[, names(metrics)])
    perm_vals <- array(NA_real_, c(n_perm, nrow(pairs_df), length(metrics)))

    cli::cli_progress_bar("Permutations", total = n_perm, clear = FALSE)
    for (i in seq_len(n_perm)) {
      ps_perm <- physeq
      sd_perm <- as.data.frame(phyloseq::sample_data(physeq))
      sd_perm[[fact]] <- sample(sd_perm[[fact]])
      phyloseq::sample_data(ps_perm) <- phyloseq::sample_data(sd_perm)
      res_perm <- .compute_pairs_df(ps_perm, fact, modalities, metrics)
      perm_vals[i, , ] <- as.matrix(res_perm$pairs_df[, names(metrics)])
      cli::cli_progress_update()
    }
    cli::cli_progress_done()

    pval_mat <- matrix(
      NA_real_,
      nrow = nrow(pairs_df),
      ncol = length(metrics),
      dimnames = list(NULL, paste0("pval_", names(metrics)))
    )
    for (j in seq_along(metrics)) {
      for (k in seq_len(nrow(pairs_df))) {
        pval_mat[k, j] <- mean(perm_vals[, k, j] >= obs_mat[k, j])
      }
    }
    pairs_df <- dplyr::bind_cols(pairs_df, as.data.frame(pval_mat))
  }

  # -- Metric metadata (color, curvature, format, bounds) ---------------------
  n_met <- length(metrics)
  curvatures <- if (n_met == 1) {
    0
  } else {
    seq(curvature_range[1], curvature_range[2], length.out = n_met)
  }
  metric_meta <- dplyr::tibble(
    metric = names(metrics),
    label = vapply(metrics, function(m) m$label, character(1)),
    color = vapply(metrics, function(m) m$color, character(1)),
    fmt = vapply(metrics, function(m) m$fmt, character(1)),
    curvature = curvatures,
    bounds = lapply(metrics, function(m) m$bounds)
  )

  # -- Link data --------------------------------------------------------------
  # bounds-aware rescale: when from is supplied use global range, otherwise
  # fall back to the observed range (or midpoint for constant values).
  safe_rescale <- function(x, to, from = NULL) {
    if (!is.null(from)) {
      scales::rescale(x, to = to, from = from)
    } else if (length(unique(x)) < 2) {
      rep(mean(to), length(x))
    } else {
      scales::rescale(x, to = to)
    }
  }
  link_df <- pairs_df |>
    tidyr::pivot_longer(
      dplyr::all_of(names(metrics)),
      names_to = "metric",
      values_to = "raw_value"
    ) |>
    dplyr::left_join(metric_meta, by = "metric") |>
    dplyr::left_join(
      dplyr::select(nodes, name, x, y),
      by = c("from" = "name")
    ) |>
    dplyr::rename(x_from = x, y_from = y) |>
    dplyr::left_join(dplyr::select(nodes, name, x, y), by = c("to" = "name")) |>
    dplyr::rename(x_to = x, y_to = y) |>
    dplyr::mutate(
      met_idx = match(metric, names(metrics)),
      # Flip curvature per pair so that metric 1 always sits closest to the
      # plot centre (and metric n closest to the border), regardless of which
      # side of the plot the pair is on.
      pair_flip = {
        dx <- x_to - x_from
        dy <- y_to - y_from
        mx <- (x_from + x_to) / 2
        my <- (y_from + y_to) / 2
        ifelse(dx * my - dy * mx > 0, -1, 1)
      },
      curvature_pair = curvature * pair_flip
    ) |>
    dplyr::group_by(metric) |>
    dplyr::mutate(
      lw = safe_rescale(raw_value, linewidth_range, from = bounds[[1]])
    ) |>
    dplyr::ungroup()

  # Add significance flag
  if (n_perm > 0) {
    pval_long <- pairs_df |>
      dplyr::select(from, to, dplyr::starts_with("pval_")) |>
      tidyr::pivot_longer(
        dplyr::starts_with("pval_"),
        names_to = "metric",
        values_to = "pval",
        names_prefix = "pval_"
      )
    link_df <- dplyr::left_join(
      link_df,
      pval_long,
      by = c("from", "to", "metric")
    ) |>
      dplyr::mutate(significant = pval < sig_threshold)
  } else {
    link_df <- dplyr::mutate(link_df, significant = TRUE)
  }

  # -- Legend (min / mean / max) ----------------------------------------------
  legend_y0 <- -1.4
  legend_step <- -0.18
  # Row 0 is reserved for the "Metrics" header; metric rows start at row 1.
  legend_df <- pairs_df |>
    tidyr::pivot_longer(
      dplyr::all_of(names(metrics)),
      names_to = "metric",
      values_to = "value"
    ) |>
    dplyr::group_by(metric) |>
    dplyr::summarise(
      vmin = min(value),
      vmean = mean(value),
      vmax = max(value),
      .groups = "drop"
    ) |>
    dplyr::left_join(metric_meta, by = "metric") |>
    dplyr::arrange(match(metric, metric_meta$metric)) |>
    dplyr::mutate(
      stats_label = purrr::pmap_chr(
        list(label, fmt, vmin, vmean, vmax),
        function(lbl, f, mn, me, mx) {
          sprintf(
            paste0("%s  [min: ", f, "  mean: ", f, "  max: ", f, "]"),
            lbl,
            mn,
            me,
            mx
          )
        }
      ),
      x = -1.65,
      xend = -1.35,
      y = legend_y0 + legend_step * dplyr::row_number(),
      yend = y
    )

  # -- Pie charts (composition at rank `pie_taxrank`) -------------------------
  d_rank <- phyloseq::tax_glom(physeq, pie_taxrank, NArm = FALSE)
  otu_rank <- .agg_by_mod(d_rank, fact, modalities)
  taxa_lab <- as.character(phyloseq::tax_table(d_rank)[
    rownames(otu_rank),
    pie_taxrank
  ])

  na_mask <- is.na(taxa_lab) | taxa_lab == ""
  if (show_na) {
    taxa_lab[na_mask] <- "NA"
  } else {
    otu_rank <- otu_rank[!na_mask, , drop = FALSE]
    taxa_lab <- taxa_lab[!na_mask]
  }
  rownames(otu_rank) <- taxa_lab

  # Collapse rare taxa into "Other" (NA kept aside as its own category)
  real_taxa <- setdiff(rownames(otu_rank), "NA")
  total_abund <- rowSums(otu_rank[real_taxa, , drop = FALSE])
  n_keep <- min(max_taxa, length(real_taxa))
  top_n <- names(sort(total_abund, decreasing = TRUE))[seq_len(n_keep)]

  is_other <- !(rownames(otu_rank) %in% c(top_n, "NA"))
  if (any(is_other)) {
    other_row <- colSums(otu_rank[is_other, , drop = FALSE])
    otu_rank <- rbind(otu_rank[!is_other, , drop = FALSE], Other = other_row)
  }

  tax_order <- c(
    top_n,
    if ("Other" %in% rownames(otu_rank)) {
      "Other"
    },
    if ("NA" %in% rownames(otu_rank)) {
      "NA"
    }
  )
  otu_rank <- otu_rank[tax_order, , drop = FALSE]

  pie_df <- as.data.frame(otu_rank) |>
    tibble::rownames_to_column(pie_taxrank) |>
    tidyr::pivot_longer(
      -dplyr::all_of(pie_taxrank),
      names_to = "modality",
      values_to = "count"
    ) |>
    dplyr::filter(count > 0) |>
    dplyr::group_by(modality) |>
    dplyr::mutate(prop = count / sum(count)) |>
    dplyr::ungroup() |>
    dplyr::left_join(
      dplyr::select(nodes, name, x, y),
      by = c("modality" = "name")
    ) |>
    dplyr::mutate(
      !!pie_taxrank := factor(.data[[pie_taxrank]], levels = tax_order)
    )

  # -- geom_curve layers (one per metric x pair_flip x significant) -----------
  # Curvature and alpha are per-layer constants, so we must split on both.
  # When n_perm = 0, significant = TRUE for all rows -> same layers as before.
  make_curve_layers <- function(m) {
    sub <- dplyr::filter(link_df, metric == m)
    meta <- dplyr::filter(metric_meta, metric == m)
    combos <- unique(sub[, c("pair_flip", "significant")])
    lapply(seq_len(nrow(combos)), function(i) {
      flip <- combos$pair_flip[i]
      sig <- combos$significant[i]
      d <- dplyr::filter(sub, pair_flip == flip, significant == sig)
      ggplot2::geom_curve(
        data = d,
        ggplot2::aes(
          x = x_from,
          y = y_from,
          xend = x_to,
          yend = y_to,
          linewidth = lw
        ),
        color = meta$color,
        curvature = meta$curvature * flip,
        alpha = if (sig) {
          0.75
        } else {
          nonsig_alpha
        },
        lineend = "round"
      )
    })
  }

  top_colors <- if (
    length(palette) == 1 && palette %in% rownames(RColorBrewer::brewer.pal.info)
  ) {
    max_n <- RColorBrewer::brewer.pal.info[palette, "maxcolors"]
    n_use <- max(3, min(length(top_n), max_n))
    cols <- RColorBrewer::brewer.pal(n_use, palette)[seq_len(min(
      length(top_n),
      max_n
    ))]
    if (length(top_n) > max_n) {
      cols <- grDevices::colorRampPalette(cols)(length(top_n))
    }
    cols
  } else {
    rep(palette, length.out = length(top_n))
  }
  names(top_colors) <- top_n
  fill_values <- top_colors
  if ("Other" %in% tax_order) {
    fill_values <- c(fill_values, Other = other_color)
  }
  if ("NA" %in% tax_order) {
    fill_values <- c(fill_values, "NA" = na_color)
  }
  fill_scale <- ggplot2::scale_fill_manual(
    values = fill_values,
    breaks = tax_order,
    name = pie_taxrank
  )

  # -- Significance legend (only when permutations were run) ------------------
  if (n_perm > 0) {
    perm_header_y <- legend_y0 + legend_step * (n_met + 1.5)
    perm_desc_y <- legend_y0 + legend_step * (n_met + 2.5)
    sig_rows_y <- legend_y0 + legend_step * (n_met + c(3.5, 4.5))

    perm_desc <- sprintf(
      "%d label permutations (group sizes preserved); p = prop(perm ≥ obs)",
      n_perm
    )

    sig_legend_df <- dplyr::tibble(
      label = c(
        sprintf("p < %g — significant", sig_threshold),
        sprintf("p ≥ %g — not significant", sig_threshold)
      ),
      y = sig_rows_y,
      sig = c(TRUE, FALSE)
    )
    y_bottom <- sig_rows_y[2] - 0.15
  } else {
    perm_header_y <- NULL
    perm_desc_y <- NULL
    perm_desc <- NULL
    sig_legend_df <- NULL
    y_bottom <- legend_y0 + legend_step * n_met - 0.15
  }
  y_top <- 1 + pie_r + label_offset + 0.25

  p <- ggplot2::ggplot()
  for (nm in names(metrics)) {
    for (layer in make_curve_layers(nm)) {
      p <- p + layer
    }
  }

  p +
    ggforce::geom_arc_bar(
      data = pie_df,
      ggplot2::aes(
        x0 = x,
        y0 = y,
        r0 = 0,
        r = pie_r,
        amount = prop,
        fill = .data[[pie_taxrank]]
      ),
      stat = "pie",
      color = "white",
      linewidth = 0.3
    ) +
    ggforce::geom_circle(
      data = nodes,
      ggplot2::aes(x0 = x, y0 = y, r = pie_r),
      color = pie_border_color,
      fill = NA,
      linewidth = pie_border_width,
      inherit.aes = FALSE
    ) +
    ggplot2::scale_linewidth_identity() +
    ggplot2::geom_text(
      data = nodes,
      ggplot2::aes(
        x = x_label,
        y = y_label,
        label = node_label,
        hjust = hjust,
        vjust = vjust
      ),
      fontface = "bold",
      size = 4,
      lineheight = 0.9
    ) +
    # -- "Metrics" sub-legend header ------------------------------------------
    ggplot2::annotate(
      "text",
      x = -1.65,
      y = legend_y0,
      label = "Metrics of similarity (higher = more similar)",
      hjust = 0,
      vjust = 0.5,
      fontface = "bold",
      size = 3.2,
      color = "gray20"
    ) +
    ggplot2::geom_segment(
      data = legend_df,
      ggplot2::aes(x = x, xend = xend, y = y, yend = yend),
      color = legend_df$color,
      linewidth = 1.8
    ) +
    ggplot2::geom_text(
      data = legend_df,
      ggplot2::aes(x = xend + 0.06, y = y, label = stats_label),
      hjust = 0,
      size = 3,
      color = "gray30"
    ) +
    # -- "Permutations" sub-legend --------------------------------------------
    (if (!is.null(sig_legend_df)) {
      list(
        ggplot2::annotate(
          "text",
          x = -1.65,
          y = perm_header_y,
          label = "Permutations",
          hjust = 0,
          vjust = 0.5,
          fontface = "bold",
          size = 3.2,
          color = "gray20"
        ),
        ggplot2::annotate(
          "text",
          x = -1.65,
          y = perm_desc_y,
          label = perm_desc,
          hjust = 0,
          vjust = 0.5,
          fontface = "italic",
          size = 2.6,
          color = "gray40"
        ),
        ggplot2::geom_segment(
          data = dplyr::filter(sig_legend_df, sig),
          ggplot2::aes(x = -1.65, xend = -1.35, y = y, yend = y),
          color = "grey30",
          linewidth = 1.8,
          alpha = 0.75
        ),
        ggplot2::geom_segment(
          data = dplyr::filter(sig_legend_df, !sig),
          ggplot2::aes(x = -1.65, xend = -1.35, y = y, yend = y),
          color = "grey30",
          linewidth = 1.8,
          alpha = nonsig_alpha
        ),
        ggplot2::geom_text(
          data = sig_legend_df,
          ggplot2::aes(x = -1.29, y = y, label = label),
          hjust = 0,
          size = 3,
          color = "gray30"
        )
      )
    } else {
      list()
    }) +
    fill_scale +
    ggplot2::coord_equal(xlim = c(-1.9, 1.9), ylim = c(y_bottom, y_top)) +
    ggplot2::theme_void(base_size = base_size) +
    ggplot2::labs(title = title) +
    ggplot2::theme(
      plot.title = ggplot2::element_text(face = "bold", hjust = 0.5, size = 13),
      plot.margin = ggplot2::margin(10, 10, 10, 10),
      legend.position = "right",
      legend.title = ggplot2::element_text(face = "bold", size = 9),
      legend.text = ggplot2::element_text(size = 8),
      legend.key.size = ggplot2::unit(0.4, "cm")
    )
}

################################################################################
#' Companion bar chart for `community_sharing_plot()`
#'
#' @description
#'
#' <a href="https://adrientaudiere.github.io/MiscMetabar/articles/Rules.html#lifecycle">
#' <img src="https://img.shields.io/badge/lifecycle-experimental-orange" alt="lifecycle-experimental"></a>
#'
#' Computes the same pairwise metrics as [community_sharing_plot()] and displays
#' them as grouped bars, with **one panel per metric** and a free y-axis. Each
#' metric is therefore compared across pairs on its own scale, which matters
#' because metrics live on incomparable scales (e.g. a shared-species count
#' dwarfs a Bray-Curtis similarity in `[0, 1]`). Useful for precise numerical
#' comparison alongside the network figure.
#'
#' @param physeq (required) A [phyloseq::phyloseq-class] object.
#' @param fact (required, character) Name of a `sample_data(physeq)` column.
#'   Must have 2 to 4 unique values.
#' @param metrics (named list, default [default_sharing_metrics()]) Metric
#'   definitions from [make_sharing_metric()].
#' @param show_na_modality (logical, default `FALSE`) Same meaning as in
#'   [community_sharing_plot()].
#' @param base_size (numeric, default `12`) Base font size.
#' @param title (character, default `NULL`) Plot title.
#'
#' @return A [ggplot2::ggplot] object.
#' @author Adrien Taudière
#' @seealso [community_sharing_plot()]
#' @export
#'
#' @examples
#' \donttest{
#' data(data_fungi_mini, package = "MiscMetabar")
#' if (all(vapply(c("purrr", "tidyr", "vegan"), requireNamespace,
#'   logical(1), quietly = TRUE))) {
#'   # One panel per metric, pairs on the x-axis, free y-scale per metric
#'   community_sharing_barplot(data_fungi_mini, fact = "Height")
#' }
#' }
community_sharing_barplot <- function(
  physeq,
  fact,
  metrics = default_sharing_metrics(),
  show_na_modality = FALSE,
  base_size = 12,
  title = NULL
) {
  for (pkg in c("purrr", "tidyr")) {
    if (!requireNamespace(pkg, quietly = TRUE)) {
      cli::cli_abort(
        "Package {.pkg {pkg}} is required for {.fn community_sharing_barplot}."
      )
    }
  }

  # -- Resolve modalities -----------------------------------------------------
  sd <- as.data.frame(phyloseq::sample_data(physeq))
  if (!fact %in% colnames(sd)) {
    cli::cli_abort(
      "Column {.val {fact}} not found in {.code sample_data(physeq)}."
    )
  }
  fact_values <- sd[[fact]]
  if (show_na_modality && anyNA(fact_values)) {
    fact_values <- ifelse(is.na(fact_values), "NA", as.character(fact_values))
    sd[[fact]] <- fact_values
    phyloseq::sample_data(physeq) <- phyloseq::sample_data(sd)
  }
  modalities <- if (is.factor(fact_values)) {
    levels(droplevels(fact_values))
  } else {
    sort(unique(stats::na.omit(fact_values)))
  }
  n_mod <- length(modalities)
  if (n_mod < 2 || n_mod > 4) {
    cli::cli_abort("Number of modalities must be between 2 and 4, not {n_mod}.")
  }

  # -- Compute pairwise metrics -----------------------------------------------
  pairs_df <- .compute_pairs_df(physeq, fact, modalities, metrics)$pairs_df

  # -- Build long data for plotting -------------------------------------------
  metric_colors <- stats::setNames(
    vapply(metrics, function(m) m$color, character(1)),
    names(metrics)
  )
  metric_labels <- stats::setNames(
    vapply(metrics, function(m) m$label, character(1)),
    names(metrics)
  )

  plot_df <- pairs_df |>
    dplyr::mutate(pair = paste0(from, " — ", to)) |>
    tidyr::pivot_longer(
      dplyr::all_of(names(metrics)),
      names_to = "metric",
      values_to = "value"
    ) |>
    dplyr::mutate(
      metric_label = factor(metric_labels[metric], levels = metric_labels)
    )

  color_scale <- ggplot2::scale_fill_manual(
    values = stats::setNames(metric_colors, metric_labels[names(metric_colors)])
  )

  base_theme <- ggplot2::theme_bw(base_size = base_size) +
    ggplot2::theme(
      strip.background = ggplot2::element_blank(),
      strip.text = ggplot2::element_text(face = "bold"),
      legend.position = "none",
      axis.text.x = ggplot2::element_text(angle = 30, hjust = 1)
    )

  # One panel per metric (free y-scale) so each metric is compared across pairs
  # on its own scale; metrics live on incomparable scales and must not share an
  # axis.
  ggplot2::ggplot(
    plot_df,
    ggplot2::aes(x = pair, y = value, fill = metric_label)
  ) +
    ggplot2::geom_col(alpha = 0.85) +
    ggplot2::facet_wrap(~metric_label, scales = "free_y") +
    color_scale +
    ggplot2::labs(x = NULL, y = "Metric value", title = title) +
    base_theme
}
