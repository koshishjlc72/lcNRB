test_that("annual CPI parser matches the audited workbook", {
  x <- lc_parse_cpi(audit_fixture("cpi-yearly.xlsx"))
  expect_equal(ncol(x), 19L)
  expect_setequal(unique(x$indicator_id), c(
    "cpi_overall_index", "cpi_food_index", "cpi_nonfood_index",
    "inflation_overall_yoy", "inflation_food_yoy", "inflation_nonfood_yoy"
  ))
  expect_true(all(is.na(x$date)))
  expect_true(all(grepl("^\\d{4}/\\d{2}", x$period)))
})

test_that("monetary parser assigns verified calendar mid-months", {
  x <- lc_parse_monetary(audit_fixture("monetary-survey.xlsx"))
  expect_setequal(unique(x$indicator_id), c(
    "money_m1", "money_m1_yoy", "money_m2", "money_m2_yoy",
    "private_sector_credit", "private_sector_credit_yoy",
    "bfi_deposits", "bfi_deposits_yoy"
  ))
  expect_equal(min(x$date), as.Date("1997-08-15"))
  expect_true(max(x$date) >= as.Date("2025-01-15"))
})

test_that("BOP parser reconstructs hierarchy and cumulative periods", {
  x <- lc_parse_bop(audit_fixture("bop.xlsx"))
  expect_true("bop_workers_remittances" %in% x$indicator_id)
  expect_true("bop_current_account" %in% x$indicator_id)
  expect_true(all(x$frequency == "monthly cumulative"))
  expect_true(all(is.na(x$date)))
})

test_that("GDP parser excludes ambiguous adjusted headers", {
  x <- lc_parse_gdp(audit_fixture("quarterly-gdp.xlsx"))
  expect_true("gdp_total_unadjusted_level" %in% x$indicator_id)
  expect_false(any(grepl("seasonally_adjusted", x$indicator_id)))
  expect_true(all(grepl("^\\d{4}/\\d{2}-Q[1-4]$", x$period)))
})

test_that("dataset-specific layout checks reject the wrong workbook", {
  expect_error(
    lc_parse_cpi(audit_fixture("bop.xlsx")),
    "expected sheet|layout"
  )
})
