data(data_fungi_mini, package = "MiscMetabar")
ps_mini <- data_fungi_mini

quiet <- function(expr) {
  suppressWarnings(suppressMessages(expr))
}

ps_tax <- quiet(palette_tax_pq(ps_mini, "Order", n = 6, add_to_phyloseq = TRUE))
pal6 <- quiet(palette_tax_pq(ps_tax, "Order"))
top6 <- .pq_tax_top(ps_mini, "Order", 6)

ps_sam <- ps_mini
phyloseq::sample_data(ps_sam)$grp <- rep(
  c("a", "b", "c"),
  length.out = phyloseq::nsamples(ps_sam)
)
ps_sam <- quiet(palette_sam_pq(ps_sam, "grp", add_to_phyloseq = TRUE))

tax_df <- data.frame(x = top6, y = seq_along(top6), Order = top6)
sam_df <- data.frame(x = c("a", "b", "c"), y = 1:3, grp = c("a", "b", "c"))

# ---- the four scales ---------------------------------------------------------

test_that("scale_fill_tax_pq colours a plot from the stored palette", {
  p <- ggplot(tax_df, aes(x, y, fill = Order)) +
    geom_col() +
    scale_fill_tax_pq(ps_tax, "Order")
  expect_identical(ggplot_build(p)$data[[1]]$fill, unname(pal6[top6]))
})

test_that("scale_color_tax_pq colours a colour aesthetic", {
  p <- ggplot(tax_df, aes(x, y, colour = Order)) +
    geom_point() +
    scale_color_tax_pq(ps_tax, "Order")
  expect_identical(ggplot_build(p)$data[[1]]$colour, unname(pal6[top6]))
})

test_that("scale_fill_sam_pq reads the sam_data palette", {
  pal <- quiet(palette_sam_pq(ps_sam, "grp"))
  p <- ggplot(sam_df, aes(x, y, fill = grp)) +
    geom_col() +
    scale_fill_sam_pq(ps_sam, "grp")
  expect_identical(
    ggplot_build(p)$data[[1]]$fill,
    unname(pal[c("a", "b", "c")])
  )
})

test_that("scale_color_sam_pq reads the sam_data palette", {
  pal <- quiet(palette_sam_pq(ps_sam, "grp"))
  p <- ggplot(sam_df, aes(x, y, colour = grp)) +
    geom_point() +
    scale_color_sam_pq(ps_sam, "grp")
  expect_identical(
    ggplot_build(p)$data[[1]]$colour,
    unname(pal[c("a", "b", "c")])
  )
})

test_that("the scale gives the same colours as the palette added with +", {
  by_scale <- ggplot(tax_df, aes(x, y, fill = Order)) +
    geom_col() +
    scale_fill_tax_pq(ps_tax, "Order")
  by_plus <- ggplot(tax_df, aes(x, y, fill = Order)) + geom_col() + pal6
  expect_identical(
    ggplot_build(by_scale)$data[[1]]$fill,
    ggplot_build(by_plus)$data[[1]]$fill
  )
})

test_that("a subset of the levels keeps its colours", {
  sub_df <- tax_df[c(1, 4, 5), ]
  p <- ggplot(sub_df, aes(x, y, fill = Order)) +
    geom_col() +
    scale_fill_tax_pq(ps_tax, "Order")
  expect_identical(
    ggplot_build(p)$data[[1]]$fill,
    unname(pal6[top6[c(1, 4, 5)]])
  )
})

test_that("levels outside the palette fall back to na.value", {
  df <- data.frame(x = c(top6[1], "zz"), y = 1:2, Order = c(top6[1], "zz"))
  p <- ggplot(df, aes(x, y, fill = Order)) +
    geom_col() +
    scale_fill_tax_pq(ps_tax, "Order", na.value = "black")
  expect_identical(ggplot_build(p)$data[[1]]$fill[2], "black")
})

# ---- identity mode -----------------------------------------------------------

