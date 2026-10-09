# Build a stable colour palette for a taxonomic rank

[![lifecycle-experimental](https://img.shields.io/badge/lifecycle-experimental-orange)](https://adrientaudiere.github.io/MiscMetabar/articles/Rules.html#lifecycle)

Assigns a colour to every level of a taxonomic rank – or, when `n` is
given, to the `n` heaviest of them plus a reserved colour for the rest –
and returns the result as a named vector that can be reused across every
figure of a document.

Because ggplot2 matches manual scales *by name*, a plot showing only
some of the levels simply consumes the matching entries: the colours
never shift from one figure to the next. Anchor the palette once on the
complete object, then reuse it on any subset.

## Usage

``` r
palette_tax_pq(
  physeq,
  rank,
  n = NULL,
  filter_by = "abundance",
  order_by = "alpha",
  nested = NULL,
  palette = "auto",
  add = c(other = "grey85"),
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

  (phyloseq, required) A phyloseq object with a `tax_table`.

- rank:

  (character, required) A rank name from
  [`phyloseq::rank_names()`](https://rdrr.io/pkg/phyloseq/man/rank_names.html).

- n:

  (integer, default `NULL`) How many levels to colour. `NULL`, the
  default, colours **every** level of the rank. Set it to keep only the
  `n` heaviest, the rest sharing the reserved `other` colour – useful
  when a rank holds more levels than a palette can distinguish.

- filter_by:

  (character, default `"abundance"`) **Only used when `n` is not
  `NULL`.** With the default `n = NULL` every level is coloured, so
  there is nothing to filter and this argument is ignored entirely. When
  `n` is set, it decides which `n` levels are kept: the heaviest by
  `"abundance"` (total reads), by `"n_taxa"` (number of taxa carrying
  the level), by `"mean"` (reads per sample) or by `"prevalence"`
  (number of samples where present). Ties are broken alphabetically, so
  the selection does not depend on the row order of `physeq`.

- order_by:

  (character, default `"alpha"`) The order the levels are listed in,
  which decides which colour each one gets and how the legend reads:
  `"alpha"`, `"abundance"` or `"n_taxa"`. Unlike `filter_by`, this
  always applies. Alphabetical by default because it does not move when
  abundances change, so a taxon keeps its colour across datasets.

- nested:

  (character, default `NULL`) Name of a parent rank (for instance
  `"Phylum"` for `rank = "Genus"`). When supplied, the palette is nested
  as described in Details.

- palette:

  (character, default `"auto"`) `"auto"` picks the smallest
  colourblind-safe IdEst palette that fits, and generates colours in
  OKLCH beyond 11 levels. Can also be `"oklch"`, a name from
  [idest_pal](https://adrientaudiere.github.io/ggplotpq/reference/idest_pal.md),
  or a vector of colours. With `nested`, this colours the *parents*.

- add:

  (character, default `c(other = "grey85")`) Named reserved entries
  appended after the levels.

- reorder:

  (logical, default `FALSE`) Reassign the same colours so that
  consecutive levels contrast as much as possible. Applied once, at
  construction; never at plot time, where it would break stability
  between figures. Refused together with `nested`.

- alternate_lightness:

  (logical, default `FALSE`) Lighten and darken levels alternately,
  adding a luminance cue on top of hue. Refused together with `nested`.

- lightness_amount:

  (numeric, default `0.15`) Size of that alternation, as an OKLCH
  lightness step.

- l_range:

  (numeric, default `c(0.35, 0.82)`) Lightness bounds of each parent's
  gradient. Only used when `nested` is supplied. The first leaf of each
  parent gets the darkest shade.

- on_duplicate:

  (character, default `"parent"`) What to do when a leaf name occurs
  under several parents: `"parent"` appends the parent name in
  parentheses to the ambiguous entries, `"first"` keeps the first
  occurrence, `"error"` aborts. Only used when `nested` is supplied.

- add_to_phyloseq:

  (logical, default `FALSE`) Write the colours into the `tax_table` and
  return the phyloseq object instead of the palette.

- suffix:

  (character, default `"_color"`) Appended to `rank` to build the column
  name. Use `"_color_<something>"` to hold a second palette for the same
  rank alongside the first.

- force:

  (logical, default `FALSE`) Overwrite an existing colour column. Prefer
  a different `suffix`, which keeps both palettes.

## Value

A `pq_palette` (a named character vector) when
`add_to_phyloseq = FALSE`, or the modified phyloseq object when it is
`TRUE`.

## Filtering is opt-in

By default (`n = NULL`) every level of the rank gets its own colour and
**`filter_by` is never consulted**. Filtering only starts when you set
`n`, and `filter_by` then decides which levels survive. The two
arguments are therefore not independent: setting `filter_by` without
setting `n` has no effect at all.

`order_by` is different – it always applies, because the levels have to
be listed in some order whether or not any were dropped.

A rank with many levels will hit the palette guards: a warning past 25
colours, an error past 40. That is the signal to set `n`.

## Where the palette lives

With `add_to_phyloseq = TRUE` the colours are written into a
`<rank><suffix>` column of the `tax_table` and the **phyloseq object**
is returned instead of the palette. Every taxon gets a colour, including
those outside the top `n`, which take the reserved `other` entry. The
column then travels with the rows through `subset_taxa()`,
`prune_taxa()` and [`saveRDS()`](https://rdrr.io/r/base/readRDS.html),
so the anchoring survives without any variable being carried around the
document.

On a later call, an existing column is **read back** rather than
recomputed, which is what makes the colours stable. Writing over it
requires either `force = TRUE`, or a different `suffix` so both palettes
coexist.

## Nested palettes

With `nested`, hue encodes the parent rank and lightness the rank of the
leaf within its parent, so a bar chart shows the phylum-level structure
at a glance. Keys are the leaf names alone; a leaf name occurring under
several parents is disambiguated according to `on_duplicate`.

A nested palette is **more** dependent on anchoring than a flat one, not
less. Recomputing it on a subset shifts the leaf shades, because each
gradient is spread over the siblings actually present, and shifts the
parent hues too whenever a whole parent drops out and the hue circle is
divided differently. Anchor once on the complete object – keep the
returned palette, or store it with `add_to_phyloseq = TRUE` – and reuse
it. That is what the anchoring is for; it is not a fallback.

## See also

[`palette_sam_pq()`](https://adrientaudiere.github.io/ggplotpq/reference/palette_sam_pq.md)
for `sample_data` variables,
[`show_palette_pq()`](https://adrientaudiere.github.io/ggplotpq/reference/show_palette_pq.md)
to check a palette,
[`scale_fill_tax_pq()`](https://adrientaudiere.github.io/ggplotpq/reference/scale_fill_tax_pq.md)
to apply one.

## Author

Adrien Taudière

## Examples

``` r
# \donttest{
data(data_fungi_mini, package = "MiscMetabar")

# Every Order gets a colour, listed alphabetically
pal <- palette_tax_pq(data_fungi_mini, "Order")
#> Using the colourblind-safe "Picabia" IdEst palette for 9 levels.
pal
#> <pq_palette> Order: 9 levels
#>   Agaricales       #744940
#>   Atractiellales   #9f7064
#>   Auriculariales   #c99582
#>   Cantharellales   #e6bcac
#>   Corticiales      #e2d8d6
#>   Hymenochaetales  #a5a6ae
#>   Polyporales      #858794
#>   Russulales       #666879
#>   Tremellales      #515260
#>   other            grey85

# Keep only the 4 most abundant; the rest turn grey
palette_tax_pq(data_fungi_mini, "Order", n = 4)
#> Using the colourblind-safe "Hokusai3" IdEst palette for 4 levels.
#> <pq_palette> Order: 4 levels
#>   Agaricales       #d8d97a
#>   Hymenochaetales  #95c36e
#>   Polyporales      #5a97c1
#>   Russulales       #295384
#>   other            grey85

# Keep the 4 carrying the most taxa instead
palette_tax_pq(data_fungi_mini, "Order", n = 4, filter_by = "n_taxa")
#> Using the colourblind-safe "Hokusai3" IdEst palette for 4 levels.
#> <pq_palette> Order: 4 levels
#>   Agaricales      #d8d97a
#>   Auriculariales  #95c36e
#>   Polyporales     #5a97c1
#>   Russulales      #295384
#>   other           grey85

# The same palette on a subset: the surviving levels keep their colours
sub <- phyloseq::prune_taxa(
  phyloseq::taxa_sums(data_fungi_mini) > 100,
  data_fungi_mini
)
palette_tax_pq(sub, "Order")
#> Using the colourblind-safe "Picabia" IdEst palette for 9 levels.
#> <pq_palette> Order: 9 levels
#>   Agaricales       #744940
#>   Atractiellales   #9f7064
#>   Auriculariales   #c99582
#>   Cantharellales   #e6bcac
#>   Corticiales      #e2d8d6
#>   Hymenochaetales  #a5a6ae
#>   Polyporales      #858794
#>   Russulales       #666879
#>   Tremellales      #515260
#>   other            grey85
# }

if (FALSE) { # \dontrun{
# Nested: hue by Phylum, lightness by Order
palette_tax_pq(data_fungi_mini, "Order", nested = "Phylum")

# Store the anchoring inside the object
ps <- palette_tax_pq(data_fungi_mini, "Order", add_to_phyloseq = TRUE)

# A second palette on the same rank, side by side with the first
ps <- palette_tax_pq(
  ps, "Order",
  palette = "oklch",
  add_to_phyloseq = TRUE, suffix = "_color_alt"
)
} # }
```
