## Resubmission

This is a resubmission. In this version I have:

* replaced the relative README link to the excluded `docs/source-audit.md`
  file with its public GitHub URL, so the source-package README no longer
  contains an invalid file URI;
* added a daily, validated GitHub mirror because the official NRB site has
  experienced extended outages. The mirror stores the original workbook
  bytes by SHA-256; the package verifies the hash and runs the same parser
  checks locally while retaining the official NRB URL as provenance;
* retained an explicit `source = "nrb"` route for direct official downloads;
* removed the currently unreachable NRB landing-page hyperlink from README
  while continuing to return the official workbook URL with every observation;
* retained "Nepal Rastra Bank" because it is the official name of the source
  institution.

## Test environments

* Windows 11 x64, R 4.5.2
* GitHub Actions: Windows (R release)
* GitHub Actions: macOS (R release)
* GitHub Actions: Ubuntu (R release, oldrel-1, and devel)

## R CMD check results

0 errors | 0 warnings | 1 note

* This is a new submission.

## External data

The package accesses official Nepal Rastra Bank workbooks only when users call
download or retrieval functions. Network-dependent tests are disabled on CRAN.
Downloads fail with informative errors when the remote source is unavailable
or its workbook structure differs from the verified parser layout.
