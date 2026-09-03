data(data_fungi_mini, package = "MiscMetabar")
ps_mini <- data_fungi_mini

# ---- .pq_resolve_palette -----------------------------------------------------

test_that(".pq_resolve_palette walks the colourblind-safe ladder", {
  expect_identical(
    .pq_resolve_palette(6, quiet = TRUE),
    as.character(idest_colors("Hokusai3", n = 6, type = "discrete"))
  )
  expect_identical(
    .pq_resolve_palette(11, quiet = TRUE),
    as.character(idest_colors("Picabia", n = 11, type = "discrete"))
  )
})

test_that(".pq_resolve_palette falls back to OKLCH past the ladder", {
  expect_identical(.pq_resolve_palette(12, quiet = TRUE), .pq_pal_oklch(12))
})

test_that(".pq_resolve_palette reports which palette it chose", {
  expect_message(.pq_resolve_palette(6), "Hokusai3")
  expect_message(.pq_resolve_palette(12), "OKLCH")
})

test_that(".pq_resolve_palette honours an explicit IdEst palette", {
  got <- .pq_resolve_palette(4, "Picasso", quiet = TRUE)
  expect_length(got, 4)
  expect_true(all(got %in% idest_pal$Picasso[[1]]))
})

test_that(".pq_resolve_palette aborts when a named palette is too small", {
  expect_error(.pq_resolve_palette(9, "Picasso"), "holds 6 colours")
})

test_that(".pq_resolve_palette accepts a bare colour vector", {
  expect_identical(
    .pq_resolve_palette(2, c("#000000", "#ffffff", "#123456")),
    c("#000000", "#ffffff")
  )
  expect_error(
    .pq_resolve_palette(3, c("#000000", "#ffffff")),
    "supplies 2 colours"
  )
})

test_that(".pq_resolve_palette can be forced to OKLCH", {
  expect_identical(.pq_resolve_palette(4, "oklch"), .pq_pal_oklch(4))
})

# ---- .pq_tax_top -------------------------------------------------------------

test_that(".pq_tax_top returns at most n level names", {
  expect_length(.pq_tax_top(ps_mini, "Order", 5), 5)
  expect_type(.pq_tax_top(ps_mini, "Order", 5), "character")
})

test_that(".pq_tax_top orders by decreasing abundance", {
  top <- .pq_tax_top(ps_mini, "Order", 6)
  tt <- as.character(ps_mini@tax_table@.Data[, "Order"])
  sums <- tapply(phyloseq::taxa_sums(ps_mini), tt, sum)
  expect_identical(top, names(sort(sums[top], decreasing = TRUE)))
})

test_that(".pq_tax_top never returns NA levels", {
  top <- .pq_tax_top(ps_mini, "Species", 50)
  expect_false(anyNA(top))
  expect_false(any(top == "NA"))
})

test_that(".pq_tax_top supports every selection metric", {
  for (by in c("abundance", "n_taxa", "mean", "prevalence")) {
    expect_length(.pq_tax_top(ps_mini, "Order", 4, by = by), 4)
  }
  expect_error(.pq_tax_top(ps_mini, "Order", 4, by = "median"))
})

test_that("selecting by n_taxa differs from selecting by abundance", {
  # A rank rich in low-abundance taxa ranks differently under the two metrics.
  by_ab <- .pq_tax_top(ps_mini, "Family", 6, by = "abundance")
  by_nt <- .pq_tax_top(ps_mini, "Family", 6, by = "n_taxa")
  expect_false(identical(by_ab, by_nt))
})

# ---- .pq_tax_weight ----------------------------------------------------------

test_that(".pq_tax_weight counts taxa, not reads, for n_taxa", {
  w <- .pq_tax_weight(ps_mini, "Order", "n_taxa")
  tt <- as.character(ps_mini@tax_table@.Data[, "Order"])
  expect_identical(w, {
    tab <- table(tt[!is.na(tt)])
    stats::setNames(as.numeric(tab), names(tab))
  })
})

test_that(".pq_tax_weight sums reads for abundance", {
  w <- .pq_tax_weight(ps_mini, "Order", "abundance")
  tt <- as.character(ps_mini@tax_table@.Data[, "Order"])
  keep <- !is.na(tt)
  expect_equal(
    w,
    {
      agg <- tapply(phyloseq::taxa_sums(ps_mini)[keep], tt[keep], sum)
      stats::setNames(as.numeric(agg), names(agg))
    },
    ignore_attr = FALSE
  )
})

# ---- .pq_tax_order -----------------------------------------------------------

