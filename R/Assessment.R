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
                             createCohorts = TRUE,
                             runCohortDiagnostics = TRUE,
                             filterExposureCohorts = NULL) {
  if (!file.exists(outputFolder)) {
    dir.create(outputFolder, recursive = TRUE)
  }
  ParallelLogger::addDefaultFileLogger(file.path(outputFolder, "assessmentLog.txt"))
  ParallelLogger::addDefaultErrorReportLogger(file.path(outputFolder, "errorReportR.txt"))
  on.exit(ParallelLogger::unregisterLogger("DEFAULT_FILE_LOGGER", silent = TRUE))
  on.exit(ParallelLogger::unregisterLogger("DEFAULT_ERRORREPORT_LOGGER", silent = TRUE), add = TRUE)


  if (createCohorts) {
    # Exposures ----------------------------------------------------------------------------------------
    createClassCohorts(connectionDetails = connectionDetails,
                     cdmDatabaseSchema = cdmDatabaseSchema,
                     cohortDatabaseSchema = cohortDatabaseSchema,
                     tablePrefix = tablePrefix,
                     oracleTempSchema = oracleTempSchema,
                     outputFolder = outputFolder,
                     databaseId = databaseId,
                     filterExposureCohorts = filterExposureCohorts)

    # exposureCohortTable <- paste(tablePrefix, tolower(indicationId), "exp_cohort", sep = "_")
    # sql <- "SELECT COUNT(*) AS exposure_count, cohort_definition_id AS cohort_id FROM @cohort_database_schema.@exposure_cohort_table GROUP BY cohort_definition_id;"
    # sql <- SqlRender::renderSql(sql = sql,
    #                             cohort_database_schema = cohortDatabaseSchema,
    #                             exposure_cohort_table = exposureCohortTable)$sql
    # sql <- SqlRender::translateSql(sql, targetDialect = connectionDetails$dbms)$sql
    # conn <- DatabaseConnector::connect(connectionDetails)
    # exposureCounts <- DatabaseConnector::querySql(conn, sql)
    # DatabaseConnector::disconnect(conn)
    # colnames(exposureCounts) <- SqlRender::snakeCaseToCamelCase(colnames(exposureCounts))
    # pathToCsv <- system.file("settings", "ExposuresOfInterest.csv", package = "Legend")
    # exposuresOfInterest <- read.csv(pathToCsv)
    # exposureCounts <- merge(exposureCounts, exposuresOfInterest[, c("cohortId", "type", "name")])
    # # To do: handle combination exposures for hypertension
    # exposureCounts$exposureCount[exposureCounts$exposureCount < minCellCount] <- paste0("<",
    #                                                                                     minCellCount)
    # exposureCounts$indicationId <- indicationId
    # exposureCounts$databaseId <- databaseId
    # write.csv(exposureCounts, file.path(assessmentExportFolder, "exposures.csv"), row.names = FALSE)
    #
    # # Outcomes ----------------------------------------------------------------------------------
    # createOutcomeCohorts(connectionDetails = connectionDetails,
    #                      cdmDatabaseSchema = cdmDatabaseSchema,
    #                      cohortDatabaseSchema = cohortDatabaseSchema,
    #                      tablePrefix = tablePrefix,
    #                      indicationId = indicationId,
    #                      oracleTempSchema = oracleTempSchema,
    #                      outputFolder = outputFolder)
    # outcomeCounts <- read.csv(file.path(outputFolder, indicationId, "outcomeCohortCounts.csv"))
    # outcomeCounts$count[outcomeCounts$count < minCellCount] <- paste0("<", minCellCount)
    # outcomeCounts$indicationId <- indicationId
    # outcomeCounts$databaseId <- databaseId
    # write.csv(outcomeCounts, file.path(assessmentExportFolder, "outcomes.csv"), row.names = FALSE)
    #
    # # Subgroups ---------------------------------------------------------------------------------
    # ParallelLogger::logInfo("Sampling cohorts for subgroup feasibility")
    # pairedCohortTable <- paste(tablePrefix, tolower(indicationId), "pair_cohort", sep = "_")
    # smallSampleTable <- paste(tablePrefix, tolower(indicationId), "small_sample", sep = "_")
    # sql <- SqlRender::loadRenderTranslateSql("SampleCohortsForSubgroupFeasibility.sql",
    #                                          "Legend",
    #                                          dbms = connectionDetails$dbms,
    #                                          oracleTempSchema = oracleTempSchema,
    #                                          cohort_database_schema = cohortDatabaseSchema,
    #                                          paired_cohort_table = pairedCohortTable,
    #                                          small_sample_table = smallSampleTable,
    #                                          sample_size = sampleSize)
    # conn <- DatabaseConnector::connect(connectionDetails)
    # DatabaseConnector::executeSql(conn, sql)
    #
    # subgroupCovariateSettings <- createSubgroupCovariateSettings()
    # subgroupCovs <- FeatureExtraction::getDbCovariateData(connection = conn,
    #                                                       oracleTempSchema = oracleTempSchema,
    #                                                       cdmDatabaseSchema = cdmDatabaseSchema,
    #                                                       cohortDatabaseSchema = cohortDatabaseSchema,
    #                                                       cohortTable = smallSampleTable,
    #                                                       cohortTableIsTemp = FALSE,
    #                                                       covariateSettings = subgroupCovariateSettings,
    #                                                       aggregated = FALSE)
    # DatabaseConnector::disconnect(conn)
    # covs <- ff::as.ram(subgroupCovs$covariates)
    # covs <- aggregate(covariateValue ~ covariateId, covs, sum)
    # covs <- merge(covs, data.frame(covariateId = ff::as.ram(subgroupCovs$covariateRef$covariateId),
    #                                covariateName = ff::as.ram(subgroupCovs$covariateRef$covariateName)))
    #
    # covs$fraction <- round(covs$covariateValue/subgroupCovs$metaData$populationSize, 3)
    # idx <- covs$covariateValue < minCellCount
    # covs$fraction[idx] <- paste0("<", round(minCellCount/subgroupCovs$metaData$populationSize, 3))
    # covs <- covs[, c("covariateId", "covariateName", "fraction")]
    # covs$indicationId <- indicationId
    # covs$databaseId <- databaseId
    # write.csv(covs, file.path(assessmentExportFolder, "subgroups.csv"), row.names = FALSE)
    #
    # # Compress ----------------------------------------------------------------------------------
    # zipName <- file.path(assessmentExportFolder,
    #                      sprintf("PhenotypeAssessment%s%s.zip", indicationId, databaseId))
    # files <- list.files(assessmentExportFolder, pattern = ".*\\.csv$")
    # oldWd <- setwd(assessmentExportFolder)
    # on.exit(setwd(oldWd))
    # DatabaseConnector::createZipFile(zipFile = zipName, files = files)
    # ParallelLogger::logInfo("Results are ready for sharing at:", zipName)
  }


  if (runCohortDiagnostics) {
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
}
