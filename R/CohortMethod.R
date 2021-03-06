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
runCohortMethod <- function(outputFolder, indicationId = "class", databaseId, maxCores = 4) {

    # Tell CohortMethod to minimize files sizes by dropping unneeded columns:
    options("minimizeFileSizes" = TRUE)

    indicationFolder <- file.path(outputFolder, indicationId)
    exposureSummary <- read.csv(file.path(indicationFolder,
                                          "pairedExposureSummaryFilteredBySize.csv"))
    pathToCsv <- system.file("settings", "OutcomesOfInterest.csv", package = "LegendT2dm")
    hois <- read.csv(pathToCsv)

    pathToCsv <- system.file("settings", "NegativeControls.csv", package = "LegendT2dm")
    negativeControls <- read.csv(pathToCsv)

    outcomeIds <- unique(c(hois$cohortId, negativeControls$cohortId))

    # injectionSummary <- read.csv(file.path(indicationFolder, "signalInjectionSummary.csv")) # TODO Add back in

    copyCmDataFiles <- function(exposures, source, destination) {
        lapply(1:nrow(exposures), function(i) {
            fileName <- file.path(source,
                                  sprintf("CmData_l1_t%s_c%s.zip",
                                          exposures[i,]$targetId,
                                          exposures[i,]$comparatorId))
            file.copy(fileName, destination, copy.date = TRUE)

        })
    }

    deleteCmDataFiles <- function(exposures, source) {
        lapply(1:nrow(exposures), function(i) {
            fileName <- file.path(source,
                                  sprintf("CmData_l1_t%s_c%s.zip",
                                          exposures[i,]$targetId,
                                          exposures[i,]$comparatorId))
            file.remove(fileName)

        })
    }

    # First run: ITT

    ParallelLogger::logInfo("Executing CohortMethod for ITT analyses")

    cmFolder1 <- file.path(indicationFolder, "cmOutput", "Run_1")
    if (!dir.exists(cmFolder1)) {
        dir.create(cmFolder1, recursive = TRUE)
    }

    ittExposureSummary <- exposureSummary[isOt1(exposureSummary$targetId), ]

    copyCmDataFiles(ittExposureSummary,
                    file.path(indicationFolder, "cmOutput"),
                    cmFolder1)

    ittTcoList <- lapply(1:nrow(ittExposureSummary), function(i) {
        CohortMethod::createTargetComparatorOutcomes(targetId = ittExposureSummary[i,]$targetId,
                                                     comparatorId = ittExposureSummary[i,]$comparatorId,
                                                     outcomeIds = outcomeIds)
    })

    ittCmAnalysisList <- CohortMethod::loadCmAnalysisList(
        system.file("settings", "ittCmAnalysisList.json", package = "LegendT2dm"))

    CohortMethod::runCmAnalyses(connectionDetails = NULL,
                                cdmDatabaseSchema = NULL,
                                exposureDatabaseSchema = NULL,
                                exposureTable = NULL,
                                outcomeDatabaseSchema = NULL,
                                outcomeTable = NULL,
                                outputFolder = cmFolder1,
                                oracleTempSchema = NULL,
                                cmAnalysisList = ittCmAnalysisList,
                                cdmVersion = 5,
                                targetComparatorOutcomesList = ittTcoList,
                                getDbCohortMethodDataThreads = 1,
                                createStudyPopThreads = min(4, maxCores),
                                createPsThreads = max(1, round(maxCores/10)),
                                psCvThreads = min(10, maxCores),
                                trimMatchStratifyThreads = min(10, maxCores),
                                prefilterCovariatesThreads = min(5, maxCores),
                                fitOutcomeModelThreads = min(10, maxCores),
                                outcomeCvThreads = min(10, maxCores),
                                refitPsForEveryOutcome = FALSE,
                                refitPsForEveryStudyPopulation = TRUE,
                                prefilterCovariates = TRUE,
                                outcomeIdsOfInterest = hois$cohortId)

    deleteCmDataFiles(ittExposureSummary,
                      cmFolder1)

    # Second run: OT1

    ParallelLogger::logInfo("Executing CohortMethod for OT1 analyses")

    ot1ExposureSummary <- exposureSummary[isOt1(exposureSummary$targetId), ]
    cmFolder2 <- file.path(indicationFolder, "cmOutput", "Run_2")
    if (!dir.exists(cmFolder2)) {
        dir.create(cmFolder2)
    }

    copyCmDataFiles(ot1ExposureSummary,
                    file.path(indicationFolder, "cmOutput"),
                    cmFolder2)

    # Should re-use shared propensity score models

    psFileList <- list.files(file.path(indicationFolder, "cmOutput", "Run_1"),
                             "^Ps_l1_s1_p2_t.*rds", full.names = TRUE, ignore.case = TRUE)
    file.copy(from = psFileList,
              to = file.path(indicationFolder, "cmOutput", "Run_2"),
              copy.date = TRUE)

    ot1TcoList <- lapply(1:nrow(ot1ExposureSummary), function(i) {
        CohortMethod::createTargetComparatorOutcomes(targetId = ot1ExposureSummary[i,]$targetId,
                                                     comparatorId = ot1ExposureSummary[i,]$comparatorId,
                                                     outcomeIds = outcomeIds)
    })

    ot1CmAnalysisList <- CohortMethod::loadCmAnalysisList(
        system.file("settings", "ot1CmAnalysisList.json", package = "LegendT2dm"))

    CohortMethod::runCmAnalyses(connectionDetails = NULL,
                                cdmDatabaseSchema = NULL,
                                exposureDatabaseSchema = NULL,
                                exposureTable = NULL,
                                outcomeDatabaseSchema = NULL,
                                outcomeTable = NULL,
                                outputFolder = cmFolder2,
                                oracleTempSchema = NULL,
                                cmAnalysisList = ot1CmAnalysisList,
                                cdmVersion = 5,
                                targetComparatorOutcomesList = ot1TcoList,
                                getDbCohortMethodDataThreads = 1,
                                createStudyPopThreads = min(4, maxCores),
                                createPsThreads = max(1, round(maxCores/10)),
                                psCvThreads = min(10, maxCores),
                                trimMatchStratifyThreads = min(10, maxCores),
                                prefilterCovariatesThreads = min(5, maxCores),
                                fitOutcomeModelThreads = min(10, maxCores),
                                outcomeCvThreads = min(10, maxCores),
                                refitPsForEveryOutcome = FALSE,
                                refitPsForEveryStudyPopulation = TRUE,
                                prefilterCovariates = TRUE,
                                outcomeIdsOfInterest = hois$cohortId)

    deleteCmDataFiles(ot1ExposureSummary,
                      cmFolder2)

    # Third run: OT2

    # Provide symbolic links for CmData_*.zip


    # Create analysis summaries -------------------------------------------------------------------
    outcomeModelReference1 <- readRDS(file.path(indicationFolder,
                                                "cmOutput", "Run_1",
                                                "outcomeModelReference.rds"))
    outcomeModelReference2 <- readRDS(file.path(indicationFolder,
                                                "cmOutput", "Run_2",
                                                "outcomeModelReference.rds"))


    appendPrefix <- function(omr, prefix) {
        omr <- omr %>% rowwise() %>%
            mutate(studyPopFile = ifelse(studyPopFile != "",
                                         paste0(prefix, "/", studyPopFile), "")) %>%
            mutate(sharedPsFile = ifelse(sharedPsFile != "",
                                         paste0(prefix, "/", sharedPsFile), "")) %>%
            mutate(psFile = ifelse(psFile != "",
                                   paste0(prefix, "/", psFile), "")) %>%
            mutate(strataFile = ifelse(strataFile != "",
                                       paste0(prefix, "/", strataFile), "")) %>%
            mutate(prefilteredCovariatesFile = ifelse(prefilteredCovariatesFile != "",
                                                      paste0(prefix, "/", prefilteredCovariatesFile), "")) %>%
            mutate(outcomeModelFile = ifelse(outcomeModelFile != "",
                                             paste0(prefix, "/", outcomeModelFile), ""))
        return(omr)
    }

    outcomeModelReference1 <- appendPrefix(outcomeModelReference1, "Run_1")
    outcomeModelReference2 <- appendPrefix(outcomeModelReference2, "Run_2")

    outcomeModelReference <- rbind(outcomeModelReference1, outcomeModelReference2)

    saveRDS(outcomeModelReference, file.path(indicationFolder,
                                             "cmOutput",
                                             "outcomeModelReference.rds"))

    ParallelLogger::logInfo("Summarizing results")

    analysesSumFile <- file.path(indicationFolder, "analysisSummary.csv")

    if (!file.exists(analysesSumFile)) {
        analysesSum <- CohortMethod::summarizeAnalyses(referenceTable = outcomeModelReference,
                                                       outputFolder =  file.path(indicationFolder, "cmOutput"))
        write.csv(analysesSum, analysesSumFile, row.names = FALSE)
    }
}

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

getOutcomesOfInterest <- function(indicationId) {
    pathToCsv <- system.file("settings", "OutcomesOfInterest.csv",
                             package = "LegendT2dm")
    outcomesOfInterest <- read.csv(pathToCsv, stringsAsFactors = FALSE)
    return (outcomesOfInterest$cohortId)
}

getAllControls <- function(indicationId, outputFolder) {
    allControlsFile <- file.path(outputFolder, indicationId, "AllControls.csv")
    if (file.exists(allControlsFile)) {
        # Positive controls must have been synthesized. Include both positive and negative controls.
        allControls <- read.csv(allControlsFile)
    } else {
        # Include only negative controls
        pathToCsv <- system.file("settings", "NegativeControls.csv", package = "LegendT2dm")
        allControls <- read.csv(pathToCsv)
        allControls$oldOutcomeId <- allControls$outcomeId
        allControls$targetEffectSize <- rep(1, nrow(allControls))
    }
    return(allControls)
}
