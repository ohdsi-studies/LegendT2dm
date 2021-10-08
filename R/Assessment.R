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
#' @param vocabularyDatabaseSchema   Schema name where your vocabulary tables in OMOP CDM format resides.
#'                               Note that for SQL Server, this should include both the database and
#'                               schema name, for example 'cdm_data.dbo'.
#' @param cohortDatabaseSchema   Schema name where intermediate data can be stored. You will need to
#'                               have write priviliges in this schema. Note that for SQL Server, this
#'                               should include both the database and schema name, for example
#'                               'cdm_data.dbo'.
#' @param tablePrefix            A prefix to be used for all table names created for this study.
#' @param indicationId           A string denoting the indicationId for which the exposure cohorts
#'                               should be created; should be 'class' or 'drug'
#' @param oracleTempSchema       Should be used in Oracle to specify a schema where the user has write
#'                               priviliges for storing temporary tables.
#' @param outputFolder           Name of local folder to place results; make sure to use forward
#'                               slashes (/)
#' @param sampleSize             What is the maximum sample size across exposure cohorts?
#' @param minCellCount           The minimum cell count for fields contains person counts or fractions.
#' @param databaseId             A short string for identifying the database (e.g. 'Synpuf').
#' @param databaseName           Full name for the database.
#' @param databaseDescription    Brief description of population in database
#' @param createExposureCohorts  Boolean: execute exposure cohort instantiation? \code{FALSE} will
#'                               attempt to re-use the cohort table in \code{cohortDatabaseSchema}
#' @param createOutcomeCohorts   Boolean: execute outcome cohort instantiation? \code{FALSE} will
#'                               attempt to re-use the cohort table in \code{cohortDatabaseSchema}
#' @param runExposureCohortDiagnostics Boolean: execute cohort diagnostics on exposure cohorts?
#' @param runOutcomeCohortDiagnostics Boolean: execute cohort diagnostics on outcome cohorts?
#' @param filterExposureCohorts  Optional subset of exposure cohorts to use; \code{NULL} implies all.
#' @param filterOutcomeCohorts   Options subset of outcome cohorts to use; \code{NULL} implies all.
#'
#' @export
assessPhenotypes <- function(connectionDetails,
                             cdmDatabaseSchema,
                             vocabularyDatabaseSchema = cdmDatabaseSchema,
                             cohortDatabaseSchema,
                             tablePrefix = "legend_t2dm",
                             indicationId = "class",
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

  ParallelLogger::logInfo(sprintf("Starting assessPhenotypes() for LEGEND-T2DM %s-vs-%s studies",
                                  indicationId, indicationId))

  if (createExposureCohorts) {
    # Exposures ----------------------------------------------------------------------------------------
    createExposureCohorts(connectionDetails = connectionDetails,
                          cdmDatabaseSchema = cdmDatabaseSchema,
                          vocabularyDatabaseSchema = vocabularyDatabaseSchema,
                          cohortDatabaseSchema = cohortDatabaseSchema,
                          tablePrefix = tablePrefix,
                          indicationId = indicationId,
                          oracleTempSchema = oracleTempSchema,
                          outputFolder = outputFolder,
                          databaseId = databaseId,
                          filterExposureCohorts = filterExposureCohorts)
  }

  writePairedCounts(outputFolder = outputFolder, indicationId = indicationId)

  if (createOutcomeCohorts) {
    # Outcomes ----------------------------------------------------------------------------------
    createOutcomeCohorts(connectionDetails = connectionDetails,
                         cdmDatabaseSchema = cdmDatabaseSchema,
                         vocabularyDatabaseSchema = vocabularyDatabaseSchema,
                         cohortDatabaseSchema = cohortDatabaseSchema,
                         tablePrefix = tablePrefix,
                         oracleTempSchema = oracleTempSchema,
                         outputFolder = outputFolder,
                         databaseId = databaseId,
                         filterOutcomeCohorts = filterOutcomeCohorts)
  }

  if (runExposureCohortDiagnostics) {
    runExposureCohortDiagnostics(connectionDetails,
                                 cdmDatabaseSchema,
                                 vocabularyDatabaseSchema = vocabularyDatabaseSchema,
                                 cohortDatabaseSchema,
                                 tablePrefix = tablePrefix,
                                 indicationId = indicationId,
                                 oracleTempSchema = oracleTempSchema,
                                 outputFolder = outputFolder,
                                 databaseId = databaseId,
                                 databaseName = databaseName,
                                 databaseDescription = databaseDescription,
                                 minCellCount = minCellCount)

    oldZipName <- file.path(outputFolder, indicationId, "cohortDiagnosticsExport",
                            sprintf("Results_%s.zip", databaseId))

    zipName <- file.path(outputFolder, indicationId, "cohortDiagnosticsExport",
                         sprintf("Results_%s_exposures_%s.zip", indicationId, databaseId))
    file.rename(oldZipName, zipName)

    ParallelLogger::logInfo("Exposure diagnostics results are ready for sharing at:", zipName)
  }

  if (runOutcomeCohortDiagnostics) {
    runOutcomeCohortDiagnostics(connectionDetails,
                                cdmDatabaseSchema,
                                vocabularyDatabaseSchema = vocabularyDatabaseSchema,
                                cohortDatabaseSchema,
                                tablePrefix = tablePrefix,
                                oracleTempSchema = oracleTempSchema,
                                outputFolder = outputFolder,
                                databaseId = databaseId,
                                databaseName = databaseName,
                                databaseDescription = databaseDescription,
                                minCellCount = minCellCount)

    oldZipName <- file.path(outputFolder, "outcome", "cohortDiagnosticsExport",
                            sprintf("Results_%s.zip", databaseId))

    zipName <- file.path(outputFolder, "outcome", "cohortDiagnosticsExport",
                         sprintf("Results_outcomes_%s.zip", databaseId))
    file.rename(oldZipName, zipName)

    ParallelLogger::logInfo("Outcome diagnostics results are ready for sharing at:", zipName)
  }

  ParallelLogger::logInfo(sprintf("Finished assessPhenotypes() for LEGEND-T2DM %s-vs-%s studies",
                                  indicationId, indicationId))
}

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
#' @param indicationId           A string denoting the indicationId for which the exposure cohorts
#'                               should be created; should be 'class' or 'drug'
#' @param oracleTempSchema       Should be used in Oracle to specify a schema where the user has write
#'                               priviliges for storing temporary tables.
#' @param outputFolder           Name of local folder to place results; make sure to use forward
#'                               slashes (/)
#' @param minCohortSize          Minimum number of people that have to be in each cohort to keep a pair of
#'                               cohorts.
#' @param sampleSize             What is the maximum sample size for each exposure cohort?
#' @param maxCores               How many parallel cores should be used? If more cores are made
#'                               available this can speed up the analyses.
#' @param databaseId             A short string for identifying the database (e.g. 'Synpuf').
#' @param preferenceScoreBounds  Preference score bounds to use when reporting proportion of subjects in
#'                               empirical clinical equipoise.
#' @param forceNewCmDataObjects  Force recreation of \code{CohortMethod} data objects?
#'
#' @export
assessPropensityModels <- function(connectionDetails,
                                   cdmDatabaseSchema,
                                   cohortDatabaseSchema,
                                   tablePrefix = "legend_t2dm",
                                   indicationId = "class",
                                   oracleTempSchema,
                                   outputFolder,
                                   minCohortSize = 1000,
                                   sampleSize = 1000,
                                   maxCores = 4,
                                   databaseId,
                                   preferenceScoreBounds = c(0.3, 0.7),
                                   forceNewCmDataObjects = FALSE) {

  originalCohortTable <- paste(tablePrefix, tolower(indicationId), "cohort", sep = "_")
  sampledCohortTable <- paste(tablePrefix, tolower(indicationId), "sample_cohort", sep = "_")

  indicationFolder <- file.path(outputFolder, indicationId)
  assessmentExportFolder <- file.path(indicationFolder, "assessmentOfPropensityScores")
  if (!file.exists(assessmentExportFolder)) {
    dir.create(assessmentExportFolder, recursive = TRUE)
  }
  ParallelLogger::addDefaultFileLogger(file.path(indicationFolder, "logAssesPropensityModels.txt"))

  ParallelLogger::logInfo(sprintf("Starting assessPropensityModels() for LEGEND-T2DM %s-vs-%s studies",
                                  indicationId, indicationId))

  ParallelLogger::logInfo("Sampling cohorts for propensity model feasibility")
  sql <- SqlRender::loadRenderTranslateSql("SampleCohortsForPsFeasibility.sql",
                                           packageName = "LegendT2dm",
                                           dbms = connectionDetails$dbms,
                                           oracleTempSchema = oracleTempSchema,
                                           cohort_database_schema = cohortDatabaseSchema,
                                           original_cohort_table = originalCohortTable,
                                           sampled_cohort_table = sampledCohortTable,
                                           sample_size = sampleSize)
  conn <- DatabaseConnector::connect(connectionDetails)
  DatabaseConnector::executeSql(conn, sql)
  DatabaseConnector::disconnect(conn)

  ParallelLogger::logInfo("Counting ", indicationId, " sampled exposure cohorts")
  sql <- SqlRender::loadRenderTranslateSql("GetCounts.sql",
                                           "LegendT2dm",
                                           dbms = connectionDetails$dbms,
                                           oracleTempSchema = oracleTempSchema,
                                           cdm_database_schema = cdmDatabaseSchema,
                                           work_database_schema = cohortDatabaseSchema,
                                           study_cohort_table = sampledCohortTable)
  connection <- DatabaseConnector::connect(connectionDetails)
  counts <- DatabaseConnector::querySql(connection, sql, snakeCaseToCamelCase = TRUE)
  DatabaseConnector::disconnect(connection)
  counts$databaseId <- databaseId
  #counts <- addCohortNames(counts)
  write.csv(counts, file.path(outputFolder, indicationId, "sampledCohortCounts.csv"), row.names = FALSE)

  filterByExposureCohortsSize(outputFolder = outputFolder, indicationId = indicationId, minCohortSize = minCohortSize)

  fetchAllDataFromServer(connectionDetails = connectionDetails,
                         cdmDatabaseSchema = cdmDatabaseSchema,
                         oracleTempSchema = oracleTempSchema,
                         cohortDatabaseSchema = cohortDatabaseSchema,
                         tablePrefix = tablePrefix,
                         indicationId = indicationId,
                         outputFolder = outputFolder,
                         useSample = TRUE,
                         forceNewObjects = forceNewCmDataObjects)

  generateAllCohortMethodDataObjects(outputFolder = outputFolder,
                                     indicationId = indicationId,
                                     useSample = TRUE,
                                     restrictToOt1 = TRUE)

  ParallelLogger::logInfo("Fitting propensity models on sampled data")

  fitPsModel <- function(i, exposureSummary, psCvThreads, indicationFolder) {
    targetId <- exposureSummary$targetId[i]
    comparatorId <- exposureSummary$comparatorId[i]

    fileName <- file.path(indicationFolder,
                          "cmSampleOutput",
                          paste0("Ps_t", targetId, "_c", comparatorId, ".rds"))

    if (!file.exists(fileName) && isOt1(targetId)) {
      cmFileName <- file.path(indicationFolder,
                              "cmSampleOutput",
                              paste0("CmData_l1_t", targetId, "_c", comparatorId, ".zip"))
      cmData <- CohortMethod::loadCohortMethodData(cmFileName)
      studyPop <- CohortMethod::createStudyPopulation(cohortMethodData = cmData,
                                                      removeDuplicateSubjects = "keep first",
                                                      restrictToCommonPeriod = TRUE,
                                                      minDaysAtRisk = 0)
      ps <- CohortMethod::createPs(cohortMethodData = cmData,
                                   population = studyPop,
                                   errorOnHighCorrelation = TRUE,
                                   stopOnError = FALSE,
                                   control = Cyclops::createControl(noiseLevel = "silent",
                                                                    cvType = "auto",
                                                                    tolerance = 2e-07,
                                                                    cvRepetitions = 1,
                                                                    startingVariance = 0.01,
                                                                    seed = 123,
                                                                    threads = psCvThreads))

      saveRDS(ps, fileName)
    }
    return(NULL)
  }

  createPsThreads <- max(1, round(maxCores/10))
  psCvThreads <- min(10, maxCores)
  exposureSummary <- read.csv(file.path(indicationFolder,
                                        "pairedExposureSummaryFilteredBySize.csv"))

  cluster <- ParallelLogger::makeCluster(createPsThreads)
  ParallelLogger::clusterApply(cluster = cluster,
                               fun = fitPsModel,
                               x = 1:nrow(exposureSummary),
                               exposureSummary = exposureSummary,
                               psCvThreads = psCvThreads,
                               indicationFolder = indicationFolder)
  ParallelLogger::stopCluster(cluster)

  ParallelLogger::logInfo("Fetching propensity models")

  getModel <- function(i, exposureSummary, indicationFolder) {
    targetId <- exposureSummary$targetId[i]
    comparatorId <- exposureSummary$comparatorId[i]
    psFileName <- file.path(indicationFolder,
                            "cmSampleOutput",
                            paste0("Ps_t", targetId, "_c", comparatorId, ".rds"))

    if (file.exists(psFileName)) {
      ps <- readRDS(psFileName)
      metaData <- attr(ps, "metaData")

      if (is.null(metaData$psError)) {
        fileName <- file.path(indicationFolder,
                              "cmSampleOutput",
                              paste0("CmData_l1_t", targetId, "_c", comparatorId, ".zip"))
        cmData <- CohortMethod::loadCohortMethodData(fileName)
        model <- CohortMethod::getPsModel(ps, cmData)
        Andromeda::close(cmData)

        # Truncate to first 25 covariates:
        if (nrow(model) > 25) {
          model <- model[1:25, ]
        }

      } else if (!is.null(metaData$psHighCorrelation)) {
        model <- tibble::tibble(coefficient = Inf,
                                covariateId = metaData$psHighCorrelation$covariateId,
                                covariateName = metaData$psHighCorrelation$covariateName)
      } else {
        model <- tibble::tibble(coefficient = NA,
                                covariateId = NA,
                                covariateName = paste("Error:", metaData$psError))
      }

      targetName <- exposureSummary$targetName[i]
      comparatorName <- exposureSummary$comparatorName[i]
      model$targetId <- targetId
      model$targetName <- targetName
      model$comparatorId <- comparatorId
      model$comparatorName <- comparatorName
      model$comparison <- paste(targetName, comparatorName, sep = " vs. ")
      return(model)
    } else {
      return(NULL)
    }
  }

  data <- plyr::llply(1:nrow(exposureSummary),
                      getModel,
                      exposureSummary = exposureSummary,
                      indicationFolder = indicationFolder,
                      .progress = "text")
  data <- do.call("rbind", data)

  # Fix intercept covariateId
  areIntercept <- which(data$covariateName == "(Intercept)")
  data$covariateId[areIntercept] <- 0

  data$databaseId <- databaseId
  data$indicationId <- indicationId
  names(data) <- SqlRender::camelCaseToSnakeCase(names(data))
  write.csv(data, file.path(assessmentExportFolder, "ps_covariate_assessment.csv"), row.names = FALSE)

  ParallelLogger::logInfo("Computing AUCs")

  getAuc <- function(i, exposureSummary, indicationFolder) {
    targetId <- exposureSummary$targetId[i]
    comparatorId <- exposureSummary$comparatorId[i]
    targetName <- exposureSummary$targetName[i]
    comparatorName <- exposureSummary$comparatorName[i]
    psFileName <- file.path(indicationFolder,
                            "cmSampleOutput",
                            paste0("Ps_t", targetId, "_c", comparatorId, ".rds"))
    if (file.exists(psFileName)) {
      ps <- readRDS(psFileName)
      targetName <- exposureSummary$targetName[i]
      comparatorName <- exposureSummary$comparatorName[i]
      ps <- CohortMethod:::computePreferenceScore(ps)
      auc <- tibble::tibble(auc = CohortMethod::computePsAuc(ps),
                            equipoise = mean(
                              ps$preferenceScore >= preferenceScoreBounds[1] &
                                ps$preferenceScore <= preferenceScoreBounds[2]),
                            targetId = targetId,
                            targetName = targetName,
                            comparatorId = comparatorId,
                            comparatorName = comparatorName,
                            comparison = paste(targetName, comparatorName, sep = " vs. "))
      return(auc)
    }
    return(NULL)
  }

  data <- plyr::llply(1:nrow(exposureSummary),
                      getAuc,
                      exposureSummary = exposureSummary,
                      indicationFolder = indicationFolder,
                      .progress = "text")
  data <- do.call("rbind", data)
  data$databaseId <- databaseId
  data$indicationId <- indicationId
  names(data) <- SqlRender::camelCaseToSnakeCase(names(data))
  write.csv(data, file.path(assessmentExportFolder, "ps_auc_assessment.csv"), row.names = FALSE)

  zipName <- file.path(assessmentExportFolder,
                       sprintf("Results_%s_ps_%s.zip", indicationId, databaseId))
  files <- list.files(assessmentExportFolder, pattern = ".*\\.csv$")
  oldWd <- setwd(assessmentExportFolder)
  on.exit(setwd(oldWd))
  DatabaseConnector::createZipFile(zipFile = zipName, files = files)
  ParallelLogger::logInfo("Propensity score assessment results are ready for sharing at:", zipName)

  ParallelLogger::logInfo(sprintf("Finished assessPropensityModels() for LEGEND-T2DM %s-vs-%s studies",
                                  indicationId, indicationId))
}
