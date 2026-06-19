# IdEst color palettes

Palettes of color for IdEst including also some palettes from MoMAColors
<https://github.com/BlakeRMills/MoMAColors/blob/main/R/Functions.R>

The available palette are c("all_color_idest", "ligth_color_idest",
"dark_color_idest", "Picabia", "Picasso", "Levine2", "Rattner", "Sidhu",
"Hokusai2", "Hokusai3")

Migrated from
[`taxinfo::idest_pal`](https://adrientaudiere.github.io/taxinfo/reference/idest_pal.html).

## Usage

``` r
idest_pal
```

## Format

A named list where each element is a list of three elements:

- colors:

  A character vector of hex color codes.

- order:

  A numeric vector describing the perceptual ordering of the colors.

- colorblind:

  Logical. Whether the palette was designed to be colorblind-safe.

## Value

A named list of palettes (see Format).

## Author

Adrien Taudière
