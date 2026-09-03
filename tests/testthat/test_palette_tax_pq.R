data(data_fungi_mini, package = "MiscMetabar")
ps_mini <- data_fungi_mini

quiet <- function(expr) {
  suppressWarnings(suppressMessages(expr))
}

# ---- flat palettes -----------------------------------------------------------

test_that("palette_tax_pq returns a pq_palette with the reserved entry", {
  pal <- quiet(palette_tax_pq(ps_mini, "Order", n = 6))
  expect_s3_class(pal, "pq_palette")
  expect_length(pal, 7)
  expect_identical(unname(pal[["other"]]), "grey85")
  expect_identical(attr(pal, "pq_var"), "Order")
  expect_identical(attr(pal, "pq_slot"), "tax_table")
})

test_that("palette_tax_pq lists levels alphabetically by default", {
  pal <- quiet(palette_tax_pq(ps_mini, "Order", n = 6))
  expect_identical(
    setdiff(names(pal), "other"),
    sort(.pq_tax_top(ps_mini, "Order", 6))
  )
})

test_that("palette_tax_pq selects by weight but orders separately", {
  # The six coloured levels are the six most abundant, whatever the ordering.
  top6 <- .pq_tax_top(ps_mini, "Order", 6)
  for (ord in c("alpha", "abundance", "n_taxa")) {
    pal <- quiet(palette_tax_pq(ps_mini, "Order", n = 6, order_by = ord))
    expect_setequal(setdiff(names(pal), "other"), top6)
  }
})

test_that("order_by changes which colour each level receives", {
  alpha <- quiet(palette_tax_pq(ps_mini, "Order", n = 6))
  abund <- quiet(
    palette_tax_pq(ps_mini, "Order", n = 6, order_by = "abundance")
  )
  expect_setequal(unname(alpha), unname(abund))
  expect_false(identical(alpha[names(alpha)], abund[names(alpha)]))
  expect_identical(
    setdiff(names(abund), "other"),
    .pq_tax_top(ps_mini, "Order", 6)
  )
})

test_that("filter_by selects on molecular abundance or on number of taxa", {
  ab <- quiet(palette_tax_pq(ps_mini, "Family", n = 6, filter_by = "abundance"))
  nt <- quiet(palette_tax_pq(ps_mini, "Family", n = 6, filter_by = "n_taxa"))
  expect_setequal(
    setdiff(names(ab), "other"),
    .pq_tax_top(ps_mini, "Family", 6, by = "abundance")
  )
  expect_setequal(
    setdiff(names(nt), "other"),
    .pq_tax_top(ps_mini, "Family", 6, by = "n_taxa")
  )
  expect_false(identical(names(ab), names(nt)))
})

test_that("n = NULL colours every level of the rank", {
  pal <- quiet(palette_tax_pq(ps_mini, "Order"))
  all_levels <- sort(unique(stats::na.omit(
    as.character(ps_mini@tax_table@.Data[, "Order"])
  )))
  expect_identical(setdiff(names(pal), "other"), all_levels)
})

test_that("filter_by is ignored when n is NULL", {
  ref <- quiet(palette_tax_pq(ps_mini, "Order"))
  for (fb in c("abundance", "n_taxa", "mean", "prevalence")) {
    expect_identical(
      quiet(palette_tax_pq(ps_mini, "Order", filter_by = fb)),
      ref
    )
  }
  # Not even validated, since it is never consulted.
  expect_no_error(quiet(palette_tax_pq(ps_mini, "Order", filter_by = "nope")))
})

test_that("filter_by is validated as soon as n filters", {
  expect_error(palette_tax_pq(ps_mini, "Order", n = 4, filter_by = "nope"))
})

test_that("setting n turns the dropped levels grey", {
  full <- quiet(palette_tax_pq(ps_mini, "Order"))
  cut <- quiet(palette_tax_pq(ps_mini, "Order", n = 4))
  expect_length(setdiff(names(cut), "other"), 4)
  expect_lt(length(cut), length(full))
  expect_setequal(
    setdiff(names(cut), "other"),
    .pq_tax_top(ps_mini, "Order", 4)
  )
})

test_that("palette_tax_pq caps n at the number of available levels", {
  pal <- quiet(palette_tax_pq(ps_mini, "Order", n = 500))
  n_levels <- length(unique(stats::na.omit(
    as.character(ps_mini@tax_table@.Data[, "Order"])
  )))
  expect_length(pal, n_levels + 1)
})

test_that("palette_tax_pq honours filter_by, palette and add", {
  pal <- quiet(palette_tax_pq(
    ps_mini,
    "Order",
    n = 4,
    filter_by = "prevalence",
    palette = "Picasso",
    add = c(other = "white", "NA" = "black")
  ))
  expect_identical(unname(pal[["other"]]), "white")
  expect_identical(unname(pal[["NA"]]), "black")
  expect_true(all(unname(pal[1:4]) %in% idest_pal$Picasso[[1]]))
})

