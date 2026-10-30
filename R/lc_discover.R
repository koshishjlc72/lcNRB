lc_source_pages <- function() {
  c(
    real = "https://www.nrb.org.np/database-on-nepalese-economy/real-sector/",
    financial = "https://www.nrb.org.np/database-on-nepalese-economy/financial-sector/",
    fiscal = "https://www.nrb.org.np/database-on-nepalese-economy/fiscal-sector/",
    external = "https://www.nrb.org.np/database-on-nepalese-economy/external-sector/"
  )
}

lc_assert_trusted_url <- function(url) {
  lc_assert_scalar_string(url, "url")
  if (!grepl("^https://", url, ignore.case = TRUE)) {
    lc_stop("Only HTTPS downloads are allowed: %s", url)
  }
  host <- sub("^https://([^/:]+).*$", "\\1", tolower(url))
  if (!grepl("(^|\\.)nrb\\.org\\.np$", host)) {
    lc_stop("Refusing a download outside trusted NRB domains: %s", host)
  }
  invisible(TRUE)
}

lc_http_fetch <- function(url, dest, assert_url, attempts = 3L) {
  assert_url(url)
  handle <- curl::new_handle(
    useragent = paste0(
      "lcNRB/0.1.0 (+https://github.com/koshishjlc72/lcNRB; ",
      "macroeconomic research client)"
    ),
    connecttimeout = 20,
    timeout = 120,
    followlocation = TRUE,
    failonerror = TRUE
  )
  last <- NULL
  for (i in seq_len(attempts)) {
    ok <- tryCatch({
      curl::curl_download(url, destfile = dest, quiet = TRUE, handle = handle)
      TRUE
    }, error = function(e) {
      last <<- e
      FALSE
    })
    if (ok) return(invisible(dest))
    if (i < attempts) Sys.sleep(i)
  }
  lc_stop("Failed to download `%s` after %d attempts: %s", url, attempts, last$message)
}

lc_http_download <- function(url, dest, attempts = 3L) {
  lc_http_fetch(url, dest, lc_assert_trusted_url, attempts = attempts)
}

lc_parse_discovery_document <- function(doc, sector, page_url) {
  links <- xml2::xml_find_all(
    doc,
    "//a[contains(translate(@href,'ABCDEFGHIJKLMNOPQRSTUVWXYZ','abcdefghijklmnopqrstuvwxyz'),'.xls') or contains(translate(@href,'ABCDEFGHIJKLMNOPQRSTUVWXYZ','abcdefghijklmnopqrstuvwxyz'),'.csv')]"
  )
  if (!length(links)) return(tibble::tibble())
  href <- xml2::xml_attr(links, "href")
  urls <- xml2::url_absolute(href, page_url)
  trusted <- vapply(urls, function(x) {
    tryCatch({ lc_assert_trusted_url(x); TRUE }, error = function(e) FALSE)
  }, logical(1))
  links <- links[trusted]
  urls <- urls[trusted]
  if (!length(urls)) return(tibble::tibble())
  titles <- lc_clean_text(xml2::xml_text(links))
  titles[!nzchar(titles)] <- basename(sub("[?#].*$", "", urls[!nzchar(titles)]))
  freq <- vapply(links, function(node) {
    h <- xml2::xml_find_first(node, "preceding::h2[1]")
    if (inherits(h, "xml_missing")) NA_character_ else lc_clean_text(xml2::xml_text(h))
  }, character(1))
  ext <- tolower(tools::file_ext(sub("[?#].*$", "", urls)))
  out <- tibble::tibble(
    dataset_id = lc_slugify(titles),
    title = titles,
    sector = sector,
    frequency = tolower(freq),
    source_page = page_url,
    source_url = urls,
    file_type = ext,
    discovered_at = lc_now_utc()
  )
  out[!duplicated(out$source_url), , drop = FALSE]
}

lc_discover_page <- function(sector, page_url) {
  tmp <- tempfile(fileext = ".html")
  on.exit(unlink(tmp), add = TRUE)
  lc_http_download(page_url, tmp)
  doc <- xml2::read_html(tmp)
  lc_parse_discovery_document(doc, sector, page_url)
}

lc_match_discovered_sources <- function(discovered, dataset_ids) {
  reg <- lc_dataset_registry()
  reg <- reg[match(dataset_ids, reg$dataset_id), , drop = FALSE]
  if (anyNA(reg$dataset_id)) lc_stop("Cannot resolve unknown registered datasets.")

  matches <- lapply(seq_len(nrow(reg)), function(i) {
    hit <- discovered[
      tolower(discovered$title) == tolower(reg$discovery_title[[i]]) &
        tolower(discovered$sector) == tolower(reg$sector[[i]]) &
        tolower(discovered$frequency) == tolower(reg$discovery_frequency[[i]]),
      , drop = FALSE
    ]
    if (nrow(hit) != 1L) {
      lc_stop(
        "Expected exactly one live source for `%s` (%s / %s / %s); found %d.",
        reg$dataset_id[[i]], reg$discovery_title[[i]], reg$sector[[i]],
        reg$discovery_frequency[[i]], nrow(hit)
      )
    }
    tibble::tibble(
      dataset_id = reg$dataset_id[[i]],
      source_url = hit$source_url[[1L]],
      discovered_at = hit$discovered_at[[1L]]
    )
  })
  dplyr::bind_rows(matches)
}

lc_discover_registered_sources <- function(dataset_ids) {
  dataset_ids <- unique(dataset_ids)
  reg <- lc_dataset_registry()
  reg <- reg[reg$dataset_id %in% dataset_ids, , drop = FALSE]
  if (nrow(reg) != length(dataset_ids)) {
    lc_stop("One or more requested datasets are not registered.")
  }
  pages <- unique(reg[, c("sector", "source_page"), drop = FALSE])
  discovered <- lapply(seq_len(nrow(pages)), function(i) {
    lc_discover_page(pages$sector[[i]], pages$source_page[[i]])
  })
  lc_match_discovered_sources(dplyr::bind_rows(discovered), dataset_ids)
}

#' Discover workbooks on the official NRB database pages
#'
#' Discovery identifies files; it does not imply that a file has a verified
#' parser. Only HTTPS links on NRB-controlled domains are returned.
#'
#' @return A tibble of discovered source files and page metadata.
#' @export
lc_discover <- function() {
  pages <- lc_source_pages()
  results <- vector("list", length(pages))
  errors <- character()
  for (i in seq_along(pages)) {
    results[[i]] <- tryCatch(
      lc_discover_page(names(pages)[[i]], pages[[i]]),
      error = function(e) {
        errors <<- c(errors, sprintf("%s: %s", names(pages)[[i]], e$message))
        NULL
      }
    )
  }
  out <- lc_bind_rows_safe(results)
  if (!nrow(out)) {
    lc_stop("NRB discovery failed for every sector. %s", paste(errors, collapse = "; "))
  }
  if (length(errors)) {
    warning("Some NRB sector pages could not be discovered: ", paste(errors, collapse = "; "), call. = FALSE)
  }
  out[order(out$sector, out$frequency, out$title), , drop = FALSE]
}
