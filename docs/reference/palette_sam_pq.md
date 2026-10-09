# Build a stable colour palette for a sample variable

[![lifecycle-experimental](https://img.shields.io/badge/lifecycle-experimental-orange)](https://adrientaudiere.github.io/MiscMetabar/articles/Rules.html#lifecycle)

The `sample_data` counterpart of
[`palette_tax_pq()`](https://adrientaudiere.github.io/ggplotpq/reference/palette_tax_pq.md):
assigns a colour to each level of a sample variable, so that a modality
keeps the same colour across every figure of a document even when a
subset does not contain it.

## Usage

``` r
palette_sam_pq(
  physeq,
  var,
  type = "auto",
  order_by = "levels",
  nested = NULL,
  palette = "auto",
  add = c(`NA` = "grey85"),
  reorder = FALSE,
  alternate_lightness = FALSE,
  lightness_amount = 0.15,
  l_range = c(0.35, 0.82),
  on_duplicate = "parent",
  add_to_phyloseq = FALSE,
  suffix = "_color",
  force = FALSE
)
```

## Arguments

- physeq:

  (phyloseq, required) A phyloseq object with `sample_data`.

- var:

  (character, required) A variable name from
  [`phyloseq::sample_variables()`](https://rdrr.io/pkg/phyloseq/man/sample_variables.html).

- type:

  (character, default `"auto"`) `"auto"`, `"qualitative"` or
  `"sequential"`. See Details.

- order_by:

  (character, default `"levels"`) `"levels"` honours factor levels and
  falls back to alphabetical order otherwise, `"frequency"` sorts by
  decreasing number of samples, `"alpha"` sorts alphabetically.

- nested:

  (character, default `NULL`) Name of a parent sample variable (for
  instance `"Region"` for `var = "Site"`). Hue then encodes the parent
  and lightness the level within it.

- palette:

  (character, default `"auto"`) `"auto"` picks the smallest
  colourblind-safe IdEst palette that fits. For `type = "sequential"`
  only the first colour is used, as the hue of the ramp; pass a single
  hex value to choose that hue explicitly.

- add:

  (character, default `c("NA" = "grey85")`) Named reserved entries
  appended after the levels.

- reorder:

  (logical, default `FALSE`) Reassign the colours to maximise contrast
  between consecutive levels. Meaningless for `type = "sequential"`,
  where it is refused, and for `nested`.

- alternate_lightness:

  (logical, default `FALSE`) Alternately lighten and darken levels.
  Refused for `type = "sequential"` and for `nested`.

- lightness_amount:

  (numeric, default `0.15`) Size of that alternation.

- l_range:

  (numeric, default `c(0.35, 0.82)`) Lightness bounds of the sequential
  ramp, or of each parent's gradient when `nested` is supplied.

- on_duplicate:

  (character, default `"parent"`) See
  [`palette_tax_pq()`](https://adrientaudiere.github.io/ggplotpq/reference/palette_tax_pq.md).
  Only used when `nested` is supplied.

- add_to_phyloseq:

  (logical, default `FALSE`) Write the colours into `sample_data` and
  return the phyloseq object instead of the palette.

- suffix:

  (character, default `"_color"`) Appended to `var` to build the column
  name.

- force:

  (logical, default `FALSE`) Overwrite an existing colour column.

## Value

A `pq_palette` (a named character vector) when
`add_to_phyloseq = FALSE`, or the modified phyloseq object when it is
`TRUE`.

## Two kinds of variable

Sample variables split into two families that deserve different colours,
and `type = "auto"` tells them apart:

- **qualitative** (default for unordered factors and character columns):
  distinct hues at constant lightness, drawn from the IdEst palettes.

- **sequential** (default for ordered factors and numeric columns): a
  single hue with increasing lightness, which reads as a gradient. Use
  it for sampling time, depth, pH – anything where the order carries
  meaning and a rainbow would destroy it.

## Level order

`order_by = "levels"` honours the levels of a factor, so a variable
declared as `factor(x, levels = c("T0", "SS", "Inoc"))` colours in that
order rather than alphabetically. This matters most for
`type = "sequential"`, where the order *is* the message. Non-factor
columns fall back to alphabetical order, which has the advantage of
being stable when a modality disappears.

## Where the palette lives

Exactly as in
[`palette_tax_pq()`](https://adrientaudiere.github.io/ggplotpq/reference/palette_tax_pq.md):
`add_to_phyloseq = TRUE` writes a `<var><suffix>` column into
`sample_data` and returns the phyloseq object, an existing column is
read back rather than recomputed, `suffix` lets a second palette
coexist, and `force` overwrites.

## See also

[`palette_tax_pq()`](https://adrientaudiere.github.io/ggplotpq/reference/palette_tax_pq.md)
for taxonomic ranks,
[`show_palette_pq()`](https://adrientaudiere.github.io/ggplotpq/reference/show_palette_pq.md)
to check a palette,
[`scale_fill_sam_pq()`](https://adrientaudiere.github.io/ggplotpq/reference/scale_fill_tax_pq.md)
to apply one.

## Author

Adrien Taudière

## Examples

``` r
# \donttest{
data(data_fungi_mini, package = "MiscMetabar")

# Qualitative: one hue per modality
palette_sam_pq(data_fungi_mini, "Height")
#> Using the colourblind-safe "Hokusai3" IdEst palette for 3 levels.
#> <pq_palette> Height: 3 levels
#>   High    #95c36e
#>   Low     #5a97c1
#>   Middle  #295384
#>   NA      grey85

# Sequential: a single hue, lightness carrying the order
palette_sam_pq(data_fungi_mini, "Time", type = "sequential")
#> <pq_palette> Time: 4 levels
#>   0   #103B6A
#>   5   #3D679A
#>   10  #6A96CC
#>   15  #9AC8FF
#>   NA  grey85
# }

if (FALSE) { # \dontrun{
# Store the anchoring inside the object
ps <- palette_sam_pq(data_fungi_mini, "Height", add_to_phyloseq = TRUE)
} # }
```
