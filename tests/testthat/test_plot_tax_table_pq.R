test_that("plot_tax_table_pq returns a combined patchwork by default", {
  skip_if_not_installed("MiscMetabar")
  skip_if_not_installed("phyloseq")
  skip_if_not_installed("patchwork")
  skip_if_not_installed("ggfittext")
  data(data_fungi_mini, package = "MiscMetabar")

  p <- plot_tax_table_pq(data_fungi_mini, ranks = c("Phylum", "Class"))
  expect_s3_class(p, "patchwork")
})

test_that("plot_tax_table_pq combine = FALSE returns a named list of ggplots", {
  skip_if_not_installed("MiscMetabar")
  skip_if_not_installed("phyloseq")
  skip_if_not_installed("ggfittext")
  data(data_fungi_mini, package = "MiscMetabar")

  pl <- plot_tax_table_pq(
    data_fungi_mini,
    ranks = c("Phylum", "Class"),
    combine = FALSE
  )
  expect_type(pl, "list")
  expect_named(pl, c("Phylum", "Class"))
  expect_s3_class(pl[["Phylum"]], "ggplot")
  expect_s3_class(pl[["Class"]], "ggplot")
})

test_that("plot_tax_table_pq defaults to rank_names(physeq) when ranks is omitted", {
  skip_if_not_installed("MiscMetabar")
  skip_if_not_installed("phyloseq")
  skip_if_not_installed("ggfittext")
  data(data_fungi_mini, package = "MiscMetabar")

  pl <- plot_tax_table_pq(data_fungi_mini, combine = FALSE)
  expect_named(
    pl,
    phyloseq::rank_names(data_fungi_mini)
  )
})

test_that("plot_tax_table_pq builds a thin raincloud row for numeric columns", {
  skip_if_not_installed("MiscMetabar")
  skip_if_not_installed("phyloseq")
  skip_if_not_installed("tidypq")
  skip_if_not_installed("ggfittext")
  data(data_fungi_mini, package = "MiscMetabar")

  dfm <- tidypq::mutate_taxa_pq(
    data_fungi_mini,
    Mol_Abundance = phyloseq::taxa_sums(.)
  )
  pl <- plot_tax_table_pq(dfm, ranks = "Mol_Abundance", combine = FALSE)
  built <- ggplot2::ggplot_build(pl[["Mol_Abundance"]])
  geoms <- vapply(
    built$plot$layers,
    function(l) {
      class(l$geom)[1]
    },
    character(1)
  )
  expect_true("GeomViolin" %in% geoms)
  expect_true("GeomBoxplot" %in% geoms)
})

test_that("plot_tax_table_pq annotates n and NA proportion on numeric rows", {
  skip_if_not_installed("MiscMetabar")
  skip_if_not_installed("phyloseq")
  skip_if_not_installed("tidypq")
  skip_if_not_installed("ggfittext")
  data(data_fungi_mini, package = "MiscMetabar")

  mol <- phyloseq::taxa_sums(data_fungi_mini)
  mol[1:5] <- NA
  dfm <- tidypq::mutate_taxa_pq(data_fungi_mini, Mol_Abundance = mol)

  pl_na <- plot_tax_table_pq(dfm, ranks = "Mol_Abundance", combine = FALSE)
  built_na <- ggplot2::ggplot_build(pl_na[["Mol_Abundance"]])
  geoms_na <- vapply(
    built_na$plot$layers,
    function(l) class(l$geom)[1],
    character(1)
  )
  expect_true("GeomLabel" %in% geoms_na)
  na_label_data <- built_na$data[[which(geoms_na == "GeomLabel")]]
  expect_equal(na_label_data$label, "n = 40 (11% NA)")
})

test_that("plot_tax_table_pq still annotates n when there is no NA", {
  skip_if_not_installed("MiscMetabar")
  skip_if_not_installed("phyloseq")
  skip_if_not_installed("tidypq")
  skip_if_not_installed("ggfittext")
  data(data_fungi_mini, package = "MiscMetabar")

  dfm_no_na <- tidypq::mutate_taxa_pq(
    data_fungi_mini,
    Mol_Abundance = phyloseq::taxa_sums(.)
  )
  pl_no_na <- plot_tax_table_pq(
    dfm_no_na,
    ranks = "Mol_Abundance",
    combine = FALSE
  )
  built_no_na <- ggplot2::ggplot_build(pl_no_na[["Mol_Abundance"]])
  geoms_no_na <- vapply(
    built_no_na$plot$layers,
    function(l) class(l$geom)[1],
    character(1)
  )
  expect_true("GeomLabel" %in% geoms_no_na)
  no_na_label_data <- built_no_na$data[[which(geoms_no_na == "GeomLabel")]]
  expect_equal(no_na_label_data$label, "n = 45")
})

