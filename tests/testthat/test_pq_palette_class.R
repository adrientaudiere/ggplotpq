pal_flat <- .pq_new_palette(
  c(a = "#dc863b", b = "#2e7891", c = "#b4dfa7", other = "grey85"),
  slot = "tax_table",
  var = "Order",
  add = c(other = "grey85")
)

df3 <- data.frame(x = c("a", "b", "c"), y = 1:3, g = c("a", "b", "c"))

# ---- construction ------------------------------------------------------------

test_that(".pq_new_palette is still a plain named character vector", {
  expect_true(is.character(pal_flat))
  expect_identical(names(pal_flat), c("a", "b", "c", "other"))
  expect_identical(unname(pal_flat[["a"]]), "#dc863b")
})

test_that(".pq_new_palette records its provenance", {
  expect_identical(attr(pal_flat, "pq_slot"), "tax_table")
  expect_identical(attr(pal_flat, "pq_var"), "Order")
  expect_null(attr(pal_flat, "pq_parent"))
  expect_identical(attr(pal_flat, "pq_na_value"), "grey70")
})

test_that(".pq_is_palette recognises the class", {
  expect_true(.pq_is_palette(pal_flat))
  expect_false(.pq_is_palette(c(a = "#000000")))
})

test_that("a pq_palette works directly in scale_fill_manual", {
  p <- ggplot(df3, aes(x, y, fill = g)) +
    geom_col() +
    scale_fill_manual(values = pal_flat)
  expect_identical(
    ggplot_build(p)$data[[1]]$fill,
    unname(pal_flat[c("a", "b", "c")])
  )
})

# ---- format / print ----------------------------------------------------------

test_that("format.pq_palette summarises the palette", {
  out <- format(pal_flat)
  expect_match(out[1], "Order")
  expect_match(out[1], "3 levels")
  expect_length(out, 5)
})

test_that("format.pq_palette announces the nesting", {
  nested <- .pq_new_palette(
    c(a = "#111111", b = "#222222"),
    var = "Genus",
    parent = "Phylum",
    parent_colors = c(P = "#333333")
  )
  expect_match(format(nested)[1], "nested in Phylum")
})

test_that("print.pq_palette returns its input invisibly", {
  expect_output(out <- print(pal_flat), "pq_palette")
  expect_identical(out, pal_flat)
})

# ---- ggplot_add --------------------------------------------------------------

test_that("p + pal colours a fill mapping", {
  p <- ggplot(df3, aes(x, y, fill = g)) + geom_col() + pal_flat
  expect_identical(
    ggplot_build(p)$data[[1]]$fill,
    unname(pal_flat[c("a", "b", "c")])
  )
})

test_that("p + pal colours a colour mapping", {
  p <- ggplot(df3, aes(x, y, colour = g)) + geom_point() + pal_flat
  expect_identical(
    ggplot_build(p)$data[[1]]$colour,
    unname(pal_flat[c("a", "b", "c")])
  )
})

test_that("p + pal covers fill and colour in one scale", {
  p <- ggplot(df3, aes(x, y, fill = g, colour = g)) + geom_col() + pal_flat
  built <- ggplot_build(p)$data[[1]]
  expect_identical(built$fill, unname(pal_flat[c("a", "b", "c")]))
  expect_identical(built$colour, unname(pal_flat[c("a", "b", "c")]))
})

test_that("p + pal picks up an aesthetic mapped at the layer level", {
  p <- ggplot(df3, aes(x, y)) + geom_col(aes(fill = g)) + pal_flat
  expect_identical(
    ggplot_build(p)$data[[1]]$fill,
    unname(pal_flat[c("a", "b", "c")])
  )
})

test_that("p + pal warns when the plot maps neither fill nor colour", {
  p <- ggplot(df3, aes(x, y)) + geom_col()
  expect_warning(out <- p + pal_flat, "maps neither")
  expect_s3_class(out, "ggplot")
})

test_that("the same palette gives the same colours on a subset of levels", {
  full <- ggplot(df3, aes(x, y, fill = g)) + geom_col() + pal_flat
  sub_df <- df3[df3$g %in% c("a", "c"), ]
  sub <- ggplot(sub_df, aes(x, y, fill = g)) + geom_col() + pal_flat

  full_fills <- ggplot_build(full)$data[[1]]$fill
  sub_fills <- ggplot_build(sub)$data[[1]]$fill
  expect_identical(sub_fills, full_fills[c(1, 3)])
})

test_that("levels absent from the palette fall back to na.value", {
  df4 <- data.frame(x = c("a", "zz"), y = 1:2, g = c("a", "zz"))
  p <- ggplot(df4, aes(x, y, fill = g)) + geom_col() + pal_flat
  expect_identical(ggplot_build(p)$data[[1]]$fill[2], "grey70")
})
