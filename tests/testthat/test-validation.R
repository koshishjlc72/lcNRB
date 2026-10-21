test_that("validation rejects duplicate observations", {
  x <- tibble::tibble(
    indicator_id = rep("x", 2), indicator_name = rep("X", 2),
    sector = rep("real", 2), period = rep("2025", 2),
    date = as.Date(c(NA, NA)), calendar = rep("fiscal", 2),
    frequency = rep("annual", 2), value = c(1, 2), unit = rep("index", 2),
    source_url = rep("https://www.nrb.org.np/x.xlsx", 2),
    source_file = rep("x.xlsx", 2), retrieved_at = rep("now", 2),
    vintage = rep("v", 2), dataset_id = rep("x", 2), sheet_name = rep("s", 2),
    source_hash = rep("hash", 2), parser_version = rep("1", 2),
    revision_status = rep("as_published", 2), notes = rep(NA_character_, 2)
  )
  expect_error(lc_validate(x), "Duplicate")
  expect_false(lc_validate(x, error = FALSE)$valid)
})

test_that("vintage comparison distinguishes additions and revisions", {
  old <- tibble::tibble(indicator_id = c("x", "x"), period = c("1", "2"), value = c(1, 2))
  new <- tibble::tibble(indicator_id = c("x", "x", "x"), period = c("1", "2", "3"), value = c(1, 9, 3))
  out <- lcNRB:::lc_compare_vintages(old, new)
  expect_equal(out$new_observations, 1L)
  expect_equal(out$revised_observations, 1L)
})
