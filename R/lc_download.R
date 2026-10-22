lc_validate_download <- function(path, expected_type) {
  if (!file.exists(path) || file.info(path)$size < 4L) {
    lc_stop("Downloaded file is empty or missing: %s", path)
  }
  bytes <- readBin(path, what = "raw", n = 8L)
  hex <- paste(sprintf("%02x", as.integer(bytes)), collapse = "")
  if (expected_type == "xlsx" && !startsWith(hex, "504b")) {
    lc_stop("Downloaded content is not an XLSX/ZIP file (signature %s).", hex)
  }
  if (expected_type == "xls" && !startsWith(hex, "d0cf11e0")) {
    lc_stop("Downloaded content is not a legacy XLS file (signature %s).", hex)
  }
  invisible(TRUE)
}

lc_download_from_url <- function(dataset_id, source_url, dest = NULL,
                                 overwrite = FALSE) {
  row <- lc_dataset_row(dataset_id)
  if (!isTRUE(row$supported[[1L]])) lc_stop("Dataset `%s` has no verified parser.", dataset_id)
  url <- source_url
  lc_assert_trusted_url(url)
  type <- row$file_type[[1L]]

  if (!is.null(dest)) {
    dest <- path.expand(dest)
    if (file.exists(dest) && !isTRUE(overwrite)) {
      lc_stop("Destination already exists; set `overwrite = TRUE`: %s", dest)
    }
    dir.create(dirname(dest), recursive = TRUE, showWarnings = FALSE)
    tmp <- tempfile(tmpdir = dirname(dest), fileext = paste0(".", type))
    on.exit(unlink(tmp), add = TRUE)
    lc_http_download(url, tmp)
    lc_validate_download(tmp, type)
    if (!file.rename(tmp, dest)) file.copy(tmp, dest, overwrite = TRUE)
    return(normalizePath(dest, winslash = "/", mustWork = TRUE))
  }

  paths <- lc_ensure_cache()
  tmp <- tempfile(tmpdir = paths$root, fileext = paste0(".", type))
  on.exit(unlink(tmp), add = TRUE)
  lc_http_download(url, tmp)
  lc_validate_download(tmp, type)
  hash <- digest::digest(file = tmp, algo = "sha256")
  raw_dir <- file.path(paths$raw, dataset_id, hash)
  dir.create(raw_dir, recursive = TRUE, showWarnings = FALSE)
  target <- file.path(raw_dir, paste0(dataset_id, ".", type))
  if (!file.exists(target)) file.copy(tmp, target)
  retrieved <- lc_now_utc()

  man <- lc_read_manifest()
  if (!any(man$dataset_id == dataset_id & man$sha256 == hash)) {
    man <- dplyr::bind_rows(man, tibble::tibble(
      dataset_id = dataset_id,
      source_url = url,
      retrieved_at = retrieved,
      sha256 = hash,
      parser_version = NA_character_,
      parsing_status = "downloaded",
      raw_path = normalizePath(target, winslash = "/", mustWork = TRUE),
      processed_path = NA_character_,
      source_modified = NA_character_
    ))
    lc_write_manifest(man)
  } else {
    hit <- man$dataset_id == dataset_id & man$sha256 == hash
    retrieved <- man$retrieved_at[hit][[1L]]
    man$source_url[hit] <- url
    man$raw_path[hit] <- normalizePath(target, winslash = "/", mustWork = TRUE)
    lc_write_manifest(man)
  }
  target <- normalizePath(target, winslash = "/", mustWork = TRUE)
  attr(target, "retrieved_at") <- retrieved
  attr(target, "source_url") <- url
  target
}

#' Download an original NRB source file
#'
#' Without `dest`, the file is stored as a content-addressed vintage in the
#' user cache. Existing cached content is reused unless `overwrite = TRUE`.
#' When a download is needed, the registered source title is resolved on the
#' official NRB database page so that newly dated workbook URLs are detected.
#'
#' @param dataset_id A supported dataset ID from [lc_catalog()].
#' @param dest Optional destination file path.
#' @param overwrite Whether to replace `dest` or re-check an existing cache.
#' @return The normalized local path, invisibly carrying retrieval metadata.
#' @export
lc_download <- function(dataset_id, dest = NULL, overwrite = FALSE) {
  lc_assert_scalar_string(dataset_id, "dataset_id")
  row <- lc_dataset_row(dataset_id)
  if (!isTRUE(row$supported[[1L]])) {
    lc_stop("Dataset `%s` has no verified parser.", dataset_id)
  }

  if (is.null(dest) && !isTRUE(overwrite)) {
    latest <- lc_latest_manifest(dataset_id)
    if (!is.null(latest)) {
      path <- normalizePath(latest$raw_path[[1L]], winslash = "/", mustWork = TRUE)
      attr(path, "retrieved_at") <- latest$retrieved_at[[1L]]
      attr(path, "source_url") <- latest$source_url[[1L]]
      return(path)
    }
  }

  current <- lc_discover_registered_sources(dataset_id)
  lc_download_from_url(
    dataset_id, current$source_url[[1L]], dest = dest, overwrite = overwrite
  )
}

#' Read an original workbook without standardizing it
#'
#' @param dataset_id A supported dataset ID.
#' @param sheet Optional sheet name or number. If omitted, a named list of all
#'   sheets is returned.
#' @return A tibble for one sheet or a named list of tibbles.
#' @export
lc_read_raw <- function(dataset_id, sheet = NULL) {
  path <- lc_download(dataset_id)
  sheets <- readxl::excel_sheets(path)
  if (is.null(sheet)) {
    out <- lapply(sheets, function(x) readxl::read_excel(path, sheet = x, col_names = FALSE))
    names(out) <- sheets
    return(out)
  }
  readxl::read_excel(path, sheet = sheet, col_names = FALSE)
}
