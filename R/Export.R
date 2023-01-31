# Copyright 2021 Observational Health Data Sciences and Informatics
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

#' Export all results to tables
#'
#' @description
#' Outputs all results to a folder called 'export', and zips them.
#'
#' @param indicationId          A string denoting the indicationId for which the results should be
#'                              exported.
#' @param outputFolder          Name of local folder to place results; make sure to use forward slashes
#'                              (/). Do not use a folder on a network drive since this greatly impacts
#'                              performance.
#' @param databaseId            A short string for identifying the database (e.g. 'Synpuf').
#' @param databaseName          The full name of the database.
#' @param databaseDescription   A short description (several sentences) of the database.
#' @param minCellCount          The minimum cell count for fields contains person counts or fractions.
#' @param runSections                          Run specific sections through CohortMethod
#' @param maxCores              How many parallel cores should be used? If more cores are made
#'                              available this can speed up the analyses.
#'
#' @export
exportResults <- function(indicationId = "class",
                          outputFolder,
                          databaseId,
                          databaseName,
                          databaseDescription,
                          runSections,
                          minCellCount = 5,
                          maxCores) {
    indicationFolder <- file.path(outputFolder, indicationId)
    exportFolder <- file.path(indicationFolder, "export")
    if (!file.exists(exportFolder)) {
        dir.create(exportFolder, recursive = TRUE)
    }

    exportAnalyses(indicationId = indicationId,
                   outputFolder = outputFolder,
                   exportFolder = exportFolder,
                   databaseId = databaseId,
                   runSections = runSections)

    exportExposures(indicationId = indicationId,
                    outputFolder = outputFolder,
                    exportFolder = exportFolder,
                    databaseId = databaseId)

    exportOutcomes(indicationId = indicationId,
                   outputFolder = outputFolder,
                   exportFolder = exportFolder,
                   databaseId = databaseId)

    exportMetadata(indicationId = indicationId,
                   outputFolder = outputFolder,
                   exportFolder = exportFolder,
                   databaseId = databaseId,
                   databaseName = databaseName,
                   databaseDescription = databaseDescription,
                   minCellCount = minCellCount)

    exportMainResults(indicationId = indicationId,
                      outputFolder = outputFolder,
                      exportFolder = exportFolder,
                      databaseId = databaseId,
                      minCellCount = minCellCount,
                      maxCores = maxCores)

    exportDiagnostics(indicationId = indicationId,
                      outputFolder = outputFolder,
                      exportFolder = exportFolder,
                      databaseId = databaseId,
                      minCellCount = minCellCount,
                      maxCores = maxCores)

    exportDateTime(indicationId = indicationId,
                   databaseId = databaseId,
                   exportFolder = exportFolder)

    # Add all to zip file -------------------------------------------------------------------------------
    ParallelLogger::logInfo("Adding results to zip file")
    zipName <- file.path(exportFolder, paste0("Results_", indicationId, "_study_", databaseId, ".zip"))
    files <- list.files(exportFolder, pattern = ".*\\.csv$")
    oldWd <- setwd(exportFolder)
    on.exit(setwd(oldWd))
    DatabaseConnector::createZipFile(zipFile = zipName, files = files)
    ParallelLogger::logInfo("Results are ready for sharing at:", zipName)
}

swapColumnContents <- function(df, column1 = "targetId", column2 = "comparatorId") {
    temp <- df[, column1]
    df[, column1] <- df[, column2]
    df[, column2] <- temp
    return(df)
}


# getAsymAnalysisIds <- function() {
#     cmAnalysisListFile <- system.file("settings",
#                                       sprintf("cmAnalysisListAsym%s.json", indicationId),
#                                       package = "Legend")
#     cmAnalysisListAsym <- CohortMethod::loadCmAnalysisList(cmAnalysisListFile)
#     analysisIds <- as.vector(unlist(ParallelLogger::selectFromList(cmAnalysisListAsym, "analysisId")))
#     return(analysisIds)
# }


enforceMinCellValue <- function(data, fieldName, minValues, silent = FALSE) {
    toCensor <- !is.na(data[, fieldName]) & data[, fieldName] < minValues & data[, fieldName] != 0
    if (!silent) {
        percent <- round(100 * sum(toCensor)/nrow(data), 1)
        ParallelLogger::logInfo("   censoring ",
                                sum(toCensor),
                                " values (",
                                percent,
                                "%) from ",
                                fieldName,
                                " because value below minimum")
    }
    if (length(minValues) == 1) {
        data[toCensor, fieldName] <- -minValues
    } else {
        data[toCensor, fieldName] <- -minValues[toCensor]
    }
    return(data)
}

# exportIndication <- function(indicationId, outputFolder, exportFolder, databaseId) {
#     ParallelLogger::logInfo("Exporting indication")
#     ParallelLogger::logInfo("- indication table")
#     pathToCsv <- system.file("settings", "Indications.csv", package = "LegendT2dm")
#     indications <- read.csv(pathToCsv)
#     indications$definition <- ""
#     indications <- indications[indications$indicationId == indicationId, ]
#     indicationTable <- indications[, c("indicationId", "indicationName", "definition")]
#     colnames(indicationTable) <- SqlRender::camelCaseToSnakeCase(colnames(indicationTable))
#     fileName <- file.path(exportFolder, "indication.csv")
#     write.csv(indicationTable, fileName, row.names = FALSE)
# }

exportAnalyses <- function(indicationId, outputFolder, exportFolder, databaseId, runSections) {
    ParallelLogger::logInfo("Exporting analyses")
    ParallelLogger::logInfo("- cohort_method_analysis table")

    tempFileName <- tempfile()

    loadList <- function(fileName, test = TRUE) {
      if (test) {
        CohortMethod::loadCmAnalysisList(system.file("settings",
                                                     fileName,
                                                     package = "LegendT2dm"))
      }
    }

    cmAnalysisToRow <- function(cmAnalysis) {
        ParallelLogger::saveSettingsToJson(cmAnalysis, tempFileName)
        row <- data.frame(analysisId = cmAnalysis$analysisId,
                          description = cmAnalysis$description,
                          definition = readChar(tempFileName, file.info(tempFileName)$size))
        return(row)
    }

    cmAnalysisList <- c(
      loadList("ittCmAnalysisList.json", 1 %in% runSections),
      loadList("ot1CmAnalysisList.json", 2 %in% runSections),
      loadList("ot2CmAnalysisList.json", 3 %in% runSections),
      loadList("ittPoCmAnalysisList.json", 4 %in% runSections),
      loadList("ot1PoCmAnalysisList.json", 5 %in% runSections),
      loadList("ot2PoCmAnalysisList.json", 6 %in% runSections)
    )

    cohortMethodAnalysis <- lapply(cmAnalysisList, cmAnalysisToRow)
    cohortMethodAnalysis <- do.call("rbind", cohortMethodAnalysis)
    cohortMethodAnalysis <- unique(cohortMethodAnalysis)
    unlink(tempFileName)
    colnames(cohortMethodAnalysis) <- SqlRender::camelCaseToSnakeCase(colnames(cohortMethodAnalysis))
    fileName <- file.path(exportFolder, "cohort_method_analysis.csv")
    write.csv(cohortMethodAnalysis, fileName, row.names = FALSE)

    ParallelLogger::logInfo("- covariate_analysis table")
    indicationFolder <- file.path(outputFolder, indicationId)
    reference <- readRDS(file.path(indicationFolder, "cmOutput", "outcomeModelReference.rds"))
    getCovariateAnalyses <- function(cmAnalysis) {
        cmDataFolder <- reference$cohortMethodDataFile[reference$analysisId == cmAnalysis$analysisId][1]
        cmData <- CohortMethod::loadCohortMethodData(file.path(indicationFolder, "cmOutput", cmDataFolder))
        covariateAnalysis <- collect(cmData$analysisRef)
        covariateAnalysis <- covariateAnalysis[, c("analysisId", "analysisName")]
        colnames(covariateAnalysis) <- c("covariate_analysis_id", "covariate_analysis_name")
        covariateAnalysis$analysis_id <- cmAnalysis$analysisId
        return(covariateAnalysis)
    }
    covariateAnalysis <- lapply(cmAnalysisList, getCovariateAnalyses)
    covariateAnalysis <- do.call("rbind", covariateAnalysis)
    fileName <- file.path(exportFolder, "covariate_analysis.csv")
    readr::write_csv(covariateAnalysis, fileName)

    # ParallelLogger::logInfo("- incidence_analysis table")
    # incidenceAnalysis <- data.frame(incidence_analysis_id = c("On-treatment", "Intent-to-treat"),
    #                                 description = c("On-treatment", "Intent-to-treat"))
    # fileName <- file.path(exportFolder, "incidence_analysis.csv")
    # write.csv(incidenceAnalysis, fileName, row.names = FALSE)
}

