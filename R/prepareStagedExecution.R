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

#' Utility function to split up CES execution, with only a subset of TC pairs in each run
#'
#' @details
#' This function prepares staged CES execution by copying/slicing necessary files.
#' But note, this does NOT run the study; this is only a utility function that allows staged execution.
#'
#' @param originalOutputFolder      Original output folder used when creating cohorts
#' @param outputFolderHeader        The staged execution output folders will start with this header name;
#'                                  default is the same as `originalOutputFolder`
#' @param indicationId              Which sub-study to run?
#' @param stages                    Number of stages for execution?
#'
#' @export
prepareStagedExecution <- function(originalOutputFolder,
                                   outputFolderHeader  = originalOutputFolder,
                                   indicationId = "drug",
                                   stages = 10){

  # slice up pairedExposureSummary file
  indicationFolder <- file.path(originalOutputFolder, indicationId)
  exposureSummary <- read.csv(file.path(indicationFolder,
                                        "pairedExposureSummaryFilteredBySize.csv"))
  chunkSize = ceiling(nrow(exposureSummary)/ stages)
  stageCounter = rep(1:stages, each = chunkSize)
  exposureSummary$stage = stageCounter[1:nrow(exposureSummary)]

  # file path to exposure cohortCounts table
  exposureCohortCountsFile = file.path(indicationFolder, "cohortCounts.csv")

  # file path to outcome cohortCounts table
  outcomeFold <- file.path(originalOutputFolder, "outcome")
  cohortCountsFile = file.path(outcomeFold, "cohortCounts.csv")

  outputFolderHeader = stringr::str_remove(outputFolderHeader, "/$")
  for(s in 1:stages){
    newOutputFolder = paste0(outputFolderHeader, "-", s)
    if(!dir.exists(newOutputFolder)){
      dir.create(newOutputFolder)
    }

    # copy over outcome cohortCounts table
    newOutcomeFolder = file.path(newOutputFolder, "outcome")
    if(!dir.exists(newOutcomeFolder)){
      dir.create(newOutcomeFolder)
    }
    file.copy(cohortCountsFile, newOutcomeFolder)

    # copy over exposure cohortCounts table
    newIndicationFolder = file.path(newOutputFolder, indicationId)
    if(!dir.exists(newIndicationFolder)){
      dir.create(newIndicationFolder)
    }
    file.copy(exposureCohortCountsFile, newIndicationFolder)

    # write sliced pairedExposureSummary file
    exposureSummarySlice <- exposureSummary %>% filter(stage == s) %>% select(-stage)
    exposureSummarySliceFile = file.path(newIndicationFolder, "pairedExposureSummaryFilteredBySize.csv")
    write.csv(exposureSummarySlice, exposureSummarySliceFile, row.names = FALSE)

  }

}
