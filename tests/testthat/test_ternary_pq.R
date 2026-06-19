skip_on_cran()
skip_if_not_installed("MiscMetabar")

data(data_fungi_mini, package = "MiscMetabar")

# Height has 3 levels (High, Low, Middle) → ternary
# Time has 4 levels (0, 5, 10, 15)        → diamond
pq_height <- data_fungi_mini # NAs in Height are dropped automatically

test_that(".ternary_norm produces correct structure for 3 groups", {
  dat <- ggplotpq:::.ternary_norm(pq_height, "Height", NULL, FALSE, TRUE)
  expect_s3_class(dat, "data.frame")
  expect_true(all(c("x", "y", "abundance") %in% names(dat)))
  expect_equal(attr(dat, "type"), "ternary")
  expect_length(attr(dat, "labels"), 3)
})

test_that("ternary_pq returns a ggplot for 3 groups", {
  p <- ternary_pq(pq_height, fact = "Height")
  expect_s3_class(p, "ggplot")
})

test_that("ternary_pq works with color_rank", {
  p <- ternary_pq(pq_height, fact = "Height", color_rank = "Class")
  expect_s3_class(p, "ggplot")
})

test_that("ternary_pq works without grid", {
  p <- ternary_pq(pq_height, fact = "Height", add_grid = FALSE)
  expect_s3_class(p, "ggplot")
})

test_that("ternary_pq works with size_by log10_abundance", {
  p <- ternary_pq(pq_height, fact = "Height", size_by = "log10_abundance")
  expect_s3_class(p, "ggplot")
})

test_that("ternary_pq works with size_by equal", {
  p <- ternary_pq(pq_height, fact = "Height", size_by = "equal")
  expect_s3_class(p, "ggplot")
})

test_that("ternary_pq aborts with wrong number of group levels (2)", {
  # Build a 2-level physeq
  sd2 <- as.data.frame(phyloseq::sample_data(data_fungi_mini))
  keep2 <- rownames(sd2)[
    sd2[["Height"]] %in% c("High", "Low") & !is.na(sd2[["Height"]])
  ]
  pq2 <- phyloseq::prune_samples(keep2, data_fungi_mini)
  expect_error(
    ternary_pq(pq2, fact = "Height"),
    "exactly 3 or 4"
  )
})

test_that(".ternary_norm produces correct structure for 4 groups", {
  # Time has 4 levels: 0, 5, 10, 15
  keep_t <- rownames(as.data.frame(phyloseq::sample_data(data_fungi_mini)))[
    !is.na(as.data.frame(phyloseq::sample_data(data_fungi_mini))[["Time"]])
  ]
  pq4 <- phyloseq::prune_samples(keep_t, data_fungi_mini)
  dat4 <- ggplotpq:::.ternary_norm(pq4, "Time", NULL, FALSE, TRUE)
  expect_equal(attr(dat4, "type"), "diamond")
  expect_length(attr(dat4, "labels"), 4)
})

test_that("ternary_pq returns a ggplot for 4 groups (diamond)", {
  keep_t <- rownames(as.data.frame(phyloseq::sample_data(data_fungi_mini)))[
    !is.na(as.data.frame(phyloseq::sample_data(data_fungi_mini))[["Time"]])
  ]
  pq4 <- phyloseq::prune_samples(keep_t, data_fungi_mini)
  p <- ternary_pq(pq4, fact = "Time")
  expect_s3_class(p, "ggplot")
})
