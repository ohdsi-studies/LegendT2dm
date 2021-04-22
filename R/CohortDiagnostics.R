# Copyright 2020 Observational Health Data Sciences and Informatics
#
# This file is part of LegendT2dm
#
# Licensed under the Apache License, Version 2.0 (the "License");
# you may not use this file except in compliance with the License.
# You may obtain a copy of the License at
#
#     http://www.apache.org/licenses/LICENSE-2.0
#
# Unless required by applicable law or agreed to in writing, software
# distributed under the License is distributed on an "AS IS" BASIS,
# WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
# See the License for the specific language governing permissions and
# limitations under the License.

runClassCohortDiagnostics <- function(connectionDetails,
                                 cdmDatabaseSchema,
                                 cohortDatabaseSchema,
                                 tablePrefix,
                                 oracleTempSchema,
                                 outputFolder,
                                 databaseId,
                                 databaseName,
                                 databaseDescription,
                                 minCellCount) {


  CohortDiagnostics::runCohortDiagnostics(packageName = "LegendT2dm",
                                          cohortToCreateFile = "settings/classCohortsToCreate.csv",
                                          connectionDetails = connectionDetails,
                                          cdmDatabaseSchema = cdmDatabaseSchema,
                                          oracleTempSchema = oracleTempSchema,
                                          cohortDatabaseSchema = cohortDatabaseSchema,
                                          cohortTable = paste(tablePrefix, "cohort", sep = "_"),
                                          inclusionStatisticsFolder = outputFolder,
                                          exportFolder = file.path(outputFolder, "classCohortDiagnosticsExport"),
                                          databaseId = databaseId,
                                          databaseName = databaseName,
                                          databaseDescription = databaseDescription,
                                          runInclusionStatistics = TRUE,
                                          runBreakdownIndexEvents = TRUE,
                                          runIncludedSourceConcepts = TRUE,
                                          runCohortCharacterization = TRUE,
                                          #runTemporalCohortCharacterization = TRUE,
                                          runCohortOverlap = FALSE,
                                          runOrphanConcepts = TRUE,
                                          runIncidenceRate = TRUE,
                                          runTimeDistributions = TRUE,
                                          minCellCount = minCellCount)
}

runOutcomeCohortDiagnostics <- function(connectionDetails,
                                      cdmDatabaseSchema,
                                      cohortDatabaseSchema,
                                      tablePrefix,
                                      oracleTempSchema,
                                      outputFolder,
                                      databaseId,
                                      databaseName,
                                      databaseDescription,
                                      minCellCount) {


  CohortDiagnostics::runCohortDiagnostics(packageName = "LegendT2dm",
                                          cohortToCreateFile = "settings/OutcomesOfInterest.csv",
                                          connectionDetails = connectionDetails,
                                          cdmDatabaseSchema = cdmDatabaseSchema,
                                          oracleTempSchema = oracleTempSchema,
                                          cohortDatabaseSchema = cohortDatabaseSchema,
                                          cohortTable = paste(tablePrefix, "outcome", sep = "_"),
                                          inclusionStatisticsFolder = outputFolder,
                                          exportFolder = file.path(outputFolder, "outcomeCohortDiagnosticsExport"),
                                          databaseId = databaseId,
                                          databaseName = databaseName,
                                          databaseDescription = databaseDescription,
                                          runInclusionStatistics = TRUE,
                                          runBreakdownIndexEvents = TRUE,
                                          runIncludedSourceConcepts = TRUE,
                                          runCohortCharacterization = TRUE,
                                          #runTemporalCohortCharacterization = TRUE,
                                          runCohortOverlap = FALSE,
                                          runOrphanConcepts = TRUE,
                                          runIncidenceRate = TRUE,
                                          runTimeDistributions = TRUE,
                                          minCellCount = minCellCount)
}

