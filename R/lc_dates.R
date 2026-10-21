lc_parse_fiscal_year <- function(x) {
  x <- lc_clean_text(x)
  m <- stringr::str_match(x, "(\\d{4})/(\\d{2})")
  start <- suppressWarnings(as.integer(m[, 2L]))
  end2 <- suppressWarnings(as.integer(m[, 3L]))
  century <- (start %/% 100L) * 100L
  end <- century + end2
  rollover <- !is.na(end) & !is.na(start) & end < start
  end[rollover] <- end[rollover] + 100L
  tibble::tibble(period = ifelse(is.na(start), NA_character_, paste0(start, "/", sprintf("%02d", end %% 100L))), start_year = start, end_year = end)
}

lc_midmonth_date <- function(year, label) {
  month_names <- c(
    jan = 1L, feb = 2L, mar = 3L, apr = 4L, may = 5L, jun = 6L,
    jul = 7L, aug = 8L, sep = 9L, oct = 10L, nov = 11L, dec = 12L
  )
  key <- tolower(substr(gsub("^mid[- ]?", "", trimws(label), ignore.case = TRUE), 1L, 3L))
  month <- unname(month_names[key])
  out <- rep(as.Date(NA_character_), length(year))
  ok <- !is.na(year) & !is.na(month)
  out[ok] <- as.Date(sprintf("%04d-%02d-15", as.integer(year[ok]), month[ok]))
  out
}