exportExposures <- function(indicationId, outputFolder, exportFolder, databaseId) {
    ParallelLogger::logInfo("Exporting exposures")
    ParallelLogger::logInfo("- exposure_of_interest table")

    pathToCsv <- system.file("settings", paste0(indicationId, "TcosOfInterest.csv"), package = "LegendT2dm")
    tcosOfInterest <- read.csv(pathToCsv, stringsAsFactors = FALSE)

    pathToCsv <- system.file("settings", paste0(indicationId, "CohortsToCreate.csv"), package = "LegendT2dm")
    cohortsToCreate <- read.csv(pathToCsv)

    createExposureRow <- function(exposureId) {
        atlasName <- as.character(cohortsToCreate$atlasName[cohortsToCreate$cohortId == exposureId])
        name <- as.character(cohortsToCreate$name[cohortsToCreate$cohortId == exposureId])
        cohortFileName <- system.file("cohorts", paste0(name, ".json"), package = "LegendT2dm")
        definition <- readChar(cohortFileName, file.info(cohortFileName)$size)
        return(tibble::tibble(exposureId = exposureId,
                              exposureName = atlasName,
                              definition = definition))
    }
    exposuresOfInterest <- unique(c(tcosOfInterest$targetId, tcosOfInterest$comparatorId))
    exposureOfInterest <- lapply(exposuresOfInterest, createExposureRow)
    exposureOfInterest <- do.call("rbind", exposureOfInterest)
    colnames(exposureOfInterest) <- SqlRender::camelCaseToSnakeCase(colnames(exposureOfInterest))
    fileName <- file.path(exportFolder, "exposure_of_interest.csv")
    readr::write_csv(exposureOfInterest, fileName)
}

exportOutcomes <- function(indicationId, outputFolder, exportFolder, databaseId) {
    ParallelLogger::logInfo("Exporting outcomes")
    ParallelLogger::logInfo("- outcome_of_interest table")
    pathToCsv <- system.file("settings", "OutcomesOfInterest.csv", package = "LegendT2dm")
    outcomesOfInterest <- read.csv(pathToCsv, stringsAsFactors = FALSE)

    getDefinition <- function(name) {
        fileName <- system.file("cohorts", paste0(name, ".json"), package = "LegendT2dm")
        return(readChar(fileName, file.info(fileName)$size))
    }
    outcomesOfInterest$definition <- sapply(outcomesOfInterest$name, getDefinition)
    outcomesOfInterest$description <- ""
    outcomesOfInterest <- outcomesOfInterest[, c("cohortId",
                                                 "name",
                                                 "definition",
                                                 "description")]
    colnames(outcomesOfInterest) <- c("outcome_id",
                                      "outcome_name",
                                      "definition",
                                      "description")
    fileName <- file.path(exportFolder, "outcome_of_interest.csv")
    write.csv(outcomesOfInterest, fileName, row.names = FALSE)

    ParallelLogger::logInfo("- negative_control_outcome table")
    pathToCsv <- system.file("settings", "NegativeControls.csv", package = "LegendT2dm")
    negativeControls <- read.csv(pathToCsv)

    negativeControls <- negativeControls[, c("cohortId", "name", "conceptId")]
    colnames(negativeControls) <- c("outcome_id", "outcome_name", "concept_id")
    fileName <- file.path(exportFolder, "negative_control_outcome.csv")
    write.csv(negativeControls, fileName, row.names = FALSE)
    colnames(negativeControls) <- SqlRender::snakeCaseToCamelCase(colnames(negativeControls))  # Need this later

    # TODO

    # ParallelLogger::logInfo("- positive_control_outcome table")
    # pathToCsv <- file.path(outputFolder, indicationId, "signalInjectionSummary.csv")
    # positiveControls <- read.csv(pathToCsv, stringsAsFactors = FALSE)
    # positiveControls$indicationId <- indicationId
    # positiveControls <- merge(positiveControls,
    #                           negativeControls[negativeControls$indicationId == indicationId,
    #                                            c("outcomeId", "outcomeName")])
    # positiveControls$outcomeName <- paste0(positiveControls$outcomeName,
    #                                        ", RR = ",
    #                                        positiveControls$targetEffectSize)
    # positiveControls <- positiveControls[, c("newOutcomeId",
    #                                          "outcomeName",
    #                                          "exposureId",
    #                                          "outcomeId",
    #                                          "targetEffectSize",
    #                                          "indicationId")]
    # colnames(positiveControls) <- c("outcomeId",
    #                                 "outcomeName",
    #                                 "exposureId",
    #                                 "negativeControlId",
    #                                 "effectSize",
    #                                 "indication_id")
    # colnames(positiveControls) <- SqlRender::camelCaseToSnakeCase(colnames(positiveControls))
    # fileName <- file.path(exportFolder, "positive_control_outcome.csv")
    # write.csv(positiveControls, fileName, row.names = FALSE)
}

