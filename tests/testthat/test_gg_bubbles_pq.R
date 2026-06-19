skip_on_cran()
skip_if_not_installed("packcircles")
skip_if_not_installed("MiscMetabar")

data(data_fungi_mini, package = "MiscMetabar")

test_that("gg_bubbles_pq returns a ggplot object", {
  p <- gg_bubbles_pq(data_fungi_mini, rank_color = "Class")
  expect_s3_class(p, "ggplot")
})

test_that("gg_bubbles_pq square layout returns a ggplot", {
  p <- gg_bubbles_pq(data_fungi_mini, rank_color = "Class", layout = "square")
  expect_s3_class(p, "ggplot")
})

test_that("gg_bubbles_pq rank_contour works", {
  p <- gg_bubbles_pq(
    data_fungi_mini,
    rank_color = "Class",
    rank_contour = "Order"
  )
  expect_s3_class(p, "ggplot")
})

test_that("gg_bubbles_pq facet_by works", {
  p <- gg_bubbles_pq(
    data_fungi_mini,
    rank_color = "Class",
    facet_by = "Height"
  )
  expect_s3_class(p, "ggplot")
})

test_that("gg_bubbles_pq return_dataframe returns a data.frame", {
  df <- gg_bubbles_pq(
    data_fungi_mini,
    rank_color = "Class",
    return_dataframe = TRUE
  )
  expect_s3_class(df, "data.frame")
  expect_true("value" %in% names(df))
  expect_true("rank_value_color" %in% names(df))
})

test_that("gg_bubbles_pq diff_contour returns patchwork when facet_by is set", {
  skip_if_not_installed("patchwork")
  p <- gg_bubbles_pq(
    data_fungi_mini,
    rank_color = "Class",
    facet_by = "Height",
    diff_contour = TRUE,
    show_labels = FALSE
  )
  expect_true(inherits(p, "patchwork") || inherits(p, "ggplot"))
})

test_that("gg_bubbles_pq diff_contour without facet_by warns and falls back", {
  expect_warning(
    p <- gg_bubbles_pq(
      data_fungi_mini,
      rank_color = "Class",
      diff_contour = TRUE
    ),
    "facet_by"
  )
  expect_s3_class(p, "ggplot")
})

test_that("gg_bubbles_pq log1p transform works", {
  p <- gg_bubbles_pq(
    data_fungi_mini,
    rank_color = "Class",
    log1ptransform = TRUE
  )
  expect_s3_class(p, "ggplot")
})

test_that("gg_bubbles_pq min_nb_seq filtering works", {
  p <- gg_bubbles_pq(data_fungi_mini, rank_color = "Class", min_nb_seq = 100)
  expect_s3_class(p, "ggplot")
})
