test_that("trusted domain policy rejects non-NRB URLs", {
  expect_invisible(lcNRB:::lc_assert_trusted_url("https://www.nrb.org.np/file.xlsx"))
  expect_error(lcNRB:::lc_assert_trusted_url("http://www.nrb.org.np/file.xlsx"), "HTTPS")
  expect_error(lcNRB:::lc_assert_trusted_url("https://nrb.org.np.example.com/file.xlsx"), "trusted")
})

test_that("download signatures are validated independently of extensions", {
  good <- tempfile(fileext = ".xlsx")
  bad <- tempfile(fileext = ".xlsx")
  on.exit(unlink(c(good, bad)), add = TRUE)
  writeBin(as.raw(c(0x50, 0x4b, 0x03, 0x04)), good)
  writeBin(charToRaw("<html>error</html>"), bad)
  expect_invisible(lcNRB:::lc_validate_download(good, "xlsx"))
  expect_error(lcNRB:::lc_validate_download(bad, "xlsx"), "not an XLSX")
})

test_that("discovery parses frequency, resolves URLs, and deduplicates", {
  fixture <- testthat::test_path("fixtures", "discovery-page.html")
  doc <- xml2::read_html(fixture)
  x <- lcNRB:::lc_parse_discovery_document(
    doc, "real", "https://www.nrb.org.np/database-on-nepalese-economy/real-sector/"
  )
  expect_equal(nrow(x), 2L)
  expect_setequal(x$frequency, c("monthly", "yearly"))
  expect_true(all(grepl("^https://www\\.nrb\\.org\\.np/", x$source_url)))
  expect_setequal(x$file_type, c("xlsx", "xls"))
})

test_that("live discovery is opt-in", {
  skip_if_not(identical(Sys.getenv("LCNRB_LIVE_TESTS"), "true"))
  x <- lc_discover()
  expect_true(nrow(x) >= 90)
  expect_true(all(grepl("^https://([^/]+\\.)?nrb\\.org\\.np/", x$source_url)))
})

test_that("registered sources resolve by exact title, sector, and frequency", {
  fixture <- testthat::test_path("fixtures", "source-resolution-page.html")
  discovered <- lcNRB:::lc_parse_discovery_document(
    xml2::read_html(fixture), "real",
    "https://www.nrb.org.np/database-on-nepalese-economy/real-sector/"
  )
  matched <- lcNRB:::lc_match_discovered_sources(
    discovered, c("cpi", "gdp_quarterly")
  )
  expect_setequal(matched$dataset_id, c("cpi", "gdp_quarterly"))
  expect_match(matched$source_url[matched$dataset_id == "cpi"], "2027/01/CPI.xlsx$")
  expect_match(
    matched$source_url[matched$dataset_id == "gdp_quarterly"],
    "2027/01/Quarterly-GDP-New.xlsx$"
  )
})

test_that("registered source resolution rejects missing or ambiguous matches", {
  fixture <- testthat::test_path("fixtures", "source-resolution-page.html")
  discovered <- lcNRB:::lc_parse_discovery_document(
    xml2::read_html(fixture), "real",
    "https://www.nrb.org.np/database-on-nepalese-economy/real-sector/"
  )
  expect_error(
    lcNRB:::lc_match_discovered_sources(discovered[0, ], "cpi"),
    "found 0"
  )
  duplicate <- dplyr::bind_rows(
    discovered,
    discovered[discovered$title == "Consumer price index", ]
  )
  expect_error(
    lcNRB:::lc_match_discovered_sources(duplicate, "cpi"),
    "found 2"
  )
})