exportMetadata <- function(indicationId,
                           outputFolder,
                           exportFolder,
                           databaseId,
                           databaseName,
                           databaseDescription,
                           minCellCount) {
    ParallelLogger::logInfo("Exporting metadata")

    indicationFolder <- file.path(outputFolder, indicationId)

    getInfo <- function(row) {
        cmData <- CohortMethod::loadCohortMethodData(file.path(indicationFolder, "cmOutput", row$cohortMethodDataFile))
        info <- cmData$cohorts %>%
            group_by(.data$treatment) %>%
            summarise(minDate = min(.data$cohortStartDate, na.rm = TRUE),
                      maxDate = max(.data$cohortStartDate, na.rm = TRUE)) %>%
            ungroup() %>%
            collect()

        info <- tibble::tibble(targetId = row$targetId,
                               comparatorId = row$comparatorId,
                               targetMinDate = info$minDate[info$treatment == 1],
                               targetMaxDate = info$maxDate[info$treatment == 1],
                               comparatorMinDate = info$minDate[info$treatment == 0],
                               comparatorMaxDate = info$maxDate[info$treatment == 0])
        info$comparisonMinDate <- min(info$targetMinDate, info$comparatorMinDate)
        info$comparisonMaxDate <- min(info$targetMaxDate, info$comparatorMaxDate)
        return(info)
    }
    reference <- readRDS(file.path(indicationFolder, "cmOutput", "outcomeModelReference.rds"))
    reference <- unique(reference[, c("targetId", "comparatorId", "cohortMethodDataFile")])
    reference <- split(reference, reference$cohortMethodDataFile)
    info <- lapply(reference, getInfo)
    info <- bind_rows(info)

    ParallelLogger::logInfo("- database table")
    database <- tibble::tibble(database_id = databaseId,
                               database_name = databaseName,
                               description = databaseDescription,
                               is_meta_analysis = 0)
    fileName <- file.path(exportFolder, "database.csv")
    readr::write_csv(database, fileName)

    ParallelLogger::logInfo("- exposure_summary table")
    minDates <- rbind(tibble::tibble(exposureId = info$targetId,
                                     minDate = info$targetMinDate),
                      tibble::tibble(exposureId = info$comparatorId,
                                     minDate = info$comparatorMinDate))
    minDates <- aggregate(minDate ~ exposureId, minDates, min)
    maxDates <- rbind(tibble::tibble(exposureId = info$targetId,
                                     maxDate = info$targetMaxDate),
                      tibble::tibble(exposureId = info$comparatorId,
                                     maxDate = info$comparatorMaxDate))
    maxDates <- aggregate(maxDate ~ exposureId, maxDates, max)
    exposureSummary <- merge(minDates, maxDates)
    exposureSummary$databaseId <- databaseId
    colnames(exposureSummary) <- SqlRender::camelCaseToSnakeCase(colnames(exposureSummary))
    fileName <- file.path(exportFolder, "exposure_summary.csv")
    readr::write_csv(exposureSummary, fileName)

    ParallelLogger::logInfo("- comparison_summary table")
    minDates <- aggregate(comparisonMinDate ~ targetId + comparatorId, info, min)
    maxDates <- aggregate(comparisonMaxDate ~ targetId + comparatorId, info, max)
    comparisonSummary <- merge(minDates, maxDates)
    comparisonSummary$databaseId <- databaseId
    colnames(comparisonSummary)[colnames(comparisonSummary) == "comparisonMinDate"] <- "minDate"
    colnames(comparisonSummary)[colnames(comparisonSummary) == "comparisonMaxDate"] <- "maxDate"
    colnames(comparisonSummary) <- SqlRender::camelCaseToSnakeCase(colnames(comparisonSummary))
    fileName <- file.path(exportFolder, "comparison_summary.csv")
    readr::write_csv(comparisonSummary, fileName)

    ParallelLogger::logInfo("- attrition table")
    fileName <- file.path(exportFolder, "attrition.csv")
    if (file.exists(fileName)) {
        unlink(fileName)
    }
    outcomesOfInterest <- getOutcomesOfInterest(indicationId)
    reference <- readRDS(file.path(indicationFolder, "cmOutput", "outcomeModelReference.rds"))
    reference <- reference[reference$outcomeId %in% outcomesOfInterest, ]
    first <- !file.exists(fileName)
    pb <- txtProgressBar(style = 3)
    for (i in 1:nrow(reference)) {
        outcomeModel <- readRDS(file.path(indicationFolder,
                                          "cmOutput",
                                          reference$outcomeModelFile[i]))
        attrition <- outcomeModel$attrition[, c("description", "targetPersons", "comparatorPersons")]
        attrition$sequenceNumber <- 1:nrow(attrition)
        attrition1 <- attrition[, c("sequenceNumber", "description", "targetPersons")]
        colnames(attrition1)[3] <- "subjects"
        attrition1$exposureId <- reference$targetId[i]
        attrition2 <- attrition[, c("sequenceNumber", "description", "comparatorPersons")]
        colnames(attrition2)[3] <- "subjects"
        attrition2$exposureId <- reference$comparatorId[i]
        attrition <- rbind(attrition1, attrition2)
        attrition$targetId <- reference$targetId[i]
        attrition$comparatorId <- reference$comparatorId[i]
        attrition$analysisId <- reference$analysisId[i]
        attrition$outcomeId <- reference$outcomeId[i]
        attrition$databaseId <- databaseId
        attrition <- attrition[, c("databaseId",
                                   "exposureId",
                                   "targetId",
                                   "comparatorId",
                                   "outcomeId",
                                   "analysisId",
                                   "sequenceNumber",
                                   "description",
                                   "subjects")]
        attrition <- enforceMinCellValue(attrition, "subjects", minCellCount, silent = TRUE)

        colnames(attrition) <- SqlRender::camelCaseToSnakeCase(colnames(attrition))
        write.table(x = attrition,
                    file = fileName,
                    row.names = FALSE,
                    col.names = first,
                    sep = ",",
                    dec = ".",
                    qmethod = "double",
                    append = !first)
        first <- FALSE
        if (i %% 100 == 10) {
            setTxtProgressBar(pb, i/nrow(reference))
        }
    }
    setTxtProgressBar(pb, 1)
    close(pb)

    ParallelLogger::logInfo("- covariate table")
    reference <- readRDS(file.path(indicationFolder, "cmOutput", "outcomeModelReference.rds"))
    getCovariates <- function(analysisId) {
        cmDataFolder <- reference$cohortMethodDataFile[reference$analysisId==analysisId][1]
        cmData <- CohortMethod::loadCohortMethodData(file.path(indicationFolder, "cmOutput", cmDataFolder))
        covariateRef <- collect(cmData$covariateRef)
        covariateRef <- covariateRef[, c("covariateId", "covariateName", "analysisId")]
        colnames(covariateRef) <- c("covariateId", "covariateName", "covariateAnalysisId")
        covariateRef$analysisId <- analysisId
        return(covariateRef)
    }
    covariates <- lapply(unique(reference$analysisId), getCovariates)
    covariates <- do.call("rbind", covariates)
    covariates$databaseId <- databaseId
    colnames(covariates) <- SqlRender::camelCaseToSnakeCase(colnames(covariates))
    fileName <- file.path(exportFolder, "covariate.csv")
    readr::write_csv(covariates, fileName)
    rm(covariates)  # Free up memory


    ParallelLogger::logInfo("- cm_follow_up_dist table")
    getResult <- function(i) {
        if (reference$strataFile[i] == "") {
            strataPop <- readRDS(file.path(indicationFolder,
                                           "cmOutput",
                                           reference$studyPopFile[i]))
        } else {
            strataPop <- readRDS(file.path(indicationFolder,
                                           "cmOutput",
                                           reference$strataFile[i]))
        }

        targetDist <- quantile(strataPop$survivalTime[strataPop$treatment == 1],
                               c(0, 0.1, 0.25, 0.5, 0.85, 0.9, 1))
        comparatorDist <- quantile(strataPop$survivalTime[strataPop$treatment == 0],
                                   c(0, 0.1, 0.25, 0.5, 0.85, 0.9, 1))

        numZeroTarget <- sum(strataPop$survivalTime[strataPop$treatment == 1] == 0)
        numZeroComparator <- sum(strataPop$survivalTime[strataPop$treatment == 0] == 0)

        row <- tibble::tibble(target_id = reference$targetId[i],
                              comparator_id = reference$comparatorId[i],
                              outcome_id = reference$outcomeId[i],
                              analysis_id = reference$analysisId[i],
                              target_min_days = targetDist[1],
                              target_p10_days = targetDist[2],
                              target_p25_days = targetDist[3],
                              target_median_days = targetDist[4],
                              target_p75_days = targetDist[5],
                              target_p90_days = targetDist[6],
                              target_max_days = targetDist[7],
                              target_zero_days = numZeroTarget,
                              comparator_min_days = comparatorDist[1],
                              comparator_p10_days = comparatorDist[2],
                              comparator_p25_days = comparatorDist[3],
                              comparator_median_days = comparatorDist[4],
                              comparator_p75_days = comparatorDist[5],
                              comparator_p90_days = comparatorDist[6],
                              comparator_max_days = comparatorDist[7],
                              comparator_zero_days = numZeroComparator)
        return(row)
    }
    outcomesOfInterest <- getOutcomesOfInterest(indicationId)
    reference <- readRDS(file.path(indicationFolder, "cmOutput", "outcomeModelReference.rds"))
    reference <- reference[reference$outcomeId %in% outcomesOfInterest, ]
    results <- plyr::llply(1:nrow(reference), getResult, .progress = "text")
    results <- do.call("rbind", results)
    results$database_id <- databaseId
    fileName <- file.path(exportFolder, "cm_follow_up_dist.csv")
    readr::write_csv(results, fileName)
    rm(results)  # Free up memory
}

