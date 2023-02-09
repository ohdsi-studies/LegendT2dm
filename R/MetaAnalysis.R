# Copyright 2023 Observational Health Data Sciences and Informatics
#
# This file is part of Legend-T2DM
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

#' Perform random-effects meta-analysis on CES results on data server
#'
#' @details
#' This function executes a meta-analysis across data source results.
#'
#' @param connectionDetails     DatabaseConnector details to public LEGEND-T2DM db server
#' @param resultsDatabaseSchema Schema on the postgres server where the tables have been created.
#' @param maExportFolder        A local folder where the meta-anlysis results will be written.
#' @param diagnosticsFilter     Table of which target-comparator-outcome-analysis-database tuples pass diagnostics;
#'                              can be NULL
#' @param maxCores              How many parallel cores should be used? If more cores are made available
#'                              this can speed up the analyses.
#' @param cacheFileName         Use (if exists) or cache database results in file
#'
#' @export
doMetaAnalysis <- function(connectionDetails,
                           indicationId = "class",
                           resultsDatabaseSchema,
                           maExportFolder,
                           maName = "Meta-analysis",
                           diagnosticsFilter = NULL,
                           maxCores,
                           cacheFileName = NULL) {

  if (!is.null(diagnosticsFilter)) {
    if (!(c("targetId", "comparatorId", "outcomeId", "analysisId",
            "databaseId", "pass") %in% names(diagnosticsFilter))) {
      stop("Improperly formatted diagnostics filter")
    }
  }

  if (!file.exists(maExportFolder)) {
    dir.create(maExportFolder, recursive = TRUE)
  }

  ParallelLogger::addDefaultFileLogger(file.path(maExportFolder, "metaAnalysisLog.txt"))

  ParallelLogger::logInfo("Performing meta-analysis for main effects")
  doMaEffectType(connectionDetails = connectionDetails,
                 resultsDatabaseSchema = resultsDatabaseSchema,
                 maExportFolder = maExportFolder,
                 maName = maName,
                 diagnosticsFilter = diagnosticsFilter,
                 maxCores = maxCores,
                 cacheFileName = cacheFileName)

  ParallelLogger::logInfo("Creating database and results_data_time tables")
  database <- data.frame(database_id = maName,
                         database_name = "Random-effects meta-analysis",
                         description = "Random-effects meta-analysis using the DerSimonian-Laird estimator.",
                         is_meta_analysis = 1)
  fileName <- file.path(maExportFolder, "database.csv")
  write.csv(database, fileName, row.names = FALSE)

  dateTime <- data.frame(
    indicationId = c(indicationId),
    databaseId = c(maName),
    dateTime = c(Sys.time()),
    packageVersion = packageVersion("LegendT2dm"))

  colnames(dateTime) <- SqlRender::camelCaseToSnakeCase(colnames(dateTime))
  fileName <- file.path(maExportFolder, "results_date_time.csv")
  write.csv(dateTime, fileName, row.names = FALSE)

  ParallelLogger::logInfo("Adding results to zip file")
  zipName <- paste0("Results_", indicationId, "_study_", maName, ".zip")
  files <- c("cohort_method_result.csv", "database.csv", "results_date_time.csv")
  oldWd <- setwd(maExportFolder)
  DatabaseConnector::createZipFile(zipFile = zipName, files = files)
  setwd(oldWd)
  ParallelLogger::logInfo("Results are ready for sharing at: ",
                          file.path(maExportFolder, zipName))
}

