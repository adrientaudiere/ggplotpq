################################################################################
#' Distance of every sample to a reference (control) sample set
#'
#' @description
#'
#' <a href="https://adrientaudiere.github.io/MiscMetabar/articles/Rules.html#lifecycle">
#' <img src="https://img.shields.io/badge/lifecycle-experimental-orange" alt="lifecycle-experimental"></a>
#'
#' Compute the community dissimilarity (default Bray-Curtis) between every
#' sample and a **reference** (e.g. a control), then visualize and test which
#' kinds of samples sit closest to that reference. The reference is either a
#' single sample given by name (`ref_sample`) or a set of samples flagged in
#' `sample_data` (`ref_fact` + `ref_value`); with several references, the
#' per-sample distance to the set is aggregated with `ref_agg`.
#'
#' Four complementary views are returned:
#'
#' 1. a violin + jitter plot of the distance to the reference per level of
#'    `fact` (levels ordered from closest to farthest), with a Kruskal-Wallis
#'    test reported in the subtitle;
#' 2. a ranked lollipop of all samples (closest to the reference first);
#' 3. a **global** ordination (context): all samples, with the `n_nearest`
#'    closest ones highlighted and joined to the reference by spokes;
#' 4. a **local** ordination recomputed on the `n_nearest` closest samples
#'    only, revealing the structure *among* the close samples (a global
#'    ordination is dominated by distances between far samples and is often
#'    uninformative for the reference question).
#'
#' @param physeq (required) A [phyloseq::phyloseq-class] object. An OTU table
#'   and sample data are required; a phylogenetic tree is required only for
#'   tree-based distances (e.g. UniFrac).
#' @param fact (default NULL) Name of a categorical column of `sam_data` used
#'   to group and color samples. With at least 2 levels among non-reference
#'   samples, modalities are ranked by proximity to the reference
#'   (`rank_table`) and compared with a Kruskal-Wallis test.
#' @param ref_fact (default NULL) Name of the column in `physeq@sam_data`
#'   flagging the reference samples: a sample is a reference when its value in
#'   `ref_fact` equals `ref_value`. Supports one or several references.
#' @param ref_sample (default NULL) A single sample name (in
#'   [phyloseq::sample_names()]) used as the reference. Exactly one of
#'   `ref_sample` or `ref_fact` must be supplied.
#' @param ref_value (default `TRUE`) Value of `ref_fact` marking a reference
#'   sample. Keep the default for a logical `TRUE`/`FALSE` column, or pass the
#'   code used in a character/factor column (e.g. `"control"`).
#' @param ref_agg (default `"mean"`) How to summarise the distance of a sample
#'   to several reference samples: `"mean"`, `"median"` or `"min"`. Ignored
#'   with a single reference sample.
#' @param method (default `"bray"`) Dissimilarity index. Any
#'   [phyloseq::distance()] method (e.g. `"bray"`, `"jaccard"`, `"unifrac"`,
#'   `"wunifrac"`; see [phyloseq::distanceMethodList()]) plus `"aitchison"`
#'   and `"robust.aitchison"` computed with [vegan::vegdist()].
#' @param ordination_method (default `"PCoA"`) Ordination method passed to
#'   [phyloseq::ordinate()] for the two ordination plots (e.g. `"PCoA"`,
#'   `"NMDS"`). Axis labels report the percentage of variance explained for
#'   `"PCoA"` only.
#' @param n_nearest (default 20) Number of non-reference samples closest to
#'   the reference highlighted in the global ordination and kept in the
#'   local ordination (the reference samples are always added on top). Must
#'   be >= 3.
#' @param show_ref (default TRUE) If TRUE, reference samples are drawn in
#'   the violin and lollipop plots (red points at distance 0). If FALSE,
#'   they are hidden and the distance axis is zoomed on the range of
#'   non-reference samples, making the differences among them easier to
#'   read.
#'
#' @return A named list with:
#'   - `dist_table`: a tibble with one row per sample (`sample_name`,
#'     `dist_to_ref` — 0 for reference samples) and all `sample_data`
#'     columns;
#'   - `rank_table`: the levels of `fact` ranked from closest to farthest
#'     (`n`, `dist_mean`, `dist_sd`, `dist_median`), computed on
#'     non-reference samples; `NULL` when `fact` is `NULL`;
#'   - `kw`: the Kruskal-Wallis test of `dist_to_ref ~ fact` on
#'     non-reference samples (`NULL` when `fact` is `NULL` or has fewer than
#'     two levels with data);
#'   - `ref_samples`: character vector of the reference sample names;
#'   - `plots`: a list of four ggplots (`violin`, `lollipop`, `pcoa_global`,
#'     `pcoa_local`);
#'   - `dist`: the full `dist` object, for reuse.
#'
#' @details
#' No normalisation is done inside the function: rarefy or transform `physeq`
#' beforehand if needed (e.g. [phyloseq::rarefy_even_depth()] or
#' [phyloseq::transform_sample_counts()]).
#'
#' Distances to a shared reference are not independent, which is why the
#' non-parametric Kruskal-Wallis test is used. With a single reference sample
#' the ranking is robust but there is no replication of the reference to
#' estimate its own variability: treat small gaps between neighbouring
#' modalities with care (a resampling wrapper may come to `bootpq`).
#'
#' The violin density is boundary-corrected to `[0, 1]` for distances known
#' to be bounded (`"bray"`, `"jaccard"`, `"unifrac"`, `"wunifrac"`,
#' `"sorensen"`) via `geom_violin(bounds = c(0, 1))` when every modality has
#' at least two distinct values; other metrics fall back to trimming the
#' violin to the observed data range.
#'
#' @export
#' @author Adrien Taudière
#'
#' @examples
#' res <- plot_samples_dist2ref_pq(data_fungi_mini, ref_sample = ref, fact = "Height")
#' res$rank_table # first row = modality closest to the reference
#' res$plots$violin
#' res$plots$lollipop
#' res$plots$pcoa_global
#' res$plots$pcoa_local
#'
#' # Reference set flagged in sample_data, distance to the nearest reference
#' phyloseq::sample_data(data_fungi_mini)$is_ref <-
#'   phyloseq::get_variable(data_fungi_mini, "Diameter") == "115,5"
#' res2 <- plot_samples_dist2ref_pq(
#'   data_fungi_mini,
#'   ref_fact = "is_ref",
#'   ref_agg = "min",
#'   fact = "Height"
#' )
#' res2$rank_table
#' \dontrun{
#' # Compositional distance and a tighter local ordination
#' res3 <- plot_samples_dist2ref_pq(
#'   data_fungi_mini,
#'   ref_sample = ref,
#'   fact = "Height",
#'   method = "robust.aitchison",
#'   n_nearest = 10
#' )
#' }
plot_samples_dist2ref_pq <- function(
  physeq,
  fact = NULL,
  ref_fact = NULL,
  ref_sample = NULL,
  ref_value = TRUE,
  ref_agg = c("mean", "median", "min"),
  method = "bray",
  ordination_method = "PCoA",
  n_nearest = 20,
  show_ref = TRUE
) {
  MiscMetabar::verify_pq(physeq)
  ref_agg <- match.arg(ref_agg)

  # ---- reference specification: exactly one of ref_sample / ref_fact -------
  if (is.null(ref_sample) && is.null(ref_fact)) {
    cli::cli_abort(
      "One of {.arg ref_sample} or {.arg ref_fact} must be supplied."
    )
  }
  if (!is.null(ref_sample) && !is.null(ref_fact)) {
    cli::cli_abort(
      "Only one of {.arg ref_sample} or {.arg ref_fact} may be supplied, not both."
    )
  }
  if (!is.null(fact)) {
    MiscMetabar::verify_fact_pq(physeq, fact = fact)
  }
  if (length(n_nearest) != 1 || n_nearest < 3) {
    cli::cli_abort("{.arg n_nearest} must be a single number >= 3.")
  }
  if (phyloseq::nsamples(physeq) < 3) {
    cli::cli_abort(
      "{.arg physeq} must have at least 3 samples for ordination plots."
    )
  }

  # ---- identify reference samples -------------------------------------------
  if (!is.null(ref_sample)) {
    if (!is.character(ref_sample) || length(ref_sample) != 1) {
      cli::cli_abort("{.arg ref_sample} must be a single sample name.")
    }
    if (!ref_sample %in% phyloseq::sample_names(physeq)) {
      cli::cli_abort(
        c(
          "{.arg ref_sample} {.val {ref_sample}} is not in {.fn phyloseq::sample_names}.",
          "i" = "First sample names: {.val {head(phyloseq::sample_names(physeq), 3)}}"
        )
      )
    }
    ref_samples <- ref_sample
  } else {
    if (!ref_fact %in% colnames(phyloseq::sample_data(physeq))) {
      cli::cli_abort(
        "{.arg ref_fact} {.val {ref_fact}} is not a column of {.field sam_data}."
      )
    }
    ref_flag <- phyloseq::get_variable(physeq, ref_fact) == ref_value
    ref_flag[is.na(ref_flag)] <- FALSE
    ref_samples <- phyloseq::sample_names(physeq)[ref_flag]
    if (length(ref_samples) == 0) {
      cli::cli_abort(
        "No reference sample found: no value of {.arg ref_fact} equal to {.val {ref_value}}."
      )
    }
  }
  n_refs <- length(ref_samples)

  # ---- distance of each sample to the reference set --------------------------
  dist_obj <- .dist_matrix_pq(physeq, method)
  dist_mat <- as.matrix(dist_obj)

  agg_fun <- switch(ref_agg, mean = mean, median = stats::median, min = min)
  all_samples <- phyloseq::sample_names(physeq)
  dist_to_ref <- vapply(
    all_samples,
    function(s) {
      if (s %in% ref_samples) {
        return(0)
      }
      agg_fun(dist_mat[s, ref_samples])
    },
    numeric(1L)
  )

  sam <- as.data.frame(phyloseq::sample_data(physeq))
  sam$sample_name <- rownames(sam)
  dist_table <- tibble::tibble(
    sample_name = all_samples,
    dist_to_ref = as.numeric(dist_to_ref)
  ) |>
    dplyr::left_join(sam, by = "sample_name")
  # Dot-prefixed flag to avoid colliding with a sam_data column (e.g. the
  # `is_ref` flag column used by the ref_fact interface).
  dist_table$.is_ref <- all_samples %in% ref_samples

  # ---- ranking of modalities + Kruskal-Wallis (non-reference samples) --------
  focal <- dist_table[!dist_table$.is_ref, ]
  rank_table <- NULL
  kw <- NULL
  kw_label <- NULL
  if (!is.null(fact)) {
    rank_table <- focal |>
      dplyr::group_by(.data[[fact]]) |>
      dplyr::summarise(
        n = dplyr::n(),
        dist_mean = mean(.data$dist_to_ref),
        dist_sd = stats::sd(.data$dist_to_ref),
        dist_median = stats::median(.data$dist_to_ref),
        .groups = "drop"
      ) |>
      dplyr::arrange(.data$dist_mean)

    if (length(unique(stats::na.omit(focal[[fact]]))) >= 2) {
      kw <- stats::kruskal.test(focal$dist_to_ref, factor(focal[[fact]]))
      kw_label <- sprintf(
        "Kruskal-Wallis chi-squared(%d) = %.2f, p = %s",
        kw$parameter,
        kw$statistic,
        format.pval(kw$p.value, digits = 2, eps = 1e-4)
      )
    } else {
      cli::cli_warn(
        "{.arg fact} has less than 2 levels among non-reference samples: Kruskal-Wallis test skipped."
      )
    }
  }

  # ---- grouping column used by every plot ------------------------------------
  fact_levels <- if (is.null(fact)) {
    "All samples"
  } else {
    lv <- union(
      as.character(rank_table[[fact]]),
      as.character(unique(dist_table[[fact]]))
    )
    stats::na.omit(lv)
  }
  dist_table$.fact <- if (is.null(fact)) {
    factor("All samples")
  } else {
    factor(as.character(dist_table[[fact]]), levels = fact_levels)
  }

  # ---- 1. violin + jitter -----------------------------------------------------
  # Distances bounded in [0, 1] (Bray-Curtis, Jaccard, UniFrac...) get a
  # boundary-corrected density (bounds = c(0, 1)); other metrics (e.g.
  # Euclidean) fall back to trimming the violin to the observed data range.
  # The bounded density estimator fails on a modality whose distances are all
  # identical (zero variance), so it is used only when every modality has at
  # least two distinct values.
  bounded_metrics <- c("bray", "jaccard", "unifrac", "wunifrac", "sorensen")
  focal_plot <- dist_table[!dist_table$.is_ref, ]
  groups_have_variance <- all(vapply(
    split(focal_plot$dist_to_ref, focal_plot$.fact),
    function(x) {
      length(unique(x)) >= 2
    },
    logical(1L)
  ))
  violin_bounds <- if (
    tolower(method) %in% bounded_metrics && isTRUE(groups_have_variance)
  ) {
    c(0, 1)
  } else {
    c(-Inf, Inf)
  }

  ref_label <- if (n_refs == 1) {
    ref_samples
  } else {
    paste0(n_refs, " reference samples")
  }
  p_violin <- ggplot2::ggplot(
    focal_plot,
    ggplot2::aes(x = .data$.fact, y = .data$dist_to_ref)
  ) +
    ggplot2::geom_violin(
      ggplot2::aes(fill = .data$.fact),
      alpha = 0.4,
      color = NA,
      scale = "width",
      show.legend = FALSE,
      bounds = violin_bounds
    ) +
    ggplot2::geom_jitter(width = 0.15, alpha = 0.6, size = 1.5)

  if (show_ref) {
    p_violin <- p_violin +
      ggplot2::geom_point(
        data = dist_table[dist_table$.is_ref, ],
        shape = 21,
        size = 4,
        stroke = 1.4,
        fill = "red",
        color = "black"
      )
  } else if (nrow(focal_plot) > 0) {
    # Discard the 0 baseline: zoom on the non-reference distance range so
    # differences among samples are easier to read.
    p_violin <- p_violin +
      ggplot2::coord_cartesian(ylim = range(focal_plot$dist_to_ref))
  }

  p_violin <- p_violin +
    ggplot2::labs(
      title = paste("Distance to reference:", ref_label),
      subtitle = kw_label,
      x = if (is.null(fact)) NULL else paste0(fact, " (closest to farthest)"),
      y = paste0("Distance to reference (", method, ")")
    ) +
    ggplot2::theme_bw() +
    ggplot2::theme(
      axis.text.x = ggplot2::element_text(angle = 45, hjust = 1)
    )

  # ---- 2. ranked lollipop ------------------------------------------------------
  df_lol <- dplyr::arrange(dist_table, .data$dist_to_ref)
  if (!show_ref) {
    df_lol <- df_lol[!df_lol$.is_ref, ]
  }
  df_lol$sample_name <- factor(df_lol$sample_name, levels = df_lol$sample_name)

  p_lollipop <- ggplot2::ggplot(
    df_lol,
    ggplot2::aes(
      x = .data$sample_name,
      y = .data$dist_to_ref,
      color = .data$.fact
    )
  ) +
    ggplot2::geom_segment(
      ggplot2::aes(xend = .data$sample_name, y = 0, yend = .data$dist_to_ref),
      alpha = 0.6
    ) +
    ggplot2::geom_point(size = 1.6)

  if (show_ref) {
    p_lollipop <- p_lollipop +
      ggplot2::geom_point(
        data = df_lol[df_lol$.is_ref, ],
        shape = 21,
        size = 4,
        stroke = 1.4,
        fill = "red",
        color = "black",
        show.legend = FALSE
      )
  }

  p_lollipop <- p_lollipop +
    ggplot2::coord_flip(
      ylim = if (show_ref) NULL else range(df_lol$dist_to_ref)
    ) +
    ggplot2::labs(
      title = "Samples ranked by distance to the reference",
      subtitle = paste("Reference:", ref_label),
      x = NULL,
      y = paste0("Distance to reference (", method, ")"),
      color = fact
    ) +
    ggplot2::theme_bw() +
    ggplot2::theme(
      axis.text.y = ggplot2::element_text(
        size = ggplot2::rel(if (nrow(df_lol) > 60) 0.35 else 0.7)
      )
    )

  # ---- ordination helper -------------------------------------------------------
  # Coordinates of the first two axes via plot_ordination(justDF = TRUE), which
  # handles every ordination method (Axis.1/Axis.2 for PCoA, NMDS1/NMDS2...).
  ord_coords <- function(physeq_ord, ord) {
    coords <- phyloseq::plot_ordination(physeq_ord, ord, justDF = TRUE)
    coords <- coords[, 1:2]
    colnames(coords) <- c("Axis1", "Axis2")
    coords$sample_name <- rownames(coords)
    dplyr::left_join(coords, dist_table, by = "sample_name")
  }
  var_expl <- function(ord) {
    if (ordination_method == "PCoA" && !is.null(ord$values)) {
      round(100 * ord$values$Relative_eig[1:2], digits = 1)
    } else {
      NULL
    }
  }
  axis_lab <- function(ve, i) {
    if (is.null(ve)) {
      paste(ordination_method, i)
    } else {
      paste0(ordination_method, " ", i, " (", ve[i], "%)")
    }
  }
  # Spokes joining samples to the reference (single reference only); with
  # several references, draw them as large triangles instead.
  add_ref_layers <- function(p, coords) {
    refs_xy <- coords[coords$.is_ref, ]
    if (n_refs == 1) {
      p <- p +
        ggplot2::geom_segment(
          data = coords[!coords$.is_ref, ],
          ggplot2::aes(
            xend = refs_xy$Axis1,
            yend = refs_xy$Axis2,
            color = .data$.fact
          ),
          alpha = 0.5
        )
    }
    p +
      ggplot2::geom_point(
        data = refs_xy,
        shape = if (n_refs == 1) 21 else 17,
        size = 5,
        stroke = 1.6,
        fill = if (n_refs == 1) "red" else NA,
        color = if (n_refs == 1) "black" else "red"
      )
  }

  # The n_nearest closest NON-reference samples + the reference set itself
  # (otherwise, with many references, the local view would contain only
  # reference samples).
  focal_ordered <- dist_table$sample_name[!dist_table$.is_ref][
    order(dist_table$dist_to_ref[!dist_table$.is_ref])
  ]
  nearest <- c(ref_samples, utils::head(focal_ordered, n_nearest))
  n_kept <- length(nearest)
  if (n_kept < 3) {
    cli::cli_abort(
      "Not enough samples for the local ordination (need the reference set plus at least 2 other samples)."
    )
  }

  # ---- 3. global ordination (context: all samples, far ones dimmed) ------------
  ord_full <- phyloseq::ordinate(
    physeq,
    method = ordination_method,
    distance = dist_obj
  )
  coords_full <- ord_coords(physeq, ord_full)
  coords_full$.is_near <- coords_full$sample_name %in% nearest
  ve_full <- var_expl(ord_full)

  p_pcoa_global <- ggplot2::ggplot(
    coords_full,
    ggplot2::aes(x = .data$Axis1, y = .data$Axis2)
  ) +
    ggplot2::geom_point(
      data = coords_full[!coords_full$.is_near, ],
      color = "grey75",
      alpha = 0.6,
      size = 1.5
    ) +
    ggplot2::geom_point(
      data = coords_full[coords_full$.is_near & !coords_full$.is_ref, ],
      ggplot2::aes(color = .data$.fact),
      size = 2
    )
  p_pcoa_global <- add_ref_layers(
    p_pcoa_global,
    coords_full[coords_full$.is_near, ]
  ) +
    ggplot2::labs(
      title = paste0(ordination_method, " - global context (all samples)"),
      subtitle = paste0(
        "Colored points = the ",
        n_nearest,
        " samples nearest to the reference (kept, with the reference set, in the local ordination); reference: ",
        ref_label
      ),
      x = axis_lab(ve_full, 1),
      y = axis_lab(ve_full, 2),
      color = fact
    ) +
    ggplot2::theme_bw()

  # ---- 4. local ordination recomputed on the closest samples -------------------
  # A global ordination embeds ALL pairwise distances and is dominated by the
  # far samples; recomputing on the k closest focuses on the structure among
  # the samples that are actually near the reference.
  physeq_sub <- phyloseq::prune_samples(nearest, physeq)
  dist_sub <- .dist_matrix_pq(physeq_sub, method)
  ord_sub <- phyloseq::ordinate(
    physeq_sub,
    method = ordination_method,
    distance = dist_sub
  )
  coords_sub <- ord_coords(physeq_sub, ord_sub)
  ve_sub <- var_expl(ord_sub)

  p_pcoa_local <- ggplot2::ggplot(
    coords_sub,
    ggplot2::aes(x = .data$Axis1, y = .data$Axis2)
  ) +
    ggplot2::geom_point(
      data = coords_sub[!coords_sub$.is_ref, ],
      ggplot2::aes(color = .data$.fact),
      size = 2
    )
  p_pcoa_local <- add_ref_layers(p_pcoa_local, coords_sub) +
    ggplot2::labs(
      title = paste0(
        ordination_method,
        " - local, recomputed on the ",
        min(n_nearest, length(focal_ordered)),
        " samples nearest to the reference (+ ",
        n_refs,
        " reference",
        if (n_refs > 1) "s" else "",
        ")"
      ),
      subtitle = paste("Reference:", ref_label),
      x = axis_lab(ve_sub, 1),
      y = axis_lab(ve_sub, 2),
      color = fact
    ) +
    ggplot2::theme_bw()

  list(
    dist_table = dist_table[, !names(dist_table) %in% c(".fact", ".is_ref")],
    rank_table = rank_table,
    kw = kw,
    ref_samples = ref_samples,
    plots = list(
      violin = p_violin,
      lollipop = p_lollipop,
      pcoa_global = p_pcoa_global,
      pcoa_local = p_pcoa_local
    ),
    dist = dist_obj
  )
}

################################################################################
#' Pairwise distance matrix as a `dist` object (internal)
#'
#' @description Dispatch pattern shared with MiscMetabar: `"aitchison"` and
#'   `"robust.aitchison"` go through [vegan::vegdist()], everything else
#'   through [phyloseq::distance()].
#' @keywords internal
#' @noRd
.dist_matrix_pq <- function(physeq, method) {
  if (method %in% c("aitchison", "robust.aitchison")) {
    if (!requireNamespace("vegan", quietly = TRUE)) {
      cli::cli_abort(
        "Package {.pkg vegan} is required for method {.val {method}}."
      )
    }
    otu <- as(phyloseq::otu_table(physeq), "matrix")
    if (phyloseq::taxa_are_rows(physeq)) {
      otu <- t(otu)
    }
    return(vegan::vegdist(otu, method = method))
  }
  phyloseq::distance(physeq, method = method)
}
################################################################################
