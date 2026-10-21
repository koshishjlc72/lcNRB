test_that("cache manifest round-trips in an isolated directory", {
  old <- getOption("lcNRB.cache_dir")
  path <- tempfile("lcnrb-cache-")
  options(lcNRB.cache_dir = path)
  on.exit({ options(lcNRB.cache_dir = old); unlink(path, recursive = TRUE) }, add = TRUE)
  expect_equal(nrow(lc_cache_info()), 0L)
  man <- lcNRB:::lc_empty_manifest()
  man <- dplyr::bind_rows(man, tibble::tibble(
    dataset_id = "cpi", source_url = "https://www.nrb.org.np/test.xlsx",
    retrieved_at = "2026-10-20 UTC", sha256 = "abc", parser_version = "test",
    parsing_status = "ok", raw_path = "missing", processed_path = "missing",
    source_modified = NA_character_
  ))
  lcNRB:::lc_write_manifest(man)
  expect_equal(lc_cache_info()$sha256, "abc")
  expect_true(lc_clear_cache())
  expect_false(dir.exists(path))
})
