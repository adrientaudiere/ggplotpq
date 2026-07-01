# Build ASCII tree labels from a parent mapping

Performs a depth-first traversal from each root and returns tree-drawn
labels plus the DFS ordering.

## Usage

``` r
.build_ascii_tree(names, parent)
```

## Arguments

- names:

  Character vector of node names (in original order).

- parent:

  Named character vector; `parent[name]` is the parent's name or `NA`
  for roots.

## Value

A list with elements `labels` (named character vector of tree-drawn
labels) and `order` (character vector of names in DFS order).
