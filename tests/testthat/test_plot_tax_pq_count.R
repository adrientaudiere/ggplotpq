test_that("plot_tax_pq_count returns a ggplot object", {
  skip_if_not_installed("MiscMetabar")
  skip_if_not_installed("phyloseq")
  data(data_fungi_sp_known, package = "MiscMetabar")

  p <- plot_tax_pq_count(
    data_fungi_sp_known,
    fact = "Time",
    merge_sample_by = "Time",
    taxa_fill = "Class"
  )
  expect_s3_class(p, "ggplot")
})

test_that("plot_tax_pq_count uses counts (non-proportional y)", {
  skip_if_not_installed("MiscMetabar")
  skip_if_not_installed("phyloseq")
  data(data_fungi_sp_known, package = "MiscMetabar")

  p <- plot_tax_pq_count(
    data_fungi_sp_known,
    fact = "Time",
    merge_sample_by = "Time",
    taxa_fill = "Class"
  )
  built <- ggplot2::ggplot_build(p)
  # max y value should be at least 1 (we cannot be 1.0 like a proportion)
  expect_gt(max(built$data[[1]]$y, na.rm = TRUE), 1)
})

test_that("plot_tax_pq_count aborts when fact is NULL", {
  skip_if_not_installed("MiscMetabar")
  skip_if_not_installed("phyloseq")
  data(data_fungi_sp_known, package = "MiscMetabar")

  expect_error(
    plot_tax_pq_count(data_fungi_sp_known, fact = NULL),
    "fact.* required"
  )
})

test_that("plot_tax_pq_count aborts on missing taxonomic rank", {
  skip_if_not_installed("MiscMetabar")
  skip_if_not_installed("phyloseq")
  data(data_fungi_sp_known, package = "MiscMetabar")

  expect_error(
    plot_tax_pq_count(
      data_fungi_sp_known,
      fact = "Time",
      merge_sample_by = "Time",
      taxa_fill = "NotARank"
    ),
    "not found"
  )
})

test_that("plot_tax_pq_count supports type='nb_taxa'", {
  skip_if_not_installed("MiscMetabar")
  skip_if_not_installed("phyloseq")
  data(data_fungi_sp_known, package = "MiscMetabar")

  p <- plot_tax_pq_count(
    data_fungi_sp_known,
    fact = "Time",
    merge_sample_by = "Time",
    taxa_fill = "Class",
    type = "nb_taxa"
  )
  expect_s3_class(p, "ggplot")
})
