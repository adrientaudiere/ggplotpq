#' @keywords internal
"_PACKAGE"

## usethis namespace: start
#' @importFrom cli cli_abort cli_warn
#' @importFrom dplyr arrange group_by mutate rename select ungroup
#' @importFrom ggplot2 aes element_blank element_text geom_col geom_density
#' @importFrom ggplot2 geom_point geom_tile geom_violin ggplot ggplot_build
#' @importFrom ggplot2 guides labs position_jitter scale_color_manual
#' @importFrom ggplot2 scale_fill_manual theme theme_minimal
#' @importFrom lifecycle deprecated
#' @importFrom methods is
#' @importFrom MiscMetabar verify_pq
#' @importFrom phyloseq nsamples ntaxa otu_table phy_tree prune_samples prune_taxa
#' @importFrom phyloseq sample_data sample_names sample_sums tax_table
#' @importFrom phyloseq taxa_are_rows taxa_names taxa_sums
#' @importFrom rlang .data :=
#' @importFrom stats na.omit setNames
#' @importFrom tibble as_tibble
## usethis namespace: end
NULL

# Columns referred to by name inside data-masked expressions (ggplot2 aes,
# dplyr verbs). They exist only at evaluation time, so R CMD check cannot
# see them bound anywhere.
utils::globalVariables(c(
  "Abundance",
  "Taxon",
  "abundance",
  "id",
  "label_var",
  "rank_value_color",
  "rank_value_contour",
  "sample_id",
  "size_var",
  "sz",
  "taxon_group",
  "total"
))
