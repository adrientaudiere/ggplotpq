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


# ---- .pq_reorder_colors_vec --------------------------------------------------

pal6 <- stats::setNames(
  c("#dc863b", "#2e7891", "#b4dfa7", "#aa4c26", "#774fa0", "#c8a734"),
  letters[1:6]
)

test_that(".pq_reorder_colors_vec permutes the colours without changing the set", {
  got <- .pq_reorder_colors_vec(pal6)
  expect_setequal(unname(got), unname(pal6))
  expect_identical(names(got), names(pal6))
  expect_false(identical(unname(got), unname(pal6)))
})

test_that(".pq_reorder_colors_vec is deterministic", {
  expect_identical(.pq_reorder_colors_vec(pal6), .pq_reorder_colors_vec(pal6))
})

test_that(".pq_reorder_colors_vec passes through vectors of length 0 or 1", {
  expect_identical(.pq_reorder_colors_vec(pal6[1]), pal6[1])
  expect_identical(.pq_reorder_colors_vec(pal6[0]), pal6[0])
})

test_that(".pq_reorder_colors_vec puts the most distinct colours first", {
  got <- .pq_reorder_colors_vec(pal6)
  lab <- function(x) {
    grDevices::convertColor(t(grDevices::col2rgb(x)) / 255, "sRGB", "Lab")
  }
  d <- as.matrix(stats::dist(lab(unname(got))))
  consecutive <- d[cbind(1:5, 2:6)]
  all_pairs <- d[upper.tri(d)]
  expect_gt(mean(consecutive), mean(all_pairs))
})

test_that(".pq_reorder_colors_vec reacts to the colorblind flag", {
  expect_false(identical(
    .pq_reorder_colors_vec(pal6, colorblind = TRUE),
    .pq_reorder_colors_vec(pal6, colorblind = FALSE)
  ))
})

test_that(".pq_reorder_colors_vec rejects an unknown colour space", {
  expect_error(.pq_reorder_colors_vec(pal6, space = "hcl"))
})

# ---- .pq_alternate_lightness -------------------------------------------------

test_that("alternate_lightness changes the colours but keeps the names", {
  got <- .pq_reorder_colors_vec(pal6, alternate_lightness = TRUE)
  plain <- .pq_reorder_colors_vec(pal6)
  expect_identical(names(got), names(pal6))
  expect_false(identical(unname(got), unname(plain)))
})

step_sizes <- function(colors, space, amount = 0.15) {
  alt <- .pq_alternate_lightness(colors, amount = amount, space = space)
  abs(.pq_hex_oklch(alt)[, "l"] - .pq_hex_oklch(colors)[, "l"])
}

test_that("the oklch space moves every colour by the requested perceived step", {
  # Mid-lightness colours, none close enough to the L = 1 ceiling to be
  # clamped. Measured spread here is under 0.002; sRGB is 30x worse.
  mid <- c("#774fa0", "#c8a734", "#2e7891", "#dc863b", "#aa4c26")

  steps <- step_sizes(mid, "oklch")
  expect_equal(
    steps,
    rep(0.15, length(mid)),
    tolerance = 0.02,
    ignore_attr = TRUE
  )
  expect_lt(diff(range(steps)), 0.005)
})

test_that("the sRGB space delivers an uneven and undersized step", {
  # This is the whole argument for OKLCH: a nominal 0.15 lands between 0.06
  # and 0.09 depending on the hue, so the luminance cue is inconsistent.
  mid <- c("#774fa0", "#c8a734", "#2e7891", "#dc863b", "#aa4c26")

  steps <- step_sizes(mid, "srgb")
  expect_lt(mean(steps), 0.12)
  expect_gt(diff(range(steps)), 5 * diff(range(step_sizes(mid, "oklch"))))
})

test_that("lightening a near-white colour stops at the lightness ceiling", {
  # #b4dfa7 sits at L = 0.86, so +0.15 would overshoot 1 and is clamped.
  steps <- step_sizes(c("#b4dfa7", "#2e7891"), "oklch")
  expect_lt(steps[1], 0.15)
  expect_equal(steps[2], 0.15, tolerance = 0.02, ignore_attr = TRUE)
})

test_that("alternate_lightness in oklch stays inside the sRGB gamut", {
  alt <- .pq_alternate_lightness(unname(pal6), amount = 0.4, space = "oklch")
  expect_true(all(.pq_in_gamut(.pq_hex_oklch(alt))))
  expect_true(all(grepl("^#[0-9A-Fa-f]{6}$", alt)))
})

test_that("alternate_lightness alternates direction", {
  l0 <- .pq_hex_oklch(unname(pal6))[, "l"]
  l1 <- .pq_hex_oklch(.pq_alternate_lightness(unname(pal6), 0.15, "oklch"))[,
    "l"
  ]
  expect_true(all(sign(l1 - l0) == rep(c(1, -1), 3)))
})
