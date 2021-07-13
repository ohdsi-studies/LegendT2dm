#' Prepare results for the LEGEND-T2DM Evidence Explorer Shiny app.
#'
#' @param resultsZipFile  Path to a zip file containing results from a study executed by this package.
#' @param dataFolder      A folder where the data files for the Evidence Explorer app will be stored.
#'
#' @examples
#'
#' \dontrun{
#' # Add results from three databases to the Shiny app data folder:
#' prepareForEvidenceExplorer("ResultsMDCD.zip", "/shinyData")
#' prepareForEvidenceExplorer("ResultsMDCR.zip", "/shinyData")
#' prepareForEvidenceExplorer("ResultsCCAE.zip", "/shinyData")
#'
#' # Launch the Shiny app:
#' launchEvidenceExplorer("/shinyData")
#' }
#'
#' @export
prepareForEvidenceExplorer <- function(resultsZipFile, dataFolder) {
  if (!file.exists(dataFolder)) {
    dir.create(dataFolder, recursive = TRUE)
  }
  tempFolder <- paste(tempdir(), "unzip")
  on.exit(unlink(tempFolder, recursive = TRUE))
  utils::unzip(resultsZipFile, exdir = tempFolder)
  databaseFileName <- file.path(tempFolder, "database.csv")
  if (!file.exists(databaseFileName)) {
    stop("Cannot find file database.csv in zip file")
  }
  databaseId <- read.csv(databaseFileName, stringsAsFactors = FALSE)$database_id
  splittableTables <- c("covariate_balance", "preference_score_dist", "kaplan_meier_dist")

  processSubet <- function(subset, tableName) {
    targetId <- subset$target_id[1]
    comparatorId <- subset$comparator_id[1]
    fileName <- sprintf("%s_t%s_c%s_%s.rds", tableName, targetId, comparatorId, databaseId)
    saveRDS(subset, file.path(dataFolder, fileName))
  }

  processFile <- function(file) {
    tableName <- gsub(".csv$", "", file)
    colTypes <- readr::cols()
    if (tableName == "covariate_balance") {
      colTypes <- "cdddddddddddddddd"
    }
    table <- readr::read_csv(file.path(tempFolder, file), col_types = colTypes)
    if (tableName %in% splittableTables) {
      subsets <- split(table, paste(table$target_id, table$comparator_id))
      plyr::l_ply(subsets, processSubet, tableName = tableName)
    } else {
      saveRDS(table, file.path(dataFolder, sprintf("%s_%s.rds", tableName, databaseId)))
    }
  }

  files <- list.files(tempFolder, ".*.csv")
  plyr::l_ply(files, processFile, .progress = "text")
}