test_that("plot_tax_table_pq builds a stacked bar row for factor columns", {
  skip_if_not_installed("MiscMetabar")
  skip_if_not_installed("phyloseq")
  skip_if_not_installed("ggfittext")
  data(data_fungi_mini, package = "MiscMetabar")

  pl <- plot_tax_table_pq(data_fungi_mini, ranks = "Class", combine = FALSE)
  built <- ggplot2::ggplot_build(pl[["Class"]])
  # one rect per category (including NA)
  n_cat <- length(unique(phyloseq::tax_table(data_fungi_mini)[, "Class"]))
  expect_equal(nrow(built$data[[1]]), n_cat)
})

test_that("plot_tax_table_pq colors below-threshold categories grey70", {
  skip_if_not_installed("MiscMetabar")
  skip_if_not_installed("phyloseq")
  skip_if_not_installed("ggfittext")
  data(data_fungi_mini, package = "MiscMetabar")

  # Species has many rare values, well below a 20% threshold
  pl <- plot_tax_table_pq(
    data_fungi_mini,
    ranks = "Species",
    threshold = 0.2,
    combine = FALSE
  )
  built <- ggplot2::ggplot_build(pl[["Species"]])
  expect_true("grey70" %in% built$data[[1]]$fill)
})

test_that("plot_tax_table_pq gives boolean-like columns a fixed color scheme", {
  skip_if_not_installed("MiscMetabar")
  skip_if_not_installed("phyloseq")
  skip_if_not_installed("tidypq")
  skip_if_not_installed("ggfittext")
  data(data_fungi_mini, package = "MiscMetabar")

  dfm <- tidypq::mutate_taxa_pq(
    data_fungi_mini,
    Bool_col = ifelse(Trophic.Mode == "Saprotroph", "TRUE", "FALSE")
  )
  pl <- plot_tax_table_pq(dfm, ranks = "Bool_col", combine = FALSE)
  built <- ggplot2::ggplot_build(pl[["Bool_col"]])
  fill_by_value <- stats::setNames(built$data[[1]]$fill, built$plot$data$value)
  expect_equal(as.character(fill_by_value["TRUE"]), "olivedrab")
  expect_equal(as.character(fill_by_value["FALSE"]), "firebrick")
})

test_that("plot_tax_table_pq detects mixed TRUE/FALSE/other columns as boolean-like", {
  skip_if_not_installed("MiscMetabar")
  skip_if_not_installed("phyloseq")
  skip_if_not_installed("tidypq")
  skip_if_not_installed("ggfittext")
  data(data_fungi_mini, package = "MiscMetabar")

  set.seed(1)
  mixed <- sample(
    c("TRUE", "FALSE", "uncertain"),
    phyloseq::ntaxa(data_fungi_mini),
    replace = TRUE,
    prob = c(0.5, 0.3, 0.2)
  )
  dfm <- tidypq::mutate_taxa_pq(data_fungi_mini, Bool_col = mixed)
  pl <- plot_tax_table_pq(dfm, ranks = "Bool_col", combine = FALSE)
  built <- ggplot2::ggplot_build(pl[["Bool_col"]])
  fill_by_value <- stats::setNames(built$data[[1]]$fill, built$plot$data$value)
  expect_equal(as.character(fill_by_value["TRUE"]), "olivedrab")
  expect_equal(as.character(fill_by_value["FALSE"]), "firebrick")
  expect_false(
    as.character(fill_by_value["uncertain"]) %in%
      c("olivedrab", "firebrick", "grey30")
  )
})

test_that("plot_tax_table_pq marks NA zones in dark grey", {
  skip_if_not_installed("MiscMetabar")
  skip_if_not_installed("phyloseq")
  skip_if_not_installed("ggfittext")
  data(data_fungi_mini, package = "MiscMetabar")

  pl <- plot_tax_table_pq(data_fungi_mini, ranks = "Genus", combine = FALSE)
  built <- ggplot2::ggplot_build(pl[["Genus"]])
  expect_true("grey30" %in% built$data[[1]]$fill)
})

