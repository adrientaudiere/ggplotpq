# Default metrics for `community_sharing_plot()`

[![lifecycle-experimental](https://img.shields.io/badge/lifecycle-experimental-orange)](https://adrientaudiere.github.io/MiscMetabar/articles/Rules.html#lifecycle)

Returns the four default metrics used by
[`community_sharing_plot()`](https://adrientaudiere.github.io/ggplotpq/reference/community_sharing_plot.md):
shared species count, Bray-Curtis similarity, Jaccard binary similarity,
and proportion of shared genera.

`bray_sim`, `jac_sim`, and `genus_prop` use `bounds = c(0, 1)` for
globally consistent linewidth scaling. `shared_sp` uses `bounds = NULL`
(count metric without a fixed upper bound; rescaled within the observed
range).

The Bray-Curtis and Jaccard metrics call vegan; it must be installed for
the default metric set.

## Usage

``` r
default_sharing_metrics()
```

## Value

A named list of metric definitions.

## See also

[`make_sharing_metric()`](https://adrientaudiere.github.io/ggplotpq/reference/make_sharing_metric.md),
[`community_sharing_plot()`](https://adrientaudiere.github.io/ggplotpq/reference/community_sharing_plot.md)

## Author

Adrien Taudière

## Examples

``` r
if (FALSE) { # \dontrun{
# Keep only a subset of the defaults
community_sharing_plot(
  data_fungi,
  fact    = "Height",
  metrics = default_sharing_metrics()[c("shared_sp", "bray_sim")]
)
} # }
```
