skip_on_cran()
skip_if_not_installed("MiscMetabar")

data(data_fungi_mini, package = "MiscMetabar")

# ---- static path (no extra dependency) -------------------------------------

test_that("sunburst static returns ggplot", {
  p <- krona_like_pq(data_fungi_mini, interactive = FALSE)
  expect_s3_class(p, "ggplot")
})

test_that("treemap static returns ggplot", {
  p <- krona_like_pq(data_fungi_mini, layout = "treemap", interactive = FALSE)
  expect_s3_class(p, "ggplot")
})

test_that("pattern = TRUE returns ggplot for both layouts", {
  skip_if_not_installed("ggpattern")
  p1 <- krona_like_pq(data_fungi_mini, interactive = FALSE, pattern = TRUE)
  expect_s3_class(p1, "ggplot")
  p2 <- krona_like_pq(
    data_fungi_mini,
    layout = "treemap",
    interactive = FALSE,
    pattern = TRUE
  )
  expect_s3_class(p2, "ggplot")
})

test_that("pattern = TRUE without ggpattern aborts", {
  skip_if(requireNamespace("ggpattern", quietly = TRUE))
  expect_error(
    krona_like_pq(data_fungi_mini, interactive = FALSE, pattern = TRUE),
    "ggpattern"
  )
})

test_that(".alternate_pattern alternates within each depth", {
  df <- data.frame(
    depth = c(1, 1, 1, 1, 2, 2),
    x0 = c(0, 1, 2, 3, 0, 1)
  )
  patt <- ggplotpq:::.alternate_pattern(df)
  expect_equal(patt, c("none", "dot", "none", "dot", "none", "dot"))
})

test_that("weight_by = 'asv' returns ggplot", {
  p <- krona_like_pq(data_fungi_mini, weight_by = "asv", interactive = FALSE)
  expect_s3_class(p, "ggplot")
})

test_that("weight_by function (log1p) returns ggplot", {
  p <- krona_like_pq(data_fungi_mini, weight_by = log1p, interactive = FALSE)
  expect_s3_class(p, "ggplot")
})

test_that("weight_by numeric vector returns ggplot", {
  w <- rep(1, phyloseq::ntaxa(data_fungi_mini))
  p <- krona_like_pq(data_fungi_mini, weight_by = w, interactive = FALSE)
  expect_s3_class(p, "ggplot")
})

test_that("weight_by numeric vector of wrong length aborts", {
  expect_error(
    krona_like_pq(data_fungi_mini, weight_by = c(1, 2, 3), interactive = FALSE),
    "ntaxa"
  )
})

test_that("ranks subset works", {
  p <- krona_like_pq(
    data_fungi_mini,
    ranks = c("Phylum", "Class", "Order"),
    interactive = FALSE
  )
  expect_s3_class(p, "ggplot")
})

test_that("title is rendered in static ggplot", {
  p <- krona_like_pq(
    data_fungi_mini,
    title = "My fungi",
    interactive = FALSE
  )
  expect_s3_class(p, "ggplot")
  expect_equal(p$labels$title, "My fungi")
})

test_that("color_by rank changes output without error", {
  p <- krona_like_pq(
    data_fungi_mini,
    color_by = "Class",
    interactive = FALSE
  )
  expect_s3_class(p, "ggplot")
})

test_that("single-rank tax_table works", {
  pq_single <- phyloseq::tax_glom(data_fungi_mini, taxrank = "Phylum")
  p <- krona_like_pq(pq_single, ranks = "Phylum", interactive = FALSE)
  expect_s3_class(p, "ggplot")
})

test_that("invalid ranks name aborts", {
  expect_error(
    krona_like_pq(data_fungi_mini, ranks = "NotARank", interactive = FALSE),
    "not found"
  )
})

test_that("invalid color_by rank aborts", {
  expect_error(
    krona_like_pq(
      data_fungi_mini,
      ranks = c("Phylum", "Class"),
      color_by = "Order",
      interactive = FALSE
    ),
    "color_by"
  )
})

# ---- label_pct -------------------------------------------------------------

test_that("label_pct = 'total' renders labels containing '%'", {
  p <- krona_like_pq(
    data_fungi_mini,
    interactive = FALSE,
    label_pct = "total"
  )
  expect_s3_class(p, "ggplot")
  # At least one geom_text layer must have a 'lab' column with '%' in some labels
  has_pct <- any(vapply(
    p$layers,
    function(l) {
      if (!inherits(l$geom, "GeomText")) {
        return(FALSE)
      }
      d <- l$data
      if (!is.data.frame(d) || !"lab" %in% names(d)) {
        return(FALSE)
      }
      any(grepl("%", d$lab, fixed = TRUE), na.rm = TRUE)
    },
    logical(1)
  ))
  expect_true(has_pct)
})

test_that("label_pct = 'parent' returns ggplot for sunburst and treemap", {
  p1 <- krona_like_pq(
    data_fungi_mini,
    interactive = FALSE,
    label_pct = "parent"
  )
  expect_s3_class(p1, "ggplot")
  p2 <- krona_like_pq(
    data_fungi_mini,
    layout = "treemap",
    interactive = FALSE,
    label_pct = "parent"
  )
  expect_s3_class(p2, "ggplot")
})

test_that("invalid label_pct aborts", {
  expect_error(
    krona_like_pq(
      data_fungi_mini,
      interactive = FALSE,
      label_pct = "wrong"
    )
  )
})

# ---- show_center_count -----------------------------------------------------

# Helper: TRUE if any layer is the centre-count annotate("text") call.
# annotate() stores constant aesthetics in l$aes_params, not l$data, so the
# label "n = ..." lives in l$aes_params$label.
.has_center_annotation <- function(p) {
  any(vapply(
    p$layers,
    function(l) {
      if (!inherits(l$geom, "GeomText")) {
        return(FALSE)
      }
      lbl <- l$aes_params[["label"]]
      if (is.null(lbl)) {
        return(FALSE)
      }
      grepl("^n = ", lbl)
    },
    logical(1)
  ))
}

