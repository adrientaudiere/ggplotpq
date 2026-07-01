# Formattable view of track_wkflow output with nesting tree

[![lifecycle-experimental](https://img.shields.io/badge/lifecycle-experimental-orange)](https://adrientaudiere.github.io/MiscMetabar/articles/Rules.html#lifecycle)

Wraps the output of
[`MiscMetabar::track_wkflow()`](https://adrientaudiere.github.io/MiscMetabar/reference/track_wkflow.html)
into a
[`formattable::formattable()`](https://renkun-ken.github.io/formattable/reference/formattable.html)
HTML widget with proportional color bars on count columns
(`nb_sequences`, `nb_clusters`, `nb_samples`, `nb_occurrences`, and any
`n_samples_*` columns).

When a `parent` mapping is supplied, an ASCII tree is drawn in the first
column to visualise which phyloseq object is nested in which, rows are
reordered to reflect the hierarchy (depth-first), and mini diff columns
are appended:

- `Δ_sequences` / `Δ_clusters` / `Δ_samples` / `Δ_occurrences` — the
  true-value difference (not a percentage) with the parent, shown as a
  colored arrow: red `↓` for reductions (pink for small, deep red for
  large), green `↑` for augmentations (light green for small, deep green
  for large).

## Usage

``` r
track_wkflow_formattable(
  track_df,
  parent = NULL,
  bar_color = "lightblue",
  tile_low = "#c0dcf5",
  tile_high = "#4882b4",
  seq_tile_low = "#c5fddd",
  seq_tile_high = "seagreen",
  div_bar_color = "mediumpurple",
  na_bar_color = "darkorange",
  show_diff = TRUE,
  .interp_size = 0.7,
  .arrow_size = 1,
  big_mark = " ",
  round = 2,
  ...
)
```

## Arguments

- track_df:

  (data.frame, required) A data.frame returned by
  [`MiscMetabar::track_wkflow()`](https://adrientaudiere.github.io/MiscMetabar/reference/track_wkflow.html).

- parent:

  (named character vector or data.frame, default: NULL) A named
  character vector mapping each row name to the row name of its parent.
  Use `NA` for roots. Alternatively, a data.frame whose first column
  holds object names and second column holds parent names (`NA` for
  roots). When `NULL`, no tree or diff columns are produced.

- bar_color:

  (character, default: "lightblue") Color used for the proportional bars
  on `nb_sequences`, `nb_clusters`, and `nb_samples`.

- tile_low, tile_high:

  (character, default: "white"/"steelblue") Colors for the gradient tile
  applied to remaining numeric columns (e.g. `nb_rank`,
  `nb_sam_metadata`, or taxonomy-rank columns added by
  `track_wkflow(taxonomy_rank = ...)`).

- seq_tile_low, seq_tile_high:

  (character, default: "white"/"seagreen") Colors for the gradient tile
  applied to `mean_length_seq`, `max_length_seq`, `min_length_seq`
  columns.

- div_bar_color:

  (character, default: "mediumpurple") Fill color of the proportion bar
  applied to `genetic_diversity_*` columns (values in \[0, 1\]; bar
  length = value).

- na_bar_color:

  (character, default: "firebrick") Fill color of the proportion bar
  applied to `prop_na_*` columns (values in \[0, 1\]; bar length =
  value). High proportions of NA appear as a long red bar to flag
  missing taxonomic assignments.

- show_diff:

  (logical, default: TRUE) If `TRUE` and `parent` is supplied, insert
  mini columns after `nb_sequences`, `nb_clusters`, `nb_samples`, and
  `nb_occurrences` showing the true-value difference with the parent.

- .interp_size:

  (numeric, default: 0.7) Font-size multiplier (in `em` units) for the
  diff value text.

- .arrow_size:

  (numeric, default: 1.0) Font-size multiplier (in `em` units) for the
  directional arrow in the diff columns.

- big_mark:

  (character, default: a thin space, U+2009) Character used to group
  digits every 3 places in numeric columns and diff values (e.g. `19000`
  becomes `19 000` using a thin space). Set to `NULL` or `""` to disable
  grouping.

- round:

  (integer, default: 2) Number of decimal places to round numeric
  columns for display. Set to `NULL` or `NA` to disable rounding.

- ...:

  Additional arguments passed to
  [`formattable::formattable()`](https://renkun-ken.github.io/formattable/reference/formattable.html).

## Value

A `formattable` object (HTML widget).

## Author

Adrien Taudière

## Examples

``` r
# \donttest{
if (requireNamespace("pbapply", quietly = TRUE) &&
  requireNamespace("formattable", quietly = TRUE)) {
  data(data_fungi_mini, package = "MiscMetabar")
  d_filt <- prune_taxa(taxa_sums(data_fungi_mini) > 10000, data_fungi_mini) |>
    clean_pq()
  track <- track_wkflow(
    list("full" = data_fungi, "mini" = data_fungi_mini, "filt" = d_filt)
  )
  parent <- c(full = NA, mini = "full", filt = "mini")
  track_wkflow_formattable(track, parent)

  # With extra metrics from track_wkflow()
  track_extra <- track_wkflow(
    list("full" = data_fungi, "mini" = data_fungi_mini, "filt" = d_filt),
    compute_occurrences = TRUE,
    compute_taxo_info = TRUE,
    compute_seq_length = TRUE
  )
  track_wkflow_formattable(track_extra, parent)
}
#> Cleaning suppress 0 taxa and 6 samples.
#> Compute the number of sequences
#> Start object of class: phyloseq
#> Start object of class: phyloseq
#> Start object of class: phyloseq
#> Compute the number of clusters
#> Start object of class: phyloseq
#> Start object of class: phyloseq
#> Start object of class: phyloseq
#> Compute the number of samples
#> Start object of class: phyloseq
#> Start object of class: phyloseq
#> Start object of class: phyloseq
#> Compute the number of sequences
#> Start object of class: phyloseq
#> Start object of class: phyloseq
#> Start object of class: phyloseq
#> Compute the number of clusters
#> Start object of class: phyloseq
#> Start object of class: phyloseq
#> Start object of class: phyloseq
#> Compute the number of samples
#> Start object of class: phyloseq
#> Start object of class: phyloseq
#> Start object of class: phyloseq
# }
```
