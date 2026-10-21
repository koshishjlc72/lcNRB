#' Validate standardized lcNRB observations
#'
#' Validation is strict about schema, types, duplicate observations, and
#' provenance. Large economic changes are not rejected automatically.
#'
#' @param data A standardized data frame returned by an lcNRB parser.
#' @param error If `TRUE`, stop on validation failure; otherwise return a
#'   diagnostic list.
#' @return Invisibly, the input data when valid; otherwise a diagnostic list
#'   when `error = FALSE`.
#' @export
lc_validate <- function(data, error = TRUE) {
  problems <- character()
  required <- lc_standard_columns()
  missing <- setdiff(required, names(data))
  if (length(missing)) problems <- c(problems, paste("Missing columns:", paste(missing, collapse = ", ")))
  if (!length(missing)) {
    if (!is.numeric(data$value)) problems <- c(problems, "`value` is not numeric")
    if (!inherits(data$date, "Date")) problems <- c(problems, "`date` is not a Date vector")
    empty_id <- is.na(data$indicator_id) | !nzchar(data$indicator_id)
    if (any(empty_id)) problems <- c(problems, "Missing indicator IDs")
    empty_period <- is.na(data$period) | !nzchar(data$period)
    if (any(empty_period)) problems <- c(problems, "Missing period labels")
    key <- paste(data$indicator_id, data$period, data$vintage, sep = "\r")
    if (anyDuplicated(key)) problems <- c(problems, "Duplicate indicator-period combinations within a vintage")
    if (any(is.na(data$source_hash) | !nzchar(data$source_hash))) problems <- c(problems, "Missing source hashes")
    if (any(is.na(data$source_url) | !nzchar(data$source_url))) problems <- c(problems, "Missing source URLs")
  }
  result <- list(valid = !length(problems), problems = unique(problems), rows = nrow(data))
  if (length(problems) && isTRUE(error)) lc_stop("Validation failed: %s", paste(unique(problems), collapse = "; "))
  if (length(problems)) return(result)
  invisible(data)
}
