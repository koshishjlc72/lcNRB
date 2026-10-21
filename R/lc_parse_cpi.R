#' Parse the verified annual CPI workbook
#'
#' The parser is intentionally specific to the `CPI_National` worksheet. It
#' stops when the expected title and two-row header are absent.
#'
#' @param path Path to an official NRB CPI workbook.
#' @param source_url Optional source URL override, useful for archived vintages.
#' @return A validated standardized tibble.
#' @export
lc_parse_cpi <- function(path, source_url = NULL) {
  sheet <- "CPI_National"
  raw <- lc_excel_sheet(path, sheet)
  if (nrow(raw) < 5L || ncol(raw) < 7L) lc_stop("CPI workbook is too small for the verified layout.")
  lc_expect_text(raw[[1L]][[1L]], "National Consumer Price Index", "CPI_National!A1")
  lc_expect_text(raw[[1L]][[3L]], "Fiscal Year", "CPI_National!A3")
  lc_expect_text(raw[[2L]][[4L]], "Overall", "CPI_National!B4")

  period_raw <- lc_clean_text(raw[[1L]])
  keep <- grepl("^\\d{4}/\\d{2}", period_raw)
  rows <- which(keep)
  if (!length(rows)) lc_stop("CPI parser found no fiscal-year observations.")
  base_label <- lc_clean_text(raw[[1L]][[2L]])
  specs <- tibble::tribble(
    ~column, ~indicator_id, ~indicator_name, ~unit,
    2L, "cpi_overall_index", "National CPI overall index", paste0("Index ", base_label),
    3L, "cpi_food_index", "National CPI food and beverages index", paste0("Index ", base_label),
    4L, "cpi_nonfood_index", "National CPI non-food and services index", paste0("Index ", base_label),
    5L, "inflation_overall_yoy", "National inflation rate", "percent",
    6L, "inflation_food_yoy", "Food inflation rate", "percent",
    7L, "inflation_nonfood_yoy", "Non-food and services inflation rate", "percent"
  )
  parts <- lapply(seq_len(nrow(specs)), function(i) {
    values <- lc_as_numeric(raw[[specs$column[[i]]]][rows])
    tibble::tibble(
      indicator_id = specs$indicator_id[[i]],
      indicator_name = specs$indicator_name[[i]],
      sector = "real",
      period = period_raw[rows],
      date = lc_empty_date(length(rows)),
      calendar = "Nepal fiscal year",
      frequency = "annual",
      value = values,
      unit = specs$unit[[i]]
    )
  })
  out <- dplyr::bind_rows(parts)
  out <- lc_add_provenance(
    out, "cpi", path, lc_source_url_for("cpi", source_url), sheet,
    parser_version = "cpi-1.0.0",
    notes = "Fiscal-year labels are preserved; no unvalidated BS-to-Gregorian date conversion is applied."
  )
  lc_validate(out)
  out
}
