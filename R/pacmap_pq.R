################################################################################
#' PaCMAP embedding of a phyloseq object (Python backend)
#'
#' @description
#'
#' <a href="https://adrientaudiere.github.io/MiscMetabar/articles/Rules.html#lifecycle">
#' <img src="https://img.shields.io/badge/lifecycle-experimental-orange" alt="lifecycle-experimental"></a>
#'
#' Compute a 2-dimensional PaCMAP embedding (Wang et al., 2021) of the samples
#' of a phyloseq object. PaCMAP optimises the preservation of both local and
#' global structure by balancing three kinds of pair constraints
#' (neighbour pairs, mid-near pairs and far pairs), and was among the best
#' compromises in the empirical comparison of Wang et al. (2021). The
#' embedding is computed by the Python package `pacmap` through
#' [reticulate::import()].
#'
#' @param physeq (required) A [phyloseq::phyloseq-class] object with an
#'   `otu_table` and `sample_data`. Samples (rows of the count matrix) are
#'   embedded; taxa are features.
#' @param n_neighbors (int, default 10) Number of neighbour pairs. PaCMAP
#'   itself reorganises the pair budget when the sample size is too small
#'   (see its warnings). Passed to `pacmap.PaCMAP()`.
#' @param ... Additional arguments passed to `pacmap.PaCMAP()`
#'   (e.g. `distance`, `MN_ratio`, `FP_ratio`, `num_iters`, `apply_pca`,
#'   `random_state`).
#'
#' @return A tibble with the columns `x_pacmap`, `y_pacmap`, `Sample`
#'   (sample name) followed by every column of `sample_data`.
#'
#' @details
#' No transformation is done inside the function: the raw count matrix
#' (samples × taxa) is handed to the backend as is (with `apply_pca = TRUE`,
#' the PaCMAP default, an initial PCA projection is computed internally).
#' Transform `physeq` beforehand if needed
#' (e.g. [phyloseq::transform_sample_counts()]).
#'
#' PaCMAP improves the *global* readability of the embedding, but distances
#' between clusters and cluster densities must still be interpreted with
#' care. For questions about point or cluster distances in the original
#' space, prefer a global technique: PCA ([stats::prcomp()]) or MDS/PCoA
#' ([phyloseq::ordinate()], [MiscMetabar::plot_ordination_pq()]).
#' [dr_plot_pq()] draws PaCMAP next to t-SNE, UMAP, UMATO, MDS and NMDS for
#' a side-by-side comparison.
#'
#' The Python packages `reticulate` (R side) and `pacmap` (Python side) are
#' required; an informative error is thrown when either is missing
#' (install the Python module with
#' `reticulate::py_install("pacmap", pip = TRUE)`).
#'
#' @export
#' @author Adrien Taudière
#'
#' @references
#' Wang, Y., Huang, H., Rudin, C., & Shaposhnik, Y. (2021). Understanding How
#'   Dimension Reduction Tools Work: An Empirical Approach to Deciphering
#'   t-SNE, UMAP, TriMap, and PaCMAP for Data Visualization. *Journal of
#'   Machine Learning Research*, 22(201), 1-73.
#'   \doi{10.48550/arXiv.2012.04456}
#'
#' Jeon, H., Park, J., Shin, S., & Seo, J. (2026). Stop Misusing t-SNE and UMAP
#'   for Visual Analytics. *IEEE Transactions on Visualization and Computer
#'   Graphics*. \doi{10.48550/arXiv.2506.08725}
#'
#' @seealso [umato_pq()], [dr_plot_pq()], [MiscMetabar::umap_pq()],
#'   [MiscMetabar::tsne_pq()]
#'
#' @examples
#' \dontrun{
#' data(data_fungi_mini, package = "MiscMetabar")
#' df_pacmap <- pacmap_pq(data_fungi_mini, n_neighbors = 10, random_state = 42)
#' ggplot2::ggplot(
#'   df_pacmap,
#'   ggplot2::aes(x = x_pacmap, y = y_pacmap, col = Height)
#' ) +
#'   ggplot2::geom_point(size = 2)
#' }
pacmap_pq <- function(physeq, n_neighbors = 10, ...) {
  MiscMetabar::verify_pq(physeq)
  if (!requireNamespace("reticulate", quietly = TRUE)) {
    cli::cli_abort(
      c(
        "Package {.pkg reticulate} is required to run PaCMAP.",
        "i" = "Install it with {.code install.packages(\"reticulate\")}."
      )
    )
  }
  if (!reticulate::py_module_available("pacmap")) {
    cli::cli_abort(
      c(
        "Python module {.pkg pacmap} is not available in the current Python environment.",
        "i" = "Install it with {.code reticulate::py_install(\"pacmap\", pip = TRUE)}.",
        "i" = "Check your Python setup with {.fn reticulate::py_config}."
      )
    )
  }
  if (phyloseq::nsamples(physeq) < 3) {
    cli::cli_abort(
      "{.arg physeq} must have at least 3 samples for a PaCMAP embedding."
    )
  }

  physeq <- MiscMetabar::taxa_as_columns(physeq)
  mat <- as.matrix(unclass(phyloseq::otu_table(physeq)))
  psm_samp <- MiscMetabar::psmelt_samples_pq(physeq)

  n_neighbors <- as.integer(max(
    2,
    min(n_neighbors, phyloseq::nsamples(physeq) - 1)
  ))

  pacmap <- reticulate::import("pacmap")
  dots <- .py_whole_doubles_as_int(list(...))
  model <- do.call(
    pacmap$PaCMAP,
    c(list(n_components = 2L, n_neighbors = n_neighbors), dots)
  )
  pacmap_layout <- reticulate::py_to_r(model$fit_transform(mat))

  pacmap_layout <- tibble::as_tibble(pacmap_layout, .name_repair = "minimal")
  pacmap_layout$Sample <- phyloseq::sample_names(physeq)
  names(pacmap_layout) <- c("x_pacmap", "y_pacmap", "Sample")

  df_pacmap <- dplyr::left_join(pacmap_layout, psm_samp, by = "Sample")

  return(df_pacmap)
}
################################################################################
