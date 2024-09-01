# helper functions to check over OptumEHR covariate balance table before uploading again

library(dplyr)

checkBalance <- function(chunk, pos){
  sprintf("Checking row %s through %s ...\n",
         pos, nrow(chunk)+pos-1)

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
  }
}


thePath = ""
csvFileName = "covariate_balance.csv"

readr::read_csv_chunked(
  file = file.path(thePath, csvFileName),
  callback = checkBalance,
  chunk_size = 1e6,
  col_types = readr::cols(),
  guess_max = 1e5,
  progress = FALSE
)
