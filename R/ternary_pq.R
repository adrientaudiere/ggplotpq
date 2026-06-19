utils::globalVariables(c(
  "x",
  "y",
  "xend",
  "yend",
  "labels",
  "xb",
  "yb",
  "xl",
  "yl",
  "xr",
  "yr",
  "xnw",
  "ynw",
  "xne",
  "yne",
  "xse",
  "yse",
  "xsw",
  "ysw"
))

# Internal: compute ternary / diamond coordinates for each taxon
# Returns a data.frame with columns x, y, abundance (per-taxon overall
# relative abundance), and taxon (row name). Attributes: type, extreme, labels.
.ternary_norm <- function(physeq, group, level_order, raw, normalize_groups) {
  if (!is.null(phyloseq::sample_data(physeq, FALSE))) {
    if (is.character(group) && length(group) == 1) {
      sd <- data.frame(phyloseq::sample_data(physeq))
      if (!group %in% colnames(sd)) {
        cli::cli_abort(
          "{.arg group} ({.val {group}}) not found in sample_data."
        )
      }
      group <- factor(sd[[group]])
    }
  }
  if (!is.factor(group)) {
    group <- factor(group)
  }

  # Drop samples where group is NA to avoid rowsum treating NA as a group
  keep_idx <- !is.na(group)
  if (sum(keep_idx) < length(keep_idx)) {
    physeq <- phyloseq::prune_samples(keep_idx, physeq)
    group <- droplevels(group[keep_idx])
  }

  # Drop taxa with zero counts in the retained samples to avoid 0/0 = NaN
  physeq <- phyloseq::prune_taxa(phyloseq::taxa_sums(physeq) > 0, physeq)

  if (!is.null(level_order)) {
    missing_lvls <- setdiff(levels(group), level_order)
    if (length(missing_lvls) > 0) {
      cli::cli_abort(
        "Some levels of {.arg group} are not in {.arg level_order}: {.val {missing_lvls}}"
      )
    }
    group <- factor(group, levels = level_order)
  }

  n_levels <- nlevels(group)
  if (n_levels < 3 || n_levels > 4) {
    cli::cli_abort(
      "{.arg group} must have exactly 3 or 4 levels, not {n_levels}."
    )
  }

  otu <- as(phyloseq::otu_table(physeq), "matrix")
  if (phyloseq::taxa_are_rows(physeq) == FALSE) {
    otu <- t(otu)
  }

  if (raw) {
    tot <- sum(otu)
    meandf <- t(rowsum(t(otu), group, reorder = TRUE)) /
      rowSums(t(otu))
    abundance <- rowSums(t(otu)) / tot
  } else {
    rel <- apply(otu, 2, function(x) x / sum(x))
    abundance <- rowSums(rel) / sum(rel)
    if (normalize_groups) {
      grp_sizes <- as.vector(table(group)[levels(group)])
      grp_sizes_mat <- matrix(
        rep(grp_sizes, each = nrow(rel)),
        nrow = nrow(rel)
      )
      meandf <- t(rowsum(t(rel), group, reorder = TRUE)) / grp_sizes_mat
      meandf <- meandf / rowSums(meandf)
    } else {
      meandf <- t(rowsum(t(rel), group, reorder = TRUE)) / rowSums(rel)
    }
  }

  type <- if (n_levels == 3) "ternary" else "diamond"

  if (n_levels == 3) {
    a <- meandf[, 1]
    b <- meandf[, 2]
    cc <- meandf[, 3]
    xyz <- data.frame(
      x = 0.5 * (2 * b + cc) / (a + b + cc),
      y = sqrt(3) / 2 * cc / (a + b + cc),
      abundance = abundance,
      row.names = rownames(meandf)
    )
    extreme <- data.frame(
      x = c(0, 1, 0.5),
      y = c(0, 0, sqrt(3) / 2),
      row.names = c("left", "right", "top")
    )
  } else {
    a <- meandf[, 1]
    b <- meandf[, 2]
    cc <- meandf[, 3]
    d <- meandf[, 4]
    s <- a + b + cc + d
    xyz <- data.frame(
      x = (a - cc) / s,
      y = (b - d) / s,
      abundance = abundance,
      row.names = rownames(meandf)
    )
    extreme <- data.frame(
      x = c(1, 0, -1, 0),
      y = c(0, 1, 0, -1),
      row.names = c("right", "top", "left", "bottom")
    )
  }

  attr(xyz, "type") <- type
  attr(xyz, "extreme") <- extreme
  attr(xyz, "labels") <- colnames(meandf)
  attr(xyz, "physeq") <- physeq
  xyz
}


