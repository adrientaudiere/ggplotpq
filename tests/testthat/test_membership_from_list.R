skip_on_cran()

test_that("membership_from_list builds a correct binary data frame", {
  membership <- list(
    bact = c("s1", "s2", "s3"),
    fungi = c("s1", "s3"),
    amf = c("s2")
  )
  result <- ggplotpq:::membership_from_list(membership)

  expect_s3_class(result, "data.frame")
  expect_named(result, c("bact", "fungi", "amf"))
  expect_equal(nrow(result), 3L)
  expect_equal(rownames(result), c("s1", "s2", "s3"))
  expect_true(is.logical(result$bact))
  expect_equal(
    as.logical(result$bact),
    c(TRUE, TRUE, TRUE)
  )
  expect_equal(
    as.logical(result$fungi),
    c(TRUE, FALSE, TRUE)
  )
  expect_equal(
    as.logical(result$amf),
    c(FALSE, TRUE, FALSE)
  )
})

test_that("membership_from_list handles overlapping and disjoint sets", {
  result <- ggplotpq:::membership_from_list(
    list(a = c("x", "y"), b = c("y", "z"))
  )
  expect_equal(nrow(result), 3L)
  expect_equal(rownames(result), c("x", "y", "z"))
  expect_equal(as.logical(result$a), c(TRUE, TRUE, FALSE))
  expect_equal(as.logical(result$b), c(FALSE, TRUE, TRUE))
})

test_that("membership_from_list drops NA members", {
  result <- ggplotpq:::membership_from_list(
    list(a = c("x", NA), b = c("y", NA))
  )
  expect_equal(nrow(result), 2L)
  expect_equal(rownames(result), c("x", "y"))
})

test_that("membership_from_list can omit member row names", {
  result <- ggplotpq:::membership_from_list(
    list(a = c("x", "y"), b = c("y", "z")),
    keep_rownames = FALSE
  )
  expect_equal(nrow(result), 3L)
  expect_false(identical(rownames(result), c("x", "y", "z")))
})

test_that("membership_from_list preserves set column order", {
  result <- ggplotpq:::membership_from_list(
    list(zeta = "m", alpha = "m", mid = "m")
  )
  expect_named(result, c("zeta", "alpha", "mid"))
})

test_that("membership_from_list aborts for non-list input", {
  expect_error(
    ggplotpq:::membership_from_list(c("a", "b")),
    "must be a list"
  )
})

test_that("membership_from_list aborts for fewer than two sets", {
  expect_error(
    ggplotpq:::membership_from_list(list(a = c("x"))),
    "at least two sets"
  )
})

test_that("membership_from_list aborts for unnamed list", {
  expect_error(
    ggplotpq:::membership_from_list(list(c("x"), c("y"))),
    "fully named"
  )
})

test_that("membership_from_list aborts for partially unnamed list", {
  expect_error(
    ggplotpq:::membership_from_list(list(a = "x", c("y"))),
    "fully named"
  )
})

test_that("membership_from_list aborts when all members are NA", {
  expect_error(
    ggplotpq:::membership_from_list(list(a = NA, b = NA_character_)),
    "no non"
  )
})