test_that("show_center_count = TRUE adds 'n = ...' annotation to sunburst", {
  p <- krona_like_pq(
    data_fungi_mini,
    interactive = FALSE,
    show_center_count = TRUE,
    check_nestedness = FALSE
  )
  expect_true(.has_center_annotation(p))
})

test_that("show_center_count = FALSE omits the centre annotation", {
  p <- krona_like_pq(
    data_fungi_mini,
    interactive = FALSE,
    show_center_count = FALSE,
    check_nestedness = FALSE
  )
  expect_false(.has_center_annotation(p))
})

# ---- collapse_single -------------------------------------------------------

test_that("collapse_single = TRUE returns ggplot", {
  p <- krona_like_pq(
    data_fungi_mini,
    interactive = FALSE,
    collapse_single = TRUE
  )
  expect_s3_class(p, "ggplot")
})

test_that(".collapse_single_children removes intermediate single-child nodes", {
  leaf1 <- list(
    name = "sp1",
    value = 10,
    depth = 3,
    children = list(),
    is_aggregate = FALSE
  )
  leaf2 <- list(
    name = "sp2",
    value = 5,
    depth = 3,
    children = list(),
    is_aggregate = FALSE
  )
  genus <- list(
    name = "genus",
    value = 15,
    depth = 2,
    children = list(leaf1, leaf2),
    is_aggregate = FALSE
  )
  family <- list(
    name = "family",
    value = 15,
    depth = 1,
    children = list(genus),
    is_aggregate = FALSE
  )
  root_node <- list(
    name = "All",
    value = 15,
    depth = 0,
    children = list(family),
    is_aggregate = FALSE
  )

  result <- ggplotpq:::.collapse_single_children(root_node)
  # family had one child (genus which had 2 children), so genus bubbles up
  expect_equal(result$children[[1]]$name, "genus")
  expect_length(result$children[[1]]$children, 2)
})

# ---- min_prop (low-abundance merging) --------------------------------------

test_that("min_prop merges low-abundance siblings into 'n more'", {
  p <- krona_like_pq(
    data_fungi_mini,
    interactive = FALSE,
    min_prop = 0.05
  )
  expect_s3_class(p, "ggplot")
})

test_that("min_prop with crosshatch requires ggpattern (or graceful fallback)", {
  skip_if_not_installed("ggpattern")
  p <- krona_like_pq(
    data_fungi_mini,
    interactive = FALSE,
    min_prop = 0.05
  )
  expect_s3_class(p, "ggplot")
})

test_that("invalid min_prop aborts", {
  expect_error(
    krona_like_pq(data_fungi_mini, interactive = FALSE, min_prop = 1.5),
    "min_prop"
  )
})

test_that(".merge_low_abundance creates aggregate node", {
  child1 <- list(
    name = "a",
    value = 100,
    depth = 1,
    children = list(),
    is_aggregate = FALSE
  )
  child2 <- list(
    name = "b",
    value = 2,
    depth = 1,
    children = list(),
    is_aggregate = FALSE
  )
  child3 <- list(
    name = "c",
    value = 1,
    depth = 1,
    children = list(),
    is_aggregate = FALSE
  )
  parent_node <- list(
    name = "root",
    value = 103,
    depth = 0,
    children = list(child1, child2, child3),
    is_aggregate = FALSE
  )
  result <- ggplotpq:::.merge_low_abundance(parent_node, min_prop = 0.05)
  # b and c are < 5% of 103; should be merged
  child_names <- vapply(result$children, function(x) x$name, character(1))
  expect_true("a" %in% child_names)
  expect_true(any(grepl("more", child_names)))
  agg <- result$children[[which(grepl("more", child_names))]]
  expect_true(agg$is_aggregate)
})

# ---- color_as_numeric ------------------------------------------------------

test_that("color_as_numeric = TRUE with non-numeric column aborts", {
  expect_error(
    krona_like_pq(
      data_fungi_mini,
      interactive = FALSE,
      color_by = "Class",
      color_as_numeric = TRUE
    ),
    "numeric"
  )
})

test_that("color_as_numeric = TRUE with valid numeric column returns ggplot", {
  skip_if_not_installed("scales")
  pq <- data_fungi_mini
  phyloseq::tax_table(pq) <- cbind(
    phyloseq::tax_table(pq),
    num_score = as.character(
      stats::runif(phyloseq::ntaxa(pq))
    )
  )
  p <- krona_like_pq(
    pq,
    interactive = FALSE,
    color_by = "num_score",
    color_as_numeric = TRUE
  )
  expect_s3_class(p, "ggplot")
})

# ---- nestedness check ------------------------------------------------------

test_that(".check_nestedness warns on non-nested taxonomy", {
  df <- data.frame(
    Phylum = c("A", "A"),
    Class = c("X", "X"),
    Order = c("Y", "Z"),
    Genus = c("g", "g"),
    stringsAsFactors = FALSE
  )
  expect_warning(
    ggplotpq:::.check_nestedness(df, c("Phylum", "Class", "Order", "Genus")),
    "Genus"
  )
})

test_that(".check_nestedness is silent for perfectly nested taxonomy", {
  df <- data.frame(
    Phylum = c("A", "A", "B"),
    Class = c("X", "X", "Y"),
    stringsAsFactors = FALSE
  )
  expect_silent(ggplotpq:::.check_nestedness(df, c("Phylum", "Class")))
})

test_that("check_nestedness = FALSE suppresses nestedness warnings", {
  # Use ranks = 'All' explicitly to include annotation columns that are not
  # strictly nested; check_nestedness = FALSE must suppress the resulting warning.
  expect_no_warning(
    krona_like_pq(
      data_fungi_mini,
      ranks = "All",
      interactive = FALSE,
      check_nestedness = FALSE
    )
  )
})

