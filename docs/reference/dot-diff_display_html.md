# Format diff values as HTML with separate arrow and value spans

Returns a list of
[`htmltools::HTML()`](https://rstudio.github.io/htmltools/reference/HTML.html)
objects so that nested `<span>` elements are rendered without escaping.
The arrow uses `arrow_size` and the value uses `value_size`, allowing
the arrow to be larger than the number.

## Usage

``` r
.diff_display_html(diffs, arrow_size = 1, value_size = 0.7, big_mark = " ")
```

## Arguments

- diffs:

  Numeric vector of differences.

- arrow_size:

  Font-size multiplier (`em`) for the arrow.

- value_size:

  Font-size multiplier (`em`) for the value text.

- big_mark:

  Character used to group digits every 3 places.

## Value

A list of
[`htmltools::HTML`](https://rstudio.github.io/htmltools/reference/HTML.html)
objects.
