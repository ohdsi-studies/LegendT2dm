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
createExposureCohorts <- function(connectionDetails,
                                  cdmDatabaseSchema,
                                  cohortDatabaseSchema,
                                  tablePrefix = "legend",
                                  indicationId = "T2DM",
                                  oracleTempSchema,
                                  outputFolder,
                                  baseUrl,
                                  databaseId,
                                  filterExposureCohorts = NULL,
                                  createInclusionStatsTables = FALSE,
                                  imputeExposureLengthWhenMissing = FALSE) {

  ParallelLogger::logInfo("Creating exposure cohorts for indicationId: ", indicationId)

  indicationFolder <- file.path(outputFolder, indicationId)
  attritionTable <- paste(tablePrefix, tolower(indicationId), "attrition", sep = "_")
  exposureEraTable <- paste(tablePrefix, tolower(indicationId), "exp_era", sep = "_")
  exposureCohortTable <- paste(tablePrefix, tolower(indicationId), "exp_cohort", sep = "_")
  pairedCohortTable <- paste(tablePrefix, tolower(indicationId), "pair_cohort", sep = "_")
  pairedCohortSummaryTable <- paste(tablePrefix, tolower(indicationId), "pair_sum", sep = "_")

  if (!file.exists(indicationFolder)) {
    dir.create(indicationFolder, recursive = TRUE)
  }


  conn <- DatabaseConnector::connect(connectionDetails)
  on.exit(DatabaseConnector::disconnect(conn))

  CohortDiagnostics::createCohortTable(connectionDetails = connectionDetails,
                                       connection = conn,
                                       cohortDatabaseSchema = cohortDatabaseSchema,
                                       cohortTable = exposureCohortTable,
                                       createInclusionStatsTables = createInclusionStatsTables)

  # Load exposures of interest --------------------------------------------------------------------
  pathToCsv <- system.file("settings", "ExposuresOfInterest.csv", package = "Legend")
  exposuresOfInterest <- read.csv(pathToCsv)
  exposuresOfInterest <- exposuresOfInterest[exposuresOfInterest$indicationId == indicationId, ]
  exposuresOfInterest <- exposuresOfInterest[order(exposuresOfInterest$conceptId), ]

  # Create exposure eras and cohorts ------------------------------------------------------
  ParallelLogger::logInfo("- Populating tables ", exposureEraTable, " and ", exposureCohortTable)
  exposureGroupTable <- ""
  exposureCombis <- NULL

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
  #                                        connection = conn,
  #                                        cdmDatabaseSchema = cdmDatabaseSchema,
  #                                        cohortDatabaseSchema = cohortDatabaseSchema,
  #                                        cohortTable = exposureCohortTable,
  #                                        cohortJson = json,
  #                                        cohortSql = sql,
  #                                        cohortId = targetId,
  #                                        generateInclusionStats = createInclusionStatsTables)
  # }

  CohortDiagnostics::instantiateCohortSet(connectionDetails = connectionDetails,
                                          connection = conn,
                                          cdmDatabaseSchema = cdmDatabaseSchema,
                                          cohortDatabaseSchema = cohortDatabaseSchema,
                                          cohortTable = exposureCohortTable,
                                          packageName = "LegendT2dm",
                                          generateInclusionStats = createInclusionStatsTables)

  ParallelLogger::logInfo("Counting cohorts")
  sql <- SqlRender::loadRenderTranslateSql("GetCounts.sql",
                                           "LegendT2dm",
                                           dbms = connectionDetails$dbms,
                                           oracleTempSchema = oracleTempSchema,
                                           cdm_database_schema = cdmDatabaseSchema,
                                           work_database_schema = cohortDatabaseSchema,
                                           study_cohort_table = exposureCohortTable)
  counts <- DatabaseConnector::querySql(conn, sql)
  colnames(counts) <- SqlRender::snakeCaseToCamelCase(colnames(counts))
  counts$databaseId <- databaseId
  #counts <- addCohortNames(counts)
  write.csv(counts, file.path(outputFolder, "CohortCounts.csv"), row.names = FALSE)
}