test_that("default ranks omit non-classical annotation columns", {
  # With ranks = 'All' (the default), the function now restricts to classical
  # taxonomic ranks when they are present, avoiding nestedness warnings from
  # annotation columns like Trophic.Mode or Confidence.Ranking.
  all_ranks <- phyloseq::rank_names(data_fungi_mini)
  classical <- c(
    "Kingdom",
    "Phylum",
    "Class",
    "Order",
    "Family",
    "Genus",
    "Species"
  )
  has_classical <- any(classical %in% all_ranks)
  skip_if_not(has_classical, "data_fungi_mini has no classical ranks")

  # Default call (ranks = 'All') should NOT warn about nestedness because the
  # annotation columns are excluded by .default_ranks().
  expect_no_warning(
    krona_like_pq(data_fungi_mini, interactive = FALSE)
  )
})

# ---- .truncate_label_middle ------------------------------------------------

test_that(".truncate_label_middle truncates long labels with middle ellipsis", {
  x <- "Lactarius_subdulcissimella"
  result <- ggplotpq:::.truncate_label_middle(x, n = 14)
  expect_true(nchar(result) <= 14)
  expect_true(grepl("\\.\\.\\.", result))
  expect_true(startsWith(result, substr(x, 1, 1)))
  expect_true(endsWith(result, substr(x, nchar(x), nchar(x))))
})

test_that(".truncate_label_middle leaves short labels unchanged", {
  x <- "Boletus"
  expect_equal(ggplotpq:::.truncate_label_middle(x, n = 20), x)
})

# ---- abbrev_species --------------------------------------------------------

test_that(".abbrev_species_names prepends the genus initial to species names", {
  node <- list(
    name = "All",
    depth = 0,
    children = list(
      list(
        name = "Amanita",
        depth = 1,
        children = list(
          list(name = "muscaria", depth = 2, children = list()),
          list(name = "unassigned", depth = 2, children = list())
        )
      )
    )
  )
  out <- ggplotpq:::.abbrev_species_names(node, sp_depth = 2)
  sp <- out$children[[1]]$children
  expect_equal(sp[[1]]$name, "A. muscaria")
  # Placeholder species names are left untouched.
  expect_equal(sp[[2]]$name, "unassigned")
  # Idempotent: re-running does not double-prefix.
  out2 <- ggplotpq:::.abbrev_species_names(out, sp_depth = 2)
  expect_equal(out2$children[[1]]$children[[1]]$name, "A. muscaria")
})

test_that("abbrev_species warns when no Species rank is selected", {
  expect_warning(
    krona_like_pq(
      data_fungi_mini,
      interactive = FALSE,
      ranks = c("Order", "Family", "Genus"),
      abbrev_species = TRUE,
      check_nestedness = FALSE
    ),
    "Species"
  )
})

test_that("abbrev_species must be a single logical", {
  expect_error(
    krona_like_pq(
      data_fungi_mini,
      interactive = FALSE,
      abbrev_species = "yes",
      check_nestedness = FALSE
    ),
    "abbrev_species"
  )
})

# ---- label_size ------------------------------------------------------------

test_that("scalar label_size scales every label's size", {
  p <- krona_like_pq(
    data_fungi_mini,
    interactive = FALSE,
    label_size = 3,
    check_nestedness = FALSE
  )
  lays <- Filter(
    function(l) {
      inherits(l$geom, "GeomText") &&
        is.data.frame(l$data) &&
        "sz" %in% names(l$data)
    },
    p$layers
  )
  szs <- unlist(lapply(lays, function(l) l$data$sz))
  # base sizes are 1.7 / 1.85, so 3x pushes every drawn label above 5.
  expect_true(length(szs) > 0)
  expect_gte(min(szs), 5)
})

test_that("per-rank label_size (length == n ranks) returns a ggplot", {
  rk <- c("Order", "Family", "Genus", "Species")
  p <- krona_like_pq(
    data_fungi_mini,
    interactive = FALSE,
    ranks = rk,
    label_size = c(1.6, 1.3, 1.0, 0.7),
    check_nestedness = FALSE
  )
  expect_s3_class(p, "ggplot")
})

test_that("per-taxon label_size (length == ntaxa) returns a ggplot", {
  nt <- phyloseq::ntaxa(data_fungi_mini)
  p <- krona_like_pq(
    data_fungi_mini,
    interactive = FALSE,
    ranks = c("Order", "Family", "Genus", "Species"),
    label_size = rep(1.2, nt),
    check_nestedness = FALSE
  )
  expect_s3_class(p, "ggplot")
})

test_that("label_size of unsupported length aborts", {
  expect_error(
    krona_like_pq(
      data_fungi_mini,
      interactive = FALSE,
      ranks = c("Order", "Family", "Genus"),
      label_size = c(1, 2),
      check_nestedness = FALSE
    ),
    "unsupported length"
  )
})

test_that("label_size must be positive and finite", {
  expect_error(
    krona_like_pq(
      data_fungi_mini,
      interactive = FALSE,
      label_size = -1,
      check_nestedness = FALSE
    ),
    "positive"
  )
})

test_that(".assign_size_by_taxon sets internal nodes to the descendant-leaf mean", {
  node <- list(
    name = "All",
    depth = 0,
    children = list(
      list(
        name = "Amanita",
        depth = 1,
        children = list(
          list(name = "muscaria", depth = 2, children = list()),
          list(name = "phalloides", depth = 2, children = list())
        )
      )
    )
  )
  tt <- data.frame(
    Genus = c("Amanita", "Amanita", "Amanita"),
    Species = c("muscaria", "muscaria", "phalloides"),
    stringsAsFactors = FALSE
  )
  # muscaria has taxa (2, 4) -> mean 3; phalloides has taxon 10.
  sizes <- c(2, 4, 10)
  out <- ggplotpq:::.assign_size_by_taxon(
    node,
    tt,
    c("Genus", "Species"),
    sizes,
    character()
  )$node
  sp <- out$children[[1]]$children
  expect_equal(sp[[1]]$size_mult, 3) # mean(2, 4)
  expect_equal(sp[[2]]$size_mult, 10)
  # internal Amanita = mean of its two leaves (3, 10)
  expect_equal(out$children[[1]]$size_mult, 6.5)
})

# ---- interactive path (guarded) --------------------------------------------

