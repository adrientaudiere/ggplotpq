# IdEst continuous color scales for ggplot2

IdEst continuous color scales for ggplot2

## Usage

``` r
scale_color_idest_c(palette_name = "all_color_idest", direction = 1, ...)
```

## Arguments

- palette_name:

  The name of the palette to use. The available palette are
  c("all_color_idest", "ligth_color_idest", "dark_color_idest",
  "Picabia", "Picasso", "Levine2", "Rattner", "Sidhu", "Hokusai2",
  "Hokusai3"). See
  [idest_pal](https://adrientaudiere.github.io/ggplotpq/reference/idest_pal.md)
  for more details.

- direction:

  Direction of the palette. 1 for standard, -1 for reversed.

- ...:

  Additional arguments passed to
  [`ggplot2::scale_color_gradientn()`](https://ggplot2.tidyverse.org/reference/scale_gradient.html).

## Value

A ggplot2 scale object.

## Author

Adrien Taudière