test_that(".pq_tax_order sorts alphabetically", {
  lv <- .pq_tax_top(ps_mini, "Order", 6)
  expect_identical(.pq_tax_order(ps_mini, "Order", lv, "alpha"), sort(lv))
})

test_that(".pq_tax_order sorts by decreasing weight", {
  lv <- .pq_tax_top(ps_mini, "Order", 6)
  for (metric in c("abundance", "n_taxa")) {
    got <- .pq_tax_order(ps_mini, "Order", lv, metric)
    w <- .pq_tax_weight(ps_mini, "Order", metric)[got]
    expect_false(is.unsorted(rev(w)))
    expect_setequal(got, lv)
  }
})

test_that(".pq_tax_order keeps the same set whatever the order", {
  lv <- .pq_tax_top(ps_mini, "Order", 6)
  for (metric in c("alpha", "abundance", "n_taxa")) {
    expect_setequal(.pq_tax_order(ps_mini, "Order", lv, metric), lv)
  }
  expect_error(.pq_tax_order(ps_mini, "Order", lv, "size"))
})

test_that(".pq_tax_top breaks ties alphabetically, not by row order", {
  ps <- ps_mini
  shuffled <- ps
  phyloseq::taxa_names(shuffled) <- phyloseq::taxa_names(ps)
  expect_identical(
    .pq_tax_top(ps, "Order", 8),
    .pq_tax_top(shuffled, "Order", 8)
  )
})

# ---- .pq_sam_levels ----------------------------------------------------------

test_that(".pq_sam_levels honours factor levels", {
  ps <- ps_mini
  phyloseq::sample_data(ps)$grp <- factor(
    rep(c("b", "a"), length.out = phyloseq::nsamples(ps)),
    levels = c("b", "a")
  )
  expect_identical(.pq_sam_levels(ps, "grp"), c("b", "a"))
  expect_identical(.pq_sam_levels(ps, "grp", "alpha"), c("a", "b"))
})

test_that(".pq_sam_levels sorts a numeric variable numerically, not as text", {
  ps <- ps_mini
  phyloseq::sample_data(ps)$num <- rep(
    c(0, 5, 10, 15),
    length.out = phyloseq::nsamples(ps)
  )
  expect_identical(.pq_sam_levels(ps, "num"), c("0", "5", "10", "15"))
  # "alpha" means alphabetical, even when that is 10 before 5.
  expect_identical(
    .pq_sam_levels(ps, "num", "alpha"),
    c("0", "10", "15", "5")
  )
})

test_that(".pq_sam_levels can sort by frequency", {
  ps <- ps_mini
  phyloseq::sample_data(ps)$grp <- rep(
    c("rare", "common", "common"),
    length.out = phyloseq::nsamples(ps)
  )
  expect_identical(.pq_sam_levels(ps, "grp", "frequency")[1], "common")
})

# ---- .pq_dedup_levels --------------------------------------------------------

test_that(".pq_dedup_levels leaves unique names untouched", {
  got <- .pq_dedup_levels(c("a", "b"), c("P", "Q"), "parent")
  expect_identical(got$keys, c("a", "b"))
  expect_true(all(got$keep))
})

test_that(".pq_dedup_levels appends the parent to duplicates only", {
  got <- .pq_dedup_levels(c("a", "a", "b"), c("P", "Q", "P"), "parent")
  expect_identical(got$keys, c("a (P)", "a (Q)", "b"))
})

test_that(".pq_dedup_levels can drop repeats or abort", {
  expect_warning(
    got <- .pq_dedup_levels(c("a", "a", "b"), c("P", "Q", "P"), "first"),
    "Dropped 1"
  )
  expect_identical(got$keep, c(TRUE, FALSE, TRUE))
  expect_error(
    .pq_dedup_levels(c("a", "a"), c("P", "Q"), "error"),
    "several parents"
  )
})

# ---- .pq_palette_engine ------------------------------------------------------

test_that(".pq_palette_engine builds a flat named palette with reserved entries", {
  got <- .pq_palette_engine(c("a", "b", "c"), quiet = TRUE)
  expect_identical(names(got$colors), c("a", "b", "c", "other"))
  expect_identical(unname(got$colors[["other"]]), "grey85")
  expect_null(got$parent_colors)
})

test_that(".pq_palette_engine gives each parent its own hue in nested mode", {
  got <- .pq_palette_engine(
    levels = c("a", "b", "c", "d"),
    parents = c("P", "P", "Q", "Q"),
    quiet = TRUE
  )
  expect_length(got$parent_colors, 2)
  hues <- .pq_hex_oklch(unname(got$colors[c("a", "b", "c", "d")]))[, "h"]
  expect_lt(abs(hues[1] - hues[2]), 2)
  expect_lt(abs(hues[3] - hues[4]), 2)
  expect_gt(abs(hues[1] - hues[3]), 10)
})

