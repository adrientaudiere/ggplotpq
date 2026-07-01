## ============================================================
## External Audit Script: ggplotpq
## Black-box audit: independent phyloseq fixtures, every export.
## Re-runnable; writes audits/ggplotpq_results.csv (cwd = PKG_ROOT).
## ============================================================

suppressPackageStartupMessages({
  library(ggplotpq)
  library(phyloseq)
  library(ggplot2)
  library(ape)
  library(Biostrings)
})

set.seed(42)

## ---- Fixtures (built from scratch, per AGENTS.md) ----
make_normal <- function() {
  otu <- matrix(
    sample(0:500, 20, replace = TRUE),
    nrow = 5,
    ncol = 4,
    dimnames = list(paste0("ASV", 1:5), paste0("S", 1:4))
  )
  tax <- matrix(
    c(
      "Bacteria",
      "Proteobacteria",
      "Gammaproteobacteria",
      "Enterobacterales",
      "Enterobacteriaceae",
      "Escherichia",
      "E_coli",
      "Bacteria",
      "Firmicutes",
      "Bacilli",
      "Lactobacillales",
      "Lactobacillaceae",
      "Lactobacillus",
      "L_acidophilus",
      "Bacteria",
      "Actinobacteriota",
      "Actinomycetia",
      "Bifidobacteriales",
      "Bifidobacteriaceae",
      "Bifidobacterium",
      "B_longum",
      "Bacteria",
      "Bacteroidota",
      "Bacteroidia",
      "Bacteroidales",
      "Bacteroidaceae",
      "Bacteroides",
      "B_fragilis",
      "Fungi",
      "Ascomycota",
      "Saccharomycetes",
      "Saccharomycetales",
      "Saccharomycetaceae",
      "Saccharomyces",
      "S_cerevisiae"
    ),
    nrow = 5,
    byrow = TRUE,
    dimnames = list(
      paste0("ASV", 1:5),
      c("Kingdom", "Phylum", "Class", "Order", "Family", "Genus", "Species")
    )
  )
  sam <- data.frame(
    Group = factor(c("A", "A", "B", "B")),
    Group3 = factor(c("A", "B", "C", "A")),
    Depth = c(100, 200, 150, 250),
    Site = c("Forest", "Forest", "Field", "Field"),
    row.names = paste0("S", 1:4)
  )
  tree <- rtree(5, tip.label = paste0("ASV", 1:5))
  seqs <- DNAStringSet(vapply(
    1:5,
    function(i) {
      paste(sample(c("A", "T", "G", "C"), 250, replace = TRUE), collapse = "")
    },
    character(1)
  ))
  names(seqs) <- paste0("ASV", 1:5)
  phyloseq(
    otu_table(otu, taxa_are_rows = TRUE),
    tax_table(tax),
    sample_data(sam),
    phy_tree(tree),
    seqs
  )
}

pq_normal <- make_normal()

# pq_mini: 2 taxa, 2 samples
pq_mini <- prune_taxa(
  taxa_names(pq_normal)[1:2],
  prune_samples(sample_names(pq_normal)[1:2], pq_normal)
)

# pq_na_tax: NAs in Genus/Species
pq_na_tax <- pq_normal
tt <- as.matrix(tax_table(pq_na_tax))
tt[1:2, c("Genus", "Species")] <- NA
tax_table(pq_na_tax) <- tax_table(tt)

# pq_empty_samples: zero-out one sample column
pq_empty_samples <- pq_normal
ot <- as.matrix(otu_table(pq_empty_samples))
ot[, 1] <- 0
otu_table(pq_empty_samples) <- otu_table(ot, taxa_are_rows = TRUE)

# pq_no_tree
pq_no_tree <- phyloseq(
  otu_table(pq_normal),
  tax_table(pq_normal),
  sample_data(pq_normal)
)

# pq_single_taxon / pq_single_sample
pq_single_taxon <- prune_taxa(taxa_names(pq_normal)[1], pq_normal)
pq_single_sample <- prune_samples(sample_names(pq_normal)[1], pq_normal)

## ---- Audit helper ----
audit_results <- data.frame(
  fn = character(),
  test = character(),
  status = character(),
  message = character(),
  stringsAsFactors = FALSE
)

