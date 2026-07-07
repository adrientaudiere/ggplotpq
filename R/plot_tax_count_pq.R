################################################################################
#' Plot taxonomic counts (non-proportion) in function of a factor with stacked bars
#'
#' @description
#'
#' <a href="https://adrientaudiere.github.io/MiscMetabar/articles/Rules.html#lifecycle">
#' <img src="https://img.shields.io/badge/lifecycle-experimental-orange" alt="lifecycle-experimental"></a>
#'
#' A non-proportion ("non-fill") variant of [MiscMetabar::plot_tax_pq()]:
#' counts of the chosen taxonomic rank are stacked per sample **without**
#' being normalised to proportions, so the y-axis reports the raw number
#' of sequences. Useful when the absolute abundance per sample matters
#' (e.g. spike-in normalisation, biomass comparisons) and a proportional
#' view would hide it.
#'
#' Implemented as a fresh function in `ggplotpq` rather than a parameter
#' on [MiscMetabar::plot_tax_pq()], so the proportion version keeps its
#' existing behaviour and the new variant is free to evolve.
#'
#' @param physeq (required) A [phyloseq::phyloseq-class] object.
#' @param fact (required) Name of the factor to cluster samples by modalities.
#'   Need to be in `physeq@sam_data`.
#' @param merge_sample_by A vector to determine which samples to merge using
#'   [MiscMetabar::merge_samples2()]. Need to be in `physeq@sam_data`.
#' @param type If "nb_seq" (default), the number of sequences is used in
#'   plot. If "nb_taxa", the number of ASV is plotted. If both, return a
#'   list of two plots, one for `nbSeq` and one for `ASV`.
#' @param taxa_fill (default: 'Order') Name of the taxonomic rank of interest.
#' @param color_border (default: 'lightgrey') Color of the bar borders.
#' @param linewidth (default: 0.1) The line width of `geom_col`.
#' @param add_info (logical, default TRUE) If TRUE, add a title and subtitle
#'   with information about the total number of sequences and the number
#'   of samples per modality.
#' @param na_remove (logical, default TRUE) If TRUE, remove all samples
#'   with NA in the `fact` variable of the `physeq@sam_data` slot.
#' @param clean_pq (logical, default TRUE) If TRUE, empty samples are
#'   discarded after subsetting ASV.
#'
#' @return A [ggplot2::ggplot] object.
#' @author Adrien Taudière
#' @seealso [MiscMetabar::plot_tax_pq()] and [MiscMetabar::tax_bar_pq()]
#' @export
#'
#' @examples
#' \donttest{
#' data(data_fungi_sp_known, package = "MiscMetabar")
#' plot_tax_count_pq(
#'   data_fungi_sp_known,
#'   "Time",
#'   merge_sample_by = "Time",
#'   taxa_fill = "Class"
#' )
#' }
plot_tax_count_pq <- function(
  physeq,
  fact = NULL,
  merge_sample_by = NULL,
  type = "nb_seq",
  taxa_fill = "Order",
  color_border = "lightgrey",
  linewidth = 0.1,
  add_info = TRUE,
  na_remove = TRUE,
  clean_pq = TRUE
) {
  if (!requireNamespace("MiscMetabar", quietly = TRUE)) {
    cli::cli_abort("Package {.pkg MiscMetabar} is required.")
  }
  if (!requireNamespace("phyloseq", quietly = TRUE)) {
    cli::cli_abort("Package {.pkg phyloseq} is required.")
  }

  if (is.null(fact)) {
    cli::cli_abort("{.arg fact} is required.")
  }
  MiscMetabar::verify_fact_pq(physeq, fact = fact)

  if (na_remove) {
    new_physeq <- MiscMetabar::subset_samples_pq(
      physeq,
      !is.na(physeq@sam_data[[fact]])
    )
    dropped <- phyloseq::nsamples(physeq) - phyloseq::nsamples(new_physeq)
    if (dropped > 0) {
      cli::cli_alert_info(
        "{dropped} sample{?s} discarded due to NA in {.arg fact}."
      )
    }
    physeq <- new_physeq
  }

  if (clean_pq) {
    physeq <- MiscMetabar::clean_pq(physeq)
  }

  if (!is.null(merge_sample_by)) {
    physeq <- MiscMetabar::merge_samples2(physeq, merge_sample_by)
  }

  if (!taxa_fill %in% phyloseq::rank_names(physeq)) {
    cli::cli_abort(
      "Taxonomic rank {.val {taxa_fill}} not found in {.code tax_table}."
    )
  }

  type <- match.arg(type, c("nb_seq", "nb_taxa"))
  if (identical(type, "nb_seq")) {
    y_label <- "Number of sequences"
  } else {
    y_label <- "Number of taxa"
  }

  if (identical(type, "nb_taxa")) {
    # Binarise the counts so psmelt reports unique-taxa counts per sample
    otu <- phyloseq::otu_table(physeq)
    otu_bin <- if (phyloseq::taxa_are_rows(physeq)) {
      (otu > 0) * 1L
    } else {
      t((t(otu) > 0) * 1L)
    }
    phyloseq::otu_table(physeq) <- otu_bin
  }

  df <- as.data.frame(phyloseq::psmelt(physeq), stringsAsFactors = FALSE)

  df <- df |>
    dplyr::filter(!is.na(.data[[taxa_fill]])) |>
    dplyr::group_by(
      Sample = .data[["Sample"]],
      Taxon = .data[[taxa_fill]]
    ) |>
    dplyr::summarise(Abundance = sum(.data[["Abundance"]]), .groups = "drop") |>
    dplyr::mutate(
      Sample = factor(.data[["Sample"]], levels = unique(.data[["Sample"]]))
    )

  p <- ggplot(
    df,
    aes(
      x = .data[["Sample"]],
      y = .data[["Abundance"]],
      fill = .data[["Taxon"]]
    )
  ) +
    geom_col(
      color = color_border,
      linewidth = linewidth,
      position = "stack"
    ) +
    labs(
      x = NULL,
      y = y_label,
      fill = taxa_fill
    ) +
    theme_minimal() +
    theme(axis.text.x = element_text(angle = 45, hjust = 1))

  if (add_info) {
    n_samples <- length(unique(df$Sample))
    total <- sum(df$Abundance)
    p <- p +
      labs(
        title = sprintf("Count distribution of '%s'", taxa_fill),
        subtitle = sprintf(
          "%d sample(s), %d total %s",
          n_samples,
          total,
          if (identical(type, "nb_taxa")) "taxa" else "sequences"
        )
      )
  }

  p
}
