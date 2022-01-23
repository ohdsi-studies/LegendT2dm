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

    # First run: ITT
    executeSingleCmRun(message = "ITT analyses",
                       folder = "Run_1",
                       exposureSummary = exposureSummary[isOt1(exposureSummary$targetId), ],
                       cmAnalysisList = system.file("settings", "ittCmAnalysisList.json", package = "LegendT2dm"),
                       outcomeIds = unique(c(hois$cohortId, negativeControls$cohortId)),
                       outcomeIdsOfInterest = hois$cohortId,
                       indicationFolder = indicationFolder,
                       maxCores = maxCores)

    # Second run: OT1
    executeSingleCmRun(message = "OT1 analyses",
                       folder = "Run_2",
                       exposureSummary = exposureSummary[isOt1(exposureSummary$targetId), ],
                       cmAnalysisList = system.file("settings", "ot1CmAnalysisList.json", package = "LegendT2dm"),
                       outcomeIds = unique(c(hois$cohortId, negativeControls$cohortId)),
                       outcomeIdsOfInterest = hois$cohortId,
                       copyPsFileFolder = "Run_1",
                       indicationFolder = indicationFolder,
                       maxCores = maxCores)

    # Third run: OT2
    executeSingleCmRun(message = "OT2 analyses",
                       folder = "Run_3",
                       exposureSummary = exposureSummary[!isOt1(exposureSummary$targetId), ],
                       cmAnalysisList = system.file("settings", "ot2CmAnalysisList.json", package = "LegendT2dm"),
                       outcomeIds = unique(c(hois$cohortId, negativeControls$cohortId)),
                       outcomeIdsOfInterest = hois$cohortId,
                       copyPsFileFolder = "Run_1",
                       convertPsFileNames = TRUE,
                       indicationFolder = indicationFolder,
                       maxCores = maxCores)

    glycemicId <- 5

    # Fourth run: ITT
    executeSingleCmRun(message = "ITT-PO analyses",
                       folder = "Run_4",
                       exposureSummary = exposureSummary[isOt1(exposureSummary$targetId), ],
                       cmAnalysisList = system.file("settings", "ittPoCmAnalysisList.json", package = "LegendT2dm"),
                       outcomeIds = unique(c(glycemicId, negativeControls$cohortId)),
                       outcomeIdsOfInterest = glycemicId,
                       copyPsFileFolder = "Run_1",
                       indicationFolder = indicationFolder,
                       maxCores = maxCores)

    # Fifth run: OT1
    executeSingleCmRun(message = "OT1-PO analyses",
                       folder = "Run_5",
                       exposureSummary = exposureSummary[isOt1(exposureSummary$targetId), ],
                       cmAnalysisList = system.file("settings", "ot1PoCmAnalysisList.json", package = "LegendT2dm"),
                       outcomeIds = unique(c(glycemicId, negativeControls$cohortId)),
                       outcomeIdsOfInterest = glycemicId,
                       copyPsFileFolder = "Run_1",
                       indicationFolder = indicationFolder,
                       maxCores = maxCores)

    # Sixth run: OT2
    executeSingleCmRun(message = "OT2-PO analyses",
                       folder = "Run_6",
                       exposureSummary = exposureSummary[!isOt1(exposureSummary$targetId), ],
                       cmAnalysisList = system.file("settings", "ot2PoCmAnalysisList.json", package = "LegendT2dm"),
                       outcomeIds = unique(c(glycemicId, negativeControls$cohortId)),
                       outcomeIdsOfInterest = glycemicId,
                       copyPsFileFolder = "Run_1",
                       convertPsFileNames = TRUE,
                       indicationFolder = indicationFolder,
                       maxCores = maxCores)

    # Create analysis summaries -------------------------------------------------------------------
    outcomeModelReference <- saveCombinedOutcomeModelReference(folders = c("Run_1", "Run_2", "Run_3",
                                                                           "Run_4", "Run_5", "Run_6"),
                                                               indicationFolder = indicationFolder)

    ParallelLogger::logInfo("Summarizing results")

    analysesSumFile <- file.path(indicationFolder, "analysisSummary.csv")

    if (!file.exists(analysesSumFile)) {
        analysesSum <- CohortMethod::summarizeAnalyses(referenceTable = outcomeModelReference,
                                                       outputFolder =  file.path(indicationFolder, "cmOutput"))
        write.csv(analysesSum, analysesSumFile, row.names = FALSE)
    }
}

saveCombinedOutcomeModelReference <- function(folders,
                                              indicationFolder) {

    appendPrefix <- function(omr, prefix) {
        omr <- omr %>% rowwise() %>%
            mutate(studyPopFile = ifelse(.data$studyPopFile != "",
                                         paste0(prefix, "/", .data$studyPopFile), "")) %>%
            mutate(sharedPsFile = ifelse(.data$sharedPsFile != "",
                                         paste0(prefix, "/", .data$sharedPsFile), "")) %>%
            mutate(psFile = ifelse(.data$psFile != "",
                                   paste0(prefix, "/", .data$psFile), "")) %>%
            mutate(strataFile = ifelse(.data$strataFile != "",
                                       paste0(prefix, "/", .data$strataFile), "")) %>%
            mutate(prefilteredCovariatesFile = ifelse(.data$prefilteredCovariatesFile != "",
                                                      paste0(prefix, "/", .data$prefilteredCovariatesFile), "")) %>%
            mutate(outcomeModelFile = ifelse(.data$outcomeModelFile != "",
                                             paste0(prefix, "/", .data$outcomeModelFile), ""))
        return(omr)
    }

    process <- function(folder) {
        outcomeModelReference <- readRDS(file.path(indicationFolder,
                                                   "cmOutput", folder,
                                                   "outcomeModelReference.rds"))

        outcomeModelReference <- appendPrefix(outcomeModelReference, folder)
    }



    outcomeModelReference <- lapply(folders, process) %>% dplyr::bind_rows()

    saveRDS(outcomeModelReference, file.path(indicationFolder,
                                             "cmOutput",
                                             "outcomeModelReference.rds"))
    return(outcomeModelReference)
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

makeOt2 <- Vectorize(
    FUN = function(id) {
        string <- as.character(id)
        string <- paste0(substring(string, 1, 2),
                         "2",
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
