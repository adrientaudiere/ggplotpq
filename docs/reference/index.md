# Package index

## Migration from MiscMetabar

Functions migrated from MiscMetabar that operate on a single phyloseq
object.

- [`wheat_plot()`](https://adrientaudiere.github.io/ggplotpq/reference/wheat_plot.md)
  : Wheat plot of a numeric distribution
- [`reorder_distinct_colors()`](https://adrientaudiere.github.io/ggplotpq/reference/reorder_distinct_colors.md)
  : Reorder fill and color scales to maximize perceptual contrast
  between adjacent segments
- [`plot_tax_count_pq()`](https://adrientaudiere.github.io/ggplotpq/reference/plot_tax_count_pq.md)
  : Plot taxonomic counts (non-proportion) in function of a factor with
  stacked bars

## Migration from comparpq

Functions migrated from comparpq (single-phyloseq variant).

- [`gg_bubbles_pq()`](https://adrientaudiere.github.io/ggplotpq/reference/gg_bubbles_pq.md)
  : Circle-packed bubble plot of a phyloseq object using ggplot2

## Migration from taxinfo

Theme and palette helpers migrated from taxinfo.

- [`theme_idest()`](https://adrientaudiere.github.io/ggplotpq/reference/theme_idest.md)
  : ggplot theme for IdEst
- [`idest_pal`](https://adrientaudiere.github.io/ggplotpq/reference/idest_pal.md)
  : IdEst color palettes
- [`idest_colors()`](https://adrientaudiere.github.io/ggplotpq/reference/idest_colors.md)
  : IdEst colors for ggplot theme_idest
- [`scale_color_idest_c()`](https://adrientaudiere.github.io/ggplotpq/reference/scale_color_idest_c.md)
  : IdEst continuous color scales for ggplot2
- [`scale_fill_idest_c()`](https://adrientaudiere.github.io/ggplotpq/reference/scale_fill_idest_c.md)
  : IdEst continuous fill scales for ggplot2
- [`scale_color_idest_d()`](https://adrientaudiere.github.io/ggplotpq/reference/scale_color_idest_d.md)
  : IdEst discrete color scales for ggplot2
- [`scale_fill_idest_d()`](https://adrientaudiere.github.io/ggplotpq/reference/scale_fill_idest_d.md)
  : IdEst discrete fill scales for ggplot2

## New visualisation functions

Pure-ggplot2 helpers for phyloseq objects (geoms, themes, scales,
palettes).

- [`comet_pq()`](https://adrientaudiere.github.io/ggplotpq/reference/comet_pq.md)
  : Comet plot for paired or multi-step measurements from a phyloseq
  object

- [`community_sharing_plot()`](https://adrientaudiere.github.io/ggplotpq/reference/community_sharing_plot.md)
  : Community sharing plot: modalities as pie nodes with multi-metric
  links

- [`community_sharing_barplot()`](https://adrientaudiere.github.io/ggplotpq/reference/community_sharing_barplot.md)
  :

  Companion bar chart for
  [`community_sharing_plot()`](https://adrientaudiere.github.io/ggplotpq/reference/community_sharing_plot.md)

- [`make_sharing_metric()`](https://adrientaudiere.github.io/ggplotpq/reference/make_sharing_metric.md)
  :

  Build a single metric definition for
  [`community_sharing_plot()`](https://adrientaudiere.github.io/ggplotpq/reference/community_sharing_plot.md)

- [`default_sharing_metrics()`](https://adrientaudiere.github.io/ggplotpq/reference/default_sharing_metrics.md)
  :

  Default metrics for
  [`community_sharing_plot()`](https://adrientaudiere.github.io/ggplotpq/reference/community_sharing_plot.md)

- [`palette_earthtones()`](https://adrientaudiere.github.io/ggplotpq/reference/palette_earthtones.md)
  : Derive a colour palette from a geographic location

- [`plot_sample_depth_pq()`](https://adrientaudiere.github.io/ggplotpq/reference/plot_sample_depth_pq.md)
  : Plot per-sample read depth (number of sequences)

- [`plot_taxa_heatmap_pq()`](https://adrientaudiere.github.io/ggplotpq/reference/plot_taxa_heatmap_pq.md)
  : Heatmap of the top-N most abundant taxa across samples

- [`scale_color_pq_discrete()`](https://adrientaudiere.github.io/ggplotpq/reference/scale_color_pq_discrete.md)
  : ggplot2 discrete colour scale using the IdEst palette family

- [`scale_fill_pq_discrete()`](https://adrientaudiere.github.io/ggplotpq/reference/scale_fill_pq_discrete.md)
  : ggplot2 discrete fill scale using the IdEst palette family

- [`ternary_biomarker_pq()`](https://adrientaudiere.github.io/ggplotpq/reference/ternary_biomarker_pq.md)
  : Ternary plot of biomarker taxa across three sample groups

- [`ternary_pq()`](https://adrientaudiere.github.io/ggplotpq/reference/ternary_pq.md)
  : Ternary and diamond plots for 3-or-4-group taxon compositions

- [`theme_pq_minimal()`](https://adrientaudiere.github.io/ggplotpq/reference/theme_pq_minimal.md)
  : A pared-down minimalist ggplot2 theme for ggplotpq

## New single-phyloseq analysis wrappers

Analysis wrappers that ship a ggplot (the analysis lives here, the plot
is the deliverable).
