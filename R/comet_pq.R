utils::globalVariables("index")

################################################################################
#' Comet plot for paired or multi-step measurements from a phyloseq object
#'
#' @description
#'
#' <a href="https://adrientaudiere.github.io/MiscMetabar/articles/Rules.html#lifecycle">
#' <img src="https://img.shields.io/badge/lifecycle-experimental-orange" alt="lifecycle-experimental"></a>
#'
#' A comet plot (also called a tapered-line or slope arrow plot) visualises
#' paired or multi-step continuous measurements for each observational unit.
#' A linewidth-tapered segment (or path) connects the origin to the destination:
#' the narrow end is the origin and the wide end is the destination.
#'
#' **Vocabulary**
#'
#' - A **comet** is the full path drawn for one observational unit. It is
#'   defined by a sequence of `(x, y, modality_level)` observations sharing
#'   the same `id` value. Each `id` level defines exactly one comet.
#' - A **step** is one node (x, y) along a comet, corresponding to one level
#'   of the `modality` ordered factor. Duplicate modality levels within the
#'   same `id` are not allowed.
#' - The **tail** is the first step (smallest modality level); the **tip** is
#'   the last step (largest modality level). The path tapers from thin at the
#'   tail to thick at the tip.
#'
#' Two interfaces are supported:
#'
#' - **Wide format** (`x_start`, `x_end`, `y_start`, `y_end`): each row in
#'   `data` holds start and end coordinates. Uses [ggforce::geom_link()] to
#'   draw a single tapered segment per row.
#'
#' - **Long format** (`x`, `y`, `modality`, `id`): each row holds one
#'   measurement for one observational unit at one modality level. `modality`
#'   must be an ordered factor with 2 or more levels; `id` identifies each
#'   unit. Uses [ggforce::geom_link2()] so that linewidth tapers continuously
#'   across all steps (not independently per segment), enabling timeline-style
#'   multi-step comets.
#'
#' Inspired by Armstrong 2014 (IEEE VIS) and zanarmstrong's gist at
#' <https://gist.github.com/zanarmstrong/6c2855a34f504029847485c690692e75>.
#'
#' The function accepts either a plain `data.frame` or a
#' [phyloseq::phyloseq-class] object. When a phyloseq object is supplied, the
#' sample metadata is used and the result is an overview plot at the sample
#' level.
#'
#' @param data A `data.frame` or [phyloseq::phyloseq-class] object.
#'   When a phyloseq object is given, `phyloseq::sample_data()` is coerced to
#'   a data frame.
#' @param x_start,x_end (wide format) Column names giving the x-coordinate of
#'   the comet origin and tip.
#' @param y_start,y_end (wide format) Column names giving the y-coordinate of
#'   the comet origin and tip.
#' @param x (long format) Column name for the x values.
#' @param y (long format) Column name for the y values.
#' @param modality (long format) Column name of an **ordered factor** (2+
#'   levels) whose levels define the comet steps. Each level is one node of the
#'   path; the taper runs from the first level (thin) to the last (thick).
#'   Must be an ordered factor — use `factor(..., ordered = TRUE)`. Each `id`
#'   must be present at two or more distinct levels; duplicate
#'   `(id, modality_level)` combinations are not allowed — aggregate first
#'   if needed (see example 5).
#' @param id (long format) Column name identifying each observational unit.
#'   Rows sharing the same `id` are connected into one comet path.
#'   **Nesting requirement:** each `id` value must appear at two or more
#'   *distinct* `modality` levels; units with fewer are dropped with a warning.
#'   If your natural identifier only appears at a single modality level (e.g.
#'   individuals each sampled at only one time point), the id and modality
#'   roles may need to be swapped or the data aggregated. See example 5 for
#'   an aggregation-based restructuring using `aggregate()`.
#' @param color_by (character, default `NULL`) Optional column name to map to
#'   the colour of the comet. In long format, two behaviours are possible:
#'   if `color_by` names the same column as `modality`, colour interpolates
#'   continuously along each path as a viridis gradient (tail = dark, tip =
#'   bright), with level names shown on the colour legend; otherwise, colour
#'   is held constant within each comet (first value per `id`), so that
#'   `color_by` can identify or categorise each comet.
#' @param label_by (character, default `NULL`) Optional column name whose
#'   values label the comet tip (last modality level in long format; `x_end`
#'   position in wide format).
#' @param label_size (numeric, default `3`) Text size for tip labels.
#' @param label_nudge_x,label_nudge_y (numeric, default `0`) Horizontal and
#'   vertical offset (in data units) applied to the tip label position. Use
#'   these to move the label away from the tip point so it does not overlap.
#' @param step_label_by (character, default `NULL`) Long-format only. Column
#'   name whose values are drawn as text at every modality step (node) along
#'   the path. Typically the `modality` column itself, to annotate each node
#'   with its level name. Ignored in wide format.
#' @param step_label_size (numeric, default `2`) Text size for step labels.
#' @param alpha (numeric, default `1`) Transparency of the segments.
#' @param n_interp (integer, default `100`) Number of interpolation points
#'   used by [ggforce::geom_link()] or [ggforce::geom_link2()]. Higher values
#'   give smoother tapers.
#' @param linewidth_range (numeric vector of length 2, default `c(0.1, 3)`)
#'   Minimum and maximum linewidth mapped to the taper gradient.
#' @param add_tip_point (logical, default `TRUE`) If `TRUE`, a filled point is
#'   drawn at the tip (end/last level) of each comet.
#' @param tip_size (numeric, default `3`) Size of the tip point.
#' @param na_rm (logical, default `TRUE`) If `TRUE`, rows with `NA` in any of
#'   the columns used by the plot (coordinates, `modality`, `id`, `color_by`,
#'   `label_by`, `step_label_by`) are silently dropped before plotting.
#' @param xlab,ylab (character, default `NULL`) Axis labels.
#'
#' @return A [ggplot2::ggplot] object.
#' @author Adrien Taudière
#' @seealso [ggforce::geom_link()] for the wide-format taper;
#'   [ggforce::geom_link2()] for the long-format multi-step taper.
#' @export
#'
#' @examples
#' # 1. Wide format: each row has start and end coordinates
#' df <- data.frame(
#'   id       = letters[1:6],
#'   modality = c("v1", "v1", "v1", "v2", "v2", "v2"),
#'   x_start  = c(12, 25, 8, 18, 14, 20),
#'   x_end    = c(12, 25, 8, 18, 14, 20) + rnorm(6, mean = 15, sd = 2),
#'   y_start  = rnorm(6, mean = 15, sd = 2),
#'   y_end    = c(5, 21, 7, 1, 26, 9)
#' )
#' comet_pq(df,
#'   x_start = "x_start", x_end = "x_end",
#'   y_start = "y_start", y_end = "y_end",
#'   label_by = "id",
#'   color_by = "modality"
#' )
#'
#' # 2. Long format: ordered factor modality for multi-step timeline comets
#' df_long <- data.frame(
#'   id    = rep(letters[1:4], each = 3),
#'   time  = factor(
#'     rep(c("T0", "T1", "T2"), 4),
#'     levels = c("T0", "T1", "T2"),
#'     ordered = TRUE
#'   ),
#'   x_val = rnorm(12),
#'   y_val = c(1, 3, 2, 2, 4, 3, 3, 2, 4, 8, 1, 2),
#'   grp   = rep(c("A", "A", "B", "B"), each = 3)
#' )
#' comet_pq(df_long,
#'   x = "x_val", y = "y_val",
#'   modality = "time", id = "id",
#'   color_by = "grp",
#'   label_by = "id", label_nudge_x = 0.05,
#'   step_label_by = "time", step_label_size = 2
#' )
#' 
#' \donttest{
#' # 3. From a phyloseq object: fungal diversity along tree height
#' #    (tail = Low, tip = High). In data_fungi_mini each tree is sampled at
#' #    up to three heights, making height the natural ordered modality.
#' data(data_fungi_mini, package = "MiscMetabar")
#' df_pq <- MiscMetabar::psmelt_samples_pq(data_fungi_mini)
#' df_pq$Height_ord <- factor(
#'   df_pq$Height,
#'   levels = c("Low", "Middle", "High"),
#'   ordered = TRUE
#' )
#' comet_pq(
#'   df_pq[!is.na(df_pq$Tree_name) & !is.na(df_pq$Height_ord), ],
#'   x = "Hill_0", y = "Abundance_log10",
#'   modality = "Height_ord", id = "Tree_name",
#'   color_by = "Height_ord", label_by = "Tree_name",
#'   label_nudge_x = 0.05
#' )
#' 
#' # 4. Same height modality, but constant colour per comet (by sampling Time).
#' #    comet_pq requires exactly one row per (id, modality) step, so
#' #    aggregate first to handle any trees sampled twice at the same height.
#' df_ex4 <- aggregate(
#'   cbind(Hill_0, Abundance_log10) ~ Tree_name + Height_ord,
#'   data = df_pq[!is.na(df_pq$Tree_name) & !is.na(df_pq$Height_ord) &
#'                  !is.na(df_pq$Time), ],
#'   FUN = mean
#' )
#' df_ex4$Time_chr <- as.character(
#'   df_pq$Time[match(df_ex4$Tree_name, df_pq$Tree_name)]
#' )
#' comet_pq(
#'   df_ex4,
#'   x = "Hill_0", y = "Abundance_log10",
#'   modality = "Height_ord", id = "Tree_name",
#'   color_by = "Time_chr", label_by = "Tree_name",
#'   label_nudge_x = 0.05
#' )
#' # 5. Gradient by time: each height (Low/Middle/High) recurs at all four
#' #    time points, making Height_ord the natural id for time-step comets.
#' #    color_by must equal modality to trigger the viridis gradient.
#' df_pq$Time_ord <- factor(
#'   df_pq$Time, levels = c("0", "5", "10", "15"), ordered = TRUE
#' )
#' df_ex5 <- aggregate(
#'   cbind(Hill_0, Abundance_log10) ~ Height_ord + Time_ord,
#'   data = df_pq[!is.na(df_pq$Height_ord) & !is.na(df_pq$Time_ord), ],
#'   FUN = mean
#' )
#' comet_pq(
#'   df_ex5,
#'   x = "Hill_0", y = "Abundance_log10",
#'   modality = "Time_ord", id = "id",
#'   color_by = "Time_ord",
#'   label_by = "Height_ord",
#'   label_nudge_x = 0.05
#' )
#' 
#' }