audit_call <- function(fn_name, expr, test_label) {
  pdf(file = tempfile(fileext = ".pdf"))
  on.exit(dev.off(), add = TRUE)
  result <- tryCatch(
    withCallingHandlers(
      {
        val <- force(expr)
        # Force rendering of ggplot/grob/plotly objects where errors hide.
        if (inherits(val, "ggplot")) {
          print(val)
        } else if (inherits(val, "patchwork")) {
          print(val)
        }
        list(status = "OK", message = "")
      },
      warning = function(w) {
        invokeRestart("muffleWarning")
      }
    ),
    error = function(e) list(status = "ERROR", message = conditionMessage(e))
  )
  # Re-run once to capture the first warning (muffled above) without aborting.
  if (is.null(result$status) || result$status != "ERROR") {
    wmsg <- ""
    tryCatch(
      withCallingHandlers(
        {
          v <- force(expr)
          if (inherits(v, c("ggplot", "patchwork"))) print(v)
        },
        warning = function(w) {
          wmsg <<- conditionMessage(w)
          invokeRestart("muffleWarning")
        }
      ),
      error = function(e) NULL
    )
    result <- if (nzchar(wmsg)) {
      list(status = "WARNING", message = wmsg)
    } else {
      list(status = "OK", message = "")
    }
  }
  audit_results[nrow(audit_results) + 1, ] <<- list(
    fn_name,
    test_label,
    result$status,
    result$message
  )
  invisible(NULL)
}

## ---- Phyloseq-input plotting functions ----
audit_call("plot_sample_depth_pq", plot_sample_depth_pq(pq_normal), "happy")
audit_call(
  "plot_sample_depth_pq",
  plot_sample_depth_pq(pq_normal, geom = "density"),
  "density"
)
audit_call(
  "plot_sample_depth_pq",
  plot_sample_depth_pq(pq_empty_samples),
  "empty_samples"
)
audit_call(
  "plot_sample_depth_pq",
  plot_sample_depth_pq(pq_single_sample),
  "single_sample"
)

audit_call("plot_tax_count_pq", plot_tax_count_pq(pq_normal), "happy")
audit_call(
  "plot_tax_count_pq",
  plot_tax_count_pq(pq_normal, fact = "Group"),
  "fact"
)
audit_call("plot_tax_count_pq", plot_tax_count_pq(pq_na_tax), "na_tax")
audit_call(
  "plot_tax_count_pq",
  plot_tax_count_pq(pq_single_taxon),
  "single_taxon"
)

audit_call("plot_taxa_heatmap_pq", plot_taxa_heatmap_pq(pq_normal), "happy")
audit_call(
  "plot_taxa_heatmap_pq",
  plot_taxa_heatmap_pq(pq_normal, log10 = TRUE),
  "log10"
)
audit_call("plot_taxa_heatmap_pq", plot_taxa_heatmap_pq(pq_na_tax), "na_tax")
audit_call(
  "plot_taxa_heatmap_pq",
  plot_taxa_heatmap_pq(pq_single_taxon),
  "single_taxon"
)

audit_call("gg_bubbles_pq", gg_bubbles_pq(pq_normal), "happy")
audit_call("gg_bubbles_pq", gg_bubbles_pq(pq_na_tax), "na_tax")
audit_call("gg_bubbles_pq", gg_bubbles_pq(pq_empty_samples), "empty_samples")

audit_call(
  "community_sharing_plot",
  community_sharing_plot(pq_normal, fact = "Group"),
  "happy"
)
audit_call(
  "community_sharing_plot",
  community_sharing_plot(pq_na_tax, fact = "Group"),
  "na_tax"
)

audit_call(
  "community_sharing_barplot",
  community_sharing_barplot(pq_normal, fact = "Group"),
  "happy"
)
audit_call(
  "community_sharing_barplot",
  community_sharing_barplot(pq_single_sample, fact = "Group"),
  "single_sample"
)

audit_call("ternary_pq", ternary_pq(pq_normal, fact = "Group3"), "happy_3grp")
audit_call(
  "ternary_pq",
  ternary_pq(pq_normal, fact = "Group"),
  "two_group_edge"
)
audit_call("ternary_pq", ternary_pq(pq_na_tax, fact = "Group3"), "na_tax")

audit_call(
  "ternary_biomarker_pq",
  ternary_biomarker_pq(pq_normal, fact = "Group3"),
  "happy_3grp"
)
audit_call(
  "ternary_biomarker_pq",
  ternary_biomarker_pq(pq_normal, fact = "Group"),
  "two_group_edge"
)

audit_call(
  "krona_like_pq",
  krona_like_pq(pq_normal, interactive = FALSE),
  "static"
)
audit_call(
  "krona_like_pq",
  krona_like_pq(pq_normal, interactive = TRUE),
  "interactive"
)
audit_call(
  "krona_like_pq",
  krona_like_pq(pq_na_tax, interactive = FALSE),
  "na_tax"
)

