#' Convert a named list of members into a binary membership data frame
#'
#' @description
#'
#' <a href="https://adrientaudiere.github.io/MiscMetabar/articles/Rules.html#lifecycle">
#' <img src="https://img.shields.io/badge/lifecycle-experimental-orange" alt="lifecycle-experimental"></a>
#'
#' Internal helper that turns a named list of character (or other) vectors
#' — each vector listing the members belonging to one set — into a
#' wide-format data frame with one row per unique member and one logical
#' column per set. This is the format expected by
#' [ComplexUpset::upset()] and similar venn/upset plotting tools, which
#' cannot consume a list directly.
#'
#' Conceptually equivalent to [UpSetR::fromList()] but kept inside the
#' package to avoid a hard dependency on \pkg{UpSetR} and to return
#' logical columns (which both \pkg{ComplexUpset} and \pkg{ggplot2}
#' handle natively).
#'
#' @param x (named list, required) Each element is a vector of members
#'   belonging to one set. The list names become the column names of the
#'   returned data frame. At least two sets are required.
#' @param keep_rownames (logical, default `TRUE`) If `TRUE`, the unique
#'   members are stored as the row names of the returned data frame.
#'
#' @return A [data.frame] with one column per set (named after the list
#'   elements) and one row per unique non-`NA` member across all sets.
#'   Cell values are `TRUE`/`FALSE`. When `keep_rownames = TRUE` the row
#'   names identify the members.
#'
#' @keywords internal
#' @author Adrien Taudière
#'
#' @examples
#' \dontrun{
#' membership <- list(
#'   bact  = c("s1", "s2", "s3"),
#'   fungi = c("s1", "s3"),
#'   amf   = c("s2")
#' )
#' ggplotpq:::membership_from_list(membership)
#' #        bact fungi   amf
#' # s1    TRUE  TRUE FALSE
#' # s2    TRUE FALSE  TRUE
#' # s3    TRUE  TRUE FALSE
#' }
membership_from_list <- function(x, keep_rownames = TRUE) {
  if (!is.list(x)) {
    cli::cli_abort(
      "{.arg x} must be a list, not {.obj_type_friendly {x}}."
    )
  }
  if (length(x) < 2) {
    cli::cli_abort("{.arg x} must contain at least two sets.")
  }
  if (is.null(names(x)) || any(names(x) == "")) {
    cli::cli_abort("{.arg x} must be a fully named list.")
  }

  all_members <- unique(unlist(x, use.names = FALSE))
  all_members <- all_members[!is.na(all_members)]

  if (length(all_members) == 0) {
    cli::cli_abort(
      "{.arg x} contains no non-{.code NA} members across all sets."
    )
  }

  result <- data.frame(
    lapply(x, function(set) all_members %in% set),
    check.names = FALSE
  )

  if (keep_rownames) {
    rownames(result) <- all_members
  }

  result
}
