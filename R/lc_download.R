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

lc_store_raw_download <- function(dataset_id, path, source_url,
                                  retrieved_at = lc_now_utc(),
                                  expected_hash = NULL,
                                  mirror_url = NA_character_,
                                  mirror_validated_at = NA_character_) {
  row <- lc_dataset_row(dataset_id)
  lc_validate_download(path, row$file_type[[1L]])
  hash <- digest::digest(file = path, algo = "sha256")
  if (!is.null(expected_hash) && !identical(tolower(hash), tolower(expected_hash))) {
    lc_stop(
      "Mirror hash mismatch for `%s`: expected %s but downloaded %s.",
      dataset_id, expected_hash, hash
    )
  }

  paths <- lc_ensure_cache()
  raw_dir <- file.path(paths$raw, dataset_id, hash)
  dir.create(raw_dir, recursive = TRUE, showWarnings = FALSE)
  target <- file.path(raw_dir, paste0(dataset_id, ".", row$file_type[[1L]]))
  if (!file.exists(target) && !file.copy(path, target)) {
    lc_stop("Failed to store the downloaded `%s` workbook.", dataset_id)
  }
  target <- normalizePath(target, winslash = "/", mustWork = TRUE)

  man <- lc_read_manifest()
  hit <- man$dataset_id == dataset_id & man$sha256 == hash
  if (!any(hit)) {
    man <- dplyr::bind_rows(man, tibble::tibble(
      dataset_id = dataset_id,
      source_url = source_url,
      retrieved_at = retrieved_at,
      sha256 = hash,
      parser_version = NA_character_,
      parsing_status = "downloaded",
      raw_path = target,
      processed_path = NA_character_,
      source_modified = NA_character_,
      mirror_url = mirror_url,
      mirror_validated_at = mirror_validated_at
    ))
  } else {
    man$source_url[hit] <- source_url
    man$retrieved_at[hit] <- retrieved_at
    man$raw_path[hit] <- target
    man$mirror_url[hit] <- mirror_url
    man$mirror_validated_at[hit] <- mirror_validated_at
  }
  lc_write_manifest(man)

  attr(target, "retrieved_at") <- retrieved_at
  attr(target, "source_url") <- source_url
  attr(target, "mirror_url") <- mirror_url
  target
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
  hash <- digest::digest(file = tmp, algo = "sha256")
  old <- lc_read_manifest()
  hit <- old$dataset_id == dataset_id & old$sha256 == hash
  retrieved <- if (any(hit)) old$retrieved_at[hit][[1L]] else lc_now_utc()
  lc_store_raw_download(
    dataset_id, tmp, source_url = url, retrieved_at = retrieved
  )
}

#' Download an original NRB source file
#'
#' Without `dest`, the file is stored as a content-addressed vintage in the
#' user cache. Existing cached content is reused unless `overwrite = TRUE`.
#' By default, downloads use the package's validated GitHub mirror. Set
#' `source = "nrb"` to resolve and download directly from the official NRB
#' database page. Both routes preserve the original NRB URL and content hash.
#'
#' @param dataset_id A supported dataset ID from [lc_catalog()].
#' @param dest Optional destination file path.
#' @param overwrite Whether to replace `dest` or re-check an existing cache.
#' @param source Download route: `"mirror"` (the default) or `"nrb"`.
#' @return The normalized local path, invisibly carrying retrieval metadata.
#' @export
lc_download <- function(dataset_id, dest = NULL, overwrite = FALSE,
                        source = getOption("lcNRB.source", "mirror")) {
  lc_assert_scalar_string(dataset_id, "dataset_id")
  source <- lc_source_mode(source)
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

  if (identical(source, "mirror")) {
    return(lc_download_from_mirror(
      dataset_id, dest = dest, overwrite = overwrite
    ))
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
