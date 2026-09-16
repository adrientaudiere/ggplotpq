################################################################################
#' UMATO embedding of a phyloseq object (Python backend)
#'
#' @description
#'
#' <a href="https://adrientaudiere.github.io/MiscMetabar/articles/Rules.html#lifecycle">
#' <img src="https://img.shields.io/badge/lifecycle-experimental-orange" alt="lifecycle-experimental"></a>
#'
#' Compute a 2-dimensional UMATO embedding (Jeon et al., 2025) of the samples
#' of a phyloseq object. UMATO bridges local and global structures: unlike
#' plain UMAP, the positions of the *hub* samples are optimised to preserve
#' global structure, giving a more reliable reading of the relations between
#' clusters. The embedding is computed by the Python package `umato` through
#' [reticulate::import()].
#'
#' @param physeq (required) A [phyloseq::phyloseq-class] object with an
#'   `otu_table` and `sample_data`. Samples (rows of the count matrix) are
#'   embedded; taxa are features.
#' @param n_neighbors (int, default 15) Number of neighbours for the local
#'   manifold. Automatically capped to `nsamples - 1` so that small phyloseq
#'   objects still run. Passed to `umato.UMATO()`.
#' @param ... Additional arguments passed to `umato.UMATO()`
#'   (e.g. `metric`, `random_state`, `min_dist`, `init`). When `hub_num` is
#'   not given, it defaults to `min(300, nsamples - 1)` (the UMATO default of
#'   300 fails on small data, where the number of hubs must stay below the
#'   number of samples).
#'
#' @return A tibble with the columns `x_umato`, `y_umato`, `Sample`
#'   (sample name) followed by every column of `sample_data`.
#'
#' @details
#' No transformation is done inside the function: the raw count matrix
#' (samples × taxa) is handed to the backend as is. Transform `physeq`
#' beforehand if needed (e.g. [phyloseq::transform_sample_counts()]) — as in
#' [MiscMetabar::umap_pq()], the Euclidean metric on the (possibly
#' transformed) count matrix is the default.
#'
#' UMATO improves the *global* readability of the embedding, but distances
#' between clusters and cluster densities must still be interpreted with
#' care. For questions about point or cluster distances in the original
#' space, prefer a global technique: PCA ([stats::prcomp()]) or MDS/PCoA
#' ([phyloseq::ordinate()], [MiscMetabar::plot_ordination_pq()]).
#' [dr_plot_pq()] draws UMATO next to t-SNE, UMAP, PaCMAP, MDS and NMDS for
#' a side-by-side comparison.
#'
#' The Python packages `reticulate` (R side) and `umato` (Python side) are
#' required; an informative error is thrown when either is missing
#' (install the Python module with
#' `reticulate::py_install("umato", pip = TRUE)`).
#'
#' @export
#' @author Adrien Taudière
#'
#' @references
#' Jeon, H., Ko, K., Lee, S., Hyun, J., Yang, T., Go, G., Jo, J., & Seo, J.
#'   (2025). UMATO: Bridging Local and Global Structures for Reliable Visual
#'   Analytics with Dimensionality Reduction. *IEEE Transactions on
#'   Visualization and Computer Graphics*. \doi{10.1109/TVCG.2025.3602735}
#'
#' Jeon, H., Park, J., Shin, S., & Seo, J. (2026). Stop Misusing t-SNE and UMAP
#'   for Visual Analytics. *IEEE Transactions on Visualization and Computer
#'   Graphics*. \doi{10.48550/arXiv.2506.08725}
#'
#' @seealso [pacmap_pq()], [dr_plot_pq()], [MiscMetabar::umap_pq()],
#'   [MiscMetabar::tsne_pq()]
#'
#' @examples
#' \dontrun{
#' data(data_fungi_mini, package = "MiscMetabar")
#' df_umato <- umato_pq(data_fungi_mini, n_neighbors = 15, random_state = 42)
#' ggplot2::ggplot(df_umato, ggplot2::aes(x = x_umato, y = y_umato, col = Height)) +
#'   ggplot2::geom_point(size = 2)
#' }
umato_pq <- function(physeq, n_neighbors = 15, ...) {
  MiscMetabar::verify_pq(physeq)
  if (!requireNamespace("reticulate", quietly = TRUE)) {
    cli::cli_abort(
      c(
        "Package {.pkg reticulate} is required to run UMATO.",
        "i" = "Install it with {.code install.packages(\"reticulate\")}."
      )
    )
  }
  if (!reticulate::py_module_available("umato")) {
    cli::cli_abort(
      c(
        "Python module {.pkg umato} is not available in the current Python environment.",
        "i" = "Install it with {.code reticulate::py_install(\"umato\", pip = TRUE)}.",
        "i" = "Check your Python setup with {.fn reticulate::py_config}."
      )
    )
  }
  if (phyloseq::nsamples(physeq) < 3) {
    cli::cli_abort(
      "{.arg physeq} must have at least 3 samples for a UMATO embedding."
    )
  }

  physeq <- MiscMetabar::taxa_as_columns(physeq)
  mat <- as.matrix(unclass(phyloseq::otu_table(physeq)))
  psm_samp <- MiscMetabar::psmelt_samples_pq(physeq)

  n_neighbors <- as.integer(min(n_neighbors, phyloseq::nsamples(physeq) - 1))

  umato <- reticulate::import("umato")
  dots <- .py_whole_doubles_as_int(list(...))
  if (is.null(dots$hub_num)) {
    dots$hub_num <- as.integer(min(300, phyloseq::nsamples(physeq) - 1))
  }
  model <- do.call(umato$UMATO, c(list(n_neighbors = n_neighbors), dots))
  umato_layout <- reticulate::py_to_r(model$fit_transform(mat))

  umato_layout <- tibble::as_tibble(umato_layout, .name_repair = "minimal")
  umato_layout$Sample <- phyloseq::sample_names(physeq)
  names(umato_layout) <- c("x_umato", "y_umato", "Sample")

  df_umato <- dplyr::left_join(umato_layout, psm_samp, by = "Sample")

  return(df_umato)
}

################################################################################
#' Coerce whole-number doubles to integers (internal)
#'
#' Python backends require `int` (not float) for seeds and count-like
#' parameters, while R users type them as doubles (e.g. `random_state = 42`).
#' @keywords internal
#' @noRd
.py_whole_doubles_as_int <- function(x) {
  lapply(x, function(v) {
    if (is.numeric(v) && length(v) == 1 && !is.integer(v) && v == floor(v)) {
      return(as.integer(v))
    }
    v
  })
}
################################################################################
