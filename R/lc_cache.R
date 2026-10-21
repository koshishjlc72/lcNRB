lc_cache_dir <- function() {
  path <- getOption("lcNRB.cache_dir", tools::R_user_dir("lcNRB", "cache"))
  normalizePath(path, winslash = "/", mustWork = FALSE)
}

lc_cache_paths <- function() {
  root <- lc_cache_dir()
  list(
    root = root,
    raw = file.path(root, "raw"),
    processed = file.path(root, "processed"),
    manifest = file.path(root, "manifest.csv")
  )
}

lc_ensure_cache <- function() {
  paths <- lc_cache_paths()
  dir.create(paths$raw, recursive = TRUE, showWarnings = FALSE)
  dir.create(paths$processed, recursive = TRUE, showWarnings = FALSE)
  paths
}

lc_empty_manifest <- function() {
  tibble::tibble(
    dataset_id = character(), source_url = character(), retrieved_at = character(),
    sha256 = character(), parser_version = character(), parsing_status = character(),
    raw_path = character(), processed_path = character(), source_modified = character()
  )
}

lc_read_manifest <- function() {
  path <- lc_cache_paths()$manifest
  if (!file.exists(path)) return(lc_empty_manifest())
  out <- utils::read.csv(path, stringsAsFactors = FALSE, check.names = FALSE)
  for (nm in setdiff(names(lc_empty_manifest()), names(out))) out[[nm]] <- NA_character_
  tibble::as_tibble(out[, names(lc_empty_manifest()), drop = FALSE])
}

lc_write_manifest <- function(x) {
  paths <- lc_ensure_cache()
  tmp <- tempfile(tmpdir = paths$root, fileext = ".csv")
  utils::write.csv(x, tmp, row.names = FALSE, na = "")
  if (!file.rename(tmp, paths$manifest)) {
    file.copy(tmp, paths$manifest, overwrite = TRUE)
    unlink(tmp)
  }
  invisible(paths$manifest)
}

lc_latest_manifest <- function(dataset_id, require_processed = FALSE) {
  man <- lc_read_manifest()
  man <- man[man$dataset_id == dataset_id, , drop = FALSE]
  if (require_processed) {
    man <- man[man$parsing_status == "ok" & file.exists(man$processed_path), , drop = FALSE]
  } else {
    man <- man[file.exists(man$raw_path), , drop = FALSE]
  }
  if (!nrow(man)) return(NULL)
  man[order(man$retrieved_at, decreasing = TRUE), , drop = FALSE][1L, , drop = FALSE]
}

#' Inspect the lcNRB cache
#'
#' @return A tibble containing one row per cached source vintage.
#' @export
lc_cache_info <- function() {
  out <- lc_read_manifest()
  attr(out, "cache_dir") <- lc_cache_dir()
  out
}

#' Clear the lcNRB runtime cache
#'
#' Removes raw and processed source vintages from the user cache. Installed
#' package files are never touched.
#'
#' @return Invisibly, `TRUE`.
#' @export
lc_clear_cache <- function() {
  path <- lc_cache_dir()
  if (dir.exists(path)) unlink(path, recursive = TRUE, force = TRUE)
  invisible(TRUE)
}
