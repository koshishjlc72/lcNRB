#' Search supported economic indicators
#'
#' @param query Search text. Matching is case-insensitive and covers IDs,
#'   names, descriptions, and synonyms.
#' @param sector Optional sector filter.
#' @param frequency Optional frequency filter.
#' @return A tibble of matching indicators.
#' @export
lc_search <- function(query, sector = NULL, frequency = NULL) {
  lc_assert_scalar_string(query, "query")
  out <- lc_indicator_registry()
  haystack <- paste(
    out$indicator_id, out$indicator_name, out$description, out$synonyms
  )
  keep <- grepl(tolower(query), tolower(haystack), fixed = TRUE)
  out <- out[keep, , drop = FALSE]
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
