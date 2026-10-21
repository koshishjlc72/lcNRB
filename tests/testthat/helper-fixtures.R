audit_fixture <- function(name) {
  candidates <- c(
    file.path(".source-audit", name),
    file.path("..", "..", ".source-audit", name),
    Sys.getenv(paste0("LCNRB_FIXTURE_", toupper(gsub("[^A-Za-z0-9]", "_", name))))
  )
  hit <- candidates[nzchar(candidates) & file.exists(candidates)]
  if (!length(hit)) testthat::skip(paste("Audited workbook fixture unavailable:", name))
  normalizePath(hit[[1L]], winslash = "/", mustWork = TRUE)
}