exportMainResults <- function(indicationId,
                              outputFolder,
                              exportFolder,
                              databaseId,
                              minCellCount,
                              maxCores) {
    ParallelLogger::logInfo("Exporting main results")

    indicationFolder <- file.path(outputFolder, indicationId)

    ParallelLogger::logInfo("- cohort_method_result table")
    analysesSum <- readr::read_csv(file.path(indicationFolder, "analysisSummary.csv"), col_types = readr::cols())
    allControls <- getAllControls(indicationId, outputFolder)
    ParallelLogger::logInfo("  Performing empirical calibration on main effects")
    cluster <- ParallelLogger::makeCluster(min(4, maxCores))
    subsets <- split(analysesSum,
                     paste(analysesSum$targetId, analysesSum$comparatorId, analysesSum$analysisId))
    rm(analysesSum)  # Free up memory
    results <- ParallelLogger::clusterApply(cluster,
                                            subsets,
                                            calibrate,
                                            allControls = allControls)
    ParallelLogger::stopCluster(cluster)
    rm(subsets)  # Free up memory
    results <- do.call("rbind", results)
    results$databaseId <- databaseId
    results <- enforceMinCellValue(results, "targetSubjects", minCellCount)
    results <- enforceMinCellValue(results, "comparatorSubjects", minCellCount)
    results <- enforceMinCellValue(results, "targetOutcomes", minCellCount)
    results <- enforceMinCellValue(results, "comparatorOutcomes", minCellCount)
    colnames(results) <- SqlRender::camelCaseToSnakeCase(colnames(results))
    fileName <- file.path(exportFolder, "cohort_method_result.csv")
    readr::write_csv(results, fileName)
    rm(results)  # Free up memory

    ParallelLogger::logInfo("- likelihood_profile table")
    reference <- readRDS(file.path(indicationFolder, "cmOutput", "outcomeModelReference.rds"))
    fileName <- file.path(exportFolder, "likelihood_profile.csv")
    if (file.exists(fileName)) {
        unlink(fileName)
    }
    first <- TRUE
    pb <- txtProgressBar(style = 3)
    for (i in 1:nrow(reference)) {
        if (reference$outcomeModelFile[i] != "") {
            outcomeModel <- readRDS(file.path(indicationFolder, "cmOutput", reference$outcomeModelFile[i]))
            profile <- outcomeModel$logLikelihoodProfile
            if (!is.null(profile)) {
                profile <- data.frame(targetId = reference$targetId[i],
                                      comparatorId = reference$comparatorId[i],
                                      outcomeId = reference$outcomeId[i],
                                      analysisId = reference$analysisId[i],
                                      point = paste0(names(profile), collapse = ";"),
                                      value = paste0(profile, collapse = ";"),
                                      databaseId = databaseId)
                colnames(profile) <- SqlRender::camelCaseToSnakeCase(colnames(profile))
                write.table(x = profile,
                            file = fileName,
                            row.names = FALSE,
                            col.names = first,
                            sep = ",",
                            dec = ".",
                            qmethod = "double",
                            append = !first)
                first <- FALSE
            }
        }
        setTxtProgressBar(pb, i/nrow(reference))
    }
    close(pb)

    ParallelLogger::logInfo("- cm_interaction_result table")
    reference <- readRDS(file.path(indicationFolder, "cmOutput", "outcomeModelReference.rds"))
    loadInteractionsFromOutcomeModel <- function(i) {
        outcomeModel <- readRDS(file.path(indicationFolder,
                                          "cmOutput",
                                          reference$outcomeModelFile[i]))
        if ("subgroupCounts" %in% names(outcomeModel)) {
            rows <- tibble::tibble(targetId = reference$targetId[i],
                                   comparatorId = reference$comparatorId[i],
                                   outcomeId = reference$outcomeId[i],
                                   analysisId = reference$analysisId[i],
                                   interactionCovariateId = outcomeModel$subgroupCounts$subgroupCovariateId,
                                   rrr = NA,
                                   ci95Lb = NA,
                                   ci95Ub = NA,
                                   p = NA,
                                   i2 = NA,
                                   logRrr = NA,
                                   seLogRrr = NA,
                                   targetSubjects = outcomeModel$subgroupCounts$targetPersons,
                                   comparatorSubjects = outcomeModel$subgroupCounts$comparatorPersons,
                                   targetDays = outcomeModel$subgroupCounts$targetDays,
                                   comparatorDays = outcomeModel$subgroupCounts$comparatorDays,
                                   targetOutcomes = outcomeModel$subgroupCounts$targetOutcomes,
                                   comparatorOutcomes = outcomeModel$subgroupCounts$comparatorOutcomes)
            if ("outcomeModelInteractionEstimates" %in% names(outcomeModel)) {
                idx <- match(outcomeModel$outcomeModelInteractionEstimates$covariateId,
                             rows$interactionCovariateId)
                rows$rrr[idx] <- exp(outcomeModel$outcomeModelInteractionEstimates$logRr)
                rows$ci95Lb[idx] <- exp(outcomeModel$outcomeModelInteractionEstimates$logLb95)
                rows$ci95Ub[idx] <- exp(outcomeModel$outcomeModelInteractionEstimates$logUb95)
                rows$logRrr[idx] <- outcomeModel$outcomeModelInteractionEstimates$logRr
                rows$seLogRrr[idx] <- outcomeModel$outcomeModelInteractionEstimates$seLogRr
                z <- rows$logRrr[idx]/rows$seLogRrr[idx]
                rows$p[idx] <- 2 * pmin(pnorm(z), 1 - pnorm(z))
            }
            return(rows)
        } else {
            return(NULL)
        }

    }
    interactions <- plyr::llply(1:nrow(reference),
                                loadInteractionsFromOutcomeModel,
                                .progress = "text")
    interactions <- bind_rows(interactions)
    if (nrow(interactions) > 0) {
        ParallelLogger::logInfo("  Performing empirical calibration on interaction effects")
        allControls <- getAllControls(indicationId, outputFolder)
        negativeControls <- allControls[allControls$targetEffectSize == 1, ]
        cluster <- ParallelLogger::makeCluster(min(4, maxCores))
        subsets <- split(interactions,
                         paste(interactions$targetId, interactions$comparatorId, interactions$analysisId))
        interactions <- ParallelLogger::clusterApply(cluster,
                                                     subsets,
                                                     calibrateInteractions,
                                                     negativeControls = negativeControls)
        ParallelLogger::stopCluster(cluster)
        rm(subsets)  # Free up memory
        interactions <- bind_rows(interactions)
        interactions$databaseId <- databaseId

        interactions <- enforceMinCellValue(interactions, "targetSubjects", minCellCount)
        interactions <- enforceMinCellValue(interactions, "comparatorSubjects", minCellCount)
        interactions <- enforceMinCellValue(interactions, "targetOutcomes", minCellCount)
        interactions <- enforceMinCellValue(interactions, "comparatorOutcomes", minCellCount)
        colnames(interactions) <- SqlRender::camelCaseToSnakeCase(colnames(interactions))
        fileName <- file.path(exportFolder, "cm_interaction_result.csv")
        readr::write_csv(interactions, fileName)
        rm(interactions)  # Free up memory
    }
}