#' Launch the Diagnostics Explorer Shiny app
#' @param connectionDetails An object of type \code{connectionDetails} as created using the
#'                          \code{\link[DatabaseConnector]{createConnectionDetails}} function in the
#'                          DatabaseConnector package, specifying how to connect to the server where
#'                          the CohortDiagnostics results have been uploaded using the
#'                          \code{\link{uploadResults}} function.
#' @param resultsDatabaseSchema  The schema on the database server where the CohortDiagnostics results
#'                               have been uploaded.
#' @param vocabularyDatabaseSchema  The schema on the database server where the vocabulary tables are located.
#' @param dataFolder       A folder where the premerged file is stored. Use
#'                         the \code{\link{preMergeDiagnosticsFiles}} function to generate this file.
#' @param runOverNetwork   (optional) Do you want the app to run over your network?
#' @param port             (optional) Only used if \code{runOverNetwork} = TRUE.
#' @param launch.browser   Should the app be launched in your default browser, or in a Shiny window.
#'                         Note: copying to clipboard will not work in a Shiny window.
#' @param aboutText        Text (using HTML markup) that will be displayed in an About tab in the Shiny app.
#'                         If not provided, no About tab will be shown.
#' @param cohortBaseUrl    The base URL for constructing linkouts to an ATLAS instance, using the
#'                         webApiCohortId in the cohortsToCreate file. If NULL, no linkouts will be
#'                         created.
#' @param conceptBaseUrl   The base URL for constructing linkouts to an Athena instance, using the
#'                         concept ID.
#'
#' @details
#' Launches a Shiny app that allows the user to explore the diagnostics
#'
#' @export
launchDiagnosticsExplorer <- function(dataFolder = "data",
                                      dataFile = "PreMerged.RData",
                                      connectionDetails = NULL,
                                      resultsDatabaseSchema = NULL,
                                      vocabularyDatabaseSchema = resultsDatabaseSchema,
                                      aboutText = NULL,
                                      cohortBaseUrl = "https://atlas.ohdsi.org/#/cohortdefinition/",
                                      conceptBaseUrl = "https://athena.ohdsi.org/search-terms/terms/",
                                      runOverNetwork = FALSE,
                                      port = 80,
                                      launch.browser = FALSE) {
  if (!is.null(connectionDetails) && connectionDetails$dbms != "postgresql")
    stop("Shiny application can only run against a Postgres database")

  ensure_installed("shiny")
  ensure_installed("shinydashboard")
  ensure_installed("shinyWidgets")
  ensure_installed("DT")
  ensure_installed("htmltools")
  ensure_installed("scales")
  ensure_installed("pool")
  ensure_installed("dplyr")
  ensure_installed("tidyr")
  ensure_installed("ggiraph")
  ensure_installed("stringr")
  ensure_installed("purrr")

  appDir <- system.file("shiny", "DiagnosticsExplorer", package = "LegendT2dm")

  if (launch.browser) {
    options(shiny.launch.browser = TRUE)
  }

  if (runOverNetwork) {
    myIpAddress <- system("ipconfig", intern = TRUE)
    myIpAddress <- myIpAddress[grep("IPv4", myIpAddress)]
    myIpAddress <- gsub(".*? ([[:digit:]])", "\\1", myIpAddress)
    options(shiny.port = port)
    options(shiny.host = myIpAddress)
  }
  shinySettings <- list(connectionDetails = connectionDetails,
                        resultsDatabaseSchema = resultsDatabaseSchema,
                        vocabularyDatabaseSchema = vocabularyDatabaseSchema,
                        dataFolder = dataFolder,
                        dataFile = dataFile,
                        aboutText = aboutText,
                        cohortBaseUrl = cohortBaseUrl,
                        conceptBaseUrl = conceptBaseUrl)
  .GlobalEnv$shinySettings <- shinySettings
  on.exit(rm("shinySettings", envir = .GlobalEnv))
  shiny::runApp(appDir = appDir)
}

# Borrowed from devtools:
# https://github.com/hadley/devtools/blob/ba7a5a4abd8258c52cb156e7b26bb4bf47a79f0b/R/utils.r#L44
is_installed <- function(pkg, version = 0) {
  installed_version <- tryCatch(utils::packageVersion(pkg), error = function(e) NA)
  !is.na(installed_version) && installed_version >= version
}

# Borrowed and adapted from devtools:
# https://github.com/hadley/devtools/blob/ba7a5a4abd8258c52cb156e7b26bb4bf47a79f0b/R/utils.r#L74
ensure_installed <- function(pkg) {
  if (!is_installed(pkg)) {
    msg <- paste0(sQuote(pkg), " must be installed for this functionality.")
    if (interactive()) {
      message(msg, "\nWould you like to install it?")
      if (menu(c("Yes", "No")) == 1) {
        install.packages(pkg)
      } else {
        stop(msg, call. = FALSE)
      }
    } else {
      stop(msg, call. = FALSE)
    }
  }
}