test_that(".pq_palette_engine darkens the first leaf of each parent", {
  got <- .pq_palette_engine(
    levels = c("a", "b"),
    parents = c("P", "P"),
    quiet = TRUE
  )
  l <- .pq_hex_oklch(unname(got$colors[c("a", "b")]))[, "l"]
  expect_lt(l[1], l[2])
})

test_that(".pq_palette_engine refuses reorder on a nested palette", {
  expect_error(
    .pq_palette_engine(c("a", "b"), parents = c("P", "Q"), reorder = TRUE),
    "cannot be combined"
  )
})

test_that(".pq_palette_engine reorders a flat palette on request", {
  plain <- .pq_palette_engine(letters[1:6], quiet = TRUE)$colors
  shuffled <- .pq_palette_engine(
    letters[1:6],
    reorder = TRUE,
    quiet = TRUE
  )$colors
  expect_identical(names(plain), names(shuffled))
  expect_setequal(unname(plain), unname(shuffled))
  expect_false(identical(unname(plain), unname(shuffled)))
})

test_that(".pq_palette_engine validates its arguments", {
  expect_error(
    .pq_palette_engine(c("a", "b"), parents = "P"),
    "has length 1"
  )
  expect_error(
    .pq_palette_engine(c("a"), add = "grey85"),
    "named vector"
  )
})

test_that(".pq_palette_engine handles an empty level set", {
  got <- .pq_palette_engine(character(0), quiet = TRUE)
  expect_identical(names(got$colors), "other")
})

# ---- column helpers ----------------------------------------------------------

test_that(".pq_color_col builds the column name and polices the suffix", {
  expect_identical(.pq_color_col("Order", "_color"), "Order_color")
  expect_identical(.pq_color_col("Order", "_color_ab"), "Order_color_ab")
  expect_warning(.pq_color_col("Order", "_pal2"), "does not start with")
})

test_that(".pq_slot_for_var locates a variable", {
  expect_identical(.pq_slot_for_var(ps_mini, "Order"), "tax_table")
  expect_identical(.pq_slot_for_var(ps_mini, "Height"), "sam_data")
  expect_error(.pq_slot_for_var(ps_mini, "nope"), "neither a taxonomic rank")
})

test_that(".pq_slot_for_var refuses an ambiguous name", {
  ps <- ps_mini
  phyloseq::sample_data(ps)$Order <- "x"
  expect_error(.pq_slot_for_var(ps, "Order"), "both")
})

# ---- write / read round trip -------------------------------------------------

top8 <- .pq_tax_top(ps_mini, "Order", 8)
pal8 <- .pq_palette_engine(top8, quiet = TRUE)$colors

test_that(".pq_write_color_col adds a column covering every row", {
  ps <- .pq_write_color_col(
    ps_mini,
    "Order",
    pal8,
    "tax_table",
    "_color",
    FALSE
  )
  expect_true("Order_color" %in% phyloseq::rank_names(ps))
  expect_false(anyNA(ps@tax_table@.Data[, "Order_color"]))
  expect_identical(phyloseq::ntaxa(ps), phyloseq::ntaxa(ps_mini))
})

test_that(".pq_write_color_col folds non-top levels into the other colour", {
  ps <- .pq_write_color_col(
    ps_mini,
    "Order",
    pal8,
    "tax_table",
    "_color",
    FALSE
  )
  tt <- as.data.frame(ps@tax_table@.Data, stringsAsFactors = FALSE)
  minor <- tt[!tt$Order %in% top8 & !is.na(tt$Order), "Order_color"]
  expect_true(all(minor == "grey85"))
})

test_that(".pq_read_color_col recovers the level-to-colour map", {
  ps <- .pq_write_color_col(
    ps_mini,
    "Order",
    pal8,
    "tax_table",
    "_color",
    FALSE
  )
  back <- .pq_read_color_col(ps, "Order", "tax_table", "_color")
  expect_identical(back[top8], pal8[top8])
})

test_that(".pq_read_color_col maps minor levels to the other colour, not a key", {
  # Reserved entries are re-attached by the caller from its own `add`
  # argument; the column cannot distinguish them from ordinary levels.
  ps <- .pq_write_color_col(
    ps_mini,
    "Order",
    pal8,
    "tax_table",
    "_color",
    FALSE
  )
  back <- .pq_read_color_col(ps, "Order", "tax_table", "_color")
  expect_false("other" %in% names(back))
  minor <- setdiff(names(back), top8)
  expect_true(all(unname(back[minor]) == "grey85"))
})

