# Changelog

## ggplotpq (development version)

- Add a “Get started with ggplotpq” vignette and a pkgdown website
  skeleton.
- [`comet_pq()`](https://adrientaudiere.github.io/ggplotpq/reference/comet_pq.md)
  draws a comet / tapered-line plot for paired continuous measurements:
  a linewidth-tapered segment (via
  [`ggforce::geom_link()`](https://ggforce.data-imaginist.com/reference/geom_link.html))
  connects the start and end value for each unit, with optional colour,
  tip-point, and text labels; accepts a data frame or a phyloseq object.
- [`community_sharing_barplot()`](https://adrientaudiere.github.io/ggplotpq/reference/community_sharing_barplot.md)
  displays the same pairwise community-similarity metrics as
  [`community_sharing_plot()`](https://adrientaudiere.github.io/ggplotpq/reference/community_sharing_plot.md)
  as bars, with one panel per metric and a free y-axis so each metric is
  compared across pairs on its own (incomparable) scale.
- [`community_sharing_plot()`](https://adrientaudiere.github.io/ggplotpq/reference/community_sharing_plot.md)
  draws the modalities of a grouping factor (2–4) as pie-chart nodes on
  a polygon, connected by one curved link per community-similarity
  metric (linewidth scaled to similarity), with an optional
  label-permutation significance test; metrics are pluggable via
  [`make_sharing_metric()`](https://adrientaudiere.github.io/ggplotpq/reference/make_sharing_metric.md)
  and
  [`default_sharing_metrics()`](https://adrientaudiere.github.io/ggplotpq/reference/default_sharing_metrics.md).
- [`default_sharing_metrics()`](https://adrientaudiere.github.io/ggplotpq/reference/default_sharing_metrics.md)
  returns the four built-in sharing metrics (shared species, Bray-Curtis
  similarity, Jaccard similarity, proportion of shared genera) used by
  [`community_sharing_plot()`](https://adrientaudiere.github.io/ggplotpq/reference/community_sharing_plot.md).
- [`gg_bubbles_pq()`](https://adrientaudiere.github.io/ggplotpq/reference/gg_bubbles_pq.md)
  produces a circle-packed bubble plot of taxa abundances (circle area ∝
  sequence count); supports circular and square layouts, optional
  faceting by sample variable, taxon labelling, contour colour by
  taxonomic rank, and pairwise `diff_contour` comparison panels;
  migrated from `comparpq` (single-phyloseq variant only — list_phyloseq
  support remains in
  [`comparpq::gg_bubbles_pq()`](https://adrientaudiere.github.io/comparpq/reference/gg_bubbles_pq.html)).
- [`idest_colors()`](https://adrientaudiere.github.io/ggplotpq/reference/idest_colors.md)
  returns a vector of colors from one of the IdEst palettes (continuous
  or discrete, with direction and override-order options), migrated from
  `taxinfo`.
- `idest_pal` is the named list of IdEst color palettes
  (`all_color_idest`, `ligth_color_idest`, `dark_color_idest`,
  `Picabia`, `Picasso`, `Levine2`, `Rattner`, `Sidhu`, `Hokusai2`,
  `Hokusai3`), migrated from `taxinfo`.
- [`make_sharing_metric()`](https://adrientaudiere.github.io/ggplotpq/reference/make_sharing_metric.md)
  builds a custom community-similarity metric definition (label, colour,
  function, format, and optional prep step and bounds) for use with
  [`community_sharing_plot()`](https://adrientaudiere.github.io/ggplotpq/reference/community_sharing_plot.md)
  and
  [`community_sharing_barplot()`](https://adrientaudiere.github.io/ggplotpq/reference/community_sharing_barplot.md).
- [`palette_earthtones()`](https://adrientaudiere.github.io/ggplotpq/reference/palette_earthtones.md)
  derives a colour palette from a geographic location
  (latitude/longitude) by downloading satellite tiles via `maptiles` and
  clustering pixel RGB values with k-means; works around the
  latitude-invariance bug in upstream `earthtones` ≤ 0.2.0 by computing
  the bounding box in EPSG:3857.
- [`plot_sample_depth_pq()`](https://adrientaudiere.github.io/ggplotpq/reference/plot_sample_depth_pq.md)
  draws a bar or density plot of per-sample sequencing depth, with
  optional log10 transform, color-by grouping, sort, and a threshold
  reference line; useful as a QA plot.
- [`plot_tax_count_pq()`](https://adrientaudiere.github.io/ggplotpq/reference/plot_tax_count_pq.md)
  is a non-proportion variant of
  [`MiscMetabar::plot_tax_pq()`](https://adrientaudiere.github.io/MiscMetabar/reference/plot_tax_pq.html):
  counts of a chosen taxonomic rank are stacked per sample without being
  normalised to percentages, useful for spike-in or biomass comparisons.
- [`plot_taxa_heatmap_pq()`](https://adrientaudiere.github.io/ggplotpq/reference/plot_taxa_heatmap_pq.md)
  draws a heatmap of the `n_top` most abundant taxa across samples, with
  optional log10 transform and custom fill scale; aggregated by the
  chosen taxonomic rank.
- [`reorder_distinct_colors()`](https://adrientaudiere.github.io/ggplotpq/reference/reorder_distinct_colors.md)
  reorders the discrete fill and color scales of a ggplot to maximise
  perceptual contrast between adjacent segments, with optional
  `alternate_lightness` and `colorblind` (deuteranopia) modes; migrated
  from `MiscMetabar` along with its `ggplot_add` S3 method.
- [`scale_color_idest_c()`](https://adrientaudiere.github.io/ggplotpq/reference/scale_color_idest_c.md),
  [`scale_fill_idest_c()`](https://adrientaudiere.github.io/ggplotpq/reference/scale_fill_idest_c.md),
  [`scale_color_idest_d()`](https://adrientaudiere.github.io/ggplotpq/reference/scale_color_idest_d.md)
  and
  [`scale_fill_idest_d()`](https://adrientaudiere.github.io/ggplotpq/reference/scale_fill_idest_d.md)
  are continuous and discrete ggplot2 scales built on top of the IdEst
  palettes, migrated from `taxinfo`.
- [`scale_color_pq_discrete()`](https://adrientaudiere.github.io/ggplotpq/reference/scale_color_pq_discrete.md)
  is a thin wrapper around the discrete IdEst scales with a clean
  `palette` argument and a curated default of `Hokusai3`.
- [`ternary_biomarker_pq()`](https://adrientaudiere.github.io/ggplotpq/reference/ternary_biomarker_pq.md)
  renders biomarker (or all) taxa on a three-group ternary diagram via
  `ggtern`, sizing points by total abundance and colouring them by the
  group in which each taxon is most abundant; the biomarker detection
  itself (e.g. a LefSe analysis) is performed elsewhere and its taxa
  names are passed in.
- [`ternary_pq()`](https://adrientaudiere.github.io/ggplotpq/reference/ternary_pq.md)
  produces a ternary triangle plot (3 groups) or diamond plot (4 groups)
  in which each taxon is positioned according to its mean relative
  abundance across groups; uses standard de Finetti coordinates
  (Wikipedia: Ternary plot) implemented fresh in ggplot2 without any
  external dependency; supports group-level labels, optional grid,
  colour-by taxonomic rank, and three size mappings (`abundance`,
  `log2_abundance`, `equal`). Samples with `NA` group values are
  automatically dropped.
- [`theme_idest()`](https://adrientaudiere.github.io/ggplotpq/reference/theme_idest.md)
  is a minimalist ggplot2 theme with serif title, sans axis text, and
  mono axis titles (fonts, sizes, grid, axis lines, ticks and strip
  background are all configurable); migrated from `taxinfo`. Requested
  font families that are not installed fall back to the graphics-device
  default font instead of raising `invalid font type` when the plot is
  printed.
- [`wheat_plot()`](https://adrientaudiere.github.io/ggplotpq/reference/wheat_plot.md)
  draws a “wheat plot” (stacked-dot) of a numeric distribution — hybrid
  between a histogram and a dot plot that keeps every observation
  visible; migrated from `MiscMetabar`.
