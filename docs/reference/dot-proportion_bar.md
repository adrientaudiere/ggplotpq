# Proportion bar formatter for \[0, 1\] valued columns

Returns a
[`formattable::formatter()`](https://renkun-ken.github.io/formattable/reference/formatter.html)
that draws a proportional color bar whose fill width equals the value (0
= empty, 1 = full bar). Intended for columns like `prop_na_*` and
`genetic_diversity_*` whose values are in the \[0, 1\] range.

## Usage

``` r
.proportion_bar(color, big_mark = " ")
```

## Arguments

- color:

  Fill color of the bar.

- big_mark:

  Character used to group digits every 3 places.

## Value

A formattable formatter.
