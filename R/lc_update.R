lc_remote_hash <- function(dataset_id) {
  row <- lc_dataset_row(dataset_id)
  tmp <- tempfile(fileext = paste0(".", row$file_type[[1L]]))
  on.exit(unlink(tmp), add = TRUE)
  lc_http_download(row$source_url[[1L]], tmp)
  lc_validate_download(tmp, row$file_type[[1L]])
  digest::digest(file = tmp, algo = "sha256")
}

lc_compare_vintages <- function(old, new) {
  if (is.null(old) || !nrow(old)) {
    return(list(new_observations = nrow(new), revised_observations = 0L))
  }
  keys <- c("indicator_id", "period")
  old_key <- paste(old$indicator_id, old$period, sep = "\r")
  new_key <- paste(new$indicator_id, new$period, sep = "\r")
  new_count <- sum(!new_key %in% old_key)
  common <- intersect(old_key, new_key)
  oi <- match(common, old_key)
  ni <- match(common, new_key)
  changed <- !(is.na(old$value[oi]) & is.na(new$value[ni])) &
    (is.na(old$value[oi]) != is.na(new$value[ni]) |
       (!is.na(old$value[oi]) & !is.na(new$value[ni]) & old$value[oi] != new$value[ni]))
  list(new_observations = new_count, revised_observations = sum(changed))
}

#' Check for and cache updated NRB source vintages
#'
#' @param dataset_ids Optional character vector of supported dataset IDs.
#' @param dry_run If `TRUE`, download to temporary files and report content
#'   changes without modifying the cache.
#' @return A tibble reporting source status and parsed changes.
#' @export
lc_update <- function(dataset_ids = NULL, dry_run = FALSE) {
  reg <- lc_dataset_registry()
  if (is.null(dataset_ids)) dataset_ids <- reg$dataset_id[reg$supported]
  if (!is.character(dataset_ids) || !length(dataset_ids) || anyNA(dataset_ids)) {
    lc_stop("`dataset_ids` must be a non-empty character vector.")
  }
  unknown <- setdiff(dataset_ids, reg$dataset_id[reg$supported])
  if (length(unknown)) lc_stop("Unknown or unsupported dataset IDs: %s", paste(unknown, collapse = ", "))

  results <- vector("list", length(dataset_ids))
  for (i in seq_along(dataset_ids)) {
    id <- dataset_ids[[i]]
    before_raw <- lc_latest_manifest(id)
    before_data <- lc_cached_dataset(id)
    old_hash <- if (is.null(before_raw)) NA_character_ else before_raw$sha256[[1L]]
    if (isTRUE(dry_run)) {
      new_hash <- lc_remote_hash(id)
      status <- if (is.na(old_hash)) "new" else if (identical(old_hash, new_hash)) "unchanged" else "changed"
      results[[i]] <- tibble::tibble(
        dataset_id = id, status = status, sha256 = new_hash,
        new_observations = NA_integer_, revised_observations = NA_integer_
      )
      next
    }
    path <- lc_download(id, overwrite = TRUE)
    new_hash <- digest::digest(file = path, algo = "sha256")
    before_parser <- if (is.null(before_raw)) NA_character_ else before_raw$parser_version[[1L]]
    parser_current <- identical(before_parser, lc_parser_version_for(id))
    if (!is.na(old_hash) && identical(old_hash, new_hash) && !is.null(before_data) && parser_current) {
      results[[i]] <- tibble::tibble(
        dataset_id = id, status = "unchanged", sha256 = new_hash,
        new_observations = 0L, revised_observations = 0L
      )
      next
    }
    parsed <- tryCatch(
      lc_process_dataset(id, path),
      error = function(e) {
        man <- lc_read_manifest()
        hit <- man$dataset_id == id & man$sha256 == new_hash
        man$parsing_status[hit] <- paste0("error: ", e$message)
        lc_write_manifest(man)
        stop(e)
      }
    )
    delta <- lc_compare_vintages(before_data, parsed)
    results[[i]] <- tibble::tibble(
      dataset_id = id,
      status = if (is.na(old_hash)) "new" else "updated",
      sha256 = new_hash,
      new_observations = delta$new_observations,
      revised_observations = delta$revised_observations
    )
  }
  dplyr::bind_rows(results)
}
