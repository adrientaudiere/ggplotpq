# Circle-packed bubble plot of a phyloseq object using ggplot2

[![lifecycle-experimental](https://img.shields.io/badge/lifecycle-experimental-orange)](https://adrientaudiere.github.io/MiscMetabar/articles/Rules.html#lifecycle)

Creates a static circle-packed bubble plot of taxa abundances from a
phyloseq object using ggplot2. Circles can be packed in a circular
layout (tight, default) or a square layout. Optionally facets the plot
by a sample data variable, producing one bubble chart per level.

When `diff_contour = TRUE` together with `facet_by`, all pairwise
comparisons between facet levels are shown side by side using patchwork.
For each pair (A vs B), taxa unique to A are highlighted with A's colour
and taxa unique to B with B's colour. Shared taxa receive a transparent
contour, making it easy to spot which taxa are exclusive to each group.

Migrated from
[`comparpq::gg_bubbles_pq()`](https://adrientaudiere.github.io/comparpq/reference/gg_bubbles_pq.html)
(single-phyloseq variant — list_phyloseq support was removed; use
[`comparpq::gg_bubbles_pq()`](https://adrientaudiere.github.io/comparpq/reference/gg_bubbles_pq.html)
for multi-object comparisons).

## Usage

``` r
gg_bubbles_pq(
  physeq,
  rank_label = "Taxa",
  rank_color = "Family",
  rank_contour = NULL,
  layout = c("circle", "square"),
  facet_by = NULL,
  log1ptransform = FALSE,
  min_nb_seq = 0,
  label_size = 2,
  label_color = "grey10",
  show_labels = TRUE,
  border_color = "white",
  border_width = 0.5,
  alpha = 0.8,
  npoints = 50,
  ncol_facet = NULL,
  return_dataframe = FALSE,
  diff_contour = FALSE,
  diff_contour_colors = c("#E41A1C", "#377EB8", "#4DAF4A", "#984EA3"),
  diff_border_width = 1.5,
  show_title = TRUE
)
```

## Arguments

- physeq:

  (required) A
  [phyloseq::phyloseq](https://rdrr.io/pkg/phyloseq/man/phyloseq-class.html)
  object.

- rank_label:

  (character, default `"Taxa"`) Column in `@tax_table` to label circles.
  When `"Taxa"`, taxa names are used.

- rank_color:

  (character, default `"Family"`) Column in `@tax_table` to colour
  circles.

- rank_contour:

  (character, default `NULL`) Column in `@tax_table` to colour circle
  borders. When `NULL`, `border_color` is used uniformly. Ignored when
  `diff_contour = TRUE`.

- layout:

  (character, default `"circle"`) Packing layout: `"circle"` for tight
  circular packing, `"square"` for a square boundary.

- facet_by:

  (character, default `NULL`) Column name from `@sam_data` to facet the
  plot. One bubble chart is produced per level.

- log1ptransform:

  (logical, default `FALSE`) If `TRUE`, sequence counts are
  log1p-transformed before computing circle sizes.

- min_nb_seq:

  (integer, default `0`) Minimum sequence count; taxa below this
  threshold are dropped.

- label_size:

  (numeric, default `2`) Font size for labels inside circles.

- label_color:

  (character, default `"grey10"`) Colour for label text.

- show_labels:

  (logical, default `TRUE`) If `TRUE`, labels are shown inside circles
  that are large enough to fit text.

- border_color:

  (character, default `"white"`) Colour for circle borders (used when
  `rank_contour = NULL`).

- border_width:

  (numeric, default `0.5`) Width of circle borders.

- alpha:

  (numeric, default `0.8`) Transparency of circle fill.

- npoints:

  (integer, default `50`) Vertices per circle polygon. Higher values
  produce smoother circles.

- ncol_facet:

  (integer, default `NULL`) Number of columns for
  [`ggplot2::facet_wrap()`](https://ggplot2.tidyverse.org/reference/facet_wrap.html).
  Ignored when `diff_contour = TRUE`.

- return_dataframe:

  (logical, default `FALSE`) If `TRUE`, return the data frame used for
  plotting instead of a ggplot object. Ignored when
  `diff_contour = TRUE`.

- diff_contour:

  (logical, default `FALSE`) If `TRUE` and `facet_by` is set, produces
  pairwise comparison panels for all facet-level pairs using patchwork.
  Taxa unique to each side are highlighted with a distinct contour
  colour; shared taxa receive a transparent contour.

- diff_contour_colors:

  (character vector, default
  `c("#E41A1C", "#377EB8", "#4DAF4A", "#984EA3")`) Border colours for
  taxa unique to each facet level. Recycled if shorter than the number
  of levels.

- diff_border_width:

  (numeric, default `1.5`) Border width in `diff_contour` mode.

- show_title:

  (logical, default `TRUE`) If `TRUE`, adds an informative title
  describing the fill, contour, size, and label mappings.

## Value

A [ggplot2::ggplot](https://ggplot2.tidyverse.org/reference/ggplot.html)
object, a patchwork object (when `diff_contour = TRUE`), or a data.frame
(when `return_dataframe = TRUE`).

## See also

[`comparpq::gg_bubbles_pq()`](https://adrientaudiere.github.io/comparpq/reference/gg_bubbles_pq.html)
for the multi-phyloseq variant.

## Author

Adrien Taudière

## Examples

``` r
# \donttest{
data(data_fungi_mini, package = "MiscMetabar")
gg_bubbles_pq(physeq = data_fungi_mini, rank_color = "Class")


gg_bubbles_pq(
  physeq = data_fungi_mini, rank_color = "Class",
  rank_contour = "Order"
)


gg_bubbles_pq(
  physeq = data_fungi_mini, rank_color = "Class",
  layout = "square"
)

# }

if (FALSE) { # \dontrun{
# Faceted by sample variable
data(data_fungi, package = "MiscMetabar")
gg_bubbles_pq(
  physeq = data_fungi, rank_color = "Order",
  facet_by = "Height", min_nb_seq = 100
)

# Pairwise diff_contour
gg_bubbles_pq(
  physeq = data_fungi, rank_color = "Order",
  facet_by = "Height", min_nb_seq = 100,
  diff_contour = TRUE, show_labels = FALSE
)
} # }
```
