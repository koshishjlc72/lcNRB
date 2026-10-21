test_that("catalog exposes only explicitly supported static datasets", {
  x <- lc_catalog()
  expect_s3_class(x, "tbl_df")
  expect_setequal(
    x$dataset_id,
    c("cpi", "gdp_quarterly", "monetary_survey", "balance_of_payments")
  )
  expect_true(all(x$supported))
  expect_true(all(x$availability == "supported"))
})

test_that("catalog filters sectors and frequencies", {
  expect_true(all(lc_catalog(sector = "external")$sector == "external"))
  expect_true(all(grepl("monthly", lc_catalog(frequency = "monthly")$frequency)))
})
