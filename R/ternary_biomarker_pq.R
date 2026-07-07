utils::globalVariables(c("sum_abund", "enriched", "taxon"))

################################################################################
#' Ternary plot of biomarker taxa across three sample groups
#'
#' @description
#'
#' <a href="https://adrientaudiere.github.io/MiscMetabar/articles/Rules.html#lifecycle">
#' <img src="https://img.shields.io/badge/lifecycle-experimental-orange" alt="lifecycle-experimental"></a>
#'
#' Renders biomarker (or any) taxa on a three-group ternary diagram using the
#' \pkg{ggtern} package. Each point is one taxon, positioned by its relative
#' abundance in the three groups defined by `fact`: a taxon near a corner is
#' enriched in that group. Point size encodes the taxon's total abundance and
#' point colour the group in which it is most abundant.
#'
#' This is a **pure rendering** helper: it does not run any biomarker-detection
#' analysis. The typical workflow is to detect biomarker taxa elsewhere (e.g. a
#' LefSe analysis, planned for the `netaipq` package) and pass the resulting
#' taxa names to `biomarker_taxa`. When `biomarker_taxa` is `NULL`, every taxon
#' is shown. The original published figure this reproduces colours ZOTUs by the
#' treatment (control / manure / frass) in which they are enriched (Du et al.
#' 2023, \doi{10.1007/s42832-023-0196-0}).
#'
#' @param physeq (required) A [phyloseq::phyloseq-class] object.
#' @param fact (required) Either a single character string matching a variable
#'   name in `sample_data(physeq)`, or a factor of length `nsamples(physeq)`.
#'   Must have exactly 3 levels.
#' @param biomarker_taxa (character vector, default `NULL`) Taxa names to plot
#'   (e.g. biomarkers from a LefSe analysis). When `NULL`, all taxa are used.
#' @param level_order (character vector, default `NULL`) Order of the 3 levels
#'   mapped to the (left = `x`, top = `y`, right = `z`) ternary axes. When
#'   `NULL`, the factor's existing level order is used.
#' @param raw (logical, default `FALSE`) If `FALSE` (default), each group's
#'   abundances are divided by the group total so that group size does not bias
#'   the position. If `TRUE`, raw summed counts are used.
#' @param point_alpha (numeric, default `0.8`) Transparency of the points.
#' @param show_labels (logical, default `FALSE`) If `TRUE`, taxa names are added
#'   next to each point with [ggplot2::geom_text()].
#' @param label_size (numeric, default `2`) Font size for the taxa labels.
#' @param size_range (numeric of length 2, default `c(1, 8)`) Point size range
#'   passed to [ggplot2::scale_size()].
#'
#' @return A `ggtern`/[ggplot2::ggplot] object.
#' @author Adrien Taudière
#' @references Du et al. (2023) \doi{10.1007/s42832-023-0196-0}.
#' @seealso [ternary_pq()] for a base-ggplot2 ternary/diamond of all taxa
#'   (no \pkg{ggtern} dependency).
#' @export
#'
#' @examples
#' \donttest{
#' data(data_fungi_mini, package = "MiscMetabar")
#' if (requireNamespace("ggtern", quietly = TRUE)) {
#'   # Height has 3 levels (High, Low, Middle); show all taxa
#'   ternary_biomarker_pq(data_fungi_mini, fact = "Height")
#' }
#' }
#' \dontrun{
#' # Restrict to biomarker taxa detected elsewhere (e.g. a LefSe analysis)
#' biomarkers <- c("ASV1", "ASV5", "ASV12")
#' ternary_biomarker_pq(
#'   data_fungi_mini,
#'   fact           = "Height",
#'   biomarker_taxa = biomarkers,
#'   show_labels    = TRUE
#' )
#' }
ternary_biomarker_pq <- function(
  physeq,
  fact,
  biomarker_taxa = NULL,
  level_order = NULL,
  raw = FALSE,
  point_alpha = 0.8,
  show_labels = FALSE,
  label_size = 2,
  size_range = c(1, 8)
) {
  if (!requireNamespace("ggtern", quietly = TRUE)) {
    cli::cli_abort(
      "Package {.pkg ggtern} is required for {.fn ternary_biomarker_pq}."
    )
  }

  built <- .ternary_biomarker_df(
    physeq,
    fact,
    biomarker_taxa = biomarker_taxa,
    level_order = level_order,
    raw = raw
  )
  plot_df <- built$plot_df
  lvls <- built$lvls

  # -- Build the ggtern plot --------------------------------------------------
  p <- ggtern::ggtern(
    data = plot_df,
    ggplot2::aes(
      x = .data[[lvls[1]]],
      y = .data[[lvls[2]]],
      z = .data[[lvls[3]]]
    )
  ) +
    ggplot2::geom_point(
      ggplot2::aes(size = sum_abund, color = enriched),
      alpha = point_alpha
    ) +
    ggplot2::scale_size(range = size_range, name = "Total abundance") +
    ggplot2::labs(color = fact_label(fact)) +
    ggtern::theme_nomask()

  if (show_labels) {
    p <- p +
      ggplot2::geom_text(
        ggplot2::aes(label = taxon),
        size = label_size,
        vjust = -0.6
      )
  }

  p
}

