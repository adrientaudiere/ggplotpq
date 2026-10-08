df_long <- data.frame(
  sample = paste0("Site_forest_", sprintf("%02d", 1:12)),
  reads = seq(100, 210, by = 10)
)
p_long <- ggplot2::ggplot(df_long, ggplot2::aes(x = sample, y = reads)) +
  ggplot2::geom_col() +
  ggplot2::labs(title = "Reads per sample")

# ---- helpers -----------------------------------------------------------------

test_that(".rf_just_values resolves character and numeric justification", {
  expect_equal(.rf_just_values("left", NULL, NULL), list(h = 0, v = 0.5))
  expect_equal(
    .rf_just_values(c("right", "top"), NULL, NULL),
    list(h = 1, v = 1)
  )
  expect_equal(.rf_just_values("centre", 0.2, NULL), list(h = 0.2, v = 0.5))
})

test_that(".rf_polygons_overlap detects rotated box overlaps", {
  sq <- function(x, y) {
    cbind(x = c(x, x + 1, x + 1, x), y = c(y, y, y + 1, y + 1))
  }
  expect_true(.rf_polygons_overlap(sq(0, 0), sq(0.5, 0.5)))
  expect_false(.rf_polygons_overlap(sq(0, 0), sq(2, 0)))
  diamond <- cbind(x = c(1.6, 2.1, 1.6, 1.1), y = c(1.1, 1.6, 2.1, 1.6))
  expect_false(.rf_polygons_overlap(sq(0, 0), diamond))
})

test_that(".rf_resolve_dims converts units and falls back to 7 x 5 in", {
  expect_equal(.rf_resolve_dims(254, 127, "mm", 300), c(10, 5))
  expect_equal(.rf_resolve_dims(600, 300, "px", 300), c(2, 1))
  skip_if(grDevices::dev.cur() > 1, "a graphics device is open")
  withr::local_options(knitr.in.progress = NULL)
  expect_message(dims <- .rf_resolve_dims(NULL, NULL, "in", 300), "7 x 5 in")
  expect_equal(dims, c(7, 5))
  expect_equal(suppressMessages(.rf_resolve_dims(NULL, 3, "in", 300)), c(7, 3))
})

test_that(".rf_resolve_dims reads the knitr chunk size", {
  skip_if_not_installed("knitr")
  withr::local_options(knitr.in.progress = TRUE)
  knitr::opts_current$set(fig.width = 4, fig.height = 3)
  withr::defer(knitr::opts_current$restore())
  expect_equal(.rf_resolve_dims(NULL, NULL, "in", 300), c(4, 3))
  expect_equal(.rf_resolve_dims(NULL, 2, "in", 300), c(4, 2))
})

# ---- resize_fonts ------------------------------------------------------------

test_that("resize_fonts shrinks overlapping axis labels", {
  res <- resize_fonts(p_long, width = 4, height = 3)
  expect_s3_class(res, "ggplot")
  expect_lt(attr(res, "font_scale"), 1)
  expect_gte(attr(res, "font_scale"), 0.3)
})

test_that("resize_fonts leaves a plot that already fits unchanged", {
  res <- resize_fonts(p_long, width = 20, height = 6)
  expect_equal(attr(res, "font_scale"), 1)
})

test_that("resize_fonts output has no overlap at the requested size", {
  res <- resize_fonts(p_long, width = 4, height = 3, device = "pdf")
  grDevices::pdf(NULL, width = 4, height = 3)
  boxes <- .rf_text_boxes(res)
  grDevices::dev.off()
  expect_length(.rf_find_overlaps(boxes, 4, 3, 0.5 / 72), 0)
})

test_that("resize_fonts does not modify the input plot", {
  p_txt <- p_long + ggplot2::geom_text(ggplot2::aes(label = reads), size = 3)
  res <- resize_fonts(p_txt, width = 4, height = 3, geom_text = TRUE)
  expect_equal(p_txt$layers[[2]]$aes_params$size, 3)
  expect_lt(res$layers[[2]]$aes_params$size, 3)
  expect_null(attr(p_txt, "font_scale"))
})

test_that("resize_fonts ignores categories set to FALSE", {
  res <- resize_fonts(p_long, width = 4, height = 3, axis_text = FALSE)
  expect_equal(attr(res, "font_scale"), 1)
})

test_that("resize_fonts with resize_all shrinks unchecked text too", {
  p_txt <- p_long + ggplot2::geom_text(ggplot2::aes(label = reads), size = 3)
  res <- resize_fonts(p_txt, width = 4, height = 3, resize_all = TRUE)
  k <- attr(res, "font_scale")
  expect_lt(k, 1)
  expect_equal(res$layers[[2]]$aes_params$size, 3 * k)
  res_default <- resize_fonts(p_txt, width = 4, height = 3)
  expect_equal(res_default$layers[[2]]$aes_params$size, 3)
})

test_that("resize_fonts works with the package themes and subclassed elements", {
  expect_lt(
    attr(
      resize_fonts(p_long + theme_pq_minimal(), width = 4, height = 3),
      "font_scale"
    ),
    1
  )
  skip_if_not_installed("ggtext")
  p_md <- p_long + ggplot2::theme(plot.title = ggtext::element_markdown())
  res <- resize_fonts(p_md, width = 4, height = 3)
  expect_lt(attr(res, "font_scale"), 1)
  expect_s3_class(ggplot2::ggplotGrob(res), "gtable")
})

test_that("resize_fonts works on patchwork assemblies", {
  skip_if_not_installed("patchwork")
  pw <- patchwork::wrap_plots(p_long, p_long, ncol = 1) +
    patchwork::plot_annotation(title = "Two panels")
  res <- resize_fonts(pw, width = 4, height = 6)
  expect_s3_class(res, "patchwork")
  expect_lt(attr(res, "font_scale"), 1)
})

test_that("resize_fonts warns when overlaps remain at min_scale", {
  df_same <- data.frame(x = c(1, 1), y = c(1, 1), lab = c("aaaa", "bbbb"))
  p_same <- ggplot2::ggplot(df_same, ggplot2::aes(x, y, label = lab)) +
    ggplot2::geom_text()
  expect_warning(
    res <- resize_fonts(p_same, width = 4, height = 3, geom_text = TRUE),
    "still overlaps"
  )
  expect_equal(attr(res, "font_scale"), 0.3)
})

test_that("resize_fonts validates its arguments", {
  expect_error(resize_fonts("not a plot", width = 4, height = 3), "ggplot")
  expect_error(
    resize_fonts(p_long, width = 4, height = 3, min_scale = 2),
    "min_scale"
  )
})
