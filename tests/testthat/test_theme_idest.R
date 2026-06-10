test_that("theme_idest returns a theme object", {
  th <- theme_idest()
  expect_s3_class(th, "theme")
  expect_s3_class(th, "gg")
})

test_that("theme_idest respects grid/axis/ticks toggles", {
  th_none <- theme_idest(grid = FALSE, axis = FALSE, ticks = FALSE)
  th_all <- theme_idest(grid = TRUE, axis = TRUE, ticks = TRUE)
  expect_s3_class(th_none, "theme")
  expect_s3_class(th_all, "theme")
})

test_that("theme_idest accepts custom fonts and sizes", {
  th <- theme_idest(
    sans_family = "Helvetica",
    base_size = 14,
    plot_title_size = 24
  )
  expect_equal(th$text$size, 14)
})

test_that("idest_pal contains the expected palettes", {
  expect_true(is.list(idest_pal))
  expect_true(all(
    c(
      "all_color_idest",
      "ligth_color_idest",
      "dark_color_idest",
      "Picabia",
      "Picasso",
      "Levine2",
      "Rattner",
      "Sidhu",
      "Hokusai2",
      "Hokusai3"
    ) %in%
      names(idest_pal)
  ))
})

test_that("idest_colors returns correct n (discrete)", {
  cols <- idest_colors("all_color_idest", n = 4, type = "discrete")
  expect_length(cols, 4)
  expect_s3_class(cols, "palette")
})

test_that("idest_colors returns correct n (continuous)", {
  cols <- idest_colors("all_color_idest", n = 20, type = "continuous")
  expect_length(cols, 20)
})

test_that("idest_colors reverses with direction = -1", {
  cols_fwd <- idest_colors(
    "all_color_idest",
    n = 4,
    type = "discrete",
    direction = 1
  )
  cols_rev <- idest_colors(
    "all_color_idest",
    n = 4,
    type = "discrete",
    direction = -1
  )
  expect_equal(as.vector(rev(cols_fwd)), as.vector(cols_rev))
})

test_that("idest_colors aborts on unknown palette", {
  expect_error(
    idest_colors("nonexistent_palette", n = 3, type = "discrete"),
    "does not exist"
  )
})

test_that("idest_colors aborts on invalid direction", {
  expect_error(
    idest_colors("all_color_idest", n = 3, type = "discrete", direction = 2),
    "must be 1"
  )
})

test_that("scale_color_idest_c works inside a ggplot", {
  p <- ggplot(mtcars, aes(wt, mpg, color = cyl)) +
    geom_point() +
    scale_color_idest_c()
  expect_s3_class(p, "ggplot")
  built <- ggplot2::ggplot_build(p)
  expect_true("colour" %in% names(built$data[[1]]))
})

test_that("scale_fill_idest_c works inside a ggplot", {
  p <- ggplot(mtcars, aes(factor(cyl), fill = factor(cyl))) +
    geom_bar() +
    scale_fill_idest_c()
  expect_s3_class(p, "ggplot")
})

test_that("scale_color_idest_d works inside a ggplot", {
  p <- ggplot(mtcars, aes(factor(cyl), color = factor(cyl))) +
    geom_point() +
    scale_color_idest_d()
  expect_s3_class(p, "ggplot")
})

test_that("scale_fill_idest_d works inside a ggplot", {
  p <- ggplot(mtcars, aes(factor(cyl), fill = factor(cyl))) +
    geom_bar() +
    scale_fill_idest_d()
  expect_s3_class(p, "ggplot")
})

test_that("theme_idest can be added to a ggplot", {
  p <- ggplot(mtcars, aes(wt, mpg)) +
    geom_point() +
    theme_idest()
  expect_s3_class(p, "ggplot")
})
