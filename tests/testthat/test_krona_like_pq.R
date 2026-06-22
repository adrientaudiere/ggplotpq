skip_on_cran()
skip_if_not_installed("MiscMetabar")

data(data_fungi_mini, package = "MiscMetabar")

# ---- static path (no extra dependency) -------------------------------------

test_that("sunburst static returns ggplot", {
  p <- krona_like_pq(data_fungi_mini, interactive = FALSE)
  expect_s3_class(p, "ggplot")
})

test_that("treemap static returns ggplot", {
  p <- krona_like_pq(data_fungi_mini, layout = "treemap", interactive = FALSE)
  expect_s3_class(p, "ggplot")
})

test_that("weight_by = 'asv' returns ggplot", {
  p <- krona_like_pq(data_fungi_mini, weight_by = "asv", interactive = FALSE)
  expect_s3_class(p, "ggplot")
})

test_that("weight_by function (log1p) returns ggplot", {
  p <- krona_like_pq(data_fungi_mini, weight_by = log1p, interactive = FALSE)
  expect_s3_class(p, "ggplot")
})

test_that("weight_by numeric vector returns ggplot", {
  w <- rep(1, phyloseq::ntaxa(data_fungi_mini))
  p <- krona_like_pq(data_fungi_mini, weight_by = w, interactive = FALSE)
  expect_s3_class(p, "ggplot")
})

test_that("weight_by numeric vector of wrong length aborts", {
  expect_error(
    krona_like_pq(data_fungi_mini, weight_by = c(1, 2, 3), interactive = FALSE),
    "ntaxa"
  )
})

test_that("ranks subset works", {
  p <- krona_like_pq(
    data_fungi_mini,
    ranks = c("Phylum", "Class", "Order"),
    interactive = FALSE
  )
  expect_s3_class(p, "ggplot")
})

test_that("title is rendered in static ggplot", {
  p <- krona_like_pq(
    data_fungi_mini,
    title = "My fungi",
    interactive = FALSE
  )
  expect_s3_class(p, "ggplot")
  expect_equal(p$labels$title, "My fungi")
})

test_that("color_by rank changes output without error", {
  p <- krona_like_pq(
    data_fungi_mini,
    color_by = "Class",
    interactive = FALSE
  )
  expect_s3_class(p, "ggplot")
})

test_that("single-rank tax_table works", {
  pq_single <- phyloseq::tax_glom(data_fungi_mini, taxrank = "Phylum")
  p <- krona_like_pq(pq_single, ranks = "Phylum", interactive = FALSE)
  expect_s3_class(p, "ggplot")
})

test_that("invalid ranks name aborts", {
  expect_error(
    krona_like_pq(data_fungi_mini, ranks = "NotARank", interactive = FALSE),
    "not found"
  )
})

test_that("invalid color_by rank aborts", {
  expect_error(
    krona_like_pq(
      data_fungi_mini,
      ranks = c("Phylum", "Class"),
      color_by = "Order",
      interactive = FALSE
    ),
    "color_by"
  )
})

# ---- internal helpers -------------------------------------------------------

test_that(".hsl_to_hex returns a character string matching hex format", {
  hex <- ggplotpq:::.hsl_to_hex(120, 0.6, 0.5)
  expect_type(hex, "character")
  expect_match(hex, "^#[0-9A-F]{6}$")
})

test_that(".resolve_weights handles 'sequences'", {
  w <- ggplotpq:::.resolve_weights(data_fungi_mini, "sequences")
  expect_length(w, phyloseq::ntaxa(data_fungi_mini))
  expect_true(all(w >= 0))
})

test_that(".resolve_weights handles 'asv'", {
  w <- ggplotpq:::.resolve_weights(data_fungi_mini, "asv")
  expect_true(all(w == 1))
})

test_that(".resolve_weights aborts on bad string", {
  expect_error(
    ggplotpq:::.resolve_weights(data_fungi_mini, "read_counts"),
    "sequences"
  )
})

# ---- interactive path (guarded) --------------------------------------------

test_that("interactive = TRUE returns htmlwidget (requires htmlwidgets)", {
  skip_if_not_installed("htmlwidgets")
  w <- krona_like_pq(data_fungi_mini)
  expect_s3_class(w, "htmlwidget")
})

test_that("interactive treemap returns htmlwidget", {
  skip_if_not_installed("htmlwidgets")
  w <- krona_like_pq(data_fungi_mini, layout = "treemap")
  expect_s3_class(w, "htmlwidget")
})

test_that("file_path writes a self-contained HTML file", {
  skip_if_not_installed("htmlwidgets")
  tmp <- tempfile(fileext = ".html")
  on.exit(unlink(tmp))
  w <- krona_like_pq(data_fungi_mini, file_path = tmp)
  expect_true(file.exists(tmp))
  expect_gt(file.size(tmp), 1000L)
})
