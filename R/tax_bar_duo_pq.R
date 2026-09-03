################################################################################
#' Side-by-side sequence and taxa composition bar plots
#'
#' @description
#'
#' <a href="https://adrientaudiere.github.io/MiscMetabar/articles/Rules.html#lifecycle">
#' <img src="https://img.shields.io/badge/lifecycle-experimental-orange" alt="lifecycle-experimental"></a>
#'
#' Build the two complementary [MiscMetabar::tax_bar_pq()] views of the same
#' `physeq` object in a single call and assemble them with `patchwork`:
#'
#' - **left panel**: relative number of sequences
#'   (`percent_bar = TRUE`, `nb_seq = TRUE`),
#' - **right panel**: number of taxa
#'   (`percent_bar = FALSE`, `nb_seq = FALSE`).
#'
#' The fill guide is collected into a single shared legend, and one overall
#' title is added above the two panels through
#' [patchwork::plot_annotation()].
#'
#' @note Both panels are computed from the same `physeq` object and the same
#'   `taxa` rank, so their discrete fill scales share the exact same set of
#'   levels. [reorder_distinct_colors()] is deterministic for a given set of
#'   levels: each taxon therefore receives the same color in both panels, and
#'   `patchwork` can merge the two guides into one legend.
#'
#' @param physeq (required) A [phyloseq::phyloseq-class] object.
#' @param fact (default: "Sample") Name of the column in the `sam_data` slot
#'   used to group samples on the x-axis.
#' @param taxa (default: "Order") Name of the taxonomic rank used to fill the
#'   bars.
#' @param title (default: `paste0(taxa, " composition")`) Overall title added
#'   with [patchwork::plot_annotation()]. Use `NULL` for no title.
#' @param subtitle (default: `c("Number of sequences (%)", "Number of taxa")`)
#'   Subtitle of the left and right panels. A length one value is used for
#'   both panels. Use `NULL` for no subtitle.
#' @param show_values (logical, default `c(TRUE, TRUE)`) Passed to
#'   [MiscMetabar::tax_bar_pq()]. The first value applies to the left
#'   (sequence) panel, the second to the right (taxa) panel. A length one
#'   value is recycled.
#' @param minimum_value_to_show (default: `c(0.05, 4)`) Passed to
#'   [MiscMetabar::tax_bar_pq()]. As for `show_values`, the first value
#'   applies to the left (sequence, in percent) panel and the second to the
#'   right (taxa, in counts) panel.
#' @param reorder_colors (logical, default TRUE) If TRUE,
#'   [reorder_distinct_colors()] is applied to both panels to maximize the
#'   perceptual contrast between adjacent bar segments.
#' @param alternate_lightness (logical, default TRUE) Passed to
#'   [reorder_distinct_colors()]. Only used when `reorder_colors = TRUE`.
#' @param add_ribbon (logical, default TRUE) Passed to
#'   [MiscMetabar::tax_bar_pq()]: draw ribbons connecting the bars of
#'   consecutive modalities.
#' @param legend_position (default: "bottom") Position of the single
#'   collected legend, passed to the `legend.position` theme element. Use
#'   "right" to get the usual side legend, or "none" to drop the legend.
#' @param legend_nrow (default: NULL) Number of rows of the collected legend.
#'   Only relevant when `legend_position` is "bottom" or "top", where the
#'   default single row quickly becomes unreadable for a taxonomic rank with
#'   many levels.
#' @param title_size (default: 20) Font size of the overall title.
#' @param subtitle_size (default: 11) Font size of the panel subtitles.
#' @param ... Other arguments passed on to [MiscMetabar::tax_bar_pq()] for
#'   **both** panels (e.g. `order_modality`, `label_taxa`, `bar_width`).
#'
#' @return A `patchwork` object.
#' @author Adrien Taudière
#' @seealso [MiscMetabar::tax_bar_pq()], [reorder_distinct_colors()]
#' @export
#'
#' @examples
#' \donttest{
#' if (requireNamespace("patchwork", quietly = TRUE)) {
#'   data(data_fungi_mini, package = "MiscMetabar")
#'   tax_bar_duo_pq(data_fungi_mini, "Height", taxa = "Genus")
#'   tax_bar_duo_pq(data_fungi_mini, "Height",
#'     taxa = "Genus",
#'     title = "Composition en genres",
#'     subtitle = c("Nombre de séquences en %", "Nombre de taxons"),
#'     minimum_value_to_show = c(0.05, 4)
#'   )
#' }
#' }
tax_bar_duo_pq <- function(
  physeq,
  fact = "Sample",
  taxa = "Order",
  title = paste0(taxa, " composition"),
  subtitle = c("Number of sequences (%)", "Number of taxa"),
  show_values = c(TRUE, TRUE),
  minimum_value_to_show = c(0.05, 4),
  reorder_colors = TRUE,
  alternate_lightness = TRUE,
  add_ribbon = TRUE,
  legend_position = "bottom",
  legend_nrow = NULL,
  title_size = 20,
  subtitle_size = 11,
  ...
) {
  if (!requireNamespace("patchwork", quietly = TRUE)) {
    cli::cli_abort("Package {.pkg patchwork} is required.")
  }
  if (!requireNamespace("MiscMetabar", quietly = TRUE)) {
    cli::cli_abort("Package {.pkg MiscMetabar} is required.")
  }

  recycle_2 <- function(x, arg) {
    if (is.null(x)) {
      return(NULL)
    }
    if (length(x) == 1) {
      x <- rep(x, 2)
    }
    if (length(x) != 2) {
      cli::cli_abort(
        "{.arg {arg}} must be of length 1 or 2, not {length(x)}."
      )
    }
    x
  }

  show_values <- recycle_2(show_values, "show_values")
  minimum_value_to_show <- recycle_2(
    minimum_value_to_show,
    "minimum_value_to_show"
  )
  subtitle <- recycle_2(subtitle, "subtitle")

  build_panel <- function(percent_bar, nb_seq, i) {
    p <- MiscMetabar::tax_bar_pq(
      physeq,
      fact = fact,
      taxa = taxa,
      percent_bar = percent_bar,
      nb_seq = nb_seq,
      add_ribbon = add_ribbon,
      show_values = show_values[[i]],
      minimum_value_to_show = minimum_value_to_show[[i]],
      ...
    )
    if (!is.null(subtitle)) {
      p <- p + ggplot2::labs(subtitle = subtitle[[i]])
    }
    if (reorder_colors) {
      p <- p +
        reorder_distinct_colors(alternate_lightness = alternate_lightness)
    }
    p
  }

  p_seq <- build_panel(percent_bar = TRUE, nb_seq = TRUE, i = 1)
  p_taxa <- build_panel(percent_bar = FALSE, nb_seq = FALSE, i = 2)

  res <- patchwork::wrap_plots(p_seq, p_taxa, guides = "collect")

  if (!is.null(title)) {
    res <- res + patchwork::plot_annotation(title = title)
  }

  res <- res &
    ggplot2::theme(
      plot.title = ggplot2::element_text(size = title_size, hjust = 0.5),
      plot.subtitle = ggplot2::element_text(size = subtitle_size, hjust = 0.5),
      legend.position = legend_position
    )

  if (!is.null(legend_nrow)) {
    res <- res &
      ggplot2::guides(fill = ggplot2::guide_legend(nrow = legend_nrow))
  }

  res
}
################################################################################
