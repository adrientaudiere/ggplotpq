################################################################################
#' Compare six dimension-reduction techniques on a phyloseq object
#'
#' @description
#'
#' <a href="https://adrientaudiere.github.io/MiscMetabar/articles/Rules.html#lifecycle">
#' <img src="https://img.shields.io/badge/lifecycle-experimental-orange" alt="lifecycle-experimental"></a>
#'
#' Apply up to six dimensionality-reduction techniques to the samples of a
#' phyloseq object and draw them side by side in a single ggplot (patchwork):
#' t-SNE, UMAP, UMATO and PaCMAP (local / compromise techniques) plus MDS and
#' NMDS (global techniques). Because each technique preserves a different
#' aspect of the data, comparing them on one figure is the safest way to read
#' an embedding (Jeon et al., 2026; Wang et al., 2021).
#'
#' The t-SNE, UMATO and PaCMAP panels come from `ggplotpq` ([tsne_pq()] is a
#' re-export of [MiscMetabar::tsne_pq()]; [umato_pq()] and [pacmap_pq()] call
#' Python through `reticulate`); the UMAP panel uses [MiscMetabar::umap_pq()];
#' the MDS and NMDS panels use [phyloseq::ordinate()] on the distance given
#' by `distance`.
#'
#' @param physeq (required) A [phyloseq::phyloseq-class] object with an
#'   `otu_table` and `sample_data`.
#' @param fact (default NULL) Name of a column of `sample_data` used to
#'   colour the samples on every panel.
#' @param distance (default `"bray"`) Dissimilarity index passed to
#'   [vegan::vegdist()] for t-SNE and to [phyloseq::ordinate()] for MDS and
#'   NMDS. Not used by the count-matrix techniques (UMAP, UMATO, PaCMAP).
#' @param techniques (default `c("tsne", "umap", "umato", "pacmap", "mds",
#'   "nmds")`) Which panels to draw. Whatever the order of the vector, the
#'   panels are always arranged in three fixed family columns — **Local**
#'   (UMAP, t-SNE), **Global** (MDS, NMDS) and **Local/Global trade-off**
#'   (UMATO, PaCMAP) — each announced by a column header, so a missing
#'   technique leaves an empty cell in its family column. Use a subset to
#'   skip techniques whose backend is unavailable (e.g. the Python ones) or
#'   to speed up a quick look.
#' @param n_neighbors (int, default 15) Number of neighbours for the
#'   count-matrix techniques (UMAP, UMATO, PaCMAP). Capped internally when
#'   the number of samples is small.
#' @param perplexity (numeric, default NULL) Perplexity of t-SNE. With the
#'   default `NULL`, it is set to `min(30, floor((nsamples - 1) / 3))` so
#'   that small datasets run.
#' @param seed (default 42) Seed used for reproducibility: [set.seed()]
#'   before the R computations, and `random_state` for the Python backends.
#'
#' @return A patchwork ggplot. Every panel is titled by the technique name and
#'   subtitled by its own backend parameters (`perplexity` for t-SNE,
#'   `n_neighbors` — and `hub_num` — for the count-matrix techniques,
#'   `stress` for NMDS, explained variance for MDS); a single colour legend
#'   for `fact`, shared by all panels, sits below the grid. The embedding
#'   data frames (one per technique, each with the two coordinate columns,
#'   `Sample` and every `sample_data` column) are attached as a named list
#'   in the attribute `layouts`, so they can be reused without recomputing.
#'
#' @details
#' No transformation is done inside the function: rarefy or transform
#' `physeq` beforehand if needed (e.g. [phyloseq::rarefy_even_depth()],
#' [phyloseq::transform_sample_counts()]).
#'
#' t-SNE, UMAP and friends are **local** techniques: they are reliable for
#' neighbourhood, outlier and cluster identification, but the distances
#' between points or clusters, the cluster density and the class separability
#' read on the embedding must not be interpreted as faithful to the original
#' space. MDS (PCoA) and NMDS are **global** techniques whose point positions
#' better reflect the supplied distance matrix. UMATO (Jeon et al., 2025) and
#' PaCMAP (Wang et al., 2021) seek a compromise between the two worlds —
#' which is precisely why they are worth comparing with the six-panel grid.
#'
#' The Python packages `reticulate` (R side) and `umato` / `pacmap`
#' (Python side) are required for the UMATO and PaCMAP panels; install the
#' Python modules with
#' `reticulate::py_install(c("umato", "pacmap"), pip = TRUE)`.
#'
#' @export
#' @author Adrien Taudière
#'
#' @references
#' Jeon, H., Park, J., Shin, S., & Seo, J. (2026). Stop Misusing t-SNE and UMAP
#'   for Visual Analytics. *IEEE Transactions on Visualization and Computer
#'   Graphics*. \doi{10.48550/arXiv.2506.08725}
#'
#' Jeon, H., Ko, K., Lee, S., Hyun, J., Yang, T., Go, G., Jo, J., & Seo, J.
#'   (2025). UMATO: Bridging Local and Global Structures for Reliable Visual
#'   Analytics with Dimensionality Reduction. *IEEE Transactions on
#'   Visualization and Computer Graphics*. \doi{10.1109/TVCG.2025.3602735}
#'
#' Wang, Y., Huang, H., Rudin, C., & Shaposhnik, Y. (2021). Understanding How
#'   Dimension Reduction Tools Work: An Empirical Approach to Deciphering
#'   t-SNE, UMAP, TriMap, and PaCMAP for Data Visualization. *Journal of
#'   Machine Learning Research*, 22(201), 1-73.
#'   \doi{10.48550/arXiv.2012.04456}
#'
#' @seealso [umato_pq()], [pacmap_pq()], [MiscMetabar::umap_pq()],
#'   [MiscMetabar::tsne_pq()], [MiscMetabar::plot_ordination_pq()]
#'
#' @examples
#' data(data_fungi_mini, package = "MiscMetabar")
#' \donttest{
#' if (requireNamespace("Rtsne", quietly = TRUE)) {
#'   p <- dr_plot_pq(
#'     prune_samples(sample_names(data_fungi_mini)[1:20], data_fungi_mini),
#'     fact = "Height",
#'     techniques = c("tsne", "mds", "nmds")
#'   )
#'   p
#' }
#' }
#' \dontrun{
#' dr_plot_pq(data_fungi_mini, fact = "Height")
#' }
dr_plot_pq <- function(
  physeq,
  fact = NULL,
  distance = "bray",
  techniques = c("tsne", "umap", "umato", "pacmap", "mds", "nmds"),
  n_neighbors = 15,
  perplexity = NULL,
  seed = 42
) {
  MiscMetabar::verify_pq(physeq)
  if (!is.null(fact)) {
    MiscMetabar::verify_fact_pq(physeq, fact = fact)
  }
  techniques <- match.arg(
    techniques,
    choices = c("tsne", "umap", "umato", "pacmap", "mds", "nmds"),
    several.ok = TRUE
  )
  if (length(techniques) == 0) {
    cli::cli_abort("{.arg techniques} must contain at least one technique.")
  }
  if (phyloseq::nsamples(physeq) < 5) {
    cli::cli_abort(
      "{.arg physeq} must have at least 5 samples for a dimension-reduction comparison."
    )
  }

  set.seed(seed)

  n_samples <- phyloseq::nsamples(physeq)
  n_neighbors <- as.integer(max(2, min(n_neighbors, n_samples - 1)))
  perplexity <- if (is.null(perplexity)) {
    min(30, floor((n_samples - 1) / 3))
  } else {
    min(perplexity, floor((n_samples - 1) / 3))
  }

  layouts <- list()
  subtitles <- list()

  # ---- local / compromise techniques on the count matrix ---------------------
  if ("tsne" %in% techniques) {
    if (!requireNamespace("Rtsne", quietly = TRUE)) {
      cli::cli_abort(
        c(
          "Package {.pkg Rtsne} is required for the t-SNE panel.",
          "i" = "Install it with {.code install.packages(\"Rtsne\")}."
        )
      )
    }
    layouts$tsne <- MiscMetabar::tsne_pq(
      physeq,
      method = distance,
      perplexity = perplexity
    )
    subtitles$tsne <- paste0("perplexity = ", perplexity)
  }
  if ("umap" %in% techniques) {
    if (!requireNamespace("umap", quietly = TRUE)) {
      cli::cli_abort(
        c(
          "Package {.pkg umap} is required for the UMAP panel.",
          "i" = "Install it with {.code install.packages(\"umap\")}."
        )
      )
    }
    layouts$umap <- MiscMetabar::umap_pq(
      physeq,
      pkg = "umap",
      n_neighbors = n_neighbors,
      random_state = seed
    )
    subtitles$umap <- paste0("n_neighbors = ", n_neighbors)
  }
  hub_num_used <- as.integer(min(300, n_samples - 1))
  if ("umato" %in% techniques) {
    layouts$umato <- umato_pq(
      physeq,
      n_neighbors = n_neighbors,
      random_state = seed
    )
    subtitles$umato <- paste0(
      "n_neighbors = ",
      n_neighbors,
      ", hub_num = ",
      hub_num_used
    )
  }
  if ("pacmap" %in% techniques) {
    layouts$pacmap <- pacmap_pq(
      physeq,
      n_neighbors = n_neighbors,
      random_state = seed
    )
    subtitles$pacmap <- paste0("n_neighbors = ", n_neighbors)
  }

  # ---- global techniques on the distance matrix ------------------------------
  psm_samp <- MiscMetabar::psmelt_samples_pq(physeq)
  ord_panel <- function(ordination_method) {
    ord <- phyloseq::ordinate(
      physeq,
      method = ordination_method,
      distance = distance
    )
    coords <- phyloseq::plot_ordination(physeq, ord, justDF = TRUE)
    # The first two columns are the axis coordinates (Axis.1/Axis.2 for MDS,
    # NMDS1/NMDS2 for NMDS, ...); the sample_data columns come after.
    coords <- coords[, 1:2]
    names(coords) <- c("x_ord", "y_ord")
    coords$Sample <- rownames(coords)
    coords <- dplyr::left_join(
      tibble::as_tibble(coords, .name_repair = "minimal"),
      psm_samp,
      by = "Sample"
    )
    subtitle <- if (ordination_method == "NMDS") {
      paste0("stress = ", round(ord$stress, digits = 3))
    } else if (!is.null(ord$values)) {
      ve <- round(100 * ord$values$Relative_eig[1:2], digits = 1)
      paste0("variance explained: ", ve[1], "% / ", ve[2], "%")
    } else {
      NULL
    }
    list(coords, subtitle)
  }
  if ("mds" %in% techniques) {
    res <- ord_panel("MDS")
    layouts$mds <- res[[1]]
    subtitles$mds <- res[[2]]
  }
  if ("nmds" %in% techniques) {
    res <- ord_panel("NMDS")
    layouts$nmds <- res[[1]]
    subtitles$nmds <- res[[2]]
  }

  x_name <- c(
    tsne = "x_tsne",
    umap = "x_umap",
    umato = "x_umato",
    pacmap = "x_pacmap",
    mds = "x_ord",
    nmds = "x_ord"
  )
  y_name <- c(
    tsne = "y_tsne",
    umap = "y_umap",
    umato = "y_umato",
    pacmap = "y_pacmap",
    mds = "y_ord",
    nmds = "y_ord"
  )

  tech_title <- c(
    tsne = "t-SNE",
    umap = "UMAP",
    umato = "UMATO",
    pacmap = "PaCMAP",
    mds = "MDS",
    nmds = "NMDS"
  )
  panels <- lapply(techniques, function(tech) {
    df <- layouts[[tech]]
    if (!is.null(fact)) {
      df$.fact_col <- as.character(df[[fact]])
    }
    p <- ggplot2::ggplot(
      df,
      ggplot2::aes(x = .data[[x_name[tech]]], y = .data[[y_name[tech]]])
    )
    if (!is.null(fact)) {
      p <- p + ggplot2::aes(color = .data$.fact_col)
    }
    p +
      ggplot2::geom_point(size = 2, alpha = 0.8) +
      ggplot2::labs(
        title = tech_title[[tech]],
        subtitle = subtitles[[tech]],
        x = NULL,
        y = NULL,
        color = fact
      ) +
      ggplot2::theme_bw()
  })
  names(panels) <- techniques

  # Panels always sit in their family column (Local | Global | Compromise) so
  # the six techniques are comparable at a glance; the family column headers
  # are drawn as a slim top row.
  slots <- list(
    local = c(umap = 1, tsne = 2),
    global = c(mds = 1, nmds = 2),
    compromise = c(umato = 1, pacmap = 2)
  )
  col_titles <- c(
    local = "Local",
    global = "Global",
    compromise = "Local/Global trade-off"
  )
  used_fams <- vapply(
    names(slots),
    function(fam) any(names(slots[[fam]]) %in% techniques),
    logical(1L)
  )
  n_cols <- sum(used_fams)
  grid <- matrix("#", nrow = 3, ncol = 2 * n_cols - 1)
  plot_letters <- LETTERS[(n_cols + 1):(n_cols + length(techniques))]
  # place title cells on the first row
  for (j in seq_len(n_cols)) {
    grid[1, 2 * j - 1] <- LETTERS[j]
  }
  # place the panels of each family in their row slot
  row_of_letter <- setNames(plot_letters, techniques)
  pos <- 1L
  for (fam in names(slots)[used_fams]) {
    fam_techs <- intersect(names(slots[[fam]]), techniques)
    for (tech in fam_techs) {
      row <- slots[[fam]][[tech]]
      grid[row + 1, 2 * pos - 1] <- row_of_letter[[tech]]
    }
    pos <- pos + 1
  }
  grid_str <- paste(apply(grid, 1, paste0, collapse = ""), collapse = "\n")

  title_cell <- function(label) {
    ggplot2::ggplot() +
      ggplot2::annotate(
        "text",
        x = 0.5,
        y = 0.5,
        label = label,
        fontface = "bold",
        size = 4
      ) +
      ggplot2::theme_void()
  }

  plots <- list()
  for (j in seq_len(n_cols)) {
    fam <- names(slots)[which(used_fams)[j]]
    plots[[LETTERS[j]]] <- title_cell(col_titles[[fam]])
  }
  for (i in seq_along(techniques)) {
    plots[[plot_letters[i]]] <- panels[[techniques[i]]]
  }

  p_dr <- do.call(
    patchwork::wrap_plots,
    c(plots, list(design = grid_str, guides = "collect"))
  ) +
    patchwork::plot_annotation(
      title = "Six dimensionality-reduction techniques",
      subtitle = paste0(
        "Local techniques preserve neighbourhoods; MDS/NMDS preserve global distances. ",
        "Distance: ",
        distance,
        "; n = ",
        n_samples,
        " samples"
      ),
      theme = ggplot2::theme(plot.title = ggplot2::element_text(face = "bold"))
    ) &
    ggplot2::theme(legend.position = "bottom")

  attr(p_dr, "layouts") <- layouts
  return(p_dr)
}
################################################################################
