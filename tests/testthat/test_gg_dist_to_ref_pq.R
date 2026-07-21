test_that("plot_samples_dist2ref_pq works with a single ref_sample", {
  skip_if_not_installed("MiscMetabar")
  skip_if_not_installed("phyloseq")
  data(data_fungi_mini, package = "MiscMetabar")

  ref <- phyloseq::sample_names(data_fungi_mini)[1]
  res <- plot_samples_dist2ref_pq(data_fungi_mini, ref_sample = ref, fact = "Height")

  expect_type(res, "list")
  expect_named(
    res,
    c("dist_table", "rank_table", "kw", "ref_samples", "plots", "dist")
  )
  expect_named(
    res$plots,
    c("violin", "lollipop", "pcoa_global", "pcoa_local")
  )
  purrr::walk(res$plots, function(p) {
    expect_s3_class(p, "ggplot")
  })

  # distances match the phyloseq::distance matrix
  d <- as.matrix(phyloseq::distance(data_fungi_mini, method = "bray"))
  expect_equal(
    res$dist_table$dist_to_ref,
    unname(d[ref, phyloseq::sample_names(data_fungi_mini)])
  )
  # reference sample is flagged and at distance 0
  expect_equal(res$ref_samples, ref)
  expect_equal(
    res$dist_table$dist_to_ref[res$dist_table$sample_name %in% res$ref_samples],
    0
  )

  expect_s3_class(res$kw, "htest")
  expect_equal(res$kw$method, "Kruskal-Wallis rank sum test")
  expect_s3_class(res$dist, "dist")
})

test_that("plot_samples_dist2ref_pq ranks modalities from closest to farthest", {
  skip_if_not_installed("MiscMetabar")
  skip_if_not_installed("phyloseq")
  data(data_fungi_mini, package = "MiscMetabar")

  ref <- phyloseq::sample_names(data_fungi_mini)[1]
  res <- plot_samples_dist2ref_pq(data_fungi_mini, ref_sample = ref, fact = "Height")

  expect_true(all(diff(res$rank_table$dist_mean) >= 0))
  # rank_table is computed on non-reference samples only
  expect_equal(
    sum(res$rank_table$n),
    phyloseq::nsamples(data_fungi_mini) - 1
  )
  expect_named(
    res$rank_table,
    c("Height", "n", "dist_mean", "dist_sd", "dist_median")
  )
})

test_that("plot_samples_dist2ref_pq works without fact", {
  skip_if_not_installed("MiscMetabar")
  skip_if_not_installed("phyloseq")
  data(data_fungi_mini, package = "MiscMetabar")

  ref <- phyloseq::sample_names(data_fungi_mini)[1]
  res <- plot_samples_dist2ref_pq(data_fungi_mini, ref_sample = ref)

  expect_null(res$rank_table)
  expect_null(res$kw)
  purrr::walk(res$plots, function(p) {
    expect_s3_class(p, "ggplot")
  })
})

test_that("plot_samples_dist2ref_pq supports the ref_fact interface and ref_agg", {
  skip_if_not_installed("MiscMetabar")
  skip_if_not_installed("phyloseq")
  data(data_fungi_mini, package = "MiscMetabar")

  is_ref_flag <- phyloseq::get_variable(data_fungi_mini, "Time") == 0
  is_ref_flag[is.na(is_ref_flag)] <- FALSE
  phyloseq::sample_data(data_fungi_mini)$is_ref <- is_ref_flag
  n_refs <- sum(is_ref_flag)
  skip_if(n_refs < 2, "need at least 2 reference samples in data_fungi_mini")

  res_min <- plot_samples_dist2ref_pq(
    data_fungi_mini,
    ref_fact = "is_ref",
    ref_agg = "min",
    fact = "Height"
  )
  res_mean <- plot_samples_dist2ref_pq(
    data_fungi_mini,
    ref_fact = "is_ref",
    ref_agg = "mean",
    fact = "Height"
  )

  expect_equal(length(res_min$ref_samples), n_refs)
  is_ref_row <- res_min$dist_table$sample_name %in% res_min$ref_samples
  expect_true(all(res_min$dist_table$dist_to_ref[is_ref_row] == 0))

  # min aggregation gives distances <= mean aggregation
  focal <- !is_ref_row
  expect_true(all(
    res_min$dist_table$dist_to_ref[focal] <=
      res_mean$dist_table$dist_to_ref[focal] + .Machine$double.eps
  ))
})

