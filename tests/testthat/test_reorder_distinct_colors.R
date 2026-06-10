test_that("reorder_distinct_colors returns a spec when p is NULL", {
  spec <- reorder_distinct_colors()
  expect_s3_class(spec, "reorder_distinct_colors_spec")
})

test_that("reorder_distinct_colors aborts on non-ggplot input", {
  expect_error(reorder_distinct_colors(p = list(a = 1)), "must be a ggplot")
})

test_that("reorder_distinct_colors works on a basic discrete fill plot", {
  df <- data.frame(
    x = factor(rep(LETTERS[1:4], each = 3)),
    y = c(10, 12, 8, 5, 7, 9, 20, 18, 22, 15, 13, 17)
  )
  p <- ggplot(df, aes(x = x, y = y, fill = x)) +
    geom_col() +
    scale_fill_brewer(palette = "Set1")

  out <- reorder_distinct_colors(p)
  expect_s3_class(out, "ggplot")
})

test_that("reorder_distinct_colors supports + operator via ggplot_add", {
  df <- data.frame(
    x = factor(rep(LETTERS[1:4], each = 3)),
    y = c(10, 12, 8, 5, 7, 9, 20, 18, 22, 15, 13, 17)
  )
  p <- ggplot(df, aes(x = x, y = y, fill = x)) +
    geom_col() +
    scale_fill_brewer(palette = "Set1")

  out <- p + reorder_distinct_colors()
  expect_s3_class(out, "ggplot")
})

test_that("reorder_distinct_colors supports colorblind mode", {
  df <- data.frame(
    x = factor(rep(LETTERS[1:4], each = 3)),
    y = c(10, 12, 8, 5, 7, 9, 20, 18, 22, 15, 13, 17)
  )
  p <- ggplot(df, aes(x = x, y = y, fill = x)) +
    geom_col() +
    scale_fill_brewer(palette = "Set1")

  out <- reorder_distinct_colors(p, colorblind = TRUE)
  expect_s3_class(out, "ggplot")
})

test_that("reorder_distinct_colors supports alternate_lightness", {
  df <- data.frame(
    x = factor(rep(LETTERS[1:4], each = 3)),
    y = c(10, 12, 8, 5, 7, 9, 20, 18, 22, 15, 13, 17)
  )
  p <- ggplot(df, aes(x = x, y = y, fill = x)) +
    geom_col() +
    scale_fill_brewer(palette = "Set1")

  out <- reorder_distinct_colors(p, alternate_lightness = TRUE)
  expect_s3_class(out, "ggplot")
})

test_that("reorder_distinct_colors aborts on a plot without discrete fill", {
  df <- data.frame(x = 1:5, y = 1:5)
  p <- ggplot(df, aes(x, y)) + geom_line()
  expect_error(reorder_distinct_colors(p), "discrete fill scale")
})