# Internal: build the per-taxon ternary data frame (no ggtern dependency).
# Returns a list with $plot_df (columns: the 3 level names, taxon, sum_abund,
# enriched) and $lvls (the ordered level names).
.ternary_biomarker_df <- function(
  physeq,
  fact,
  biomarker_taxa = NULL,
  level_order = NULL,
  raw = FALSE
) {
  # -- Resolve grouping factor ------------------------------------------------
  if (is.character(fact) && length(fact) == 1) {
    MiscMetabar::verify_fact_pq(physeq, fact = fact)
    sd <- as.data.frame(phyloseq::sample_data(physeq))
    group <- factor(sd[[fact]])
  } else {
    group <- factor(fact)
  }

  # Drop NA-group samples
  keep_idx <- !is.na(group)
  if (any(!keep_idx)) {
    physeq <- phyloseq::prune_samples(keep_idx, physeq)
    group <- droplevels(group[keep_idx])
  }

  if (!is.null(level_order)) {
    missing_lvls <- setdiff(levels(group), level_order)
    if (length(missing_lvls) > 0) {
      cli::cli_abort(
        "Some levels of {.arg fact} are not in {.arg level_order}: {.val {missing_lvls}}"
      )
    }
    group <- factor(group, levels = level_order)
  }

  if (nlevels(group) != 3) {
    cli::cli_abort(
      "{.arg fact} must have exactly 3 levels, not {nlevels(group)}."
    )
  }
  lvls <- levels(group)

  # -- Optionally restrict to biomarker taxa ----------------------------------
  if (!is.null(biomarker_taxa)) {
    known <- intersect(biomarker_taxa, phyloseq::taxa_names(physeq))
    if (length(known) == 0) {
      cli::cli_abort(
        "None of {.arg biomarker_taxa} match {.code taxa_names(physeq)}."
      )
    }
    if (length(known) < length(biomarker_taxa)) {
      cli::cli_warn(
        "{length(biomarker_taxa) - length(known)} of {.arg biomarker_taxa} not found and dropped."
      )
    }
    physeq <- phyloseq::prune_taxa(known, physeq)
  }

  # -- Per-group abundance matrix (taxa x 3 groups) ---------------------------
  otu <- as(phyloseq::otu_table(physeq), "matrix")
  if (!phyloseq::taxa_are_rows(physeq)) {
    otu <- t(otu)
  }
  grp_abund <- t(rowsum(t(otu), group, reorder = FALSE))
  grp_abund <- grp_abund[, lvls, drop = FALSE]

  if (!raw) {
    col_tot <- colSums(grp_abund)
    col_tot[col_tot == 0] <- 1
    grp_abund <- sweep(grp_abund, 2, col_tot, "/")
  }

  # Keep taxa present in at least one group
  keep_tax <- rowSums(grp_abund) > 0
  grp_abund <- grp_abund[keep_tax, , drop = FALSE]
  if (nrow(grp_abund) == 0) {
    cli::cli_abort("No taxa with non-zero abundance to plot.")
  }

  plot_df <- as.data.frame(grp_abund)
  colnames(plot_df) <- lvls
  plot_df$taxon <- rownames(grp_abund)
  plot_df$sum_abund <- rowSums(grp_abund)
  plot_df$enriched <- factor(
    lvls[apply(grp_abund, 1, which.max)],
    levels = lvls
  )

  list(plot_df = plot_df, lvls = lvls)
}

# Internal: legend title for the colour scale.
fact_label <- function(fact) {
  if (is.character(fact) && length(fact) == 1) {
    paste0("Enriched in\n(", fact, ")")
  } else {
    "Enriched in"
  }
}
