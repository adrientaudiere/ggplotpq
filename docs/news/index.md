# Changelog

## ggplotpq 0.1.0\* `plot_tax_count_pq()`, `ternary_pq()` and `ternary_biomarker_pq()` now validate their grouping column through `MiscMetabar::verify_fact_pq()`, raising a clear error listing the available `sample_data` columns when the requested `fact` column is absent; `plot_tax_count_pq()` previously accessed the column without checking it existed.

- [`track_wkflow_formattable()`](https://adrientaudiere.github.io/ggplotpq/reference/track_wkflow_formattable.md)
  gains `clean_parent` (default `TRUE`), which drops rows of `track_df`
  that have no entry in `parent` before building the tree instead of
  rendering them as unexplained roots; set to `FALSE` to keep the
  previous behavior.
- [`membership_from_list()`](https://adrientaudiere.github.io/ggplotpq/reference/membership_from_list.md)
  (internal) converts a named list of member vectors into a binary
  membership data frame (one row per unique member, one logical column
  per set), the wide format required by
  [`ComplexUpset::upset()`](https://krassowski.github.io/complex-upset/reference/upset.html)
  and similar venn/upset tools; avoids a hard dependency on
  [`UpSetR::fromList()`](https://rdrr.io/pkg/UpSetR/man/fromList.html).
- [`track_wkflow_formattable()`](https://adrientaudiere.github.io/ggplotpq/reference/track_wkflow_formattable.md)
  wraps
  [`MiscMetabar::track_wkflow()`](https://adrientaudiere.github.io/MiscMetabar/reference/track_wkflow.html)
  output into a formattable HTML widget with proportional color bars on
  count columns, an optional ASCII tree showing parent-child nesting
  between phyloseq objects (via an explicit `parent` mapping), and mini
  diff columns (`Δ_sequences`, `Δ_clusters`, `Δ_samples`,
  `Δ_occurrences`) with colored directional arrows scaled by magnitude.
  Extra-metrics columns from `track_wkflow(compute_* = TRUE)` are
  rendered by type: `nb_occurrences` and `n_samples_*` get proportional
  bars, `prop_na_*` and `genetic_diversity_*` get proportion bars (bar
  length = value in \[0, 1\]) with configurable colors (`na_bar_color`
  default firebrick, `div_bar_color` default mediumpurple), `seq_*`
  columns get a distinct gradient tile (`seq_tile_low`/`seq_tile_high`
  default white/seagreen), and remaining columns (`nb_rank`,
  `nb_sam_metadata`) keep the steelblue tile. Columns are reordered so
  `prop_na_*` appear after `seq_*` and `genetic_diversity_*`. Numeric
  columns are rounded for display via the `round` argument (default 2;
  set to `NULL` to disable).
- [`neg_control_diag_pq()`](https://adrientaudiere.github.io/ggplotpq/reference/neg_control_diag_pq.md)
  builds a four-panel patchwork figure diagnosing contamination from
  negative controls (per-sample reads/richness, NC-vs-real dumbbell,
  NC-taxa heatmap, ordination), migrated from `tidypq`; the programmatic
  counterpart is
  [`tidypq::identify_contam_negcontrol_pq()`](https://adrientaudiere.github.io/tidypq/reference/identify_contam_negcontrol_pq.html).
- [`krona_like_pq()`](https://adrientaudiere.github.io/ggplotpq/reference/krona_like_pq.md)
  static sunburst’s default (`"auto"`/`"radial"`) styling now reads
  correctly as intended: **internal** labels run tangentially,
  arc-following along their own ring band; **leaf** labels are radial, a
  spoke reading straight outward from the centre, placed outside the
  coloured arc with the offset controlled by a new `leaf_label_padding`
  argument (default `0.08`; `0` sits right at the border, negative
  values pull the label back inside the wedge, larger values push it
  further out with a leader line); also gains two more
  `label_orientation` values, `"mixed"` (internal labels
  circular/tangential, leaf labels radial) and `"adaptive"` (every label
  tries the radial placement first and falls back to circular/tangential
  only when radial does not fit the arc); a new `dismiss_overlaps`
  argument (default `TRUE`) detects radially-oriented labels that would
  visually crowd a denser neighbour and drops the lower-value one
  instead of drawing overlapping text, fixing the label pile-ups seen in
  dense regions; and a new `label_fallback` argument
  (`"dot"`/`"initials"`/`"none"`/`"legend"`, with `fallback_symbol` and
  `fallback_nchar` to customise it) controls what replaces a label that
  has no room or was dismissed for overlapping – `"legend"` assigns a
  unique short code (or, if that doesn’t fit either, a number) to each
  such label and lists it in an on-canvas legend, instead of the
  previous fixed dot; default label sizes are also slightly smaller to
  reduce crowding.
- [`krona_like_pq()`](https://adrientaudiere.github.io/ggplotpq/reference/krona_like_pq.md)
  interactive sunburst: fixed a bug where clicking a wedge to zoom left
  stray ancestor/sibling labels rendered in white at the plot centre –
  `zoomTo()`/`zoomTreemap()` now hide any path or label outside the
  zoomed focus’s own subtree instead of letting the zoom-rescale formula
  (only valid for descendants of the focus) collapse them onto the
  centre point; brought label placement to parity with the corrected
  static model (internal labels default to tangential/arc-following,
  leaf labels default to radial/spoke, each falling back to the other
  style and then a dot when it does not fit), with overlap dismissal
  ported from the static path and label classification recomputed on
  every zoom (a thin-wedge dot correctly becomes a full label once
  zooming reveals enough room, and vice versa) instead of being frozen
  at initial render; a wedge too narrow for any label in the full,
  un-zoomed tree is no longer permanently excluded from ever getting one
  – eligibility is now re-evaluated against the current zoom’s rescaled
  width, so zooming into a small clade correctly reveals labels for it;
  default font size is smaller (9px) and default widget height is taller
  (900px, up from 700px) since the widget is meant to be viewed
  full-screen.
- [`krona_like_pq()`](https://adrientaudiere.github.io/ggplotpq/reference/krona_like_pq.md)
  static sunburst now places leaf labels OUTSIDE the rim (radial,
  reading outward, readable in every quadrant) linked to their wedge by
  a short grey leader line, while internal labels run tangentially and
  are shown only when the name fits their arc, removing the previous
  label overlap; `fill_unassigned` now also extends `min_prop`
  `"n more"` aggregates out to the leaf ring, identical fill chains (and
  `collapse_single` runs of them) are drawn as one borderless wedge with
  a single label, and the interactive widget mirrors all of this
  (borderless chains, one label per chain) plus always shows the search
  box in its toolbar (including the treemap layout) and keeps the
  overall circle size when zooming.
- [`krona_like_pq()`](https://adrientaudiere.github.io/ggplotpq/reference/krona_like_pq.md)
  gains `fill_unassigned` (default `TRUE`) which extends an
  `"unassigned"` section with a chain of nested `"unassigned"` nodes
  down to the deepest selected rank, so its arc reaches the outer ring
  instead of leaving a hole, and `show_collapsed_path` (default `FALSE`)
  which, together with `collapse_single`, labels each collapsed section
  with the full taxonomic path of the skipped ranks (joined by `" / "`)
  drawn in grey.
- [`krona_like_pq()`](https://adrientaudiere.github.io/ggplotpq/reference/krona_like_pq.md)
  static sunburst labels now default to a hybrid layout
  (`label_orientation = "auto"`): internal labels are radial and centred
  on their ring band (drawn slightly smaller), while leaf labels are
  tangential and anchored at the centre of their arc;
  `label_orientation = "radial"` keeps every label radial and reading
  outward, and `label_orientation = "tangential"` runs every label along
  its arc.
- [`krona_like_pq()`](https://adrientaudiere.github.io/ggplotpq/reference/krona_like_pq.md)
  interactive widget no longer leaves the hover info panel stuck on its
  placeholder (the missing `miniPieSvg` helper that drew each ancestor’s
  proportion pie is now defined), the **Reset** button again returns the
  chart to the root view (the toolbar state carrying the button
  reference is now the one used for rendering), and clicking a wedge to
  zoom keeps the overall circle size by rescaling the focused subtree to
  fill the full radius.
- [`break_outlier_axis()`](https://adrientaudiere.github.io/ggplotpq/reference/break_outlier_axis.md)
  adds axis-break symbols (via **ggbreak**) at automatically detected
  outlier gaps; gaps are found where the ratio of consecutive sorted
  positive values exceeds `cutoff`; supports `"y"`, `"x"`, or `"both"`
  axes and both direct-call and `+`-operator usage; gains
  `space_proportional` (make the break-gap symbol proportional to the
  data gap size) and `expand_cluster` (add breathing room above the
  cluster maximum so boundary points are not clipped, default 5 %);
  internal gap boundaries are now offset by 0.5 % so that the
  cluster-maximum value stays in the lower panel and the first outlier
  value stays in the upper panel.
- [`zoom_outlier_axis()`](https://adrientaudiere.github.io/ggplotpq/reference/zoom_outlier_axis.md)
  zooms the plot into the main data cluster (largest group of
  consecutive values) using
  [`coord_cartesian()`](https://ggplot2.tidyverse.org/reference/coord_cartesian.html)
  and draws an arrow with the outlier value at the panel edge for each
  outlier point; works for `"y"`, `"x"`, or `"both"` axes and supports
  both direct-call and `+`-operator usage; gains `extra_margin`
  (automatically enlarges `plot.margin` on the outlier side so that
  `clip = "off"` arrows and labels are not cut by the device boundary,
  default 30 pt).
- [`krona_like_pq()`](https://adrientaudiere.github.io/ggplotpq/reference/krona_like_pq.md)
  default for `ranks = "All"` now restricts to the seven classical
  taxonomic ranks (Kingdom → Species) when at least two are present,
  avoiding non-hierarchical annotation columns from appearing in the
  chart; the interactive widget now shows a toolbar with a **Color by**
  dropdown (pre-computes one colour set per rank on the R side), **Max
  depth** and **Font size** selectors, a **Collapse** toggle (JS-side
  single-child collapse), and the search box is integrated into the same
  bar; the interactive sunburst now renders text labels on arcs wide
  enough to hold them; the widget default height is 700 px;
  `show_info_panel` is now correctly positioned (the container is set to
  `position:relative`); static sunburst label rotation is fixed to
  always stay in `[−90°, 90°]` using a single modulo normalisation;
  outer-ring (leaf) labels in the static sunburst are now rendered in
  dark ink since the outermost sections tend to be lighter;
  [`krona_like_pq()`](https://adrientaudiere.github.io/ggplotpq/reference/krona_like_pq.md)
  gains `check_nestedness` (default `TRUE`) to toggle the nestedness
  validation warning, `collapse_single` to remove uninformative
  single-child intermediate ranks, `color_as_numeric` to map any numeric
  `tax_table()` column to a viridis gradient, `label_pct` (`"none"` /
  `"total"` / `"parent"`) to append proportions to section labels,
  `min_prop` to merge low-abundance siblings into a crosshatch-marked
  `"n more"` aggregate, `show_center_count` (default `TRUE`) to display
  the total count in the sunburst centre (and the focused node count on
  zoom), `show_search` to add a live search box to the interactive
  widget, and `show_info_panel` to add a hover info panel showing count
  and percentages; also adds nestedness validation (`cli_warn` on
  non-strictly-nested `tax_table`), middle-ellipsis label truncation,
  and radially-oriented leaf-rank labels.
- [`krona_like_pq()`](https://adrientaudiere.github.io/ggplotpq/reference/krona_like_pq.md)
  interactive sunburst widget now draws labels with the same Krona
  radial-outward layout as the static plot (radial, reading outward,
  centred on each wedge, anchored at the band inner edge, never
  upside-down, shown by angular width), so the static and interactive
  views agree, and the labels stay correct after click-zoom; the static
  sunburst no longer clips outward leaf labels at the cardinal edges
  (uses `clip = "off"` plus a small plot margin); and a named
  `weight_by` numeric vector is now aligned to
  [`phyloseq::taxa_names()`](https://rdrr.io/pkg/phyloseq/man/taxa_names-methods.html)
  (aborting on a names mismatch) instead of being used in positional
  order.
- [`krona_like_pq()`](https://adrientaudiere.github.io/ggplotpq/reference/krona_like_pq.md)
  static sunburst labels now follow the original Krona layout: every
  label runs radially, reading outward from the centre, centred on its
  wedge and anchored at the inner edge of its ring band, with the anchor
  flipping across the vertical axis so both halves read outward and no
  text is upside-down; a label is shown whenever its wedge is angularly
  wide enough to fit the text height (independent of label length)
  rather than being hidden when too long, and only extremely long labels
  are shortened with a middle ellipsis; the new `label_orientation`
  argument (`"auto"`/`"radial"` or `"tangential"`) and the `grey_terms`
  argument are now documented.
- [`krona_like_pq()`](https://adrientaudiere.github.io/ggplotpq/reference/krona_like_pq.md)
  now gives sections clearly distinct colours (each `color_by` value
  gets its own hue and its descendants fan out across a hue band), draws
  readable radial labels on the static sunburst and leaf-only
  top-anchored labels on the static treemap, and gains a `pattern`
  argument to overlay a faint grey dotted motif on alternate sections
  (static plots, via `ggpattern`); the interactive widget now bundles
  D3.js correctly so it renders instead of showing only the title.

## ggplotpq 0.0.0

- [`krona_like_pq()`](https://adrientaudiere.github.io/ggplotpq/reference/krona_like_pq.md)
  builds Krona-style interactive (D3.js zoomable sunburst or treemap,
  via `htmlwidgets`) or static (pure ggplot2) taxonomy explorer from a
  `phyloseq` object, without requiring KronaTools; the interactive
  widget works on all platforms including Windows, and can be saved as a
  self-contained `.html` file.
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
- [`plot_tax_table_pq()`](https://adrientaudiere.github.io/ggplotpq/reference/plot_tax_table_pq.md)
  draws a compact distribution overview of `tax_table` columns (via
  [`tidypq::tax_table_to_df()`](https://adrientaudiere.github.io/tidypq/reference/tax_table_to_df.html))
  as one horizontal row per `ranks` column (defaulting to
  `phyloseq::rank_names(physeq)`); `na_equivalent` (default
  `c("-", "NA_NA")`) is first converted to true `NA`, and columns that
  end up entirely `NA` are discarded with a message by default
  (`discard_full_NA_column = TRUE`) or, when set to `FALSE`, drawn as a
  single dark grey `"NA"` row instead (including a numeric column that
  is entirely `NA`, which cannot be shown as a raincloud); other
  factor/character/logical columns become a single stacked bar (dark
  grey for `NA`, colored zones sized by proportion, categories below
  `threshold` shown in grey with a stripe motif via `ggpattern` and
  unlabeled, labels sized to fit via `ggfittext`); a column is treated
  as boolean-like as soon as one value reads `"true"` or `"false"`
  (case-insensitive), giving it a fixed color scheme shared across every
  such column (olive green for true, brick red for false, a blue
  gradient for any other value); the last such bar row in each figure
  carries a shared `"Proportion"` x-axis (ticks at 0, 0.25, 0.5, 0.75,
  1), with other bar rows’ axes hidden to avoid repeating it; numeric
  columns become a thin horizontal raincloud (violin + boxplot + jitter)
  always annotated with a dark, high-contrast `"n = XX"` badge in the
  top-right corner, extended to `"n = XX (YY% NA)"` when there is at
  least one `NA`; rows are stacked into one `patchwork` figure by
  default, or returned as a named list of one `ggplot` per column via
  `combine = FALSE`; when more than `max_combined_ranks` (default 25)
  columns are selected with `combine = TRUE`, `ranks` is instead split
  into consecutive chunks of at most `max_combined_ranks` columns (with
  a message), each combined into its own `patchwork` figure, so a named
  list of figures is returned instead of one overly dense plot.
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
