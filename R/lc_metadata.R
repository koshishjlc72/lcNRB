#' Retrieve dataset or indicator metadata
#'
#' @param indicator A dataset or indicator ID.
#' @return A list containing dataset and, where applicable, indicator metadata.
#' @export
lc_metadata <- function(indicator) {
  resolved <- lc_resolve_indicator(indicator)
  dataset <- lc_dataset_row(resolved$dataset_id)
  indicators <- lc_indicator_registry()
  if (is.null(resolved$indicator_id)) {
    indicators <- indicators[indicators$dataset_id == resolved$dataset_id, , drop = FALSE]
  } else {
    indicators <- indicators[indicators$indicator_id == resolved$indicator_id, , drop = FALSE]
  }
  list(dataset = tibble::as_tibble(dataset), indicators = tibble::as_tibble(indicators))
}
