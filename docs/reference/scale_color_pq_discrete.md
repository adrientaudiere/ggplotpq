# ggplot2 discrete colour scale using the IdEst palette family

[![lifecycle-experimental](https://img.shields.io/badge/lifecycle-experimental-orange)](https://adrientaudiere.github.io/MiscMetabar/articles/Rules.html#lifecycle)

A thin wrapper around
[`scale_color_idest_d()`](https://adrientaudiere.github.io/ggplotpq/reference/scale_color_idest_d.md)
that uses one of the curated colorblind-safe IdEst palettes (`Hokusai3`,
`Picabia`, `Picasso`, `Levine2`, `Rattner`, `Sidhu`) by name. Behaves
like
[`ggplot2::scale_color_brewer()`](https://ggplot2.tidyverse.org/reference/scale_brewer.html)
but with the IdEst palette set.

## Usage

``` r
scale_color_pq_discrete(
  palette = "Hokusai3",
  direction = 1,
  override_order = FALSE,
  ...
)
```

## Arguments

- palette:

  (character, default "Hokusai3") The IdEst palette to use. Must be one
  of the palettes in
  [idest_pal](https://adrientaudiere.github.io/ggplotpq/reference/idest_pal.md).

- direction:

  (integer, default 1) Set to -1 to reverse the palette.

- override_order:

  (logical, default FALSE) Override the curated perceptual ordering of
  the palette.

- ...:

  Additional arguments passed to
  [`ggplot2::discrete_scale()`](https://ggplot2.tidyverse.org/reference/discrete_scale.html).

## Value

A [ggplot2::ggplot](https://ggplot2.tidyverse.org/reference/ggplot.html)
discrete colour scale.

## See also

[`scale_fill_pq_discrete()`](https://adrientaudiere.github.io/ggplotpq/reference/scale_fill_pq_discrete.md)
for the matching fill scale,
[`idest_colors()`](https://adrientaudiere.github.io/ggplotpq/reference/idest_colors.md)
for the underlying palette lookup.

## Author

Adrien Taudière

## Examples

``` r
# \donttest{
library(ggplot2)
ggplot(mtcars, aes(wt, mpg, color = factor(cyl))) +
  geom_point(size = 2) +
  scale_color_pq_discrete("Picabia")

# }
```
