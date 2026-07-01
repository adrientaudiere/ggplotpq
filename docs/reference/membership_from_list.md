# Convert a named list of members into a binary membership data frame

[![lifecycle-experimental](https://img.shields.io/badge/lifecycle-experimental-orange)](https://adrientaudiere.github.io/MiscMetabar/articles/Rules.html#lifecycle)

Internal helper that turns a named list of character (or other) vectors
— each vector listing the members belonging to one set — into a
wide-format data frame with one row per unique member and one logical
column per set. This is the format expected by
[`ComplexUpset::upset()`](https://krassowski.github.io/complex-upset/reference/upset.html)
and similar venn/upset plotting tools, which cannot consume a list
directly.

Conceptually equivalent to
[`UpSetR::fromList()`](https://rdrr.io/pkg/UpSetR/man/fromList.html) but
kept inside the package to avoid a hard dependency on UpSetR and to
return logical columns (which both ComplexUpset and ggplot2 handle
natively).

## Usage

``` r
membership_from_list(x, keep_rownames = TRUE)
```

## Arguments

- x:

  (named list, required) Each element is a vector of members belonging
  to one set. The list names become the column names of the returned
  data frame. At least two sets are required.

- keep_rownames:

  (logical, default `TRUE`) If `TRUE`, the unique members are stored as
  the row names of the returned data frame.

## Value

A [data.frame](https://rdrr.io/r/base/data.frame.html) with one column
per set (named after the list elements) and one row per unique non-`NA`
member across all sets. Cell values are `TRUE`/`FALSE`. When
`keep_rownames = TRUE` the row names identify the members.

## Author

Adrien Taudière

## Examples

``` r
if (FALSE) { # \dontrun{
membership <- list(
  bact  = c("s1", "s2", "s3"),
  fungi = c("s1", "s3"),
  amf   = c("s2")
)
ggplotpq:::membership_from_list(membership)
#        bact fungi   amf
# s1    TRUE  TRUE FALSE
# s2    TRUE FALSE  TRUE
# s3    TRUE  TRUE FALSE
} # }
```