test_that("plot_samples_dist2ref_pq validates its arguments", {
  skip_if_not_installed("MiscMetabar")
  skip_if_not_installed("phyloseq")
  data(data_fungi_mini, package = "MiscMetabar")

  ref <- phyloseq::sample_names(data_fungi_mini)[1]

  expect_error(
    plot_samples_dist2ref_pq(data_fungi_mini, fact = "Height"),
    "ref_sample"
  )
  expect_error(
    plot_samples_dist2ref_pq(
      data_fungi_mini,
      ref_sample = ref,
      ref_fact = "Height"
    ),
    "not both"
  )
  expect_error(
    plot_samples_dist2ref_pq(data_fungi_mini, ref_sample = "not_a_sample"),
    "not_a_sample"
  )
  expect_error(
    plot_samples_dist2ref_pq(data_fungi_mini, ref_fact = "not_a_column"),
    "not_a_column"
  )
  expect_error(
    plot_samples_dist2ref_pq(data_fungi_mini, ref_sample = ref, n_nearest = 2),
    ">= 3"
  )

  phyloseq::sample_data(data_fungi_mini)$is_ref <- FALSE
  expect_error(
    plot_samples_dist2ref_pq(data_fungi_mini, ref_fact = "is_ref"),
    "No reference sample"
  )
})

test_that("plot_samples_dist2ref_pq local ordination keeps only n_nearest samples", {
  skip_if_not_installed("MiscMetabar")
  skip_if_not_installed("phyloseq")
  data(data_fungi_mini, package = "MiscMetabar")

  ref <- phyloseq::sample_names(data_fungi_mini)[1]
  res <- plot_samples_dist2ref_pq(
    data_fungi_mini,
    ref_sample = ref,
    fact = "Height",
    n_nearest = 10
  )

  # 10 nearest non-reference samples + the single reference sample
  expect_equal(nrow(res$plots$pcoa_local$data), 11)
  expect_gt(nrow(res$plots$pcoa_global$data), 11)
})

test_that("plot_samples_dist2ref_pq supports robust.aitchison via vegan", {
  skip_if_not_installed("MiscMetabar")
  skip_if_not_installed("phyloseq")
  skip_if_not_installed("vegan")
  data(data_fungi_mini, package = "MiscMetabar")

  ref <- phyloseq::sample_names(data_fungi_mini)[1]
  res <- plot_samples_dist2ref_pq(
    data_fungi_mini,
    ref_sample = ref,
    fact = "Height",
    method = "robust.aitchison"
  )

  d <- as.matrix(vegan::vegdist(
    t(as(phyloseq::otu_table(data_fungi_mini), "matrix")),
    method = "robust.aitchison"
  ))
  expect_equal(
    res$dist_table$dist_to_ref,
    unname(d[ref, phyloseq::sample_names(data_fungi_mini)])
  )
})

test_that("plot_samples_dist2ref_pq plots render without error", {
  skip_if_not_installed("MiscMetabar")
  skip_if_not_installed("phyloseq")
  data(data_fungi_mini, package = "MiscMetabar")

  ref <- phyloseq::sample_names(data_fungi_mini)[1]
  res <- plot_samples_dist2ref_pq(data_fungi_mini, ref_sample = ref, fact = "Height")

  pdf(NULL)
  on.exit(dev.off())
  purrr::walk(res$plots, function(p) {
    expect_no_error(print(p))
  })
})
