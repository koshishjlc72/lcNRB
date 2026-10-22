# Build compact workbook fixtures that exercise each verified parser layout.
# openxlsx is a maintainer-only dependency; generated XLSX files are committed.

fixture_dir <- file.path("tests", "testthat", "fixtures")
dir.create(fixture_dir, recursive = TRUE, showWarnings = FALSE)

write_fixture <- function(sheets, filename) {
  workbook <- openxlsx::createWorkbook()
  for (name in names(sheets)) {
    openxlsx::addWorksheet(workbook, name)
    openxlsx::writeData(
      workbook, name, sheets[[name]], colNames = FALSE, rowNames = FALSE,
      keepNA = FALSE
    )
  }
  openxlsx::saveWorkbook(
    workbook, file.path(fixture_dir, filename), overwrite = TRUE
  )
}

cpi <- matrix(NA, nrow = 7L, ncol = 7L)
cpi[1L, 1L] <- "National Consumer Price Index"
cpi[2L, 1L] <- "Base: 2023/24 = 100"
cpi[3L, 1L] <- "Fiscal Year"
cpi[4L, 2:7] <- c("Overall", "Food", "Non-food", "Overall", "Food", "Non-food")
cpi[5:7, 1L] <- c("2023/24", "2024/25", "2025/26 P")
cpi[5:7, 2:7] <- matrix(
  c(100, 100, 100, 5.4, 6.1, 4.8,
    104, 106, 102, 4.0, 6.0, 2.0,
    106, 109, 103, 1.9, 2.8, 1.0),
  nrow = 3L, byrow = TRUE
)
write_fixture(list(CPI_National = cpi), "cpi-layout.xlsx")

money <- matrix(NA, nrow = 10L, ncol = 10L)
money[1L, 1L] <- "Monetary Aggregates"
money[2L, c(3L, 5L, 7L, 9L)] <- c(
  "M1", "M2", "Private Sector Credit", "Deposits of BFIs"
)
money[3:10, 2L] <- c(
  "Mid-Aug", "Mid-Sep", "Mid-Oct", "Mid-Nov", "Mid-Dec", "Mid-Jan",
  "Mid-Jan", "Mid-Jul"
)
money[c(8L, 9L), 1L] <- c(1998, 2025)
for (row in 3:10) money[row, 3:10] <- seq_len(8L) * 100 + row
write_fixture(list(MA = money), "monetary-layout.xlsx")

bop <- matrix(NA, nrow = 10L, ncol = 17L)
bop[1L, 1L] <- "Balance of Payments BPM 5"
bop[2L, 1L] <- "million rupees"
bop[3L, 1L] <- "Particulars"
bop[3L, 6L] <- "2023/24"
bop[4L, 6:17] <- month.abb[c(8:12, 1:7)]
bop[5L, 1L] <- "A. Current Account"
bop[6L, 2L] <- "Goods: exports f.o.b."
bop[7L, 2L] <- "Workers' remittances"
bop[8L, 1L] <- "B. Capital Account"
bop[9L, 1L] <- "Reserve Assets"
for (row in 5:9) bop[row, 6:17] <- seq_len(12L) * row
bop[10L, 1L] <- "Note: compact parser fixture"
write_fixture(list(`BOP BPM5` = bop), "bop-layout.xlsx")

gdp_sheet <- function(growth = FALSE) {
  x <- matrix(NA, nrow = 23L, ncol = 6L)
  x[1L, 1L] <- "Seasonally Unadjusted Quarterly Gross Domestic Product"
  x[2L, 3L] <- "2080/81"
  x[3L, 3L] <- "2023/24"
  x[4L, 3:6] <- paste0("Q", 1:4)
  x[5L, 1L] <- "Total"
  x[5L, 2L] <- "Gross domestic product"
  x[5L, 3:6] <- if (growth) c(2.1, 2.5, 3.0, 3.4) else c(100, 103, 106, 110)
  x[23L, 1L] <- "fixture end"
  x
}
write_fixture(
  list(label = gdp_sheet(FALSE), Growth_rate = gdp_sheet(TRUE)),
  "gdp-layout.xlsx"
)
