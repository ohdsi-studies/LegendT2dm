# helper functions to check over OptumEHR covariate balance table before uploading again

library(dplyr)


thePath = "E:/LegendT2dmOutput_optum_ehr_drug2/drug/export/"
csvFileName = "covariate_balance.csv"

chunk0 <- readr::read_csv(
  file = file.path(thePath, csvFileName),
  n_max = 2,
  col_types = readr::cols(),
  guess_max = 2
)
theNames = names(chunk0)


checkBalance <- function(chunk, pos){
  cat(sprintf("Checking row %s through %s ...\n",
              pos, nrow(chunk)+pos-1))

  sel <- chunk %>%
    filter(database_id == "OptumEHR",
           target_id == 311100000,
           comparator_id == 331100000,
           analysis_id %in% c(5,6))

  if(nrow(sel) > 0){
    cat("Found it!! \n\n")
    maxStd <- sel %>% group_by(analysis_id) %>%
      summarize(maxStdDiff = max(std_diff_after, na.rm = TRUE)) %>%
      ungroup() %>%
      pull(maxStdDiff)

    cat("The maxStdDiff after is:",
        paste(round(maxStd,4), collapse = ", "),
        "\n\n\n")

    names(sel) = theNames

    readr::write_csv(sel, file.path(thePath, "covariate_balance_canaempa.csv"))
    cat("Relevant chunk has been out put!\n")

  }
}


thePath = "E:/LegendT2dmOutput_optum_ehr_drug2/drug/export/"
csvFileName = "covariate_balance.csv"

readr::read_csv_chunked(
  file = file.path(thePath, csvFileName),
  callback = checkBalance,
  chunk_size = 1e6,
  col_types = readr::cols(),
  guess_max = 1e5,
  progress = FALSE
)


## write the relevant rows to a file...

# theBalance = readr::read_csv_chunked(
#   file = file.path(thePath, csvFileName),
#   callback = writeIt,
#   chunk_size = 1e6,
#   skip = 3.7e+7,
#   col_types = readr::cols(),
#   guess_max = 1e5,
#   progress = FALSE
# )

chunk0 <- readr::read_csv(
  file = file.path(thePath, csvFileName),
  n_max = 2,
  col_types = readr::cols(),
  guess_max = 2
)
theNames = names(chunk0)

chunk <- readr::read_csv(
  file = file.path(thePath, csvFileName),
  skip = 3.7e7,
  n_max = 1e6,
  col_types = readr::cols(),
  guess_max = 1e5
)

names(chunk) = theNames

readr::write_csv(chunk, file =  file.path(thePath, "covariate_balance_chunk.csv"))
