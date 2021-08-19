# Copyright 2020 Observational Health Data Sciences and Informatics
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

runExposureCohortDiagnostics <- function(connectionDetails,
                                         cdmDatabaseSchema,
                                         vocabularyDatabaseSchema,
                                         cohortDatabaseSchema,
                                         tablePrefix,
                                         indicationId,
                                         oracleTempSchema,
                                         outputFolder,
                                         databaseId,
                                         databaseName,
                                         databaseDescription,
                                         minCellCount) {

  CohortDiagnostics::runCohortDiagnostics(packageName = "LegendT2dm",
                                          cohortToCreateFile = paste0("settings/", indicationId, "CohortsToCreate.csv"),
                                          connectionDetails = connectionDetails,
                                          cdmDatabaseSchema = cdmDatabaseSchema,
                                          vocabularyDatabaseSchema = vocabularyDatabaseSchema,
                                          oracleTempSchema = oracleTempSchema,
                                          cohortDatabaseSchema = cohortDatabaseSchema,
                                          cohortTable = paste(tablePrefix, indicationId, "cohort", sep = "_"),
                                          inclusionStatisticsFolder = file.path(outputFolder, indicationId),
                                          exportFolder = file.path(outputFolder, indicationId, "cohortDiagnosticsExport"),
                                          databaseId = databaseId,
                                          databaseName = databaseName,
                                          databaseDescription = databaseDescription,
                                          runInclusionStatistics = TRUE,
                                          runBreakdownIndexEvents = TRUE,
                                          runIncludedSourceConcepts = TRUE,
                                          runCohortCharacterization = TRUE,
                                          #runTemporalCohortCharacterization = TRUE,
                                          runCohortOverlap = FALSE,
                                          runOrphanConcepts = TRUE,
                                          runIncidenceRate = TRUE,
                                          runTimeDistributions = TRUE,
                                          minCellCount = minCellCount)
}

runOutcomeCohortDiagnostics <- function(connectionDetails,
                                      cdmDatabaseSchema,
                                      vocabularyDatabaseSchema,
                                      cohortDatabaseSchema,
                                      tablePrefix,
                                      oracleTempSchema,
                                      outputFolder,
                                      databaseId,
                                      databaseName,
                                      databaseDescription,
                                      minCellCount) {

  CohortDiagnostics::runCohortDiagnostics(packageName = "LegendT2dm",
                                          cohortToCreateFile = "settings/OutcomesOfInterest.csv",
                                          connectionDetails = connectionDetails,
                                          cdmDatabaseSchema = cdmDatabaseSchema,
                                          vocabularyDatabaseSchema = vocabularyDatabaseSchema,
                                          oracleTempSchema = oracleTempSchema,
                                          cohortDatabaseSchema = cohortDatabaseSchema,
                                          cohortTable = paste(tablePrefix, "outcome", "cohort", sep = "_"),
                                          inclusionStatisticsFolder = file.path(outputFolder, "outcome"),
                                          exportFolder = file.path(outputFolder, "outcome", "cohortDiagnosticsExport"),
                                          databaseId = databaseId,
                                          databaseName = databaseName,
                                          databaseDescription = databaseDescription,
                                          runInclusionStatistics = FALSE,
                                          runBreakdownIndexEvents = TRUE,
                                          runIncludedSourceConcepts = TRUE,
                                          runCohortCharacterization = TRUE,
                                          #runTemporalCohortCharacterization = TRUE,
                                          runCohortOverlap = FALSE,
                                          runOrphanConcepts = TRUE,
                                          runIncidenceRate = TRUE,
                                          runTimeDistributions = TRUE,
                                          minCellCount = minCellCount)
}
