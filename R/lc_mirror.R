lc_default_mirror_url <- function() {
  "https://raw.githubusercontent.com/koshishjlc72/lcNRB/data-cache"
}

lc_assert_trusted_mirror_url <- function(url) {
  lc_assert_scalar_string(url, "url")
  if (!grepl("^https://", url, ignore.case = TRUE)) {
    lc_stop("Only HTTPS mirror downloads are allowed: %s", url)
  }
  host <- sub("^https://([^/:]+).*$", "\\1", tolower(url))
  if (!identical(host, "raw.githubusercontent.com")) {
    lc_stop("Refusing a mirror download outside raw.githubusercontent.com: %s", host)
  }
  invisible(TRUE)
}

lc_mirror_base_url <- function() {
  url <- getOption("lcNRB.mirror_url", lc_default_mirror_url())
  lc_assert_trusted_mirror_url(url)
  sub("/+$", "", url)
}

lc_source_mode <- function(source = getOption("lcNRB.source", "mirror")) {
  lc_assert_scalar_string(source, "source")
  match.arg(tolower(source), c("mirror", "nrb"))
}

lc_http_mirror_download <- function(url, dest, attempts = 3L) {
  lc_http_fetch(url, dest, lc_assert_trusted_mirror_url, attempts = attempts)
}

lc_validate_mirror_manifest <- function(x) {
  required <- c(
    "dataset_id", "source_url", "retrieved_at", "sha256",
    "parser_version", "file_type", "mirror_path", "validated_at", "current",
    "rows", "indicators"
  )
  missing <- setdiff(required, names(x))
  if (length(missing)) {
    lc_stop("Mirror manifest is missing columns: %s", paste(missing, collapse = ", "))
  }
  x <- x[, required, drop = FALSE]
  current_value <- tolower(trimws(as.character(x$current)))
  if (anyNA(current_value) || any(!current_value %in% c("true", "false", "1", "0"))) {
    lc_stop("Mirror manifest contains an invalid current-vintage flag.")
  }
  x$current <- current_value %in% c("true", "1")
  text_columns <- setdiff(required, c("current", "rows", "indicators"))
  if (any(vapply(x[text_columns], function(z) anyNA(z) || any(!nzchar(z)), logical(1)))) {
    lc_stop("Mirror manifest contains missing required values.")
  }
  if (any(!grepl("^[0-9a-f]{64}$", tolower(x$sha256)))) {
    lc_stop("Mirror manifest contains an invalid SHA-256 value.")
  }
  x$rows <- suppressWarnings(as.integer(x$rows))
  x$indicators <- suppressWarnings(as.integer(x$indicators))
  if (anyNA(x$rows) || anyNA(x$indicators) || any(x$rows < 1L) || any(x$indicators < 1L)) {
    lc_stop("Mirror manifest contains invalid row or indicator counts.")
  }
  safe_path <- grepl("^[A-Za-z0-9_./-]+$", x$mirror_path) &
    !grepl("(^|/)\\.\\.(/|$)", x$mirror_path) &
    !startsWith(x$mirror_path, "/") &
    !grepl("\\\\", x$mirror_path)
  if (any(!safe_path)) lc_stop("Mirror manifest contains an unsafe asset path.")
  for (url in unique(x$source_url)) lc_assert_trusted_url(url)
  current_counts <- table(x$dataset_id[x$current])
  if (length(current_counts) && any(current_counts != 1L)) {
    lc_stop("Mirror manifest must contain exactly one current vintage per dataset.")
  }
  tibble::as_tibble(x)
}

lc_read_mirror_manifest <- function() {
  base <- lc_mirror_base_url()
  url <- paste0(base, "/manifest.csv")
  tmp <- tempfile(fileext = ".csv")
  on.exit(unlink(tmp), add = TRUE)
  lc_http_mirror_download(url, tmp)
  out <- utils::read.csv(tmp, stringsAsFactors = FALSE, check.names = FALSE)
  lc_validate_mirror_manifest(out)
}

lc_current_mirror_sources <- function(dataset_ids, manifest = NULL) {
  if (is.null(manifest)) manifest <- lc_read_mirror_manifest()
  manifest <- lc_validate_mirror_manifest(manifest)
  reg <- lc_dataset_registry()
  result <- lapply(dataset_ids, function(id) {
    row <- manifest[manifest$dataset_id == id & manifest$current, , drop = FALSE]
    if (nrow(row) != 1L) {
      lc_stop("Expected exactly one current mirror vintage for `%s`; found %d.", id, nrow(row))
    }
    registered <- reg[reg$dataset_id == id & reg$supported, , drop = FALSE]
    if (nrow(registered) != 1L) lc_stop("Dataset `%s` has no verified parser.", id)
    if (!identical(row$file_type[[1L]], registered$file_type[[1L]])) {
      lc_stop("Mirror file type does not match the registry for `%s`.", id)
    }
    expected_parser <- lc_parser_version_for(id)
    if (!identical(row$parser_version[[1L]], expected_parser)) {
      lc_stop(
        "Mirror parser version for `%s` is `%s`; this package requires `%s`.",
        id, row$parser_version[[1L]], expected_parser
      )
    }
    row
  })
  dplyr::bind_rows(result)
}

lc_mirror_asset_url <- function(row) {
  url <- paste0(lc_mirror_base_url(), "/", row$mirror_path[[1L]])
  lc_assert_trusted_mirror_url(url)
  url
}

lc_store_mirror_file <- function(dataset_id, path, row) {
  lc_store_raw_download(
    dataset_id = dataset_id,
    path = path,
    source_url = row$source_url[[1L]],
    retrieved_at = row$retrieved_at[[1L]],
    expected_hash = row$sha256[[1L]],
    mirror_url = lc_mirror_asset_url(row),
    mirror_validated_at = row$validated_at[[1L]]
  )
}

lc_download_from_mirror <- function(dataset_id, dest = NULL, overwrite = FALSE,
                                    manifest = NULL) {
  row <- lc_current_mirror_sources(dataset_id, manifest = manifest)
  url <- lc_mirror_asset_url(row)
  type <- row$file_type[[1L]]

  target_dir <- if (is.null(dest)) lc_ensure_cache()$root else dirname(path.expand(dest))
  dir.create(target_dir, recursive = TRUE, showWarnings = FALSE)
  tmp <- tempfile(tmpdir = target_dir, fileext = paste0(".", type))
  on.exit(unlink(tmp), add = TRUE)
  lc_http_mirror_download(url, tmp)
  lc_validate_download(tmp, type)
  observed_hash <- digest::digest(file = tmp, algo = "sha256")
  if (!identical(tolower(observed_hash), tolower(row$sha256[[1L]]))) {
    lc_stop(
      "Mirror hash mismatch for `%s`: expected %s but downloaded %s.",
      dataset_id, row$sha256[[1L]], observed_hash
    )
  }

  if (!is.null(dest)) {
    dest <- path.expand(dest)
    if (file.exists(dest) && !isTRUE(overwrite)) {
      lc_stop("Destination already exists; set `overwrite = TRUE`: %s", dest)
    }
    if (!file.rename(tmp, dest) && !file.copy(tmp, dest, overwrite = TRUE)) {
      lc_stop("Failed to write the mirror workbook to `%s`.", dest)
    }
    out <- normalizePath(dest, winslash = "/", mustWork = TRUE)
    attr(out, "retrieved_at") <- row$retrieved_at[[1L]]
    attr(out, "source_url") <- row$source_url[[1L]]
    attr(out, "mirror_url") <- url
    return(out)
  }

  lc_store_mirror_file(dataset_id, tmp, row)
}
