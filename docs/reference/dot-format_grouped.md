# Format numbers with a digit-grouping mark

Format numbers with a digit-grouping mark

## Usage

``` r
.format_grouped(x, big_mark = " ")
```

## Arguments

- x:

  Numeric vector.

- big_mark:

  Character used to group digits every 3 places. `NULL` or `""` disables
  grouping.

## Value

Character vector of formatted strings. `NA` becomes `"\u2014"`.
