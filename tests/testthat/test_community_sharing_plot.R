skip_on_cran()
skip_if_not_installed("MiscMetabar")
skip_if_not_installed("ggforce")
skip_if_not_installed("vegan")
skip_if_not_installed("RColorBrewer")

data(data_fungi_mini, package = "MiscMetabar")

test_that("make_sharing_metric returns a well-formed metric list", {
  m <- make_sharing_metric(
    label = "x",
    color = "#000000",
    fn = function(a, b, otu_sp, cache) 1
  )
  expect_type(m, "list")
  expect_named(m, c("label", "color", "fn", "fmt", "prep", "bounds"))
  expect_equal(m$fmt, "%.2f")
  expect_null(m$prep)
})

test_that("default_sharing_metrics returns the four expected metrics", {
  mets <- default_sharing_metrics()
  expect_named(mets, c("shared_sp", "bray_sim", "jac_sim", "genus_prop"))
  expect_true(all(vapply(mets, function(m) is.function(m$fn), logical(1))))
})

test_that("community_sharing_plot returns a ggplot with 3 modalities", {
  p <- community_sharing_plot(data_fungi_mini, fact = "Height")
  expect_s3_class(p, "ggplot")
})

test_that("community_sharing_plot honours a single-metric subset", {
  p <- community_sharing_plot(
    data_fungi_mini,
    fact = "Height",
    metrics = default_sharing_metrics()["jac_sim"]
  )
  expect_s3_class(p, "ggplot")
})

test_that("community_sharing_plot can add NA samples as a modality", {
  p <- community_sharing_plot(
    data_fungi_mini,
    fact = "Height",
    show_na_modality = TRUE
  )
  expect_s3_class(p, "ggplot")
})

test_that("community_sharing_plot aborts on a missing column", {
  expect_error(
    community_sharing_plot(data_fungi_mini, fact = "not_a_column"),
    "not found"
  )
})

test_that("community_sharing_barplot returns a ggplot faceted by metric", {
  p <- community_sharing_barplot(data_fungi_mini, fact = "Height")
  expect_s3_class(p, "ggplot")
  # one panel per metric, free y-scale (metrics are on incomparable scales)
  expect_s3_class(p$facet, "FacetWrap")
  expect_named(p$facet$params$facets, "metric_label")
})

test_that("community_sharing_barplot no longer accepts facet_by", {
  expect_error(
    community_sharing_barplot(
      data_fungi_mini,
      fact = "Height",
      facet_by = "pair"
    ),
    "unused argument"
  )
})