comet_pq <- function(
  data,
  x_start = NULL,
  x_end = NULL,
  y_start = NULL,
  y_end = NULL,
  x = NULL,
  y = NULL,
  modality = NULL,
  id = NULL,
  color_by = NULL,
  label_by = NULL,
  label_size = 3,
  label_nudge_x = 0,
  label_nudge_y = 0,
  step_label_by = NULL,
  step_label_size = 2,
  alpha = 1,
  n_interp = 100,
  linewidth_range = c(0.1, 3),
  add_tip_point = TRUE,
  tip_size = 3,
  na_rm = TRUE,
  xlab = NULL,
  ylab = NULL
) {
  if (!requireNamespace("ggforce", quietly = TRUE)) {
    cli::cli_abort(
      "Package {.pkg ggforce} is required. Install it with {.code install.packages('ggforce')}."
    )
  }

  if (inherits(data, "phyloseq")) {
    data <- as.data.frame(phyloseq::sample_data(data))
    class(data) <- "data.frame"
  }

  if (!inherits(data, "data.frame")) {
    cli::cli_abort("{.arg data} must be a data.frame or phyloseq object.")
  }

  use_modality <- !is.null(modality)
  use_wide <- !is.null(x_start) && !is.null(x_end) && !is.null(y_start) && !is.null(y_end)

  if (na_rm) {
    if (use_modality) {
      used_cols <- c(x, y, modality, id, color_by, label_by, step_label_by)
    } else {
      used_cols <- c(x_start, x_end, y_start, y_end, color_by, label_by)
    }
    used_cols <- used_cols[used_cols %in% names(data)]
    if (length(used_cols) > 0) {
      data <- data[stats::complete.cases(data[, used_cols, drop = FALSE]), ]
    }
  }

  if (!use_modality && !use_wide) {
    cli::cli_abort(
      c(
        "Must supply one of:",
        "i" = "Wide format: {.arg x_start}, {.arg x_end}, {.arg y_start}, {.arg y_end}.",
        "i" = "Long format: {.arg x}, {.arg y}, {.arg modality}, {.arg id}."
      )
    )
  }
  if (use_modality && use_wide) {
    cli::cli_abort(
      "Cannot mix wide-format ({.arg x_start}/{.arg x_end}/...) and long-format ({.arg modality}/{.arg id}/...) arguments."
    )
  }

  if (!is.null(color_by) && !color_by %in% names(data)) {
    cli::cli_abort("Column {.val {color_by}} not found in {.arg data}.")
  }
  if (!is.null(label_by) && !label_by %in% names(data)) {
    cli::cli_abort("Column {.val {label_by}} not found in {.arg data}.")
  }
  if (!is.null(step_label_by) && !step_label_by %in% names(data)) {
    cli::cli_abort("Column {.val {step_label_by}} not found in {.arg data}.")
  }

  if (use_modality) {
    if (is.null(x) || is.null(y) || is.null(id)) {
      cli::cli_abort(
        "When using {.arg modality}, you must also supply {.arg x}, {.arg y}, and {.arg id}."
      )
    }
    needed <- c(x, y, modality, id)
    missing_cols <- needed[!needed %in% names(data)]
    if (length(missing_cols) > 0) {
      cli::cli_abort("Column{?s} not found in {.arg data}: {.val {missing_cols}}")
    }
    if (!is.ordered(data[[modality]])) {
      cli::cli_abort(
        c(
          "{.arg modality} column {.val {modality}} must be an ordered factor.",
          "i" = "Use {.code factor({modality}, levels = ..., ordered = TRUE)} to create one."
        )
      )
    }
    n_levels <- nlevels(data[[modality]])
    if (n_levels < 2) {
      cli::cli_abort("{.arg modality} must have at least 2 levels.")
    }

    data <- data[order(data[[id]], as.numeric(data[[modality]])), ]

    id_level_counts <- tapply(
      as.character(data[[modality]]), data[[id]],
      function(v) length(unique(v))
    )
    single_point_ids <- names(id_level_counts)[id_level_counts < 2]
    if (length(single_point_ids) > 0) {
      cli::cli_warn(c(
        "{length(single_point_ids)} {.arg id} value{?s} dropped: fewer than 2 distinct {.arg modality} levels.",
        "i" = "Each comet must span ≥2 modality levels. If your natural id only appears at one level (e.g. individuals each sampled at a single time point), the {.arg id} and {.arg modality} roles may need to be swapped or the data aggregated.",
        "i" = "See {.code ?comet_pq} example 5 for an {.fn aggregate}-based restructuring.",
        "i" = "Dropped {.arg id} value{?s}: {.val {single_point_ids}}"
      ))
      data <- data[!data[[id]] %in% single_point_ids, ]
    }

    dup_key <- interaction(data[[id]], data[[modality]], drop = TRUE)
    if (anyDuplicated(dup_key)) {
      cli::cli_abort(c(
        "Duplicate {.arg modality} levels found within one or more {.arg id} groups.",
        "i" = "Each step of a comet must have exactly one row per ({.arg id}, {.arg modality}) combination.",
        "i" = "Aggregate duplicates first — see {.code ?comet_pq} example 5, or use:",
        "i" = "{.code dplyr::summarise(dplyr::across(c({.val {x}}, {.val {y}}), mean), .by = c({.val {id}}, {.val {modality}}))}"
      ))
    }

    # Linewidth index: 0 at the tail (first level), 1 at the tip (last level).
    data$.lw_index <- (as.numeric(data[[modality]]) - 1) / (n_levels - 1)

    # Colour index (global, same scale as .lw_index): used when color_by ==
    # modality so the gradient reflects the actual modality position rather
    # than a per-comet-normalised value.
    data$.color_index <- data$.lw_index

    # Two colour modes for long format:
    # - gradient (color_by == modality): .color_index mapped to viridis_c so
    #   the colour transitions continuously along each comet path.
    # - constant (color_by != modality): a single colour per id is used;
    #   geom_link2 would otherwise blend discrete colours across nodes.
    use_gradient_color <- !is.null(color_by) && color_by == modality
    use_const_color <- !is.null(color_by) && color_by != modality
    if (use_const_color) {
      first_color <- tapply(
        as.character(data[[color_by]]), data[[id]],
        function(x_val) x_val[1]
      )
      data$.colour_const <- first_color[as.character(data[[id]])]
      varying <- names(which(tapply(
        as.character(data[[color_by]]), data[[id]],
        function(x_val) length(unique(x_val)) > 1
      )))
      if (length(varying) > 0) {
        cli::cli_warn(
          "{.arg color_by} varies within {length(varying)} {.arg id} group{?s}: using the first value per group."
        )
      }
    }

    aes_link2 <- ggplot2::aes(
      x = .data[[x]],
      y = .data[[y]],
      group = .data[[id]],
      linewidth = .data[[".lw_index"]]
    )
    if (!is.null(color_by)) {
      if (use_gradient_color) {
        aes_link2$colour <- rlang::sym(".color_index")
      } else {
        aes_link2$colour <- rlang::sym(".colour_const")
      }
    }

    p <- ggplot2::ggplot(data) +
      ggforce::geom_link2(
        mapping = aes_link2,
        n = n_interp,
        alpha = alpha
      ) +
      ggplot2::scale_linewidth(range = linewidth_range) +
      ggplot2::guides(linewidth = "none") +
      ggplot2::labs(
        x = xlab %||% x,
        y = ylab %||% y
      ) +
      ggplot2::theme_minimal()

    if (use_gradient_color) {
      lw_breaks <- (seq_len(n_levels) - 1) / (n_levels - 1)
      p <- p + ggplot2::scale_color_viridis_c(
        breaks = lw_breaks,
        labels = levels(data[[modality]]),
        name = modality
      )
    } else if (use_const_color) {
      p <- p + ggplot2::scale_color_discrete(name = color_by)
    }

    last_level <- levels(data[[modality]])[n_levels]
    tip_data <- data[data[[modality]] == last_level, ]

    if (add_tip_point) {
      aes_pt <- ggplot2::aes(x = .data[[x]], y = .data[[y]])
      if (!is.null(color_by)) {
        if (use_gradient_color) {
          aes_pt$colour <- rlang::sym(".color_index")
        } else {
          aes_pt$colour <- rlang::sym(".colour_const")
        }
      }
      p <- p + ggplot2::geom_point(data = tip_data, mapping = aes_pt, size = tip_size)
    }

    if (!is.null(label_by)) {
      aes_txt <- ggplot2::aes(
        x = .data[[x]],
        y = .data[[y]],
        label = .data[[label_by]]
      )
      p <- p +
        ggplot2::geom_text(
          data = tip_data,
          mapping = aes_txt,
          size = label_size,
          hjust = -0.2,
          nudge_x = label_nudge_x,
          nudge_y = label_nudge_y
        )
    }

    if (!is.null(step_label_by)) {
      aes_step <- ggplot2::aes(
        x = .data[[x]],
        y = .data[[y]],
        label = .data[[step_label_by]]
      )
      p <- p +
        ggplot2::geom_text(
          mapping = aes_step,
          size = step_label_size,
          vjust = -0.5
        )
    }
  } else {
    needed <- c(x_start, x_end, y_start, y_end)
    missing_cols <- needed[!needed %in% names(data)]
    if (length(missing_cols) > 0) {
      cli::cli_abort("Column{?s} not found in {.arg data}: {.val {missing_cols}}")
    }

    aes_link <- ggplot2::aes(
      x = .data[[x_start]],
      xend = .data[[x_end]],
      y = .data[[y_start]],
      yend = .data[[y_end]],
      linewidth = ggplot2::after_stat(index)
    )
    if (!is.null(color_by)) {
      aes_link$colour <- rlang::sym(color_by)
    }

    p <- ggplot2::ggplot(data) +
      ggforce::geom_link(
        mapping = aes_link,
        n = n_interp,
        alpha = alpha
      ) +
      ggplot2::scale_linewidth(range = linewidth_range) +
      ggplot2::guides(linewidth = "none") +
      ggplot2::labs(
        x = xlab %||% x_start,
        y = ylab %||% y_start
      ) +
      ggplot2::theme_minimal()

    if (add_tip_point) {
      aes_pt <- ggplot2::aes(x = .data[[x_end]], y = .data[[y_end]])
      if (!is.null(color_by)) {
        aes_pt$colour <- rlang::sym(color_by)
      }
      p <- p + ggplot2::geom_point(mapping = aes_pt, size = tip_size)
    }

    if (!is.null(label_by)) {
      aes_txt <- ggplot2::aes(
        x = .data[[x_end]],
        y = .data[[y_end]],
        label = .data[[label_by]]
      )
      p <- p +
        ggplot2::geom_text(
          mapping = aes_txt,
          size = label_size,
          hjust = -0.2,
          nudge_x = label_nudge_x,
          nudge_y = label_nudge_y
        )
    }
  }

  p
}
################################################################################
