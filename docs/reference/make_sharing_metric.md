# Build a single metric definition for `community_sharing_plot()`

[![lifecycle-experimental](https://img.shields.io/badge/lifecycle-experimental-orange)](https://adrientaudiere.github.io/MiscMetabar/articles/Rules.html#lifecycle)

Helper constructor that packages one community-similarity metric for use
by
[`community_sharing_plot()`](https://adrientaudiere.github.io/ggplotpq/reference/community_sharing_plot.md)
and
[`community_sharing_barplot()`](https://adrientaudiere.github.io/ggplotpq/reference/community_sharing_barplot.md).
All metrics should be expressed as **similarities** (higher value = more
similar communities = thicker link).

## Usage

``` r
make_sharing_metric(
  label,
  color,
  fn,
  fmt = "%.2f",
  prep = NULL,
  bounds = NULL
)
```

## Arguments

- label:

  (character) Human-readable label used in the legend.

- color:

  (character) Colour of the curve connecting modalities.

- fn:

  (function) Function with signature `function(a, b, otu_sp, cache)`
  returning a single numeric value. `a`, `b` are modality names;
  `otu_sp` is the species-level OTU table aggregated by modality;
  `cache` is the object returned by `prep` (or `NULL`).

- fmt:

  (character, default `"%.2f"`) `sprintf` format string for legend stats
  (min / mean / max). Use `"%.0f"` for integer counts.

- prep:

  (function, default `NULL`) Optional function
  `function(physeq, fact, modalities)` called once to precompute helper
  data shared across all pairs (e.g. genus-level aggregation). Returns
  an object passed as `cache` to `fn`.

- bounds:

  (numeric vector of length 2, default `NULL`) Theoretical range
  `c(lower, upper)` of the metric. When non-`NULL`, linewidth is scaled
  to `linewidth_range` using these fixed bounds, so the same metric
  value always maps to the same linewidth regardless of the observed
  data. When `NULL`, linewidth is rescaled within the observed range of
  values. Use `bounds = c(0, 1)` for proportions or similarities (e.g.
  Jaccard, Bray-Curtis).

## Value

A named list with the metric definition.

## See also

[`default_sharing_metrics()`](https://adrientaudiere.github.io/ggplotpq/reference/default_sharing_metrics.md),
[`community_sharing_plot()`](https://adrientaudiere.github.io/ggplotpq/reference/community_sharing_plot.md)

## Author

Adrien Taudière

## Examples

``` r
if (FALSE) { # \dontrun{
# Custom metric: number of unique (non-shared) species
unique_sp <- make_sharing_metric(
  label = "Unique species count",
  color = "#A65628",
  fmt   = "%.0f",
  fn    = function(a, b, otu_sp, cache) {
    sum(xor(otu_sp[, a] > 0, otu_sp[, b] > 0))
  }
)

# Custom metric with prep step: Sorensen similarity at Family rank
sor_family <- make_sharing_metric(
  label = "Sorensen at Family rank",
  color = "#F781BF",
  prep  = function(physeq, fact, modalities) {
    d_fam <- phyloseq::tax_glom(physeq, "Family", NArm = FALSE)
    .agg_by_mod(d_fam, fact, modalities)
  },
  fn    = function(a, b, otu_sp, cache) {
    1 - as.numeric(vegan::vegdist(
      t(cache[, c(a, b)]),
      method = "bray", binary = TRUE
    ))
  }
)
} # }
```
