#' List lcNRB datasets
#'
#' Returns the manually verified dataset registry. With `refresh = TRUE`, the
#' live NRB database pages are also inspected and unverified discoveries are
#' included with `availability = "discovered_unverified"`.
#'
#' @param sector Optional sector filter (`"real"`, `"financial"`,
#'   `"external"`, or `"fiscal"`).
#' @param frequency Optional case-insensitive frequency filter.
#' @param refresh If `TRUE`, run live source discovery.
#' @return A tibble with source, parser, support, and availability metadata.
#' @export
lc_catalog <- function(sector = NULL, frequency = NULL, refresh = FALSE) {
  out <- lc_dataset_registry()
  out$availability <- ifelse(out$supported, "supported", "registered_unverified")

  if (isTRUE(refresh)) {
    live <- lc_discover()
    current <- lc_match_discovered_sources(live, out$dataset_id[out$supported])
    out$source_url[match(current$dataset_id, out$dataset_id)] <- current$source_url
    known <- live$source_url %in% current$source_url
    extra <- live[!known, , drop = FALSE]
    if (nrow(extra)) {
      extra$supported <- FALSE
      extra$parser <- NA_character_
      extra$calendar <- NA_character_
      extra$unit <- NA_character_
      extra$last_verified <- NA_character_
      extra$notes <- "Automatically discovered; no verified parser"
      extra$availability <- "discovered_unverified"
      needed <- union(names(out), names(extra))
      for (nm in setdiff(needed, names(out))) out[[nm]] <- NA
      for (nm in setdiff(needed, names(extra))) extra[[nm]] <- NA
      out <- dplyr::bind_rows(out[, needed], extra[, needed])
    }
  }

  if (!is.null(sector)) {
    lc_assert_scalar_string(sector, "sector")
    out <- out[tolower(out$sector) == tolower(sector), , drop = FALSE]
  }
  if (!is.null(frequency)) {
    lc_assert_scalar_string(frequency, "frequency")
    out <- out[grepl(frequency, out$frequency, ignore.case = TRUE), , drop = FALSE]
  }
  tibble::as_tibble(out)
}