loadMainResults <- function(connectionDetails,
                            resultsDatabaseSchema,
                            cacheFileName) {

  if (!is.null(cacheFileName) && file.exists(cacheFileName)) {

    ParallelLogger::logInfo("Loading cached main results from ", cacheFileName)
    cohortMethodResult <- readRDS(cacheFileName)

  } else {

    ParallelLogger::logInfo("Loading main results from database for meta-analysis")

    connection <- DatabaseConnector::connect(connectionDetails)

    sql <- paste0("SET search_path TO ", resultsDatabaseSchema, ";")
    DatabaseConnector::executeSql(connection = connection, sql = sql)

    sql <- "SELECT * FROM cohort_method_result;"
    cohortMethodResult <- DatabaseConnector::querySql(connection, sql)
    colnames(cohortMethodResult) <- SqlRender::snakeCaseToCamelCase(colnames(cohortMethodResult))

    sql <- "SELECT DISTINCT outcome_id FROM negative_control_outcome;"
    ncs <- DatabaseConnector::querySql(connection, sql)
    colnames(ncs) <- SqlRender::snakeCaseToCamelCase(colnames(ncs))

    DatabaseConnector::disconnect(connection)

    cohortMethodResult$trueEffectSize <- NA
    idx <- cohortMethodResult$outcomeId %in% ncs$outcomeId
    cohortMethodResult$trueEffectSize[idx] <- 1

    if (!is.null(cacheFileName)) {
      ParallelLogger::logInfo("Caching main results into ", cacheFileName)
      saveRDS(cohortMethodResult, file = cacheFileName)
    }
  }

  return(cohortMethodResult)
}

doMaEffectType <- function(connectionDetails,
                           resultsDatabaseSchema,
                           maExportFolder,
                           maName,
                           maxCores,
                           diagnosticsFilter,
                           cacheFileName) {

  allResults <- loadMainResults(connectionDetails, resultsDatabaseSchema,
                                 cacheFileName)

  if (!is.null(diagnosticsFilter)) {
    blind <- allResults %>%
      left_join(diagnosticsFilter,
                by = c("targetId",
                       "comparatorId",
                       "analysisId",
                       "databaseId")) %>%
      filter("pass") %>% select(-"pass")
  }

  ncIds <- allResults %>% filter(trueEffectSize == 1) %>% pull(outcomeId) %>% unique()
  allResults$type[allResults$outcomeId %in% ncIds] <- "Negative control"
  allResults$type[is.na(allResults$type)] <- "Outcome of interest"

  groups <- split(allResults, paste(allResults$targetId, allResults$comparatorId, allResults$analysisId), drop = TRUE)
  cluster <- ParallelLogger::makeCluster(min(maxCores, 12))
  results <- ParallelLogger::clusterApply(cluster,
                                          groups,
                                          computeGroupMetaAnalysis,
                                          shinyDataFolder = NULL,
                                          allControls = NULL)
  ParallelLogger::stopCluster(cluster)
  results <- do.call(rbind, results)

  maName <- "Meta-analysis"
  results <- results %>% mutate(databaseId = maName) %>%
    select(-trueEffectSize,-type)
  colnames(results) <- SqlRender::camelCaseToSnakeCase(colnames(results))

  fileName <- file.path(maExportFolder, "cohort_method_result.csv")
  write.csv(results, fileName, row.names = FALSE, na = "")

}

computeGroupMetaAnalysis <- function(group,
                                     shinyDataFolder,
                                     allControls) {

  analysisId <- group$analysisId[1]
  targetId <- group$targetId[1]
  comparatorId <- group$comparatorId[1]
  ParallelLogger::logInfo("Performing meta-analysis for target ", targetId, ", comparator ", comparatorId, ", analysis ", analysisId)
  outcomeGroups <- split(group, group$outcomeId, drop = TRUE)
  outcomeGroupResults <- lapply(outcomeGroups, computeSingleMetaAnalysis)

  groupResults <- do.call(rbind, outcomeGroupResults)

  ncs <- groupResults[groupResults$type == "Negative control", ]
  ncs <- ncs[!is.na(ncs$seLogRr), ]
  if (nrow(ncs) > 5) {
    null <- EmpiricalCalibration::fitMcmcNull(ncs$logRr, ncs$seLogRr) # calibrate CIs without synthesizing positive controls, assumes error consistent across effect sizes
    model <- EmpiricalCalibration::convertNullToErrorModel(null)
    calibratedP <- EmpiricalCalibration::calibrateP(null = null,
                                                    logRr = groupResults$logRr,
                                                    seLogRr = groupResults$seLogRr)
    calibratedCi <- EmpiricalCalibration::calibrateConfidenceInterval(logRr = groupResults$logRr,
                                                                      seLogRr = groupResults$seLogRr,
                                                                      model = model)
    groupResults$calibratedP <- calibratedP$p
    groupResults$calibratedRr <- exp(calibratedCi$logRr)
    groupResults$calibratedCi95Lb <- exp(calibratedCi$logLb95Rr)
    groupResults$calibratedCi95Ub <- exp(calibratedCi$logUb95Rr)
    groupResults$calibratedLogRr <- calibratedCi$logRr
    groupResults$calibratedSeLogRr <- calibratedCi$seLogRr
  } else {
    groupResults$calibratedP <- rep(NA, nrow(groupResults))
    groupResults$calibratedRr <- rep(NA, nrow(groupResults))
    groupResults$calibratedCi95Lb <- rep(NA, nrow(groupResults))
    groupResults$calibratedCi95Ub <- rep(NA, nrow(groupResults))
    groupResults$calibratedLogRr <- rep(NA, nrow(groupResults))
    groupResults$calibratedSeLogRr <- rep(NA, nrow(groupResults))
  }
  return(groupResults)
}

