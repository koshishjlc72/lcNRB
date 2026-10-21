# Internal utilities ------------------------------------------------------

lc_stop <- function(..., call. = FALSE) {
  stop(sprintf(...), call. = call.)
}

lc_now_utc <- function() {
  format(Sys.time(), tz = "UTC", usetz = TRUE)
}

lc_slugify <- function(x) {
  x <- stringr::str_to_lower(x)
  x <- stringr::str_replace_all(x, "[^a-z0-9]+", "_")
  stringr::str_remove_all(x, "^_+|_+$")
}

lc_clean_text <- function(x) {
  x <- as.character(x)
  x[is.na(x)] <- ""
  stringr::str_squish(x)
}

lc_as_numeric <- function(x) {
  x <- trimws(as.character(x))
  x[x %in% c("", "-", "--", "...", "NA", "N/A", "n.a.")] <- NA_character_
  suppressWarnings(as.numeric(gsub(",", "", x, fixed = TRUE)))
}

lc_empty_date <- function(n) {
  as.Date(rep(NA_character_, n))
}

lc_assert_scalar_string <- function(x, name, allow_null = FALSE) {
  if (allow_null && is.null(x)) return(invisible(TRUE))
  if (!is.character(x) || length(x) != 1L || is.na(x) || !nzchar(x)) {
    lc_stop("`%s` must be one non-empty character value.", name)
  }
  invisible(TRUE)
}

lc_first_nonempty <- function(x) {
  x <- lc_clean_text(x)
  x <- x[nzchar(x)]
  if (length(x)) x[[1L]] else NA_character_
}

lc_bind_rows_safe <- function(xs) {
  xs <- Filter(function(x) !is.null(x) && nrow(x), xs)
  if (!length(xs)) return(tibble::tibble())
  dplyr::bind_rows(xs)
}

lc_standard_columns <- function() {
  c(
    "indicator_id", "indicator_name", "sector", "period", "date",
    "calendar", "frequency", "value", "unit", "source_url",
    "source_file", "retrieved_at", "vintage", "dataset_id",
    "sheet_name", "source_hash", "parser_version", "revision_status",
    "notes"
  )
}

lc_add_provenance <- function(data, dataset_id, path, source_url, sheet_name,
                              parser_version, notes = NA_character_) {
  info <- file.info(path)
  hash <- digest::digest(file = path, algo = "sha256")
  retrieved <- attr(path, "retrieved_at", exact = TRUE)
  if (is.null(retrieved) || is.na(retrieved)) {
    retrieved <- format(info$mtime, tz = "UTC", usetz = TRUE)
  }
  data$source_url <- source_url
  data$source_file <- basename(path)
  data$retrieved_at <- retrieved
  data$vintage <- substr(hash, 1L, 12L)
  data$dataset_id <- dataset_id
  data$sheet_name <- sheet_name
  data$source_hash <- hash
  data$parser_version <- parser_version
  data$revision_status <- "as_published"
  data$notes <- notes
  missing <- setdiff(lc_standard_columns(), names(data))
  for (nm in missing) data[[nm]] <- NA_character_
  data <- data[, lc_standard_columns(), drop = FALSE]
  tibble::as_tibble(data)
}

lc_package_file <- function(...) {
  path <- system.file(..., package = "lcNRB")
  if (!nzchar(path)) {
    candidate <- file.path(getwd(), ...)
    if (file.exists(candidate)) path <- candidate
  }
  if (!nzchar(path) || !file.exists(path)) {
    lc_stop("Package file not found: %s", file.path(...))
  }
  path
}