test_that("palette_tax_pq applies reorder and alternate_lightness separately", {
  plain <- quiet(palette_tax_pq(ps_mini, "Order", n = 6))
  reord <- quiet(
    palette_tax_pq(ps_mini, "Order", n = 6, reorder = TRUE)
  )
  alt <- quiet(
    palette_tax_pq(ps_mini, "Order", n = 6, alternate_lightness = TRUE)
  )

  expect_setequal(unname(plain), unname(reord))
  expect_false(identical(unname(plain), unname(reord)))
  expect_false(identical(unname(plain), unname(alt)))
  expect_false(identical(unname(reord), unname(alt)))
})

test_that("palette_tax_pq validates rank and nested", {
  expect_error(palette_tax_pq(ps_mini, "nope"), "must be one of the ranks")
  expect_error(
    palette_tax_pq(ps_mini, "Order", nested = "nope"),
    "must be one of the ranks"
  )
  expect_error(
    palette_tax_pq(ps_mini, "Order", nested = "Order"),
    "must differ"
  )
})

# ---- nested palettes ---------------------------------------------------------

test_that("palette_tax_pq nests hue by parent and lightness by leaf", {
  pal <- quiet(
    palette_tax_pq(ps_mini, "Family", n = 12, nested = "Class")
  )
  expect_identical(attr(pal, "pq_parent"), "Class")
  expect_gt(length(attr(pal, "pq_parent_colors")), 1)

  leaves <- setdiff(names(pal), "other")
  parents <- .pq_parents_of(
    .pq_slot_df(ps_mini, "tax_table"),
    "Family",
    "Class",
    leaves
  )
  hue <- .pq_hex_oklch(unname(pal[leaves]))[, "h"]
  # Within a parent the hue is constant; across parents it is not.
  spread_within <- tapply(hue, parents, function(x) diff(range(x)))
  expect_true(all(spread_within < 3))
  expect_gt(diff(range(tapply(hue, parents, mean))), 10)
})

test_that("palette_tax_pq warns when one parent holds too many leaves", {
  # 19 of the 20 Families of data_fungi_mini sit in Agaricomycetes: their
  # shades are separated by less than the perceptual threshold.
  expect_warning(
    suppressMessages(
      palette_tax_pq(ps_mini, "Family", n = 20, nested = "Class")
    ),
    "hard to tell apart"
  )
  # Four leaves under one parent is comfortable.
  expect_no_warning(
    suppressMessages(
      palette_tax_pq(ps_mini, "Order", n = 4, nested = "Class")
    )
  )
})

test_that("palette_tax_pq refuses reorder or alternate_lightness when nested", {
  expect_error(
    palette_tax_pq(ps_mini, "Family", nested = "Class", reorder = TRUE),
    "cannot be combined"
  )
  expect_error(
    palette_tax_pq(
      ps_mini,
      "Family",
      nested = "Class",
      alternate_lightness = TRUE
    ),
    "cannot be combined"
  )
})

# `data_fungi_mini` holds exactly 20 Families and 9 Orders, and an abundance
# filter drops none of them - a subset built that way would make every
# stability test pass trivially. Drop named levels instead.
drop_levels <- function(physeq, rank, levels) {
  keep <- !as.character(physeq@tax_table@.Data[, rank]) %in% levels
  phyloseq::prune_taxa(keep, physeq)
}

fam_top <- .pq_tax_top(ps_mini, "Family", 20)
sub_ps <- drop_levels(ps_mini, "Family", fam_top[c(2, 5, 9)])

test_that("the test subset really removes levels", {
  expect_length(.pq_tax_top(sub_ps, "Family", 20), length(fam_top) - 3)
})

test_that("recomputing a nested palette on a subset does NOT preserve colours", {
  # Documented behaviour, not an accident: each gradient is spread over the
  # siblings actually present. This is precisely why anchoring exists.
  full <- quiet(
    palette_tax_pq(ps_mini, "Family", n = 20, nested = "Class")
  )
  sub <- quiet(
    palette_tax_pq(sub_ps, "Family", n = 20, nested = "Class")
  )
  common <- setdiff(intersect(names(full), names(sub)), "other")
  expect_gt(length(common), 2)
  expect_false(identical(unname(full[common]), unname(sub[common])))
})

test_that("an anchored nested palette IS preserved on a subset", {
  ps <- quiet(palette_tax_pq(
    ps_mini,
    "Family",
    n = 20,
    nested = "Class",
    add_to_phyloseq = TRUE
  ))
  sub <- drop_levels(ps, "Family", fam_top[c(2, 5, 9)])

  full_pal <- quiet(palette_tax_pq(ps, "Family"))
  sub_pal <- quiet(palette_tax_pq(sub, "Family"))
  common <- intersect(names(full_pal), names(sub_pal))
  expect_gt(length(common), 2)
  expect_length(sub_pal, length(full_pal) - 3)
  expect_identical(full_pal[common], sub_pal[common])
})

