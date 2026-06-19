# ggplot2 discrete fill scale using the IdEst palette family

ggplot2 discrete fill scale using the IdEst palette family

## Usage

``` r
scale_fill_pq_discrete(
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
discrete fill scale.

## See also

[`scale_color_pq_discrete()`](https://adrientaudiere.github.io/ggplotpq/reference/scale_color_pq_discrete.md)
for the matching colour scale.

## Author

Adrien Taudière

## Examples

``` r
# \donttest{
library(ggplot2)
ggplot(mtcars, aes(factor(cyl), fill = factor(cyl))) +
  geom_bar() +
  scale_fill_pq_discrete("Levine2")

# }
```
