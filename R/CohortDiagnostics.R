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

runClassCohortDiagnostics <- function(connectionDetails,
                                 cdmDatabaseSchema,
                                 cohortDatabaseSchema,
                                 tablePrefix,
                                 oracleTempSchema,
                                 outputFolder,
                                 databaseId,
                                 databaseName,
                                 databaseDescription,
                                 minCellCount) {


  CohortDiagnostics::runCohortDiagnostics(packageName = "LegendT2dm",
                                          cohortToCreateFile = "settings/classCohortsToCreate.csv",
                                          connectionDetails = connectionDetails,
                                          cdmDatabaseSchema = cdmDatabaseSchema,
                                          oracleTempSchema = oracleTempSchema,
                                          cohortDatabaseSchema = cohortDatabaseSchema,
                                          cohortTable = paste(tablePrefix, "cohort", sep = "_"),
                                          inclusionStatisticsFolder = outputFolder,
                                          exportFolder = file.path(outputFolder, "cohortDiagnosticsExport"),
                                          databaseId = databaseId,
                                          databaseName = databaseName,
                                          databaseDescription = databaseDescription,
                                          runInclusionStatistics = TRUE,
                                          runBreakdownIndexEvents = TRUE,
                                          runIncludedSourceConcepts = TRUE,
                                          runCohortCharacterization = TRUE,
                                          #runTemporalCohortCharacterization = TRUE,
                                          runCohortOverlap = TRUE,
                                          runOrphanConcepts = TRUE,
                                          runIncidenceRate = TRUE,
                                          runTimeDistributions = TRUE,
                                          minCellCount = minCellCount)
}
