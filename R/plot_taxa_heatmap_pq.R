#' Heatmap of the top-N most abundant taxa across samples
#'
#' @description
#'
#' <a href="https://adrientaudiere.github.io/MiscMetabar/articles/Rules.html#lifecycle">
#' <img src="https://img.shields.io/badge/lifecycle-experimental-orange" alt="lifecycle-experimental"></a>
#'
#' Draw a ggplot2 heatmap of the `n_top` most abundant taxa (by total
#' read count) across the samples of a phyloseq object. The x-axis is
#' the sample, the y-axis is the taxon (with the chosen `taxa_rank`
#' name), and the fill is either the raw abundance (default) or the
#' log10-transformed abundance (`log10 = TRUE`). Useful for a quick
#' survey of the dominant taxa and to spot per-sample anomalies.
#'
#' @param physeq (required) A [phyloseq::phyloseq-class] object.
#' @param n_top (integer, default 20) Number of top taxa (by total read
#'   count across samples) to display. Must be >= 1.
#' @param taxa_rank (character, default "Family") The taxonomic rank
#'   used to label the y-axis. Must be a column in
#'   [phyloseq::tax_table()].
#' @param log10 (logical, default FALSE) If TRUE, the cell value is
#'   log10(`Abundance + 1`) — useful when the abundance distribution is
#'   heavily right-skewed.
#' @param na_rm (logical, default TRUE) Drop samples with NA in the
#'   abundance before plotting.
#' @param fill_scale (function, default NULL) Optional ggplot2 fill
#'   scale applied to the heatmap. If NULL, uses
#'   [ggplot2::scale_fill_viridis_c()] for continuous fills. Ignored
#'   when `log10 = FALSE` and the user wants the default.
#'
#' @return A [ggplot2::ggplot] object.
#' @author Adrien Taudière
#' @export
#'
#' @examples
#' \donttest{
#' data(data_fungi_mini, package = "MiscMetabar")
#' plot_taxa_heatmap_pq(data_fungi_mini, n_top = 15, taxa_rank = "Family")
#' plot_taxa_heatmap_pq(data_fungi_mini, n_top = 10, log10 = TRUE)
#' }
plot_taxa_heatmap_pq <- function(
  physeq,
  n_top = 20,
  taxa_rank = "Family",
  log10 = FALSE,
  na_rm = TRUE,
  fill_scale = NULL
) {
  if (!requireNamespace("phyloseq", quietly = TRUE)) {
    cli::cli_abort("Package {.pkg phyloseq} is required.")
  }
  if (!requireNamespace("MiscMetabar", quietly = TRUE)) {
    cli::cli_abort("Package {.pkg MiscMetabar} is required.")
  }

  if (!is.numeric(n_top) || length(n_top) != 1 || n_top < 1) {
    cli::cli_abort("{.arg n_top} must be a single positive integer.")
  }
  n_top <- as.integer(n_top)

  if (!taxa_rank %in% phyloseq::rank_names(physeq)) {
    cli::cli_abort(
      "Taxonomic rank {.val {taxa_rank}} not found in {.code tax_table}."
    )
  }

  if (na_rm) {
    physeq <- MiscMetabar::clean_pq(physeq)
  }

  # Top-N taxa by total abundance
  taxa_sums_totals <- phyloseq::taxa_sums(physeq)
  keep_taxa <- names(sort(taxa_sums_totals, decreasing = TRUE)[seq_len(
    min(n_top, length(taxa_sums_totals))
  )])
  physeq_sub <- phyloseq::prune_taxa(keep_taxa, physeq)

  df <- as.data.frame(phyloseq::psmelt(physeq_sub), stringsAsFactors = FALSE)

  # Aggregate by Sample × taxa_rank (so multiple ASVs from the same
  # Family collapse into one cell)
  df <- df |>
    dplyr::filter(!is.na(.data[[taxa_rank]])) |>
    dplyr::group_by(
      Sample = .data[["Sample"]],
      Taxon = .data[[taxa_rank]]
    ) |>
    dplyr::summarise(Abundance = sum(.data[["Abundance"]]), .groups = "drop")

  if (nrow(df) == 0) {
    cli::cli_abort("No data to plot after filtering.")
  }

  # Order taxa by overall abundance (top of heatmap = most abundant)
  taxon_order <- df |>
    dplyr::group_by(Taxon) |>
    dplyr::summarise(total = sum(Abundance), .groups = "drop") |>
    dplyr::arrange(dplyr::desc(total)) |>
    dplyr::pull(Taxon)
  df$Taxon <- factor(df$Taxon, levels = rev(taxon_order))

  fill_var <- if (log10) log10(df$Abundance + 1) else df$Abundance
  fill_label <- if (log10) "log10(Abundance + 1)" else "Abundance"

  p <- ggplot(
    df,
    aes(
      x = .data[["Sample"]],
      y = .data[["Taxon"]],
      fill = fill_var
    )
  ) +
    geom_tile(color = "white", linewidth = 0.2) +
    labs(
      x = NULL,
      y = taxa_rank,
      fill = fill_label,
      title = sprintf("Top %d %s", length(taxon_order), taxa_rank)
    ) +
    theme_minimal() +
    theme(
      axis.text.x = element_text(angle = 45, hjust = 1),
      panel.grid = element_blank()
    )

  if (is.null(fill_scale)) {
    p <- p + ggplot2::scale_fill_viridis_c()
  } else {
    p <- p + fill_scale
  }

  p
}
