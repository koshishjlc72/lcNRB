lc_bop_known_id <- function(path, leaf) {
  text <- tolower(paste(path, collapse = " > "))
  known <- c(
    "^a\\. current account$" = "bop_current_account",
    "goods: exports f\\.o\\.b\\.$" = "bop_goods_exports_fob",
    "goods: imports f\\.o\\.b\\.$" = "bop_goods_imports_fob",
    "balance on goods$" = "bop_balance_on_goods",
    "services: net$" = "bop_services_net",
    "workers' remittances$" = "bop_workers_remittances",
    "reserve assets$" = "bop_reserve_assets"
  )
  for (pattern in names(known)) if (grepl(pattern, text)) return(unname(known[[pattern]]))
  paste0("bop_", lc_slugify(paste(path, collapse = "_")))
}

#' Parse the verified Balance of Payments BPM5 workbook
#'
#' The source observations are cumulative within each Nepalese fiscal year.
#' Month labels are retained exactly and standardized dates are intentionally
#' left unavailable because the workbook states that labels follow Nepali
#' calendar periods.
#'
#' @param path Path to the official NRB BPM5 workbook.
#' @param source_url Optional source URL override.
#' @return A validated standardized tibble.
#' @export
lc_parse_bop <- function(path, source_url = NULL) {
  sheet <- "BOP BPM5"
  raw <- lc_excel_sheet(path, sheet)
  if (nrow(raw) < 10L || ncol(raw) < 10L) lc_stop("BOP workbook is too small for the verified layout.")
  lc_expect_text(raw[[1L]][[1L]], "Balance of Payment.*BPM 5", "BOP BPM5!A1")
  lc_expect_text(raw[[1L]][[2L]], "million rupees", "BOP BPM5!A2")
  lc_expect_text(raw[[1L]][[3L]], "Particul", "BOP BPM5!A3")

  years <- lc_fill_right(unlist(raw[3L, 6:ncol(raw)], use.names = FALSE))
  months <- lc_clean_text(unlist(raw[4L, 6:ncol(raw)], use.names = FALSE))
  keep_col <- !is.na(years) & nzchar(years) & nzchar(months)
  cols <- which(keep_col) + 5L
  years <- years[keep_col]
  months <- months[keep_col]
  if (!length(cols)) lc_stop("BOP parser found no fiscal-year/month columns.")

  state <- rep(NA_character_, 5L)
  records <- vector("list", 0L)
  for (r in 5:nrow(raw)) {
    labels <- lc_clean_text(unlist(raw[r, 1:5], use.names = FALSE))
    if (!any(nzchar(labels))) next
    if (grepl("^(note|these data|the data)", labels[nzchar(labels)][[1L]], ignore.case = TRUE)) next
    for (depth in which(nzchar(labels))) {
      state[[depth]] <- labels[[depth]]
      if (depth < 5L) state[(depth + 1L):5L] <- NA_character_
    }
    path_parts <- state[!is.na(state) & nzchar(state)]
    leaf <- labels[nzchar(labels)][[length(labels[nzchar(labels)])]]
    vals <- lc_as_numeric(unlist(raw[r, cols], use.names = FALSE))
    if (all(is.na(vals))) next
    id <- lc_bop_known_id(path_parts, leaf)
    records[[length(records) + 1L]] <- tibble::tibble(
      indicator_id = id,
      indicator_name = leaf,
      sector = "external",
      period = paste0(years, "-", months),
      date = lc_empty_date(length(cols)),
      calendar = "Nepal fiscal year",
      frequency = "monthly cumulative",
      value = vals,
      unit = "NPR million"
    )
  }
  out <- lc_bind_rows_safe(records)
  if (!nrow(out)) lc_stop("BOP parser produced no observations.")
  out <- lc_add_provenance(
    out, "balance_of_payments", path,
    lc_source_url_for("balance_of_payments", source_url), sheet,
    parser_version = "bop-bpm5-1.0.0",
    notes = "Cumulative within fiscal year. Month labels follow the Nepali-calendar convention documented in the source workbook; Gregorian date is unavailable."
  )
  lc_validate(out)
  out
}
