#' Assess propensity models
#'
#' @details
#' This function will sample the exposure cohorts, and fit propensity models to identify issues.
#' Assumes the exposure and outcome cohorts have already been created.
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
#' @param oracleTempSchema       Should be used in Oracle to specify a schema where the user has write
#'                               priviliges for storing temporary tables.
#' @param outputFolder           Name of local folder to place results; make sure to use forward
#'                               slashes (/)
#' @param sampleSize             What is the maximum sample size across exposure cohorts?
#' @param minCellCount           The minimum cell count for fields contains person counts or fractions.
#' @param databaseId             A short string for identifying the database (e.g. 'Synpuf').
#'
#' @importFrom dplyr `%>%` pull
#'
#' @export
assessPhenotypes <- function(connectionDetails,
                             cdmDatabaseSchema,
                             cohortDatabaseSchema,
                             tablePrefix = "legend",
                             oracleTempSchema,
                             outputFolder,
                             sampleSize = 1e+05,
                             minCellCount = 5,
                             databaseId,
                             databaseName = databaseId,
                             databaseDescription = databaseId,
                             createExposureCohorts = TRUE,
                             runExposureCohortDiagnostics = TRUE,
                             createOutcomeCohorts = TRUE,
                             runOutcomeCohortDiagnostics = TRUE,
                             filterExposureCohorts = NULL,
                             filterOutcomeCohorts = NULL) {

  if (!file.exists(outputFolder)) {
    dir.create(outputFolder, recursive = TRUE)
  }
  ParallelLogger::addDefaultFileLogger(file.path(outputFolder, "assessmentLog.txt"))
  ParallelLogger::addDefaultErrorReportLogger(file.path(outputFolder, "errorReportR.txt"))
  on.exit(ParallelLogger::unregisterLogger("DEFAULT_FILE_LOGGER", silent = TRUE))
  on.exit(ParallelLogger::unregisterLogger("DEFAULT_ERRORREPORT_LOGGER", silent = TRUE), add = TRUE)


  if (createExposureCohorts) {
    # Exposures ----------------------------------------------------------------------------------------
    createClassCohorts(connectionDetails = connectionDetails,
                     cdmDatabaseSchema = cdmDatabaseSchema,
                     cohortDatabaseSchema = cohortDatabaseSchema,
                     tablePrefix = tablePrefix,
                     oracleTempSchema = oracleTempSchema,
                     outputFolder = outputFolder,
                     databaseId = databaseId,
                     filterExposureCohorts = filterExposureCohorts)
  }

  if (createOutcomeCohorts) {
    # Outcomes ----------------------------------------------------------------------------------
    createOutcomeCohorts(connectionDetails = connectionDetails,
                         cdmDatabaseSchema = cdmDatabaseSchema,
                         cohortDatabaseSchema = cohortDatabaseSchema,
                         tablePrefix = tablePrefix,
                         oracleTempSchema = oracleTempSchema,
                         outputFolder = outputFolder,
                         databaseId = databaseId,
                         filterOutcomeCohorts = filterOutcomeCohorts)
  }

  if (runExposureCohortDiagnostics) {
    runClassCohortDiagnostics(connectionDetails,
                              cdmDatabaseSchema,
                              cohortDatabaseSchema,
                              tablePrefix = tablePrefix,
                              oracleTempSchema = oracleTempSchema,
                              outputFolder = outputFolder,
                              databaseId = databaseId,
                              databaseName = databaseName,
                              databaseDescription = databaseDescription,
                              minCellCount = minCellCount)
  }

  if (runOutcomeCohortDiagnostics) {
    runOutcomeCohortDiagnostics(connectionDetails,
                              cdmDatabaseSchema,
                              cohortDatabaseSchema,
                              tablePrefix = tablePrefix,
                              oracleTempSchema = oracleTempSchema,
                              outputFolder = outputFolder,
                              databaseId = databaseId,
                              databaseName = databaseName,
                              databaseDescription = databaseDescription,
                              minCellCount = minCellCount)
  }
}