test_that("plot_tax_table_pq treats na_equivalent values as NA", {
  skip_if_not_installed("MiscMetabar")
  skip_if_not_installed("phyloseq")
  skip_if_not_installed("ggfittext")
  data(data_fungi_mini, package = "MiscMetabar")

  # Confidence.Ranking uses "-" as a placeholder for missing values
  pl_default <- plot_tax_table_pq(
    data_fungi_mini,
    ranks = "Confidence.Ranking",
    combine = FALSE
  )
  built_default <- ggplot2::ggplot_build(pl_default[["Confidence.Ranking"]])
  expect_true("grey30" %in% built_default$data[[1]]$fill)

  pl_raw <- plot_tax_table_pq(
    data_fungi_mini,
    ranks = "Confidence.Ranking",
    na_equivalent = NULL,
    combine = FALSE
  )
  built_raw <- ggplot2::ggplot_build(pl_raw[["Confidence.Ranking"]])
  expect_false("grey30" %in% built_raw$data[[1]]$fill)
})

test_that("plot_tax_table_pq handles logical columns as a two-zone bar", {
  skip_if_not_installed("MiscMetabar")
  skip_if_not_installed("phyloseq")
  skip_if_not_installed("tidypq")
  skip_if_not_installed("ggfittext")
  data(data_fungi_mini, package = "MiscMetabar")

  dfm <- tidypq::mutate_taxa_pq(
    data_fungi_mini,
    is_sapro = Trophic.Mode == "Saprotroph"
  )
  pl <- plot_tax_table_pq(dfm, ranks = "is_sapro", combine = FALSE)
  built <- ggplot2::ggplot_build(pl[["is_sapro"]])
  expect_equal(nrow(built$data[[1]]), 2)
})

test_that("plot_tax_table_pq discards fully-NA columns by default", {
  skip_if_not_installed("MiscMetabar")
  skip_if_not_installed("phyloseq")
  skip_if_not_installed("tidypq")
  skip_if_not_installed("ggfittext")
  data(data_fungi_mini, package = "MiscMetabar")

  dfm <- tidypq::mutate_taxa_pq(data_fungi_mini, All_NA_col = NA_character_)
  expect_message(
    pl <- plot_tax_table_pq(
      dfm,
      ranks = c("Phylum", "All_NA_col"),
      combine = FALSE
    ),
    "discarded"
  )
  expect_named(pl, "Phylum")
})

test_that("plot_tax_table_pq keeps fully-NA columns as a dark grey NA row when asked", {
  skip_if_not_installed("MiscMetabar")
  skip_if_not_installed("phyloseq")
  skip_if_not_installed("tidypq")
  skip_if_not_installed("ggfittext")
  data(data_fungi_mini, package = "MiscMetabar")

  dfm_chr <- tidypq::mutate_taxa_pq(data_fungi_mini, All_NA_col = NA_character_)
  pl_chr <- plot_tax_table_pq(
    dfm_chr,
    ranks = c("Phylum", "All_NA_col"),
    discard_full_NA_column = FALSE,
    combine = FALSE
  )
  expect_named(pl_chr, c("Phylum", "All_NA_col"))
  built_chr <- ggplot2::ggplot_build(pl_chr[["All_NA_col"]])
  expect_true(all(built_chr$data[[1]]$fill == "grey30"))

  dfm_num <- tidypq::mutate_taxa_pq(data_fungi_mini, All_NA_num = NA_real_)
  pl_num <- plot_tax_table_pq(
    dfm_num,
    ranks = c("Phylum", "All_NA_num"),
    discard_full_NA_column = FALSE,
    combine = FALSE
  )
  expect_named(pl_num, c("Phylum", "All_NA_num"))
  built_num <- ggplot2::ggplot_build(pl_num[["All_NA_num"]])
  expect_true(all(built_num$data[[1]]$fill == "grey30"))
})

test_that("plot_tax_table_pq aborts when a rank is not found", {
  skip_if_not_installed("MiscMetabar")
  skip_if_not_installed("phyloseq")
  skip_if_not_installed("ggfittext")
  data(data_fungi_mini, package = "MiscMetabar")

  expect_error(
    plot_tax_table_pq(
      data_fungi_mini,
      ranks = "NotAColumn",
      combine = FALSE
    ),
    "not found"
  )
})

test_that("plot_tax_table_pq splits into chunked combined figures when > max_combined_ranks columns are selected", {
  skip_if_not_installed("MiscMetabar")
  skip_if_not_installed("phyloseq")
  skip_if_not_installed("patchwork")
  skip_if_not_installed("ggfittext")
  data(data_fungi_mini, package = "MiscMetabar")

  tt <- as.data.frame(phyloseq::tax_table(data_fungi_mini))
  for (i in 1:20) {
    tt[[paste0("Extra", i)]] <- tt$Phylum
  }
  phyloseq::tax_table(data_fungi_mini) <- phyloseq::tax_table(as.matrix(tt))
  n_ranks <- length(phyloseq::rank_names(data_fungi_mini))

  expect_message(
    pl <- plot_tax_table_pq(data_fungi_mini),
    "splitting into"
  )
  expect_type(pl, "list")
  expect_length(pl, ceiling(n_ranks / 25))
  expect_true(all(vapply(pl, inherits, logical(1), "patchwork")))
})

