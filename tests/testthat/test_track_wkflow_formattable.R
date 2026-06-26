test_that("track_wkflow_formattable returns a formattable object", {
  skip_if_not_installed("formattable")
  skip_if_not_installed("htmltools")
  track_df <- data.frame(
    nb_sequences = c(10000, 8000),
    nb_clusters = c(500, 400),
    nb_samples = c(10, 10),
    row.names = c("raw", "filt")
  )
  ft <- track_wkflow_formattable(track_df)
  expect_s3_class(ft, "formattable")
})

test_that("track_wkflow_formattable handles extra-metrics columns", {
  skip_if_not_installed("formattable")
  skip_if_not_installed("htmltools")
  track_df <- data.frame(
    nb_sequences = c(10000, 8000),
    nb_clusters = c(500, 400),
    nb_samples = c(10, 10),
    nb_occurrences = c(2000, 1500),
    nb_rank = c(7, 7),
    prop_na_Genus = c(0.1, 0.3),
    prop_na_Family = c(0.05, 0.2),
    nb_sam_metadata = c(5, 5),
    mean_length_seq = c(250, 260),
    max_length_seq = c(300, 320),
    min_length_seq = c(200, 210),
    genetic_diversity_weighted = c(0.05, 0.06),
    genetic_diversity_unweighted = c(0.07, 0.08),
    n_samples_High = c(5, 5),
    n_samples_Low = c(5, 5),
    row.names = c("raw", "filt")
  )
  ft <- track_wkflow_formattable(track_df)
  expect_s3_class(ft, "formattable")
  out <- as.data.frame(ft)
  expect_true("nb_occurrences" %in% colnames(out))
  expect_true("prop_na_Genus" %in% colnames(out))
  expect_true("n_samples_High" %in% colnames(out))
  expect_true("mean_length_seq" %in% colnames(out))
})

test_that("track_wkflow_formattable adds delta_occurrences with parent", {
  skip_if_not_installed("formattable")
  skip_if_not_installed("htmltools")
  track_df <- data.frame(
    nb_sequences = c(10000, 8000),
    nb_clusters = c(500, 400),
    nb_samples = c(10, 10),
    nb_occurrences = c(2000, 1500),
    row.names = c("raw", "filt")
  )
  parent <- c(raw = NA, filt = "raw")
  ft <- track_wkflow_formattable(track_df, parent = parent)
  out <- as.data.frame(ft)
  expect_true("\u0394_occurrences" %in% colnames(out))
  expect_true("\u0394_sequences" %in% colnames(out))
  expect_true("\u0394_clusters" %in% colnames(out))
  expect_true("\u0394_samples" %in% colnames(out))
  expect_false("retention" %in% colnames(out))
})

test_that("track_wkflow_formattable no diff columns without parent", {
  skip_if_not_installed("formattable")
  skip_if_not_installed("htmltools")
  track_df <- data.frame(
    nb_sequences = c(10000, 8000),
    nb_clusters = c(500, 400),
    nb_samples = c(10, 10),
    nb_occurrences = c(2000, 1500),
    row.names = c("raw", "filt")
  )
  ft <- track_wkflow_formattable(track_df)
  out <- as.data.frame(ft)
  expect_false("\u0394_occurrences" %in% colnames(out))
  expect_false("\u0394_sequences" %in% colnames(out))
  expect_false("\u0394_samples" %in% colnames(out))
  expect_false("retention" %in% colnames(out))
})

test_that("track_wkflow_formattable works with real track_wkflow extra metrics", {
  skip_if_not_installed("formattable")
  skip_if_not_installed("htmltools")
  skip_if_not_installed("MiscMetabar")
  skip_on_cran()
  data(data_fungi_mini, package = "MiscMetabar")
  d_filt <- phyloseq::prune_taxa(
    phyloseq::taxa_sums(data_fungi_mini) > 10, data_fungi_mini
  )
  track <- MiscMetabar::track_wkflow(
    list("raw" = data_fungi_mini, "filt" = d_filt),
    compute_occurrences = TRUE,
    compute_taxo_info = TRUE,
    compute_seq_length = TRUE
  )
  parent <- c(raw = NA, filt = "raw")
  ft <- track_wkflow_formattable(track, parent = parent)
  expect_s3_class(ft, "formattable")
  out <- as.data.frame(ft)
  expect_true("nb_occurrences" %in% colnames(out))
  expect_true("prop_na_Genus" %in% colnames(out))
  expect_true("mean_length_seq" %in% colnames(out))
  expect_true("\u0394_occurrences" %in% colnames(out))
})

