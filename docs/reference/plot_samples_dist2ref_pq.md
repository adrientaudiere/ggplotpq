# Distance of every sample to a reference (control) sample set

[![lifecycle-experimental](https://img.shields.io/badge/lifecycle-experimental-orange)](https://adrientaudiere.github.io/MiscMetabar/articles/Rules.html#lifecycle)

Compute the community dissimilarity (default Bray-Curtis) between every
sample and a **reference** (e.g. a control), then visualize and test
which kinds of samples sit closest to that reference. The reference is
either a single sample given by name (`ref_sample`) or a set of samples
flagged in `sample_data` (`ref_fact` + `ref_value`); with several
references, the per-sample distance to the set is aggregated with
`ref_agg`.

Four complementary views are returned:

1.  a violin + jitter plot of the distance to the reference per level of
    `fact` (levels ordered from closest to farthest), with a
    Kruskal-Wallis test reported in the subtitle;

2.  a ranked lollipop of all samples (closest to the reference first);

3.  a **global** ordination (context): all samples, with the `n_nearest`
    closest ones highlighted and joined to the reference by spokes;

4.  a **local** ordination recomputed on the `n_nearest` closest samples
    only, revealing the structure *among* the close samples (a global
    ordination is dominated by distances between far samples and is
    often uninformative for the reference question).

## Usage

``` r
plot_samples_dist2ref_pq(
  physeq,
  fact = NULL,
  ref_fact = NULL,
  ref_sample = NULL,
  ref_value = TRUE,
  ref_agg = c("mean", "median", "min"),
  method = "bray",
  ordination_method = "PCoA",
  n_nearest = 20,
  show_ref = TRUE
)
```

## Arguments

- physeq:

  (required) A
  [phyloseq::phyloseq](https://rdrr.io/pkg/phyloseq/man/phyloseq-class.html)
  object. An OTU table and sample data are required; a phylogenetic tree
  is required only for tree-based distances (e.g. UniFrac).

- fact:

  (default NULL) Name of a categorical column of `sam_data` used to
  group and color samples. With at least 2 levels among non-reference
  samples, modalities are ranked by proximity to the reference
  (`rank_table`) and compared with a Kruskal-Wallis test.

- ref_fact:

  (default NULL) Name of the column in `physeq@sam_data` flagging the
  reference samples: a sample is a reference when its value in
  `ref_fact` equals `ref_value`. Supports one or several references.

- ref_sample:

  (default NULL) A single sample name (in
  [`phyloseq::sample_names()`](https://rdrr.io/pkg/phyloseq/man/sample_names-methods.html))
  used as the reference. Exactly one of `ref_sample` or `ref_fact` must
  be supplied.

- ref_value:

  (default `TRUE`) Value of `ref_fact` marking a reference sample. Keep
  the default for a logical `TRUE`/`FALSE` column, or pass the code used
  in a character/factor column (e.g. `"control"`).

- ref_agg:

  (default `"mean"`) How to summarise the distance of a sample to
  several reference samples: `"mean"`, `"median"` or `"min"`. Ignored
  with a single reference sample.

- method:

  (default `"bray"`) Dissimilarity index. Any
  [`phyloseq::distance()`](https://rdrr.io/pkg/phyloseq/man/distance.html)
  method (e.g. `"bray"`, `"jaccard"`, `"unifrac"`, `"wunifrac"`; see
  [`phyloseq::distanceMethodList()`](https://rdrr.io/pkg/phyloseq/man/distanceMethodList.html))
  plus `"aitchison"` and `"robust.aitchison"` computed with
  [`vegan::vegdist()`](https://vegandevs.github.io/vegan/reference/vegdist.html).

- ordination_method:

  (default `"PCoA"`) Ordination method passed to
  [`phyloseq::ordinate()`](https://rdrr.io/pkg/phyloseq/man/ordinate.html)
  for the two ordination plots (e.g. `"PCoA"`, `"NMDS"`). Axis labels
  report the percentage of variance explained for `"PCoA"` only.

- n_nearest:

  (default 20) Number of non-reference samples closest to the reference
  highlighted in the global ordination and kept in the local ordination
  (the reference samples are always added on top). Must be \>= 3.

- show_ref:

  (default TRUE) If TRUE, reference samples are drawn in the violin and
  lollipop plots (red points at distance 0). If FALSE, they are hidden
  and the distance axis is zoomed on the range of non-reference samples,
  making the differences among them easier to read.

## Value

A named list with:

- `dist_table`: a tibble with one row per sample (`sample_name`,
  `dist_to_ref` — 0 for reference samples) and all `sample_data`
  columns;

- `rank_table`: the levels of `fact` ranked from closest to farthest
  (`n`, `dist_mean`, `dist_sd`, `dist_median`), computed on
  non-reference samples; `NULL` when `fact` is `NULL`;

- `kw`: the Kruskal-Wallis test of `dist_to_ref ~ fact` on non-reference
  samples (`NULL` when `fact` is `NULL` or has fewer than two levels
  with data);

- `ref_samples`: character vector of the reference sample names;

- `plots`: a list of four ggplots (`violin`, `lollipop`, `pcoa_global`,
  `pcoa_local`);

- `dist`: the full `dist` object, for reuse.

## Details

No normalisation is done inside the function: rarefy or transform
`physeq` beforehand if needed (e.g.
[`phyloseq::rarefy_even_depth()`](https://rdrr.io/pkg/phyloseq/man/rarefy_even_depth.html)
or
[`phyloseq::transform_sample_counts()`](https://rdrr.io/pkg/phyloseq/man/transformcounts.html)).

Distances to a shared reference are not independent, which is why the
non-parametric Kruskal-Wallis test is used. With a single reference
sample the ranking is robust but there is no replication of the
reference to estimate its own variability: treat small gaps between
neighbouring modalities with care (a resampling wrapper may come to
`bootpq`).

The violin density is boundary-corrected to `[0, 1]` for distances known
to be bounded (`"bray"`, `"jaccard"`, `"unifrac"`, `"wunifrac"`,
`"sorensen"`) via `geom_violin(bounds = c(0, 1))` when every modality
has at least two distinct values; other metrics fall back to trimming
the violin to the observed data range.

## Author

Adrien Taudière

## Examples

``` r
res <- plot_samples_dist2ref_pq(data_fungi_mini, ref_sample = ref, fact = "Height")
#> Error: object 'ref' not found
res$rank_table # first row = modality closest to the reference
#> Error: object 'res' not found
res$plots$violin
#> Error: object 'res' not found
res$plots$lollipop
#> Error: object 'res' not found
res$plots$pcoa_global
#> Error: object 'res' not found
res$plots$pcoa_local
#> Error: object 'res' not found

# Reference set flagged in sample_data, distance to the nearest reference
phyloseq::sample_data(data_fungi_mini)$is_ref <-
  phyloseq::get_variable(data_fungi_mini, "Diameter") == "115,5"
res2 <- plot_samples_dist2ref_pq(
  data_fungi_mini,
  ref_fact = "is_ref",
  ref_agg = "min",
  fact = "Height"
)
res2$rank_table
#> # A tibble: 4 × 5
#>   Height     n dist_mean dist_sd dist_median
#>   <chr>  <int>     <dbl>   <dbl>       <dbl>
#> 1 NA        47     0.928  0.130        0.991
#> 2 Low       31     0.939  0.160        1.000
#> 3 High      27     0.945  0.168        0.998
#> 4 Middle    29     0.964  0.0729       0.999
if (FALSE) { # \dontrun{
# Compositional distance and a tighter local ordination
res3 <- plot_samples_dist2ref_pq(
  data_fungi_mini,
  ref_sample = ref,
  fact = "Height",
  method = "robust.aitchison",
  n_nearest = 10
)
} # }
```
