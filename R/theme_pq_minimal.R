#' A pared-down minimalist ggplot2 theme for ggplotpq
#'
#' @description
#'
#' <a href="https://adrientaudiere.github.io/MiscMetabar/articles/Rules.html#lifecycle">
#' <img src="https://img.shields.io/badge/lifecycle-experimental-orange" alt="lifecycle-experimental"></a>
#'
#' A minimalist ggplot2 theme that mirrors the look of [theme_idest()]
#' but with no font customisation, no light/dark toggles, and no
#' grid/axis/ticks switches. It is intended as a sensible default
#' theme that does not require the user to have any specific fonts
#' installed.
#'
#' For more control over fonts, grid lines, axis lines and ticks, use
#' [theme_idest()] instead.
#'
#' @param base_size (numeric, default 11) Base font size.
#' @param base_family (character, default "") Base font family. Empty
#'   string means use the system default sans-serif family.
#' @param plot_title_size (numeric, default 14) Font size for the plot
#'   title.
#' @param axis_title_size (numeric, default 11) Font size for the axis
#'   titles.
#'
#' @return A [ggplot2::theme] object.
#' @author Adrien Taudière
#' @seealso [theme_idest()] for a fuller, font-aware theme.
#' @export
#'
#' @examples
#' \donttest{
#' library(ggplot2)
#' ggplot(mtcars, aes(wt, mpg)) +
#'   geom_point() +
#'   theme_pq_minimal()
#' }
theme_pq_minimal <- function(
  base_size = 11,
  base_family = "",
  plot_title_size = 14,
  axis_title_size = 11
) {
  ggplot2::theme_minimal(
    base_family = base_family,
    base_size = base_size
  ) +
    ggplot2::theme(
      legend.background = ggplot2::element_blank(),
      legend.key = ggplot2::element_blank(),
      plot.title = ggplot2::element_text(
        size = plot_title_size,
        face = "bold",
        hjust = 0,
        margin = ggplot2::margin(b = 8)
      ),
      plot.subtitle = ggplot2::element_text(
        size = base_size,
        hjust = 0,
        margin = ggplot2::margin(b = 10),
        color = "grey30"
      ),
      plot.caption = ggplot2::element_text(
        size = base_size * 0.8,
        hjust = 1,
        color = "grey30"
      ),
      axis.title = ggplot2::element_text(
        size = axis_title_size,
        face = "plain"
      ),
      axis.title.x = ggplot2::element_text(
        size = axis_title_size,
        hjust = 0.5
      ),
      axis.title.y = ggplot2::element_text(
        size = axis_title_size,
        hjust = 0.5
      ),
      strip.text = ggplot2::element_text(face = "bold", hjust = 0),
      panel.grid.minor = ggplot2::element_blank(),
      panel.grid.major = ggplot2::element_line(
        color = "#e6e6e6",
        linewidth = 0.2
      ),
      axis.ticks = ggplot2::element_blank()
    )
}