test_that("track_wkflow_formattable accepts color override args", {
  skip_if_not_installed("formattable")
  skip_if_not_installed("htmltools")
  track_df <- data.frame(
    nb_sequences = c(10000, 8000),
    nb_clusters = c(500, 400),
    nb_samples = c(10, 10),
    prop_na_Genus = c(0.1, 0.3),
    row.names = c("raw", "filt")
  )
  expect_no_error(
    track_wkflow_formattable(track_df,
      na_bar_color = "darkred",
      div_bar_color = "blue",
      seq_tile_low = "yellow",
      seq_tile_high = "green"
    )
  )
})

test_that("track_wkflow_formattable rounds numeric columns", {
  skip_if_not_installed("formattable")
  skip_if_not_installed("htmltools")
  track_df <- data.frame(
    nb_sequences = c(10000, 8000),
    nb_clusters = c(500, 400),
    nb_samples = c(10, 10),
    prop_na_Genus = c(0.123456, 0.987654),
    mean_length_seq = c(250.333, 260.666),
    row.names = c("raw", "filt")
  )
  ft <- track_wkflow_formattable(track_df, round = 2)
  out <- as.data.frame(ft)
  expect_equal(out$prop_na_Genus[[1]], 0.12)
  expect_equal(out$prop_na_Genus[[2]], 0.99)
  expect_equal(out$mean_length_seq[[1]], 250.33)
  expect_equal(out$mean_length_seq[[2]], 260.67)
})

test_that("track_wkflow_formattable round = NULL disables rounding", {
  skip_if_not_installed("formattable")
  skip_if_not_installed("htmltools")
  track_df <- data.frame(
    nb_sequences = c(10000, 8000),
    nb_clusters = c(500, 400),
    nb_samples = c(10, 10),
    prop_na_Genus = c(0.123456, 0.987654),
    row.names = c("raw", "filt")
  )
  ft <- track_wkflow_formattable(track_df, round = NULL)
  out <- as.data.frame(ft)
  expect_equal(out$prop_na_Genus[[1]], 0.123456)
})

test_that("track_wkflow_formattable reorders prop_na after seq and genetic_diversity", {
  skip_if_not_installed("formattable")
  skip_if_not_installed("htmltools")
  track_df <- data.frame(
    nb_sequences = c(10000, 8000),
    nb_clusters = c(500, 400),
    nb_samples = c(10, 10),
    nb_occurrences = c(2000, 1500),
    nb_rank = c(7, 7),
    prop_na_Genus = c(0.1, 0.3),
    nb_sam_metadata = c(5, 5),
    mean_length_seq = c(250, 260),
    max_length_seq = c(300, 320),
    min_length_seq = c(200, 210),
    genetic_diversity_weighted = c(0.05, 0.06),
    genetic_diversity_unweighted = c(0.07, 0.08),
    row.names = c("raw", "filt")
  )
  ft <- track_wkflow_formattable(track_df)
  out <- as.data.frame(ft)
  col_order <- names(out)
  # prop_na must come after seq_* and genetic_diversity_*
  prop_na_pos <- which(col_order == "prop_na_Genus")
  seq_pos <- which(col_order == "mean_length_seq")
  div_pos <- which(col_order == "genetic_diversity_weighted")
  expect_gt(prop_na_pos, max(seq_pos))
  expect_gt(prop_na_pos, max(div_pos))
  # seq_* must come before genetic_diversity_*
  expect_lt(max(seq_pos), min(div_pos))
})
