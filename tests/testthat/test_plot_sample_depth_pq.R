test_that("plot_sample_depth_pq returns a bar ggplot by default", {
  skip_if_not_installed("MiscMetabar")
  skip_if_not_installed("phyloseq")
  data(data_fungi_mini, package = "MiscMetabar")

  p <- plot_sample_depth_pq(data_fungi_mini)
  expect_s3_class(p, "ggplot")
})

test_that("plot_sample_depth_pq supports geom = 'density'", {
  skip_if_not_installed("MiscMetabar")
  skip_if_not_installed("phyloseq")
  data(data_fungi_mini, package = "MiscMetabar")

  p <- plot_sample_depth_pq(data_fungi_mini, geom = "density")
  expect_s3_class(p, "ggplot")
})

test_that("plot_sample_depth_pq supports log10", {
  skip_if_not_installed("MiscMetabar")
  skip_if_not_installed("phyloseq")
  data(data_fungi_mini, package = "MiscMetabar")

  p_bar <- plot_sample_depth_pq(data_fungi_mini, log10 = TRUE)
  p_dens <- plot_sample_depth_pq(
    data_fungi_mini,
    geom = "density",
    log10 = TRUE
  )
  expect_s3_class(p_bar, "ggplot")
  expect_s3_class(p_dens, "ggplot")
})

test_that("plot_sample_depth_pq supports color_fac", {
  skip_if_not_installed("MiscMetabar")
  skip_if_not_installed("phyloseq")
  data(data_fungi_mini, package = "MiscMetabar")

  p <- plot_sample_depth_pq(data_fungi_mini, color_fac = "Height")
  expect_s3_class(p, "ggplot")
  expect_equal(p$labels$fill, "Height")
})

test_that("plot_sample_depth_pq supports sort and threshold", {
  skip_if_not_installed("MiscMetabar")
  skip_if_not_installed("phyloseq")
  data(data_fungi_mini, package = "MiscMetabar")

  p <- plot_sample_depth_pq(
    data_fungi_mini,
    sort = TRUE,
    threshold = 1000
  )
  expect_s3_class(p, "ggplot")
  # The first sample in the plot should be the highest-depth one
  first_sample <- as.character(levels(p$data$Sample)[1])
  expect_equal(
    first_sample,
    names(sort(phyloseq::sample_sums(data_fungi_mini), decreasing = TRUE))[1]
  )
})

test_that("plot_sample_depth_pq aborts on bad color_fac", {
  skip_if_not_installed("MiscMetabar")
  skip_if_not_installed("phyloseq")
  data(data_fungi_mini, package = "MiscMetabar")

  expect_error(
    plot_sample_depth_pq(data_fungi_mini, color_fac = "NotACol"),
    "not found in sample_data"
  )
})
