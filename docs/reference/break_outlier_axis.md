# Add axis breaks to show outlier values

[![lifecycle-experimental](https://img.shields.io/badge/lifecycle-experimental-orange)](https://adrientaudiere.github.io/MiscMetabar/articles/Rules.html#lifecycle)

A thin, opinionated wrapper around
[`ggbreak::scale_y_break()`](https://rdrr.io/pkg/ggbreak/man/scale_break.html)
and
[`ggbreak::scale_x_break()`](https://rdrr.io/pkg/ggbreak/man/scale_break.html)
that auto-detects outlier gaps from plot data. A gap is defined by a
consecutive ratio: if the ratio of a sorted value to the next smaller
value exceeds `cutoff`, the region between them is cut from the axis and
replaced by a zigzag break symbol. Multiple gaps produce multiple
breaks.

The main data cluster (the segment with the most unique values) is shown
at full scale; outlier values appear in a compressed secondary panel
joined by the break symbol.

## Usage

``` r
break_outlier_axis(
  p = NULL,
  cutoff = 5,
  axis = c("y", "x", "both"),
  space = 0.2,
  space_proportional = FALSE,
  scales = "proportional",
  expand = TRUE,
  expand_cluster = 0.1
)
```

## Arguments

- p:

  A
  [ggplot2::ggplot](https://ggplot2.tidyverse.org/reference/ggplot.html)
  object to modify. When `NULL`, returns a spec object that can be added
  to a ggplot with `+`.

- cutoff:

  (numeric, default `5`) Ratio threshold for gap detection. Consecutive
  sorted positive values `v[i]` and `v[i+1]` define a gap when
  `v[i+1] / v[i] > cutoff`. Increase to detect only extreme outliers.

- axis:

  (character, default `"y"`) Which axis to break: `"y"`, `"x"`, or
  `"both"`.

- space:

  (numeric, default `0.2`) Relative width of the break gap symbol as a
  fraction of the figure dimension. Ignored when
  `space_proportional = TRUE`.

- space_proportional:

  (logical, default `FALSE`) When `TRUE`, the visual width of each break
  gap symbol is made proportional to the data gap size relative to the
  total data range, so the folded axis represents the actual scale of
  the gap. The result is clamped to `[0.05, 0.75]`.

- scales:

  (character or numeric, default `"proportional"`) Panel-size policy.
  `"proportional"` (default) automatically sizes each outlier panel
  proportionally to the data range it contains relative to the lower
  panel's display range, so the axis is visually to scale. `"free"` lets
  ggbreak choose equal-height panels independently. A positive numeric
  value sets the height (width for x) ratio of the outlier panel to the
  main panel directly.

- expand:

  (logical, default `TRUE`) Whether to let ggplot2 add its default 5 %
  expansion to each panel's axis range. Setting to `TRUE` (default)
  prevents points and bars right at the panel boundary from being
  clipped; set to `FALSE` for exact data-range panels.

- expand_cluster:

  (numeric, default `0.10`) Extra space added above (y-axis) or to the
  right of (x-axis) the cluster maximum before the break starts, as a
  fraction of the cluster range. Prevents data points right at the
  cluster boundary from being clipped.

## Value

A modified ggplot object with axis breaks, or a spec object (when
`p = NULL`). Note:
[ggbreak](https://rdrr.io/pkg/ggbreak/man/ggbreak-package.html) wraps
the plot in a custom grid layout; adding further ggplot2 layers after
`break_outlier_axis()` may behave unexpectedly.

## Limitations

- Outlier detection operates on all data values across all layers
  collectively (positive values only).

- Works best with linear scales; log-transformed scales may produce
  unexpected break positions.

- Requires the **ggbreak** package (listed under `Suggests`).

- Line geoms that cross a break are visually cut at the break boundary
  but no additional break symbol is drawn on the line itself.

## See also

[`zoom_outlier_axis()`](https://adrientaudiere.github.io/ggplotpq/reference/zoom_outlier_axis.md),
[`ggbreak::scale_y_break()`](https://rdrr.io/pkg/ggbreak/man/scale_break.html),
[`ggbreak::scale_x_break()`](https://rdrr.io/pkg/ggbreak/man/scale_break.html)

## Author

Adrien Taudière

## Examples

``` r
# \donttest{
df <- data.frame(
  sample = c("A", "B", "C", "D", "E"),
  reads  = c(120, 145, 110, 130, 5000)
)
p <- ggplot2::ggplot(df, ggplot2::aes(x = sample, y = reads)) +
  ggplot2::geom_col()

# Via direct call
break_outlier_axis(p, cutoff = 5, axis = "y")
#> Error in .ggbreak$scale_break("y", breaks, scales, ticklabels, expand,     space, symbol): invalid called.

# Via + operator
p + break_outlier_axis(cutoff = 5)
#> Error in .ggbreak$scale_break("y", breaks, scales, ticklabels, expand,     space, symbol): invalid called.

# Proportional break gap (gap symbol sized to the actual data gap)
p + break_outlier_axis(cutoff = 5, space_proportional = TRUE)
#> Error in .ggbreak$scale_break("y", breaks, scales, ticklabels, expand,     space, symbol): invalid called.
# }

if (FALSE) { # \dontrun{
# With phyloseq — first build the count bar chart, then add the break
data(data_fungi_sp_known, package = "MiscMetabar")
p_pq <- plot_tax_count_pq(
  data_fungi_sp_known, "Time",
  merge_sample_by = "Time", taxa_fill = "Class"
)
p_pq + break_outlier_axis(cutoff = 2)
} # }
```
