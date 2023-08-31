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

Sys.setenv(DATABASECONNECTOR_JAR_FOLDER="d:/Drivers")

### Manage OHDSI Postgres server
## for drug-level comparison
connectionDetails <- DatabaseConnector::createConnectionDetails(
  dbms = "postgresql",
  server = paste(keyring::key_get("ohdsiPostgresServer"),
                 keyring::key_get("ohdsiPostgresShinyDatabase"),
                 sep = "/"),
  user = keyring::key_get("ohdsiPostgresUser"),
  password = keyring::key_get("ohdsiPostgresPassword"))

# have to install PostgreSQL first?
#Sys.setenv(POSTGRES_PATH = "C:\\Program Files\\PostgreSQL\\13\\bin")

# drug diagnostics

drugSchema <- "legendt2dm_drug_diagnostics"

# create all data tables; will nuke everything
# LegendT2dm::createDataModelOnServer(connectionDetails = connectionDetails,
#                                     schema = drugSchema,
#                                     sqlFileName = "CreateCohortDiagnosticsTables.sql")


## grant user read permission
LegendT2dm::grantPermissionOnServer(connectionDetails = connectionDetails,
                                    user = "legend", schema = drugSchema)

## grant user read permission
LegendT2dm::grantPermissionOnServer(connectionDetails = connectionDetails,
                                    user = "legendt2dm_readonly", schema = drugSchema)

# uploaded, Feb 28 2023
CohortDiagnostics::uploadResults(
  connectionDetails = connectionDetails,
  schema = drugSchema,
  zipFileName = "E:/LegendT2dmOutput_optum_ehr_new/sglt2i/cohortDiagnosticsExport/Results_sglt2i_exposures_OptumEHR.zip")

# uploaded, Feb 2023
CohortDiagnostics::uploadResults(
  connectionDetails = connectionDetails,
  schema = drugSchema,
  zipFileName = "E:/LegendT2dmOutput_optum_dod_new/sglt2i/cohortDiagnosticsExport/Results_sglt2i_exposures_OptumDod.zip")

# uploaded, Feb 8 2023
CohortDiagnostics::uploadResults(
  connectionDetails = connectionDetails,
  schema = drugSchema,
  zipFileName = "E:/LegendT2dmOutput_mdcr_sglt2i_new/sglt2i/cohortDiagnosticsExport/Results_sglt2i_exposures_MDCR.zip")

CohortDiagnostics::uploadResults(
  connectionDetails = connectionDetails,
  schema = drugSchema,
  zipFileName = "E:/LegendT2dmOutput_mdcd_new/sglt2i/cohortDiagnosticsExport/Results_sglt2i_exposures_MDCD.zip")


# # uploaded for dpp4i too, Feb 6 2023
# CohortDiagnostics::uploadResults(
#   connectionDetails = connectionDetails,
#   schema = drugSchema,
#   zipFileName = "E:/LegendT2dmOutput_mdcr_DPP4I_2/DPP4I/cohortDiagnosticsExport/Results_DPP4I_exposures_MDCR.zip")

# uploaded, Feb 8 2023
CohortDiagnostics::uploadResults(
  connectionDetails = connectionDetails,
  schema = drugSchema,
  zipFileName = "E:/LegendT2dmOutput_ccae_sglt2i_new/sglt2i/cohortDiagnosticsExport/Results_sglt2i_exposures_CCAE.zip")

# April 2023: upload VA exposure diagnostics
CohortDiagnostics::uploadResults(
  connectionDetails = connectionDetails,
  schema = drugSchema,
  zipFileName = "E:/m6oukety_Results_sglt2i_exposures_VA-OMOP.zip")

# April 2023: upload CUIMC exposure diagnostics
CohortDiagnostics::uploadResults(
  connectionDetails = connectionDetails,
  schema = drugSchema,
  zipFileName = "E:/Results_sglt2i_exposures_CUIMC.zip")



