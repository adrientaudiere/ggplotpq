test_that("wheat_plot returns a ggplot object", {
  set.seed(42)
  df <- data.frame(value = rnorm(200, mean = 50, sd = 10))
  p <- wheat_plot(df, value, binwidth = 2)
  expect_s3_class(p, "ggplot")
})

test_that("wheat_plot works on phyloseq-derived data", {
  skip_if_not_installed("MiscMetabar")
  skip_if_not_installed("phyloseq")
  data(data_fungi_mini, package = "MiscMetabar")
  df <- data.frame(value = phyloseq::taxa_sums(data_fungi_mini))
  p <- wheat_plot(df, value, binwidth = 2000)
  expect_s3_class(p, "ggplot")
})

test_that("wheat_plot aborts on non-numeric column", {
  df <- data.frame(value = letters[1:5])
  expect_error(
    suppressWarnings(suppressMessages(
      wheat_plot(df, value, binwidth = 1)
    )),
    "must refer to a numeric column"
  )
})

test_that("wheat_plot accepts custom labels and titles", {
  set.seed(1)
  df <- data.frame(value = rnorm(50))
  p <- wheat_plot(
    df,
    value,
    binwidth = 0.5,
    xlab = "My x",
    ylab = "My y",
    title = "My title"
  )
  expect_s3_class(p, "ggplot")
  expect_equal(p$labels$x, "My x")
  expect_equal(p$labels$y, "My y")
  expect_equal(p$labels$title, "My title")
})

test_that("wheat_plot falls back when IQR is zero (constant data)", {
  df <- data.frame(value = rep(5, 20))
  p <- wheat_plot(df, value)
  expect_s3_class(p, "ggplot")
})
