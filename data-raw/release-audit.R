# Release-time data and provenance audit. This script deliberately lives in
# data-raw/ and is excluded from the CRAN source tarball.

pkgload::load_all(".", export_all = FALSE, helpers = FALSE, quiet = TRUE)

audit_dir <- file.path(".source-audit", "release-cache")
dir.create(audit_dir, recursive = TRUE, showWarnings = FALSE)
options(lcNRB.cache_dir = normalizePath(audit_dir, winslash = "/"))

ids <- lc_catalog()$dataset_id
updates <- lc_update(ids, dry_run = FALSE)

expected <- utils::read.csv(
  file.path("data-raw", "source-manifest.csv"),
  stringsAsFactors = FALSE
)
observed <- lc_cache_info()
expected_hash <- expected$sha256[match(observed$dataset_id, expected$dataset_id)]
stopifnot(!anyNA(expected_hash), identical(expected_hash, observed$sha256))
stopifnot(all(startsWith(observed$source_url, "https://www.nrb.org.np/")))

expected_shape <- data.frame(
  dataset_id = c("cpi", "gdp_quarterly", "monetary_survey", "balance_of_payments"),
  rows = c(324L, 2204L, 2656L, 18144L),
  indicators = c(6L, 38L, 8L, 63L)
)

audit_numeric <- function(x) {
  x <- trimws(as.character(x))
  x[x %in% c("", "-", "--", "...", "NA", "N/A", "n.a.")] <- NA_character_
  suppressWarnings(as.numeric(gsub(",", "", x, fixed = TRUE)))
}

assert_values <- function(actual, expected, label) {
  if (!isTRUE(all.equal(actual, expected, check.attributes = FALSE))) {
    stop("Raw-to-standardized value mismatch: ", label, call. = FALSE)
  }
}

fill_right <- function(x) {
  last <- NA_character_
  for (i in seq_along(x)) {
    if (!is.na(x[[i]]) && nzchar(x[[i]])) last <- x[[i]]
    x[[i]] <- last
  }
  x
}

parsed <- setNames(lapply(ids, lc_get), ids)
shape <- do.call(rbind, lapply(ids, function(id) {
  x <- parsed[[id]]
  lc_validate(x)
  stopifnot(length(unique(x$source_hash)) == 1L)
  stopifnot(unique(x$source_hash) == observed$sha256[observed$dataset_id == id])
  data.frame(
    dataset_id = id,
    rows = nrow(x),
    indicators = length(unique(x$indicator_id))
  )
}))
shape <- shape[match(expected_shape$dataset_id, shape$dataset_id), ]
stopifnot(identical(shape, expected_shape))

raw_path <- setNames(observed$raw_path, observed$dataset_id)

# CPI: independently compare all six parsed series with workbook columns B:G.
cpi_raw <- readxl::read_excel(
  raw_path[["cpi"]], sheet = "CPI_National", col_names = FALSE,
  .name_repair = "minimal"
)
cpi_rows <- grep("^\\d{4}/\\d{2}", as.character(cpi_raw[[1L]]))
cpi_map <- c(
  cpi_overall_index = 2L,
  cpi_food_index = 3L,
  cpi_nonfood_index = 4L,
  inflation_overall_yoy = 5L,
  inflation_food_yoy = 6L,
  inflation_nonfood_yoy = 7L
)
for (id in names(cpi_map)) {
  actual <- parsed$cpi$value[parsed$cpi$indicator_id == id]
  expected_values <- audit_numeric(cpi_raw[[cpi_map[[id]]]][cpi_rows])
  assert_values(actual, expected_values, paste("CPI", id))
}

# Monetary Survey: compare all eight parsed series with MA columns C:J.
money_raw <- readxl::read_excel(
  raw_path[["monetary_survey"]], sheet = "MA", col_names = FALSE,
  .name_repair = "minimal"
)
money_rows <- grep(
  "^Mid[- ]?(Jan|Feb|Mar|Apr|May|Jun|Jul|Aug|Sep|Oct|Nov|Dec)$",
  as.character(money_raw[[2L]]), ignore.case = TRUE
)
money_map <- c(
  money_m1 = 3L,
  money_m1_yoy = 4L,
  money_m2 = 5L,
  money_m2_yoy = 6L,
  private_sector_credit = 7L,
  private_sector_credit_yoy = 8L,
  bfi_deposits = 9L,
  bfi_deposits_yoy = 10L
)
for (id in names(money_map)) {
  actual <- parsed$monetary_survey$value[
    parsed$monetary_survey$indicator_id == id
  ]
  expected_values <- audit_numeric(money_raw[[money_map[[id]]]][money_rows])
  assert_values(actual, expected_values, paste("Monetary Survey", id))
}

# GDP: compare every value from both supported unadjusted tables.
gdp_values <- numeric()
for (sheet in c("label", "Growth_rate")) {
  raw <- readxl::read_excel(raw_path[["gdp_quarterly"]], sheet = sheet,
                            col_names = FALSE, .name_repair = "minimal")
  ad_year <- as.character(unlist(raw[3L, 3:ncol(raw)], use.names = FALSE))
  ad_year <- fill_right(ad_year)
  quarter <- trimws(as.character(unlist(raw[4L, 3:ncol(raw)], use.names = FALSE)))
  cols <- which(grepl("^\\d{4}/\\d{2}", ad_year) & grepl("^Q[1-4]$", quarter)) + 2L
  for (row in 5:23) {
    values <- audit_numeric(unlist(raw[row, cols], use.names = FALSE))
    if (!all(is.na(values))) gdp_values <- c(gdp_values, values)
  }
}
assert_values(parsed$gdp_quarterly$value, gdp_values, "Quarterly GDP")

# BOP: compare every numeric cell retained from the supported BPM5 table.
bop_raw <- readxl::read_excel(
  raw_path[["balance_of_payments"]], sheet = "BOP BPM5", col_names = FALSE,
  .name_repair = "minimal"
)
years <- as.character(unlist(bop_raw[3L, 6:ncol(bop_raw)], use.names = FALSE))
years <- fill_right(years)
months <- trimws(as.character(unlist(bop_raw[4L, 6:ncol(bop_raw)], use.names = FALSE)))
cols <- which(!is.na(years) & nzchar(years) & nzchar(months)) + 5L
bop_values <- numeric()
for (row in 5:nrow(bop_raw)) {
  labels <- trimws(as.character(unlist(bop_raw[row, 1:5], use.names = FALSE)))
  labels[is.na(labels)] <- ""
  if (!any(nzchar(labels))) next
  first <- labels[nzchar(labels)][[1L]]
  if (grepl("^(note|these data|the data)", first, ignore.case = TRUE)) next
  values <- audit_numeric(unlist(bop_raw[row, cols], use.names = FALSE))
  if (!all(is.na(values))) bop_values <- c(bop_values, values)
}
assert_values(parsed$balance_of_payments$value, bop_values, "Balance of Payments")

print(updates)
print(shape)
cat("Release data audit: PASS\n")
