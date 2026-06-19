# Plot per-sample read depth (number of sequences)

[![lifecycle-experimental](https://img.shields.io/badge/lifecycle-experimental-orange)](https://adrientaudiere.github.io/MiscMetabar/articles/Rules.html#lifecycle)

Draw a bar or density plot of per-sample sequencing depth
([`phyloseq::sample_sums()`](https://rdrr.io/pkg/phyloseq/man/sample_sums.html))
for a phyloseq object. Useful as a quick QA plot to identify low-depth
samples before downstream analyses. A reference line at `threshold`
(when supplied) is drawn to make the cutoff visible.

## Usage

``` r
plot_sample_depth_pq(
  physeq,
  geom = c("bar", "density"),
  color_fac = NULL,
  threshold = NULL,
  log10 = FALSE,
  sort = FALSE
)
```

## Arguments

- physeq:

  (required) A
  [phyloseq::phyloseq](https://rdrr.io/pkg/phyloseq/man/phyloseq-class.html)
  object.

- geom:

  (character, default "bar") One of `"bar"` (a single bar per sample) or
  `"density"` (a smoothed density estimate).

- color_fac:

  (character, default NULL) Optional name of a column in
  [`phyloseq::sample_data()`](https://rdrr.io/pkg/phyloseq/man/sample_data-methods.html)
  to color the bars by. Ignored when `geom = "density"`.

- threshold:

  (numeric, default NULL) Optional horizontal reference line drawn at
  this depth value. Common use: the rarefaction cutoff.

- log10:

  (logical, default FALSE) If TRUE, the y-axis (or the density's x-axis)
  is log10-transformed.

- sort:

  (logical, default FALSE) If TRUE, samples are sorted from highest to
  lowest depth. Useful for bar plots to spot outliers at a glance.

## Value

A [ggplot2::ggplot](https://ggplot2.tidyverse.org/reference/ggplot.html)
object.

## Author

Adrien Taudière

## Examples

``` r
# \donttest{
data(data_fungi_mini, package = "MiscMetabar")
plot_sample_depth_pq(data_fungi_mini)

plot_sample_depth_pq(data_fungi_mini, geom = "density", log10 = TRUE)

plot_sample_depth_pq(data_fungi_mini, color_fac = "Height", sort = TRUE)
#> Warning: Ignoring empty aesthetic: `fill`.

# }
```
