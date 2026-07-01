# Format diff values with directional arrows

Format diff values with directional arrows

## Usage

``` r
.diff_display(diffs, big_mark = " ")
```

## Arguments

- diffs:

  Numeric vector of differences.

- big_mark:

  Character used to group digits every 3 places.

## Value

Character vector: `"\u2193 N"` for reductions, `"\u2191 N"` for
augmentations, `"0"` for zero, `"\u2014"` for `NA`.
