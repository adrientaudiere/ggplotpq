test_that("umato_pq returns a tibble with sample info and coordinates", {
  skip_on_cran()
  skip_if_not_installed("MiscMetabar")
  skip_if_not_installed("phyloseq")
  skip_if_not_installed("reticulate")
  skip_if_not(
    reticulate::py_module_available("umato"),
    "python umato unavailable"
  )
  data(data_fungi_mini, package = "MiscMetabar")

  df <- umato_pq(
    prune_samples(sample_names(data_fungi_mini)[1:20], data_fungi_mini),
    n_neighbors = 10,
    random_state = 42
  )

  expect_s3_class(df, "tbl_df")
  expect_true(all(c("x_umato", "y_umato", "Sample") %in% names(df)))
  expect_equal(nrow(df), 20)
  expect_true(is.numeric(df$x_umato))
  expect_true(is.numeric(df$y_umato))
  expect_true("Height" %in% names(df))
})

test_that("umato_pq errors on missing python module or too few samples", {
  skip_if_not_installed("MiscMetabar")
  skip_if_not_installed("phyloseq")
  skip_if_not_installed("reticulate")
  data(data_fungi_mini, package = "MiscMetabar")

  two_samples <- prune_samples(
    sample_names(data_fungi_mini)[1:2],
    data_fungi_mini
  )
  if (reticulate::py_module_available("umato")) {
    expect_error(umato_pq(two_samples), "at least 3 samples")
  } else {
    expect_error(umato_pq(data_fungi_mini), "umato")
  }

  skip_if_not(
    reticulate::py_module_available("umato"),
    "python umato unavailable"
  )
  expect_error(umato_pq(two_samples), "at least 3 samples")
})
