# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working
with code in this repository — the **ggplotpq** sub-package of the
pqverse.

## Package Overview

**ggplotpq** is the ‘ggplot2’ visualisation layer of the pqverse. It
owns pure-ggplot2 helpers and single-phyloseq ggplot wrappers migrated
from ‘MiscMetabar’ and ‘comparpq’.

**Scope guard** (from `ROADMAP.md`):

- ✅ In scope: pure ggplot2 helpers (geoms, themes, scales, palettes),
  single-phyloseq ggplot wrappers (e.g. `wheat_plot`,
  `reorder_distinct_colors`), rendering of analyses done elsewhere
  (ternary plot for `lefser` output, `plotGamma` rendering for ALDEx2),
  and HTML-widget visualisations of workflow/phyloseq metadata
  (e.g. `track_wkflow_formattable`) — these widgets stand here because
  they are pure rendering of pqverse objects, not analysis methods.
- ❌ Out of scope: multi-phyloseq comparators (→ `comparpq`), ML /
  networks / DAGs (→ `netaipq`), data-structure utilities (→ `tidypq`),
  analysis methods (→ `netaipq`).

**Dependency rule.** New heavy deps for analysis live in `netaipq`. New
pure-ggplot2 deps (themes, scales, palettes) live here.

## Common Commands

``` bash
# Run code with loaded package
Rscript -e "devtools::load_all(); code"

# Run all tests
Rscript -e "devtools::test()"

# Run tests for files starting with {name}
Rscript -e "devtools::test(filter = '^{name}')"

# Generate documentation
Rscript -e "devtools::document()"

# Full package check
Rscript -e "devtools::check()"
```

## Coding Conventions

- Use base pipe (`|>`) not magrittr (`%>%`)
- Use `function() {}` for anonymous functions (not `\()` for
  multi-statement)
- Line length limit: 120 characters
- Tests for `R/{name}.R` go in `tests/testthat/test_{name}.R`
  (underscore)
- Every user-facing function must be exported with full roxygen2
  documentation (`@param`, `@return`, `@export`, `@examples`, `@author`)
- Wrap roxygen comments at 80 characters
- CRAN example constraints: primary example in `\donttest{}`, variants
  in `\dontrun{}`; cap per-sample work at 5 samples via
  `prune_samples(sample_names(data_fungi_mini)[1:5], data_fungi_mini)`
- Guard every Suggests-package call with
  [`requireNamespace()`](https://rdrr.io/r/base/ns-load.html) +
  [`cli::cli_abort()`](https://cli.r-lib.org/reference/cli_abort.html)
- Air format the package: `air format .` (then scope the diff — revert
  incidental reformats to unrelated files)

## First migrations (priority order, from ROADMAP.md)

1.  [`wheat_plot()`](https://adrientaudiere.github.io/ggplotpq/reference/wheat_plot.md)
    from `pqverse_pkg/MiscMetabar/R/wheat_plot.R` — \[High/easy\]
2.  [`reorder_distinct_colors()`](https://adrientaudiere.github.io/ggplotpq/reference/reorder_distinct_colors.md) +
    `ggplot_add.reorder_distinct_colors_spec()` from
    `pqverse_pkg/MiscMetabar/R/plot_functions.R:6926, 7065` —
    \[Medium/easy\]
3.  Non-`fill` variant of `plot_tax_pq()` for count-based bar charts —
    \[Medium/easy\]
4.  [`gg_bubbles_pq()`](https://adrientaudiere.github.io/ggplotpq/reference/gg_bubbles_pq.md)
    from `pqverse_pkg/comparpq/R/gg_bubbles_pq.R:130` —
    \[Medium/moderate\]

See the R Feature Batch skill (`/r-feature-batch`) for the per-feature
workflow.

## Cross-references

- Workspace CLAUDE.md: `pqverse/CLAUDE.md` (overall context)
- ROADMAP section:
  <https://github.com/adrientaudiere/pqverse/ROADMAP.md#ggplotpq>
- Sister packages: `pqverse_pkg/MiscMetabar/`, `pqverse_pkg/comparpq/`,
  `pqverse_pkg/netaipq/`, `pqverse_pkg/tidypq/`

## Agent skills

### Issue tracker

Issues and PRDs are tracked as GitHub issues via the `gh` CLI; external
PRs are not a triage surface. See `docs/agents/issue-tracker.md`.

### Triage labels

Uses the five canonical triage labels (`needs-triage`, `needs-info`,
`ready-for-agent`, `ready-for-human`, `wontfix`). See
`docs/agents/triage-labels.md`.

### Domain docs

Single-context: one `CONTEXT.md` + `docs/adr/` at the repo root. See
`docs/agents/domain.md`.
