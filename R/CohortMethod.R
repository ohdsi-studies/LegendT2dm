# Copyright 2018 Observational Health Data Sciences and Informatics
#
# This file is part of Legend
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

#' Run the cohort method package
#'
#' @details
#' Runs the cohort method package to produce propensity scores and outcome models.
#'
#' @param outputFolder   Name of local folder to place results; make sure to use forward slashes (/).
#'                       Do not use a folder on a network drive since this greatly impacts performance.
#' @param indicationId   A string denoting the indicationId.
#' @param databaseId                           A short string for identifying the database (e.g.
#'                                             'Synpuf').
#' @param maxCores       How many parallel cores should be used? If more cores are made available this
#'                       can speed up the analyses.
#'
#' @export
runCohortMethod <- function(outputFolder, indicationId = "Depression", databaseId, maxCores = 4) {
    # Note: we don't want to run all analyses on all TCO pairs. Specifically, analyses that are
    # symmetrical (e.g. PS stratification) we only want to do one way, and the interaction analyses we
    # don't want to run on the positive controls.  To do this, we split up the analyses across several
    # CohortMethod runs. We must be careful not to have intermediary files in the different runs with the
    # same name but different content.

    # Tell CohortMethod to minimize files sizes by dropping unneeded columns:
    options("minimizeFileSizes" = TRUE)

    indicationFolder <- file.path(outputFolder, indicationId)
    cmFolder <- file.path(indicationFolder, "cmOutput")
    exposureSummary <- read.csv(file.path(indicationFolder,
                                          "pairedExposureSummaryFilteredBySize.csv"))
    pathToCsv <- system.file("settings", "OutcomesOfInterest.csv", package = "LegendT2dm")
    hois <- read.csv(pathToCsv)

    pathToCsv <- system.file("settings", "NegativeControls.csv", package = "LegendT2dm")
    negativeControls <- read.csv(pathToCsv)

    outcomeIds <- unique(c(hois$cohortId, negativeControls$cohortId))

    # injectionSummary <- read.csv(file.path(indicationFolder, "signalInjectionSummary.csv")) # TODO Add back in

    isOt1 <- Vectorize(
        FUN = function(id) {
            string <- as.character(id)
            length(grep("^\\d\\d2", string)) == 0
        })

    makeOt1 <- Vectorize(
        FUN = function(id) {
            string <- as.character(id)
            string <- paste0(substring(string, 1, 2),
                             "1",
                             substring(string, 4, 9))
            as.integer(string)
        })

    ot1ExposureSummary <- exposureSummary[isOt1(exposureSummary$targetId), ]
    tco <- CohortMethod::createTargetComparatorOutcomes(targetId = ot1ExposureSummary$targetId,
                                                        comparatorId = ot1ExposureSummary$comparatorId,
                                                        outcomeIds = outcomeIds)


    cmAnalysisListFile <- system.file("settings",
                                      sprintf("cmAnalysisList%s.json", indicationId),
                                      package = "Legend")
    cmAnalysisList <- CohortMethod::loadCmAnalysisList(cmAnalysisListFile)

    cmAnalysisListFile <- system.file("settings",
                                      sprintf("cmAnalysisListAsym%s.json", indicationId),
                                      package = "Legend")
    cmAnalysisListAsym <- CohortMethod::loadCmAnalysisList(cmAnalysisListFile)

    cmAnalysisListFile <- system.file("settings",
                                      sprintf("cmAnalysisListInteractions%s.json", indicationId),
                                      package = "Legend")
    cmAnalysisListInteractions <- CohortMethod::loadCmAnalysisList(cmAnalysisListFile)

    if ((databaseId == "CCAE" || databaseId == "Optum" || databaseId == "Panther") && indicationId == "Hypertension") {
        # ParallelLogger::logInfo("*** Skipping matching and interactions for CCAE, Optum, and Panther (Hypertension) ***")
        ParallelLogger::logInfo("*** Skipping interactions for CCAE, Optum, and Panther (Hypertension) ***")
        # cmAnalysisListAsym <- list()
        cmAnalysisListInteractions <- list()
    }


    # First run: Forward pairs only, no positive controls ---------------------------------

    tcos <- lapply(1:nrow(exposureSummary), createTcos, positiveControls = "exclude", reverse = FALSE)
    tcos <- plyr::compact(tcos)
    cmAnalyses <- c(cmAnalysisList, cmAnalysisListAsym, cmAnalysisListInteractions)
    CohortMethod::runCmAnalyses(connectionDetails = NULL,
                                cdmDatabaseSchema = NULL,
                                exposureDatabaseSchema = NULL,
                                exposureTable = NULL,
                                outcomeDatabaseSchema = NULL,
                                outcomeTable = NULL,
                                outputFolder = cmFolder,
                                oracleTempSchema = NULL,
                                cmAnalysisList = cmAnalyses,
                                cdmVersion = 5,
                                targetComparatorOutcomesList = tcos,
                                getDbCohortMethodDataThreads = 1,
                                createStudyPopThreads = min(4, maxCores),
                                createPsThreads = max(1, round(maxCores/10)),
                                psCvThreads = min(10, maxCores),
                                trimMatchStratifyThreads = min(10, maxCores),
                                prefilterCovariatesThreads = min(5, maxCores),
                                fitOutcomeModelThreads = min(10, maxCores),
                                outcomeCvThreads = min(10, maxCores),
                                refitPsForEveryOutcome = FALSE,
                                refitPsForEveryStudyPopulation = FALSE,
                                prefilterCovariates = TRUE,
                                outcomeIdsOfInterest = hois$cohortId)
    file.rename(from = file.path(indicationFolder, "cmOutput", "outcomeModelReference.rds"),
                to = file.path(indicationFolder, "cmOutput", "outcomeModelReference1.rds"))

    # Second run: Forward pairs only, only target positive controls ---------------------------------

    tcos <- lapply(1:nrow(exposureSummary),
                   createTcos,
                   positiveControls = "onlyTarget",
                   reverse = FALSE)
    tcos <- plyr::compact(tcos)
    cmAnalyses <- c(cmAnalysisList, cmAnalysisListAsym)
    CohortMethod::runCmAnalyses(connectionDetails = NULL,
                                cdmDatabaseSchema = NULL,
                                exposureDatabaseSchema = NULL,
                                exposureTable = NULL,
                                outcomeDatabaseSchema = NULL,
                                outcomeTable = NULL,
                                outputFolder = cmFolder,
                                oracleTempSchema = NULL,
                                cmAnalysisList = cmAnalyses,
                                cdmVersion = 5,
                                targetComparatorOutcomesList = tcos,
                                getDbCohortMethodDataThreads = 1,
                                createStudyPopThreads = min(4, maxCores),
                                createPsThreads = max(1, round(maxCores/10)),
                                psCvThreads = min(10, maxCores),
                                trimMatchStratifyThreads = min(10, maxCores),
                                prefilterCovariatesThreads = min(5, maxCores),
                                fitOutcomeModelThreads = min(10, maxCores),
                                outcomeCvThreads = min(2, maxCores),
                                refitPsForEveryOutcome = FALSE,
                                refitPsForEveryStudyPopulation = FALSE,
                                prefilterCovariates = TRUE,
                                outcomeIdsOfInterest = hois$cohortId)
    file.rename(from = file.path(indicationFolder, "cmOutput", "outcomeModelReference.rds"),
                to = file.path(indicationFolder, "cmOutput", "outcomeModelReference2.rds"))

    # Third run: Forward pairs only, only comparator positive controls ----------------

    tcos <- lapply(1:nrow(exposureSummary),
                   createTcos,
                   positiveControls = "onlyComparator",
                   reverse = FALSE)
    tcos <- plyr::compact(tcos)
    cmAnalyses <- c(cmAnalysisList)
    CohortMethod::runCmAnalyses(connectionDetails = NULL,
                                cdmDatabaseSchema = NULL,
                                exposureDatabaseSchema = NULL,
                                exposureTable = NULL,
                                outcomeDatabaseSchema = NULL,
                                outcomeTable = NULL,
                                outputFolder = cmFolder,
                                oracleTempSchema = NULL,
                                cmAnalysisList = cmAnalyses,
                                cdmVersion = 5,
                                targetComparatorOutcomesList = tcos,
                                getDbCohortMethodDataThreads = 1,
                                createStudyPopThreads = min(4, maxCores),
                                createPsThreads = max(1, round(maxCores/10)),
                                psCvThreads = min(10, maxCores),
                                trimMatchStratifyThreads = min(10, maxCores),
                                prefilterCovariatesThreads = min(5, maxCores),
                                fitOutcomeModelThreads = min(10, maxCores),
                                outcomeCvThreads = min(2, maxCores),
                                refitPsForEveryOutcome = FALSE,
                                refitPsForEveryStudyPopulation = FALSE,
                                prefilterCovariates = TRUE,
                                outcomeIdsOfInterest = hois$cohortId)
    file.rename(from = file.path(indicationFolder, "cmOutput", "outcomeModelReference.rds"),
                to = file.path(indicationFolder, "cmOutput", "outcomeModelReference3.rds"))

    # Fourth run: Reverse pairs, exclude comparator controls ------------------------------------

    if (length(cmAnalysisListAsym) != 0) {
        # Create reverse (comparator-target) cohortMethodData and ps objects: Warning: cohortMethodData will
        # not have covariate and covariateRef data, since we won't need them (PS is already computed)
        pathToRds <- file.path(indicationFolder, "cmOutput", "outcomeModelReference1.rds")
        reference <- readRDS(pathToRds)
        reference <- reference[order(reference$cohortMethodDataFolder), ]
        reference <- reference[!duplicated(reference$cohortMethodDataFolder), ]
        ParallelLogger::logInfo("Making cohortMethodData and ps objects symmetrical")
        addOtherHalf <- function(i) {
            sourceFolder <- file.path(cmFolder, reference$cohortMethodDataFolder[i])
            targetFolder <- gsub(paste0("_t", reference$targetId[i]),
                                 paste0("_t", reference$comparatorId[i]),
                                 gsub(paste0("_c", reference$comparatorId[i]),
                                      paste0("_c", reference$targetId[i]),
                                      sourceFolder))
            if (!file.exists(targetFolder)) {
                cohortMethodData <- CohortMethod::loadCohortMethodData(sourceFolder)
                idx <- ff::as.ff(1:2)
                cohortMethodData$covariates <- cohortMethodData$covariates[idx, ]
                cohortMethodData$covariateRef <- cohortMethodData$covariateRef[idx, ]
                cohortMethodData$analysisRef <- cohortMethodData$analysisRef[idx, ]
                cohortMethodData$cohorts$treatment <- 1 - cohortMethodData$cohorts$treatment
                metaData <- attr(cohortMethodData$cohorts, "metaData")
                temp <- metaData$attrition$targetPersons
                metaData$attrition$targetPersons <- metaData$attrition$comparatorPersons
                metaData$attrition$comparatorPersons <- temp
                metaData$targetId <- reference$comparatorId[i]
                metaData$comparatorId <- reference$targetId[i]
                attr(cohortMethodData$cohorts, "metaData") <- metaData
                CohortMethod::saveCohortMethodData(cohortMethodData, targetFolder)
            }
            sourceFile <- file.path(cmFolder, reference$sharedPsFile[i])
            targetFile <- gsub(paste0("_t", reference$targetId[i]),
                               paste0("_t", reference$comparatorId[i]),
                               gsub(paste0("_c", reference$comparatorId[i]),
                                    paste0("_c", reference$targetId[i]),
                                    sourceFile))
            if (!file.exists(targetFile)) {
                ps <- readRDS(sourceFile)
                ps$propensityScore <- 1 - ps$propensityScore
                ps$preferenceScore <- 1 - ps$preferenceScore
                ps$treatment <- 1 - ps$treatment
                metaData <- attr(ps, "metaData")
                temp <- metaData$attrition$targetPersons
                metaData$attrition$targetPersons <- metaData$attrition$comparatorPersons
                metaData$attrition$comparatorPersons <- temp
                metaData$targetId <- reference$comparatorId[i]
                metaData$comparatorId <- reference$targetId[i]
                if (!is.null(metaData$psModelCoef)) {
                    metaData$psModelCoef <- -metaData$psModelCoef
                }
                attr(ps, "metaData") <- metaData
                saveRDS(ps, targetFile)
            }
            return(NULL)
        }
        plyr::llply(1:nrow(reference), addOtherHalf, .progress = "text")

        tcos <- lapply(1:nrow(exposureSummary),
                       createTcos,
                       positiveControl = "excludeComparator",
                       reverse = TRUE)
        tcos <- plyr::compact(tcos)
        cmAnalyses <- c(cmAnalysisListAsym)
        CohortMethod::runCmAnalyses(connectionDetails = NULL,
                                    cdmDatabaseSchema = NULL,
                                    exposureDatabaseSchema = NULL,
                                    exposureTable = NULL,
                                    outcomeDatabaseSchema = NULL,
                                    outcomeTable = NULL,
                                    outputFolder = cmFolder,
                                    oracleTempSchema = NULL,
                                    cmAnalysisList = cmAnalyses,
                                    cdmVersion = 5,
                                    targetComparatorOutcomesList = tcos,
                                    getDbCohortMethodDataThreads = 1,
                                    createStudyPopThreads = min(4, maxCores),
                                    createPsThreads = max(1, round(maxCores/10)),
                                    psCvThreads = min(10, maxCores),
                                    trimMatchStratifyThreads = min(4, maxCores),
                                    fitOutcomeModelThreads = min(8, maxCores),
                                    outcomeCvThreads = min(2, maxCores),
                                    refitPsForEveryOutcome = FALSE,
                                    refitPsForEveryStudyPopulation = FALSE,
                                    prefilterCovariates = TRUE,
                                    outcomeIdsOfInterest = hois$cohortId)
        file.rename(from = file.path(indicationFolder, "cmOutput", "outcomeModelReference.rds"),
                    to = file.path(indicationFolder, "cmOutput", "outcomeModelReference4.rds"))
    }

    # Create analysis summaries -------------------------------------------------------------------
    outcomeModelReference1 <- readRDS(file.path(indicationFolder,
                                                "cmOutput",
                                                "outcomeModelReference1.rds"))
    outcomeModelReference2 <- readRDS(file.path(indicationFolder,
                                                "cmOutput",
                                                "outcomeModelReference2.rds"))
    outcomeModelReference3 <- readRDS(file.path(indicationFolder,
                                                "cmOutput",
                                                "outcomeModelReference3.rds"))
    if (file.exists(file.path(indicationFolder,
                              "cmOutput",
                              "outcomeModelReference4.rds"))) {
        outcomeModelReference4 <- readRDS(file.path(indicationFolder,
                                                    "cmOutput",
                                                    "outcomeModelReference4.rds"))
    } else {
        outcomeModelReference4 <- NULL
    }

    # Check to make sure no file names were used twice:
    if (any(outcomeModelReference1$studyPopFile != "" & outcomeModelReference1$studyPopFile %in% outcomeModelReference2$studyPopFile)) {
        stop("Overlapping studyPop files detected between run 1 and 2")
    }
    if (any(outcomeModelReference1$studyPopFile != "" & outcomeModelReference1$studyPopFile %in% outcomeModelReference3$studyPopFile)) {
        stop("Overlapping studyPop files detected between run 1 and 3")
    }
    if (any(outcomeModelReference2$studyPopFile != "" & outcomeModelReference2$studyPopFile %in% outcomeModelReference3$studyPopFile)) {
        stop("Overlapping studyPop files detected between run 2 and 3")
    }
    if (any(outcomeModelReference1$strataFile != "" & outcomeModelReference1$strataFile %in% outcomeModelReference2$strataFile)) {
        stop("Overlapping strataFile files detected between run 1 and 2")
    }
    if (any(outcomeModelReference1$strataFile != "" & outcomeModelReference1$strataFile %in% outcomeModelReference3$strataFile)) {
        stop("Overlapping strata files detected between run 1 and 3")
    }
    if (any(outcomeModelReference2$strataFile != "" & outcomeModelReference2$strataFile %in% outcomeModelReference3$strataFile)) {
        stop("Overlapping strata files detected between run 2 and 3")
    }
    if (!is.null(outcomeModelReference4)) {
        if (any(outcomeModelReference1$studyPopFile != "" & outcomeModelReference1$studyPopFile %in% outcomeModelReference4$studyPopFile)) {
            stop("Overlapping studyPop files detected between run 1 and 4")
        }
        if (any(outcomeModelReference2$studyPopFile != "" & outcomeModelReference2$studyPopFile %in% outcomeModelReference4$studyPopFile)) {
            stop("Overlapping studyPop files detected between run 2 and 4")
        }
        if (any(outcomeModelReference3$studyPopFile != "" & outcomeModelReference3$studyPopFile %in% outcomeModelReference4$studyPopFile)) {
            stop("Overlapping studyPop files detected between run 3 and 4")
        }
        if (any(outcomeModelReference1$strataFile != "" & outcomeModelReference1$strataFile %in% outcomeModelReference4$strataFile)) {
            stop("Overlapping strata files detected between run 1 and 4")
        }
        if (any(outcomeModelReference2$strataFile != "" & outcomeModelReference2$strataFile %in% outcomeModelReference4$strataFile)) {
            stop("Overlapping strata files detected between run 2 and 4")
        }
        if (any(outcomeModelReference3$strataFile != "" & outcomeModelReference3$strataFile %in% outcomeModelReference4$strataFile)) {
            stop("Overlapping strata files detected between run 3 and 4")
        }
    }

    ParallelLogger::logInfo("Summarizing results")
    analysesSum <- CohortMethod::summarizeAnalyses(referenceTable = outcomeModelReference1,
                                                   outputFolder = cmFolder)
    write.csv(analysesSum, file.path(indicationFolder, "analysisSummary1.csv"), row.names = FALSE)

    analysesSum <- CohortMethod::summarizeAnalyses(referenceTable = outcomeModelReference2,
                                                   outputFolder = cmFolder)
    write.csv(analysesSum, file.path(indicationFolder, "analysisSummary2.csv"), row.names = FALSE)

    analysesSum <- CohortMethod::summarizeAnalyses(referenceTable = outcomeModelReference3,
                                                   outputFolder = cmFolder)
    write.csv(analysesSum, file.path(indicationFolder, "analysisSummary3.csv"), row.names = FALSE)

    if (!is.null(outcomeModelReference4)) {
        analysesSum <- CohortMethod::summarizeAnalyses(referenceTable = outcomeModelReference4,
                                                       outputFolder = cmFolder)
        write.csv(analysesSum, file.path(indicationFolder, "analysisSummary4.csv"), row.names = FALSE)
    }
}
