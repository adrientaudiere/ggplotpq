# Derive a colour palette from a geographic location

[![lifecycle-experimental](https://img.shields.io/badge/lifecycle-experimental-orange)](https://adrientaudiere.github.io/MiscMetabar/articles/Rules.html#lifecycle)

Retrieves a satellite or map tile centred on a geographic point (via
maptiles) and clusters the pixel colours with k-means to produce a
palette of dominant tones. Unlike the upstream earthtones package, this
implementation uses the bounding-box derived from the actual map
projection (EPSG:3857), which avoids the latitude-invariance bug present
in earthtones \\\leq\\ 0.2.0.

## Usage

``` r
palette_earthtones(
  latitude,
  longitude,
  n_colors = 6,
  zoom = 10,
  bbox_size = NULL,
  provider = "Esri.WorldImagery",
  method = c("kmeans", "mean", "quantile"),
  sample_n = 10000,
  seed = 42
)
```

## Arguments

- latitude:

  (numeric, required) Latitude of the target location (decimal degrees,
  WGS84).

- longitude:

  (numeric, required) Longitude of the target location (decimal degrees,
  WGS84).

- n_colors:

  (integer, default `6`) Number of colours to extract.

- zoom:

  (integer, default `10`) Tile zoom level passed to
  `maptiles::get_tiles()`. Higher values show more detail but download
  larger tiles.

- bbox_size:

  (numeric, default `NULL`) Half-side of the bounding square in metres
  (in EPSG:3857). When `NULL`, it is set to `5000 * (15 - zoom)` — the
  same heuristic used by earthtones.

- provider:

  (character, default `"Esri.WorldImagery"`) Tile provider passed to
  `maptiles::get_tiles()`.

- method:

  (character, default `"kmeans"`) Clustering method: `"kmeans"`
  (default) or `"mean"` / `"quantile"` for a simple central-tendency
  single colour.

- sample_n:

  (integer, default `10000`) Maximum number of pixels to sample before
  clustering. Reduces memory usage for high-zoom tiles.

- seed:

  (integer, default `42`) Random seed for k-means reproducibility.

## Value

A character vector of `n_colors` hex colour codes.

## See also

[`grDevices::rgb()`](https://rdrr.io/r/grDevices/rgb.html),
`maptiles::get_tiles()`,
[`stats::kmeans()`](https://rdrr.io/r/stats/kmeans.html)

## Author

Adrien Taudière

## Examples

``` r
if (FALSE) { # \dontrun{
# Palette from the Massif Central, France
cols <- palette_earthtones(latitude = 44.5, longitude = 3.2, n_colors = 5)
scales::show_col(cols)

# Palette from the Norwegian fjords (tests latitude sensitivity)
cols_north <- palette_earthtones(latitude = 60.4, longitude = 5.3, n_colors = 5)
scales::show_col(cols_north)
} # }
```
