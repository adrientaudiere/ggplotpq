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
grey with a stripe motif (via `ggpattern`, when installed) and left
unlabeled (only zones at or above `threshold` get a small text label). A
column is treated as boolean-like as soon as one of its values reads
`"true"` or `"false"` (case-insensitive, so logical columns and mixes
like `c(TRUE, FALSE, "uncertain")` both qualify): the color scheme is
then fixed across every such column (olive green for true, brick red for
false, a blue gradient for any other value), instead of the arbitrary
categorical palette used for other factor columns. The last such bar row
carries a shared `"Proportion"` x-axis (ticks at 0, 0.25, 0.5, 0.75, 1)
for the whole group; other bar rows have theirs hidden to avoid
repeating it. Numeric columns become a thin horizontal raincloud
(violin + boxplot + jittered points) with the number of non-`NA` values
annotated in the top-right corner (and the proportion of `NA` values
too, when there is at least one `NA`).

## Usage

``` r
plot_tax_table_pq(
  physeq,
  ranks = phyloseq::rank_names(physeq),
  na_equivalent = c("-", "NA_NA"),
  threshold = 0.02,
  discard_full_NA_column = TRUE,
  combine = TRUE,
  max_combined_ranks = 25
)
```

## Arguments

- physeq:

  (required) A
  [phyloseq::phyloseq](https://rdrr.io/pkg/phyloseq/man/phyloseq-class.html)
  or
  [phyloseq::taxonomyTable](https://rdrr.io/pkg/phyloseq/man/taxonomyTable-class.html)
  object.

- ranks:

  (character, default `phyloseq::rank_names(physeq)`) Names of
  `tax_table` columns to plot.

- na_equivalent:

  (character vector or NULL, default `"-"`) Values found in
  character/factor columns that are treated as `NA` before summarizing
  (e.g. placeholder codes such as `"-"`). Set to `NULL` to disable.

- threshold:

  (numeric, default 0.02) For factor/character/logical columns,
  categories whose proportion of the total is below `threshold` are
  drawn in grey (with a stripe motif) and left unlabeled; `NA` is exempt
  (always dark grey, always labeled when non-zero), and so are
  `TRUE`/`FALSE` values in boolean-like columns.

- discard_full_NA_column:

  (logical, default TRUE) If TRUE, columns that are entirely `NA` (after
  `na_equivalent` conversion) are dropped with a message. If FALSE, they
  are kept and drawn as a single dark grey `"NA"` row (a numeric column
  that is entirely `NA` is drawn this way too, since a raincloud needs
  at least one value).

- combine:

  (logical, default TRUE) If TRUE, stack the per-column rows into a
  single
  [patchwork::patchwork](https://patchwork.data-imaginist.com/reference/patchwork-package.html)
  figure (or several, see `max_combined_ranks`). If FALSE, return a
  named list of
  [ggplot2::ggplot](https://ggplot2.tidyverse.org/reference/ggplot.html)
  objects (one per column).

- max_combined_ranks:

  (integer, default 25) Maximum number of rows per combined figure. If
  `combine = TRUE` and more than `max_combined_ranks` columns are
  selected, `ranks` is split into consecutive chunks of at most
  `max_combined_ranks` columns (with a message), each combined into its
  own
  [patchwork::patchwork](https://patchwork.data-imaginist.com/reference/patchwork-package.html)
  figure, so a named list of figures is returned instead of a single,
  too-dense one.

## Value

A
[patchwork::patchwork](https://patchwork.data-imaginist.com/reference/patchwork-package.html)
object when `combine = TRUE` and `ranks` fits within
`max_combined_ranks`; otherwise a named list, of
[ggplot2::ggplot](https://ggplot2.tidyverse.org/reference/ggplot.html)
objects (one per column) when `combine = FALSE`, or of
[patchwork::patchwork](https://patchwork.data-imaginist.com/reference/patchwork-package.html)
objects (one per chunk of at most `max_combined_ranks` columns) when
`combine = TRUE` with more than `max_combined_ranks` columns selected.

## Author

Adrien Taudière

## Examples

``` r
data(data_fungi_mini, package = "MiscMetabar")
plot_tax_table_pq(data_fungi_mini)


# Restrict to a subset of columns
plot_tax_table_pq(data_fungi_mini, ranks = c("Class", "Guild"))


data_fungi_mini <- tidypq::mutate_taxa_pq(
  data_fungi_mini,
  Mol_Abundance = phyloseq::taxa_sums(.)
)
plot_tax_table_pq(data_fungi_mini, ranks = c("Class", "Mol_Abundance"))
```
