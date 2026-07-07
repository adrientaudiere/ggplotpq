# Plot a compact distribution overview of `tax_table` columns

[![lifecycle-experimental](https://img.shields.io/badge/lifecycle-experimental-orange)](https://adrientaudiere.github.io/MiscMetabar/articles/Rules.html#lifecycle)

Build one compact horizontal row per column of a phyloseq's `tax_table`
(via
[`tidypq::tax_table_to_df()`](https://adrientaudiere.github.io/tidypq/reference/tax_table_to_df.html)),
stacked into a single tight figure so many columns can be scanned at a
glance. Factor/character/logical columns become a single stacked bar
spanning the full row: each category is a colored zone sized by its
proportion of the total, `NA` is a dark grey zone, and categories that
individually represent less than `threshold` of the total are drawn in
white and left unlabeled (only zones at or above `threshold` get a small
text label). Numeric columns become a thin horizontal raincloud
(violin + boxplot + jittered points).

## Usage

``` r
plot_tax_table_pq(physeq, ..., threshold = 0.02, combine = TRUE)
```

## Arguments

- physeq:

  (required) A
  [phyloseq::phyloseq](https://rdrr.io/pkg/phyloseq/man/phyloseq-class.html)
  or
  [phyloseq::taxonomyTable](https://rdrr.io/pkg/phyloseq/man/taxonomyTable-class.html)
  object.

- ...:

  Columns of the `tax_table` to plot. Supports tidyselect helpers,
  including regex-based ones such as `dplyr::matches("^Guild")`.
  Defaults to every column when omitted.

- threshold:

  (numeric, default 0.02) For factor/character/logical columns,
  categories whose proportion of the total is below `threshold` are
  drawn in white and left unlabeled; `NA` is exempt (always dark grey,
  always labeled when non-zero).

- combine:

  (logical, default TRUE) If TRUE, stack the per-column rows into a
  single
  [patchwork::patchwork](https://patchwork.data-imaginist.com/reference/patchwork-package.html)
  figure. If FALSE, return a named list of
  [ggplot2::ggplot](https://ggplot2.tidyverse.org/reference/ggplot.html)
  objects (one per column).

## Value

A
[patchwork::patchwork](https://patchwork.data-imaginist.com/reference/patchwork-package.html)
object (default), or a named list of
[ggplot2::ggplot](https://ggplot2.tidyverse.org/reference/ggplot.html)
objects when `combine = FALSE`.

## Author

Adrien Taudière

## Examples

``` r
data(data_fungi_mini, package = "MiscMetabar")
plot_tax_table_pq(data_fungi_mini)


# Restrict to a subset of columns, mixing exact names and tidyselect
plot_tax_table_pq(data_fungi_mini, Phylum, Class, dplyr::matches("^Guild"))


data_fungi_mini <- tidypq::mutate_taxa_pq(
  data_fungi_mini,
  Mol_Abundance = phyloseq::taxa_sums(.)
)
plot_tax_table_pq(data_fungi_mini, Phylum, Mol_Abundance)
```