test_that("interactive = TRUE returns htmlwidget (requires htmlwidgets)", {
  skip_if_not_installed("htmlwidgets")
  w <- krona_like_pq(data_fungi_mini)
  expect_s3_class(w, "htmlwidget")
})

test_that("interactive treemap returns htmlwidget", {
  skip_if_not_installed("htmlwidgets")
  w <- krona_like_pq(data_fungi_mini, layout = "treemap")
  expect_s3_class(w, "htmlwidget")
})

test_that("interactive widget passes options to htmlwidget", {
  skip_if_not_installed("htmlwidgets")
  w <- krona_like_pq(
    data_fungi_mini,
    show_center_count = FALSE,
    show_search = TRUE,
    show_info_panel = TRUE,
    label_pct = "total"
  )
  expect_false(w$x$options$showCenterCount)
  expect_true(w$x$options$showSearch)
  expect_true(w$x$options$showInfoPanel)
  expect_equal(w$x$options$labelPct, "total")
  expect_true(is.list(w$x$options$ranks))
  expect_gt(length(w$x$options$ranks), 0L)
})

test_that("file_path writes a self-contained HTML file", {
  skip_if_not_installed("htmlwidgets")
  tmp <- tempfile(fileext = ".html")
  on.exit(unlink(tmp))
  w <- krona_like_pq(data_fungi_mini, file_path = tmp)
  expect_true(file.exists(tmp))
  expect_gt(file.size(tmp), 1000L)
})

# ---- internal helpers -------------------------------------------------------

test_that(".hsl_to_hex returns a character string matching hex format", {
  hex <- ggplotpq:::.hsl_to_hex(120, 0.6, 0.5)
  expect_type(hex, "character")
  expect_match(hex, "^#[0-9A-F]{6}$")
})

test_that(".resolve_weights handles 'sequences'", {
  w <- ggplotpq:::.resolve_weights(data_fungi_mini, "sequences")
  expect_length(w, phyloseq::ntaxa(data_fungi_mini))
  expect_true(all(w >= 0))
})

test_that(".resolve_weights handles 'asv'", {
  w <- ggplotpq:::.resolve_weights(data_fungi_mini, "asv")
  expect_true(all(w == 1))
})

test_that(".resolve_weights aborts on bad string", {
  expect_error(
    ggplotpq:::.resolve_weights(data_fungi_mini, "read_counts"),
    "sequences"
  )
})

# ---- label_orientation -----------------------------------------------------

# Section-label layers are the GeomText layers whose data carries an `ang`
# column (excludes the centre count and the dot markers).
.label_text_layers <- function(p) {
  Filter(
    function(l) {
      inherits(l$geom, "GeomText") &&
        is.data.frame(l$data) &&
        "ang" %in% names(l$data)
    },
    p$layers
  )
}

# TRUE if a layer maps hjust as an aesthetic (vs a constant parameter).
.maps_hjust <- function(l) {
  !is.null(l$mapping$hjust)
}

test_that("all label modes keep angles within [-90, 90]", {
  for (mode in c("auto", "radial", "tangential", "mixed", "adaptive")) {
    p <- krona_like_pq(
      data_fungi_mini,
      interactive = FALSE,
      label_orientation = mode,
      check_nestedness = FALSE
    )
    lays <- .label_text_layers(p)
    expect_gt(length(lays), 0)
    for (l in lays) {
      expect_true(all(abs(l$data$ang) <= 90 + 1e-9))
    }
  }
})

test_that("label_orientation = 'radial' centres internal labels, anchors leaf labels by side", {
  p <- krona_like_pq(
    data_fungi_mini,
    interactive = FALSE,
    label_orientation = "radial",
    check_nestedness = FALSE
  )
  lays <- .label_text_layers(p)
  # Internal radial labels are centred (constant hjust = 0.5, not mapped);
  # leaf radial labels still read outward and need the hemisphere-based
  # hjust, so at least one layer maps it and at least one does not.
  maps <- vapply(lays, .maps_hjust, logical(1))
  expect_true(any(maps))
  expect_true(any(!maps))
})

test_that("label_orientation = 'tangential' centres every label (no aes hjust)", {
  p <- krona_like_pq(
    data_fungi_mini,
    interactive = FALSE,
    label_orientation = "tangential",
    check_nestedness = FALSE
  )
  lays <- .label_text_layers(p)
  expect_false(any(vapply(lays, .maps_hjust, logical(1))))
})

# Total number of section labels actually drawn across all text layers.
.n_drawn_labels <- function(p) {
  sum(vapply(.label_text_layers(p), function(l) nrow(l$data), integer(1)))
}

test_that("option1/option2/option3 alias tangential/mixed/auto", {
  aliases <- list(
    c("option1", "tangential"),
    c("option2", "mixed"),
    c("option3", "auto")
  )
  for (pair in aliases) {
    p_new <- krona_like_pq(
      data_fungi_mini,
      interactive = FALSE,
      label_orientation = pair[[1]],
      check_nestedness = FALSE
    )
    p_old <- krona_like_pq(
      data_fungi_mini,
      interactive = FALSE,
      label_orientation = pair[[2]],
      check_nestedness = FALSE
    )
    maps_new <- vapply(.label_text_layers(p_new), .maps_hjust, logical(1))
    maps_old <- vapply(.label_text_layers(p_old), .maps_hjust, logical(1))
    expect_identical(sort(maps_new), sort(maps_old))
    expect_identical(.n_drawn_labels(p_new), .n_drawn_labels(p_old))
  }
})

test_that("truncate_labels shows at least as many arc-following labels", {
  p_on <- krona_like_pq(
    data_fungi_mini,
    interactive = FALSE,
    label_orientation = "option1",
    truncate_labels = TRUE,
    check_nestedness = FALSE
  )
  p_off <- krona_like_pq(
    data_fungi_mini,
    interactive = FALSE,
    label_orientation = "option1",
    truncate_labels = FALSE,
    check_nestedness = FALSE
  )
  expect_gt(.n_drawn_labels(p_on), .n_drawn_labels(p_off))
  # A truncated label carries the ellipsis and never exceeds the original name.
  labs <- unlist(lapply(.label_text_layers(p_on), function(l) l$data$lab))
  expect_true(any(grepl("\\.\\.\\.", labs)))
})

