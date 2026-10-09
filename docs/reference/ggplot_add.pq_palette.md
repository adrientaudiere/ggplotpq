# Add a pq_palette to a ggplot with `+`

Applies the palette to whichever of `fill` and `colour` the plot maps,
as a single
[`ggplot2::scale_discrete_manual()`](https://ggplot2.tidyverse.org/reference/scale_manual.html)
call. `drop = FALSE` and `limits = force` keep the legend identical
across figures that show different subsets of the levels.

## Usage

``` r
# S3 method for class 'pq_palette'
ggplot_add(object, plot, ...)
```

## Arguments

- object:

  (pq_palette, required) The palette being added.

- plot:

  (ggplot, required) The plot it is added to.

- ...:

  Ignored.

## Value

A ggplot object.

## Author

Adrien Taudière