test_that("plot_tax_table_pq respects a raised max_combined_ranks", {
  skip_if_not_installed("MiscMetabar")
  skip_if_not_installed("phyloseq")
  skip_if_not_installed("patchwork")
  skip_if_not_installed("ggfittext")
  data(data_fungi_mini, package = "MiscMetabar")

  tt <- as.data.frame(phyloseq::tax_table(data_fungi_mini))
  for (i in 1:20) {
    tt[[paste0("Extra", i)]] <- tt$Phylum
  }
  phyloseq::tax_table(data_fungi_mini) <- phyloseq::tax_table(as.matrix(tt))

  p <- plot_tax_table_pq(data_fungi_mini, max_combined_ranks = 40)
  expect_s3_class(p, "patchwork")
})

test_that("plot_tax_table_pq combine = FALSE ignores max_combined_ranks", {
  skip_if_not_installed("MiscMetabar")
  skip_if_not_installed("phyloseq")
  skip_if_not_installed("ggfittext")
  data(data_fungi_mini, package = "MiscMetabar")

  tt <- as.data.frame(phyloseq::tax_table(data_fungi_mini))
  for (i in 1:20) {
    tt[[paste0("Extra", i)]] <- tt$Phylum
  }
  phyloseq::tax_table(data_fungi_mini) <- phyloseq::tax_table(as.matrix(tt))
  n_ranks <- length(phyloseq::rank_names(data_fungi_mini))

  pl <- plot_tax_table_pq(data_fungi_mini, combine = FALSE)
  expect_length(pl, n_ranks)
  expect_true(all(vapply(pl, inherits, logical(1), "ggplot")))
})

test_that("plot_tax_table_pq shows a shared Proportion x-axis on the last bar row only (combine = FALSE)", {
  skip_if_not_installed("MiscMetabar")
  skip_if_not_installed("phyloseq")
  skip_if_not_installed("ggfittext")
  data(data_fungi_mini, package = "MiscMetabar")

  pl <- plot_tax_table_pq(
    data_fungi_mini,
    ranks = c("Phylum", "Class", "Order"),
    combine = FALSE
  )
  expect_null(ggplot2::ggplot_build(pl$Phylum)$plot$labels$x)
  expect_null(ggplot2::ggplot_build(pl$Class)$plot$labels$x)
  expect_equal(ggplot2::ggplot_build(pl$Order)$plot$labels$x, "Proportion")
})

test_that("plot_tax_table_pq shows a shared Proportion x-axis on the last bar row only (combined)", {
  skip_if_not_installed("MiscMetabar")
  skip_if_not_installed("phyloseq")
  skip_if_not_installed("patchwork")
  skip_if_not_installed("ggfittext")
  data(data_fungi_mini, package = "MiscMetabar")

  dfm <- tidypq::mutate_taxa_pq(
    data_fungi_mini,
    Mol_Abundance = phyloseq::taxa_sums(.)
  )
  p <- plot_tax_table_pq(
    dfm,
    ranks = c("Phylum", "Class", "Mol_Abundance"),
    combine = FALSE
  )
  # numeric row after the last bar row: axis still lands on the last bar row
  expect_null(ggplot2::ggplot_build(p$Phylum)$plot$labels$x)
  expect_equal(ggplot2::ggplot_build(p$Class)$plot$labels$x, "Proportion")
})

test_that("plot_tax_table_pq adds no Proportion axis when there is no bar row", {
  skip_if_not_installed("MiscMetabar")
  skip_if_not_installed("phyloseq")
  skip_if_not_installed("tidypq")
  skip_if_not_installed("ggfittext")
  data(data_fungi_mini, package = "MiscMetabar")

  dfm <- tidypq::mutate_taxa_pq(
    data_fungi_mini,
    Mol_Abundance = phyloseq::taxa_sums(.)
  )
  pl <- plot_tax_table_pq(dfm, ranks = "Mol_Abundance", combine = FALSE)
  expect_false(
    identical(
      ggplot2::ggplot_build(pl$Mol_Abundance)$plot$labels$x,
      "Proportion"
    )
  )
})
