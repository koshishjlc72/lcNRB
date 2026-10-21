#' Parse the verified Monetary Survey aggregate sheet
#'
#' Parses the `MA` worksheet containing M1, M2, private-sector credit, and BFI
#' deposits as levels and year-on-year growth rates. Other workbook sheets can
#' be inspected with [lc_read_raw()].
#'
#' @param path Path to an official NRB Monetary Survey workbook.
#' @param source_url Optional source URL override.
#' @return A validated standardized tibble.
#' @export
lc_parse_monetary <- function(path, source_url = NULL) {
  sheet <- "MA"
  raw <- lc_excel_sheet(path, sheet)
  if (nrow(raw) < 10L || ncol(raw) < 10L) lc_stop("Monetary Survey workbook is too small for the verified MA layout.")
  lc_expect_text(raw[[1L]][[1L]], "Monetary Aggreg", "MA!A1")
  expected <- c("M1", "M2", "Private Sector Credit", "Deposits of BFIs")
  header <- lc_clean_text(unlist(raw[2L, 1:10], use.names = FALSE))
  if (!all(expected %in% header)) {
    lc_stop("Unsupported MA header. Expected M1, M2, Private Sector Credit, and Deposits of BFIs.")
  }

  month <- lc_clean_text(raw[[2L]])
  keep <- grepl("^Mid[- ]?(Jan|Feb|Mar|Apr|May|Jun|Jul|Aug|Sep|Oct|Nov|Dec)$", month, ignore.case = TRUE)
  rows <- which(keep)
  if (!length(rows)) lc_stop("Monetary Survey parser found no Mid-Month observations.")
  explicit_year <- suppressWarnings(as.integer(raw[[1L]][rows]))
  first <- explicit_year[!is.na(explicit_year)][[1L]]
  current <- first - 1L
  years <- integer(length(rows))
  for (i in seq_along(rows)) {
    if (!is.na(explicit_year[[i]])) current <- explicit_year[[i]]
    years[[i]] <- current
  }
  dates <- lc_midmonth_date(years, month[rows])
  if (anyNA(dates)) lc_stop("Monetary Survey contained an unrecognized mid-month label.")
  periods <- format(dates, "%Y-%m-%d")
  specs <- tibble::tribble(
    ~column, ~indicator_id, ~indicator_name, ~unit,
    3L, "money_m1", "Narrow money M1", "NPR million",
    4L, "money_m1_yoy", "Narrow money M1 growth", "percent",
    5L, "money_m2", "Broad money M2", "NPR million",
    6L, "money_m2_yoy", "Broad money M2 growth", "percent",
    7L, "private_sector_credit", "Private sector credit", "NPR million",
    8L, "private_sector_credit_yoy", "Private sector credit growth", "percent",
    9L, "bfi_deposits", "BFI deposits", "NPR million",
    10L, "bfi_deposits_yoy", "BFI deposit growth", "percent"
  )
  parts <- lapply(seq_len(nrow(specs)), function(i) {
    tibble::tibble(
      indicator_id = specs$indicator_id[[i]],
      indicator_name = specs$indicator_name[[i]],
      sector = "financial",
      period = periods,
      date = dates,
      calendar = "Gregorian mid-month",
      frequency = "monthly",
      value = lc_as_numeric(raw[[specs$column[[i]]]][rows]),
      unit = specs$unit[[i]]
    )
  })
  out <- dplyr::bind_rows(parts)
  out <- lc_add_provenance(
    out, "monetary_survey", path,
    lc_source_url_for("monetary_survey", source_url), sheet,
    parser_version = "monetary-1.0.0",
    notes = "Source note: data from July 2021 are compiled on a residence basis under IMF MFS 2016 guidance."
  )
  lc_validate(out)
  out
}
