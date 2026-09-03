in_gamut_refs <- c("#dc863b", "#2e7891", "#faefd1", "#003f5f", "#b4dfa7")

# An orange that sRGB cannot represent at this chroma.
oog_orange <- cbind(l = 0.45, c = 0.30, h = 58)

# ---- .pq_oklch_to_srgb -------------------------------------------------------

test_that(".pq_oklch_to_srgb reproduces known sRGB values for in-gamut colours", {
  expected <- t(grDevices::col2rgb(in_gamut_refs)) / 255
  got <- .pq_oklch_to_srgb(.pq_hex_oklch(in_gamut_refs))
  expect_equal(unname(got), unname(expected), tolerance = 1e-3)
})

test_that(".pq_oklch_to_srgb returns out-of-range channels out of gamut", {
  got <- .pq_oklch_to_srgb(oog_orange)
  expect_true(any(got < 0 | got > 1))
})

# ---- .pq_in_gamut ------------------------------------------------------------

test_that(".pq_in_gamut separates in- from out-of-gamut colours", {
  expect_true(all(.pq_in_gamut(.pq_hex_oklch(in_gamut_refs))))
  expect_false(.pq_in_gamut(oog_orange))
})

test_that(".pq_in_gamut is vectorised", {
  m <- rbind(.pq_hex_oklch("#2e7891"), oog_orange)
  expect_identical(.pq_in_gamut(m), c(TRUE, FALSE))
})

# ---- .pq_gamut_map_oklch -----------------------------------------------------

test_that(".pq_gamut_map_oklch leaves in-gamut colours untouched", {
  m <- .pq_hex_oklch(in_gamut_refs)
  expect_identical(.pq_gamut_map_oklch(m), m)
})

test_that(".pq_gamut_map_oklch brings every colour into gamut", {
  m <- cbind(
    l = c(0.45, 0.85, 0.30, 0.62),
    c = c(0.30, 0.25, 0.20, 0.13),
    h = c(58, 250, 320, 145)
  )
  expect_true(all(.pq_in_gamut(.pq_gamut_map_oklch(m))))
})

test_that(".pq_gamut_map_oklch preserves lightness and hue, reduces only chroma", {
  mapped <- .pq_gamut_map_oklch(oog_orange)
  expect_equal(mapped[, "l"], oog_orange[, "l"])
  expect_equal(mapped[, "h"], oog_orange[, "h"])
  expect_lt(mapped[, "c"], oog_orange[, "c"])
})

test_that("gamut mapping avoids the hue shift that naive sRGB clamping causes", {
  target_h <- oog_orange[, "h"]
  # farver clamps to the sRGB cube, turning this orange into a pure red.
  naive_h <- .pq_hex_oklch(farver::encode_colour(oog_orange, from = "oklch"))[,
    "h"
  ]
  mapped_h <- .pq_hex_oklch(.pq_oklch_hex(oog_orange))[, "h"]

  expect_gt(abs(naive_h - target_h), 20)
  expect_lt(abs(mapped_h - target_h), 2)
})

test_that("gamut mapping keeps distinct requests distinct", {
  # Naive clamping sends 79 distinct OKLCH requests in the cyan region to a
  # single #00FFFF. A nested gradient built there would be uniformly flat.
  m <- cbind(l = c(0.85, 0.90, 0.95), c = 0.30, h = 200)

  expect_length(unique(farver::encode_colour(m, from = "oklch")), 1)
  expect_length(unique(.pq_oklch_hex(m)), 3)
})

# ---- .pq_as_oklch_matrix -----------------------------------------------------

test_that(".pq_as_oklch_matrix promotes a bare vector to a one-row matrix", {
  m <- .pq_as_oklch_matrix(c(0.6, 0.1, 200))
  expect_equal(dim(m), c(1L, 3L))
  expect_identical(colnames(m), c("l", "c", "h"))
})

test_that(".pq_as_oklch_matrix rejects a wrong number of columns", {
  expect_error(.pq_as_oklch_matrix(cbind(1, 2)), "exactly 3 columns")
})

# ---- .pq_pal_oklch -----------------------------------------------------------