#' Ternary and diamond plots for 3-or-4-group taxon compositions
#'
#' @description
#'
#' <a href="https://adrientaudiere.github.io/MiscMetabar/articles/Rules.html#lifecycle">
#' <img src="https://img.shields.io/badge/lifecycle-experimental-orange" alt="lifecycle-experimental"></a>
#'
#' Displays each taxon as a point inside a triangle (3 groups) or a diamond
#' (4 groups) whose corners represent the sample groups. A taxon plotted
#' near one corner is most abundant in that group.
#'
#' The coordinate math follows the standard de Finetti diagram
#' (Wikipedia: Ternary plot):
#' \deqn{x = \frac{2b + c}{2(a+b+c)}, \quad y = \frac{\sqrt{3}\,c}{2(a+b+c)}}
#' where \eqn{a,b,c} are the mean relative abundances in the left, right, and
#' top groups respectively.
#'
#' The diamond projection for 4 groups uses:
#' \deqn{x = \frac{a - c}{a+b+c+d}, \quad y = \frac{b - d}{a+b+c+d}}
#' (right, top, left, bottom).
#'
#' This is an independent implementation; the coordinate formulas are in the
#' public domain (de Finetti 1926; see also Armstrong 2014, IEEE VIS).
#'
#' @param physeq (required) A [phyloseq::phyloseq-class] object.
#' @param fact (required) Either a single character string matching a
#'   variable name in `sample_data(physeq)`, or a factor of length
#'   `nsamples(physeq)`. Must have exactly 3 (ternary) or 4 (diamond) levels.
#' @param level_order (character vector, default `NULL`) Order of levels; for
#'   ternary plots this is (left, right, top); for diamond plots (right, top,
#'   left, bottom). When `NULL`, the natural factor level order is used.
#' @param raw (logical, default `FALSE`) If `TRUE`, raw counts are used
#'   instead of relative abundances.
#' @param normalize_groups (logical, default `TRUE`) If `TRUE` (and `raw =
#'   FALSE`), each group is given equal weight regardless of its sample count.
#'   If `FALSE`, weight is proportional to sample count.
#' @param color_rank (character, default `NULL`) Column name from `@tax_table`
#'   to map to point colour.
#' @param size_by (character, default `"abundance"`) How to scale point size.
#'   One of `"abundance"` (overall relative abundance), `"log10_abundance"`, or
#'   `"equal"` (all the same size).
#' @param label_by (character, default `NULL`) Column name from `@tax_table`
#'   (or `"taxon"` for row names) to annotate points with text labels.
#' @param label_size (numeric, default `2.5`) Text size for labels.
#' @param add_grid (logical, default `TRUE`) If `TRUE`, a 10-interval
#'   reference grid is drawn inside the triangle / diamond.
#' @param point_alpha (numeric, default `0.8`) Transparency of the points.
#'
#' @return A [ggplot2::ggplot] object.
#' @author Adrien Taudière
#' @export
#'
#' @examples
#' \donttest{
#' data(data_fungi_mini, package = "MiscMetabar")
#' # Ternary plot: Height has 3 levels (High, Low, Middle)
#' ternary_pq(data_fungi_mini, fact = "Height", color_rank = "Class")
#' # Diamond plot: Time has 4 levels (0, 5, 10, 15)
#' ternary_pq(data_fungi_mini, fact = "Time")
#' }
#'
#' \dontrun{
#' ternary_pq(data_fungi_mini, fact = "Height", color_rank = "Family", add_grid = FALSE)
#' ternary_pq(data_fungi_mini, fact = "Height", size_by = "log10_abundance")
#' }
ternary_pq <- function(
  physeq,
  fact,
  level_order = NULL,
  raw = FALSE,
  normalize_groups = TRUE,
  color_rank = NULL,
  size_by = c("abundance", "log10_abundance", "equal"),
  label_by = NULL,
  label_size = 2.5,
  add_grid = TRUE,
  point_alpha = 0.8
) {
  verify_pq(physeq)
  size_by <- match.arg(size_by)

  dat <- .ternary_norm(physeq, fact, level_order, raw, normalize_groups)
  type <- attr(dat, "type")
  extreme <- attr(dat, "extreme")
  lvl_labels <- attr(dat, "labels")
  physeq <- attr(dat, "physeq")

  dat$taxon <- rownames(dat)

  if (!is.null(color_rank)) {
    if (!color_rank %in% phyloseq::rank_names(physeq)) {
      cli::cli_abort(
        "{.arg color_rank} column {.val {color_rank}} not found in tax_table."
      )
    }
    dat$color_var <- as.vector(phyloseq::tax_table(physeq)[, color_rank])
  }

  if (!is.null(label_by)) {
    if (label_by == "taxon") {
      dat$label_var <- dat$taxon
    } else if (label_by %in% phyloseq::rank_names(physeq)) {
      dat$label_var <- as.vector(phyloseq::tax_table(physeq)[, label_by])
    } else {
      cli::cli_abort("{.arg label_by} must be {.val taxon} or a rank name.")
    }
  }

  dat$size_var <- switch(
    size_by,
    abundance = dat$abundance,
    log10_abundance = log1p(dat$abundance),
    equal = 1
  )

  borders <- data.frame(
    x = extreme$x,
    y = extreme$y,
    xend = extreme$x[c(2:nrow(extreme), 1)],
    yend = extreme$y[c(2:nrow(extreme), 1)]
  )

  axes_offset <- if (type == "ternary") {
    data.frame(
      x = extreme$x + c(-1 / 2, 1 / 2, 0) * 0.1,
      y = extreme$y + c(-sqrt(3) / 4, -sqrt(3) / 4, sqrt(3) / 4) * 0.1,
      labels = lvl_labels
    )
  } else {
    data.frame(
      x = extreme$x + c(0.12, 0, -0.12, 0),
      y = extreme$y + c(0, 0.1, 0, -0.1),
      labels = lvl_labels
    )
  }

  p <- ggplot2::ggplot() +
    ggplot2::theme_void() +
    ggplot2::theme(legend.title = ggplot2::element_blank())

  if (add_grid) {
    tick_seq <- seq(0.1, 0.9, by = 0.1)
    if (type == "ternary") {
      tc <- function(a, b, cc) {
        data.frame(
          x = 0.5 * (2 * b + cc) / (a + b + cc),
          y = sqrt(3) / 2 * cc / (a + b + cc)
        )
      }
      bt <- tc(tick_seq, 1 - tick_seq, 0)
      lt <- tc(tick_seq, 0, 1 - tick_seq)
      rt <- tc(0, 1 - tick_seq, tick_seq)
      grid_df1 <- data.frame(
        xb = bt$x,
        yb = bt$y,
        xl = lt$x,
        yl = lt$y
      )
      grid_df2 <- data.frame(
        xb = bt$x,
        yb = bt$y,
        xr = rt$x,
        yr = rt$y
      )
      grid_df3 <- data.frame(
        xl = rev(lt$x),
        yl = rev(lt$y),
        xr = rt$x,
        yr = rt$y
      )
      p <- p +
        ggplot2::geom_segment(
          data = grid_df1,
          ggplot2::aes(x = xb, y = yb, xend = xl, yend = yl),
          linewidth = 0.25,
          color = "grey60"
        ) +
        ggplot2::geom_segment(
          data = grid_df2,
          ggplot2::aes(x = xb, y = yb, xend = xr, yend = yr),
          linewidth = 0.25,
          color = "grey60"
        ) +
        ggplot2::geom_segment(
          data = grid_df3,
          ggplot2::aes(x = xl, y = yl, xend = xr, yend = yr),
          linewidth = 0.25,
          color = "grey60"
        )
    } else {
      dc <- function(a, b, cc, d) {
        s <- a + b + cc + d
        data.frame(x = (a - cc) / s, y = (b - d) / s)
      }
      nw <- dc(tick_seq, 1 - tick_seq, 0, 0)
      ne <- dc(0, tick_seq, 1 - tick_seq, 0)
      sw <- dc(tick_seq, 0, 0, 1 - tick_seq)
      se <- dc(0, 0, 1 - tick_seq, tick_seq)
      grid_dfd <- data.frame(
        xnw = nw$x,
        ynw = nw$y,
        xse = se$x,
        yse = se$y,
        xne = ne$x,
        yne = ne$y,
        xsw = sw$x,
        ysw = sw$y
      )
      p <- p +
        ggplot2::geom_segment(
          data = grid_dfd,
          ggplot2::aes(x = xnw, y = ynw, xend = xse, yend = yse),
          linewidth = 0.25,
          color = "grey60"
        ) +
        ggplot2::geom_segment(
          data = grid_dfd,
          ggplot2::aes(x = xne, y = yne, xend = xsw, yend = ysw),
          linewidth = 0.25,
          color = "grey60"
        ) +
        ggplot2::geom_segment(
          data = data.frame(
            x = c(0, -1),
            y = c(-1, 0),
            xend = c(0, 1),
            yend = c(1, 0)
          ),
          ggplot2::aes(x = x, y = y, xend = xend, yend = yend),
          linewidth = 0.25,
          color = "grey60"
        )
    }
  }

  p <- p +
    ggplot2::geom_segment(
      data = borders,
      ggplot2::aes(x = x, y = y, xend = xend, yend = yend),
      linewidth = 0.6,
      color = "black"
    ) +
    ggplot2::geom_text(
      data = axes_offset,
      ggplot2::aes(x = x, y = y, label = labels),
      size = 4,
      fontface = "bold"
    )

  pt_aes <- ggplot2::aes(x = x, y = y, size = size_var)
  if (!is.null(color_rank)) {
    pt_aes$colour <- rlang::sym("color_var")
  }

  p <- p +
    ggplot2::geom_point(
      data = dat,
      mapping = pt_aes,
      alpha = point_alpha
    )

  if (size_by != "equal") {
    size_label <- switch(
      size_by,
      abundance = "Relative abundance",
      log10_abundance = "log2(Rel. abundance)"
    )
    p <- p + ggplot2::labs(size = size_label)
  } else {
    p <- p + ggplot2::guides(size = "none")
  }

  if (!is.null(label_by)) {
    p <- p +
      ggplot2::geom_text(
        data = dat,
        ggplot2::aes(x = x, y = y, label = label_var),
        size = label_size,
        vjust = -0.8
      )
  }

  p
}
