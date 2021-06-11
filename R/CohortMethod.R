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
runCohortMethod <- function(outputFolder, indicationId = "Depression", databaseId, maxCores = 4) {

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

    # First run: OT1 and ITT

    ot1IttExposureSummary <- exposureSummary[isOt1(exposureSummary$targetId), ]
    ot1IttTco <- CohortMethod::createTargetComparatorOutcomes(targetId = ot1ExposureSummary$targetId,
                                                        comparatorId = ot1ExposureSummary$comparatorId,
                                                        outcomeIds = outcomeIds)

    ot1IttCmAnalysisList <- CohortMethod::loadCmAnalysisList(
        system.file("settings", "ot1IttCmAnalysisList.json", package = "LegendT2dm"))

    CohortMethod::runCmAnalyses(connectionDetails = NULL,
                                cdmDatabaseSchema = NULL,
                                exposureDatabaseSchema = NULL,
                                exposureTable = NULL,
                                outcomeDatabaseSchema = NULL,
                                outcomeTable = NULL,
                                outputFolder = cmFolder,
                                oracleTempSchema = NULL,
                                cmAnalysisList = ot1IttCmAnalysisList,
                                cdmVersion = 5,
                                targetComparatorOutcomesList = ot1IttTco,
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

    # Second run: OT2

    # Provide symbolic links for CmData_*.zip


    # Create analysis summaries -------------------------------------------------------------------
    outcomeModelReference1 <- readRDS(file.path(indicationFolder,
                                                "cmOutput",
                                                "outcomeModelReference1.rds"))
    # outcomeModelReference2 <- readRDS(file.path(indicationFolder,
    #                                             "cmOutput",
    #                                             "outcomeModelReference2.rds"))

    ParallelLogger::logInfo("Summarizing results")

    analysesSum <- CohortMethod::summarizeAnalyses(referenceTable = outcomeModelReference1,
                                                   outputFolder = cmFolder)
    write.csv(analysesSum, file.path(indicationFolder, "analysisSummary1.csv"), row.names = FALSE)

    # analysesSum <- CohortMethod::summarizeAnalyses(referenceTable = outcomeModelReference2,
    #                                                outputFolder = cmFolder)
    # write.csv(analysesSum, file.path(indicationFolder, "analysisSummary2.csv"), row.names = FALSE)
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
