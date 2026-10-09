# PaCMAP embedding of a phyloseq object (Python backend)

[![lifecycle-experimental](https://img.shields.io/badge/lifecycle-experimental-orange)](https://adrientaudiere.github.io/MiscMetabar/articles/Rules.html#lifecycle)

Compute a 2-dimensional PaCMAP embedding (Wang et al., 2021) of the
samples of a phyloseq object. PaCMAP optimises the preservation of both
local and global structure by balancing three kinds of pair constraints
(neighbour pairs, mid-near pairs and far pairs), and was among the best
compromises in the empirical comparison of Wang et al. (2021). The
embedding is computed by the Python package `pacmap` through
[`reticulate::import()`](https://rstudio.github.io/reticulate/reference/import.html).

## Usage

``` r
pacmap_pq(physeq, n_neighbors = 10, ...)
```

## Arguments

- physeq:

  (required) A
  [phyloseq::phyloseq](https://rdrr.io/pkg/phyloseq/man/phyloseq-class.html)
  object with an `otu_table` and `sample_data`. Samples (rows of the
  count matrix) are embedded; taxa are features.

- n_neighbors:

  (int, default 10) Number of neighbour pairs. PaCMAP itself reorganises
  the pair budget when the sample size is too small (see its warnings).
  Passed to `pacmap.PaCMAP()`.

- ...:

  Additional arguments passed to `pacmap.PaCMAP()` (e.g. `distance`,
  `MN_ratio`, `FP_ratio`, `num_iters`, `apply_pca`, `random_state`).

## Value

A tibble with the columns `x_pacmap`, `y_pacmap`, `Sample` (sample name)
followed by every column of `sample_data`.

## Details

No transformation is done inside the function: the raw count matrix
(samples × taxa) is handed to the backend as is (with
`apply_pca = TRUE`, the PaCMAP default, an initial PCA projection is
computed internally). Transform `physeq` beforehand if needed (e.g.
[`phyloseq::transform_sample_counts()`](https://rdrr.io/pkg/phyloseq/man/transformcounts.html)).

PaCMAP improves the *global* readability of the embedding, but distances
between clusters and cluster densities must still be interpreted with
care. For questions about point or cluster distances in the original
space, prefer a global technique: PCA
([`stats::prcomp()`](https://rdrr.io/r/stats/prcomp.html)) or MDS/PCoA
([`phyloseq::ordinate()`](https://rdrr.io/pkg/phyloseq/man/ordinate.html),
[`MiscMetabar::plot_ordination_pq()`](https://adrientaudiere.github.io/MiscMetabar/reference/plot_ordination_pq.html)).
[`dr_plot_pq()`](https://adrientaudiere.github.io/ggplotpq/reference/dr_plot_pq.md)
draws PaCMAP next to t-SNE, UMAP, UMATO, MDS and NMDS for a side-by-side
comparison.

The Python packages `reticulate` (R side) and `pacmap` (Python side) are
required; an informative error is thrown when either is missing (install
the Python module with `reticulate::py_install("pacmap", pip = TRUE)`).

## References

Wang, Y., Huang, H., Rudin, C., & Shaposhnik, Y. (2021). Understanding
How Dimension Reduction Tools Work: An Empirical Approach to Deciphering
t-SNE, UMAP, TriMap, and PaCMAP for Data Visualization. *Journal of
Machine Learning Research*, 22(201), 1-73.
[doi:10.48550/arXiv.2012.04456](https://doi.org/10.48550/arXiv.2012.04456)

Jeon, H., Park, J., Shin, S., & Seo, J. (2026). Stop Misusing t-SNE and
UMAP for Visual Analytics. *IEEE Transactions on Visualization and
Computer Graphics*.
[doi:10.48550/arXiv.2506.08725](https://doi.org/10.48550/arXiv.2506.08725)

## See also

[`umato_pq()`](https://adrientaudiere.github.io/ggplotpq/reference/umato_pq.md),
[`dr_plot_pq()`](https://adrientaudiere.github.io/ggplotpq/reference/dr_plot_pq.md),
[`MiscMetabar::umap_pq()`](https://adrientaudiere.github.io/MiscMetabar/reference/umap_pq.html),
[`MiscMetabar::tsne_pq()`](https://adrientaudiere.github.io/MiscMetabar/reference/tsne_pq.html)

## Author

Adrien Taudière

## Examples

``` r
if (FALSE) { # \dontrun{
data(data_fungi_mini, package = "MiscMetabar")
df_pacmap <- pacmap_pq(data_fungi_mini, n_neighbors = 10, random_state = 42)
ggplot2::ggplot(
  df_pacmap,
  ggplot2::aes(x = x_pacmap, y = y_pacmap, col = Height)
) +
  ggplot2::geom_point(size = 2)
} # }
```
