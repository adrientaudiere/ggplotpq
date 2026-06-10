#' ggplot2 discrete colour scale using the IdEst palette family
#'
#' @description
#'
#' <a href="https://adrientaudiere.github.io/MiscMetabar/articles/Rules.html#lifecycle">
#' <img src="https://img.shields.io/badge/lifecycle-experimental-orange" alt="lifecycle-experimental"></a>
#'
#' A thin wrapper around [scale_color_idest_d()] that uses one of the
#' curated colorblind-safe IdEst palettes (`Hokusai3`, `Picabia`,
#' `Picasso`, `Levine2`, `Rattner`, `Sidhu`) by name. Behaves like
#' [ggplot2::scale_color_brewer()] but with the IdEst palette set.
#'
#' @param palette (character, default "Hokusai3") The IdEst palette
#'   to use. Must be one of the palettes in [idest_pal].
#' @param direction (integer, default 1) Set to -1 to reverse the
#'   palette.
#' @param override_order (logical, default FALSE) Override the curated
#'   perceptual ordering of the palette.
#' @param ... Additional arguments passed to [ggplot2::discrete_scale()].
#'
#' @return A [ggplot2::ggplot] discrete colour scale.
#' @author Adrien Taudière
#' @seealso [scale_fill_pq_discrete()] for the matching fill scale,
#'   [idest_colors()] for the underlying palette lookup.
#' @export
#'
#' @examples
#' \donttest{
#' library(ggplot2)
#' ggplot(mtcars, aes(wt, mpg, color = factor(cyl))) +
#'   geom_point(size = 2) +
#'   scale_color_pq_discrete("Picabia")
#' }
scale_color_pq_discrete <- function(
  palette = "Hokusai3",
  direction = 1,
  override_order = FALSE,
  ...
) {
  if (!palette %in% names(idest_pal)) {
    cli::cli_abort(
      "Palette {.val {palette}} is not in the IdEst palette family. See {.fn idest_pal} for the available names."
    )
  }
  if (!direction %in% c(1, -1)) {
    cli::cli_abort("{.arg direction} must be 1 or -1.")
  }

  scale_color_idest_d(
    palette_name = palette,
    direction = direction,
    override_order = override_order,
    ...
  )
}


#' ggplot2 discrete fill scale using the IdEst palette family
#'
#' @inheritParams scale_color_pq_discrete
#'
#' @return A [ggplot2::ggplot] discrete fill scale.
#' @author Adrien Taudière
#' @seealso [scale_color_pq_discrete()] for the matching colour scale.
#' @export
#'
#' @examples
#' \donttest{
#' library(ggplot2)
#' ggplot(mtcars, aes(factor(cyl), fill = factor(cyl))) +
#'   geom_bar() +
#'   scale_fill_pq_discrete("Levine2")
#' }
scale_fill_pq_discrete <- function(
  palette = "Hokusai3",
  direction = 1,
  override_order = FALSE,
  ...
) {
  if (!palette %in% names(idest_pal)) {
    cli::cli_abort(
      "Palette {.val {palette}} is not in the IdEst palette family. See {.fn idest_pal} for the available names."
    )
  }
  if (!direction %in% c(1, -1)) {
    cli::cli_abort("{.arg direction} must be 1 or -1.")
  }

  scale_fill_idest_d(
    palette_name = palette,
    direction = direction,
    override_order = override_order,
    ...
  )
}
