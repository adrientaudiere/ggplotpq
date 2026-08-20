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
  abbrev_species = FALSE,
  label_size = NULL,
  grey_terms = c(NA_character_, "unassigned", "unknown"),
  label_orientation = c("auto", "option1", "option2", "option3", "tangential", "radial",
    "mixed", "adaptive"),
  truncate_labels = FALSE,
  dismiss_overlaps = TRUE,
  label_fallback = c("dot", "initials", "none", "legend"),
  fallback_symbol = "·",
  fallback_nchar = 3,
  leaf_label_padding = 0.08,
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

- abbrev_species:

  (logical, default `FALSE`) When `TRUE`, each name at the `"Species"`
  rank is prefixed with the initial of its parent genus, so a species
  epithet reads as an abbreviated binomial (e.g. `"muscaria"` under
  genus `"Amanita"` becomes `"A. muscaria"`). Applies to both the static
  and interactive plots. Placeholder names (`"unassigned"`) and names
  already carrying an initial are left untouched; if no `"Species"` rank
  is among `ranks`, a warning is issued and names are unchanged.

- label_size:

  (numeric, default `NULL`) A positive multiplier on the base label font
  size, applied to both the static and interactive plots. Its length
  selects the mode:

  - length `1` – a single multiplier for every label.

  - length `length(ranks)` – one multiplier per rank; a label at rank
    `i` uses `label_size[i]`.

  - length `ntaxa(physeq)` – one value per taxon, positional in
    `taxa_names()` order. Each leaf's multiplier is the mean of its
    constituent taxa's values, and each internal node's is the mean of
    all its descendant leaves' multipliers. `NULL` keeps the default
    sizing. Values must be finite and `> 0`.

- grey_terms:

  (character, default `c(NA, "unassigned", "unknown")`) Section names
  whose colour is overridden to grey, used to visually mute
  uninformative taxa. `NA` matches sections with a missing name. Pass
  `character(0)` to disable.

- label_orientation:

  (character, default `"auto"`) Static sunburst only. Controls how
  section labels are placed. The three documented modes are `"option1"`,
  `"option2"`, and `"option3"`; the older names are kept as aliases.

  - `"option3"` / `"auto"` (default): **internal** labels run **along
    their own ring band** (arc-following, never upside-down), centred;
    **leaf** labels are **radial**, a spoke reading straight outward
    from the centre, placed outside the coloured arc by
    `leaf_label_padding`, with crowded leaves thinned by
    `dismiss_overlaps`. `"radial"` is a further alias of this mode.

  - `"option1"` / `"tangential"`: **every** label (internal and leaf)
    runs along its arc, centred in the band. Long labels are shortened
    to fit with `truncate_labels`; a name still too wide for its arc is
    hidden (replaced by the `label_fallback` marker).

  - `"option2"` / `"mixed"`: **internal** labels are tangential
    (circular); **leaf** labels are radial, outside the rim like
    `"option3"`.

  - `"adaptive"`: every label tries the radial placement first and falls
    back to tangential only when radial does not fit the arc. In every
    mode, a label with nowhere to go gets the `label_fallback` marker;
    see `dismiss_overlaps` for thinning crowded radial labels and
    `leaf_label_padding` for how far outside the rim leaf labels sit.
    The interactive widget mirrors the default styling (internal
    arc-following, leaf radial), but does not expose these modes.

- truncate_labels:

  (logical, default `FALSE`) Applies to the static sunburst and the
  interactive widget. Controls whether labels may be abbreviated with a
  middle ellipsis. When `TRUE`, a label too long for its space is
  shortened so it still fits and stays visible (e.g. `"Strophariaceae"`
  becomes `"Stro...aceae"`). When `FALSE` (the default), labels are
  never abbreviated: a name is shown in full when it fits, and an
  arc-following name too long for its arc is hidden (its wedge gets the
  `label_fallback` marker) rather than truncated. Pair `FALSE` with
  `label_size` to shrink the text until full names fit.

- dismiss_overlaps:

  (logical, default `TRUE`) Static sunburst only. Radially-oriented
  labels are anchored at a single point and can visually crowd a
  neighbour when their wedges are angularly close, even though each
  individually "fits" its own wedge. When `TRUE`, such collisions are
  detected and the lower-value label of the pair is replaced by the
  `label_fallback` marker instead of being drawn overlapping. Has no
  effect on purely tangential labels, which are already confined to
  their own arc. Set to `FALSE` to restore the unfiltered placement.