test_that(".pq_read_color_col returns NULL when there is no such column", {
  expect_null(.pq_read_color_col(ps_mini, "Order", "tax_table", "_color"))
})

test_that("colours survive the removal of whole levels", {
  # An abundance filter drops no Order at all from `data_fungi_mini`, which
  # would make this pass trivially; remove named levels instead.
  ps <- .pq_write_color_col(
    ps_mini,
    "Order",
    pal8,
    "tax_table",
    "_color",
    FALSE
  )
  gone <- top8[c(2, 4)]
  ps_sub <- phyloseq::prune_taxa(
    !as.character(ps@tax_table@.Data[, "Order"]) %in% gone,
    ps
  )
  expect_false(any(
    gone %in% as.character(ps_sub@tax_table@.Data[, "Order"])
  ))
  full <- .pq_read_color_col(ps, "Order", "tax_table", "_color")
  sub <- .pq_read_color_col(ps_sub, "Order", "tax_table", "_color")
  common <- intersect(names(full), names(sub))
  expect_gt(length(common), 1)
  expect_identical(full[common], sub[common])
})

test_that(".pq_write_color_col guards an existing column and suggests both exits", {
  ps <- .pq_write_color_col(
    ps_mini,
    "Order",
    pal8,
    "tax_table",
    "_color",
    FALSE
  )
  expect_error(
    .pq_write_color_col(ps, "Order", pal8, "tax_table", "_color", FALSE),
    "already exists"
  )
  expect_warning(
    ps2 <- .pq_write_color_col(ps, "Order", pal8, "tax_table", "_color", TRUE),
    "Overwriting"
  )
  expect_true("Order_color" %in% phyloseq::rank_names(ps2))
})

test_that("a suffix lets a second palette coexist on the same rank", {
  ps <- .pq_write_color_col(
    ps_mini,
    "Order",
    pal8,
    "tax_table",
    "_color",
    FALSE
  )
  pal_alt <- .pq_palette_engine(top8, palette = "oklch", quiet = TRUE)$colors
  ps <- .pq_write_color_col(
    ps,
    "Order",
    pal_alt,
    "tax_table",
    "_color_ab",
    FALSE
  )
  expect_true(all(
    c("Order_color", "Order_color_ab") %in% phyloseq::rank_names(ps)
  ))
  expect_identical(
    .pq_read_color_col(ps, "Order", "tax_table", "_color")[top8],
    pal8[top8]
  )
  expect_identical(
    .pq_read_color_col(ps, "Order", "tax_table", "_color_ab")[top8],
    pal_alt[top8]
  )
})

test_that("the sam_data path writes and reads back too", {
  ps <- ps_mini
  phyloseq::sample_data(ps)$grp <- rep(
    c("a", "b"),
    length.out = phyloseq::nsamples(ps)
  )
  pal <- .pq_palette_engine(c("a", "b"), quiet = TRUE)$colors
  ps <- .pq_write_color_col(ps, "grp", pal, "sam_data", "_color", FALSE)
  expect_true("grp_color" %in% phyloseq::sample_variables(ps))
  back <- .pq_read_color_col(ps, "grp", "sam_data", "_color")
  expect_identical(back[c("a", "b")], pal[c("a", "b")])
})

# ---- .pq_find_color_cols -----------------------------------------------------

test_that(".pq_find_color_cols reports nothing on a bare object", {
  expect_identical(nrow(.pq_find_color_cols(ps_mini)), 0L)
})

test_that(".pq_find_color_cols lists palettes from both slots", {
  ps <- .pq_write_color_col(
    ps_mini,
    "Order",
    pal8,
    "tax_table",
    "_color",
    FALSE
  )
  phyloseq::sample_data(ps)$grp <- rep(
    c("a", "b"),
    length.out = phyloseq::nsamples(ps)
  )
  pal <- .pq_palette_engine(c("a", "b"), quiet = TRUE)$colors
  ps <- .pq_write_color_col(ps, "grp", pal, "sam_data", "_color_x", FALSE)

  found <- .pq_find_color_cols(ps)
  expect_identical(nrow(found), 2L)
  expect_setequal(found$slot, c("tax_table", "sam_data"))
  expect_setequal(found$column, c("Order_color", "grp_color_x"))
  expect_setequal(found$suffix, c("_color", "_color_x"))
})
