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
#' @importFrom dplyr `%>%` pull select left_join rename
#'
#' @export
assessPhenotypes <- function(connectionDetails,
                             cdmDatabaseSchema,
                             cohortDatabaseSchema,
                             tablePrefix = "legend_t2dm",
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

  writePairedCounts <- function(indicationId) {
    tcos <- readr::read_csv(file = system.file("settings", paste0(indicationId, "TcosOfInterest.csv"),
                                               package = "LegendT2dm"))
    counts <- readr::read_csv(file = file.path(outputFolder, indicationId, "cohortCounts.csv")) %>% select(cohortDefinitionId, cohortCount)

    tmp <- tcos %>%
      left_join(counts, by = c("targetId" = "cohortDefinitionId")) %>% rename(targetPairedPersons = cohortCount) %>%
      left_join(counts, by = c("comparatorId" = "cohortDefinitionId")) %>% rename(comparatorPairedPersons = cohortCount)

    readr::write_csv(tmp, file = file.path(outputFolder, indicationId, "pairedExposureSummary.csv"))
  }

  if (createExposureCohorts) {
    # Exposures ----------------------------------------------------------------------------------------
    createExposureCohorts(connectionDetails = connectionDetails,
                          cdmDatabaseSchema = cdmDatabaseSchema,
                          cohortDatabaseSchema = cohortDatabaseSchema,
                          tablePrefix = tablePrefix,
                          indicationId = "class",
                          oracleTempSchema = oracleTempSchema,
                          outputFolder = outputFolder,
                          databaseId = databaseId,
                          filterExposureCohorts = filterExposureCohorts)
  }

  writePairedCounts("class")

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
    runExposureCohortDiagnostics(connectionDetails,
                                 cdmDatabaseSchema,
                                 cohortDatabaseSchema,
                                 tablePrefix = tablePrefix,
                                 indicationId = "class",
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
#' @param minCohortsSize         Minimum number of people that have to be in each cohort to keep a pair of
#'                               cohorts.
#' @param sampleSize             What is the maximum sample size for each exposure cohort?
#' @param maxCores               How many parallel cores should be used? If more cores are made
#'                               available this can speed up the analyses.
#' @param databaseId             A short string for identifying the database (e.g. 'Synpuf').
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
                                   databaseId) {

  originalCohortTable <- paste(tablePrefix, tolower(indicationId), "cohort", sep = "_")
  sampledCohortTable <- paste(tablePrefix, tolower(indicationId), "sample_cohort", sep = "_")

  indicationFolder <- file.path(outputFolder, indicationId)
  assessmentExportFolder <- file.path(indicationFolder, "assessmentOfPropensityScores")
  if (!file.exists(assessmentExportFolder)) {
    dir.create(assessmentExportFolder, recursive = TRUE)
  }
  ParallelLogger::addDefaultFileLogger(file.path(indicationFolder, "logAssesPropensityModels.txt"))

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
                                           study_cohort_table = cohortTable)
  connection <- DatabaseConnector::connect(connectionDetails)
  counts <- DatabaseConnector::querySql(connection, sql, snakeCaseToCamelCase = TRUE)
  DatabaseConnector::disconnect(connection)
  counts$databaseId <- databaseId
  #counts <- addCohortNames(counts)
  write.csv(counts, file.path(outputFolder, indicationId, "sampledCohortCounts.csv"), row.names = FALSE)


  filterByExposureCohortsSize(outputFolder = outputFolder, indicationId = indicationId, minCohortSize = minCohortSize)

  # fetchAllDataFromServer(connectionDetails = connectionDetails,
  #                        cdmDatabaseSchema = cdmDatabaseSchema,
  #                        oracleTempSchema = oracleTempSchema,
  #                        cohortDatabaseSchema = cohortDatabaseSchema,
  #                        tablePrefix = tablePrefix,
  #                        indicationId = indicationId,
  #                        outputFolder = outputFolder,
  #                        useSample = TRUE)

  # generateAllCohortMethodDataObjects(outputFolder = outputFolder,
  #                                    indicationId = indicationId,
  #                                    useSample = TRUE)
  #
  # ParallelLogger::logInfo("Fitting propensity models on sampled data")
  # fitPsModel <- function(i, exposureSummary, psCvThreads, indicationFolder) {
  #   targetId <- exposureSummary$targetId[i]
  #   comparatorId <- exposureSummary$comparatorId[i]
  #   folderName <- file.path(indicationFolder,
  #                           "cmSampleOutput",
  #                           paste0("CmData_l1_t", targetId, "_c", comparatorId))
  #   cmData <- CohortMethod::loadCohortMethodData(folderName)
  #   studyPop <- CohortMethod::createStudyPopulation(cohortMethodData = cmData,
  #                                                   removeDuplicateSubjects = "keep first",
  #                                                   minDaysAtRisk = 0)
  #   ps <- CohortMethod::createPs(cohortMethodData = cmData,
  #                                population = studyPop,
  #                                errorOnHighCorrelation = TRUE,
  #                                stopOnError = FALSE,
  #                                control = Cyclops::createControl(noiseLevel = "silent",
  #                                                                 cvType = "auto",
  #                                                                 tolerance = 2e-07,
  #                                                                 cvRepetitions = 1,
  #                                                                 startingVariance = 0.01,
  #                                                                 seed = 123,
  #                                                                 threads = psCvThreads))
  #   fileName <- file.path(indicationFolder,
  #                         "cmSampleOutput",
  #                         paste0("Ps_t", targetId, "_c", comparatorId, ".rds"))
  #   saveRDS(ps, fileName)
  #   return(NULL)
  # }
  # createPsThreads <- max(1, round(maxCores/10))
  # psCvThreads <- min(10, maxCores)
  # exposureSummary <- read.csv(file.path(indicationFolder,
  #                                       "pairedExposureSummaryFilteredBySize.csv"))
  # cluster <- ParallelLogger::makeCluster(createPsThreads)
  # ParallelLogger::clusterApply(cluster = cluster,
  #                              fun = fitPsModel,
  #                              x = 1:nrow(exposureSummary),
  #                              exposureSummary = exposureSummary,
  #                              psCvThreads = psCvThreads,
  #                              indicationFolder = indicationFolder)
  # ParallelLogger::stopCluster(cluster)
  #
  # ParallelLogger::logInfo("Fetching propensity models")
  # getModel <- function(i, exposureSummary, indicationFolder) {
  #   targetId <- exposureSummary$targetId[i]
  #   comparatorId <- exposureSummary$comparatorId[i]
  #   psFileName <- file.path(indicationFolder,
  #                           "cmSampleOutput",
  #                           paste0("Ps_t", targetId, "_c", comparatorId, ".rds"))
  #   if (file.exists(psFileName)) {
  #     ps <- readRDS(psFileName)
  #     metaData <- attr(ps, "metaData")
  #     if (is.null(metaData$psError)) {
  #       folderName <- file.path(indicationFolder,
  #                               "cmSampleOutput",
  #                               paste0("CmData_l1_t", targetId, "_c", comparatorId))
  #       cmData <- CohortMethod::loadCohortMethodData(folderName)
  #       model <- CohortMethod::getPsModel(ps, cmData)
  #       ff::close.ffdf(cmData$covariates)
  #       ff::close.ffdf(cmData$covariateRef)
  #       ff::close.ffdf(cmData$analysisRef)
  #       # Truncate to first 25 covariates:
  #       if (nrow(model) > 25) {
  #         model <- model[1:25, ]
  #       }
  #     } else if (!is.null(metaData$psHighCorrelation)) {
  #       model <- data.frame(coefficient = Inf,
  #                           covariateId = metaData$psHighCorrelation$covariateId,
  #                           covariateName = metaData$psHighCorrelation$covariateName)
  #     } else {
  #       model <- data.frame(coefficient = NA,
  #                           covariateId = NA,
  #                           covariateName = paste("Error:", metaData$psError))
  #     }
  #     targetName <- exposureSummary$targetName[i]
  #     comparatorName <- exposureSummary$comparatorName[i]
  #     model$targetId <- targetId
  #     model$targetName <- targetName
  #     model$comparatorId <- comparatorId
  #     model$comparatorName <- comparatorName
  #     model$comparison <- paste(targetName, comparatorName, sep = " vs. ")
  #     return(model)
  #   }
  #   return(NULL)
  # }
  #
  # data <- plyr::llply(1:nrow(exposureSummary),
  #                     getModel,
  #                     exposureSummary = exposureSummary,
  #                     indicationFolder = indicationFolder,
  #                     .progress = "text")
  # data <- do.call("rbind", data)
  # data$databaseId <- databaseId
  # data$indicationId <- indicationId
  # write.csv(data, file.path(assessmentExportFolder, "propensityModels.csv"), row.names = FALSE)
  #
  # ParallelLogger::logInfo("Computing AUCs")
  # getAuc <- function(i, exposureSummary, indicationFolder) {
  #   targetId <- exposureSummary$targetId[i]
  #   comparatorId <- exposureSummary$comparatorId[i]
  #   psFileName <- file.path(indicationFolder,
  #                           "cmSampleOutput",
  #                           paste0("Ps_t", targetId, "_c", comparatorId, ".rds"))
  #   if (file.exists(psFileName)) {
  #     ps <- readRDS(psFileName)
  #     targetName <- exposureSummary$targetName[i]
  #     comparatorName <- exposureSummary$comparatorName[i]
  #     auc <- data.frame(auc = CohortMethod::computePsAuc(ps),
  #                       targetId = targetId,
  #                       targetName = targetName,
  #                       comparatorId = comparatorId,
  #                       comparatorName = comparatorName,
  #                       comparison = paste(targetName, comparatorName, sep = " vs. "))
  #     return(auc)
  #   }
  #   return(NULL)
  # }
  #
  # data <- plyr::llply(1:nrow(exposureSummary),
  #                     getAuc,
  #                     exposureSummary = exposureSummary,
  #                     indicationFolder = indicationFolder,
  #                     .progress = "text")
  # data <- do.call("rbind", data)
  # data$databaseId <- databaseId
  # data$indicationId <- indicationId
  # write.csv(data, file.path(assessmentExportFolder, "aucs.csv"), row.names = FALSE)
  #
  # zipName <- file.path(assessmentExportFolder,
  #                      sprintf("PropensityModelAssessment%s%s.zip", indicationId, databaseId))
  # files <- list.files(assessmentExportFolder, pattern = ".*\\.csv$")
  # oldWd <- setwd(assessmentExportFolder)
  # on.exit(setwd(oldWd))
  # DatabaseConnector::createZipFile(zipFile = zipName, files = files)
  # ParallelLogger::logInfo("Results are ready for sharing at:", zipName)
}
