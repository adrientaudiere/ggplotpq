# Shrink the text of a ggplot so that it fits a given figure size

[![lifecycle-experimental](https://img.shields.io/badge/lifecycle-experimental-orange)](https://adrientaudiere.github.io/MiscMetabar/articles/Rules.html#lifecycle)

Finds the largest font scale at which no text of a ggplot (or of a
patchwork assembly of ggplots) overlaps another text or leaves the
canvas, once the figure is drawn at `width` x `height`, and returns the
plot with its text resized by that scale.

Text sizes in ggplot2 are absolute (points), so whether labels overlap
depends on the final figure size. `resize_fonts()` draws the figure
off-screen at that size, measures the box of every label (rotated labels
included), and searches the scale by bisection between `min_scale` and
`max_scale`. Inside a knitr or Quarto chunk, `width` and `height`
default to the chunk's `fig-width` and `fig-height`.

## Usage

``` r
resize_fonts(
  p,
  width = NULL,
  height = NULL,
  units = c("in", "cm", "mm", "px"),
  dpi = 300,
  axis_text = TRUE,
  axis_title = TRUE,
  titles = TRUE,
  strip = TRUE,
  legend = TRUE,
  geom_text = FALSE,
  resize_all = FALSE,
  min_scale = 0.3,
  max_scale = 1,
  padding = 1,
  tolerance = 0.02,
  device = NULL,
  verbose = FALSE
)
```

## Arguments

- p:

  A
  [ggplot2::ggplot](https://ggplot2.tidyverse.org/reference/ggplot.html)
  object or a
  [patchwork](https://patchwork.data-imaginist.com/reference/patchwork-package.html)
  assembly.

- width, height:

  (numeric, default `NULL`) Figure size in `units`. When `NULL`, the
  size is taken from the current knitr/Quarto chunk (`fig.width` /
  `fig-width`, in inches), or else from the open graphics device, or
  else defaults to 7 x 5 inches (with a message).

- units:

  (character, default `"in"`) Units of `width` and `height`: one of
  `"in"`, `"cm"`, `"mm"` or `"px"`.

- dpi:

  (numeric, default `300`) Resolution used to convert `"px"`.

- axis_text:

  (logical, default `TRUE`) Check the axis tick labels for overlaps (and
  resize them, see `resize_all`).

- axis_title:

  (logical, default `TRUE`) Check the axis titles for overlaps (and
  resize them).

- titles:

  (logical, default `TRUE`) Check the plot title, subtitle, caption and
  tag, including a patchwork annotation, for overlaps (and resize them).

- strip:

  (logical, default `TRUE`) Check the facet strip text for overlaps (and
  resize it).

- legend:

  (logical, default `TRUE`) Check the legend titles and labels for
  overlaps (and resize them).

- geom_text:

  (logical, default `FALSE`) Check the text drawn by text and label
  layers (`geom_text()`, `geom_label()`, `ggrepel` geoms) for overlaps
  (and resize it). Layers mapping `size` to a variable are never
  resized.

- resize_all:

  (logical, default `FALSE`) When `FALSE`, only the categories set to
  `TRUE` above are resized, and the others keep their size. When `TRUE`,
  every text of the plot (all the categories above, `geom_text`
  included) is shrunk by the same scale, and the category arguments only
  choose which text is checked for overlaps.

- min_scale, max_scale:

  (numeric, default `0.3` and `1`) Range of the font scale searched. Set
  `max_scale` above 1 to also let text grow.

- padding:

  (numeric, default `1`) Minimum gap, in points, required between two
  labels.

- tolerance:

  (numeric, default `0.02`) Precision of the scale search.

- device:

  (character, default `NULL`) Device used to measure text: `"png"`,
  `"pdf"` or `"ragg"`. Font metrics differ slightly between devices.
  When `NULL`, the device of the current knitr chunk (`dev` option) is
  used, or else `"png"`.

- verbose:

  (logical, default `FALSE`) Print the chosen scale and the number of
  overlaps found at full size.

## Value

The plot `p` with its text resized, with the chosen scale stored in the
`"font_scale"` attribute. A category set to `FALSE` is never checked,
and is resized only when `resize_all = TRUE`.

## Limitations

- Only text drawn as plain grid text is measured: rich text from
  'ggtext' or 'marquee' is resized but not checked for overlaps.

- A single scale is applied to every selected category, which keeps the
  relative hierarchy of the text sizes; one crowded axis therefore
  shrinks all the selected text.

- When some text still overlaps at `min_scale` (e.g. two labels at the
  same position), a warning is raised and the plot is returned at
  `min_scale`. Consider
  [`ggplot2::guide_axis()`](https://ggplot2.tidyverse.org/reference/guide_axis.html)
  (`n.dodge`, `angle`) or wrapping labels instead.

- Each step draws the whole figure, so large plots take a few seconds.

## See also

[`MiscMetabar::reshape_ggplot()`](https://adrientaudiere.github.io/MiscMetabar/reference/reshape_ggplot.html)
to wrap long titles before resizing,
[`ggplot2::guide_axis()`](https://ggplot2.tidyverse.org/reference/guide_axis.html),
[`ggplot2::ggsave()`](https://ggplot2.tidyverse.org/reference/ggsave.html)

## Author

Adrien Taudière

## Examples

``` r
df <- data.frame(
  sample = paste0("Site_forest_", sprintf("%02d", 1:12)),
  reads = c(120, 145, 110, 130, 150, 90, 160, 135, 128, 142, 99, 117)
)
p <- ggplot2::ggplot(df, ggplot2::aes(x = sample, y = reads)) +
  ggplot2::geom_col()

p_fit <- resize_fonts(p, width = 150, height = 80, units = "mm")
attr(p_fit, "font_scale")
#> [1] 0.5296875

if (FALSE) { # \dontrun{
# In a Quarto chunk, the size comes from the chunk options:
#| fig-width: 6
#| fig-height: 4
resize_fonts(p)

# A patchwork, also counting the overlaps of geom_text() labels
library(patchwork)
resize_fonts(p / p, width = 6, height = 6, geom_text = TRUE)

# Shrink every text by the same amount, but only check the axis labels
resize_fonts(
  p,
  width = 4,
  height = 3,
  axis_title = FALSE,
  titles = FALSE,
  strip = FALSE,
  legend = FALSE,
  resize_all = TRUE
)
} # }
```
