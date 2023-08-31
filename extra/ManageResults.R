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
library(dplyr)

Sys.setenv(DATABASECONNECTOR_JAR_FOLDER="d:/Drivers")

### Manage OHDSI Postgres server
connectionDetails <- DatabaseConnector::createConnectionDetails(
  dbms = "postgresql",
  server = paste(keyring::key_get("ohdsiPostgresServer"),
                 keyring::key_get("ohdsiPostgresShinyDatabase"),
                 sep = "/"),
  user = keyring::key_get("ohdsiPostgresUser"),
  password = keyring::key_get("ohdsiPostgresPassword"))

Sys.setenv(POSTGRES_PATH = "C:\\Program Files\\PostgreSQL\\13\\bin")

# Class CER results

resultsSchema <- "legendt2dm_class_results"
# LegendT2dm::createDataModelOnServer(connectionDetails = connectionDetails,
#                                     schema = resultsSchema,
#                                     sqlFileName = "CreateResultsTables.sql")
#
# LegendT2dm::grantPermissionOnServer(connectionDetails = connectionDetails,
#                                     user = "legend", schema = resultsSchema)
#
# LegendT2dm::grantPermissionOnServer(connectionDetails = connectionDetails,
#                                     user = "legendt2dm_readonly", schema = resultsSchema)

LegendT2dm::addDatabaseIdToTables(
  tableName = "likelihood_profile",
  databaseId = c(
    # "OptumEHR", "OptumDod", "MDCD", "MDCR", "CCAE", "US_Open_Claims", "SIDIAP", "UK_IMRD",
    #              "VA-OMOP", "France_LPD", "HIC-Dundee", "HK-HA-DM",
    # "CUIMC",
    # "Germany_DA",
    "TMUCRD"),
  originalZipFileName = c(
    # "d:/LegendT2dmOutput_optum_ehr_v114/class/export/Results_class_study_OptumEHR.zip",
    # "d:/LegendT2dmOutput_optum_dod_v114/class/export/Results_class_study_OptumDod.zip",
    # "d:/LegendT2dmOutput_mdcd_v114/class/export/Results_class_study_MDCD.zip",
    # "d:/LegendT2dmOutput_mdcr_v114/class/export/Results_class_study_MDCR.zip",
    # "d:/LegendT2dmOutput_ccae_v114/class/export/Results_class_study_CCAE.zip",
    # "d:/LegendT2dmOutput_SFTP/class_ces/Results_class_study_US_Open_Claims_220816.zip",
    # "d:/LegendT2dmOutput_SFTP/class_ces/Results_class_study_SIDIAP_221226.zip",
    # "d:/LegendT2dmOutput_SFTP/class_ces/Results_class_study_UK_IMRD_230105.zip",
    # "d:/LegendT2dmOutput_SFTP/class_ces/Results_class_study_VA-OMOP_221121.zip",
    # "d:/LegendT2dmOutput_SFTP/class_ces/Results_class_study_France_LPD_220906.zip",
    # "d:/LegendT2dmOutput_SFTP/class_ces/Results_class_study_HIC-Dundee_220529_v1121.zip",
    # "d:/LegendT2dmOutput_SFTP/class_ces/Results_class_study_HK-HA-DM_220507_v1121.zip",
    # "d:/LegendT2dmOutput_SFTP/class_ces/Results_class_study_CUIMC_230119.zip",
    # "d:/LegendT2dmOutput_SFTP/class_ces/Results_class_study_Germany_DA_220907.zip",
    "d:/LegendT2dmOutput_SFTP/class_ces/Results_class_study_TMUCRD_230426.zip",
    NULL),
  newZipFileName = c(
    # "d:/LegendT2dmOutput_final/class_ces/Results_class_study_OptumEHR.zip",
    # "d:/LegendT2dmOutput_final/class_ces/Results_class_study_OptumDod.zip",
    # "d:/LegendT2dmOutput_final/class_ces/Results_class_study_MDCD.zip",
    # "d:/LegendT2dmOutput_final/class_ces/Results_class_study_MDCR.zip",
    # "d:/LegendT2dmOutput_final/class_ces/Results_class_study_CCAE.zip",
    # "d:/LegendT2dmOutput_final/class_ces/Results_class_study_US_Open_Claims_220816.zip",
    # "d:/LegendT2dmOutput_final/class_ces/Results_class_study_SIDIAP_221226.zip",
    # "d:/LegendT2dmOutput_final/class_ces/Results_class_study_UK_IMRD_230105.zip",
    # "d:/LegendT2dmOutput_final/class_ces/Results_class_study_VA-OMOP_221121.zip",
    # "d:/LegendT2dmOutput_final/class_ces/Results_class_study_France_LPD_220906.zip",
    # "d:/LegendT2dmOutput_final/class_ces/Results_class_study_HIC-Dundee_220529_v1121.zip",
    # "d:/LegendT2dmOutput_final/class_ces/Results_class_study_HK-HA-DM_220507_v1121.zip",
    # "d:/LegendT2dmOutput_final/class_ces/Results_class_study_CUIMC_230119.zip",
    # "d:/LegendT2dmOutput_final/class_ces/Results_class_study_Germany_DA_220907.zip",
    "d:/LegendT2dmOutput_final/class_ces/Results_class_study_TMUCRD_230426.zip",
    NULL)
  )

LegendT2dm::uploadResultsToDatabase(
  connectionDetails = connectionDetails,
  schema = resultsSchema,
  purgeSiteDataBeforeUploading = TRUE,
  zipFileName = c(
    # "d:/LegendT2dmOutput_final/class_ces/Results_class_study_OptumEHR.zip",
    # "d:/LegendT2dmOutput_final/class_ces/Results_class_study_OptumDod.zip",
    # "d:/LegendT2dmOutput_final/class_ces/Results_class_study_MDCD.zip",
    # "d:/LegendT2dmOutput_final/class_ces/Results_class_study_MDCR.zip",
    # "d:/LegendT2dmOutput_final/class_ces/Results_class_study_CCAE.zip",
    # "d:/LegendT2dmOutput_final/class_ces/Results_class_study_US_Open_Claims_220816.zip",
    # "d:/LegendT2dmOutput_final/class_ces/Results_class_study_SIDIAP_221226.zip",
    # "d:/LegendT2dmOutput_final/class_ces/Results_class_study_UK_IMRD_230105.zip",
    # "d:/LegendT2dmOutput_final/class_ces/Results_class_study_VA-OMOP_221121.zip",
    # "d:/LegendT2dmOutput_final/class_ces/Results_class_study_France_LPD_220906.zip",
    # "d:/LegendT2dmOutput_final/class_ces/Results_class_study_HIC-Dundee_220529_v1121.zip",
    # "d:/LegendT2dmOutput_final/class_ces/Results_class_study_HK-HA-DM_220507_v1121.zip",
    # "d:/LegendT2dmOutput_final/class_ces/Results_class_study_CUIMC_230119.zip",
    # "d:/LegendT2dmOutput_final/class_ces/Results_class_study_Germany_DA_220907.zip",
    "d:/LegendT2dmOutput_final/class_ces/Results_class_study_TMUCRD_230426.zip",
    NULL),
  specifications = tibble::tibble(read.csv("inst/settings/ResultsModelSpecs.csv") %>%
                                    filter(!(tableName %in% c("kaplan_meier_dist"))))
)