test_that("truncate_labels must be a single logical", {
  expect_error(
    krona_like_pq(
      data_fungi_mini,
      interactive = FALSE,
      truncate_labels = "yes",
      check_nestedness = FALSE
    ),
    "truncate_labels"
  )
})

test_that("label_orientation = 'auto' centres internal labels, anchors leaf labels by side", {
  p <- krona_like_pq(
    data_fungi_mini,
    interactive = FALSE,
    label_orientation = "auto",
    check_nestedness = FALSE
  )
  lays <- .label_text_layers(p)
  maps <- vapply(lays, .maps_hjust, logical(1))
  expect_true(any(maps))
  expect_true(any(!maps))
})

test_that("leaf labels outside the rim draw a leader line by default; padding <= 0.03 omits it", {
  has_seg <- function(p) {
    any(vapply(
      p$layers,
      function(l) inherits(l$geom, "GeomSegment"),
      logical(1)
    ))
  }
  # Every mode except pure "tangential" places leaf labels outside the rim
  # by default (leaf_label_padding > 0.03), so all of them draw a leader.
  for (mode in c("auto", "radial", "mixed", "adaptive")) {
    p <- krona_like_pq(
      data_fungi_mini,
      interactive = FALSE,
      label_orientation = mode,
      check_nestedness = FALSE
    )
    expect_true(has_seg(p), info = mode)
  }
  p_tang <- krona_like_pq(
    data_fungi_mini,
    interactive = FALSE,
    label_orientation = "tangential",
    check_nestedness = FALSE
  )
  expect_false(has_seg(p_tang))
  p_zero_pad <- krona_like_pq(
    data_fungi_mini,
    interactive = FALSE,
    label_orientation = "radial",
    leaf_label_padding = 0,
    check_nestedness = FALSE
  )
  expect_false(has_seg(p_zero_pad))
})

# ---- grey_terms ------------------------------------------------------------

# Return the data of the first layer whose data has both 'name' and 'color'.
.rect_layer_data <- function(p) {
  for (l in p$layers) {
    d <- l$data
    if (is.data.frame(d) && all(c("name", "color") %in% names(d))) {
      return(d)
    }
  }
  NULL
}

test_that("grey_terms greys matching sections", {
  p <- krona_like_pq(
    data_fungi_mini,
    interactive = FALSE,
    grey_terms = "Basidiomycota",
    check_nestedness = FALSE
  )
  d <- .rect_layer_data(p)
  expect_false(is.null(d))
  skip_if_not("Basidiomycota" %in% d$name, "no Basidiomycota section")
  expect_true(all(d$color[d$name == "Basidiomycota"] == "#c8c8c8"))
})

test_that("grey_terms = character(0) applies no grey override", {
  p <- krona_like_pq(
    data_fungi_mini,
    interactive = FALSE,
    grey_terms = character(0),
    check_nestedness = FALSE
  )
  d <- .rect_layer_data(p)
  expect_false(is.null(d))
  expect_false(any(d$color == "#c8c8c8"))
})

# ---- add_unassigned_rank ---------------------------------------------------

test_that(".build_tax_hierarchy drops deep NAs when add_unassigned_rank > 0", {
  df <- data.frame(
    Phylum = c("P", "P"),
    Class = c("C", NA),
    stringsAsFactors = FALSE
  )
  w <- c(10, 5)
  h <- ggplotpq:::.build_tax_hierarchy(df, c("Phylum", "Class"), w, 0, 1)
  classes <- vapply(h$children[[1]]$children, function(x) x$name, character(1))
  expect_false("unassigned" %in% classes)
  expect_true("C" %in% classes)
})

test_that(".build_tax_hierarchy keeps NAs as 'unassigned' when rank is 0", {
  df <- data.frame(
    Phylum = c("P", "P"),
    Class = c("C", NA),
    stringsAsFactors = FALSE
  )
  w <- c(10, 5)
  h <- ggplotpq:::.build_tax_hierarchy(df, c("Phylum", "Class"), w, 0, 0)
  classes <- vapply(h$children[[1]]$children, function(x) x$name, character(1))
  expect_true("unassigned" %in% classes)
})

# ---- fill_unassigned -------------------------------------------------------

# Deepest depth reached by any node named "unassigned".
.max_unassigned_depth <- function(node, depth = 0) {
  d <- if (identical(node$name, "unassigned")) depth else -1
  for (k in node$children) {
    d <- max(d, .max_unassigned_depth(k, depth + 1))
  }
  d
}

test_that("fill_unassigned extends an unassigned arc to the deepest rank", {
  df <- data.frame(
    Phylum = c("P", "P"),
    Class = c("C", NA),
    Order = c("O", NA),
    stringsAsFactors = FALSE
  )
  w <- c(10, 5)
  rk <- c("Phylum", "Class", "Order")
  hT <- ggplotpq:::.build_tax_hierarchy(df, rk, w, 0, 0, fill_unassigned = TRUE)
  hF <- ggplotpq:::.build_tax_hierarchy(
    df,
    rk,
    w,
    0,
    0,
    fill_unassigned = FALSE
  )
  expect_equal(.max_unassigned_depth(hT), length(rk))
  expect_equal(.max_unassigned_depth(hF), 2L)
})

test_that("fill_unassigned default reaches the leaf ring via krona_like_pq", {
  p <- krona_like_pq(
    data_fungi_mini,
    interactive = FALSE,
    ranks = c("Phylum", "Class", "Order", "Family"),
    check_nestedness = FALSE
  )
  d <- .rect_layer_data(p)
  un <- d[d$name == "unassigned", , drop = FALSE]
  # at least one unassigned section reaches the outer (Family) rim
  expect_true(any(un$depthmax == max(d$depthmax)))
})

# ---- fill-chain merge (no border + single label) ---------------------------

