test_that("theme_pq_minimal returns a theme object", {
  th <- theme_pq_minimal()
  expect_s3_class(th, "theme")
  expect_s3_class(th, "gg")
})

test_that("theme_pq_minimal respects custom sizes", {
  th <- theme_pq_minimal(
    base_size = 13,
    plot_title_size = 18,
    axis_title_size = 12
  )
  expect_equal(th$text$size, 13)
  expect_equal(th$plot.title$size, 18)
  expect_equal(th$axis.title$size, 12)
})

test_that("theme_pq_minimal can be added to a ggplot", {
  p <- ggplot(mtcars, aes(wt, mpg)) +
    geom_point() +
    theme_pq_minimal()
  expect_s3_class(p, "ggplot")
})

test_that("theme_pq_minimal works with facets", {
  p <- ggplot(mtcars, aes(wt, mpg)) +
    geom_point() +
    facet_wrap(~ factor(cyl)) +
    theme_pq_minimal()
  expect_s3_class(p, "ggplot")
  expect_true(length(p$facet$params$facets) > 0)
})
