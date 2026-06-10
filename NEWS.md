# ggplotpq (development version)

* `idest_colors()` returns a vector of colors from one of the IdEst palettes (continuous or discrete, with direction and override-order options), migrated from `taxinfo`.
* `idest_pal` is the named list of IdEst color palettes (`all_color_idest`, `ligth_color_idest`, `dark_color_idest`, `Picabia`, `Picasso`, `Levine2`, `Rattner`, `Sidhu`, `Hokusai2`, `Hokusai3`), migrated from `taxinfo`.
* `plot_sample_depth_pq()` draws a bar or density plot of per-sample sequencing depth, with optional log10 transform, color-by grouping, sort, and a threshold reference line; useful as a QA plot.
* `plot_tax_count_pq()` is a non-proportion variant of `MiscMetabar::plot_tax_pq()`: counts of a chosen taxonomic rank are stacked per sample without being normalised to percentages, useful for spike-in or biomass comparisons.
* `plot_taxa_heatmap_pq()` draws a heatmap of the `n_top` most abundant taxa across samples, with optional log10 transform and custom fill scale; aggregated by the chosen taxonomic rank.
* `reorder_distinct_colors()` reorders the discrete fill and color scales of a ggplot to maximise perceptual contrast between adjacent segments, with optional `alternate_lightness` and `colorblind` (deuteranopia) modes; migrated from `MiscMetabar` along with its `ggplot_add` S3 method.
* `scale_color_idest_c()`, `scale_fill_idest_c()`, `scale_color_idest_d()` and `scale_fill_idest_d()` are continuous and discrete ggplot2 scales built on top of the IdEst palettes, migrated from `taxinfo`.
* `scale_color_pq_discrete()` and `scale_fill_pq_discrete()` are thin wrappers around the discrete IdEst scales with a clean `palette` argument and a curated default of `Hokusai3`.
* `theme_idest()` is a minimalist ggplot2 theme with serif title, sans axis text, and mono axis titles (fonts, sizes, grid, axis lines, ticks and strip background are all configurable); migrated from `taxinfo`.
* `theme_pq_minimal()` is a pared-down minimalist theme that requires no specific fonts installed, intended as a sensible default for `ggplotpq` plots.
* `wheat_plot()` draws a "wheat plot" (stacked-dot) of a numeric distribution — hybrid between a histogram and a dot plot that keeps every observation visible; migrated from `MiscMetabar`.
