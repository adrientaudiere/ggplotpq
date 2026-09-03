data(data_fungi_mini, package = "MiscMetabar")
ps_mini <- data_fungi_mini

quiet <- function(expr) {
  suppressWarnings(suppressMessages(expr))
}

with_var <- function(physeq, name, values) {
  phyloseq::sample_data(physeq)[[name]] <- values
  physeq
}

n_samp <- phyloseq::nsamples(ps_mini)

# ---- qualitative -------------------------------------------------------------

test_that("palette_sam_pq returns a pq_palette for a character variable", {
  ps <- with_var(ps_mini, "grp", rep(c("a", "b", "c"), length.out = n_samp))
  pal <- quiet(palette_sam_pq(ps, "grp"))
  expect_s3_class(pal, "pq_palette")
  expect_identical(names(pal), c("a", "b", "c", "NA"))
  expect_identical(attr(pal, "pq_slot"), "sam_data")
  expect_identical(unname(pal[["NA"]]), "grey85")
})

test_that("palette_sam_pq honours factor levels rather than the alphabet", {
  ps <- with_var(
    ps_mini,
    "grp",
    factor(
      rep(c("T0", "SS", "Inoc"), length.out = n_samp),
      levels = c("T0", "SS", "Inoc")
    )
  )
  pal <- quiet(palette_sam_pq(ps, "grp"))
  expect_identical(names(pal)[1:3], c("T0", "SS", "Inoc"))

  alpha <- quiet(palette_sam_pq(ps, "grp", order_by = "alpha"))
  expect_identical(names(alpha)[1:3], c("Inoc", "SS", "T0"))
})

test_that("palette_sam_pq can order by frequency", {
  ps <- with_var(
    ps_mini,
    "grp",
    rep(c("rare", "common", "common"), length.out = n_samp)
  )
  pal <- quiet(palette_sam_pq(ps, "grp", order_by = "frequency"))
  expect_identical(names(pal)[1], "common")
})

test_that("palette_sam_pq applies reorder and alternate_lightness", {
  ps <- with_var(ps_mini, "grp", rep(letters[1:6], length.out = n_samp))
  plain <- quiet(palette_sam_pq(ps, "grp"))
  reord <- quiet(palette_sam_pq(ps, "grp", reorder = TRUE))
  alt <- quiet(palette_sam_pq(ps, "grp", alternate_lightness = TRUE))
  expect_setequal(unname(plain), unname(reord))
  expect_false(identical(unname(plain), unname(reord)))
  expect_false(identical(unname(plain), unname(alt)))
})

# ---- sequential --------------------------------------------------------------

test_that("type auto picks sequential for numeric and ordered variables", {
  ps <- with_var(ps_mini, "num", rep(1:4, length.out = n_samp))
  ps <- with_var(
    ps,
    "ord",
    factor(
      rep(c("lo", "mid", "hi"), length.out = n_samp),
      levels = c("lo", "mid", "hi"),
      ordered = TRUE
    )
  )
  ps <- with_var(ps, "chr", rep(c("x", "y", "z"), length.out = n_samp))

  expect_identical(
    quiet(palette_sam_pq(ps, "num")),
    quiet(palette_sam_pq(ps, "num", type = "sequential"))
  )
  expect_identical(
    quiet(palette_sam_pq(ps, "ord")),
    quiet(palette_sam_pq(ps, "ord", type = "sequential"))
  )
  expect_identical(
    quiet(palette_sam_pq(ps, "chr")),
    quiet(palette_sam_pq(ps, "chr", type = "qualitative"))
  )
})

test_that("a sequential ramp follows the numeric order of the variable", {
  ps <- with_var(ps_mini, "num", rep(c(0, 5, 10, 15), length.out = n_samp))
  pal <- quiet(palette_sam_pq(ps, "num"))
  expect_identical(names(pal), c("0", "5", "10", "15", "NA"))
  l <- .pq_hex_oklch(unname(pal[c("0", "5", "10", "15")]))[, "l"]
  expect_identical(order(l), 1:4)
})

test_that("a sequential palette holds one hue and increasing lightness", {
  ps <- with_var(ps_mini, "num", rep(1:5, length.out = n_samp))
  pal <- quiet(palette_sam_pq(ps, "num", type = "sequential"))
  lv <- setdiff(names(pal), "NA")
  m <- .pq_hex_oklch(unname(pal[lv]))

  expect_lt(diff(range(m[, "h"])), 3)
  expect_identical(order(m[, "l"]), seq_along(lv))
})

test_that("a sequential palette takes its hue from the palette argument", {
  ps <- with_var(ps_mini, "num", rep(1:4, length.out = n_samp))
  pal <- quiet(palette_sam_pq(ps, "num", palette = "#aa4c26"))
  lv <- setdiff(names(pal), "NA")
  expect_equal(
    .pq_hex_oklch(unname(pal[lv]))[, "h"],
    rep(.pq_hex_oklch("#aa4c26")[, "h"], length(lv)),
    tolerance = 0.05,
    ignore_attr = TRUE
  )
})

