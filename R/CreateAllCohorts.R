#' Create the class exposure cohorts
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
createClassCohorts <- function(connectionDetails,
                             cdmDatabaseSchema,
                             cohortDatabaseSchema,
                             tablePrefix = "legend",
                             oracleTempSchema,
                             outputFolder,
                             databaseId,
                             filterExposureCohorts = NULL,
                             imputeExposureLengthWhenMissing = FALSE) {

  ParallelLogger::logInfo("Creating class exposure cohorts")

  cohortTable <- paste(tablePrefix, "cohort", sep = "_")


  # Note: using connection when calling createCohortTable and instantiateCohortSet is pereferred, but requires this
  # fix in CohortDiagnostics to be released: https://github.com/OHDSI/CohortDiagnostics/commit/f4c920bc4feb5d701f1149ddd9cf7ca968be6a71
  # connection <- DatabaseConnector::connect(connectionDetails)
  # on.exit(DatabaseConnector::disconnect(connection))

  CohortDiagnostics::createCohortTable(connectionDetails = connectionDetails,
                                       cohortDatabaseSchema = cohortDatabaseSchema,
                                       cohortTable = cohortTable)

  ParallelLogger::logInfo("- Populating table ", cohortTable)

  CohortDiagnostics::instantiateCohortSet(connectionDetails = connectionDetails,
                                          cdmDatabaseSchema = cdmDatabaseSchema,
                                          cohortDatabaseSchema = cohortDatabaseSchema,
                                          oracleTempSchema = oracleTempSchema,
                                          cohortTable = cohortTable,
                                          packageName = "LegendT2dm",
                                          cohortToCreateFile = "settings/classCohortsToCreate.csv",
                                          generateInclusionStats = TRUE,
                                          inclusionStatisticsFolder = outputFolder)

  ParallelLogger::logInfo("Counting class cohorts")
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
  write.csv(counts, file.path(outputFolder, "classCohortCounts.csv"), row.names = FALSE)
}

#' Create the outcome cohorts
#'
#' @details
#' This function will create the outcome cohorts following the definitions included in this package.
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
createOutcomeCohorts <- function(connectionDetails,
                               cdmDatabaseSchema,
                               cohortDatabaseSchema,
                               tablePrefix = "legend",
                               oracleTempSchema,
                               outputFolder,
                               databaseId,
                               filterOutcomeCohorts = NULL) {

  ParallelLogger::logInfo("Creating outcome cohorts")

  cohortTable <- paste(tablePrefix, "outcome", sep = "_")

  connection <- DatabaseConnector::connect(connectionDetails)
  on.exit(DatabaseConnector::disconnect(connection))

  CohortDiagnostics::createCohortTable(connection = connection,
                                       cohortDatabaseSchema = cohortDatabaseSchema,
                                       cohortTable = cohortTable)

  ParallelLogger::logInfo("- Populating table ", cohortTable)

  CohortDiagnostics::instantiateCohortSet(connection = connection,
                                          cdmDatabaseSchema = cdmDatabaseSchema,
                                          cohortDatabaseSchema = cohortDatabaseSchema,
                                          oracleTempSchema = oracleTempSchema,
                                          cohortTable = cohortTable,
                                          packageName = "LegendT2dm",
                                          cohortToCreateFile = "settings/OutcomesOfInterest.csv",
                                          generateInclusionStats = TRUE,
                                          inclusionStatisticsFolder = outputFolder)

  # Creating negative control outcome cohorts -------------------
  ParallelLogger::logInfo("Creating negative control outcome cohorts")
  negativeControls <- loadNegativeControls()
  sql <- SqlRender::loadRenderTranslateSql("NegativeControlOutcomes.sql",
                                           "LegendT2dm",
                                           dbms = connectionDetails$dbms,
                                           cdm_database_schema = cdmDatabaseSchema,
                                           cohort_database_schema = cohortDatabaseSchema,
                                           cohort_table = cohortTable,
                                           outcome_ids = unique(negativeControls$conceptId))
  DatabaseConnector::executeSql(connection, sql)

  # Count cohort sizes
  ParallelLogger::logInfo("Counting outcome cohorts")
  sql <- SqlRender::loadRenderTranslateSql("GetCounts.sql",
                                           "LegendT2dm",
                                           dbms = connectionDetails$dbms,
                                           oracleTempSchema = oracleTempSchema,
                                           cdm_database_schema = cdmDatabaseSchema,
                                           work_database_schema = cohortDatabaseSchema,
                                           study_cohort_table = cohortTable)

  counts <- DatabaseConnector::querySql(connection, sql, snakeCaseToCamelCase = TRUE)

  counts$databaseId <- databaseId
  write.csv(counts, file.path(outputFolder, "outcomeCohortCounts.csv"), row.names = FALSE)
}

loadNegativeControls <- function() {
  pathToCsv <- system.file("settings", "NegativeControls.csv", package = "LegendT2dm")
  negativeControls <- readr::read_csv(pathToCsv, col_types = readr::cols())
  return(negativeControls)
}
