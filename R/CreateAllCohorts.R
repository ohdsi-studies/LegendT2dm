#' Create the exposure cohorts
#'
#' @details
#' This function will create the exposure cohorts following the definitions included in this package.
#'
#' @param connectionDetails      An object of type \code{connectionDetails} as created using the
#'                               \code{\link[DatabaseConnector]{createConnectionDetails}} function in
#'                               the DatabaseConnector package.
#' @param cdmDatabaseSchema      Schema name where your patient-level data in OMOP CDM format resides.
#'                               Note that for SQL Server, this should include both the database and
#'                               schema name, for example 'cdm_data.dbo'.
#' @param cohortDatabaseSchema   Schema name where intermediate data can be stored. You will need to
#'                               have write priviliges in this schema. Note that for SQL Server, this
#'                               should include both the database and schema name, for example
#'                               'cdm_data.dbo'.
#' @param tablePrefix            A prefix to be used for all table names created for this study.
#' @param indicationId           A string denoting the indicationId for which the exposure cohorts
#'                               should be created.
#' @param oracleTempSchema       Should be used in Oracle to specify a schema where the user has write
#'                               priviliges for storing temporary tables.
#' @param outputFolder           Name of local folder to place results; make sure to use forward
#'                               slashes (/)
#' @param imputeExposureLengthWhenMissing  For PanTher: impute length of drug exposures when the length is missing?
#'
#' @export
createAllCohorts <- function(connectionDetails,
                             cdmDatabaseSchema,
                             cohortDatabaseSchema,
                             tablePrefix = "legend",
                             oracleTempSchema,
                             outputFolder,
                             databaseId,
                             filterExposureCohorts = NULL,
                             imputeExposureLengthWhenMissing = FALSE) {

  ParallelLogger::logInfo("Creating exposure cohorts")

  cohortTable <- paste(tablePrefix, "cohort", sep = "_")


  # Note: using connection when calling createCohortTable and instantiateCohortSet is pereferred, but requires this
  # fix in CohortDiagnostics to be released: https://github.com/OHDSI/CohortDiagnostics/commit/f4c920bc4feb5d701f1149ddd9cf7ca968be6a71
  # connection <- DatabaseConnector::connect(connectionDetails)
  # on.exit(DatabaseConnector::disconnect(connection))

  CohortDiagnostics::createCohortTable(connectionDetails = connectionDetails,
                                       cohortDatabaseSchema = cohortDatabaseSchema,
                                       cohortTable = cohortTable)

  # # Load exposures of interest --------------------------------------------------------------------
  # pathToCsv <- system.file("settings", "ExposuresOfInterest.csv", package = "LegendT2dm")
  # exposuresOfInterest <- read.csv(pathToCsv)
  # exposuresOfInterest <- exposuresOfInterest[order(exposuresOfInterest$conceptId), ]

  # Create exposure eras and cohorts ------------------------------------------------------
  ParallelLogger::logInfo("- Populating table ", cohortTable)
  # exposureGroupTable <- ""
  # exposureCombis <- NULL

  # cohorts <- readr::read_csv(file = system.file("settings", "classComparisonsWithJson.csv",
  #                                               package = "LegendT2dm"))
  #
  # if (!is.null(filterExposureCohorts)) {
  #   cohorts <- filterExposureCohorts(cohorts)
  # }
  #
  # for (idx in 1:nrow(cohorts)) {
  #
  #   json <- cohorts[idx, "json"] %>% pull()
  #   targetId <- cohorts[idx, "cohortId"] %>% pull()
  #
  #   sql <- ROhdsiWebApi::getCohortSql(RJSONIO::fromJSON(json),
  #                                           baseUrl,
  #                                           generateStats = createInclusionStatsTables)
  #
  #   CohortDiagnostics::instantiateCohort(connectionDetails = connectionDetails,
  #                                        connection = connection,
  #                                        cdmDatabaseSchema = cdmDatabaseSchema,
  #                                        cohortDatabaseSchema = cohortDatabaseSchema,
  #                                        cohortTable = exposureCohortTable,
  #                                        cohortJson = json,
  #                                        cohortSql = sql,
  #                                        cohortId = targetId,
  #                                        generateInclusionStats = createInclusionStatsTables)
  # }

  CohortDiagnostics::instantiateCohortSet(connectionDetails = connectionDetails,
                                          cdmDatabaseSchema = cdmDatabaseSchema,
                                          cohortDatabaseSchema = cohortDatabaseSchema,
                                          oracleTempSchema = oracleTempSchema,
                                          cohortTable = cohortTable,
                                          packageName = "LegendT2dm",
                                          cohortToCreateFile = "settings/CohortsToCreate.csv",
                                          generateInclusionStats = TRUE,
                                          inclusionStatisticsFolder = outputFolder)

  ParallelLogger::logInfo("Counting cohorts")
  sql <- SqlRender::loadRenderTranslateSql("GetCounts.sql",
                                           "LegendT2dm",
                                           dbms = connectionDetails$dbms,
                                           oracleTempSchema = oracleTempSchema,
                                           cdm_database_schema = cdmDatabaseSchema,
                                           work_database_schema = cohortDatabaseSchema,
                                           study_cohort_table = cohortTable)
  connection <- DatabaseConnector::connect(connectionDetails)
  counts <- DatabaseConnector::querySql(connection, sql, snakeCaseToCamelCase = TRUE)
  DatabaseConnector::disconnect(connection)
  counts$databaseId <- databaseId
  #counts <- addCohortNames(counts)
  write.csv(counts, file.path(outputFolder, "CohortCounts.csv"), row.names = FALSE)
}