calibrate <- function(subset, allControls) {
    ncs <- subset[subset$outcomeId %in% allControls$cohortId[allControls$targetEffectSize == 1], ]
    ncs <- ncs[!is.na(ncs$seLogRr), ]
    if (nrow(ncs) > 5) {
        set.seed(123)
        null <- EmpiricalCalibration::fitMcmcNull(ncs$logRr, ncs$seLogRr)
        calibratedP <- EmpiricalCalibration::calibrateP(null = null,
                                                        logRr = subset$logRr,
                                                        seLogRr = subset$seLogRr)

        # Update from LEGEND-HTN.  Now calibrating effect and CI based on negative-control distribution
        model <- EmpiricalCalibration::convertNullToErrorModel(null)
        calibratedCi <- EmpiricalCalibration::calibrateConfidenceInterval(logRr = subset$logRr,
                                                                          seLogRr = subset$seLogRr,
                                                                          model = model,
                                                                          ciWidth = 0.95)
        subset$calibratedP <- calibratedP$p
        subset$calibratedLogRr <- calibratedCi$logRr
        subset$calibratedSeLogRr <- calibratedCi$seLogRr
        subset$calibratedCi95Lb <- exp(calibratedCi$logLb95Rr)
        subset$calibratedCi95Ub <- exp(calibratedCi$logUb95Rr)
        subset$calibratedRr <- exp(calibratedCi$logRr)
    } else {
        subset$calibratedP <- rep(NA, nrow(subset))
        subset$calibratedRr <- rep(NA, nrow(subset))
        subset$calibratedCi95Lb <- rep(NA, nrow(subset))
        subset$calibratedCi95Ub <- rep(NA, nrow(subset))
        subset$calibratedLogRr <- rep(NA, nrow(subset))
        subset$calibratedSeLogRr <- rep(NA, nrow(subset))
    }

    subset$i2 <- rep(NA, nrow(subset))
    subset <- subset[, c("targetId",
                         "comparatorId",
                         "outcomeId",
                         "analysisId",
                         "rr",
                         "ci95lb",
                         "ci95ub",
                         "p",
                         "i2",
                         "logRr",
                         "seLogRr",
                         "target",
                         "comparator",
                         "targetDays",
                         "comparatorDays",
                         "eventsTarget",
                         "eventsComparator",
                         "calibratedP",
                         "calibratedRr",
                         "calibratedCi95Lb",
                         "calibratedCi95Ub",
                         "calibratedLogRr",
                         "calibratedSeLogRr")]
    colnames(subset) <- c("targetId",
                          "comparatorId",
                          "outcomeId",
                          "analysisId",
                          "rr",
                          "ci95Lb",
                          "ci95Ub",
                          "p",
                          "i2",
                          "logRr",
                          "seLogRr",
                          "targetSubjects",
                          "comparatorSubjects",
                          "targetDays",
                          "comparatorDays",
                          "targetOutcomes",
                          "comparatorOutcomes",
                          "calibratedP",
                          "calibratedRr",
                          "calibratedCi95Lb",
                          "calibratedCi95Ub",
                          "calibratedLogRr",
                          "calibratedSeLogRr")
    return(subset)
}

calibrateInteractions <- function(subset, negativeControls) {
    ncs <- subset[subset$outcomeId %in% negativeControls$outcomeId, ]
    ncs <- ncs[!is.na(pull(ncs, .data$seLogRrr)), ]
    if (nrow(ncs) > 5) {
        set.seed(123)
        null <- EmpiricalCalibration::fitMcmcNull(ncs$logRrr, ncs$seLogRrr)
        calibratedP <- EmpiricalCalibration::calibrateP(null = null,
                                                        logRr = subset$logRrr,
                                                        seLogRr = subset$seLogRrr)
        subset$calibratedP <- calibratedP$p
    } else {
        subset$calibratedP <- rep(NA, nrow(subset))
    }
    return(subset)
}

exportDateTime <- function(indicationId,
                           databaseId,
                           exportFolder) {
    ParallelLogger::logInfo("Exporting results date/time")
    ParallelLogger::logInfo("- results_date_time table")
    fileName <- file.path(exportFolder, "results_date_time.csv")
    if (file.exists(fileName)) {
        unlink(fileName)
    }
    dateTime <- data.frame(
        indicationId = c(indicationId),
        databaseId = c(databaseId),
        dateTime = c(Sys.time()),
        packageVersion = packageVersion("LegendT2dm"))

    colnames(dateTime) <- SqlRender::camelCaseToSnakeCase(colnames(dateTime))
    write.table(x = dateTime,
                file = fileName,
                row.names = FALSE,
                sep = ",",
                dec = ".",
                qmethod = "double")
}


