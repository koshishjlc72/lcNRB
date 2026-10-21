lc_dataset_registry <- function() {
  path <- lc_package_file("extdata", "dataset_registry.csv")
  out <- utils::read.csv(path, stringsAsFactors = FALSE, check.names = FALSE)
  out$supported <- tolower(out$supported) == "true"
  tibble::as_tibble(out)
}

lc_indicator_registry <- function() {
  path <- lc_package_file("extdata", "indicator_registry.csv")
  tibble::as_tibble(utils::read.csv(
    path, stringsAsFactors = FALSE, check.names = FALSE
  ))
}

lc_dataset_row <- function(dataset_id) {
  reg <- lc_dataset_registry()
  row <- reg[reg$dataset_id == dataset_id, , drop = FALSE]
  if (!nrow(row)) {
    lc_stop(
      "Unknown dataset `%s`. Use lc_catalog() to list dataset IDs.",
      dataset_id
    )
  }
  row[1L, , drop = FALSE]
}

lc_resolve_indicator <- function(indicator) {
  lc_assert_scalar_string(indicator, "indicator")
  dreg <- lc_dataset_registry()
  ireg <- lc_indicator_registry()
  key <- tolower(indicator)
  ds <- dreg$dataset_id[tolower(dreg$dataset_id) == key]
  if (length(ds)) {
    return(list(dataset_id = ds[[1L]], indicator_id = NULL, kind = "dataset"))
  }
  hit <- ireg[tolower(ireg$indicator_id) == key, , drop = FALSE]
  if (nrow(hit)) {
    return(list(
      dataset_id = hit$dataset_id[[1L]],
      indicator_id = hit$indicator_id[[1L]],
      kind = "indicator"
    ))
  }
  lc_stop("Unknown indicator `%s`. Use lc_search() to find supported IDs.", indicator)
}

lc_parser_for <- function(parser) {
  switch(
    parser,
    cpi = lc_parse_cpi,
    gdp = lc_parse_gdp,
    monetary = lc_parse_monetary,
    bop = lc_parse_bop,
    lc_stop("No parser is registered for `%s`.", parser)
  )
}

lc_parser_version_for <- function(dataset_id) {
  switch(
    dataset_id,
    cpi = "cpi-1.0.0",
    gdp_quarterly = "gdp-quarterly-1.0.0",
    monetary_survey = "monetary-1.0.0",
    balance_of_payments = "bop-bpm5-1.0.0",
    lc_stop("No parser version is registered for `%s`.", dataset_id)
  )
}
