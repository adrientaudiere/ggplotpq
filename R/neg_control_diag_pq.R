# Negative-control diagnostic figure (migrated from tidypq)

################################################################################
#' Diagnose contamination from negative controls
#'
#' @description
#'
#' <a href="https://adrientaudiere.github.io/MiscMetabar/articles/Rules.html#lifecycle">
#' <img src="https://img.shields.io/badge/lifecycle-experimental-orange" alt="lifecycle-experimental"></a>
#'
#' Build a four-panel patchwork figure to inspect potential contamination
#' from negative-control samples (extraction blanks, PCR blanks, etc.).
#'
#' Panels:
#' * **A** boxplots of total reads and taxa richness per sample, split by
#'   negative-control status.
#' * **B** dumbbell of the top contaminant taxa (mean relative abundance in NC
#'   vs real samples), with mean read counts annotated above each point.
#' * **C** heatmap of the taxa detected in any negative control across all
#'   samples; absences are drawn in white, columns are faceted by NC status.
#' * **D** PCoA ordination (Bray-Curtis by default) with samples coloured by NC
#'   status.
#'
#' The patchwork subtitle reports the number of real and negative-control
#' samples. To *flag* or *classify* negative-control taxa programmatically, see
#' `tidypq::identify_contam_negcontrol_pq()`; this function is the visual
#' companion.
#'
#' @param physeq (required) A [phyloseq::phyloseq-class] object.
#' @param neg_control <data-masking> An expression evaluated on
#'   [phyloseq::sample_data()] that returns TRUE for negative-control samples
#'   (e.g. `is_control == TRUE`, `sample_type == "blank"`). Use `.` to refer to
#'   the phyloseq object.
#' @param top_n_heatmap (integer, default 30) Maximum number of taxa shown in
#'   the heatmap (panel C), ranked by total reads in negative controls.
#' @param top_n_contaminant (integer, default 20) Maximum number of taxa shown
#'   in the contaminant ranking (panel B).
#' @param log10_transform (logical, default TRUE) If TRUE, apply
#'   `log10(x + 1)` to the heatmap fill (panel C), the y-axis of panel A, and
#'   the ordination input (panel D).
#' @param ordination_method (character, default "PCoA") Method passed to
#'   [phyloseq::ordinate()].
#' @param ordination_dist (character, default "bray") Distance metric for the
#'   ordination.
#' @param palette (character) Length-2 named vector with entries `` `FALSE` ``
#'   (real samples) and `` `TRUE` `` (negative controls). Defaults to a
#'   blue/orange contrast.
#' @param title (character, default NULL) Optional title placed above the
#'   figure. The subtitle (real / NC sample counts) is added automatically.
#'
#' @return A [patchwork::patchwork] object with the four diagnostic panels.
#'
#' @author Adrien Taudière
#' @export
#'
#' @examples
#' \donttest{
#' data(data_fungi_mini, package = "MiscMetabar")
#' # A small subset, with the lowest-depth samples marked as mock controls
#' pq <- phyloseq::prune_samples(
#'   phyloseq::sample_names(data_fungi_mini)[1:15],
#'   data_fungi_mini
#' )
#' phyloseq::sample_data(pq)$is_control <-
#'   phyloseq::sample_sums(pq) < stats::median(phyloseq::sample_sums(pq))
#' neg_control_diag_pq(pq, is_control)
#' }
neg_control_diag_pq <- function(
  physeq,
  neg_control,
  top_n_heatmap = 30,
  top_n_contaminant = 20,
  log10_transform = TRUE,
  ordination_method = "PCoA",
  ordination_dist = "bray",
  palette = c(`FALSE` = "#4C72B0", `TRUE` = "#D55E00"),
  title = NULL
) {
  MiscMetabar::verify_pq(physeq)

  for (pkg in c("patchwork", "tidyr")) {
    if (!requireNamespace(pkg, quietly = TRUE)) {
      cli::cli_abort(
        "Package {.pkg {pkg}} is required for {.fn neg_control_diag_pq}."
      )
    }
  }

  sam_df <- as.data.frame(phyloseq::sample_data(physeq))
  data_env <- rlang::new_environment(as.list(sam_df))
  data_env[["."]] <- physeq
  mask <- rlang::new_data_mask(data_env)
  nc_vec <- rlang::eval_tidy(rlang::enquo(neg_control), data = mask)

  if (!is.logical(nc_vec)) {
    stop("`neg_control` must evaluate to a logical vector.")
  }
  nc_vec[is.na(nc_vec)] <- FALSE
  if (sum(nc_vec) == 0) {
    stop("No samples match the `neg_control` expression.")
  }

  # inject internal column so plot_ordination() can reference it
  sd <- as(phyloseq::sample_data(physeq), "data.frame")
  sd[[".is_neg"]] <- nc_vec
  rownames(sd) <- phyloseq::sample_names(physeq)
  phyloseq::sample_data(physeq) <- phyloseq::sample_data(sd)

  st_levels <- c("Real sample", "Negative control")
  st_colours <- stats::setNames(
    c(unname(palette[["FALSE"]]), unname(palette[["TRUE"]])),
    st_levels
  )
  fill_scale <- ggplot2::scale_fill_manual(
    name = "Sample type",
    values = st_colours,
    drop = FALSE
  )
  color_scale <- ggplot2::scale_colour_manual(
    name = "Sample type",
    values = st_colours,
    drop = FALSE
  )

  otu <- as(phyloseq::otu_table(physeq), "matrix")
  if (!phyloseq::taxa_are_rows(physeq)) {
    otu <- t(otu)
  }
  storage.mode(otu) <- "double"

  nc_idx <- which(nc_vec)
  real_idx <- which(!nc_vec)
  n_nc <- length(nc_idx)
  n_real <- length(real_idx)

  st_factor <- factor(
    ifelse(nc_vec, "Negative control", "Real sample"),
    levels = st_levels
  )

  # ---------------------------------------------------------------- Panel A
  samp_df <- data.frame(
    sample = phyloseq::sample_names(physeq),
    Reads = colSums(otu),
    Richness = colSums(otu > 0),
    sample_type = st_factor,
    stringsAsFactors = FALSE
  )
  samp_long <- tidyr::pivot_longer(
    samp_df,
    cols = c("Reads", "Richness"),
    names_to = "metric",
    values_to = "value"
  )
  if (log10_transform) {
    samp_long$value <- log10(samp_long$value + 1)
  }
  p_a <- ggplot2::ggplot(
    samp_long,
    ggplot2::aes(
      x = .data$sample_type,
      y = .data$value,
      fill = .data$sample_type
    )
  ) +
    ggplot2::geom_boxplot(outlier.shape = NA, alpha = 0.55, width = 0.5) +
    ggplot2::geom_jitter(
      ggplot2::aes(colour = .data$sample_type),
      width = 0.15,
      height = 0,
      alpha = 0.85,
      show.legend = FALSE
    ) +
    ggplot2::facet_wrap(~metric, scales = "free_y") +
    fill_scale +
    color_scale +
    ggplot2::labs(
      x = NULL,
      y = if (log10_transform) {
        "log10(value + 1)"
      } else {
        NULL
      },
      title = "A. Reads & taxa richness per sample"
    )

  # ----------------------------------------------- per-taxon NC summary
  nc_taxa_reads <- rowSums(otu[, nc_idx, drop = FALSE])
  taxa_in_nc <- nc_taxa_reads > 0

  fig_subtitle <- sprintf(
    "%d real sample%s | %d negative control%s",
    n_real,
    if (n_real == 1) {
      ""
    } else {
      "s"
    },
    n_nc,
    if (n_nc == 1) {
      ""
    } else {
      "s"
    }
  )

  if (n_real == 0) {
    warning("No real samples in input; only panel A will be drawn.")
    fig <- p_a +
      patchwork::plot_annotation(title = title, subtitle = fig_subtitle)
    return(fig)
  }

  if (!any(taxa_in_nc)) {
    warning(
      "No taxa detected in negative-control samples; ",
      "panels B and C will be empty."
    )
  }

  raw_nc <- otu[, nc_idx, drop = FALSE]
  raw_real <- otu[, real_idx, drop = FALSE]
  rel_nc <- sweep(raw_nc, 2, pmax(colSums(raw_nc), 1), "/")
  rel_real <- sweep(raw_real, 2, pmax(colSums(raw_real), 1), "/")

  contam <- data.frame(
    taxon = rownames(otu),
    mean_nc = rowMeans(rel_nc),
    mean_real = rowMeans(rel_real),
    mean_nc_count = rowMeans(raw_nc),
    mean_real_count = rowMeans(raw_real),
    total_nc = nc_taxa_reads,
    stringsAsFactors = FALSE
  )
  contam <- contam[taxa_in_nc, , drop = FALSE]

  # ---------------------------------------------------------------- Panel B
  fmt_count <- function(x) {
    formatC(signif(x, 3), format = "fg", flag = "#", drop0trailing = TRUE)
  }
  if (nrow(contam) > 0) {
    top_b <- contam[order(-contam$mean_nc), , drop = FALSE]
    top_b <- utils::head(top_b, top_n_contaminant)
    top_b$taxon <- factor(top_b$taxon, levels = rev(top_b$taxon))
    top_b$lab_nc <- fmt_count(top_b$mean_nc_count)
    top_b$lab_real <- fmt_count(top_b$mean_real_count)
    p_b <- ggplot2::ggplot(top_b, ggplot2::aes(y = .data$taxon)) +
      ggplot2::geom_segment(
        ggplot2::aes(
          x = .data$mean_real,
          xend = .data$mean_nc,
          yend = .data$taxon
        ),
        colour = "grey75"
      ) +
      ggplot2::geom_point(
        ggplot2::aes(x = .data$mean_real, colour = "Real sample"),
        size = 2.6
      ) +
      ggplot2::geom_point(
        ggplot2::aes(x = .data$mean_nc, colour = "Negative control"),
        size = 2.6
      ) +
      ggplot2::geom_text(
        ggplot2::aes(x = .data$mean_real, label = .data$lab_real),
        colour = unname(palette[["FALSE"]]),
        vjust = -0.9,
        size = 2.5
      ) +
      ggplot2::geom_text(
        ggplot2::aes(x = .data$mean_nc, label = .data$lab_nc),
        colour = unname(palette[["TRUE"]]),
        vjust = -0.9,
        size = 2.5
      ) +
      color_scale +
      ggplot2::labs(
        x = "Mean relative abundance",
        y = NULL,
        title = "B. Top NC-detected taxa (NC vs real)",
        caption = "Numbers above points = mean read count"
      )
  } else {
    p_b <- ggplot2::ggplot() +
      ggplot2::annotate(
        "text",
        x = 0,
        y = 0,
        label = "No taxon detected in negative controls."
      ) +
      ggplot2::theme_void() +
      ggplot2::labs(title = "B. Top NC-detected taxa")
  }

  # ---------------------------------------------------------------- Panel C
  if (nrow(contam) > 0) {
    top_c_taxa <- contam$taxon[order(-contam$total_nc)]
    top_c_taxa <- utils::head(top_c_taxa, top_n_heatmap)
    otu_sub <- otu[top_c_taxa, , drop = FALSE]
    heat_df <- as.data.frame(as.table(otu_sub), stringsAsFactors = FALSE)
    names(heat_df) <- c("taxon", "sample", "abund")
    heat_df$is_neg <- nc_vec[match(heat_df$sample, colnames(otu))]
    heat_df$sample_type <- factor(
      ifelse(heat_df$is_neg, "Negative control", "Real sample"),
      levels = st_levels
    )
    heat_df$fill_val <- if (log10_transform) {
      log10(heat_df$abund + 1)
    } else {
      heat_df$abund
    }
    # zero abundance (absence) -> NA -> white tile
    heat_df$fill_val[heat_df$abund == 0] <- NA_real_

    samp_ord <- samp_df[
      order(samp_df$sample_type != "Negative control", -samp_df$Reads),
      "sample"
    ]
    heat_df$sample <- factor(heat_df$sample, levels = samp_ord)
    heat_df$taxon <- factor(heat_df$taxon, levels = rev(top_c_taxa))

    fill_lab <- if (log10_transform) {
      "log10(count + 1)"
    } else {
      "count"
    }
    p_c <- ggplot2::ggplot(
      heat_df,
      ggplot2::aes(x = .data$sample, y = .data$taxon, fill = .data$fill_val)
    ) +
      ggplot2::geom_tile(colour = "grey90", linewidth = 0.05) +
      ggplot2::facet_grid(
        . ~ sample_type,
        scales = "free_x",
        space = "free_x"
      ) +
      ggplot2::scale_fill_viridis_c(
        name = fill_lab,
        option = "magma",
        direction = -1,
        na.value = "white"
      ) +
      ggplot2::labs(
        x = NULL,
        y = NULL,
        title = "C. Heatmap of NC-detected taxa across samples"
      ) +
      ggplot2::theme(
        axis.text.x = ggplot2::element_text(
          angle = 90,
          hjust = 1,
          vjust = 0.5,
          size = 6
        )
      )
  } else {
    p_c <- ggplot2::ggplot() +
      ggplot2::annotate(
        "text",
        x = 0,
        y = 0,
        label = "No taxon detected in negative controls."
      ) +
      ggplot2::theme_void() +
      ggplot2::labs(title = "C. Heatmap of NC-detected taxa")
  }

  # ---------------------------------------------------------------- Panel D
  ord_palette <- stats::setNames(
    c(unname(palette[["FALSE"]]), unname(palette[["TRUE"]])),
    c("FALSE", "TRUE")
  )
  physeq_ord <- if (log10_transform) {
    phyloseq::transform_sample_counts(physeq, function(x) {
      log10(x + 1)
    })
  } else {
    physeq
  }
  ord_subtitle <- if (log10_transform) {
    sprintf("%s distance on log10(count + 1)", ordination_dist)
  } else {
    sprintf("%s distance on raw counts", ordination_dist)
  }
  p_d <- tryCatch(
    {
      ord <- phyloseq::ordinate(
        physeq_ord,
        method = ordination_method,
        distance = ordination_dist
      )
      pp <- phyloseq::plot_ordination(physeq_ord, ord, color = ".is_neg")
      pp +
        ggplot2::geom_point(size = 3, alpha = 0.85) +
        ggplot2::scale_colour_manual(
          name = "Sample type",
          values = ord_palette,
          labels = c(`FALSE` = "Real sample", `TRUE` = "Negative control")
        ) +
        ggplot2::labs(
          title = sprintf("D. %s ordination", ordination_method),
          subtitle = ord_subtitle
        )
    },
    error = function(e) {
      ggplot2::ggplot() +
        ggplot2::annotate(
          "text",
          x = 0,
          y = 0,
          label = paste("Ordination failed:\n", conditionMessage(e))
        ) +
        ggplot2::theme_void() +
        ggplot2::labs(title = sprintf("D. %s ordination", ordination_method))
    }
  )

  # ---------------------------------------------------------------- compose
  top_row <- p_a + p_b + patchwork::plot_layout(widths = c(1, 1))
  fig <- (top_row / p_c / p_d) +
    patchwork::plot_layout(heights = c(1, 1.2, 1), guides = "collect") +
    patchwork::plot_annotation(title = title, subtitle = fig_subtitle) &
    ggplot2::theme(legend.position = "bottom")
  fig
}