test_that(".merge_fill_chains collapses an identical chain into one span", {
  df <- data.frame(
    name = c("A", "unassigned", "unassigned", "unassigned"),
    depth = c(1, 2, 3, 4),
    x0 = c(0, 0.5, 0.5, 0.5),
    x1 = c(0.5, 1, 1, 1),
    stringsAsFactors = FALSE
  )
  out <- ggplotpq:::.merge_fill_chains(df)
  # the three identical "unassigned" rows merge into one spanning row
  un <- out[out$name == "unassigned", , drop = FALSE]
  expect_equal(nrow(un), 1L)
  expect_true(un$spanning)
  expect_equal(un$depth, 2)
  expect_equal(un$depthmax, 5)
  # the non-chain "A" row is untouched
  expect_false(out$spanning[out$name == "A"])
})

test_that("auto mode draws leader lines (GeomSegment) for external leaves", {
  p <- krona_like_pq(
    data_fungi_mini,
    interactive = FALSE,
    label_orientation = "auto",
    check_nestedness = FALSE
  )
  has_seg <- any(vapply(
    p$layers,
    function(l) inherits(l$geom, "GeomSegment"),
    logical(1)
  ))
  expect_true(has_seg)
})

test_that("min_prop aggregate spans to the leaf ring when fill is on", {
  p <- krona_like_pq(
    data_fungi_mini,
    interactive = FALSE,
    min_prop = 0.05,
    ranks = c("Phylum", "Class", "Order", "Family"),
    check_nestedness = FALSE
  )
  d <- .rect_layer_data(p)
  agg <- d[grepl("more", d$name), , drop = FALSE]
  expect_gt(nrow(agg), 0)
  expect_true(any(agg$depthmax == max(d$depthmax)))
})

# ---- show_collapsed_path ---------------------------------------------------

test_that(".collapse_single_children records the skipped path", {
  leaf <- list(name = "sp", value = 5, depth = 3, children = list())
  genus <- list(name = "Genus", value = 5, depth = 2, children = list(leaf))
  family <- list(name = "Family", value = 5, depth = 1, children = list(genus))
  root_node <- list(name = "All", value = 5, depth = 0, children = list(family))
  res <- ggplotpq:::.collapse_single_children(root_node)
  # Family had a single child Genus (which has a child) -> Genus bubbles up
  expect_equal(res$children[[1]]$name, "Genus")
  expect_true("Family" %in% res$children[[1]]$collapsed_path)
})

test_that("show_collapsed_path marks collapsed labels distinctly", {
  # Internal radial labels are now centred within their own single-ring band
  # (see leaf/internal centring fix), so a long "path / name" prefix can be
  # truncated past the point where the literal " / " survives; the robust
  # signal that show_collapsed_path took effect is the dedicated grey ink
  # (#555555) applied to every collapsed-path row before truncation.
  p <- krona_like_pq(
    data_fungi_mini,
    interactive = FALSE,
    collapse_single = TRUE,
    show_collapsed_path = TRUE,
    check_nestedness = FALSE
  )
  lays <- .label_text_layers(p)
  cols <- unlist(lapply(lays, function(l) l$data$col))
  expect_true(any(cols == "#555555"))
})

test_that("show_collapsed_path = FALSE leaves labels without a path", {
  p <- krona_like_pq(
    data_fungi_mini,
    interactive = FALSE,
    collapse_single = TRUE,
    show_collapsed_path = FALSE,
    check_nestedness = FALSE
  )
  lays <- .label_text_layers(p)
  labs <- unlist(lapply(lays, function(l) l$data$lab))
  expect_false(any(grepl(" / ", labs, fixed = TRUE)))
})

# ---- weight_by edge cases --------------------------------------------------

test_that("zero-weight taxa are dropped with a warning", {
  w <- rep(1, phyloseq::ntaxa(data_fungi_mini))
  w[1] <- 0
  expect_warning(
    krona_like_pq(
      data_fungi_mini,
      weight_by = w,
      interactive = FALSE,
      check_nestedness = FALSE
    ),
    "zero weight"
  )
})

test_that("named weight_by with mismatched names aborts", {
  w <- rep(1, phyloseq::ntaxa(data_fungi_mini))
  names(w) <- paste0("wrong", seq_along(w))
  expect_error(
    krona_like_pq(data_fungi_mini, weight_by = w, interactive = FALSE),
    "taxa_names"
  )
})

test_that("named weight_by is aligned by name, not position", {
  tn <- phyloseq::taxa_names(data_fungi_mini)
  w <- stats::setNames(seq_along(tn), rev(tn))
  p <- krona_like_pq(
    data_fungi_mini,
    weight_by = w,
    interactive = FALSE,
    check_nestedness = FALSE
  )
  expect_s3_class(p, "ggplot")
  w_resolved <- ggplotpq:::.resolve_weights(data_fungi_mini, w)
  expect_equal(w_resolved[tn], w[tn])
})

# ---- label_orientation: mixed / adaptive -----------------------------------

test_that("label_orientation = 'mixed' has both tangential and radial layers", {
  p <- krona_like_pq(
    data_fungi_mini,
    interactive = FALSE,
    label_orientation = "mixed",
    check_nestedness = FALSE
  )
  lays <- .label_text_layers(p)
  expect_true(any(vapply(lays, .maps_hjust, logical(1))))
  expect_true(any(!vapply(lays, .maps_hjust, logical(1))))
})

test_that("label_orientation = 'mixed' leaf labels sit outside the rim like every other mode", {
  # Leaf-radial placement is unified across modes (rim + leaf_label_padding);
  # "mixed" no longer has a separate inside-the-rim leaf style, so it draws a
  # leader line under the default padding just like auto/radial/adaptive
  # (covered together in the "leaf labels outside the rim" test above).
  p <- krona_like_pq(
    data_fungi_mini,
    interactive = FALSE,
    label_orientation = "mixed",
    leaf_label_padding = 0,
    check_nestedness = FALSE
  )
  has_seg <- any(vapply(
    p$layers,
    function(l) inherits(l$geom, "GeomSegment"),
    logical(1)
  ))
  expect_false(has_seg)
})

