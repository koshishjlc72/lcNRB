mirror_record <- function(hash = paste(rep("a", 64L), collapse = ""),
                          current = TRUE,
                          path = paste0("data/cpi/", hash, ".xlsx")) {
  data.frame(
    dataset_id = "cpi",
    source_url = "https://www.nrb.org.np/contents/uploads/test/CPI.xlsx",
    retrieved_at = "2026-10-21 08:01:20 UTC",
    sha256 = hash,
    parser_version = "cpi-1.0.0",
    file_type = "xlsx",
    mirror_path = path,
    validated_at = "2026-10-30 01:17:00 UTC",
    current = current,
    rows = 18L,
    indicators = 6L,
    stringsAsFactors = FALSE
  )
}

test_that("mirror URLs and manifests enforce trust and provenance", {
  expect_invisible(lcNRB:::lc_assert_trusted_mirror_url(
    "https://raw.githubusercontent.com/koshishjlc72/lcNRB/data-cache/manifest.csv"
  ))
  expect_error(
    lcNRB:::lc_assert_trusted_mirror_url("https://example.com/manifest.csv"),
    "outside raw.githubusercontent.com"
  )
  expect_s3_class(lcNRB:::lc_validate_mirror_manifest(mirror_record()), "tbl_df")
  expect_error(
    lcNRB:::lc_validate_mirror_manifest(mirror_record(hash = "abc")),
    "invalid SHA-256"
  )
  expect_error(
    lcNRB:::lc_validate_mirror_manifest(mirror_record(path = "../CPI.xlsx")),
    "unsafe asset path"
  )
  bad_source <- mirror_record()
  bad_source$source_url <- "https://example.com/CPI.xlsx"
  expect_error(
    lcNRB:::lc_validate_mirror_manifest(bad_source),
    "outside trusted NRB domains"
  )
})

test_that("mirror selection requires the registered parser version", {
  manifest <- mirror_record()
  expect_equal(
    lcNRB:::lc_current_mirror_sources("cpi", manifest)$dataset_id,
    "cpi"
  )
  manifest$parser_version <- "cpi-0.0.0"
  expect_error(
    lcNRB:::lc_current_mirror_sources("cpi", manifest),
    "requires `cpi-1.0.0`"
  )
})

test_that("mirror files are hash checked before entering the cache", {
  old_cache <- getOption("lcNRB.cache_dir")
  cache <- tempfile("lcnrb-mirror-cache-")
  options(lcNRB.cache_dir = cache)
  on.exit({
    options(lcNRB.cache_dir = old_cache)
    unlink(cache, recursive = TRUE)
  }, add = TRUE)

  fixture <- testthat::test_path("fixtures", "cpi-layout.xlsx")
  hash <- digest::digest(file = fixture, algo = "sha256")
  row <- mirror_record(hash = hash)
  row$mirror_path <- paste0("data/cpi/", hash, ".xlsx")
  stored <- lcNRB:::lc_store_mirror_file("cpi", fixture, row)
  expect_true(file.exists(stored))
  cached <- lc_cache_info()
  expect_identical(cached$sha256, hash)
  expect_identical(cached$source_url, row$source_url)
  expect_match(cached$mirror_url, "raw.githubusercontent.com")

  parsed <- lcNRB:::lc_process_dataset("cpi", stored)
  expect_equal(nrow(parsed), 18L)
  expect_identical(unique(parsed$source_hash), hash)
  expect_identical(unique(parsed$source_url), row$source_url)

  wrong <- row
  wrong$sha256 <- paste(rep("0", 64L), collapse = "")
  expect_error(
    lcNRB:::lc_store_mirror_file("cpi", fixture, wrong),
    "Mirror hash mismatch"
  )
})
