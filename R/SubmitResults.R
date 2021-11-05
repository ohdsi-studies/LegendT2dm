# Copyright 2019 Observational Health Data Sciences and Informatics
#
# This file is part of Covid19IncidenceRasInhibitors
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

#' Upload cohort diagnostic results to OHDSI server
#'
#' @details
#' This function uploads the 'Results<databaseId>.zip' to the OHDSI SFTP server. Before sending, you can inspect the zip file,
#' which contains (zipped) CSV files. You can send the zip file from a different computer than the one on which is was created.
#'
#' @param cohorts              Specifies which set of cohorts to upload
#' @param privateKeyFileName   A character string denoting the path to the RSA private key provided by the study coordinator.
#' @param userName             A character string containing the user name provided by the study coordinator.
#' @param outputFolder         Name of local folder to place results; make sure to use forward slashes
#'                             (/). Do not use a folder on a network drive since this greatly impacts
#'                             performance.
#'
#' @export
uploadPhenotypeResults <- function(cohorts, outputFolder, privateKeyFileName, userName) {
  fileName <- list.files(file.path(outputFolder, cohorts, "cohortDiagnosticsExport"),
                         "Results.*.zip$", full.names = TRUE)
  if (length(fileName) == 0) {
    stop("Could not find results file in folder. Did you run (and complete) execute?")
  }
  if (length(fileName) == 0) {
    stop("Multiple results files found. Don't know which one to upload")
  }
  OhdsiSharing::sftpUploadFile(privateKeyFileName = privateKeyFileName,
                               userName = userName,
                               remoteFolder = paste0("LegendT2dm_", cohorts, "_diagnostics"),
                               fileName = fileName)
  ParallelLogger::logInfo("Finished uploading")
}

#' Upload propensity score assessment results to OHDSI server
#'
#' @details
#' This function uploads the 'Results<databaseId>.zip' to the OHDSI SFTP server. Before sending, you can inspect the zip file,
#' which contains (zipped) CSV files. You can send the zip file from a different computer than the one on which is was created.
#'
#' @param cohorts              Specifies which set of cohorts to upload
#' @param privateKeyFileName   A character string denoting the path to the RSA private key provided by the study coordinator.
#' @param userName             A character string containing the user name provided by the study coordinator.
#' @param outputFolder         Name of local folder to place results; make sure to use forward slashes
#'                             (/). Do not use a folder on a network drive since this greatly impacts
#'                             performance.
#'
#' @export
#'
uploadPsAssessmentResults <- function(cohorts, outputFolder, privateKeyFileName, userName) {
  fileName <- list.files(file.path(outputFolder, cohorts, "assessmentOfPropensityScores"),
                         "Results.*.zip$", full.names = TRUE)
  if (length(fileName) == 0) {
    stop("Could not find results file in folder. Did you run (and complete) execute?")
  }
  if (length(fileName) == 0) {
    stop("Multiple results files found. Don't know which one to upload")
  }
  OhdsiSharing::sftpUploadFile(privateKeyFileName = privateKeyFileName,
                               userName = userName,
                               remoteFolder = paste0("LegendT2dm_", cohorts, "_ps"),
                               fileName = fileName)
  ParallelLogger::logInfo("Finished uploading")
}