test_that("label_orientation = 'adaptive' returns ggplot", {
  p <- krona_like_pq(
    data_fungi_mini,
    interactive = FALSE,
    label_orientation = "adaptive",
    check_nestedness = FALSE
  )
  expect_s3_class(p, "ggplot")
  lays <- .label_text_layers(p)
  expect_gt(length(lays), 0)
})

# ---- dismiss_overlaps -------------------------------------------------------

test_that(".dismiss_overlapping_labels thins a tight angular cluster, keeping the highest value", {
  df <- data.frame(
    xmid = c(0, 0.02, 0.04, 3.0),
    value = c(10, 50, 5, 20)
  )
  out <- ggplotpq:::.dismiss_overlapping_labels(df, min_gap = 0.3)
  expect_false(out$overlap_dismissed[2]) # highest value in the tight cluster
  expect_true(out$overlap_dismissed[1])
  expect_true(out$overlap_dismissed[3])
  expect_false(out$overlap_dismissed[4]) # far away, unaffected
})

test_that(".dismiss_overlapping_labels never dismisses across different groups", {
  df <- data.frame(
    xmid = c(1.0, 1.001),
    value = c(100, 90)
  )
  out <- ggplotpq:::.dismiss_overlapping_labels(
    df,
    min_gap = 0.3,
    group = c(1, 2)
  )
  expect_false(any(out$overlap_dismissed))
})

test_that(".dismiss_overlapping_labels is a no-op for a single row", {
  df <- data.frame(xmid = 1.5, value = 10)
  out <- ggplotpq:::.dismiss_overlapping_labels(df)
  expect_false(out$overlap_dismissed)
})

test_that("dismiss_overlaps = FALSE restores the unfiltered placement", {
  p_on <- krona_like_pq(
    data_fungi_mini,
    interactive = FALSE,
    dismiss_overlaps = TRUE,
    check_nestedness = FALSE
  )
  p_off <- krona_like_pq(
    data_fungi_mini,
    interactive = FALSE,
    dismiss_overlaps = FALSE,
    check_nestedness = FALSE
  )
  n_labels <- function(p) {
    sum(vapply(.label_text_layers(p), function(l) nrow(l$data), integer(1)))
  }
  expect_gte(n_labels(p_off), n_labels(p_on))
})

# ---- label_fallback / fallback_symbol / fallback_nchar ---------------------

test_that(".fallback_marker_label 'dot' returns the symbol for every name", {
  out <- ggplotpq:::.fallback_marker_label(c("a", NA, "bcd"), "dot", "*", 3)
  expect_equal(out, c("*", "*", "*"))
})

test_that(".fallback_marker_label 'initials' truncates to nchar_cap", {
  out <- ggplotpq:::.fallback_marker_label(
    c("Basidiomycota", "Ab"),
    "initials",
    "*",
    3
  )
  expect_equal(out, c("Bas", "Ab"))
})

test_that(".fallback_marker_label 'none' returns NA for every name", {
  out <- ggplotpq:::.fallback_marker_label(c("a", "b"), "none", "*", 3)
  expect_true(all(is.na(out)))
})

test_that("label_fallback = 'initials' shows short names instead of the dot", {
  p <- krona_like_pq(
    data_fungi_mini,
    interactive = FALSE,
    label_fallback = "initials",
    fallback_nchar = 3,
    check_nestedness = FALSE
  )
  expect_s3_class(p, "ggplot")
  marker_layer <- Filter(
    function(l) inherits(l$geom, "GeomText") && "marker" %in% names(l$data),
    p$layers
  )
  expect_gt(length(marker_layer), 0)
  markers <- marker_layer[[1]]$data$marker
  expect_true(all(nchar(markers) <= 3))
})

test_that("label_fallback = 'none' draws no fallback marker layer", {
  p <- krona_like_pq(
    data_fungi_mini,
    interactive = FALSE,
    label_fallback = "none",
    check_nestedness = FALSE
  )
  marker_layer <- Filter(
    function(l) inherits(l$geom, "GeomText") && "marker" %in% names(l$data),
    p$layers
  )
  expect_equal(length(marker_layer), 0)
})

test_that("fallback_symbol changes the dot glyph", {
  p <- krona_like_pq(
    data_fungi_mini,
    interactive = FALSE,
    label_fallback = "dot",
    fallback_symbol = "+",
    check_nestedness = FALSE
  )
  marker_layer <- Filter(
    function(l) inherits(l$geom, "GeomText") && "marker" %in% names(l$data),
    p$layers
  )
  expect_gt(length(marker_layer), 0)
  expect_true(all(marker_layer[[1]]$data$marker == "+"))
})

test_that("invalid fallback_symbol aborts", {
  expect_error(
    krona_like_pq(data_fungi_mini, interactive = FALSE, fallback_symbol = ""),
    "fallback_symbol"
  )
})

test_that("invalid fallback_nchar aborts", {
  expect_error(
    krona_like_pq(data_fungi_mini, interactive = FALSE, fallback_nchar = 0),
    "fallback_nchar"
  )
})

test_that("invalid label_fallback aborts", {
  expect_error(
    krona_like_pq(
      data_fungi_mini,
      interactive = FALSE,
      label_fallback = "wrong"
    )
  )
})

# ---- leaf_label_padding / internal radial centring -------------------------

test_that("leaf radial labels sit outside the rim by default (anchor > rim)", {
  p <- krona_like_pq(
    data_fungi_mini,
    interactive = FALSE,
    label_orientation = "radial",
    check_nestedness = FALSE
  )
  lays <- .label_text_layers(p)
  # Leaf layers use hjust (aes-mapped); their y column is the outside-rim
  # anchor, which must exceed the leaf depth (i.e. the rim).
  leaf_lays <- Filter(.maps_hjust, lays)
  expect_gt(length(leaf_lays), 0)
  for (l in leaf_lays) {
    y_col <- l$mapping$y
    y_vals <- rlang::eval_tidy(y_col, l$data)
    expect_true(all(y_vals > l$data$depth))
  }
})

