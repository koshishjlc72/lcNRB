test_that("search covers synonyms case-insensitively", {
  expect_true("inflation_overall_yoy" %in% lc_search("INFLATION")$indicator_id)
  expect_true("money_m2" %in% lc_search("broad money")$indicator_id)
  expect_true("bop_workers_remittances" %in% lc_search("remittance inflows")$indicator_id)
})

test_that("unknown identifiers fail with guidance", {
  expect_error(lc_metadata("not_a_real_indicator"), "lc_search")
})
