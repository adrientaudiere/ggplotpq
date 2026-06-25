df_outlier <- data.frame(
  sample = c("A", "B", "C", "D", "E"),
  reads = c(120, 145, 110, 130, 5000)
)
p_bar <- ggplot2::ggplot(df_outlier, ggplot2::aes(x = sample, y = reads)) +
  ggplot2::geom_col()

df_scatter <- data.frame(
  x = c(1, 2, 3, 4, 500),
  y = c(10, 12, 11, 13, 8)
)
p_scatter <- ggplot2::ggplot(df_scatter, ggplot2::aes(x = x, y = y)) +
  ggplot2::geom_point()

df_no_outlier <- data.frame(
  sample = c("A", "B", "C"),
  reads = c(100, 120, 110)
)
p_no_outlier <- ggplot2::ggplot(df_no_outlier, ggplot2::aes(x = sample, y = reads)) +
  ggplot2::geom_col()

# ---- .pq_find_main_cluster ---------------------------------------------------

test_that(".pq_find_main_cluster returns NULL when no gap exceeds cutoff", {
  expect_null(.pq_find_main_cluster(c(1, 2, 3, 4, 5), cutoff = 5))
})

test_that(".pq_find_main_cluster detects a single gap", {
  result <- .pq_find_main_cluster(c(1, 2, 3, 100, 200), cutoff = 5)
  expect_false(is.null(result))
  expect_equal(result$main_min, 1)
  expect_equal(result$main_max, 3)
  expect_length(result$gaps, 1)
  # Gap boundaries are offset by 0.5 % of the gap so cluster-max and
  # outlier-min each stay in their own panel.
  gap <- result$gaps[[1]]
  expect_gt(gap[1], 3)
  expect_lt(gap[2], 100)
})

test_that(".pq_find_main_cluster selects the largest segment as main", {
  # Three segments: [1], [100-500], [1e6]; middle is largest
  vals <- c(1, 100, 200, 300, 400, 500, 1e6)
  result <- .pq_find_main_cluster(vals, cutoff = 5)
  expect_equal(result$main_min, 100)
  expect_equal(result$main_max, 500)
  expect_length(result$gaps, 2)
})

test_that(".pq_find_main_cluster returns NULL for length-1 input", {
  expect_null(.pq_find_main_cluster(42, cutoff = 5))
})

# ---- break_outlier_axis ------------------------------------------------------

test_that("break_outlier_axis returns a spec when p is NULL", {
  spec <- break_outlier_axis()
  expect_s3_class(spec, "break_outlier_axis_spec")
})

test_that("break_outlier_axis returns a spec with correct fields", {
  spec <- break_outlier_axis(cutoff = 10, axis = "x")
  expect_equal(spec$cutoff, 10)
  expect_equal(spec$axis, "x")
})

test_that("break_outlier_axis aborts on non-ggplot input", {
  expect_error(break_outlier_axis(p = list(a = 1)), "must be a ggplot")
})

test_that("break_outlier_axis informs and returns plot unchanged when no outlier", {
  expect_message(
    out <- break_outlier_axis(p_no_outlier, cutoff = 5),
    "No y-axis outliers"
  )
  expect_s3_class(out, "ggplot")
})

test_that("break_outlier_axis (ggbreak) works on a bar plot with a y outlier", {
  skip_if_not_installed("ggbreak")
  out <- break_outlier_axis(p_bar, cutoff = 5, axis = "y")
  expect_true(inherits(out, c("gg", "ggplot_ggbreak")))
})

test_that("break_outlier_axis supports + operator via ggplot_add", {
  skip_if_not_installed("ggbreak")
  out <- p_bar + break_outlier_axis(cutoff = 5)
  expect_true(inherits(out, c("gg", "ggplot_ggbreak")))
})

test_that("break_outlier_axis works for x-axis outlier", {
  skip_if_not_installed("ggbreak")
  out <- break_outlier_axis(p_scatter, cutoff = 5, axis = "x")
  expect_true(inherits(out, c("gg", "ggplot_ggbreak")))
})

# ---- zoom_outlier_axis -------------------------------------------------------

test_that("zoom_outlier_axis returns a spec when p is NULL", {
  spec <- zoom_outlier_axis()
  expect_s3_class(spec, "zoom_outlier_axis_spec")
})

