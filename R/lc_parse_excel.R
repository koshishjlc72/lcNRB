lc_excel_sheet <- function(path, sheet, range = NULL) {
  if (!file.exists(path)) lc_stop("Workbook does not exist: %s", path)
  sheets <- readxl::excel_sheets(path)
  if (!sheet %in% sheets) {
    lc_stop(
      "Workbook layout changed: expected sheet `%s`; found %s.",
      sheet, paste(sheets, collapse = ", ")
    )
  }
  readxl::read_excel(
    path, sheet = sheet, range = range, col_names = FALSE,
    .name_repair = "minimal"
  )
}

lc_expect_text <- function(value, pattern, where) {
  value <- lc_clean_text(value)
  if (!length(value) || !grepl(pattern, value[[1L]], ignore.case = TRUE)) {
    lc_stop(
      "Unsupported workbook layout at %s: expected text matching `%s`, found `%s`.",
      where, pattern, lc_first_nonempty(value)
    )
  }
  invisible(TRUE)
}

lc_fill_right <- function(x) {
  out <- as.character(x)
  last <- NA_character_
  for (i in seq_along(out)) {
    if (!is.na(out[[i]]) && nzchar(trimws(out[[i]]))) last <- out[[i]]
    out[[i]] <- last
  }
  out
}

lc_source_url_for <- function(dataset_id, source_url = NULL) {
  if (!is.null(source_url)) return(source_url)
  lc_dataset_row(dataset_id)$source_url[[1L]]
}