test_that("negative leaf_label_padding pulls leaf labels back toward the rim", {
  p_out <- krona_like_pq(
    data_fungi_mini,
    interactive = FALSE,
    label_orientation = "radial",
    leaf_label_padding = 0.5,
    check_nestedness = FALSE
  )
  p_in <- krona_like_pq(
    data_fungi_mini,
    interactive = FALSE,
    label_orientation = "radial",
    leaf_label_padding = -0.5,
    check_nestedness = FALSE
  )
  max_y <- function(p) {
    lays <- Filter(.maps_hjust, .label_text_layers(p))
    max(unlist(lapply(lays, function(l) {
      rlang::eval_tidy(l$mapping$y, l$data)
    })))
  }
  expect_gt(max_y(p_out), max_y(p_in))
})

test_that("internal radial labels centre on their own band", {
  p <- krona_like_pq(
    data_fungi_mini,
    interactive = FALSE,
    label_orientation = "radial",
    check_nestedness = FALSE
  )
  lays <- .label_text_layers(p)
  # Internal layers do not map hjust (constant 0.5 now); their y anchor
  # should equal depth + 0.5, the centre of a single-ring band.
  inner_lays <- Filter(function(l) !.maps_hjust(l), lays)
  expect_gt(length(inner_lays), 0)
  for (l in inner_lays) {
    y_col <- l$mapping$y
    y_vals <- rlang::eval_tidy(y_col, l$data)
    expect_equal(y_vals, l$data$depth + 0.5)
  }
})

test_that("default leaf labels read as a spoke, internal labels as arc-following", {
  # Regression test for the visual-effect/naming mismatch discovered while
  # implementing this: under coord_polar(start = -pi/2), the formula that
  # keeps its OWN flip axis at data-x = 0/pi renders arc-following, and the
  # one flipping at data-x = pi/2/3*pi/2 renders as a spoke -- confirmed by
  # rendering a synthetic 8-wedge test circle with each formula, independent
  # of this package's naming. Leaf labels (`auto` default) must use the
  # spoke-look formula; internal labels must keep the arc-following one.
  ang_norm <- function(a) ((a + 90) %% 180) - 90
  ang_radial_of <- function(x) ang_norm(-(x / (2 * pi)) * 360 + 90)
  ang_tang_of <- function(x) ang_norm(-(x / (2 * pi)) * 360)

  p <- krona_like_pq(
    data_fungi_mini,
    interactive = FALSE,
    check_nestedness = FALSE
  )
  lays <- .label_text_layers(p)
  leaf_lays <- Filter(.maps_hjust, lays)
  inner_lays <- Filter(function(l) !.maps_hjust(l), lays)
  expect_gt(length(leaf_lays), 0)
  expect_gt(length(inner_lays), 0)
  for (l in leaf_lays) {
    expect_equal(l$data$ang, ang_tang_of(l$data$xmid))
  }
  for (l in inner_lays) {
    expect_equal(l$data$ang, ang_radial_of(l$data$xmid))
  }
})

test_that("leaf hjust flips at the same axis as its own rotation formula", {
  # hj_side must switch at data-x = pi/2 and 3*pi/2 (the spoke-look formula's
  # own flip axis), not at pi (a mismatch here made labels fold back over
  # their own wedge instead of extending outward -- caught by rendering).
  p <- krona_like_pq(
    data_fungi_mini,
    interactive = FALSE,
    label_orientation = "radial",
    check_nestedness = FALSE
  )
  leaf_lays <- Filter(.maps_hjust, .label_text_layers(p))
  for (l in leaf_lays) {
    hj <- rlang::eval_tidy(l$mapping$hjust, l$data)
    expected <- ifelse(
      l$data$xmid > pi / 2 & l$data$xmid < 3 * pi / 2,
      0,
      1
    )
    expect_equal(hj, expected)
  }
})

# ---- label_fallback = "legend" ----------------------------------------------

test_that(".assign_unique_codes returns unique codes, disambiguating collisions", {
  codes <- ggplotpq:::.assign_unique_codes(
    c("Stereum", "Stereaceae", "Steccherinaceae"),
    nchar_cap = 3
  )
  expect_equal(length(codes), length(unique(codes)))
  expect_true(all(nchar(codes) >= 3))
})

test_that(".assign_unique_codes falls back to a numeric suffix when exhausted", {
  # "AB" has only two possible 3-char windows is none (shorter than cap);
  # forcing repeats should still yield unique codes via numeric suffixes.
  codes <- ggplotpq:::.assign_unique_codes(c("AB", "AB", "AB"), nchar_cap = 3)
  expect_equal(length(codes), length(unique(codes)))
})

test_that(".legend_fallback assigns a code when it fits, else a number, else NA", {
  df <- data.frame(
    name = c("Amanita", "B"),
    arcw = c(10, 0.001),
    ymid = c(5, 5),
    stringsAsFactors = FALSE
  )
  res <- ggplotpq:::.legend_fallback(df, nchar_cap = 3, cw = 0.16)
  expect_false(is.na(res$marker[1]))
  expect_equal(nrow(res$legend), sum(!is.na(res$marker)))
})

test_that("label_fallback = 'legend' renders a legend annotation and short markers", {
  p <- krona_like_pq(
    data_fungi_mini,
    interactive = FALSE,
    label_orientation = "adaptive",
    label_fallback = "legend",
    check_nestedness = FALSE
  )
  expect_s3_class(p, "ggplot")
  marker_layer <- Filter(
    function(l) inherits(l$geom, "GeomText") && "marker" %in% names(l$data),
    p$layers
  )
  expect_gt(length(marker_layer), 0)
  markers <- marker_layer[[1]]$data$marker
  expect_true(all(nchar(markers) <= 3))
  is_annotate_text <- vapply(
    p$layers,
    function(l) {
      inherits(l$geom, "GeomText") &&
        !is.null(l$aes_params[["label"]]) &&
        grepl("—", l$aes_params[["label"]], fixed = TRUE)
    },
    logical(1)
  )
  expect_true(any(is_annotate_text))
})
