# UMATO embedding of a phyloseq object (Python backend)

[![lifecycle-experimental](https://img.shields.io/badge/lifecycle-experimental-orange)](https://adrientaudiere.github.io/MiscMetabar/articles/Rules.html#lifecycle)

Compute a 2-dimensional UMATO embedding (Jeon et al., 2025) of the
samples of a phyloseq object. UMATO bridges local and global structures:
unlike plain UMAP, the positions of the *hub* samples are optimised to
preserve global structure, giving a more reliable reading of the
relations between clusters. The embedding is computed by the Python
package `umato` through
[`reticulate::import()`](https://rstudio.github.io/reticulate/reference/import.html).

## Usage

``` r
umato_pq(physeq, n_neighbors = 15, ...)
```

## Arguments

- physeq:

  (required) A
  [phyloseq::phyloseq](https://rdrr.io/pkg/phyloseq/man/phyloseq-class.html)
  object with an `otu_table` and `sample_data`. Samples (rows of the
  count matrix) are embedded; taxa are features.

- n_neighbors:

  (int, default 15) Number of neighbours for the local manifold.
  Automatically capped to `nsamples - 1` so that small phyloseq objects
  still run. Passed to `umato.UMATO()`.

- ...:

  Additional arguments passed to `umato.UMATO()` (e.g. `metric`,
  `random_state`, `min_dist`, `init`). When `hub_num` is not given, it
  defaults to `min(300, nsamples - 1)` (the UMATO default of 300 fails
  on small data, where the number of hubs must stay below the number of
  samples).

## Value

A tibble with the columns `x_umato`, `y_umato`, `Sample` (sample name)
followed by every column of `sample_data`.

## Details

No transformation is done inside the function: the raw count matrix
(samples × taxa) is handed to the backend as is. Transform `physeq`
beforehand if needed (e.g.
[`phyloseq::transform_sample_counts()`](https://rdrr.io/pkg/phyloseq/man/transformcounts.html))
— as in
[`MiscMetabar::umap_pq()`](https://adrientaudiere.github.io/MiscMetabar/reference/umap_pq.html),
the Euclidean metric on the (possibly transformed) count matrix is the
default.

UMATO improves the *global* readability of the embedding, but distances
between clusters and cluster densities must still be interpreted with
care. For questions about point or cluster distances in the original
space, prefer a global technique: PCA
([`stats::prcomp()`](https://rdrr.io/r/stats/prcomp.html)) or MDS/PCoA
([`phyloseq::ordinate()`](https://rdrr.io/pkg/phyloseq/man/ordinate.html),
[`MiscMetabar::plot_ordination_pq()`](https://adrientaudiere.github.io/MiscMetabar/reference/plot_ordination_pq.html)).
[`dr_plot_pq()`](https://adrientaudiere.github.io/ggplotpq/reference/dr_plot_pq.md)
draws UMATO next to t-SNE, UMAP, PaCMAP, MDS and NMDS for a side-by-side
comparison.

The Python packages `reticulate` (R side) and `umato` (Python side) are
required; an informative error is thrown when either is missing (install
the Python module with `reticulate::py_install("umato", pip = TRUE)`).
The Python module `pynndescent` is also required when `physeq` has 10
samples or fewer: without it, `umato` falls back on a nearest-neighbour
search that crashes on such small data
(`reticulate::py_install("pynndescent", pip = TRUE)`).

## References

Jeon, H., Ko, K., Lee, S., Hyun, J., Yang, T., Go, G., Jo, J., & Seo, J.
(2025). UMATO: Bridging Local and Global Structures for Reliable Visual
Analytics with Dimensionality Reduction. *IEEE Transactions on
Visualization and Computer Graphics*.
[doi:10.1109/TVCG.2025.3602735](https://doi.org/10.1109/TVCG.2025.3602735)

Jeon, H., Park, J., Shin, S., & Seo, J. (2026). Stop Misusing t-SNE and
UMAP for Visual Analytics. *IEEE Transactions on Visualization and
Computer Graphics*.
[doi:10.48550/arXiv.2506.08725](https://doi.org/10.48550/arXiv.2506.08725)

## See also

[`pacmap_pq()`](https://adrientaudiere.github.io/ggplotpq/reference/pacmap_pq.md),
[`dr_plot_pq()`](https://adrientaudiere.github.io/ggplotpq/reference/dr_plot_pq.md),
[`MiscMetabar::umap_pq()`](https://adrientaudiere.github.io/MiscMetabar/reference/umap_pq.html),
[`MiscMetabar::tsne_pq()`](https://adrientaudiere.github.io/MiscMetabar/reference/tsne_pq.html)

## Author

Adrien Taudière

## Examples

``` r
if (FALSE) { # \dontrun{
data(data_fungi_mini, package = "MiscMetabar")
df_umato <- umato_pq(data_fungi_mini, n_neighbors = 15, random_state = 42)
ggplot2::ggplot(df_umato, ggplot2::aes(x = x_umato, y = y_umato, col = Height)) +
  ggplot2::geom_point(size = 2)
} # }
```
