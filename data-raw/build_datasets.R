# Refresh tracked data artifacts after the package has been installed.
library(lcNRB)

root <- normalizePath(".", winslash = "/", mustWork = TRUE)
cache <- file.path(root, "data-raw", "cache")
processed <- file.path(root, "data-raw", "processed")
manifest_path <- file.path(root, "data-raw", "source-manifest.csv")
report_path <- file.path(root, "data-raw", "change-report.md")
options(lcNRB.cache_dir = cache)
dir.create(processed, recursive = TRUE, showWarnings = FALSE)

old <- if (file.exists(manifest_path)) {
  read.csv(manifest_path, stringsAsFactors = FALSE)
} else {
  data.frame(dataset_id = character(), sha256 = character(), parser_version = character())
}

ids <- lc_catalog()$dataset_id
updates <- lc_update(ids, dry_run = FALSE)
cache_manifest <- lc_cache_info()
latest <- do.call(rbind, lapply(ids, function(id) {
  rows <- cache_manifest[cache_manifest$dataset_id == id & cache_manifest$parsing_status == "ok", ]
  rows[order(rows$retrieved_at, decreasing = TRUE)[1L], ]
}))
new <- data.frame(
  dataset_id = latest$dataset_id,
  sha256 = latest$sha256,
  parser_version = latest$parser_version,
  stringsAsFactors = FALSE
)
new <- new[order(new$dataset_id), ]
old <- old[order(old$dataset_id), ]
rownames(new) <- NULL
rownames(old) <- NULL

missing_artifact <- !file.exists(file.path(processed, paste0(new$dataset_id, ".rds")))
changed <- !identical(old, new) || any(missing_artifact)
if (!changed) {
  message("No source hash or tracked artifact changed.")
  quit(save = "no", status = 0L)
}

for (i in seq_len(nrow(latest))) {
  file.copy(
    latest$processed_path[[i]],
    file.path(processed, paste0(latest$dataset_id[[i]], ".rds")),
    overwrite = TRUE
  )
}
write.csv(new, manifest_path, row.names = FALSE, na = "")

lines <- c(
  "# lcNRB automated data change report",
  "",
  paste("Generated (UTC):", format(Sys.time(), tz = "UTC", usetz = TRUE)),
  "",
  "| Dataset | Status | New observations | Revised observations | SHA-256 |",
  "|---|---:|---:|---:|---|",
  vapply(seq_len(nrow(updates)), function(i) sprintf(
    "| `%s` | %s | %s | %s | `%s` |",
    updates$dataset_id[[i]], updates$status[[i]],
    updates$new_observations[[i]], updates$revised_observations[[i]],
    updates$sha256[[i]]
  ), character(1))
)
writeLines(lines, report_path, useBytes = TRUE)
