test_that("scale_color_pq_discrete works inside a ggplot", {
  p <- ggplot(mtcars, aes(wt, mpg, color = factor(cyl))) +
    geom_point() +
    scale_color_pq_discrete()
  expect_s3_class(p, "ggplot")
  built <- ggplot2::ggplot_build(p)
  expect_true("colour" %in% names(built$data[[1]]))
})

test_that("scale_color_pq_discrete supports palette choice", {
  p <- ggplot(mtcars, aes(wt, mpg, color = factor(cyl))) +
    geom_point() +
    scale_color_pq_discrete("Picabia")
  expect_s3_class(p, "ggplot")
})

test_that("scale_color_pq_discrete supports direction = -1", {
  p_fwd <- ggplot(mtcars, aes(factor(cyl), fill = factor(cyl))) +
    geom_bar() +
    scale_fill_pq_discrete("Picabia", direction = 1)
  p_rev <- ggplot(mtcars, aes(factor(cyl), fill = factor(cyl))) +
    geom_bar() +
    scale_fill_pq_discrete("Picabia", direction = -1)
  expect_s3_class(p_fwd, "ggplot")
  expect_s3_class(p_rev, "ggplot")
})

test_that("scale_fill_pq_discrete works inside a ggplot", {
  p <- ggplot(mtcars, aes(factor(cyl), fill = factor(cyl))) +
    geom_bar() +
    scale_fill_pq_discrete()
  expect_s3_class(p, "ggplot")
})

test_that("scale_color_pq_discrete aborts on bad palette", {
  expect_error(
    ggplot(mtcars, aes(wt, mpg, color = factor(cyl))) +
      geom_point() +
      scale_color_pq_discrete("NoSuchPalette"),
    "not in the IdEst palette family"
  )
})

test_that("scale_color_pq_discrete aborts on bad direction", {
  expect_error(
    ggplot(mtcars, aes(wt, mpg, color = factor(cyl))) +
      geom_point() +
      scale_color_pq_discrete(direction = 2),
    "must be 1 or -1"
  )
})
