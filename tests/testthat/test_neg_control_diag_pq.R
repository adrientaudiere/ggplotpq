skip_on_cran()

make_nc_pq <- function() {
  data(data_fungi_mini, package = "MiscMetabar")
  pq <- phyloseq::prune_samples(
    phyloseq::sample_names(data_fungi_mini)[1:15],
    data_fungi_mini
  )
  pq <- MiscMetabar::clean_pq(pq, silent = TRUE)
  phyloseq::sample_data(pq)$is_control <-
    phyloseq::sample_sums(pq) < stats::median(phyloseq::sample_sums(pq))
  pq
}

test_that("neg_control_diag_pq returns a patchwork figure", {
  skip_if_not_installed("patchwork")
  skip_if_not_installed("tidyr")
  skip_if_not_installed("vegan")
  pq <- make_nc_pq()
  p <- neg_control_diag_pq(pq, is_control)
  expect_s3_class(p, "patchwork")
})

test_that("neg_control_diag_pq errors when no sample matches", {
  skip_if_not_installed("patchwork")
  skip_if_not_installed("tidyr")
  pq <- make_nc_pq()
  phyloseq::sample_data(pq)$is_control <- FALSE
  expect_error(neg_control_diag_pq(pq, is_control), "No samples match")
})

test_that("neg_control_diag_pq rejects a non-logical expression", {
  skip_if_not_installed("patchwork")
  skip_if_not_installed("tidyr")
  pq <- make_nc_pq()
  expect_error(
    neg_control_diag_pq(pq, phyloseq::sample_sums(.)),
    "logical"
  )
})