test_that("identity = TRUE maps hex columns and repairs the legend", {
  idf <- tax_df
  idf$Order_color <- unname(pal6[top6])
  p <- ggplot(idf, aes(x, y, fill = Order_color)) +
    geom_col() +
    scale_fill_tax_pq(ps_tax, "Order", identity = TRUE)

  expect_identical(ggplot_build(p)$data[[1]]$fill, unname(pal6[top6]))
  # Without the scale the legend would read hex codes; with it, level names.
  key <- ggplot_build(p)$plot$scales$get_scales("fill")$get_labels()
  expect_true(any(top6 %in% key))
  expect_false(any(grepl("^#", key)))
})

test_that("identity = TRUE works on the colour aesthetic too", {
  idf <- tax_df
  idf$Order_color <- unname(pal6[top6])
  p <- ggplot(idf, aes(x, y, colour = Order_color)) +
    geom_point() +
    scale_color_tax_pq(ps_tax, "Order", identity = TRUE)
  expect_identical(ggplot_build(p)$data[[1]]$colour, unname(pal6[top6]))
})

# ---- column resolution -------------------------------------------------------

test_that("a single suffixed palette is picked up when the default is absent", {
  ps <- quiet(palette_tax_pq(
    ps_mini,
    "Order",
    n = 6,
    add_to_phyloseq = TRUE,
    suffix = "_color_alt"
  ))
  expect_message(scale_fill_tax_pq(ps, "Order"), "the only palette stored")
})

test_that("the default column wins when it is there, whatever else exists", {
  ps <- quiet(palette_tax_pq(
    ps_tax,
    "Order",
    n = 6,
    palette = "oklch",
    add_to_phyloseq = TRUE,
    suffix = "_color_alt"
  ))
  expect_no_error(scale_fill_tax_pq(ps, "Order"))
  expect_s3_class(
    scale_fill_tax_pq(ps, "Order", suffix = "_color_alt"),
    "Scale"
  )
})

test_that("several suffixed palettes and no default force an explicit suffix", {
  ps <- quiet(palette_tax_pq(
    ps_mini,
    "Order",
    n = 6,
    add_to_phyloseq = TRUE,
    suffix = "_color_a"
  ))
  ps <- quiet(palette_tax_pq(
    ps,
    "Order",
    n = 6,
    palette = "oklch",
    add_to_phyloseq = TRUE,
    suffix = "_color_b"
  ))
  expect_error(scale_fill_tax_pq(ps, "Order"), "carries 2 palettes")
  expect_s3_class(scale_fill_tax_pq(ps, "Order", suffix = "_color_b"), "Scale")
})

test_that("an explicit suffix is never silently replaced", {
  expect_error(
    scale_fill_tax_pq(ps_tax, "Order", suffix = "_color_nope"),
    "is not in"
  )
})

test_that("an object with no palette names both correct fixes", {
  expect_error(
    scale_fill_tax_pq(ps_mini, "Order"),
    "carries no palette"
  )
  expect_error(scale_fill_sam_pq(ps_mini, "Height"), "carries no palette")
})

test_that(".pq_escape_regex neutralises regex metacharacters", {
  expect_identical(.pq_escape_regex("a.b"), "a\\.b")
  expect_identical(.pq_escape_regex("x(y)"), "x\\(y\\)")
  expect_false(grepl(paste0("^", .pq_escape_regex("a.b")), "aXb"))
  expect_true(grepl(paste0("^", .pq_escape_regex("a.b")), "a.b_color"))
})

test_that("a variable name holding a dot resolves to its own column", {
  ps <- ps_mini
  phyloseq::sample_data(ps)$a.b <- rep(
    c("x", "y"),
    length.out = phyloseq::nsamples(ps)
  )
  # A decoy the unescaped pattern "^a.b_color" would also match.
  phyloseq::sample_data(ps)$aXb_color <- "#000000"
  ps <- quiet(palette_sam_pq(ps, "a.b", add_to_phyloseq = TRUE))
  expect_s3_class(scale_fill_sam_pq(ps, "a.b"), "Scale")
})