exportDiagnostics <- function(indicationId,
                              outputFolder,
                              exportFolder,
                              databaseId,
                              minCellCount,
                              maxCores) {
    ParallelLogger::logInfo("Exporting diagnostics")
    ParallelLogger::logInfo("- covariate_balance table")
    fileName <- file.path(exportFolder, "covariate_balance.csv")
    if (file.exists(fileName)) {
        unlink(fileName)
    }
    first <- TRUE
    balanceFolder <- file.path(outputFolder, indicationId, "balance")
    files <- list.files(balanceFolder, pattern = "bal_.*.rds", full.names = TRUE)
    pb <- txtProgressBar(style = 3)

    if (length(files) > 0) {

    for (i in 1:length(files)) {
        ids <- gsub("^.*bal_t", "", files[i])
        targetId <- as.numeric(gsub("_c.*", "", ids))
        ids <- gsub("^.*_c", "", ids)
        comparatorId <- as.numeric(gsub("_[aso].*$", "", ids))
        if (grepl("_s", ids)) {
            subgroupId <- as.numeric(gsub("^.*_s", "", gsub("_a[0-9]*.rds", "", ids)))
        } else {
            subgroupId <- NA
        }
        if (grepl("_o", ids)) {
            outcomeId <- as.numeric(gsub("^.*_o", "", gsub("_a[0-9]*.rds", "", ids)))
        } else {
            outcomeId <- NA
        }
        ids <- gsub("^.*_a", "", ids)
        analysisId <- as.numeric(gsub(".rds", "", ids))
        balance <- readRDS(files[i])
        inferredTargetBeforeSize <- mean(balance$beforeMatchingSumTarget/balance$beforeMatchingMeanTarget,
                                         na.rm = TRUE)
        inferredComparatorBeforeSize <- mean(balance$beforeMatchingSumComparator/balance$beforeMatchingMeanComparator,
                                             na.rm = TRUE)
        inferredTargetAfterSize <- mean(balance$afterMatchingSumTarget/balance$afterMatchingMeanTarget,
                                        na.rm = TRUE)
        inferredComparatorAfterSize <- mean(balance$afterMatchingSumComparator/balance$afterMatchingMeanComparator,
                                            na.rm = TRUE)

        balance$databaseId <- databaseId
        balance$targetId <- targetId
        balance$comparatorId <- comparatorId
        balance$outcomeId <- outcomeId
        balance$analysisId <- analysisId
        balance$interactionCovariateId <- subgroupId
        balance <- balance[, c("databaseId",
                               "targetId",
                               "comparatorId",
                               "outcomeId",
                               "analysisId",
                               "interactionCovariateId",
                               "covariateId",
                               "beforeMatchingMeanTarget",
                               "beforeMatchingMeanComparator",
                               "beforeMatchingStdDiff",
                               "afterMatchingMeanTarget",
                               "afterMatchingMeanComparator",
                               "afterMatchingStdDiff",
                               "beforeMatchingSumTarget",
                               "beforeMatchingSumComparator",
                               "afterMatchingSumTarget",
                               "afterMatchingSumComparator")]
        colnames(balance) <- c("databaseId",
                               "targetId",
                               "comparatorId",
                               "outcomeId",
                               "analysisId",
                               "interactionCovariateId",
                               "covariateId",
                               "targetMeanBefore",
                               "comparatorMeanBefore",
                               "stdDiffBefore",
                               "targetMeanAfter",
                               "comparatorMeanAfter",
                               "stdDiffAfter",
                               "targetSumBefore",
                               "comparatorSumBefore",
                               "targetSumAfter",
                               "comparatorSumAfter")
        balance$targetMeanBefore[is.na(balance$targetMeanBefore)] <- 0
        balance$comparatorMeanBefore[is.na(balance$comparatorMeanBefore)] <- 0
        balance$stdDiffBefore <- round(balance$stdDiffBefore, 3)
        balance$targetMeanAfter[is.na(balance$targetMeanAfter)] <- 0
        balance$comparatorMeanAfter[is.na(balance$comparatorMeanAfter)] <- 0
        balance$stdDiffAfter <- round(balance$stdDiffAfter, 3)

        # balance$targetSizeBefore <- inferredTargetBeforeSize
        # balance$targetSizeBefore[is.na(inferredTargetBeforeSize)] <- 0
        #
        # balance$comparatorSizeBefore <- inferredComparatorBeforeSize
        # balance$comparatorSizeBefore[is.na(inferredComparatorBeforeSize)] <- 0
        #
        # balance$targetSizeAfter <- inferredTargetAfterSize
        # balance$targetSizeAfter[is.na(inferredTargetAfterSize)] <- 0
        #
        # balance$comparatorSizeAfter <- inferredComparatorAfterSize
        # balance$comparatorSizeAfter[is.na(inferredComparatorAfterSize)] <- 0


        balance$targetSumBefore[is.na(balance$targetSumBefore)] <- 0
        balance$comparatorSumBefore[is.na(balance$comparatorSumBefore)] <- 0
        balance$targetSumAfter[is.na(balance$targetSumAfter)] <- 0
        balance$comparatorSumAfter[is.na(balance$comparatorSumAfter)] <- 0

        balance <- enforceMinCellValue(balance,
                                       "targetMeanBefore",
                                       minCellCount/inferredTargetBeforeSize,
                                       TRUE)
        balance <- enforceMinCellValue(balance,
                                       "comparatorMeanBefore",
                                       minCellCount/inferredComparatorBeforeSize,
                                       TRUE)
        balance <- enforceMinCellValue(balance,
                                       "targetMeanAfter",
                                       minCellCount/inferredTargetAfterSize,
                                       TRUE)
        balance <- enforceMinCellValue(balance,
                                       "comparatorMeanAfter",
                                       minCellCount/inferredComparatorAfterSize,
                                       TRUE)

        balance <- enforceMinCellValue(balance,
                                       "targetSumBefore",
                                       minCellCount,
                                       TRUE)
        balance <- enforceMinCellValue(balance,
                                       "targetSumAfter",
                                       minCellCount,
                                       TRUE)
        balance <- enforceMinCellValue(balance,
                                       "comparatorSumBefore",
                                       minCellCount,
                                       TRUE)
        balance <- enforceMinCellValue(balance,
                                       "comparatorSumAfter",
                                       minCellCount,
                                       TRUE)

        balance$targetMeanBefore <- round(balance$targetMeanBefore, 3)
        balance$comparatorMeanBefore <- round(balance$comparatorMeanBefore, 3)
        balance$targetMeanAfter <- round(balance$targetMeanAfter, 3)
        balance$comparatorMeanAfter <- round(balance$comparatorMeanAfter, 3)

        balance <- balance[balance$targetMeanBefore != 0 & balance$comparatorMeanBefore != 0 & balance$targetMeanAfter !=
                               0 & balance$comparatorMeanAfter != 0 & balance$stdDiffBefore != 0 & balance$stdDiffAfter !=
                               0, ]

        # balance$targetSizeBefore <- round(balance$targetSizeBefore, 0)
        # balance$comparatorSizeBefore <- round(balance$comparatorSizeBefore, 0)
        # balance$targetSizeAfter <- round(balance$targetSizeAfter, 0)
        # balance$comparatorSizeAfter <- round(balance$comparatorSizeAfter, 0)

        balance <- balance[!is.na(balance$targetId), ]
        colnames(balance) <- SqlRender::camelCaseToSnakeCase(colnames(balance))
        write.table(x = balance,
                    file = fileName,
                    row.names = FALSE,
                    col.names = first,
                    sep = ",",
                    dec = ".",
                    qmethod = "double",
                    append = !first)
        first <- FALSE
        setTxtProgressBar(pb, i/length(files))
    }

    }
    close(pb)

    ParallelLogger::logInfo("- preference_score_dist table")
    reference <- readRDS(file.path(outputFolder, indicationId, "cmOutput", "outcomeModelReference.rds"))
    preparePlot <- function(row, reference) {
        idx <- reference$analysisId == row$analysisId &
            reference$targetId == row$targetId &
            reference$comparatorId == row$comparatorId
        psFileName <- file.path(outputFolder, indicationId,
                                "cmOutput",
                                reference$sharedPsFile[idx][1])
        if (file.exists(psFileName)) {
            ps <- readRDS(psFileName)
            if (min(ps$propensityScore) < max(ps$propensityScore)) {
                ps <- CohortMethod:::computePreferenceScore(ps)

                d1 <- density(ps$preferenceScore[ps$treatment == 1], from = 0, to = 1, n = 100)
                d0 <- density(ps$preferenceScore[ps$treatment == 0], from = 0, to = 1, n = 100)

                result <- tibble::tibble(databaseId = databaseId,
                                         targetId = row$targetId,
                                         comparatorId = row$comparatorId,
                                         analysisId = row$analysisId,
                                         preferenceScore = d1$x,
                                         targetDensity = d1$y,
                                         comparatorDensity = d0$y)
                return(result)
            }
        }
        return(NULL)
    }
    subset <- unique(reference[reference$sharedPsFile != "",
                               c("targetId", "comparatorId", "analysisId")])
    data <- plyr::llply(split(subset, 1:nrow(subset)),
                        preparePlot,
                        reference = reference,
                        .progress = "text")
    data <- do.call("rbind", data)
    fileName <- file.path(exportFolder, "preference_score_dist.csv")
    if (!is.null(data)) {
        colnames(data) <- SqlRender::camelCaseToSnakeCase(colnames(data))
    }
    readr::write_csv(data, fileName)

    ParallelLogger::logInfo("- ps_auc_assessment table")

    getAuc <- function(row, reference) {
        idx <- reference$analysisId == row$analysisId &
            reference$targetId == row$targetId &
            reference$comparatorId == row$comparatorId
        psFileName <- file.path(outputFolder, indicationId,
                                "cmOutput",
                                reference$sharedPsFile[idx][1])
        if (file.exists(psFileName)) {
            ps <- readRDS(psFileName)
            ps <- CohortMethod:::computePreferenceScore(ps)
            auc <- tibble::tibble(auc = CohortMethod::computePsAuc(ps),
                                  equipoise = mean(
                                      ps$preferenceScore >= 0.3 &
                                          ps$preferenceScore <= 0.7),
                                  targetId = row$targetId,
                                  comparatorId = row$comparatorId,
                                  analysisId = row$analysisId,
                                  databaseId = databaseId)
            return(auc)
        }
        return(NULL)
    }

    subset <- unique(reference[reference$sharedPsFile != "",
                               c("targetId", "comparatorId", "analysisId")])
    data <- plyr::llply(split(subset, 1:nrow(subset)),
                        getAuc,
                        reference = reference,
                        .progress = "text")
    data <- do.call("rbind", data)
    fileName <- file.path(exportFolder, "ps_auc_assessment.csv")
    if (!is.null(data)) {
        colnames(data) <- SqlRender::camelCaseToSnakeCase(colnames(data))
    }
    readr::write_csv(data, fileName)

    ParallelLogger::logInfo("- propensity_model table")
    getPsModel <- function(row, reference) {
        idx <- reference$analysisId == row$analysisId &
            reference$targetId == row$targetId &
            reference$comparatorId == row$comparatorId
        psFileName <- file.path(outputFolder, indicationId,
                                "cmOutput",
                                reference$sharedPsFile[idx][1])
        if (file.exists(psFileName)) {
            ps <- readRDS(psFileName)
            metaData <- attr(ps, "metaData")
            if (is.null(metaData$psError)) {
                cmDataFile <- file.path(outputFolder, indicationId,
                                        "cmOutput",
                                        reference$cohortMethodDataFile[idx][1])
                cmData <- CohortMethod::loadCohortMethodData(cmDataFile)
                model <- CohortMethod::getPsModel(ps, cmData)
                model$covariateId[is.na(model$covariateId)] <- 0
                Andromeda::close(cmData)
                model$databaseId <- databaseId
                model$targetId <- row$targetId
                model$comparatorId <- row$comparatorId
                model$analysisId <- row$analysisId
                model <- model[, c("databaseId", "targetId", "comparatorId", "analysisId", "covariateId", "coefficient")]
                return(model)
            }
        }
        return(NULL)
    }
    subset <- unique(reference[reference$sharedPsFile != "",
                               c("targetId", "comparatorId", "analysisId")])
    data <- plyr::llply(split(subset, 1:nrow(subset)),
                        getPsModel,
                        reference = reference,
                        .progress = "text")
    data <- do.call("rbind", data)
    fileName <- file.path(exportFolder, "propensity_model.csv")
    if (!is.null(data)) {
        colnames(data) <- SqlRender::camelCaseToSnakeCase(colnames(data))
    }
    readr::write_csv(data, fileName)

    ParallelLogger::logInfo("- kaplan_meier_dist table")
    ParallelLogger::logInfo("  Computing KM curves")
    reference <- readRDS(file.path(outputFolder, indicationId, "cmOutput", "outcomeModelReference.rds"))
    outcomesOfInterest <- getOutcomesOfInterest()
    reference <- reference[reference$outcomeId %in% outcomesOfInterest, ]
    reference <- reference[, c("strataFile",
                               "studyPopFile",
                               "targetId",
                               "comparatorId",
                               "outcomeId",
                               "analysisId")]
    tempFolder <- file.path(exportFolder, "temp")
    if (!file.exists(tempFolder)) {
        dir.create(tempFolder)
    }
    cluster <- ParallelLogger::makeCluster(min(4, maxCores))
    ParallelLogger::clusterRequire(cluster, "LegendT2dm")
    tasks <- split(reference, seq(nrow(reference)))
    ParallelLogger::clusterApply(cluster,
                                 tasks,
                                 prepareKm,
                                 outputFolder = file.path(outputFolder, indicationId),
                                 tempFolder = tempFolder,
                                 databaseId = databaseId,
                                 minCellCount = minCellCount)
    ParallelLogger::stopCluster(cluster)
    ParallelLogger::logInfo("  Writing to single csv file")
    saveKmToCsv <- function(file, first, outputFile) {
        data <- readRDS(file)
        if (!is.null(data)) {
            colnames(data) <- SqlRender::camelCaseToSnakeCase(colnames(data))
        }
        write.table(x = data,
                    file = outputFile,
                    row.names = FALSE,
                    col.names = first,
                    sep = ",",
                    dec = ".",
                    qmethod = "double",
                    append = !first)
    }
    outputFile <- file.path(exportFolder, "kaplan_meier_dist.csv")
    files <- list.files(tempFolder, "km_.*.rds", full.names = TRUE)
    saveKmToCsv(files[1], first = TRUE, outputFile = outputFile)
    if (length(files) > 1) {
        plyr::l_ply(files[2:length(files)], saveKmToCsv, first = FALSE, outputFile = outputFile, .progress = "text")
    }
    unlink(tempFolder, recursive = TRUE)
}


