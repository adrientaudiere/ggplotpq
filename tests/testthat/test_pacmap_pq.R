test_that("pacmap_pq returns a tibble with sample info and coordinates", {
  skip_on_cran()
  skip_if_not_installed("MiscMetabar")
  skip_if_not_installed("phyloseq")
  skip_if_not_installed("reticulate")
  skip_if_not(
    reticulate::py_module_available("pacmap"),
    "python pacmap unavailable"
  )
  data(data_fungi_mini, package = "MiscMetabar")

  df <- pacmap_pq(
    prune_samples(sample_names(data_fungi_mini)[1:20], data_fungi_mini),
    n_neighbors = 10,
    random_state = 42
  )

  expect_s3_class(df, "tbl_df")
  expect_true(all(c("x_pacmap", "y_pacmap", "Sample") %in% names(df)))
  expect_equal(nrow(df), 20)
  expect_true(is.numeric(df$x_pacmap))
  expect_true(is.numeric(df$y_pacmap))
  expect_true("Height" %in% names(df))
})

test_that("pacmap_pq errors when the Python module or samples are missing", {
  skip_if_not_installed("MiscMetabar")
  skip_if_not_installed("phyloseq")
  skip_if_not_installed("reticulate")
  data(data_fungi_mini, package = "MiscMetabar")

  two_samples <- prune_samples(
    sample_names(data_fungi_mini)[1:2],
    data_fungi_mini
  )
  if (reticulate::py_module_available("pacmap")) {
    expect_error(pacmap_pq(two_samples), "at least 3 samples")
  } else {
    expect_error(pacmap_pq(data_fungi_mini), "pacmap")
  }

  skip_if_not(
    reticulate::py_module_available("pacmap"),
    "python pacmap unavailable"
  )
  expect_error(pacmap_pq(two_samples), "at least 3 samples")
})
