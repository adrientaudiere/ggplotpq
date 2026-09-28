test_that("dr_plot_pq draws the requested panels and attaches layouts", {
  skip_on_cran()
  skip_if_not_installed("MiscMetabar")
  skip_if_not_installed("phyloseq")
  skip_if_not_installed("Rtsne")
  data(data_fungi_mini, package = "MiscMetabar")

  p <- dr_plot_pq(
    prune_samples(sample_names(data_fungi_mini)[1:20], data_fungi_mini),
    fact = "Height",
    techniques = c("tsne", "mds", "nmds")
  )

  expect_s3_class(p, "ggplot")
  layouts <- attr(p, "layouts")
  expect_type(layouts, "list")
  expect_named(layouts, c("tsne", "mds", "nmds"))
  expect_equal(nrow(layouts$tsne), 20)
  expect_true(all(c("x_tsne", "y_tsne", "Sample") %in% names(layouts$tsne)))
  expect_true(all(c("x_ord", "y_ord", "Sample") %in% names(layouts$mds)))
  expect_equal(
    p$patches$annotation$title,
    "Three dimensionality-reduction techniques"
  )
})

test_that("dr_plot_pq maps shape and label on the data panels only", {
  skip_on_cran()
  skip_if_not_installed("MiscMetabar")
  skip_if_not_installed("phyloseq")
  data(data_fungi_mini, package = "MiscMetabar")

  p <- dr_plot_pq(
    prune_samples(sample_names(data_fungi_mini)[1:20], data_fungi_mini),
    fact = "Height",
    shape = "Time",
    label = "Sample",
    techniques = c("mds", "nmds")
  )

  expect_equal(
    p$patches$annotation$title,
    "Two dimensionality-reduction techniques"
  )
  # the last plot of the patchwork is the NMDS panel
  expect_true("shape" %in% names(p$mapping))
  expect_length(p$layers, 2)
  expect_true("label" %in% names(p$layers[[2]]$mapping))
  expect_no_error(print(p))

  # samples with NA in the shape column are drawn, not silently dropped
  p_na <- dr_plot_pq(
    prune_samples(sample_names(data_fungi_mini)[1:20], data_fungi_mini),
    shape = "Height",
    techniques = "mds"
  )
  built <- ggplot2::ggplot_build(p_na)
  expect_false(anyNA(built$data[[1]]$shape))

  p_one <- dr_plot_pq(
    prune_samples(sample_names(data_fungi_mini)[1:20], data_fungi_mini),
    techniques = "mds"
  )
  expect_equal(p_one$patches$annotation$title, "MDS dimensionality reduction")
})

test_that("dr_plot_pq runs all six techniques when backends are available", {
  skip_on_cran()
  skip_if_not_installed("MiscMetabar")
  skip_if_not_installed("phyloseq")
  skip_if_not_installed("Rtsne")
  skip_if_not_installed("reticulate")
  skip_if_not_installed("umap")
  if (
    !reticulate::py_module_available("umato") ||
      !reticulate::py_module_available("pacmap")
  ) {
    skip("python umato/pacmap unavailable")
  }
  data(data_fungi_mini, package = "MiscMetabar")

  p <- dr_plot_pq(
    prune_samples(sample_names(data_fungi_mini)[1:20], data_fungi_mini),
    techniques = c("tsne", "umap", "umato", "pacmap", "mds", "nmds")
  )

  expect_s3_class(p, "ggplot")
  expect_named(
    attr(p, "layouts"),
    c("tsne", "umap", "umato", "pacmap", "mds", "nmds")
  )
})

test_that("dr_plot_pq validates its arguments", {
  skip_if_not_installed("MiscMetabar")
  skip_if_not_installed("phyloseq")
  data(data_fungi_mini, package = "MiscMetabar")

  expect_error(
    dr_plot_pq(data_fungi_mini, techniques = "pcoa"),
    "arg"
  )
  expect_error(
    dr_plot_pq(
      prune_samples(sample_names(data_fungi_mini)[1:2], data_fungi_mini)
    ),
    "at least 5 samples"
  )
  expect_error(
    dr_plot_pq(data_fungi_mini, fact = "not_a_column"),
    "fact"
  )
  expect_error(
    dr_plot_pq(data_fungi_mini, shape = "not_a_column"),
    "shape"
  )
  expect_error(
    dr_plot_pq(data_fungi_mini, label = "not_a_column"),
    "label"
  )
})