test_that(".pq_pal_oklch returns n valid, distinct, in-gamut hex colours", {
  for (n in c(1, 3, 8, 12, 25)) {
    pal <- .pq_pal_oklch(n)
    expect_length(pal, n)
    expect_true(all(grepl("^#[0-9A-Fa-f]{6}$", pal)))
    expect_length(unique(pal), n)
    expect_true(all(.pq_in_gamut(.pq_hex_oklch(pal))))
  }
})

test_that(".pq_pal_oklch warns past 25 colours and stops past 40", {
  expect_no_warning(.pq_pal_oklch(25))
  expect_warning(.pq_pal_oklch(26), "hard to tell apart")
  expect_warning(pal40 <- .pq_pal_oklch(40))
  expect_length(pal40, 40)
  expect_error(.pq_pal_oklch(41), "more than 40")
})

test_that(".pq_pal_oklch is deterministic", {
  expect_identical(.pq_pal_oklch(12), .pq_pal_oklch(12))
})

test_that(".pq_pal_oklch holds lightness constant in the 'hue' regime", {
  l <- .pq_hex_oklch(.pq_pal_oklch(6, vary = "hue"))[, "l"]
  expect_equal(max(l) - min(l), 0, tolerance = 0.02)
})

test_that(".pq_pal_oklch varies lightness in the 'all' regime", {
  l <- .pq_hex_oklch(.pq_pal_oklch(12, vary = "all"))[, "l"]
  expect_gt(max(l) - min(l), 0.1)
})

test_that(".pq_pal_oklch switches regime at n = 8", {
  expect_identical(.pq_pal_oklch(8), .pq_pal_oklch(8, vary = "hue"))
  expect_identical(.pq_pal_oklch(9), .pq_pal_oklch(9, vary = "all"))
})

test_that(".pq_pal_oklch rejects invalid n", {
  expect_error(.pq_pal_oklch(0), "positive number")
  expect_error(.pq_pal_oklch(NA), "positive number")
  expect_error(.pq_pal_oklch(c(2, 3)), "positive number")
})

# ---- .pq_gradient_oklch ------------------------------------------------------

test_that(".pq_gradient_oklch returns one in-gamut colour per position", {
  g <- .pq_gradient_oklch("#2e7891", positions = 1:5)
  expect_length(g, 5)
  expect_true(all(.pq_in_gamut(.pq_hex_oklch(g))))
})

test_that(".pq_gradient_oklch keeps hue and increases lightness with rank", {
  base_h <- .pq_hex_oklch("#2e7891")[, "h"]
  got <- .pq_hex_oklch(.pq_gradient_oklch("#2e7891", positions = 1:5))
  expect_true(all(abs(got[, "h"] - base_h) < 2))
  expect_identical(order(got[, "l"]), 1:5)
})

test_that(".pq_gradient_oklch is stable across subsets - the ggnested defect", {
  full <- .pq_gradient_oklch("#2e7891", positions = 1:6, n_total = 6)
  # Levels 2, 4 and 5 survive a filtering step; the other three are gone.
  kept <- c(2L, 4L, 5L)
  subset <- .pq_gradient_oklch("#2e7891", positions = kept, n_total = 6)
  expect_identical(subset, full[kept])
})

test_that(".pq_gradient_oklch places a lone level mid-ramp", {
  g <- .pq_gradient_oklch("#2e7891", positions = 1, n_total = 1)
  expect_length(g, 1)
  mid <- .pq_hex_oklch(g)[, "l"]
  expect_equal(mid, mean(c(0.35, 0.82)), tolerance = 0.02)
})

test_that(".pq_gradient_oklch accepts an OKLCH matrix as base", {
  expect_identical(
    .pq_gradient_oklch(.pq_hex_oklch("#2e7891"), positions = 1:4),
    .pq_gradient_oklch("#2e7891", positions = 1:4)
  )
})

test_that(".pq_gradient_oklch rejects inconsistent arguments", {
  expect_error(
    .pq_gradient_oklch(c("#2e7891", "#dc863b"), positions = 1:3),
    "a single colour"
  )
  expect_error(
    .pq_gradient_oklch("#2e7891", positions = 1:5, n_total = 3),
    "at least"
  )
  expect_error(
    .pq_gradient_oklch("#2e7891", positions = numeric(0)),
    "non-empty"
  )
})
