library(lcNRB)

paths <- list.files("data-raw/processed", pattern = "\\.rds$", full.names = TRUE)
if (!length(paths)) stop("No processed data artifacts were generated.", call. = FALSE)
for (path in paths) {
  data <- readRDS(path)
  lc_validate(data)
  message(basename(path), ": ", nrow(data), " validated observations")
}