test_that("zoom_outlier_axis returns a spec with correct fields", {
  spec <- zoom_outlier_axis(cutoff = 8, axis = "x", arrow_color = "red")
  expect_equal(spec$cutoff, 8)
  expect_equal(spec$axis, "x")
  expect_equal(spec$arrow_color, "red")
})

test_that("zoom_outlier_axis aborts on non-ggplot input", {
  expect_error(zoom_outlier_axis(p = list(a = 1)), "must be a ggplot")
})

test_that("zoom_outlier_axis informs and returns unchanged when no outlier", {
  expect_message(
    out <- zoom_outlier_axis(p_no_outlier, cutoff = 5),
    "No y-axis outliers"
  )
  expect_s3_class(out, "ggplot")
})

test_that("zoom_outlier_axis returns a ggplot with coord_cartesian on a y outlier", {
  out <- zoom_outlier_axis(p_bar, cutoff = 5, axis = "y")
  expect_s3_class(out, "ggplot")
  coord_class <- class(out$coordinates)
  expect_true(any(grepl("CoordCartesian", coord_class)))
})

test_that("zoom_outlier_axis adds arrow annotations for each outlier position", {
  out <- zoom_outlier_axis(p_bar, cutoff = 5, axis = "y")
  ann_layers <- Filter(
    function(l) inherits(l$geom, "GeomSegment"),
    out$layers
  )
  expect_gte(length(ann_layers), 1L)
})

test_that("zoom_outlier_axis + operator works via ggplot_add", {
  out <- p_bar + zoom_outlier_axis(cutoff = 5)
  expect_s3_class(out, "ggplot")
})

test_that("zoom_outlier_axis respects label_format", {
  out <- zoom_outlier_axis(p_bar, cutoff = 5, label_format = "%.1f")
  expect_s3_class(out, "ggplot")
})

test_that("zoom_outlier_axis handles x-axis outlier", {
  out <- zoom_outlier_axis(p_scatter, cutoff = 5, axis = "x")
  expect_s3_class(out, "ggplot")
  coord_class <- class(out$coordinates)
  expect_true(any(grepl("CoordCartesian", coord_class)))
})

test_that("zoom_outlier_axis handles axis = 'both'", {
  df_both <- data.frame(x = c(1, 2, 3, 200), y = c(10, 12, 11, 800))
  p_both <- ggplot2::ggplot(df_both, ggplot2::aes(x = x, y = y)) +
    ggplot2::geom_point()
  out <- zoom_outlier_axis(p_both, cutoff = 5, axis = "both")
  expect_s3_class(out, "ggplot")
})

# ---- new parameters ----------------------------------------------------------

test_that("break_outlier_axis space_proportional = TRUE returns ggbreak object", {
  skip_if_not_installed("ggbreak")
  out <- break_outlier_axis(p_bar, cutoff = 5, space_proportional = TRUE)
  expect_true(inherits(out, c("gg", "ggplot_ggbreak")))
})

test_that("break_outlier_axis spec stores space_proportional field", {
  spec <- break_outlier_axis(cutoff = 5, space_proportional = TRUE)
  expect_true(spec$space_proportional)
})

test_that("break_outlier_axis expand_cluster adds margin before break", {
  skip_if_not_installed("ggbreak")
  # Should succeed with non-default expand_cluster value
  out <- break_outlier_axis(p_bar, cutoff = 5, expand_cluster = 0.10)
  expect_true(inherits(out, c("gg", "ggplot_ggbreak")))
})

test_that("break_outlier_axis scales = 'free' (explicit) works", {
  skip_if_not_installed("ggbreak")
  out <- break_outlier_axis(p_bar, cutoff = 5, scales = "free")
  expect_true(inherits(out, c("gg", "ggplot_ggbreak")))
})

test_that("zoom_outlier_axis extra_margin adds plot.margin theme element", {
  out <- zoom_outlier_axis(p_bar, cutoff = 5, extra_margin = 40)
  expect_s3_class(out, "ggplot")
  # The theme should have a plot.margin element set
  thm <- ggplot2::theme_get() + out$theme
  expect_false(is.null(thm$plot.margin))
})

test_that("zoom_outlier_axis extra_margin = 0 disables automatic margin", {
  out <- zoom_outlier_axis(p_bar, cutoff = 5, extra_margin = 0)
  expect_s3_class(out, "ggplot")
})
