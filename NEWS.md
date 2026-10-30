# lcNRB 0.1.0

* Initial CRAN release.
* Adds verified parsers for annual national CPI, the monthly Monetary Survey,
  monthly cumulative Balance of Payments (BPM5), and quarterly GDP.
* Preserves source URLs, SHA-256 hashes, retrieval timestamps, units, period
  labels, parser versions, and source notes with every observation.
* Adds content-addressed caching, source discovery, validation, and vintage
  update checks.
* Adds a scheduled, content-addressed GitHub data mirror. Mirror workbooks are
  accepted only after SHA-256 verification and the same local parser checks;
  direct NRB downloads remain available with `source = "nrb"`.
