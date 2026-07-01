# Audit Report: ggplotpq v0.1.0.9000

Date: 2026-06-30
Type: external black-box audit (independent phyloseq fixtures, AGENTS.md template)

## Summary

- Exported functions: 28
- Tests run: 54
- OK: 38
- Warnings: 3
- Errors: 12 (1 genuine defect; the rest are correct input-validation or
  harness argument mismatches — see below)
- Skipped: 1 (`palette_earthtones` — downloads map tiles over the network)

## Errors — genuine

- [ ] `wheat_plot()` on an empty data.frame fails with a cryptic base-R message
      ("'from' doit être un nombre fini") instead of a clear validation error.
      Recommendation: validate `nrow(data) > 0` (and finite range of `xvar`)
      and emit a `cli::cli_abort()` message.

## Errors — correct validation (NOT defects, no action)

- `community_sharing_barplot()` with 1 modality → "Number of modalities must be
  between 2 and 4, not 1." (single-sample input rejected as designed)
- `ternary_pq()` / `ternary_biomarker_pq()` with a 2-level factor → "must have
  exactly 3 (or 3-4) levels" (ternary geometry requires 3 groups)

## Errors — audit harness artifacts (NOT defects)

- `idest_pal` is an exported **palette list**, not a function; the harness
  wrongly called `idest_pal()`. No bug.
- `comet_pq()` errored because the harness supplied `x/y/id` without `modality`
  (long format needs all four); the function's validation message is clear.
- `neg_control_diag_pq()` rejects a sample-name string for `neg_control`
  (wants a logical vector) — the logical-vector call passed.
- `reorder_distinct_colors()` needs a discrete **fill** scale; the harness gave
  a colour scale.
- `plot_tax_count_pq()` requires `fact`; the harness called it without one (the
  `fact = "Group"` call passed). Minor: the `fact = NULL` default is not usable
  — consider documenting `fact` as required or giving a clearer default error.

## Warnings

- [ ] `community_sharing_barplot()`, `krona_like_pq()`: `mbcsToSbcs` conversion
      warnings for em-dash (U+2014) and narrow no-break space (U+202F) when
      rendering on a non-UTF-8 PDF device. Cosmetic / environment-specific;
      consider ASCII fallbacks for separators in labels if portability matters.

## Skipped

- [ ] `palette_earthtones()`: requires network (map-tile download via
      `provider = "Esri.WorldImagery"`).

## Files

- audits/ggplotpq_script.R   (re-runnable)
- audits/ggplotpq_results.csv (raw results, 54 rows)