# CohortDiagnostics::uploadResults(
#   connectionDetails = connectionDetails,
#   schema = classSchema,
#   zipFileName = "d:/LegendT2dmOutput_IQVIA/Results_class_exposures_Germany_DA.zip")
#
# CohortDiagnostics::uploadResults(
#   connectionDetails = connectionDetails,
#   schema = classSchema,
#   zipFileName = "d:/LegendT2dmOutput_IQVIA/Results_class_exposures_Australia_LPD.zip")
#
# CohortDiagnostics::uploadResults(
#   connectionDetails = connectionDetails,
#   schema = classSchema,
#   zipFileName = "d:/LegendT2dmOutput_IQVIA/Results_class_exposures_France_LPD.zip")
#
# CohortDiagnostics::uploadResults(
#   connectionDetails = connectionDetails,
#   schema = classSchema,
#   zipFileName = "d:/LegendT2dmOutput_IQVIA/Results_class_exposures_US_Open_Claims.zip")
#
# CohortDiagnostics::uploadResults(
#   connectionDetails = connectionDetails,
#   schema = classSchema,
#   zipFileName = "d:/LegendT2dmOutput_SFTP/gj0iqfy3_Results_class_exposures_CUIMC.zip")
#
# CohortDiagnostics::uploadResults(
#   connectionDetails = connectionDetails,
#   schema = classSchema,
#   zipFileName = "d:/LegendT2dmOutput_SFTP/tkq5la4h_Results_class_exposures_UK-IMRD.zip")
#
# CohortDiagnostics::uploadResults(
#   connectionDetails = connectionDetails,
#   schema = classSchema,
#   zipFileName = "d:/LegendT2dmOutput_SFTP/x8db42kr_Results_class_exposures_HK-HA-DM.zip")
#
# CohortDiagnostics::uploadResults(
#   connectionDetails = connectionDetails,
#   schema = classSchema,
#   zipFileName = "d:/LegendT2dmOutput_SFTP/56d4ju1v_Results_class_exposures_SG_KTPH.zip")
#
# CohortDiagnostics::uploadResults(
#   connectionDetails = connectionDetails,
#   schema = classSchema,
#   zipFileName = "d:/LegendT2dmOutput_SFTP/fixed_Results_class_exposures_HIC-Dundee.zip")
#
# CohortDiagnostics::uploadResults(
#   connectionDetails = connectionDetails,
#   schema = classSchema,
#   zipFileName = "d:/LegendT2dmOutput_SFTP/0z4r1kpn_Results_class_exposures_JHM.zip")
#
# CohortDiagnostics::uploadResults(
#   connectionDetails = connectionDetails,
#   schema = classSchema,
#   zipFileName = "d:/LegendT2dmOutput_SFTP/9gkhynbo_Results_class_exposures_VA-OMOP.zip")
#
# CohortDiagnostics::uploadResults(
#   connectionDetails = connectionDetails,
#   schema = classSchema,
#   zipFileName = "d:/LegendT2dmOutput_SFTP/db46ulzp_Results_class_exposures_SIDIAP.zip")
#
# CohortDiagnostics::uploadResults(
#   connectionDetails = connectionDetails,
#   schema = classSchema,
#   zipFileName = "d:/LegendT2dmOutput_SFTP/go15dnyv_Results_class_exposures_STARR.zip")


# Outcome diagnostics----
# no need to do this again for drug-level studies

# outcomeSchema <- "legendt2dm_outcome_diagnostics"
# LegendT2dm::createDataModelOnServer(connectionDetails = connectionDetails,
#                                     schema = outcomeSchema,
#                                     sqlFileName = "CreateCohortDiagnosticsTables.sql")
#
# LegendT2dm::grantPermissionOnServer(connectionDetails = connectionDetails,
#                                     user = "legend", schema = outcomeSchema)
#
# LegendT2dm::grantPermissionOnServer(connectionDetails = connectionDetails,
#                                     user = "legendt2dm_readonly", schema = outcomeSchema)
#
# CohortDiagnostics::uploadResults(
#   connectionDetails = connectionDetails,
#   schema = outcomeSchema,
#   zipFileName = "d:/LegendT2dmOutput_optum_ehr1/outcome/cohortDiagnosticsExport/Results_outcomes_OptumEHR.zip")
#
# CohortDiagnostics::uploadResults(
#   connectionDetails = connectionDetails,
#   schema = outcomeSchema,
#   zipFileName = "d:/LegendT2dmOutput_optum_dod1/outcome/cohortDiagnosticsExport/Results_outcomes_OptumDod.zip")
#
# CohortDiagnostics::uploadResults(
#   connectionDetails = connectionDetails,
#   schema = outcomeSchema,
#   zipFileName = "d:/LegendT2dmOutput_mdcd1/outcome/cohortDiagnosticsExport/Results_outcomes_MDCD.zip")
#
# CohortDiagnostics::uploadResults(
#   connectionDetails = connectionDetails,
#   schema = outcomeSchema,
#   zipFileName = "d:/LegendT2dmOutput_mdcr1/outcome/cohortDiagnosticsExport/Results_outcomes_MDCR.zip")
#
# CohortDiagnostics::uploadResults(
#   connectionDetails = connectionDetails,
#   schema = outcomeSchema,
#   zipFileName = "d:/LegendT2dmOutput_ccae1/outcome/cohortDiagnosticsExport/Results_outcomes_CCAE.zip")
#
# CohortDiagnostics::uploadResults(
#   connectionDetails = connectionDetails,
#   schema = outcomeSchema,
#   zipFileName = "d:/LegendT2dmOutput_IQVIA/Results_outcomes_Germany_DA.zip")
#
# CohortDiagnostics::uploadResults(
#   connectionDetails = connectionDetails,
#   schema = outcomeSchema,
#   zipFileName = "d:/LegendT2dmOutput_IQVIA/Results_outcomes_Australia_LPD.zip")
#
# CohortDiagnostics::uploadResults(
#   connectionDetails = connectionDetails,
#   schema = outcomeSchema,
#   zipFileName = "d:/LegendT2dmOutput_IQVIA/Results_outcomes_France_LPD.zip")
#
# CohortDiagnostics::uploadResults(
#   connectionDetails = connectionDetails,
#   schema = outcomeSchema,
#   zipFileName = "d:/LegendT2dmOutput_IQVIA/Results_outcomes_US_Open_Claims.zip")
#
# CohortDiagnostics::uploadResults(
#   connectionDetails = connectionDetails,
#   schema = outcomeSchema,
#   zipFileName = "d:/LegendT2dmOutput_SFTP/urvmnap2_Results_outcomes_CUIMC.zip")
#
# CohortDiagnostics::uploadResults(
#   connectionDetails = connectionDetails,
#   schema = outcomeSchema,
#   zipFileName = "d:/LegendT2dmOutput_SFTP/1kb6ezdp_Results_outcomes_UK-IMRD.zip")
#
# CohortDiagnostics::uploadResults(
#   connectionDetails = connectionDetails,
#   schema = outcomeSchema,
#   zipFileName = "d:/LegendT2dmOutput_SFTP/5kjc7zg0_Results_outcomes_HK-HA-DM.zip")
#
# CohortDiagnostics::uploadResults(
#   connectionDetails = connectionDetails,
#   schema = outcomeSchema,
#   zipFileName = "d:/LegendT2dmOutput_SFTP/4ouldb7r_Results_outcomes_SG_KTPH.zip")
#
# # TODO Add VA, JHU, HIC, SIDIAP, STARR


