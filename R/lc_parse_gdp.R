lc_parse_gdp_block <- function(raw, sheet, header_row, rows, suffix, label, unit) {
  ad_year <- lc_fill_right(unlist(raw[header_row + 1L, 3:ncol(raw)], use.names = FALSE))
  bs_year <- lc_fill_right(unlist(raw[header_row, 3:ncol(raw)], use.names = FALSE))
  quarter <- lc_clean_text(unlist(raw[header_row + 2L, 3:ncol(raw)], use.names = FALSE))
  keep_col <- grepl("^\\d{4}/\\d{2}", ad_year) & grepl("^Q[1-4]$", quarter)
  cols <- which(keep_col) + 2L
  ad_year <- ad_year[keep_col]
  bs_year <- bs_year[keep_col]
  quarter <- quarter[keep_col]
  records <- vector("list", 0L)
  for (r in rows) {
    name <- lc_clean_text(raw[[2L]][[r]])
    code <- lc_clean_text(raw[[1L]][[r]])
    vals <- lc_as_numeric(unlist(raw[r, cols], use.names = FALSE))
    if (!nzchar(name) || all(is.na(vals))) next
    stem <- if (nzchar(code)) lc_slugify(code) else lc_slugify(name)
    records[[length(records) + 1L]] <- tibble::tibble(
      indicator_id = paste0("gdp_", stem, "_", suffix),
      indicator_name = paste(name, label),
      sector = "real",
      period = paste0(ad_year, "-", quarter),
      date = lc_empty_date(length(cols)),
      calendar = "Gregorian fiscal year (BS label retained in notes)",
      frequency = "quarterly",
      value = vals,
      unit = unit,
      source_note = paste0("BS fiscal year ", bs_year)
    )
  }
  lc_bind_rows_safe(records)
}

#' Parse the verified quarterly GDP workbook
#'
#' Extracts seasonally unadjusted levels and year-on-year growth by economic
#' activity from the first tables in the `label` and `Growth_rate` worksheets.
#' The adjusted table is deliberately excluded because its latest published
#' growth header repeats a fiscal-year label and is therefore ambiguous.
#'
#' @param path Path to the official NRB quarterly GDP workbook.
#' @param source_url Optional source URL override.
#' @return A validated standardized tibble.
#' @export
lc_parse_gdp <- function(path, source_url = NULL) {
  level <- lc_excel_sheet(path, "label")
  growth <- lc_excel_sheet(path, "Growth_rate")
  if (nrow(level) < 23L || nrow(growth) < 23L || ncol(level) < 6L) {
    lc_stop("Quarterly GDP workbook is too small for the verified unadjusted-table layout.")
  }
  lc_expect_text(level[[1L]][[1L]], "Seasonally Unadjusted.*Quart", "label!A1")
  lc_expect_text(growth[[1L]][[1L]], "Seasonally Unadjusted.*Quart", "Growth_rate!A1")
  parts <- list(
    lc_parse_gdp_block(level, "label", 2L, 5:23, "unadjusted_level", "unadjusted GDP", "NPR million"),
    lc_parse_gdp_block(growth, "Growth_rate", 2L, 5:23, "unadjusted_growth_yoy", "unadjusted GDP growth (year-on-year)", "percent")
  )
  out <- dplyr::bind_rows(parts)
  note <- out$source_note
  out$source_note <- NULL
  out <- lc_add_provenance(
    out, "gdp_quarterly", path,
    lc_source_url_for("gdp_quarterly", source_url), "label; Growth_rate",
    parser_version = "gdp-quarterly-1.0.0",
    notes = note
  )
  lc_validate(out)
  out
}
