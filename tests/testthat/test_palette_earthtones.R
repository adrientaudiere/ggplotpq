skip_on_cran()

test_that("palette_earthtones aborts for bad bbox_size without network", {
  expect_error(
    palette_earthtones(44, 3, bbox_size = -100),
    "positive"
  )
})

skip_if_not_installed("maptiles")
skip_if_not_installed("terra")
skip_if_not_installed("sf")

test_that("palette_earthtones returns n_colors hex codes (kmeans)", {
  cols <- palette_earthtones(
    latitude = 44.5, longitude = 3.2, n_colors = 4, zoom = 6
  )
  expect_length(cols, 4)
  expect_match(cols, "^#[0-9A-Fa-f]{6}$")
})

test_that("palette_earthtones returns different palettes for different latitudes", {
  cols_south <- palette_earthtones(
    latitude = 20, longitude = 3, n_colors = 3, zoom = 5
  )
  cols_north <- palette_earthtones(
    latitude = 65, longitude = 3, n_colors = 3, zoom = 5
  )
  expect_false(identical(cols_south, cols_north))
})

test_that("palette_earthtones method='mean' returns n_colors codes", {
  cols <- palette_earthtones(
    latitude = 44.5, longitude = 3.2, n_colors = 3, zoom = 6,
    method = "mean"
  )
  expect_length(cols, 3)
  expect_match(cols, "^#[0-9A-Fa-f]{6}$")
})

test_that("palette_earthtones aborts for bad bbox_size", {
  expect_error(
    palette_earthtones(44, 3, bbox_size = -100),
    "positive"
  )
})
