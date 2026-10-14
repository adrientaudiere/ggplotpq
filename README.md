
<!-- README.md is generated from README.Rmd. Please edit that file -->
<!-- devtools::build_readme() -->

# ggplotpq

A ‘ggplot2’-based visualisation layer for ‘phyloseq’ objects, part of
the ‘pqverse’ ecosystem.

`ggplotpq` is the **ggplot2 visualisation layer** of the pqverse. It
owns pure ggplot2 helpers (geoms, themes, scales, color/palette
management) and single-phyloseq ggplot wrappers that previously lived in
‘MiscMetabar’ or ‘comparpq’.

It is **not** for:

- cross-package multi-phyloseq comparators (those stay in ‘comparpq’),
- ML / networks / DAGs (those stay in ‘netaipq’),
- data-structure utilities (those stay in ‘tidypq’).

Genuinely new analysis methods (PLS-DA, aPCoA, Zeta-diversity, LefSe,
ALDEx2 sensitivity, etc.) belong in ‘netaipq’ — `ggplotpq` may still
render their plots, but the analysis wrapper itself does not live here.

## Parameter conventions: `fact`, `color_by`, and `facet_by`

Unlike `MiscMetabar`, where a single grouping argument sometimes drives
data aggregation, color, and faceting simultaneously, `ggplotpq`
strictly separates three orthogonal roles:

- **`fact`** (and **`bifactor`** for a secondary 2-level grouping): the
  primary `sample_data()` grouping or ordering variable that structures
  the data or geometry (e.g. groups in `community_sharing_plot()`,
  `ternary_pq()`, `plot_samples_dist2ref_pq()`, or the ordered step
  factor in `comet_pq()`).
- **`color_by`** (for plain data-frame columns, alongside
  `color_rank` for `tax_table()` ranks and `color_fac` for
  `sample_data()` variables): the variable mapped to the color/fill
  aesthetic, which may differ from `fact` (for instance, `comet_pq()`
  can step along `fact = "Height_ord"` while coloring each comet by
  `color_by = "Time_chr"`).
- **`facet_by`**: the `sample_data()` variable used to split the plot
  into small multiples (e.g. in `gg_bubbles_pq()`).

## Installation

`r{eval = FALSE} # install.packages("devtools") devtools::install_github("adrientaudiere/ggplotpq")`

## Status

Initial development version (0.0.0.9000). No exported functions yet —
migrations from ‘MiscMetabar’ and ‘comparpq’ land here first (see the
ROADMAP at <https://github.com/adrientaudiere/pqverse>, section
`ggplotpq`).

## License

MIT + file LICENSE
