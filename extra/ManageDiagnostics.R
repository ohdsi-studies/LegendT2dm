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


### Manage OHDSI Postgres server
connectionDetails <- DatabaseConnector::createConnectionDetails(
  dbms = "postgresql",
  server = paste(keyring::key_get("ohdsiPostgresServer"),
                 keyring::key_get("ohdsiPostgresShinyDatabase"),
                 sep = "/"),
  user = keyring::key_get("ohdsiPostgresUser"),
  password = keyring::key_get("ohdsiPostgresPassword"))

Sys.setenv(POSTGRES_PATH = "C:\\Program Files\\PostgreSQL\\13\\bin")

# Class diagnostics

classSchema <- "legendt2dm_class_diagnostics"
LegendT2dm::createDataModelOnServer(connectionDetails = connectionDetails,
                                    schema = classSchema,
                                    sqlFileName = "CreateCohortDiagnosticsTables.sql")

LegendT2dm::grantPermissionOnServer(connectionDetails = connectionDetails,
                                    user = "legend", schema = classSchema)

LegendT2dm::grantPermissionOnServer(connectionDetails = connectionDetails,
                                    user = "legendt2dm_readonly", schema = classSchema)

CohortDiagnostics::uploadResults(
  connectionDetails = connectionDetails,
  schema = classSchema,
  zipFileName = "d:/LegendT2dmOutput_optum_ehr1/class/cohortDiagnosticsExport/Results_class_exposures_OptumEHR.zip")

CohortDiagnostics::uploadResults(
  connectionDetails = connectionDetails,
  schema = classSchema,
  zipFileName = "d:/LegendT2dmOutput_optum_dod1/class/cohortDiagnosticsExport/Results_class_exposures_OptumDod.zip")

CohortDiagnostics::uploadResults(
  connectionDetails = connectionDetails,
  schema = classSchema,
  zipFileName = "d:/LegendT2dmOutput_mdcd1/class/cohortDiagnosticsExport/Results_class_exposures_MDCD.zip")

CohortDiagnostics::uploadResults(
  connectionDetails = connectionDetails,
  schema = classSchema,
  zipFileName = "d:/LegendT2dmOutput_mdcr1/class/cohortDiagnosticsExport/Results_class_exposures_MDCR.zip")

CohortDiagnostics::uploadResults(
  connectionDetails = connectionDetails,
  schema = classSchema,
  zipFileName = "d:/LegendT2dmOutput_ccae1/class/cohortDiagnosticsExport/Results_class_exposures_CCAE.zip")

CohortDiagnostics::uploadResults(
  connectionDetails = connectionDetails,
  schema = classSchema,
  zipFileName = "d:/LegendT2dmOutput_IQVIA/Results_class_exposures_Germany_DA.zip")

# Outcome diagnostics

outcomeSchema <- "legendt2dm_outcome_diagnostics"
LegendT2dm::createDataModelOnServer(connectionDetails = connectionDetails,
                                    schema = outcomeSchema,
                                    sqlFileName = "CreateCohortDiagnosticsTables.sql")

LegendT2dm::grantPermissionOnServer(connectionDetails = connectionDetails,
                                    user = "legend", schema = outcomeSchema)

LegendT2dm::grantPermissionOnServer(connectionDetails = connectionDetails,
                                    user = "legendt2dm_readonly", schema = outcomeSchema)

CohortDiagnostics::uploadResults(
  connectionDetails = connectionDetails,
  schema = outcomeSchema,
  zipFileName = "d:/LegendT2dmOutput_optum_ehr1/outcome/cohortDiagnosticsExport/Results_outcomes_OptumEHR.zip")

CohortDiagnostics::uploadResults(
  connectionDetails = connectionDetails,
  schema = outcomeSchema,
  zipFileName = "d:/LegendT2dmOutput_optum_dod1/outcome/cohortDiagnosticsExport/Results_outcomes_OptumDod.zip")

CohortDiagnostics::uploadResults(
  connectionDetails = connectionDetails,
  schema = outcomeSchema,
  zipFileName = "d:/LegendT2dmOutput_mdcd1/outcome/cohortDiagnosticsExport/Results_outcomes_MDCD.zip")

CohortDiagnostics::uploadResults(
  connectionDetails = connectionDetails,
  schema = outcomeSchema,
  zipFileName = "d:/LegendT2dmOutput_mdcr1/outcome/cohortDiagnosticsExport/Results_outcomes_MDCR.zip")

CohortDiagnostics::uploadResults(
  connectionDetails = connectionDetails,
  schema = outcomeSchema,
  zipFileName = "d:/LegendT2dmOutput_ccae1/outcome/cohortDiagnosticsExport/Results_outcomes_CCAE.zip")

CohortDiagnostics::uploadResults(
  connectionDetails = connectionDetails,
  schema = outcomeSchema,
  zipFileName = "d:/LegendT2dmOutput_IQVIA/Results_outcomes_Germany_DA.zip")

# PS Assessment

classPsSchema <- "legendt2dm_class_diagnostics"
LegendT2dm::createDataModelOnServer(connectionDetails = connectionDetails,
                                    schema = classPsSchema,
                                    sqlFileName = "CreatePsAssessmentTables.sql")

LegendT2dm::grantPermissionOnServer(connectionDetails = connectionDetails,
                                    user = "legend", schema = classPsSchema)

LegendT2dm::grantPermissionOnServer(connectionDetails = connectionDetails,
                                    user = "legendt2dm_readonly", schema = classPsSchema)

LegendT2dm::uploadResultsToDatabase(
  connectionDetails = connectionDetails,
  schema = classPsSchema,
  purgeSiteDataBeforeUploading = FALSE,
  zipFileName = c(
    "d:/LegendT2dmOutput_optum_ehr1/class/assessmentOfPropensityScores/Results_class_ps_OptumEHR.zip",
    "d:/LegendT2dmOutput_optum_dod1/class/assessmentOfPropensityScores/Results_class_ps_OptumDod.zip",
    "d:/LegendT2dmOutput_mdcd1/class/assessmentOfPropensityScores/Results_class_ps_MDCD.zip",
    "d:/LegendT2dmOutput_mdcr1/class/assessmentOfPropensityScores/Results_class_ps_MDCR.zip",
    "d:/LegendT2dmOutput_ccae1/class/assessmentOfPropensityScores/Results_class_ps_CCAE.zip",
    "d:/LegendT2dmOutput_IQVIA//Results_class_ps_Germany_DA.zip"),
  specifications = tibble::tibble(read.csv("inst/settings/PsAssessmentModelSpecs.csv"))
)

