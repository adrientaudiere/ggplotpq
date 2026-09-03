data(data_fungi_mini, package = "MiscMetabar")
ps_mini <- data_fungi_mini

quiet <- function(expr) {
  suppressWarnings(suppressMessages(expr))
}

pal8 <- quiet(palette_tax_pq(ps_mini, "Order", n = 8))
pal_nested <- quiet(palette_tax_pq(ps_mini, "Order", n = 6, nested = "Class"))

layer_data <- function(p) {
  ggplot_build(p)$data[[1]]
}

# ---- geoms -------------------------------------------------------------------

test_that("show_palette_pq draws one tile per entry, in palette colours", {
  p <- show_palette_pq(pal8, geom = "tile")
  expect_s3_class(p, "ggplot")
  d <- layer_data(p)
  expect_identical(nrow(d), length(pal8))
  expect_setequal(d$fill, unname(pal8))
})

test_that("show_palette_pq draws points at the requested size", {
  p <- show_palette_pq(pal8, geom = "point", point_size = 2, n_preview = 1)
  d <- layer_data(p)
  expect_identical(nrow(d), length(pal8))
  expect_setequal(d$colour, unname(pal8))
  expect_true(all(d$size == 2))
})

test_that("n_preview repeats each entry as a deterministic cloud", {
  p <- show_palette_pq(pal8, geom = "point", n_preview = 6)
  d <- layer_data(p)
  expect_identical(nrow(d), 6L * length(pal8))
  expect_gt(length(unique(d$x)), 1)
  # Deterministic: no RNG, so two builds agree exactly.
  expect_identical(
    d,
    layer_data(show_palette_pq(pal8, geom = "point", n_preview = 6))
  )
})

test_that("n_preview = 1 keeps a single column of points", {
  d <- layer_data(show_palette_pq(pal8, geom = "point", n_preview = 1))
  expect_length(unique(d$x), 1)
})

test_that("the default shows both views side by side", {
  p <- show_palette_pq(pal8)
  expect_s3_class(p, "patchwork")
  # wrap_plots() keeps the earlier panels in $patches$plots and makes the last
  # one the object itself, so there is one entry for a two-panel figure.
  expect_length(p$patches$plots, 1)

  tiles <- p$patches$plots[[1]]
  expect_s3_class(tiles$layers[[1]]$geom, "GeomTile")
  expect_identical(nrow(tiles$data), length(pal8))

  expect_s3_class(p$layers[[1]]$geom, "GeomPoint")
  expect_identical(nrow(p$data), 25L * length(pal8))
})

test_that("the default point view drops its labels, the swatch view keeps them", {
  p <- show_palette_pq(pal8)
  panels <- c(list(p$patches$plots[[1]]), list(p))
  expect_s3_class(panels[[1]]$theme$axis.text.y, "element_text")
  expect_s3_class(panels[[2]]$theme$axis.text.y, "element_blank")
})

test_that("the first palette entry sits at the top of the panel", {
  d <- layer_data(show_palette_pq(pal8, geom = "tile"))
  top <- d$fill[which.max(d$y)]
  expect_identical(top, unname(pal8[1]))
})

# ---- labels and facets -------------------------------------------------------

test_that("label = FALSE hides the level names", {
  shown <- show_palette_pq(pal8, geom = "tile", label = TRUE)
  hidden <- show_palette_pq(pal8, geom = "tile", label = FALSE)
  expect_s3_class(shown$theme$axis.text.y, "element_text")
  expect_s3_class(hidden$theme$axis.text.y, "element_blank")
})

test_that("a nested palette is faceted by parent", {
  p <- show_palette_pq(pal_nested, geom = "tile")
  expect_s3_class(p$facet, "FacetWrap")
  facets <- ggplot_build(p)$layout$layout$facet
  parents <- attr(pal_nested, "pq_leaf_parents")
  expect_true(all(unique(parents) %in% facets))
  expect_true("reserved" %in% facets)
})

test_that("a flat palette is not faceted", {
  expect_s3_class(show_palette_pq(pal8)$facet, "FacetNull")
})

test_that("a palette read back from a column is drawn unfaceted", {
  ps <- quiet(palette_tax_pq(
    ps_mini,
    "Order",
    n = 6,
    nested = "Class",
    add_to_phyloseq = TRUE
  ))
  reread <- quiet(palette_tax_pq(ps, "Order"))
  expect_null(attr(reread, "pq_leaf_parents"))
  expect_s3_class(show_palette_pq(reread, geom = "tile")$facet, "FacetNull")
})

# ---- inventory mode ----------------------------------------------------------

test_that("a phyloseq object lists every palette it carries", {
  ps <- quiet(palette_tax_pq(ps_mini, "Order", n = 6, add_to_phyloseq = TRUE))
  phyloseq::sample_data(ps)$grp <- rep(
    c("a", "b"),
    length.out = phyloseq::nsamples(ps)
  )
  ps <- quiet(palette_sam_pq(ps, "grp", add_to_phyloseq = TRUE))

  p <- show_palette_pq(ps, geom = "tile")
  facets <- ggplot_build(p)$layout$layout$facet
  expect_setequal(as.character(facets), c("Order_color", "grp_color"))
})

test_that("an object with no palette gives an actionable error", {
  expect_error(show_palette_pq(ps_mini), "carries no colour column")
})

# ---- input handling ----------------------------------------------------------

test_that("show_palette_pq accepts a plain named colour vector", {
  p <- show_palette_pq(c(a = "#dc863b", b = "#2e7891"), geom = "tile")
  expect_identical(nrow(layer_data(p)), 2L)
})

test_that("show_palette_pq rejects unnamed or non-character input", {
  expect_error(show_palette_pq(c("#dc863b", "#2e7891")), "named character")
  expect_error(show_palette_pq(1:3), "named character")
})

test_that("show_palette_pq validates geom and n_preview", {
  expect_error(show_palette_pq(pal8, geom = "bar"))
  expect_error(show_palette_pq(pal8, n_preview = 0), "positive integer")
  expect_error(show_palette_pq(pal8, n_preview = c(2, 3)), "positive integer")
})