audit_call(
  "neg_control_diag_pq",
  neg_control_diag_pq(pq_normal, neg_control = "S1"),
  "happy"
)
audit_call(
  "neg_control_diag_pq",
  neg_control_diag_pq(pq_normal, neg_control = c(TRUE, FALSE, FALSE, FALSE)),
  "logical_negctrl"
)

## ---- ggplot-spec functions (added to a plot) ----
base_p <- ggplot(
  data.frame(x = c(1, 2, 3, 100), y = c(1, 2, 3, 200)),
  aes(x, y)
) +
  geom_point()
audit_call("break_outlier_axis", base_p + break_outlier_axis(), "added_to_plot")
audit_call("break_outlier_axis", break_outlier_axis(), "bare_spec")
audit_call("zoom_outlier_axis", base_p + zoom_outlier_axis(), "added_to_plot")
audit_call("zoom_outlier_axis", zoom_outlier_axis(), "bare_spec")
audit_call(
  "reorder_distinct_colors",
  (base_p + aes(color = factor(x))) + reorder_distinct_colors(),
  "added_to_plot"
)

## ---- data.frame-input functions ----
comet_df <- data.frame(
  id = letters[1:4],
  x = 1:4,
  y = c(2, 4, 3, 5),
  modality = c("A", "A", "B", "B")
)
audit_call("comet_pq", comet_pq(comet_df, x = "x", y = "y", id = "id"), "happy")
audit_call(
  "comet_pq",
  comet_pq(comet_df[0, , drop = FALSE], x = "x", y = "y", id = "id"),
  "empty_df"
)

wheat_df <- data.frame(val = c(1, 1, 2, 3, 3, 3, 5))
audit_call("wheat_plot", wheat_plot(wheat_df, xvar = "val"), "happy")
audit_call(
  "wheat_plot",
  wheat_plot(wheat_df[0, , drop = FALSE], xvar = "val"),
  "empty_df"
)

track_df <- data.frame(
  nb_sequences = c(1000, 800, 600),
  nb_clusters = c(100, 80, 60),
  nb_samples = c(10, 10, 9),
  row.names = c("raw", "filtered", "final")
)
audit_call(
  "track_wkflow_formattable",
  track_wkflow_formattable(track_df),
  "happy"
)

## ---- palette / scale / theme functions ----
audit_call("idest_colors", idest_colors(n = 5), "n5")
audit_call("idest_colors", idest_colors(n = 0), "n0_edge")
audit_call(
  "idest_colors",
  idest_colors(n = 3, type = "continuous"),
  "continuous"
)
audit_call("idest_pal", idest_pal()(5), "pal_5")

audit_call("default_sharing_metrics", default_sharing_metrics(), "happy")
audit_call(
  "make_sharing_metric",
  make_sharing_metric(label = "test", color = "red", fn = function(a, b) {
    length(intersect(a, b))
  }),
  "happy"
)

audit_call("scale_color_idest_d", scale_color_idest_d(), "happy")
audit_call("scale_color_idest_c", scale_color_idest_c(), "happy")
audit_call("scale_fill_idest_d", scale_fill_idest_d(), "happy")
audit_call("scale_fill_idest_c", scale_fill_idest_c(), "happy")
audit_call("scale_color_pq_discrete", scale_color_pq_discrete(), "happy")
audit_call("scale_fill_pq_discrete", scale_fill_pq_discrete(), "happy")

audit_call("theme_idest", theme_idest(), "happy")
audit_call("theme_pq_minimal", theme_pq_minimal(), "happy")

## ---- Skipped (require network / external resources) ----
audit_results[nrow(audit_results) + 1, ] <- list(
  "palette_earthtones",
  "skipped",
  "SKIPPED",
  "downloads map tiles over the network (provider Esri.WorldImagery)"
)

## ---- Write results ----
dir.create("audits", showWarnings = FALSE)
write.csv(audit_results, "audits/ggplotpq_results.csv", row.names = FALSE)
cat("\nAudit complete:", nrow(audit_results), "tests run\n")
cat("OK:", sum(audit_results$status == "OK"), "\n")
cat("WARNING:", sum(audit_results$status == "WARNING"), "\n")
cat("ERROR:", sum(audit_results$status == "ERROR"), "\n")
cat("SKIPPED:", sum(audit_results$status == "SKIPPED"), "\n")
