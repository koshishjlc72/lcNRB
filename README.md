# lcNRB

`lcNRB` is an independent R package for reproducible access to macroeconomic
data published by Nepal Rastra Bank (NRB).
It retrieves validated copies of official workbooks from a scheduled GitHub
mirror, stores immutable source vintages in a user cache, applies
dataset-specific parsers, and returns traceable long-form time series. The
original NRB URL and content hash remain attached to every observation. It is
not affiliated with or endorsed by Nepal Rastra Bank.

## Installation

```r
pak::pak("koshishjlc72/lcNRB")
```

## Quick start

```r
library(lcNRB)

lc_catalog()
lc_search("inflation")
lc_search("remittances")

# Dataset IDs return every verified series parsed from that workbook.
cpi <- lc_get("cpi")
money <- lc_get("monetary_survey")
bop <- lc_get("balance_of_payments")
gdp <- lc_get("gdp_quarterly")

# Indicator IDs return one series.
m2 <- lc_get("money_m2", start = "2015-01-01", end = "2026-01-01")
lc_metadata("money_m2")
```

The first request downloads the current validated workbook from the GitHub
data mirror. Subsequent calls use the local cache. `refresh = TRUE` checks the
mirror for a new content hash.

## Verified coverage

| Dataset ID | Source series | Frequency | Standardized dates |
|---|---|---:|---|
| `cpi` | National CPI indexes and annual inflation | Annual | No; fiscal-year label retained |
| `monetary_survey` | M1, M2, private credit, and BFI deposits, levels and YoY growth | Monthly | Yes; reported mid-month |
| `balance_of_payments` | 63 BPM5 rows including current account, trade, services, remittances, and reserves | Monthly cumulative | No; Nepali fiscal month retained |
| `gdp_quarterly` | Seasonally unadjusted GDP levels and YoY growth by activity | Quarterly | No; fiscal quarter retained |

The GDP workbook also contains seasonally adjusted tables. The September 2026
workbook repeats the `2023/24` header for its last adjusted growth columns, so
those ambiguous columns are not advertised or parsed.

## Standardized data

Every parsed row contains:

```text
indicator_id, indicator_name, sector, period, date, calendar, frequency,
value, unit, source_url, source_file, retrieved_at, vintage, dataset_id,
sheet_name, source_hash, parser_version, revision_status, notes
```

Original units are preserved. `lcNRB` does not silently convert NPR millions,
indexes, or percentage rates. Fiscal-year and Bikram Sambat labels are not
forced into Gregorian dates. Consequently, `start`/`end` filtering is rejected
for series without a validated `date`; filter their `period` column explicitly.

## Discovery, source files, and updates

```r
# Live inventory; discovered files are not necessarily parser-supported.
live <- lc_catalog(refresh = TRUE)

# Original workbook or raw sheets.
path <- lc_download("cpi")
raw <- lc_read_raw("cpi", sheet = "CPI_National")

# Content-hash comparison, then a validated update.
lc_update(dry_run = TRUE)
lc_update()
lc_cache_info()

# Optional: bypass the mirror and use NRB directly.
lc_download("cpi", source = "nrb", overwrite = TRUE)
lc_update(source = "nrb")
```

Raw sources are kept under `tools::R_user_dir("lcNRB", "cache")`, or the path
in `options(lcNRB.cache_dir = ...)`. Different SHA-256 vintages are retained.
`lc_clear_cache()` removes only this runtime cache.

The `data-cache` branch is refreshed daily by GitHub Actions. The job downloads
from NRB, validates every supported parser, verifies row and indicator counts,
and publishes the original XLSX bytes by SHA-256 only if the entire run passes.
If NRB is unavailable or a workbook layout changes, the workflow fails and the
last validated mirror remains available. Set `options(lcNRB.source = "nrb")`
to make direct NRB downloads the session default.

## Reliability and limitations

- Workbook parsers verify sheet names, titles, headers, and expected layouts;
  structural changes cause explicit errors.
- Discovery only follows HTTPS downloads on NRB-controlled domains.
- Mirror downloads are restricted to `raw.githubusercontent.com`, checked
  against the published SHA-256, and parsed locally; GitHub is a transport and
  availability layer, not the stated data source.
- Routine tests are offline. Optional source-integration tests use the audited
  workbooks or the live site when explicitly enabled.
- A changed source file is parsed and validated before becoming the latest
  processed cache. Historical source hashes remain in the manifest.
- The static registry is deliberately narrower than NRB's full database.
  Unverified files are discoverable but are never presented as standardized
  indicators.

See [the source audit](https://github.com/koshishjlc72/lcNRB/blob/main/docs/source-audit.md)
for workbook-level findings.

## Contributing

Open an issue before adding a new dataset parser. A contribution should include
the official source URL, a documented workbook audit, explicit layout checks,
a local regression fixture, validation rules, and updated registry metadata.
Never copy an existing parser to a new workbook without verifying every header,
unit, period convention, and footnote.

## License and attribution

Package code is MIT licensed. Data remain subject to the terms and attribution
requirements of their publisher. Cite Nepal Rastra Bank as the data source and
retain the `source_url`, `retrieved_at`, and `vintage` columns in reproducible
research outputs.