test_that(".pq_parents_of warns on a leaf spanning several parents", {
  ps <- ps_mini
  tt <- ps@tax_table@.Data
  tt[1, "Class"] <- "Fake_class"
  target <- tt[1, "Family"]
  tt[2, c("Family", "Class")] <- c(target, "Other_class")
  phyloseq::tax_table(ps) <- phyloseq::tax_table(tt)
  expect_warning(
    .pq_parents_of(.pq_slot_df(ps, "tax_table"), "Family", "Class", target),
    "span"
  )
})

# ---- storing in the object ---------------------------------------------------

test_that("add_to_phyloseq returns a phyloseq carrying the colour column", {
  ps <- quiet(
    palette_tax_pq(ps_mini, "Order", n = 6, add_to_phyloseq = TRUE)
  )
  expect_s4_class(ps, "phyloseq")
  expect_true("Order_color" %in% phyloseq::rank_names(ps))
  expect_identical(phyloseq::ntaxa(ps), phyloseq::ntaxa(ps_mini))
})

test_that("a stored palette is read back instead of recomputed", {
  ps <- quiet(
    palette_tax_pq(ps_mini, "Order", n = 6, add_to_phyloseq = TRUE)
  )
  expect_message(
    reread <- palette_tax_pq(ps, "Order", n = 6),
    "Reusing the palette"
  )
  fresh <- quiet(palette_tax_pq(ps_mini, "Order", n = 6))
  top6 <- .pq_tax_top(ps_mini, "Order", 6)
  expect_identical(reread[top6], fresh[top6])
})

test_that("the stored palette wins over a different n, keeping colours stable", {
  ps <- quiet(
    palette_tax_pq(ps_mini, "Order", n = 4, add_to_phyloseq = TRUE)
  )
  top4 <- .pq_tax_top(ps_mini, "Order", 4)
  reread <- quiet(palette_tax_pq(ps, "Order", n = 8))
  fresh <- quiet(palette_tax_pq(ps_mini, "Order", n = 4))
  expect_identical(reread[top4], fresh[top4])
})

test_that("stored colours survive the removal of whole levels", {
  ps <- quiet(
    palette_tax_pq(ps_mini, "Order", n = 6, add_to_phyloseq = TRUE)
  )
  top6 <- .pq_tax_top(ps_mini, "Order", 6)
  sub <- drop_levels(ps, "Order", top6[c(2, 4)])

  full_pal <- quiet(palette_tax_pq(ps, "Order"))
  sub_pal <- quiet(palette_tax_pq(sub, "Order"))
  common <- intersect(names(full_pal), names(sub_pal))

  expect_false(any(top6[c(2, 4)] %in% names(sub_pal)))
  expect_gt(length(common), 1)
  expect_identical(full_pal[common], sub_pal[common])
})

test_that("writing twice is blocked, and suffix lets both coexist", {
  ps <- quiet(
    palette_tax_pq(ps_mini, "Order", n = 6, add_to_phyloseq = TRUE)
  )
  expect_error(
    quiet(
      palette_tax_pq(ps, "Order", n = 6, add_to_phyloseq = TRUE)
    ),
    "already exists"
  )
  ps2 <- quiet(
    (palette_tax_pq(
      ps,
      "Order",
      n = 6,
      palette = "oklch",
      add_to_phyloseq = TRUE,
      suffix = "_color_alt"
    ))
  )
  expect_true(all(
    c("Order_color", "Order_color_alt") %in% phyloseq::rank_names(ps2)
  ))
  expect_false(identical(
    quiet(palette_tax_pq(ps2, "Order"))[1:6],
    quiet(palette_tax_pq(ps2, "Order", suffix = "_color_alt"))[1:6]
  ))
})

test_that("a nested palette also stores the parent colours", {
  ps <- quiet(
    palette_tax_pq(
      ps_mini,
      "Family",
      n = 12,
      nested = "Class",
      add_to_phyloseq = TRUE
    )
  )
  expect_true(all(
    c("Family_color", "Class_color") %in% phyloseq::rank_names(ps)
  ))
})

# ---- integration with ggplot -------------------------------------------------

test_that("the palette colours a plot through the + operator", {
  pal <- quiet(palette_tax_pq(ps_mini, "Order", n = 6))
  levels_vec <- setdiff(names(pal), "other")
  df <- data.frame(
    x = levels_vec,
    y = seq_along(levels_vec),
    g = levels_vec
  )
  p <- ggplot(df, aes(x, y, fill = g)) + geom_col() + pal
  expect_identical(
    ggplot_build(p)$data[[1]]$fill,
    unname(pal[levels_vec])
  )
})
