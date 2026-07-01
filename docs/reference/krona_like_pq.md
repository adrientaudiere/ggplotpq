# Krona-like interactive taxonomy plot from a phyloseq object

[![lifecycle-experimental](https://img.shields.io/badge/lifecycle-experimental-orange)](https://adrientaudiere.github.io/MiscMetabar/articles/Rules.html#lifecycle)

Build a [Krona](https://github.com/marbl/Krona)-style interactive
taxonomy explorer from a
[phyloseq::phyloseq](https://rdrr.io/pkg/phyloseq/man/phyloseq-class.html)
object, **without** needing KronaTools installed. The interactive
version (default) is a D3.js `htmlwidget` that renders in the RStudio
viewer, in Shiny, and in R Markdown documents, and can be saved as a
self-contained `.html` file via `file_path`. A static ggplot2 version is
also available (`interactive = FALSE`) for publication-ready output.

Two layouts are supported:

- `"sunburst"` (default): concentric rings, one per taxonomic rank; the
  **angle** of each wedge is proportional to its value. This is the
  Krona pie. Click a wedge to zoom into that subtree (Krona's signature
  interaction).

- `"treemap"`: nested rectangles; the **area** of each rectangle is
  proportional to its value. Click a cell to zoom in.

Colours: each distinct value at the `color_by` rank receives its own
evenly spaced hue; its descendants then fan out across a hue band
centred on that hue (and grow slightly darker with depth), so nested
sections are clearly distinct colours rather than near-identical shades.
Set `pattern = TRUE` (static plots only) to overlay a faint grey dotted
motif on every other section, an extra channel to tell neighbours apart.

This function is a drop-in alternative to
[`MiscMetabar::krona()`](https://adrientaudiere.github.io/MiscMetabar/reference/krona.html),
which shells out to KronaTools and does not work on Windows.
`krona_like_pq()` works on all platforms because it bundles D3.js
locally.

## Usage

``` r
krona_like_pq(
  physeq,
  ranks = "All",
  weight_by = "sequences",
  add_unassigned_rank = 0,
  fill_unassigned = TRUE,
  layout = c("sunburst", "treemap"),
  interactive = TRUE,
  title = NULL,
  color_by = NULL,
  color_as_numeric = FALSE,
  pattern = FALSE,
  label_pct = c("none", "total", "parent"),
  show_center_count = TRUE,
  min_prop = NULL,
  collapse_single = FALSE,
  show_collapsed_path = FALSE,
  grey_terms = c(NA_character_, "unassigned", "unknown"),
  label_orientation = c("auto", "tangential", "radial"),
  show_search = FALSE,
  show_info_panel = FALSE,
  check_nestedness = TRUE,
  file_path = NULL,
  width = NULL,
  height = NULL
)
```

## Arguments

- physeq:

  (required) A
  [phyloseq::phyloseq](https://rdrr.io/pkg/phyloseq/man/phyloseq-class.html)
  object.

- ranks:

  (character or integer, default `"All"`) Taxonomic ranks to include.
  `"All"` (default) first tries to select only the seven standard ranks
  Kingdom, Phylum, Class, Order, Family, Genus, Species (in that order)
  if at least two of them are present — this avoids cluttering the chart
  with non-hierarchical annotation columns. Falls back to every column
  of `tax_table()` only when fewer than two classical ranks are found.
  An integer vector selects columns by position; a character vector
  selects columns by name (must all be present in
  [`phyloseq::rank_names()`](https://rdrr.io/pkg/phyloseq/man/rank_names.html)).

- weight_by:

  Weight applied to each taxon when computing wedge/rectangle sizes. One
  of:

  - `"sequences"` (default): the total read count per taxon
    ([`phyloseq::taxa_sums()`](https://rdrr.io/pkg/phyloseq/man/taxa_sums.html)).

  - `"asv"`: each taxon counts as 1 (distribution of ASVs/OTUs).

  - a function: applied to the per-taxon read counts (e.g. `log1p`,
    `sqrt`); negative/NA results are clamped to 0 with a warning.

  - a numeric vector of length
    [`phyloseq::ntaxa()`](https://rdrr.io/pkg/phyloseq/man/ntaxa-methods.html),
    aligned to
    [`phyloseq::taxa_names()`](https://rdrr.io/pkg/phyloseq/man/taxa_names-methods.html);
    negative/NA entries are clamped to 0.

- add_unassigned_rank:

  (integer, default 0) Controls how taxa with missing (`NA` or empty)
  taxonomic labels are handled. When `0` (default), `NA` values are
  relabelled `"unassigned"` at every rank and become a leaf at the rank
  where they first occur. When `> 0`, this relabelling only happens for
  the first `add_unassigned_rank` ranks (1-based, among the selected
  `ranks`); beyond that depth, taxa with `NA` at a rank are dropped.

- fill_unassigned:

  (logical, default `TRUE`) When `TRUE`, a section that terminates
  before the deepest rank – an `"unassigned"` taxon, or a `min_prop`
  `"n more"` aggregate – is extended with a chain of identical nested
  nodes down to the deepest selected rank, so its arc reaches the outer
  ring (e.g. a taxon unidentified from Class onwards still spans Class,
  Order, ..., Species; the whole circle is filled). The repeated
  segments render as a single borderless wedge carrying one label at the
  leaf. When `FALSE`, the section stops at the rank where it ended,
  leaving an inner wedge with no outer rings.

- layout:

  (character, default `"sunburst"`) One of `"sunburst"` (angle = value,
  Krona pie) or `"treemap"` (area = value).

- interactive:

  (logical, default `TRUE`) If `TRUE`, returns a D3.js `htmlwidget`
  (requires the **htmlwidgets** package). If `FALSE`, returns a static
  [ggplot2::ggplot](https://ggplot2.tidyverse.org/reference/ggplot.html)
  object with no extra dependency.

- title:

  (character, default `NULL`) Chart title. When `NULL`, defaults to
  `"Taxonomy"`.

- color_by:

  (character, default `NULL`) Name of the rank (must be in `ranks` for
  categorical coloring, or any `tax_table()` column when
  `color_as_numeric = TRUE`) whose values drive the colour assignment.
  When `NULL`, defaults to the first selected rank. Tip: when the first
  rank has only one value (e.g. a single phylum), set `color_by` to a
  more diverse rank to spread colour earlier.

- color_as_numeric:

  (logical, default `FALSE`) When `TRUE`, `color_by` may be any column
  of `tax_table()` (not just a rank in `ranks`). Its values are coerced
  to numeric and mapped to a continuous sequential gradient (viridis
  palette via **scales**). Numeric values are aggregated up the tree by
  weighted mean using `weight_by`, so internal sections receive a
  meaningful colour. Requires the **scales** package.

- pattern:

  (logical, default `FALSE`) Static plots only. When `TRUE`, overlays a
  faint grey dotted motif on every other section (alternating within
  each ring/level) so neighbouring sections of similar colour can still
  be told apart. Requires the **ggpattern** package. Ignored when
  `interactive = TRUE`.

- label_pct:

  (character, default `"none"`) Whether to append a proportion to each
  section label. One of `"none"` (no percentage), `"total"` (percentage
  of the overall total, following `weight_by`), or `"parent"`
  (percentage of the immediate parent section). Applies to static plots
  only.

- show_center_count:

  (logical, default `TRUE`) Static sunburst only. When `TRUE`, the total
  count (following `weight_by`) is shown in the centre hole as
  `n = <x>`, mirroring the original Krona display. Set to `FALSE` to
  suppress. For the interactive widget the centre count updates to the
  focused node when zooming; controlled by `show_center_count` as well.

- min_prop:

  (numeric, default `NULL`) When a positive number, siblings within the
  same parent whose proportion of that parent falls below this threshold
  are merged into a single `"<n> more"` aggregate section (crosshatch
  motif via **ggpattern**; plain grey if **ggpattern** is not
  available). `NULL` (default) disables merging. A typical value is
  `0.02` (2%). Aggregation recurs at every depth. When
  `fill_unassigned = TRUE` (the default) the aggregate also spans out to
  the leaf ring as one borderless wedge, so the whole circle stays
  filled.

- collapse_single:

  (logical, default `FALSE`) When `TRUE`, internal nodes that have
  exactly one child (and that child is not a leaf) are removed from the
  hierarchy; the grandchildren attach directly to the grandparent. This
  trims redundant intermediate ranks (e.g. a Family containing a single
  Genus) from both static and interactive views. Leaf nodes are never
  collapsed.

- show_collapsed_path:

  (logical, default `FALSE`) Static plots only, and only meaningful
  together with `collapse_single = TRUE`. When `TRUE`, each collapsed
  section is labelled with its full taxonomic path – the names of the
  skipped intermediate ranks joined by `" / "` and prefixed to the node
  name (e.g. `"Stereaceae / Stereum"`) – drawn in grey so the merged
  ranks remain visible.

- grey_terms:

  (character, default `c(NA, "unassigned", "unknown")`) Section names
  whose colour is overridden to grey, used to visually mute
  uninformative taxa. `NA` matches sections with a missing name. Pass
  `character(0)` to disable.

- label_orientation:

  (character, default `"auto"`) Static sunburst only. Controls how
  section labels are placed. `"auto"` (default): **internal** labels are
  **radial** (running along the radius), centred on their wedge and
  reading outward from the band inner edge, shortened to the radial room
  so they stay within ~their ring; **leaf** labels are placed **outside
  the rim**, radial and reading outward, each linked to its wedge by a
  short grey leader line. `"radial"` is the same but keeps the leaf
  labels inside the circle (the original Krona style). `"tangential"`
  runs every label along its arc, centred in the band, shown only when
  the name fits. In all modes text is normalised to never appear
  upside-down, merged fill chains are labelled once, and wedges with no
  room get a small dot.

- show_search:

  (logical, default `FALSE`) Interactive widget only. Deprecated: the
  search box is now always shown in the widget toolbar (for both
  layouts); this argument is retained for backward compatibility and has
  no effect.

- show_info_panel:

  (logical, default `FALSE`) Interactive widget only. When `TRUE`, a
  top-left info panel shows the hovered node's name, count, and
  percentages of parent and total, plus a list of sibling nodes.

- check_nestedness:

  (logical, default `TRUE`) When `TRUE`, the function checks that
  `tax_table()` is strictly nested (each value at rank `i+1` appears
  under only one parent at rank `i`) and issues a
  [`cli::cli_warn()`](https://cli.r-lib.org/reference/cli_abort.html)
  for any offending rank pair. Set to `FALSE` to suppress this check,
  e.g. when annotation columns are intentionally non-hierarchical.

- file_path:

  (character, default `NULL`) When `interactive = TRUE` and this is set,
  the widget is also saved as a self-contained `.html` file via
  [`htmlwidgets::saveWidget()`](https://rdrr.io/pkg/htmlwidgets/man/saveWidget.html).
  The widget is then returned invisibly. Ignored when
  `interactive = FALSE`.

- width, height:

  (numeric, default `NULL`) Widget dimensions in pixels. When `NULL`,
  the widget fills its container (RStudio viewer / Shiny). Ignored when
  `interactive = FALSE`.

## Value

When `interactive = TRUE`, an `htmlwidget` object (invisibly if
`file_path` is set). When `interactive = FALSE`, a
[ggplot2::ggplot](https://ggplot2.tidyverse.org/reference/ggplot.html)
object.

## See also

[`MiscMetabar::krona()`](https://adrientaudiere.github.io/MiscMetabar/reference/krona.html)
for the legacy KronaTools wrapper (does not work on Windows);
<https://github.com/marbl/Krona> for the original Krona project.

## Author

Adrien Taudière

## Examples

``` r
# \donttest{
data(data_fungi_mini, package = "MiscMetabar")
pq5 <- phyloseq::prune_samples(
  phyloseq::sample_names(data_fungi_mini)[1:5],
  data_fungi_mini
)

# Static sunburst (no extra dependency needed)
krona_like_pq(pq5, interactive = FALSE)
#> Warning: 33 taxa with zero weight were dropped before plotting.

# }

if (FALSE) { # \dontrun{
data(data_fungi_mini, package = "MiscMetabar")

# Static treemap
krona_like_pq(data_fungi_mini, layout = "treemap", interactive = FALSE)

# Show proportion of total on labels
krona_like_pq(data_fungi_mini, interactive = FALSE, label_pct = "total")

# Show proportion of parent on labels
krona_like_pq(data_fungi_mini, interactive = FALSE, label_pct = "parent")

# Merge low-abundance sections (< 2 percent of parent) into "n more"
krona_like_pq(data_fungi_mini, interactive = FALSE, min_prop = 0.02)

# Collapse single-child intermediate levels
krona_like_pq(data_fungi_mini, interactive = FALSE, collapse_single = TRUE)

# Add a faint dotted motif on alternate sections (needs ggpattern)
if (requireNamespace("ggpattern", quietly = TRUE)) {
  krona_like_pq(data_fungi_mini, interactive = FALSE, pattern = TRUE)
}

# Colour by a numeric tax_table attribute (e.g. a confidence score column)
if (requireNamespace("scales", quietly = TRUE)) {
  pq_num <- data_fungi_mini
  phyloseq::tax_table(pq_num) <- cbind(
    phyloseq::tax_table(pq_num),
    conf_score = as.character(stats::runif(phyloseq::ntaxa(pq_num)))
  )
  krona_like_pq(
    pq_num,
    interactive = FALSE,
    color_by = "conf_score",
    color_as_numeric = TRUE
  )
}

# Weight by ASV count instead of read count
krona_like_pq(data_fungi_mini, weight_by = "asv", interactive = FALSE)

# Subset of ranks and a custom title
krona_like_pq(
  data_fungi_mini,
  ranks = c("Phylum", "Class", "Order"),
  title = "Fungi -- top 3 ranks",
  interactive = FALSE
)

# Interactive D3 widget (requires the htmlwidgets package)
krona_like_pq(data_fungi_mini)

# Interactive widget with search box and info panel
krona_like_pq(
  data_fungi_mini,
  show_search = TRUE,
  show_info_panel = TRUE
)

# Save a self-contained HTML file to share
krona_like_pq(data_fungi_mini, file_path = "krona_fungi.html")

# Interactive treemap
krona_like_pq(data_fungi_mini, layout = "treemap")
} # }
```