test_that("sequential refuses the options that would destroy its order", {
  ps <- with_var(ps_mini, "num", rep(1:4, length.out = n_samp))
  expect_error(
    palette_sam_pq(ps, "num", type = "sequential", reorder = TRUE),
    "cannot be combined"
  )
  expect_error(
    palette_sam_pq(ps, "num", type = "sequential", alternate_lightness = TRUE),
    "cannot be combined"
  )
  ps <- with_var(ps, "par", rep(c("P", "Q"), length.out = n_samp))
  expect_error(
    palette_sam_pq(ps, "num", type = "sequential", nested = "par"),
    "both drive lightness"
  )
})

# ---- nested ------------------------------------------------------------------

test_that("palette_sam_pq nests hue by parent variable", {
  ps <- with_var(
    ps_mini,
    "site",
    rep(c("s1", "s2", "s3", "s4"), length.out = n_samp)
  )
  ps <- with_var(
    ps,
    "region",
    ifelse(
      phyloseq::sample_data(ps)$site %in% c("s1", "s2"),
      "north",
      "south"
    )
  )
  pal <- quiet(palette_sam_pq(ps, "site", nested = "region"))
  expect_identical(attr(pal, "pq_parent"), "region")
  expect_length(attr(pal, "pq_parent_colors"), 2)

  hue <- .pq_hex_oklch(unname(pal[c("s1", "s2", "s3", "s4")]))[, "h"]
  expect_lt(abs(hue[1] - hue[2]), 3)
  expect_lt(abs(hue[3] - hue[4]), 3)
  expect_gt(abs(hue[1] - hue[3]), 10)
})

# ---- validation --------------------------------------------------------------

test_that("palette_sam_pq validates var, nested and type", {
  expect_error(palette_sam_pq(ps_mini, "nope"), "must be one of the sample")
  expect_error(
    palette_sam_pq(ps_mini, "Height", nested = "nope"),
    "must be one of the sample"
  )
  expect_error(
    palette_sam_pq(ps_mini, "Height", nested = "Height"),
    "must differ"
  )
  expect_error(palette_sam_pq(ps_mini, "Height", type = "diverging"))
})

# ---- storing in the object ---------------------------------------------------

test_that("add_to_phyloseq writes a column and returns the object", {
  ps <- with_var(ps_mini, "grp", rep(c("a", "b"), length.out = n_samp))
  out <- quiet(palette_sam_pq(ps, "grp", add_to_phyloseq = TRUE))
  expect_s4_class(out, "phyloseq")
  expect_true("grp_color" %in% phyloseq::sample_variables(out))
  expect_identical(phyloseq::nsamples(out), n_samp)
})

test_that("a stored palette is read back and survives sample pruning", {
  ps <- with_var(ps_mini, "grp", rep(c("a", "b", "c"), length.out = n_samp))
  ps <- quiet(palette_sam_pq(ps, "grp", add_to_phyloseq = TRUE))

  expect_message(palette_sam_pq(ps, "grp"), "Reusing the palette")

  keep <- phyloseq::sample_data(ps)$grp != "b"
  sub <- phyloseq::prune_samples(keep, ps)
  full_pal <- quiet(palette_sam_pq(ps, "grp"))
  sub_pal <- quiet(palette_sam_pq(sub, "grp"))

  expect_false("b" %in% names(sub_pal))
  common <- intersect(names(full_pal), names(sub_pal))
  expect_identical(full_pal[common], sub_pal[common])
})

test_that("writing twice is blocked, and suffix lets both coexist", {
  ps <- with_var(ps_mini, "grp", rep(c("a", "b"), length.out = n_samp))
  ps <- quiet(palette_sam_pq(ps, "grp", add_to_phyloseq = TRUE))
  expect_error(
    quiet(palette_sam_pq(ps, "grp", add_to_phyloseq = TRUE)),
    "already exists"
  )
  ps2 <- quiet(palette_sam_pq(
    ps,
    "grp",
    palette = "oklch",
    add_to_phyloseq = TRUE,
    suffix = "_color_alt"
  ))
  expect_true(all(
    c("grp_color", "grp_color_alt") %in% phyloseq::sample_variables(ps2)
  ))
})

# ---- integration -------------------------------------------------------------

test_that("the palette colours a plot through the + operator", {
  ps <- with_var(ps_mini, "grp", rep(c("a", "b", "c"), length.out = n_samp))
  pal <- quiet(palette_sam_pq(ps, "grp"))
  df <- data.frame(x = c("a", "b", "c"), y = 1:3, g = c("a", "b", "c"))
  p <- ggplot(df, aes(x, y, fill = g)) + geom_col() + pal
  expect_identical(
    ggplot_build(p)$data[[1]]$fill,
    unname(pal[c("a", "b", "c")])
  )
})