- label_fallback:

  (character, default `"dot"`) Static sunburst only. What to draw
  instead of a label that has no room, or that `dismiss_overlaps`
  removed for overlapping a neighbour. `"dot"` draws the single glyph in
  `fallback_symbol`. `"initials"` draws the first `fallback_nchar`
  characters of the section name. `"none"` draws nothing. `"legend"`
  tries a unique `fallback_nchar`-letter code derived from the name
  first (disambiguated on collision), then the shortest unused number if
  even the code does not fit, then nothing; every assigned code/number
  is listed in an on-canvas legend (`"code -- name"`, bottom-left
  corner). With many small sections the legend can be long enough to
  extend past a typical device size – increase the plot height when
  using `label_fallback = "legend"` on high-diversity data. Leaf labels
  replaced by a marker keep a short leader line stub pointing to it
  whenever `leaf_label_padding` places leaf labels with a real gap past
  the rim.

- fallback_symbol:

  (character, default `"·"` i.e. a middle dot) Static sunburst only. The
  glyph drawn when `label_fallback = "dot"`; pass e.g. `"*"` or `"+"`
  for a different marker.

- fallback_nchar:

  (integer, default `3`) Static sunburst only. Number of leading
  characters of the section name shown when
  `label_fallback = "initials"`; length of the derived code when
  `label_fallback = "legend"`.

- leaf_label_padding:

  (numeric, default `0.08`) Static sunburst only. How far past a leaf
  wedge's outer border its radial label starts, in the same depth units
  as one ring. `0` places the label right at the border; negative values
  pull it back inside the wedge (recreating the pre-session "inside the
  rim" look); larger positive values push it further out and draw a
  connecting leader line. Ignored for tangential leaf labels (which stay
  centred inside their own coloured band) and for
  `label_orientation = "tangential"`, which never places leaf labels
  outside the rim.

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

  (numeric, default `NULL`) Widget dimensions in pixels. Both default to
  `NULL`, in which case the widget **fills its container**: the whole
  browser window for a standalone `.html`, the whole RStudio viewer
  pane, and the full viewport height elsewhere – the widget is meant to
  be viewed full-screen and the dense label layout needs the room. Pass
  explicit pixel values to fix the size instead. Ignored when
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
pq5 <- phyloseq::prune_samples(
  phyloseq::sample_names(data_fungi_mini)[1:5],
  data_fungi_mini
)

# Static sunburst (no extra dependency needed)
krona_like_pq(pq5, interactive = FALSE)
#> Warning: 33 taxa with zero weight were dropped before plotting.

# }

if (FALSE) { # \dontrun{
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

# Internal labels circular, leaf labels radial (outside the rim)
krona_like_pq(data_fungi_mini, interactive = FALSE, label_orientation = "mixed")

# Radial where it fits, circular otherwise, for every label
krona_like_pq(data_fungi_mini, interactive = FALSE, label_orientation = "adaptive")

# Show the first 3 letters instead of a dot for labels with no room
krona_like_pq(data_fungi_mini, interactive = FALSE, label_fallback = "initials")

# Unique code/number ladder with an on-canvas legend for labels with no room
krona_like_pq(
  data_fungi_mini,
  interactive = FALSE,
  label_orientation = "adaptive",
  label_fallback = "legend"
)

# Pull leaf labels back inside the rim instead of the outside-border default
krona_like_pq(data_fungi_mini, interactive = FALSE, leaf_label_padding = -0.5)

# Add a faint dotted motif on alternate sections (needs ggpattern)
if (requireNamespace("ggpattern", quietly = TRUE)) {
  krona_like_pq(data_fungi_mini, interactive = FALSE, pattern = TRUE)
}

# Colour by a numeric tax_table attribute (e.g. a confidence score column)
if (requireNamespace("scales", quietly = TRUE)) {
  pq_num <- data_fungi_mini
  phyloseq::tax_table(pq_num) <- cbind(
    phyloseq::tax_table(pq_num),
    conf_score = taxa_sums(pq_num)
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