computeSingleMetaAnalysis <- function(outcomeGroup) {

  maRow <- outcomeGroup[1, ]
  outcomeGroup <- outcomeGroup[!is.na(outcomeGroup$seLogRr), ] # drops rows with zero events in T or C

  if (nrow(outcomeGroup) == 0) {
    maRow$targetSubjects <- 0
    maRow$comparatorSubjects <- 0
    maRow$targetDays <- 0
    maRow$comparatorDays <- 0
    maRow$targetOutcomes <- 0
    maRow$comparatorOutcomes <- 0
    maRow$rr <- NA
    maRow$ci95Lb <- NA
    maRow$ci95Ub <- NA
    maRow$p <- NA
    maRow$logRr <- NA
    maRow$seLogRr <- NA
    maRow$i2 <- NA
  } else if (nrow(outcomeGroup) == 1) {
    maRow <- outcomeGroup[1, ]
    maRow$i2 <- 0
  } else {
    maRow$targetSubjects <- sumMinCellCount(outcomeGroup$targetSubjects)
    maRow$comparatorSubjects <- sumMinCellCount(outcomeGroup$comparatorSubjects)
    maRow$targetDays <- sum(outcomeGroup$targetDays)
    maRow$comparatorDays <- sum(outcomeGroup$comparatorDays)
    maRow$targetOutcomes <- sumMinCellCount(outcomeGroup$targetOutcomes)
    maRow$comparatorOutcomes <- sumMinCellCount(outcomeGroup$comparatorOutcomes)
    meta <- meta::metagen(outcomeGroup$logRr, outcomeGroup$seLogRr, sm = "RR", hakn = FALSE)
    s <- summary(meta)
    maRow$i2 <- s$I2$TE

    rnd <- s$random
    maRow$rr <- exp(rnd$TE)
    maRow$ci95Lb <- exp(rnd$lower)
    maRow$ci95Ub <- exp(rnd$upper)
    maRow$p <- rnd$p
    maRow$logRr <- rnd$TE
    maRow$seLogRr <- rnd$seTE
  }
  if (is.na(maRow$logRr)) {
    maRow$mdrr <- NA
  } else {
    alpha <- 0.05
    power <- 0.8
    z1MinAlpha <- qnorm(1 - alpha/2)
    zBeta <- -qnorm(1 - power)
    pA <- maRow$targetSubjects / (maRow$targetSubjects + maRow$comparatorSubjects)
    pB <- 1 - pA
    totalEvents <- abs(maRow$targetOutcomes) + abs(maRow$comparatorOutcomes)
    maRow$mdrr <- exp(sqrt((zBeta + z1MinAlpha)^2/(totalEvents * pA * pB)))
  }
  maRow$databaseId <- "Meta-analysis"
  maRow$sources <- paste(outcomeGroup$databaseId[order(outcomeGroup$databaseId)], collapse = ";")
  return(maRow)
}

sumMinCellCount <- function(counts) {
  total <- sum(abs(counts))
  if (any(counts < 0)) {
    total <- -total
  }
  return(total)
}
