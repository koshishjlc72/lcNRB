test_that("fiscal labels are parsed without inventing exact dates", {
  x <- lcNRB:::lc_parse_fiscal_year(c("2023/24 P", "1999/00", "bad"))
  expect_equal(x$start_year, c(2023L, 1999L, NA_integer_))
  expect_equal(x$end_year, c(2024L, 2000L, NA_integer_))
  expect_equal(x$period[1:2], c("2023/24", "1999/00"))
})

test_that("mid-month dates are deterministic", {
  expect_equal(
    lcNRB:::lc_midmonth_date(c(2025L, 2026L), c("Mid-Dec", "Mid-Jan")),
    as.Date(c("2025-12-15", "2026-01-15"))
  )
})
