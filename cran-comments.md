## Test environments

* Windows 11 x64, R 4.5.2

## R CMD check results

0 errors | 0 warnings | 1 note

* This is a new submission.

## External data

The package accesses official Nepal Rastra Bank workbooks only when users call
download or retrieval functions. Network-dependent tests are disabled on CRAN.
Downloads fail with informative errors when the remote source is unavailable
or its workbook structure differs from the verified parser layout.
