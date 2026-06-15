skip_on_cran()
skip_if_not_installed("MiscMetabar")

data(data_fungi_mini, package = "MiscMetabar")

test_that(".ternary_biomarker_df builds the expected 3-group data frame", {
  built <- ggplotpq:::.ternary_biomarker_df(data_fungi_mini, fact = "Height")
  expect_length(built$lvls, 3)
  expect_setequal(built$lvls, c("High", "Low", "Middle"))
  expect_true(all(built$lvls %in% colnames(built$plot_df)))
  expect_true(all(
    c("taxon", "sum_abund", "enriched") %in% colnames(built$plot_df)
  ))
  expect_s3_class(built$plot_df$enriched, "factor")
  # relative (raw = FALSE): each group column sums to 1
  col_sums <- colSums(built$plot_df[, built$lvls])
  expect_equal(unname(col_sums), c(1, 1, 1), tolerance = 1e-8)
})

test_that(".ternary_biomarker_df honours raw = TRUE (counts not normalised)", {
  built <- ggplotpq:::.ternary_biomarker_df(
    data_fungi_mini,
    fact = "Height",
    raw = TRUE
  )
  expect_true(all(colSums(built$plot_df[, built$lvls]) > 1))
})

test_that(".ternary_biomarker_df restricts to biomarker_taxa", {
  some <- phyloseq::taxa_names(data_fungi_mini)[1:3]
  built <- ggplotpq:::.ternary_biomarker_df(
    data_fungi_mini,
    fact = "Height",
    biomarker_taxa = some
  )
  expect_true(all(built$plot_df$taxon %in% some))
})

test_that(".ternary_biomarker_df aborts when fact has != 3 levels", {
  expect_error(
    ggplotpq:::.ternary_biomarker_df(data_fungi_mini, fact = "Diameter"),
    "exactly 3 levels"
  )
})

test_that(".ternary_biomarker_df aborts on unknown biomarker taxa", {
  expect_error(
    ggplotpq:::.ternary_biomarker_df(
      data_fungi_mini,
      fact = "Height",
      biomarker_taxa = c("not_a_taxon")
    ),
    "None of"
  )
})

test_that("ternary_biomarker_pq aborts without ggtern", {
  skip_if(requireNamespace("ggtern", quietly = TRUE))
  expect_error(
    ternary_biomarker_pq(data_fungi_mini, fact = "Height"),
    "ggtern"
  )
})

test_that("ternary_biomarker_pq returns a ggtern/ggplot when ggtern is present", {
  skip_if_not_installed("ggtern")
  p <- ternary_biomarker_pq(data_fungi_mini, fact = "Height")
  expect_s3_class(p, "ggplot")
})
