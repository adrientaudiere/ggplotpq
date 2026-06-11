################################################################################
#' Circle-packed bubble plot of a phyloseq object using ggplot2
#'
#' @description
#'
#' <a href="https://adrientaudiere.github.io/MiscMetabar/articles/Rules.html#lifecycle">
#' <img src="https://img.shields.io/badge/lifecycle-experimental-orange" alt="lifecycle-experimental"></a>
#'
#' Creates a static circle-packed bubble plot of taxa abundances from a
#' phyloseq object using ggplot2. Circles can be packed in a circular layout
#' (tight, default) or a square layout. Optionally facets the plot by a sample
#' data variable, producing one bubble chart per level.
#'
#' When `diff_contour = TRUE` together with `facet_by`, all pairwise
#' comparisons between facet levels are shown side by side using
#' \pkg{patchwork}. For each pair (A vs B), taxa unique to A are highlighted
#' with A's colour and taxa unique to B with B's colour. Shared taxa receive
#' a transparent contour, making it easy to spot which taxa are exclusive to
#' each group.
#'
#' Migrated from `comparpq::gg_bubbles_pq()` (single-phyloseq variant —
#' list_phyloseq support was removed; use `comparpq::gg_bubbles_pq()` for
#' multi-object comparisons).
#'
#' @param physeq (required) A [phyloseq::phyloseq-class] object.
#' @param rank_label (character, default `"Taxa"`) Column in `@tax_table` to
#'   label circles. When `"Taxa"`, taxa names are used.
#' @param rank_color (character, default `"Family"`) Column in `@tax_table` to
#'   colour circles.
#' @param rank_contour (character, default `NULL`) Column in `@tax_table` to
#'   colour circle borders. When `NULL`, `border_color` is used uniformly.
#'   Ignored when `diff_contour = TRUE`.
#' @param layout (character, default `"circle"`) Packing layout: `"circle"`
#'   for tight circular packing, `"square"` for a square boundary.
#' @param facet_by (character, default `NULL`) Column name from `@sam_data` to
#'   facet the plot. One bubble chart is produced per level.
#' @param log1ptransform (logical, default `FALSE`) If `TRUE`, sequence counts
#'   are log1p-transformed before computing circle sizes.
#' @param min_nb_seq (integer, default `0`) Minimum sequence count; taxa below
#'   this threshold are dropped.
#' @param label_size (numeric, default `2`) Font size for labels inside circles.
#' @param label_color (character, default `"grey10"`) Colour for label text.
#' @param show_labels (logical, default `TRUE`) If `TRUE`, labels are shown
#'   inside circles that are large enough to fit text.
#' @param border_color (character, default `"white"`) Colour for circle borders
#'   (used when `rank_contour = NULL`).
#' @param border_width (numeric, default `0.5`) Width of circle borders.
#' @param alpha (numeric, default `0.8`) Transparency of circle fill.
#' @param npoints (integer, default `50`) Vertices per circle polygon. Higher
#'   values produce smoother circles.
#' @param ncol_facet (integer, default `NULL`) Number of columns for
#'   [ggplot2::facet_wrap()]. Ignored when `diff_contour = TRUE`.
#' @param return_dataframe (logical, default `FALSE`) If `TRUE`, return the
#'   data frame used for plotting instead of a ggplot object. Ignored when
#'   `diff_contour = TRUE`.
#' @param diff_contour (logical, default `FALSE`) If `TRUE` and `facet_by` is
#'   set, produces pairwise comparison panels for all facet-level pairs using
#'   \pkg{patchwork}. Taxa unique to each side are highlighted with a distinct
#'   contour colour; shared taxa receive a transparent contour.
#' @param diff_contour_colors (character vector, default
#'   `c("#E41A1C", "#377EB8", "#4DAF4A", "#984EA3")`) Border colours for taxa
#'   unique to each facet level. Recycled if shorter than the number of levels.
#' @param diff_border_width (numeric, default `1.5`) Border width in
#'   `diff_contour` mode.
#' @param show_title (logical, default `TRUE`) If `TRUE`, adds an informative
#'   title describing the fill, contour, size, and label mappings.
#'
#' @return A [ggplot2::ggplot] object, a patchwork object (when
#'   `diff_contour = TRUE`), or a data.frame (when `return_dataframe = TRUE`).
#' @author Adrien Taudière
#' @seealso [comparpq::gg_bubbles_pq()] for the multi-phyloseq variant.
#' @export
#'
#' @examples
#' \donttest{
#' data(data_fungi_mini, package = "MiscMetabar")
#' gg_bubbles_pq(physeq = data_fungi_mini, rank_color = "Class")
#'
#' gg_bubbles_pq(
#'   physeq = data_fungi_mini, rank_color = "Class",
#'   rank_contour = "Order"
#' )
#'
#' gg_bubbles_pq(
#'   physeq = data_fungi_mini, rank_color = "Class",
#'   layout = "square"
#' )
#' }
#'
#' \dontrun{
#' # Faceted by sample variable
#' data(data_fungi, package = "MiscMetabar")
#' gg_bubbles_pq(
#'   physeq = data_fungi, rank_color = "Order",
#'   facet_by = "Height", min_nb_seq = 100
#' )
#'
#' # Pairwise diff_contour
#' gg_bubbles_pq(
#'   physeq = data_fungi, rank_color = "Order",
#'   facet_by = "Height", min_nb_seq = 100,
#'   diff_contour = TRUE, show_labels = FALSE
#' )
#' }
gg_bubbles_pq <- function(
  physeq,
  rank_label = "Taxa",
  rank_color = "Family",
  rank_contour = NULL,
  layout = c("circle", "square"),
  facet_by = NULL,
  log1ptransform = FALSE,
  min_nb_seq = 0,
  label_size = 2,
  label_color = "grey10",
  show_labels = TRUE,
  border_color = "white",
  border_width = 0.5,
  alpha = 0.8,
  npoints = 50,
  ncol_facet = NULL,
  return_dataframe = FALSE,
  diff_contour = FALSE,
  diff_contour_colors = c("#E41A1C", "#377EB8", "#4DAF4A", "#984EA3"),
  diff_border_width = 1.5,
  show_title = TRUE
) {
  if (!requireNamespace("packcircles", quietly = TRUE)) {
    cli::cli_abort(
      "Package {.pkg packcircles} is required. Install it with {.code install.packages('packcircles')}."
    )
  }

  verify_pq(physeq)
  layout <- match.arg(layout, c("circle", "square"))

  if (!is.null(facet_by)) {
    if (!facet_by %in% colnames(physeq@sam_data)) {
      cli::cli_abort(
        "{.val {facet_by}} not found in {.code sample_data} of the phyloseq object."
      )
    }
  }

  if (diff_contour && is.null(facet_by)) {
    cli::cli_warn(
      "{.arg diff_contour} requires {.arg facet_by} to be set. Ignoring {.arg diff_contour}."
    )
    diff_contour <- FALSE
  }

  if (diff_contour && !is.null(rank_contour)) {
    cli::cli_inform(
      "{.arg rank_contour} is ignored when {.arg diff_contour = TRUE}."
    )
    rank_contour <- NULL
  }

  # ---- diff_contour: pairwise comparison panels ------------------------------
  if (diff_contour) {
    if (!requireNamespace("patchwork", quietly = TRUE)) {
      cli::cli_abort(
        "Package {.pkg patchwork} is required for {.arg diff_contour = TRUE}. Install it with {.code install.packages('patchwork')}."
      )
    }

    levels_var <- unique(as.character(physeq@sam_data[[facet_by]]))
    levels_var <- levels_var[!is.na(levels_var)]

    diff_colors <- stats::setNames(
      rep_len(diff_contour_colors, length(levels_var)),
      levels_var
    )

    all_color_vals <- sort(unique(na.omit(
      as.vector(physeq@tax_table[, rank_color])
    )))

    subset_to_level <- function(lvl) {
      sam_values <- as.character(physeq@sam_data[[facet_by]])
      idx <- !is.na(sam_values) & sam_values == lvl
      pq_sub <- prune_samples(idx, physeq)
      prune_taxa(taxa_sums(pq_sub) > 0, pq_sub)
    }

    make_diff_panel <- function(pq, unique_taxa, contour_color, title) {
      phyloseq::tax_table(pq) <- cbind(
        phyloseq::tax_table(pq),
        .cmpq_diff = ifelse(
          taxa_names(pq) %in% unique_taxa,
          "unique",
          "shared"
        )
      )
      p <- gg_bubbles_pq(
        physeq = pq,
        rank_label = rank_label,
        rank_color = rank_color,
        rank_contour = ".cmpq_diff",
        layout = layout,
        log1ptransform = log1ptransform,
        min_nb_seq = min_nb_seq,
        label_size = label_size,
        label_color = label_color,
        show_labels = show_labels,
        border_width = diff_border_width,
        alpha = alpha,
        npoints = npoints,
        show_title = FALSE
      ) +
        ggplot2::scale_color_manual(
          values = c("unique" = contour_color, "shared" = "transparent"),
          guide = "none"
        )
      if (length(all_color_vals) > 0) {
        p <- p + ggplot2::scale_fill_discrete(limits = all_color_vals)
      }
      p + ggplot2::ggtitle(title)
    }

    pair_indices <- utils::combn(seq_along(levels_var), 2, simplify = FALSE)

    pair_plots <- lapply(pair_indices, function(idx) {
      i <- idx[1]
      j <- idx[2]
      lvl_i <- levels_var[i]
      lvl_j <- levels_var[j]

      pq_i <- subset_to_level(lvl_i)
      pq_j <- subset_to_level(lvl_j)

      unique_i <- setdiff(taxa_names(pq_i), taxa_names(pq_j))
      unique_j <- setdiff(taxa_names(pq_j), taxa_names(pq_i))

      p_i <- make_diff_panel(pq_i, unique_i, diff_colors[lvl_i], lvl_i)
      p_j <- make_diff_panel(pq_j, unique_j, diff_colors[lvl_j], lvl_j)

      (p_i | p_j) +
        patchwork::plot_annotation(
          title = paste0(lvl_i, " vs ", lvl_j),
          theme = ggplot2::theme(
            plot.title = ggplot2::element_text(size = 11, face = "bold")
          )
        )
    })

    pw <- patchwork::wrap_plots(pair_plots, ncol = 1) +
      patchwork::plot_layout(guides = "collect")

    if (show_title) {
      size_desc <- if (log1ptransform) "log1p(nb sequences)" else "Nb sequences"
      label_desc <- if (rank_label == "Taxa") "taxa names" else rank_label
      title_parts <- paste0(
        "Fill: ",
        rank_color,
        " | Contour: unique taxa in each comparison",
        " | Size: ",
        size_desc,
        if (show_labels) paste0(" | Label: ", label_desc) else ""
      )
      pw <- pw +
        patchwork::plot_annotation(
          title = title_parts,
          theme = ggplot2::theme(
            plot.title = ggplot2::element_text(size = 10)
          )
        )
    }

    return(pw)
  }

  # ---- Build data frame (standard mode) -------------------------------------
  build_bubble_df <- function(pq, facet_label = NULL) {
    if (rank_label == "Taxa") {
      label <- taxa_names(pq)
    } else {
      label <- as.vector(pq@tax_table[, rank_label])
    }

    df <- data.frame(
      value = taxa_sums(pq),
      label = label,
      rank_value_color = as.vector(pq@tax_table[, rank_color]),
      stringsAsFactors = FALSE
    )

    if (!is.null(rank_contour)) {
      df$rank_value_contour <- as.vector(pq@tax_table[, rank_contour])
    }

    if (min_nb_seq > 0) {
      df <- df[df$value > min_nb_seq, ]
    }

    if (nrow(df) == 0) {
      return(NULL)
    }

    if (log1ptransform) {
      df$value <- log1p(df$value)
    }

    if (!is.null(facet_label)) {
      df$facet <- facet_label
    }

    df
  }

  if (is.null(facet_by)) {
    df_all <- build_bubble_df(physeq)
  } else {
    levels_var <- unique(as.character(physeq@sam_data[[facet_by]]))
    levels_var <- levels_var[!is.na(levels_var)]
    df_list <- lapply(levels_var, function(lvl) {
      sam_values <- as.character(physeq@sam_data[[facet_by]])
      idx <- !is.na(sam_values) & sam_values == lvl
      if (sum(idx) == 0) {
        return(NULL)
      }
      pq_sub <- prune_samples(idx, physeq)
      pq_sub <- prune_taxa(taxa_sums(pq_sub) > 0, pq_sub)
      if (ntaxa(pq_sub) == 0) {
        return(NULL)
      }
      build_bubble_df(pq_sub, facet_label = lvl)
    })
    df_all <- do.call(rbind, df_list)
  }

  if (is.null(df_all) || nrow(df_all) == 0) {
    cli::cli_abort(
      "No taxa remaining after filtering. Try lowering {.arg min_nb_seq}."
    )
  }

  if (return_dataframe) {
    return(df_all)
  }

  # ---- Compute circle layout ------------------------------------------------
  compute_layout <- function(df) {
    lay <- packcircles::circleProgressiveLayout(df$value, sizetype = "area")

    if (layout == "square") {
      cx <- mean(range(lay$x))
      cy <- mean(range(lay$y))
      dx <- lay$x - cx
      dy <- lay$y - cy
      r <- sqrt(dx^2 + dy^2)
      theta <- atan2(dy, dx)

      stretch <- ifelse(
        r > 0,
        1 / pmax(abs(cos(theta)), abs(sin(theta))),
        1
      )
      lay$x <- cx + dx * stretch
      lay$y <- cy + dy * stretch

      init_dat <- data.frame(x = lay$x, y = lay$y, radius = lay$radius)
      xrng <- range(lay$x - lay$radius, lay$x + lay$radius)
      yrng <- range(lay$y - lay$radius, lay$y + lay$radius)
      pad <- max(lay$radius) * 0.1
      lay <- packcircles::circleRepelLayout(
        init_dat,
        xlim = c(xrng[1] - pad, xrng[2] + pad),
        ylim = c(yrng[1] - pad, yrng[2] + pad),
        xysizecols = c(1, 2, 3),
        sizetype = "radius",
        maxiter = 1000,
        wrap = FALSE
      )$layout
    }

    vertices <- packcircles::circleLayoutVertices(lay, npoints = npoints)
    vertices$label <- rep(df$label, each = npoints + 1)
    vertices$rank_value_color <- rep(df$rank_value_color, each = npoints + 1)

    if (!is.null(rank_contour)) {
      vertices$rank_value_contour <- rep(
        df$rank_value_contour,
        each = npoints + 1
      )
    }

    center <- data.frame(
      x = lay$x,
      y = lay$y,
      radius = lay$radius,
      label = df$label
    )

    list(vertices = vertices, center = center)
  }

  if (is.null(facet_by)) {
    result <- compute_layout(df_all)
    verts <- result$vertices
    centers <- result$center
  } else {
    facet_levels <- unique(df_all$facet)
    verts_list <- list()
    centers_list <- list()
    for (fl in facet_levels) {
      df_sub <- df_all[df_all$facet == fl, ]
      result <- compute_layout(df_sub)
      result$vertices$facet <- fl
      result$center$facet <- fl
      verts_list[[fl]] <- result$vertices
      centers_list[[fl]] <- result$center
    }
    verts <- do.call(rbind, verts_list)
    centers <- do.call(rbind, centers_list)
  }

  # ---- Build plot ------------------------------------------------------------
  if (!is.null(rank_contour)) {
    p <- ggplot2::ggplot() +
      ggplot2::geom_polygon(
        data = verts,
        ggplot2::aes(
          x = x,
          y = y,
          group = id,
          fill = rank_value_color,
          color = rank_value_contour
        ),
        linewidth = border_width,
        alpha = alpha
      )
  } else {
    p <- ggplot2::ggplot() +
      ggplot2::geom_polygon(
        data = verts,
        ggplot2::aes(
          x = x,
          y = y,
          group = id,
          fill = rank_value_color
        ),
        color = border_color,
        linewidth = border_width,
        alpha = alpha
      )
  }

  p <- p +
    ggplot2::coord_fixed() +
    ggplot2::theme_void() +
    ggplot2::theme(legend.title = ggplot2::element_blank())

  if (show_labels) {
    max_radius <- max(centers$radius, na.rm = TRUE)
    label_threshold <- max_radius * 0.05
    centers_labeled <- centers[centers$radius > label_threshold, ]

    if (nrow(centers_labeled) > 0) {
      p <- p +
        ggplot2::geom_text(
          data = centers_labeled,
          ggplot2::aes(x = x, y = y, label = label),
          size = label_size,
          color = label_color
        )
    }
  }

  if (!is.null(facet_by)) {
    p <- p + ggplot2::facet_wrap(~facet, ncol = ncol_facet)
  }

  if (show_title) {
    size_desc <- if (log1ptransform) "log1p(nb sequences)" else "Nb sequences"
    contour_part <- if (!is.null(rank_contour)) {
      paste0(" | Contour: ", rank_contour)
    } else {
      ""
    }
    label_desc <- if (rank_label == "Taxa") "taxa names" else rank_label
    title_parts <- paste0(
      "Fill: ",
      rank_color,
      contour_part,
      " | Size: ",
      size_desc,
      if (show_labels) paste0(" | Label: ", label_desc) else ""
    )
    p <- p + ggplot2::ggtitle(title_parts)
  }

  p
}
################################################################################
