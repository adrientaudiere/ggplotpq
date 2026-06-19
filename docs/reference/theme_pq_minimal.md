# A pared-down minimalist ggplot2 theme for ggplotpq

[![lifecycle-experimental](https://img.shields.io/badge/lifecycle-experimental-orange)](https://adrientaudiere.github.io/MiscMetabar/articles/Rules.html#lifecycle)

A minimalist ggplot2 theme that mirrors the look of
[`theme_idest()`](https://adrientaudiere.github.io/ggplotpq/reference/theme_idest.md)
but with no font customisation, no light/dark toggles, and no
grid/axis/ticks switches. It is intended as a sensible default theme
that does not require the user to have any specific fonts installed.

For more control over fonts, grid lines, axis lines and ticks, use
[`theme_idest()`](https://adrientaudiere.github.io/ggplotpq/reference/theme_idest.md)
instead.

## Usage

``` r
theme_pq_minimal(
  base_size = 11,
  base_family = "",
  plot_title_size = 14,
  axis_title_size = 11
)
```

## Arguments

- base_size:

  (numeric, default 11) Base font size.

- base_family:

  (character, default "") Base font family. Empty string means use the
  system default sans-serif family.

- plot_title_size:

  (numeric, default 14) Font size for the plot title.

- axis_title_size:

  (numeric, default 11) Font size for the axis titles.

## Value

A [ggplot2::theme](https://ggplot2.tidyverse.org/reference/theme.html)
object.

## See also

[`theme_idest()`](https://adrientaudiere.github.io/ggplotpq/reference/theme_idest.md)
for a fuller, font-aware theme.

## Author

Adrien Taudière

## Examples

``` r
# \donttest{
library(ggplot2)
ggplot(mtcars, aes(wt, mpg)) +
  geom_point() +
  theme_pq_minimal()

# }
```
