# Compute text colors for diff values

Negative diffs (reductions) range from pink (small) to dark red (large).
Positive diffs (augmentations) range from light green (small) to dark
green (large). `NA` is gray.

## Usage

``` r
.diff_colors(diffs)
```

## Arguments

- diffs:

  Numeric vector of differences.

## Value

Character vector of hex color strings.
