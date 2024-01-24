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

#' Filter exposure pairs by size of the cohorts
#'
#' @param outputFolder     Name of local folder to place results; make sure to use forward slashes (/)
#' @param indicationId     A string denoting the indicationId.
#' @param minCohortSize   Minimum number of people that have to be in each cohort to keep a pair of
#'                         cohorts.
#' @param summaryFile     File name of the csv that contains paired exposure summary;
#'                        if NULL, then default to "pairedExposureSummary.csv"
#'
#' @export
filterByExposureCohortsSize <- function(outputFolder,
                                        indicationId,
                                        minCohortSize,
                                        summaryFile = NULL) {
    if(is.null(summaryFile)){
      summaryFilePath = file.path(outputFolder, indicationId, "pairedExposureSummary.csv")
    }else{
      summaryFilePath = file.path(outputFolder, indicationId, summaryFile)
    }
    exposureSummary <- read.csv(summaryFilePath)
    filtered <- exposureSummary[exposureSummary$targetPairedPersons > minCohortSize & exposureSummary$comparatorPairedPersons >
                                  minCohortSize, ]
    write.csv(filtered,
              file.path(outputFolder, indicationId, "pairedExposureSummaryFilteredBySize.csv"),
              row.names = FALSE)
}
