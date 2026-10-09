# Compare six dimension-reduction techniques on a phyloseq object

[![lifecycle-experimental](https://img.shields.io/badge/lifecycle-experimental-orange)](https://adrientaudiere.github.io/MiscMetabar/articles/Rules.html#lifecycle)

Apply up to six dimensionality-reduction techniques to the samples of a
phyloseq object and draw them side by side in a single ggplot
(patchwork): t-SNE, UMAP, UMATO and PaCMAP (local / compromise
techniques) plus MDS and NMDS (global techniques). Because each
technique preserves a different aspect of the data, comparing them on
one figure is the safest way to read an embedding (Jeon et al., 2026;
Wang et al., 2021).

The t-SNE, UMATO and PaCMAP panels come from `ggplotpq`
([`tsne_pq()`](https://adrientaudiere.github.io/MiscMetabar/reference/tsne_pq.html)
is a re-export of
[`MiscMetabar::tsne_pq()`](https://adrientaudiere.github.io/MiscMetabar/reference/tsne_pq.html);
[`umato_pq()`](https://adrientaudiere.github.io/ggplotpq/reference/umato_pq.md)
and
[`pacmap_pq()`](https://adrientaudiere.github.io/ggplotpq/reference/pacmap_pq.md)
call Python through `reticulate`); the UMAP panel uses
[`MiscMetabar::umap_pq()`](https://adrientaudiere.github.io/MiscMetabar/reference/umap_pq.html);
the MDS and NMDS panels use
[`phyloseq::ordinate()`](https://rdrr.io/pkg/phyloseq/man/ordinate.html)
on the distance given by `distance`. Taxa with zero counts are dropped
first, so the NMDS species scores are not undefined when `physeq` is a
sparse subset.

## Usage

``` r
dr_plot_pq(
  physeq,
  fact = NULL,
  shape = NULL,
  label = NULL,
  distance = "bray",
  techniques = c("tsne", "umap", "umato", "pacmap", "mds", "nmds"),
  n_neighbors = 15,
  perplexity = NULL,
  seed = 42
)
```

## Arguments

- physeq:

  (required) A
  [phyloseq::phyloseq](https://rdrr.io/pkg/phyloseq/man/phyloseq-class.html)
  object with an `otu_table` and `sample_data`.

- fact:

  (default NULL) Name of a column of `sample_data` used to colour the
  samples on every panel.

- shape:

  (default NULL) Name of a column of `sample_data` used to set the point
  shape on every panel. The column is treated as discrete.

- label:

  (default NULL) Name of a column of `sample_data` (or `"Sample"` for
  the sample names) used to label the samples on every panel. Labels are
  drawn with
  [`ggrepel::geom_text_repel()`](https://ggrepel.slowkow.com/reference/geom_text_repel.html)
  when `ggrepel` is installed, and with
  [`ggplot2::geom_text()`](https://ggplot2.tidyverse.org/reference/geom_text.html)
  otherwise.

- distance:

  (default `"bray"`) Dissimilarity index passed to
  [`vegan::vegdist()`](https://vegandevs.github.io/vegan/reference/vegdist.html)
  for t-SNE and to
  [`phyloseq::ordinate()`](https://rdrr.io/pkg/phyloseq/man/ordinate.html)
  for MDS and NMDS. Not used by the count-matrix techniques (UMAP,
  UMATO, PaCMAP).

- techniques:

  (default `c("tsne", "umap", "umato", "pacmap", "mds", "nmds")`) Which
  panels to draw. Whatever the order of the vector, the panels are
  always arranged in three fixed family columns — **Local** (UMAP,
  t-SNE), **Global** (MDS, NMDS) and **Local/Global trade-off** (UMATO,
  PaCMAP) — each announced by a column header, so a missing technique
  leaves an empty cell in its family column. Use a subset to skip
  techniques whose backend is unavailable (e.g. the Python ones) or to
  speed up a quick look.

- n_neighbors:

  (int, default 15) Number of neighbours for the count-matrix techniques
  (UMAP, UMATO, PaCMAP). Capped internally when the number of samples is
  small.

- perplexity:

  (numeric, default NULL) Perplexity of t-SNE. With the default `NULL`,
  it is set to `min(30, floor((nsamples - 1) / 3))` so that small
  datasets run.

- seed:

  (default 42) Seed used for reproducibility:
  [`set.seed()`](https://rdrr.io/r/base/Random.html) before the R
  computations, and `random_state` for the Python backends.

## Value

A patchwork ggplot. Every panel is titled by the technique name and
subtitled by its own backend parameters (`perplexity` for t-SNE,
`n_neighbors` — and `hub_num` — for the count-matrix techniques,
`stress` for NMDS, explained variance for MDS); a single colour legend
for `fact` (and shape legend for `shape`), shared by all panels, sits
below the grid. The embedding data frames (one per technique, each with
the two coordinate columns, `Sample` and every `sample_data` column) are
attached as a named list in the attribute `layouts`, so they can be
reused without recomputing.

## Details

No transformation is done inside the function: rarefy or transform
`physeq` beforehand if needed (e.g.
[`phyloseq::rarefy_even_depth()`](https://rdrr.io/pkg/phyloseq/man/rarefy_even_depth.html),
[`phyloseq::transform_sample_counts()`](https://rdrr.io/pkg/phyloseq/man/transformcounts.html)).

t-SNE, UMAP and friends are **local** techniques: they are reliable for
neighbourhood, outlier and cluster identification, but the distances
between points or clusters, the cluster density and the class
separability read on the embedding must not be interpreted as faithful
to the original space. MDS (PCoA) and NMDS are **global** techniques
whose point positions better reflect the supplied distance matrix. UMATO
(Jeon et al., 2025) and PaCMAP (Wang et al., 2021) seek a compromise
between the two worlds — which is precisely why they are worth comparing
with the six-panel grid.

The Python packages `reticulate` (R side) and `umato` / `pacmap` (Python
side) are required for the UMATO and PaCMAP panels; install the Python
modules with `reticulate::py_install(c("umato", "pacmap"), pip = TRUE)`.

## References

Jeon, H., Park, J., Shin, S., & Seo, J. (2026). Stop Misusing t-SNE and
UMAP for Visual Analytics. *IEEE Transactions on Visualization and
Computer Graphics*.
[doi:10.48550/arXiv.2506.08725](https://doi.org/10.48550/arXiv.2506.08725)

Jeon, H., Ko, K., Lee, S., Hyun, J., Yang, T., Go, G., Jo, J., & Seo, J.
(2025). UMATO: Bridging Local and Global Structures for Reliable Visual
Analytics with Dimensionality Reduction. *IEEE Transactions on
Visualization and Computer Graphics*.
[doi:10.1109/TVCG.2025.3602735](https://doi.org/10.1109/TVCG.2025.3602735)

Wang, Y., Huang, H., Rudin, C., & Shaposhnik, Y. (2021). Understanding
How Dimension Reduction Tools Work: An Empirical Approach to Deciphering
t-SNE, UMAP, TriMap, and PaCMAP for Data Visualization. *Journal of
Machine Learning Research*, 22(201), 1-73.
[doi:10.48550/arXiv.2012.04456](https://doi.org/10.48550/arXiv.2012.04456)

## See also

[`umato_pq()`](https://adrientaudiere.github.io/ggplotpq/reference/umato_pq.md),
[`pacmap_pq()`](https://adrientaudiere.github.io/ggplotpq/reference/pacmap_pq.md),
[`MiscMetabar::umap_pq()`](https://adrientaudiere.github.io/MiscMetabar/reference/umap_pq.html),
[`MiscMetabar::tsne_pq()`](https://adrientaudiere.github.io/MiscMetabar/reference/tsne_pq.html),
[`MiscMetabar::plot_ordination_pq()`](https://adrientaudiere.github.io/MiscMetabar/reference/plot_ordination_pq.html)

## Author

Adrien Taudière

## Examples

``` r
data(data_fungi_mini, package = "MiscMetabar")
# \donttest{
if (requireNamespace("Rtsne", quietly = TRUE)) {
  p <- dr_plot_pq(
    prune_samples(sample_names(data_fungi_mini)[1:20], data_fungi_mini),
    fact = "Height",
    techniques = c("tsne", "mds", "nmds")
  )
  p

  dr_plot_pq(
    prune_samples(sample_names(data_fungi_mini)[1:20], data_fungi_mini),
    fact = "Height",
    shape = "Time",
    label = "Sample",
    techniques = c("mds", "nmds")
  )
}
#> ! Function arguments cannot be checked because the package divent is not attached.
#> → Add `CheckArguments=FALSE` to suppress this warning or run `library('divent')`.
#> ! Function arguments cannot be checked because the package divent is not attached.
#> → Add `CheckArguments=FALSE` to suppress this warning or run `library('divent')`.
#> ! Function arguments cannot be checked because the package divent is not attached.
#> → Add `CheckArguments=FALSE` to suppress this warning or run `library('divent')`.
#> ! Function arguments cannot be checked because the package divent is not attached.
#> → Add `CheckArguments=FALSE` to suppress this warning or run `library('divent')`.
#> ! Function arguments cannot be checked because the package divent is not attached.
#> → Add `CheckArguments=FALSE` to suppress this warning or run `library('divent')`.
#> ! Function arguments cannot be checked because the package divent is not attached.
#> → Add `CheckArguments=FALSE` to suppress this warning or run `library('divent')`.
#> ! Function arguments cannot be checked because the package divent is not attached.
#> → Add `CheckArguments=FALSE` to suppress this warning or run `library('divent')`.
#> ! Function arguments cannot be checked because the package divent is not attached.
#> → Add `CheckArguments=FALSE` to suppress this warning or run `library('divent')`.
#> ! Function arguments cannot be checked because the package divent is not attached.
#> → Add `CheckArguments=FALSE` to suppress this warning or run `library('divent')`.
#> ! Function arguments cannot be checked because the package divent is not attached.
#> → Add `CheckArguments=FALSE` to suppress this warning or run `library('divent')`.
#> ! Function arguments cannot be checked because the package divent is not attached.
#> → Add `CheckArguments=FALSE` to suppress this warning or run `library('divent')`.
#> ! Function arguments cannot be checked because the package divent is not attached.
#> → Add `CheckArguments=FALSE` to suppress this warning or run `library('divent')`.
#> ! Function arguments cannot be checked because the package divent is not attached.
#> → Add `CheckArguments=FALSE` to suppress this warning or run `library('divent')`.
#> ! Function arguments cannot be checked because the package divent is not attached.
#> → Add `CheckArguments=FALSE` to suppress this warning or run `library('divent')`.
#> ! Function arguments cannot be checked because the package divent is not attached.
#> → Add `CheckArguments=FALSE` to suppress this warning or run `library('divent')`.
#> ! Function arguments cannot be checked because the package divent is not attached.
#> → Add `CheckArguments=FALSE` to suppress this warning or run `library('divent')`.
#> ! Function arguments cannot be checked because the package divent is not attached.
#> → Add `CheckArguments=FALSE` to suppress this warning or run `library('divent')`.
#> ! Function arguments cannot be checked because the package divent is not attached.
#> → Add `CheckArguments=FALSE` to suppress this warning or run `library('divent')`.
#> ! Function arguments cannot be checked because the package divent is not attached.
#> → Add `CheckArguments=FALSE` to suppress this warning or run `library('divent')`.
#> ! Function arguments cannot be checked because the package divent is not attached.
#> → Add `CheckArguments=FALSE` to suppress this warning or run `library('divent')`.
#> ! Function arguments cannot be checked because the package divent is not attached.
#> → Add `CheckArguments=FALSE` to suppress this warning or run `library('divent')`.
#> ! Function arguments cannot be checked because the package divent is not attached.
#> → Add `CheckArguments=FALSE` to suppress this warning or run `library('divent')`.
#> ! Function arguments cannot be checked because the package divent is not attached.
#> → Add `CheckArguments=FALSE` to suppress this warning or run `library('divent')`.
#> ! Function arguments cannot be checked because the package divent is not attached.
#> → Add `CheckArguments=FALSE` to suppress this warning or run `library('divent')`.
#> ! Function arguments cannot be checked because the package divent is not attached.
#> → Add `CheckArguments=FALSE` to suppress this warning or run `library('divent')`.
#> ! Function arguments cannot be checked because the package divent is not attached.
#> → Add `CheckArguments=FALSE` to suppress this warning or run `library('divent')`.
#> ! Function arguments cannot be checked because the package divent is not attached.
#> → Add `CheckArguments=FALSE` to suppress this warning or run `library('divent')`.
#> ! Function arguments cannot be checked because the package divent is not attached.
#> → Add `CheckArguments=FALSE` to suppress this warning or run `library('divent')`.
#> ! Function arguments cannot be checked because the package divent is not attached.
#> → Add `CheckArguments=FALSE` to suppress this warning or run `library('divent')`.
#> ! Function arguments cannot be checked because the package divent is not attached.
#> → Add `CheckArguments=FALSE` to suppress this warning or run `library('divent')`.
#> ! Function arguments cannot be checked because the package divent is not attached.
#> → Add `CheckArguments=FALSE` to suppress this warning or run `library('divent')`.
#> ! Function arguments cannot be checked because the package divent is not attached.
#> → Add `CheckArguments=FALSE` to suppress this warning or run `library('divent')`.
#> ! Function arguments cannot be checked because the package divent is not attached.
#> → Add `CheckArguments=FALSE` to suppress this warning or run `library('divent')`.
#> ! Function arguments cannot be checked because the package divent is not attached.
#> → Add `CheckArguments=FALSE` to suppress this warning or run `library('divent')`.
#> ! Function arguments cannot be checked because the package divent is not attached.
#> → Add `CheckArguments=FALSE` to suppress this warning or run `library('divent')`.
#> ! Function arguments cannot be checked because the package divent is not attached.
#> → Add `CheckArguments=FALSE` to suppress this warning or run `library('divent')`.
#> ! Function arguments cannot be checked because the package divent is not attached.
#> → Add `CheckArguments=FALSE` to suppress this warning or run `library('divent')`.
#> ! Function arguments cannot be checked because the package divent is not attached.
#> → Add `CheckArguments=FALSE` to suppress this warning or run `library('divent')`.
#> ! Function arguments cannot be checked because the package divent is not attached.
#> → Add `CheckArguments=FALSE` to suppress this warning or run `library('divent')`.
#> ! Function arguments cannot be checked because the package divent is not attached.
#> → Add `CheckArguments=FALSE` to suppress this warning or run `library('divent')`.
#> ! Function arguments cannot be checked because the package divent is not attached.
#> → Add `CheckArguments=FALSE` to suppress this warning or run `library('divent')`.
#> ! Function arguments cannot be checked because the package divent is not attached.
#> → Add `CheckArguments=FALSE` to suppress this warning or run `library('divent')`.
#> ! Function arguments cannot be checked because the package divent is not attached.
#> → Add `CheckArguments=FALSE` to suppress this warning or run `library('divent')`.
#> ! Function arguments cannot be checked because the package divent is not attached.
#> → Add `CheckArguments=FALSE` to suppress this warning or run `library('divent')`.
#> ! Function arguments cannot be checked because the package divent is not attached.
#> → Add `CheckArguments=FALSE` to suppress this warning or run `library('divent')`.
#> ! Function arguments cannot be checked because the package divent is not attached.
#> → Add `CheckArguments=FALSE` to suppress this warning or run `library('divent')`.
#> ! Function arguments cannot be checked because the package divent is not attached.
#> → Add `CheckArguments=FALSE` to suppress this warning or run `library('divent')`.
#> ! Function arguments cannot be checked because the package divent is not attached.
#> → Add `CheckArguments=FALSE` to suppress this warning or run `library('divent')`.
#> ! Function arguments cannot be checked because the package divent is not attached.
#> → Add `CheckArguments=FALSE` to suppress this warning or run `library('divent')`.
#> ! Function arguments cannot be checked because the package divent is not attached.
#> → Add `CheckArguments=FALSE` to suppress this warning or run `library('divent')`.
#> ! Function arguments cannot be checked because the package divent is not attached.
#> → Add `CheckArguments=FALSE` to suppress this warning or run `library('divent')`.
#> ! Function arguments cannot be checked because the package divent is not attached.
#> → Add `CheckArguments=FALSE` to suppress this warning or run `library('divent')`.
#> ! Function arguments cannot be checked because the package divent is not attached.
#> → Add `CheckArguments=FALSE` to suppress this warning or run `library('divent')`.
#> ! Function arguments cannot be checked because the package divent is not attached.
#> → Add `CheckArguments=FALSE` to suppress this warning or run `library('divent')`.
#> ! Function arguments cannot be checked because the package divent is not attached.
#> → Add `CheckArguments=FALSE` to suppress this warning or run `library('divent')`.
#> ! Function arguments cannot be checked because the package divent is not attached.
#> → Add `CheckArguments=FALSE` to suppress this warning or run `library('divent')`.
#> ! Function arguments cannot be checked because the package divent is not attached.
#> → Add `CheckArguments=FALSE` to suppress this warning or run `library('divent')`.
#> ! Function arguments cannot be checked because the package divent is not attached.
#> → Add `CheckArguments=FALSE` to suppress this warning or run `library('divent')`.
#> ! Function arguments cannot be checked because the package divent is not attached.
#> → Add `CheckArguments=FALSE` to suppress this warning or run `library('divent')`.
#> ! Function arguments cannot be checked because the package divent is not attached.
#> → Add `CheckArguments=FALSE` to suppress this warning or run `library('divent')`.
#> Joining with `by = join_by(Sample)`
#> Joining with `by = join_by(Sample)`
#> ! Function arguments cannot be checked because the package divent is not attached.
#> → Add `CheckArguments=FALSE` to suppress this warning or run `library('divent')`.
#> ! Function arguments cannot be checked because the package divent is not attached.
#> → Add `CheckArguments=FALSE` to suppress this warning or run `library('divent')`.
#> ! Function arguments cannot be checked because the package divent is not attached.
#> → Add `CheckArguments=FALSE` to suppress this warning or run `library('divent')`.
#> ! Function arguments cannot be checked because the package divent is not attached.
#> → Add `CheckArguments=FALSE` to suppress this warning or run `library('divent')`.
#> ! Function arguments cannot be checked because the package divent is not attached.
#> → Add `CheckArguments=FALSE` to suppress this warning or run `library('divent')`.
#> ! Function arguments cannot be checked because the package divent is not attached.
#> → Add `CheckArguments=FALSE` to suppress this warning or run `library('divent')`.
#> ! Function arguments cannot be checked because the package divent is not attached.
#> → Add `CheckArguments=FALSE` to suppress this warning or run `library('divent')`.
#> ! Function arguments cannot be checked because the package divent is not attached.
#> → Add `CheckArguments=FALSE` to suppress this warning or run `library('divent')`.
#> ! Function arguments cannot be checked because the package divent is not attached.
#> → Add `CheckArguments=FALSE` to suppress this warning or run `library('divent')`.
#> ! Function arguments cannot be checked because the package divent is not attached.
#> → Add `CheckArguments=FALSE` to suppress this warning or run `library('divent')`.
#> ! Function arguments cannot be checked because the package divent is not attached.
#> → Add `CheckArguments=FALSE` to suppress this warning or run `library('divent')`.
#> ! Function arguments cannot be checked because the package divent is not attached.
#> → Add `CheckArguments=FALSE` to suppress this warning or run `library('divent')`.
#> ! Function arguments cannot be checked because the package divent is not attached.
#> → Add `CheckArguments=FALSE` to suppress this warning or run `library('divent')`.
#> ! Function arguments cannot be checked because the package divent is not attached.
#> → Add `CheckArguments=FALSE` to suppress this warning or run `library('divent')`.
#> ! Function arguments cannot be checked because the package divent is not attached.
#> → Add `CheckArguments=FALSE` to suppress this warning or run `library('divent')`.
#> ! Function arguments cannot be checked because the package divent is not attached.
#> → Add `CheckArguments=FALSE` to suppress this warning or run `library('divent')`.
#> ! Function arguments cannot be checked because the package divent is not attached.
#> → Add `CheckArguments=FALSE` to suppress this warning or run `library('divent')`.
#> ! Function arguments cannot be checked because the package divent is not attached.
#> → Add `CheckArguments=FALSE` to suppress this warning or run `library('divent')`.
#> ! Function arguments cannot be checked because the package divent is not attached.
#> → Add `CheckArguments=FALSE` to suppress this warning or run `library('divent')`.
#> ! Function arguments cannot be checked because the package divent is not attached.
#> → Add `CheckArguments=FALSE` to suppress this warning or run `library('divent')`.
#> ! Function arguments cannot be checked because the package divent is not attached.
#> → Add `CheckArguments=FALSE` to suppress this warning or run `library('divent')`.
#> ! Function arguments cannot be checked because the package divent is not attached.
#> → Add `CheckArguments=FALSE` to suppress this warning or run `library('divent')`.
#> ! Function arguments cannot be checked because the package divent is not attached.
#> → Add `CheckArguments=FALSE` to suppress this warning or run `library('divent')`.
#> ! Function arguments cannot be checked because the package divent is not attached.
#> → Add `CheckArguments=FALSE` to suppress this warning or run `library('divent')`.
#> ! Function arguments cannot be checked because the package divent is not attached.
#> → Add `CheckArguments=FALSE` to suppress this warning or run `library('divent')`.
#> ! Function arguments cannot be checked because the package divent is not attached.
#> → Add `CheckArguments=FALSE` to suppress this warning or run `library('divent')`.
#> ! Function arguments cannot be checked because the package divent is not attached.
#> → Add `CheckArguments=FALSE` to suppress this warning or run `library('divent')`.
#> ! Function arguments cannot be checked because the package divent is not attached.
#> → Add `CheckArguments=FALSE` to suppress this warning or run `library('divent')`.
#> ! Function arguments cannot be checked because the package divent is not attached.
#> → Add `CheckArguments=FALSE` to suppress this warning or run `library('divent')`.
#> ! Function arguments cannot be checked because the package divent is not attached.
#> → Add `CheckArguments=FALSE` to suppress this warning or run `library('divent')`.
#> ! Function arguments cannot be checked because the package divent is not attached.
#> → Add `CheckArguments=FALSE` to suppress this warning or run `library('divent')`.
#> ! Function arguments cannot be checked because the package divent is not attached.
#> → Add `CheckArguments=FALSE` to suppress this warning or run `library('divent')`.
#> ! Function arguments cannot be checked because the package divent is not attached.
#> → Add `CheckArguments=FALSE` to suppress this warning or run `library('divent')`.
#> ! Function arguments cannot be checked because the package divent is not attached.
#> → Add `CheckArguments=FALSE` to suppress this warning or run `library('divent')`.
#> ! Function arguments cannot be checked because the package divent is not attached.
#> → Add `CheckArguments=FALSE` to suppress this warning or run `library('divent')`.
#> ! Function arguments cannot be checked because the package divent is not attached.
#> → Add `CheckArguments=FALSE` to suppress this warning or run `library('divent')`.
#> ! Function arguments cannot be checked because the package divent is not attached.
#> → Add `CheckArguments=FALSE` to suppress this warning or run `library('divent')`.
#> ! Function arguments cannot be checked because the package divent is not attached.
#> → Add `CheckArguments=FALSE` to suppress this warning or run `library('divent')`.
#> ! Function arguments cannot be checked because the package divent is not attached.
#> → Add `CheckArguments=FALSE` to suppress this warning or run `library('divent')`.
#> ! Function arguments cannot be checked because the package divent is not attached.
#> → Add `CheckArguments=FALSE` to suppress this warning or run `library('divent')`.
#> ! Function arguments cannot be checked because the package divent is not attached.
#> → Add `CheckArguments=FALSE` to suppress this warning or run `library('divent')`.
#> ! Function arguments cannot be checked because the package divent is not attached.
#> → Add `CheckArguments=FALSE` to suppress this warning or run `library('divent')`.
#> ! Function arguments cannot be checked because the package divent is not attached.
#> → Add `CheckArguments=FALSE` to suppress this warning or run `library('divent')`.
#> ! Function arguments cannot be checked because the package divent is not attached.
#> → Add `CheckArguments=FALSE` to suppress this warning or run `library('divent')`.
#> ! Function arguments cannot be checked because the package divent is not attached.
#> → Add `CheckArguments=FALSE` to suppress this warning or run `library('divent')`.
#> ! Function arguments cannot be checked because the package divent is not attached.
#> → Add `CheckArguments=FALSE` to suppress this warning or run `library('divent')`.
#> ! Function arguments cannot be checked because the package divent is not attached.
#> → Add `CheckArguments=FALSE` to suppress this warning or run `library('divent')`.
#> ! Function arguments cannot be checked because the package divent is not attached.
#> → Add `CheckArguments=FALSE` to suppress this warning or run `library('divent')`.
#> ! Function arguments cannot be checked because the package divent is not attached.
#> → Add `CheckArguments=FALSE` to suppress this warning or run `library('divent')`.
#> ! Function arguments cannot be checked because the package divent is not attached.
#> → Add `CheckArguments=FALSE` to suppress this warning or run `library('divent')`.
#> ! Function arguments cannot be checked because the package divent is not attached.
#> → Add `CheckArguments=FALSE` to suppress this warning or run `library('divent')`.
#> ! Function arguments cannot be checked because the package divent is not attached.
#> → Add `CheckArguments=FALSE` to suppress this warning or run `library('divent')`.
#> ! Function arguments cannot be checked because the package divent is not attached.
#> → Add `CheckArguments=FALSE` to suppress this warning or run `library('divent')`.
#> ! Function arguments cannot be checked because the package divent is not attached.
#> → Add `CheckArguments=FALSE` to suppress this warning or run `library('divent')`.
#> ! Function arguments cannot be checked because the package divent is not attached.
#> → Add `CheckArguments=FALSE` to suppress this warning or run `library('divent')`.
#> ! Function arguments cannot be checked because the package divent is not attached.
#> → Add `CheckArguments=FALSE` to suppress this warning or run `library('divent')`.
#> ! Function arguments cannot be checked because the package divent is not attached.
#> → Add `CheckArguments=FALSE` to suppress this warning or run `library('divent')`.
#> ! Function arguments cannot be checked because the package divent is not attached.
#> → Add `CheckArguments=FALSE` to suppress this warning or run `library('divent')`.
#> ! Function arguments cannot be checked because the package divent is not attached.
#> → Add `CheckArguments=FALSE` to suppress this warning or run `library('divent')`.
#> ! Function arguments cannot be checked because the package divent is not attached.
#> → Add `CheckArguments=FALSE` to suppress this warning or run `library('divent')`.
#> Joining with `by = join_by(Sample)`
#> Square root transformation
#> Wisconsin double standardization
#> Run 0 stress 0.2017177 
#> Run 1 stress 0.1996773 
#> ... New best solution
#> ... Procrustes: rmse 0.1106859  max resid 0.211348 
#> Run 2 stress 0.188014 
#> ... New best solution
#> ... Procrustes: rmse 0.1681037  max resid 0.5448173 
#> Run 3 stress 0.1961368 
#> Run 4 stress 0.2001809 
#> Run 5 stress 0.1757172 
#> ... New best solution
#> ... Procrustes: rmse 0.1191586  max resid 0.4743412 
#> Run 6 stress 0.1757172 
#> ... New best solution
#> ... Procrustes: rmse 7.167509e-05  max resid 0.0002387343 
#> ... Similar to previous best
#> Run 7 stress 0.1757172 
#> ... Procrustes: rmse 6.713387e-05  max resid 0.0002225891 
#> ... Similar to previous best
#> Run 8 stress 0.1757172 
#> ... Procrustes: rmse 0.0001095239  max resid 0.0003041361 
#> ... Similar to previous best
#> Run 9 stress 0.2055651 
#> Run 10 stress 0.1777205 
#> Run 11 stress 0.1784507 
#> Run 12 stress 0.2033371 
#> Run 13 stress 0.1904317 
#> Run 14 stress 0.1777204 
#> Run 15 stress 0.1757172 
#> ... Procrustes: rmse 6.190299e-05  max resid 0.0001736256 
#> ... Similar to previous best
#> Run 16 stress 0.1792992 
#> Run 17 stress 0.1830048 
#> Run 18 stress 0.1757172 
#> ... Procrustes: rmse 3.455346e-05  max resid 7.69384e-05 
#> ... Similar to previous best
#> Run 19 stress 0.1964398 
#> Run 20 stress 0.1757172 
#> ... Procrustes: rmse 6.298589e-05  max resid 0.0001972754 
#> ... Similar to previous best
#> *** Best solution repeated 6 times
#> ! Function arguments cannot be checked because the package divent is not attached.
#> → Add `CheckArguments=FALSE` to suppress this warning or run `library('divent')`.
#> ! Function arguments cannot be checked because the package divent is not attached.
#> → Add `CheckArguments=FALSE` to suppress this warning or run `library('divent')`.
#> ! Function arguments cannot be checked because the package divent is not attached.
#> → Add `CheckArguments=FALSE` to suppress this warning or run `library('divent')`.
#> ! Function arguments cannot be checked because the package divent is not attached.
#> → Add `CheckArguments=FALSE` to suppress this warning or run `library('divent')`.
#> ! Function arguments cannot be checked because the package divent is not attached.
#> → Add `CheckArguments=FALSE` to suppress this warning or run `library('divent')`.
#> ! Function arguments cannot be checked because the package divent is not attached.
#> → Add `CheckArguments=FALSE` to suppress this warning or run `library('divent')`.
#> ! Function arguments cannot be checked because the package divent is not attached.
#> → Add `CheckArguments=FALSE` to suppress this warning or run `library('divent')`.
#> ! Function arguments cannot be checked because the package divent is not attached.
#> → Add `CheckArguments=FALSE` to suppress this warning or run `library('divent')`.
#> ! Function arguments cannot be checked because the package divent is not attached.
#> → Add `CheckArguments=FALSE` to suppress this warning or run `library('divent')`.
#> ! Function arguments cannot be checked because the package divent is not attached.
#> → Add `CheckArguments=FALSE` to suppress this warning or run `library('divent')`.
#> ! Function arguments cannot be checked because the package divent is not attached.
#> → Add `CheckArguments=FALSE` to suppress this warning or run `library('divent')`.
#> ! Function arguments cannot be checked because the package divent is not attached.
#> → Add `CheckArguments=FALSE` to suppress this warning or run `library('divent')`.
#> ! Function arguments cannot be checked because the package divent is not attached.
#> → Add `CheckArguments=FALSE` to suppress this warning or run `library('divent')`.
#> ! Function arguments cannot be checked because the package divent is not attached.
#> → Add `CheckArguments=FALSE` to suppress this warning or run `library('divent')`.
#> ! Function arguments cannot be checked because the package divent is not attached.
#> → Add `CheckArguments=FALSE` to suppress this warning or run `library('divent')`.
#> ! Function arguments cannot be checked because the package divent is not attached.
#> → Add `CheckArguments=FALSE` to suppress this warning or run `library('divent')`.
#> ! Function arguments cannot be checked because the package divent is not attached.
#> → Add `CheckArguments=FALSE` to suppress this warning or run `library('divent')`.
#> ! Function arguments cannot be checked because the package divent is not attached.
#> → Add `CheckArguments=FALSE` to suppress this warning or run `library('divent')`.
#> ! Function arguments cannot be checked because the package divent is not attached.
#> → Add `CheckArguments=FALSE` to suppress this warning or run `library('divent')`.
#> ! Function arguments cannot be checked because the package divent is not attached.
#> → Add `CheckArguments=FALSE` to suppress this warning or run `library('divent')`.
#> ! Function arguments cannot be checked because the package divent is not attached.
#> → Add `CheckArguments=FALSE` to suppress this warning or run `library('divent')`.
#> ! Function arguments cannot be checked because the package divent is not attached.
#> → Add `CheckArguments=FALSE` to suppress this warning or run `library('divent')`.
#> ! Function arguments cannot be checked because the package divent is not attached.
#> → Add `CheckArguments=FALSE` to suppress this warning or run `library('divent')`.
#> ! Function arguments cannot be checked because the package divent is not attached.
#> → Add `CheckArguments=FALSE` to suppress this warning or run `library('divent')`.
#> ! Function arguments cannot be checked because the package divent is not attached.
#> → Add `CheckArguments=FALSE` to suppress this warning or run `library('divent')`.
#> ! Function arguments cannot be checked because the package divent is not attached.
#> → Add `CheckArguments=FALSE` to suppress this warning or run `library('divent')`.
#> ! Function arguments cannot be checked because the package divent is not attached.
#> → Add `CheckArguments=FALSE` to suppress this warning or run `library('divent')`.
#> ! Function arguments cannot be checked because the package divent is not attached.
#> → Add `CheckArguments=FALSE` to suppress this warning or run `library('divent')`.
#> ! Function arguments cannot be checked because the package divent is not attached.
#> → Add `CheckArguments=FALSE` to suppress this warning or run `library('divent')`.
#> ! Function arguments cannot be checked because the package divent is not attached.
#> → Add `CheckArguments=FALSE` to suppress this warning or run `library('divent')`.
#> ! Function arguments cannot be checked because the package divent is not attached.
#> → Add `CheckArguments=FALSE` to suppress this warning or run `library('divent')`.
#> ! Function arguments cannot be checked because the package divent is not attached.
#> → Add `CheckArguments=FALSE` to suppress this warning or run `library('divent')`.
#> ! Function arguments cannot be checked because the package divent is not attached.
#> → Add `CheckArguments=FALSE` to suppress this warning or run `library('divent')`.
#> ! Function arguments cannot be checked because the package divent is not attached.
#> → Add `CheckArguments=FALSE` to suppress this warning or run `library('divent')`.
#> ! Function arguments cannot be checked because the package divent is not attached.
#> → Add `CheckArguments=FALSE` to suppress this warning or run `library('divent')`.
#> ! Function arguments cannot be checked because the package divent is not attached.
#> → Add `CheckArguments=FALSE` to suppress this warning or run `library('divent')`.
#> ! Function arguments cannot be checked because the package divent is not attached.
#> → Add `CheckArguments=FALSE` to suppress this warning or run `library('divent')`.
#> ! Function arguments cannot be checked because the package divent is not attached.
#> → Add `CheckArguments=FALSE` to suppress this warning or run `library('divent')`.
#> ! Function arguments cannot be checked because the package divent is not attached.
#> → Add `CheckArguments=FALSE` to suppress this warning or run `library('divent')`.
#> ! Function arguments cannot be checked because the package divent is not attached.
#> → Add `CheckArguments=FALSE` to suppress this warning or run `library('divent')`.
#> ! Function arguments cannot be checked because the package divent is not attached.
#> → Add `CheckArguments=FALSE` to suppress this warning or run `library('divent')`.
#> ! Function arguments cannot be checked because the package divent is not attached.
#> → Add `CheckArguments=FALSE` to suppress this warning or run `library('divent')`.
#> ! Function arguments cannot be checked because the package divent is not attached.
#> → Add `CheckArguments=FALSE` to suppress this warning or run `library('divent')`.
#> ! Function arguments cannot be checked because the package divent is not attached.
#> → Add `CheckArguments=FALSE` to suppress this warning or run `library('divent')`.
#> ! Function arguments cannot be checked because the package divent is not attached.
#> → Add `CheckArguments=FALSE` to suppress this warning or run `library('divent')`.
#> ! Function arguments cannot be checked because the package divent is not attached.
#> → Add `CheckArguments=FALSE` to suppress this warning or run `library('divent')`.
#> ! Function arguments cannot be checked because the package divent is not attached.
#> → Add `CheckArguments=FALSE` to suppress this warning or run `library('divent')`.
#> ! Function arguments cannot be checked because the package divent is not attached.
#> → Add `CheckArguments=FALSE` to suppress this warning or run `library('divent')`.
#> ! Function arguments cannot be checked because the package divent is not attached.
#> → Add `CheckArguments=FALSE` to suppress this warning or run `library('divent')`.
#> ! Function arguments cannot be checked because the package divent is not attached.
#> → Add `CheckArguments=FALSE` to suppress this warning or run `library('divent')`.
#> ! Function arguments cannot be checked because the package divent is not attached.
#> → Add `CheckArguments=FALSE` to suppress this warning or run `library('divent')`.
#> ! Function arguments cannot be checked because the package divent is not attached.
#> → Add `CheckArguments=FALSE` to suppress this warning or run `library('divent')`.
#> ! Function arguments cannot be checked because the package divent is not attached.
#> → Add `CheckArguments=FALSE` to suppress this warning or run `library('divent')`.
#> ! Function arguments cannot be checked because the package divent is not attached.
#> → Add `CheckArguments=FALSE` to suppress this warning or run `library('divent')`.
#> ! Function arguments cannot be checked because the package divent is not attached.
#> → Add `CheckArguments=FALSE` to suppress this warning or run `library('divent')`.
#> ! Function arguments cannot be checked because the package divent is not attached.
#> → Add `CheckArguments=FALSE` to suppress this warning or run `library('divent')`.
#> ! Function arguments cannot be checked because the package divent is not attached.
#> → Add `CheckArguments=FALSE` to suppress this warning or run `library('divent')`.
#> ! Function arguments cannot be checked because the package divent is not attached.
#> → Add `CheckArguments=FALSE` to suppress this warning or run `library('divent')`.
#> ! Function arguments cannot be checked because the package divent is not attached.
#> → Add `CheckArguments=FALSE` to suppress this warning or run `library('divent')`.
#> ! Function arguments cannot be checked because the package divent is not attached.
#> → Add `CheckArguments=FALSE` to suppress this warning or run `library('divent')`.
#> Joining with `by = join_by(Sample)`
#> Square root transformation
#> Wisconsin double standardization
#> Run 0 stress 0.2017177 
#> Run 1 stress 0.1880148 
#> ... New best solution
#> ... Procrustes: rmse 0.1815892  max resid 0.5258687 
#> Run 2 stress 0.1757172 
#> ... New best solution
#> ... Procrustes: rmse 0.1195723  max resid 0.4761103 
#> Run 3 stress 0.1830048 
#> Run 4 stress 0.1974072 
#> Run 5 stress 0.1996785 
#> Run 6 stress 0.2055641 
#> Run 7 stress 0.1757172 
#> ... Procrustes: rmse 2.94605e-05  max resid 5.789093e-05 
#> ... Similar to previous best
#> Run 8 stress 0.1792993 
#> Run 9 stress 0.203337 
#> Run 10 stress 0.2333336 
#> Run 11 stress 0.1951291 
#> Run 12 stress 0.188015 
#> Run 13 stress 0.2046136 
#> Run 14 stress 0.1904317 
#> Run 15 stress 0.1792992 
#> Run 16 stress 0.1792993 
#> Run 17 stress 0.2161456 
#> Run 18 stress 0.2049353 
#> Run 19 stress 0.2077781 
#> Run 20 stress 0.1777206 
#> *** Best solution repeated 1 times

# }
if (FALSE) { # \dontrun{
dr_plot_pq(data_fungi_mini, fact = "Height")
} # }
```