# PS Assessment----

drugPsSchema <- "legendt2dm_drug_diagnostics"
LegendT2dm::createDataModelOnServer(connectionDetails = connectionDetails,
                                    schema = drugPsSchema,
                                    sqlFileName = "CreatePsAssessmentTables.sql")

LegendT2dm::grantPermissionOnServer(connectionDetails = connectionDetails,
                                    user = "legend", schema = drugPsSchema)

LegendT2dm::grantPermissionOnServer(connectionDetails = connectionDetails,
                                    user = "legendt2dm_readonly", schema = drugPsSchema)

# Feb 2023 upload for sglt2i w/ JnJ databases
# JnJ new data versions DONE
LegendT2dm::uploadResultsToDatabase(
  connectionDetails = connectionDetails,
  schema = drugPsSchema,
  purgeSiteDataBeforeUploading = FALSE,
  zipFileName = c(
    "E:/LegendT2dmOutput_optum_ehr_new/sglt2i/assessmentOfPropensityScores/Results_sglt2i_ps_OptumEHR.zip",
    "E:/LegendT2dmOutput_optum_dod_new/sglt2i/assessmentOfPropensityScores/Results_sglt2i_ps_OptumDod.zip",
    "E:/LegendT2dmOutput_mdcd_new/sglt2i/assessmentOfPropensityScores/Results_sglt2i_ps_MDCD.zip",
    "E:/LegendT2dmOutput_mdcr_sglt2i_new/sglt2i/assessmentOfPropensityScores/Results_sglt2i_ps_MDCR.zip",
    "E:/LegendT2dmOutput_ccae_sglt2i_new/sglt2i/assessmentOfPropensityScores/Results_sglt2i_ps_CCAE.zip"#,
    # "d:/LegendT2dmOutput_IQVIA/Results_class_ps_Germany_DA.zip",
    # "d:/LegendT2dmOutput_IQVIA/Results_class_ps_France_LPD.zip",
    # "d:/LegendT2dmOutput_IQVIA/Results_class_ps_US_Open_Claims.zip",
    # "d:/LegendT2dmOutput_SFTP/8fjt16zl_Results_class_ps_CUIMC.zip",
    # "d:/LegendT2dmOutput_SFTP/eo7lwdtp_Results_class_ps_UK-IMRD.zip",
    # "d:/LegendT2dmOutput_SFTP/yu12zpk5_Results_class_ps_HK-HA-DM.zip",
    # "d:/LegendT2dmOutput_SFTP/9knopym8_Results_class_ps_VA-OMOP.zip",
    # "d:/LegendT2dmOutput_SFTP/a9o8izgx_Results_class_ps_SIDIAP.zip"
    # TODO Add JHU, HIC, STARR
  ),
  specifications = tibble::tibble(read.csv("inst/settings/PsAssessmentModelSpecs.csv"))
)
