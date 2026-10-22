lc_store_processed <- function(dataset_id, path, data) {
  paths <- lc_ensure_cache()
  hash <- digest::digest(file = path, algo = "sha256")
  dir <- file.path(paths$processed, dataset_id)
  dir.create(dir, recursive = TRUE, showWarnings = FALSE)
  target <- file.path(dir, paste0(hash, ".rds"))
  saveRDS(data, target, version = 3)
  target <- normalizePath(target, winslash = "/", mustWork = TRUE)
  man <- lc_read_manifest()
  hit <- man$dataset_id == dataset_id & man$sha256 == hash
  if (!any(hit)) {
    row <- lc_dataset_row(dataset_id)
    man <- dplyr::bind_rows(man, tibble::tibble(
      dataset_id = dataset_id,
      source_url = row$source_url[[1L]],
      retrieved_at = lc_now_utc(),
      sha256 = hash,
      parser_version = unique(data$parser_version)[[1L]],
      parsing_status = "ok",
      raw_path = normalizePath(path, winslash = "/", mustWork = TRUE),
      processed_path = target,
      source_modified = NA_character_
    ))
  } else {
    man$parser_version[hit] <- unique(data$parser_version)[[1L]]
    man$parsing_status[hit] <- "ok"
    man$processed_path[hit] <- target
  }
  lc_write_manifest(man)
  target
}

lc_process_dataset <- function(dataset_id, path) {
  row <- lc_dataset_row(dataset_id)
  parser <- lc_parser_for(row$parser[[1L]])
  source_url <- attr(path, "source_url", exact = TRUE)
  if (is.null(source_url) || is.na(source_url) || !nzchar(source_url)) {
    source_url <- row$source_url[[1L]]
  }
  out <- parser(path, source_url = source_url)
  lc_validate(out)
  lc_store_processed(dataset_id, path, out)
  out
}

lc_cached_dataset <- function(dataset_id) {
  latest <- lc_latest_manifest(dataset_id, require_processed = TRUE)
  if (is.null(latest)) return(NULL)
  if (!identical(latest$parser_version[[1L]], lc_parser_version_for(dataset_id))) {
    raw <- lc_latest_manifest(dataset_id, require_processed = FALSE)
    if (is.null(raw)) return(NULL)
    path <- raw$raw_path[[1L]]
    attr(path, "retrieved_at") <- raw$retrieved_at[[1L]]
    attr(path, "source_url") <- raw$source_url[[1L]]
    return(lc_process_dataset(dataset_id, path))
  }
  readRDS(latest$processed_path[[1L]])
}

lc_parse_date_arg <- function(x, name) {
  if (is.null(x)) return(NULL)
  if (inherits(x, "Date") && length(x) == 1L && !is.na(x)) return(x)
  lc_assert_scalar_string(x, name)
  out <- as.Date(x)
  if (is.na(out)) lc_stop("`%s` must use ISO date format YYYY-MM-DD.", name)
  out
}

#' Retrieve standardized macroeconomic observations
#'
#' `indicator` may be a dataset ID (returning every parsed indicator in that
#' dataset) or an indicator ID from [lc_search()]. The first use downloads and
#' caches the official workbook; later uses work from that local vintage.
#'
#' @param indicator Dataset or indicator ID.
#' @param start,end Optional ISO dates or `Date` values. Date filtering is only
#'   available for series with validated Gregorian dates.
#' @param frequency Optional exact frequency filter.
#' @param refresh If `TRUE`, check the official workbook for a new vintage.
#' @return A standardized long-form tibble.
#' @export
lc_get <- function(indicator, start = NULL, end = NULL, frequency = NULL,
                   refresh = FALSE) {
  resolved <- lc_resolve_indicator(indicator)
  if (isTRUE(refresh)) lc_update(resolved$dataset_id, dry_run = FALSE)
  data <- lc_cached_dataset(resolved$dataset_id)
  if (is.null(data)) {
    path <- lc_download(resolved$dataset_id)
    data <- lc_process_dataset(resolved$dataset_id, path)
  }
  if (!is.null(resolved$indicator_id)) {
    data <- data[data$indicator_id == resolved$indicator_id, , drop = FALSE]
  }
  if (!is.null(frequency)) {
    lc_assert_scalar_string(frequency, "frequency")
    data <- data[tolower(data$frequency) == tolower(frequency), , drop = FALSE]
  }
  start <- lc_parse_date_arg(start, "start")
  end <- lc_parse_date_arg(end, "end")
  if (!is.null(start) || !is.null(end)) {
    if (!nrow(data) || all(is.na(data$date))) {
      lc_stop(
        "Date filtering is unavailable for `%s`: its source periods cannot be converted to exact Gregorian dates without an unverified assumption. Filter `period` explicitly instead.",
        indicator
      )
    }
    if (anyNA(data$date)) {
      lc_stop("Date filtering is unsafe because some observations have no standardized date.")
    }
    keep <- rep(TRUE, nrow(data))
    if (!is.null(start)) keep <- keep & data$date >= start
    if (!is.null(end)) keep <- keep & data$date <= end
    data <- data[keep, , drop = FALSE]
  }
  tibble::as_tibble(data)
}
