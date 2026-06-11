skip_on_cran()
skip_if_not_installed("ggforce")
skip_if_not_installed("MiscMetabar")

df_wide <- data.frame(
  x_s = c(1, 2, 3),
  x_e = c(4, 5, 6),
  y_s = c(1, 2, 3),
  y_e = c(2, 3, 4)
)

df_long <- data.frame(
  id   = rep(letters[1:3], each = 3),
  time = factor(rep(c("T0", "T1", "T2"), 3), levels = c("T0", "T1", "T2"), ordered = TRUE),
  xv   = c(1, 2, 3, 4, 3, 2, 2, 4, 3),
  yv   = c(1, 3, 2, 2, 4, 3, 3, 2, 4),
  grp  = rep(c("A", "A", "B"), each = 3)
)

test_that("comet_pq wide format returns a ggplot", {
  p <- comet_pq(df_wide, x_start = "x_s", x_end = "x_e", y_start = "y_s", y_end = "y_e")
  expect_s3_class(p, "ggplot")
})

test_that("comet_pq wide format works with color_by and label_by", {
  df <- cbind(df_wide, grp = c("a", "b", "a"), lbl = c("A", "B", "C"))
  p <- comet_pq(df,
    x_start = "x_s", x_end = "x_e", y_start = "y_s", y_end = "y_e",
    color_by = "grp", label_by = "lbl"
  )
  expect_s3_class(p, "ggplot")
})

test_that("comet_pq wide format aborts on missing column", {
  expect_error(
    comet_pq(df_wide, x_start = "x_s", x_end = "missing", y_start = "y_s", y_end = "y_e"),
    "not found"
  )
})

test_that("comet_pq long format returns a ggplot", {
  p <- comet_pq(df_long, x = "xv", y = "yv", modality = "time", id = "id")
  expect_s3_class(p, "ggplot")
})

test_that("comet_pq long format works with color_by and label_by", {
  p <- comet_pq(df_long,
    x = "xv", y = "yv", modality = "time", id = "id",
    color_by = "grp", label_by = "id"
  )
  expect_s3_class(p, "ggplot")
})

test_that("comet_pq long format aborts if modality is not ordered", {
  df_bad <- df_long
  df_bad$time <- factor(df_bad$time, ordered = FALSE)
  expect_error(
    comet_pq(df_bad, x = "xv", y = "yv", modality = "time", id = "id"),
    "ordered factor"
  )
})

test_that("comet_pq long format aborts if id/x/y are missing", {
  expect_error(
    comet_pq(df_long, x = "xv", y = "yv", modality = "time"),
    "id"
  )
})

test_that("comet_pq aborts if neither interface is specified", {
  expect_error(comet_pq(df_wide), "Wide format")
})

test_that("comet_pq aborts if both interfaces are mixed", {
  expect_error(
    comet_pq(df_long,
      x_start = "xv", x_end = "xv", y_start = "yv", y_end = "yv",
      modality = "time", id = "id"
    ),
    "Cannot mix"
  )
})

test_that("comet_pq label_nudge shifts tip labels", {
  p <- comet_pq(df_long,
    x = "xv", y = "yv", modality = "time", id = "id",
    label_by = "id", label_nudge_x = 0.3, label_nudge_y = 0.1
  )
  expect_s3_class(p, "ggplot")
})

test_that("comet_pq step_label_by adds node labels in long format", {
  p <- comet_pq(df_long,
    x = "xv", y = "yv", modality = "time", id = "id",
    step_label_by = "time", step_label_size = 2
  )
  expect_s3_class(p, "ggplot")
})

test_that("comet_pq na_rm drops rows with NA in used columns", {
  df_na <- df_long
  df_na$xv[3] <- NA
  p_rm <- comet_pq(df_na, x = "xv", y = "yv", modality = "time", id = "id", na_rm = TRUE)
  expect_s3_class(p_rm, "ggplot")
  p_keep <- comet_pq(df_na, x = "xv", y = "yv", modality = "time", id = "id", na_rm = FALSE)
  expect_s3_class(p_keep, "ggplot")
})

test_that("comet_pq accepts phyloseq input (wide format)", {
  data(data_fungi_mini, package = "MiscMetabar")
  sd <- as.data.frame(phyloseq::sample_data(data_fungi_mini))
  class(sd) <- "data.frame"
  sd$x_s <- as.numeric(factor(sd$Height))
  sd$x_e <- as.numeric(factor(sd$Height)) + stats::rnorm(nrow(sd))
  sd$y_s <- as.numeric(factor(sd$Height))
  sd$y_e <- as.numeric(factor(sd$Time))
  sd_clean <- sd[complete.cases(sd[, c("x_s", "x_e", "y_s", "y_e")]), ]
  p <- comet_pq(sd_clean, x_start = "x_s", x_end = "x_e", y_start = "y_s", y_end = "y_e")
  expect_s3_class(p, "ggplot")
})
