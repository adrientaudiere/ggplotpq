test_that("plot_taxa_heatmap_pq returns a ggplot", {
  skip_if_not_installed("MiscMetabar")
  skip_if_not_installed("phyloseq")
  data(data_fungi_mini, package = "MiscMetabar")

  p <- plot_taxa_heatmap_pq(data_fungi_mini, n_top = 15, taxa_rank = "Family")
  expect_s3_class(p, "ggplot")
})

test_that("plot_taxa_heatmap_pq supports log10 transform", {
  skip_if_not_installed("MiscMetabar")
  skip_if_not_installed("phyloseq")
  data(data_fungi_mini, package = "MiscMetabar")

  p <- plot_taxa_heatmap_pq(data_fungi_mini, n_top = 10, log10 = TRUE)
  expect_s3_class(p, "ggplot")
  expect_equal(p$labels$fill, "log10(Abundance + 1)")
})

test_that("plot_taxa_heatmap_pq respects n_top", {
  skip_if_not_installed("MiscMetabar")
  skip_if_not_installed("phyloseq")
  data(data_fungi_mini, package = "MiscMetabar")

  p5 <- plot_taxa_heatmap_pq(data_fungi_mini, n_top = 5, taxa_rank = "Order")
  p20 <- plot_taxa_heatmap_pq(data_fungi_mini, n_top = 20, taxa_rank = "Order")
  # p5 has fewer distinct y levels than p20
  expect_lt(length(unique(p5$data$Taxon)), length(unique(p20$data$Taxon)))
})

test_that("plot_taxa_heatmap_pq aborts on bad n_top", {
  skip_if_not_installed("MiscMetabar")
  skip_if_not_installed("phyloseq")
  data(data_fungi_mini, package = "MiscMetabar")

  expect_error(
    plot_taxa_heatmap_pq(data_fungi_mini, n_top = 0),
    "positive integer"
  )
  expect_error(
    plot_taxa_heatmap_pq(data_fungi_mini, n_top = -3),
    "positive integer"
  )
})

test_that("plot_taxa_heatmap_pq aborts on bad taxa_rank", {
  skip_if_not_installed("MiscMetabar")
  skip_if_not_installed("phyloseq")
  data(data_fungi_mini, package = "MiscMetabar")

  expect_error(
    plot_taxa_heatmap_pq(data_fungi_mini, taxa_rank = "NotARank"),
    "not found"
  )
})
