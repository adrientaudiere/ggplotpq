################################################################################
#' Derive a colour palette from a geographic location
#'
#' @description
#'
#' <a href="https://adrientaudiere.github.io/MiscMetabar/articles/Rules.html#lifecycle">
#' <img src="https://img.shields.io/badge/lifecycle-experimental-orange" alt="lifecycle-experimental"></a>
#'
#' Retrieves a satellite or map tile centred on a geographic point (via
#' \pkg{maptiles}) and clusters the pixel colours with k-means to produce a
#' palette of dominant tones. Unlike the upstream \pkg{earthtones} package,
#' this implementation uses the bounding-box derived from the actual map
#' projection (EPSG:3857), which avoids the latitude-invariance bug present
#' in \pkg{earthtones} \eqn{\leq} 0.2.0.
#'
#' @param latitude (numeric, required) Latitude of the target location
#'   (decimal degrees, WGS84).
#' @param longitude (numeric, required) Longitude of the target location
#'   (decimal degrees, WGS84).
#' @param n_colors (integer, default `6`) Number of colours to extract.
#' @param zoom (integer, default `10`) Tile zoom level passed to
#'   [maptiles::get_tiles()]. Higher values show more detail but download
#'   larger tiles.
#' @param bbox_size (numeric, default `NULL`) Half-side of the bounding square
#'   in metres (in EPSG:3857). When `NULL`, it is set to
#'   `5000 * (15 - zoom)` — the same heuristic used by \pkg{earthtones}.
#' @param provider (character, default `"Esri.WorldImagery"`) Tile provider
#'   passed to [maptiles::get_tiles()].
#' @param method (character, default `"kmeans"`) Clustering method: `"kmeans"`
#'   (default) or `"mean"` / `"quantile"` for a simple central-tendency
#'   single colour.
#' @param sample_n (integer, default `10000`) Maximum number of pixels to
#'   sample before clustering. Reduces memory usage for high-zoom tiles.
#' @param seed (integer, default `42`) Random seed for k-means
#'   reproducibility.
#'
#' @return A character vector of `n_colors` hex colour codes.
#' @author Adrien Taudière
#' @seealso [grDevices::rgb()], [maptiles::get_tiles()], [stats::kmeans()]
#' @export
#'
#' @examples
#' \dontrun{
#' # Palette from the Massif Central, France
#' cols <- palette_earthtones(latitude = 44.5, longitude = 3.2, n_colors = 5)
#' scales::show_col(cols)
#'
#' # Palette from the Norwegian fjords (tests latitude sensitivity)
#' cols_north <- palette_earthtones(latitude = 60.4, longitude = 5.3, n_colors = 5)
#' scales::show_col(cols_north)
#' }
palette_earthtones <- function(
  latitude,
  longitude,
  n_colors = 6,
  zoom = 10,
  bbox_size = NULL,
  provider = "Esri.WorldImagery",
  method = c("kmeans", "mean", "quantile"),
  sample_n = 10000,
  seed = 42
) {
  method <- match.arg(method)

  if (!is.null(bbox_size) && bbox_size <= 0) {
    cli::cli_abort("{.arg bbox_size} must be positive (got {bbox_size}).")
  }

  if (!requireNamespace("maptiles", quietly = TRUE)) {
    cli::cli_abort(
      "Package {.pkg maptiles} is required. Install it with {.code install.packages('maptiles')}."
    )
  }
  if (!requireNamespace("terra", quietly = TRUE)) {
    cli::cli_abort(
      "Package {.pkg terra} is required. Install it with {.code install.packages('terra')}."
    )
  }
  if (!requireNamespace("sf", quietly = TRUE)) {
    cli::cli_abort(
      "Package {.pkg sf} is required. Install it with {.code install.packages('sf')}."
    )
  }

  if (is.null(bbox_size)) {
    bbox_size <- 5000 * (15 - zoom)
  }

  point_sf <- sf::st_sfc(sf::st_point(c(longitude, latitude)), crs = 4326)
  point_3857 <- sf::st_transform(point_sf, 3857)
  bbox <- sf::st_bbox(sf::st_buffer(point_3857, dist = bbox_size))

  map_raster <- maptiles::get_tiles(
    x = bbox,
    provider = provider,
    crop = TRUE,
    zoom = zoom
  )

  pixel_vals <- terra::values(map_raster, mat = TRUE)
  pixel_vals <- pixel_vals[stats::complete.cases(pixel_vals), , drop = FALSE]

  if (nrow(pixel_vals) == 0) {
    cli::cli_abort(
      "No valid pixels found. Try a different location or zoom level."
    )
  }

  if (nrow(pixel_vals) > sample_n) {
    set.seed(seed)
    pixel_vals <- pixel_vals[
      sample.int(nrow(pixel_vals), sample_n),
      ,
      drop = FALSE
    ]
  }

  if (ncol(pixel_vals) >= 3) {
    rgb_mat <- pixel_vals[, 1:3, drop = FALSE]
  } else {
    cli::cli_abort("Raster has fewer than 3 bands; cannot extract RGB colours.")
  }

  if (method == "kmeans") {
    set.seed(seed)
    km <- stats::kmeans(rgb_mat, centers = n_colors, nstart = 5)
    centers <- km$centers[order(km$size, decreasing = TRUE), , drop = FALSE]
    cols <- grDevices::rgb(centers, maxColorValue = 255)
  } else if (method == "mean") {
    col_mean <- colMeans(rgb_mat)
    cols <- rep(grDevices::rgb(t(col_mean), maxColorValue = 255), n_colors)
  } else {
    q25 <- apply(rgb_mat, 2, stats::quantile, probs = 0.25)
    q75 <- apply(rgb_mat, 2, stats::quantile, probs = 0.75)
    centers <- rbind(colMeans(rgb_mat), q25, q75)
    centers <- centers[
      rep_len(seq_len(nrow(centers)), n_colors),
      ,
      drop = FALSE
    ]
    cols <- grDevices::rgb(centers, maxColorValue = 255)
  }

  cols
}
################################################################################