prepareKm <- function(task,
                      outputFolder,
                      tempFolder,
                      databaseId,
                      minCellCount) {
    ParallelLogger::logTrace("Preparing KM plot for target ",
                             task$targetId,
                             ", comparator ",
                             task$comparatorId,
                             ", outcome ",
                             task$outcomeId,
                             ", analysis ",
                             task$analysisId)
    outputFileName <- file.path(tempFolder, sprintf("km_t%s_c%s_o%s_a%s.rds",
                                                    task$targetId,
                                                    task$comparatorId,
                                                    task$outcomeId,
                                                    task$analysisId))
    if (file.exists(outputFileName)) {
        return(NULL)
    }
    popFile <- task$strataFile
    if (popFile == "") {
        popFile <- task$studyPopFile
    }
    population <- readRDS(file.path(outputFolder,
                                    "cmOutput",
                                    popFile))
    if (nrow(population) == 0) {
        # Can happen when matching and treatment is predictable
        return(NULL)
    }
    data <- prepareKaplanMeier(population)
    if (is.null(data)) {
        # No shared strata
        return(NULL)
    }
    data$targetId <- task$targetId
    data$comparatorId <- task$comparatorId
    data$outcomeId <- task$outcomeId
    data$analysisId <- task$analysisId
    data$databaseId <- databaseId
    data <- enforceMinCellValue(data, "targetAtRisk", minCellCount)
    data <- enforceMinCellValue(data, "comparatorAtRisk", minCellCount)
    saveRDS(data, outputFileName)
}

