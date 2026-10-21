# NRB source audit

Audit date: **2026-10-20 (Asia/Katmandu)**

Official entry point: <https://www.nrb.org.np/database-on-nepalese-economy/>

This audit reflects the live website and representative workbooks inspected on
the date above. NRB may replace a file at the same page location. `lcNRB`
therefore identifies source vintages by SHA-256 content hash, not by filename
or URL alone.

## Website inventory

The landing page links separate Real, Financial, Fiscal, and External sector
pages plus a Read Me page. Live discovery found the following workbook links:

| Sector | Daily | Monthly | Quarterly | Yearly | Total |
|---|---:|---:|---:|---:|---:|
| Real | 0 | 3 | 3 | 16 | 22 |
| Financial | 2 | 14 | 6 | 19 | 41 |
| Fiscal | 1 | 3 | 0 | 13 | 17 |
| External | 0 | 7 | 0 | 10 | 17 |

The Read Me page also linked a database-description XLSX and a general-
information DOCX. Automatic discovery records all workbook links, but only the
four datasets below have verified standardized parsers in this release.

## Verified workbooks

### National Consumer Price Index (`cpi`)

- Page: <https://www.nrb.org.np/database-on-nepalese-economy/real-sector/>
- File audited: <https://www.nrb.org.np/contents/uploads/2026/09/Consumer-Price-Index-1.xlsx>
- HTTP metadata: 74,927 bytes; last modified 2026-09-28 09:29:53 GMT; XLSX content type.
- Sheets: `CPI_National` (63 x 10), `CPI_National_Sub-Groupwise` (22 x 28),
  `CPI_KTM Valley` (60 x 5), `CPI_Terai` (60 x 4), `CPI_Hills` (60 x 4),
  and `CPI_Mountain` (17 x 4).
- Verified extraction: `CPI_National`, rows beginning with a four-digit fiscal
  year. Rows 3-4 form a two-level header. Columns B-D are indexes and E-G are
  annual percentage changes.
- Coverage observed: fiscal years 1972/73 through 2025/26.
- Unit/base: the workbook reports base `2023/24 = 100`; the parser carries the
  base label in each index unit. A dash is treated as a reported missing value.
- Date treatment: the fiscal-year label is retained and `date` is `NA`; an
  exact Gregorian endpoint is not invented.

### Monetary Survey (`monetary_survey`)

- Page: <https://www.nrb.org.np/database-on-nepalese-economy/financial-sector/>
- File audited: <https://www.nrb.org.np/contents/uploads/2026/09/Monetary-survey-DDD.xlsx>
- HTTP metadata: 1,620,285 bytes; last modified 2026-09-23 05:22:56 GMT; XLSX content type.
- Sheets: `MA` (354 x 31), `DCS` (1206 x 298), `CBS` (1092 x 269), and
  `ODC` (1120 x 298).
- Verified extraction: `MA` only. Its first three rows contain the title and a
  two-level header. Data run from Mid-August 1997 through Mid-July 2026.
  Extracted fields are M1, M2, private-sector credit, and BFI deposits, each as
  NPR millions and year-on-year percent growth.
- Year representation: a calendar year is printed on January rows; the parser
  carries it forward, with the initial August-December rows assigned to the
  preceding calendar year.
- Source footnote: observations from July 2021 are compiled on a residence
  basis following IMF Monetary and Financial Statistics 2016 guidance.
- Limitation: the very wide `DCS`, `CBS`, and `ODC` sheets contain additional
  balance-sheet series and stacked sections. They are available through
  `lc_read_raw()` but are not standardized in this release.

### Balance of Payments BPM5 (`balance_of_payments`)

- Page: <https://www.nrb.org.np/database-on-nepalese-economy/external-sector/>
- File audited: <https://www.nrb.org.np/contents/uploads/2026/09/Balance-of-Payments-BPM5.xlsx>
- HTTP metadata: 192,943 bytes; last modified 2026-09-23 05:56:41 GMT; XLSX content type.
- Sheet: `BOP BPM5` (71 x 293).
- Layout: title and unit rows, fiscal years merged across twelve columns on row
  3, month labels on row 4, and 63 hierarchical line items spread across five
  description columns. The parser reconstructs each hierarchy before assigning
  a stable ID.
- Coverage observed: 2000/01 through provisional 2023/24, August-July.
- Unit and orientation: NPR million; values are cumulative sums within each
  fiscal year. Negative signs are preserved.
- Date treatment: the workbook explicitly says that August corresponds to the
  Nepali Shrawan period (mid-July to mid-August). The parser retains labels such
  as `2023/24 P-Jul` and leaves exact Gregorian dates unavailable.

### Quarterly GDP (`gdp_quarterly`)

- Page: <https://www.nrb.org.np/database-on-nepalese-economy/real-sector/>
- File audited: <https://www.nrb.org.np/contents/uploads/2025/08/Quarterly-GDP-2081-82Q2.xlsx>
- HTTP metadata: 76,201 bytes; last modified 2025-08-13 03:44:40 GMT; XLSX content type.
- Sheets: `Growth_rate` (50 x 60) and `label` (49 x 60).
- Verified extraction: the first table in each sheet—seasonally unadjusted GDP
  levels in NPR million and year-on-year growth in percent, by ISIC activity.
  Three header rows hold BS fiscal year, Gregorian fiscal year, and quarter.
- Coverage observed: 2010/11 Q1 through 2024/25 Q2.
- Important source limitation: the seasonally adjusted growth table repeats
  `2023/24` over the final Q1-Q2 columns, while the corresponding level table
  labels those columns `2024/25`. The parser does not guess which is correct and
  excludes the adjusted tables.

## Format variation and maintenance implications

- Files use merged cells, multilevel headers, horizontally and vertically
  oriented time series, blank separators, source notes, provisional/revised
  suffixes, and both Gregorian and Nepalese fiscal conventions.
- Several workbook filenames contain generic suffixes such as `DDD`, `-1`, or
  publication-month paths; these are not stable identifiers.
- An XLSX extension is insufficient validation. Downloads are checked for a ZIP
  signature and parser-specific workbook structure.
- Missing markers include blank cells and dashes. They are converted to `NA`
  only where a verified parser understands the surrounding table.
- Publication shocks and revisions are reported, not automatically rejected.
  Duplicates, structural changes, missing provenance, and ambiguous period
  headers are hard failures.

## Unverified scope

The live pages expose many additional sources—monthly prices, reserves,
exchange rates, foreign trade, fiscal operations, public debt, interest rates,
bank balance sheets, and more. Their links are discoverable through
`lc_discover()`, but this release does not advertise them as standardized
indicators. Each requires a separate layout audit, unit mapping, fixture, and
validation test before inclusion.