prepareKaplanMeier <- function(population) {
    dataCutoff <- 0.9
    population$y <- 0
    population$y[population$outcomeCount != 0] <- 1
    if (!("stratumId" %in% names(population)) || length(unique(population$stratumId)) == nrow(population)/2) {
        sv <- survival::survfit(survival::Surv(survivalTime, y) ~ treatment, population, conf.int = TRUE)
        idx <- summary(sv, censored = T)$strata == "treatment=1"
        survTarget <- tibble::tibble(time = sv$time[idx],
                                     targetSurvival = sv$surv[idx],
                                     targetSurvivalLb = sv$lower[idx],
                                     targetSurvivalUb = sv$upper[idx])
        idx <- summary(sv, censored = T)$strata == "treatment=0"
        survComparator <- tibble::tibble(time = sv$time[idx],
                                         comparatorSurvival = sv$surv[idx],
                                         comparatorSurvivalLb = sv$lower[idx],
                                         comparatorSurvivalUb = sv$upper[idx])
        data <- merge(survTarget, survComparator, all = TRUE)
    } else {
        population$stratumSizeT <- 1
        strataSizesT <- aggregate(stratumSizeT ~ stratumId, population[population$treatment == 1, ], sum)
        # if (max(strataSizesT$stratumSizeT) == 1) {
        #     # variable ratio matching: use propensity score to compute IPTW
        #     if (is.null(population$propensityScore)) {
        #         stop("Variable ratio matching detected, but no propensity score found")
        #     }
        #     weights <- aggregate(propensityScore ~ stratumId, population, mean)
        #     if (max(weights$propensityScore) > 0.99999) {
        #         return(NULL)
        #     }
        #     weights$weight <- weights$propensityScore / (1 - weights$propensityScore)
        # } else {
            # stratification: infer probability of treatment from subject counts
            strataSizesC <- aggregate(stratumSizeT ~ stratumId, population[population$treatment == 0, ], sum)
            colnames(strataSizesC)[2] <- "stratumSizeC"
            weights <- merge(strataSizesT, strataSizesC)
            if (nrow(weights) == 0) {
                warning("No shared strata between target and comparator")
                return(NULL)
            }
            weights$weight <- weights$stratumSizeT/weights$stratumSizeC
        # }
        population <- merge(population, weights[, c("stratumId", "weight")])
        population$weight[population$treatment == 1] <- 1
        idx <- population$treatment == 1
        survTarget <- CohortMethod:::adjustedKm(weight = population$weight[idx],
                                                time = population$survivalTime[idx],
                                                y = population$y[idx])
        survTarget$targetSurvivalUb <- survTarget$s^exp(qnorm(0.975)/log(survTarget$s) * sqrt(survTarget$var)/survTarget$s)
        survTarget$targetSurvivalLb <- survTarget$s^exp(qnorm(0.025)/log(survTarget$s) * sqrt(survTarget$var)/survTarget$s)
        survTarget$targetSurvivalLb[survTarget$s > 0.9999] <- survTarget$s[survTarget$s > 0.9999]
        survTarget$targetSurvival <- survTarget$s
        survTarget$s <- NULL
        survTarget$var <- NULL
        idx <- population$treatment == 0
        survComparator <- CohortMethod:::adjustedKm(weight = population$weight[idx],
                                                    time = population$survivalTime[idx],
                                                    y = population$y[idx])
        survComparator$comparatorSurvivalUb <- survComparator$s^exp(qnorm(0.975)/log(survComparator$s) *
                                                                        sqrt(survComparator$var)/survComparator$s)
        survComparator$comparatorSurvivalLb <- survComparator$s^exp(qnorm(0.025)/log(survComparator$s) *
                                                                        sqrt(survComparator$var)/survComparator$s)
        survComparator$comparatorSurvivalLb[survComparator$s > 0.9999] <- survComparator$s[survComparator$s >
                                                                                               0.9999]
        survComparator$comparatorSurvival <- survComparator$s
        survComparator$s <- NULL
        survComparator$var <- NULL
        data <- merge(survTarget, survComparator, all = TRUE)
    }
    data <- data[, c("time", "targetSurvival", "targetSurvivalLb", "targetSurvivalUb", "comparatorSurvival", "comparatorSurvivalLb", "comparatorSurvivalUb")]
    cutoff <- quantile(population$survivalTime, dataCutoff)
    data <- data[data$time <= cutoff, ]
    if (cutoff <= 300) {
        xBreaks <- seq(0, cutoff, by = 50)
    } else if (cutoff <= 600) {
        xBreaks <- seq(0, cutoff, by = 100)
    } else {
        xBreaks <- seq(0, cutoff, by = 250)
    }

    targetAtRisk <- c()
    comparatorAtRisk <- c()
    for (xBreak in xBreaks) {
        targetAtRisk <- c(targetAtRisk,
                          sum(population$treatment == 1 & population$survivalTime >= xBreak))
        comparatorAtRisk <- c(comparatorAtRisk,
                              sum(population$treatment == 0 & population$survivalTime >=
                                      xBreak))
    }
    data <- merge(data, tibble::tibble(time = xBreaks,
                                       targetAtRisk = targetAtRisk,
                                       comparatorAtRisk = comparatorAtRisk), all = TRUE)
    if (is.na(data$targetSurvival[1])) {
        data$targetSurvival[1] <- 1
        data$targetSurvivalUb[1] <- 1
        data$targetSurvivalLb[1] <- 1
    }
    if (is.na(data$comparatorSurvival[1])) {
        data$comparatorSurvival[1] <- 1
        data$comparatorSurvivalUb[1] <- 1
        data$comparatorSurvivalLb[1] <- 1
    }
    idx <- which(is.na(data$targetSurvival))
    while (length(idx) > 0) {
        data$targetSurvival[idx] <- data$targetSurvival[idx - 1]
        data$targetSurvivalLb[idx] <- data$targetSurvivalLb[idx - 1]
        data$targetSurvivalUb[idx] <- data$targetSurvivalUb[idx - 1]
        idx <- which(is.na(data$targetSurvival))
    }
    idx <- which(is.na(data$comparatorSurvival))
    while (length(idx) > 0) {
        data$comparatorSurvival[idx] <- data$comparatorSurvival[idx - 1]
        data$comparatorSurvivalLb[idx] <- data$comparatorSurvivalLb[idx - 1]
        data$comparatorSurvivalUb[idx] <- data$comparatorSurvivalUb[idx - 1]
        idx <- which(is.na(data$comparatorSurvival))
    }
    data$targetSurvival <- round(data$targetSurvival, 4)
    data$targetSurvivalLb <- round(data$targetSurvivalLb, 4)
    data$targetSurvivalUb <- round(data$targetSurvivalUb, 4)
    data$comparatorSurvival <- round(data$comparatorSurvival, 4)
    data$comparatorSurvivalLb <- round(data$comparatorSurvivalLb, 4)
    data$comparatorSurvivalUb <- round(data$comparatorSurvivalUb, 4)

    # Remove duplicate (except time) entries:
    data <- data[order(data$time), ]
    data <- data[!duplicated(data[, -1]), ]
    return(data)
}
