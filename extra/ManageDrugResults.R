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
connectionDetails <- DatabaseConnector::createConnectionDetails(
  dbms = "postgresql",
  server = paste(keyring::key_get("ohdsiPostgresServer"),
                 keyring::key_get("ohdsiPostgresShinyDatabase"),
                 sep = "/"),
  user = keyring::key_get("ohdsiPostgresUser"),
  password = keyring::key_get("ohdsiPostgresPassword"))

# Sys.setenv(POSTGRES_PATH = "C:\\Program Files\\PostgreSQL\\13\\bin")

# Drug CER results
# create the data model first
# DO NOT DO THIS IF NOT NECESSARY! WILL PURGE EVEYTHING

resultsSchema <- "legendt2dm_drug_results"
LegendT2dm::createDataModelOnServer(connectionDetails = connectionDetails,
                                    schema = resultsSchema,
                                    sqlFileName = "CreateResultsTables.sql")

LegendT2dm::grantPermissionOnServer(connectionDetails = connectionDetails,
                                    user = "legend", schema = resultsSchema)

LegendT2dm::grantPermissionOnServer(connectionDetails = connectionDetails,
                                    user = "legendt2dm_readonly", schema = resultsSchema)


# Uploaded for sglt2i, Feb 9 2023
LegendT2dm::uploadResultsToDatabase(
  connectionDetails = connectionDetails,
  schema = resultsSchema,
  purgeSiteDataBeforeUploading = TRUE,
  zipFileName = c(
    "E:/LegendT2dmOutput_optum_ehr_v114/sglt2i/export/Results_sglt2i_study_OptumEHR.zip",
    "E:/LegendT2dmOutput_optum_dod/sglt2i/export/Results_sglt2i_study_OptumDod.zip",
    "E:/LegendT2dmOutput_mdcd/sglt2i/export/Results_sglt2i_study_MDCD.zip",
    "E:/LegendT2dmOutput_mdcr_sglt2i_2/sglt2i/export/Results_sglt2i_study_MDCR.zip",
    "E:/LegendT2dmOutput_ccae_sglt2i/sglt2i/export/Results_sglt2i_study_CCAE.zip"
    #"d:/LegendT2dmOutput_SFTP/class_ces/Results_class_study_US_Open_Claims_220816.zip"
    ),
  specifications = tibble::tibble(read.csv("inst/settings/ResultsModelSpecs.csv"))
)



imrdZipFile <- "/Users/msuchard/Dropbox/Projects/LegendT2dm_Results/class_ces/5w17o2h3_Results_class_study_UK-IMRD.zip"

LegendT2dm::prepareForEvidenceExplorer(resultsZipFile = imrdZipFile,
                                       dataFolder = "/Users/msuchard/Dropbox/Projects/LegendT2dm_Results/class_ces/imrd")

LegendT2dmEvidenceExplorer::launchEvidenceExplorer(dataFolder = "/Users/msuchard/Dropbox/Projects/LegendT2dm_Results/class_ces/imrd")

model <- readRDS("/Users/msuchard/Dropbox/Projects/LegendT2dm_Results/class_ces/imrd/propensity_model_UK-IMRD.rds")


# SIDIAP

sidiapZipFile <- "/Users/msuchard/Dropbox/Projects/LegendT2dm_Results/class_ces/ouy7l9at_Results_class_study_SIDIAP.zip"

LegendT2dm::prepareForEvidenceExplorer(resultsZipFile = sidiapZipFile,
                                       dataFolder = "/Users/msuchard/Dropbox/Projects/LegendT2dm_Results/class_ces/sidiap")

LegendT2dmEvidenceExplorer::launchEvidenceExplorer(dataFolder = "/Users/msuchard/Dropbox/Projects/LegendT2dm_Results/class_ces/sidiap")



## Display local results

zipFileName = c(
  "d:/LegendT2dmOutput_optum_ehr2/class/export/Results_class_study_OptumEHR.zip",
  "d:/LegendT2dmOutput_optum_dod2/class/export/Results_class_study_OptumDod.zip",
  "d:/LegendT2dmOutput_mdcd2/class/export/Results_class_study_MDCD.zip",
  "d:/LegendT2dmOutput_mdcr4/class/export/Results_class_study_MDCR.zip",
  "d:/LegendT2dmOutput_ccae3/class/export/Results_class_study_CCAE.zip"
#  ,"d:/LegendT2dmOutput_SFTP/Results_class_study_US_Open_Claims.zip"
)

shinyOutput <- "d:/LegendT2dmOutput_shiny"
lapply(zipFileName, function(file) {
  prepareForEvidenceExplorer(resultsZipFile = file,
                             dataFolder = shinyOutput)
})

LegendT2dmEvidenceExplorer::launchEvidenceExplorer(dataFolder = shinyOutput,
                                                   blind = TRUE)

# Open_Claims
ocShinyOutput <- "d:/LegendT2dmOutput_shiny_oc"
prepareForEvidenceExplorer(resultsZipFile = "d:/LegendT2dmOutput_SFTP/Results_class_study_US_Open_Claims.zip",
                             dataFolder = ocShinyOutput)

LegendT2dmEvidenceExplorer::launchEvidenceExplorer(dataFolder = ocShinyOutput,
                                                   blind = TRUE)

# CUIMC
cuimcShinyOutput <- "d:/LegendT2dmOutput_shiny_cuimc"
prepareForEvidenceExplorer(resultsZipFile = "d:/LegendT2dmOutput_SFTP/Results_class_study_CUIMC.zip",
                           dataFolder = cuimcShinyOutput)
LegendT2dmEvidenceExplorer::launchEvidenceExplorer(dataFolder = cuimcShinyOutput,
                                                   blind = TRUE)

# IMRD
imrdShinyOutput <- "d:/LegendT2dmOutput_shiny_imrd"
prepareForEvidenceExplorer(resultsZipFile = "d:/LegendT2dmOutput_SFTP/5w17o2h3_Results_class_study_UK-IMRD.zip",
                           dataFolder = imrdShinyOutput)
LegendT2dmEvidenceExplorer::launchEvidenceExplorer(dataFolder = imrdShinyOutput,
                                                   blind = TRUE)

# HK
hkShinyOutput <- "d:/LegendT2dmOutput_shiny_hk"
prepareForEvidenceExplorer(resultsZipFile = "d:/LegendT2dmOutput_SFTP/Results_class_study_HK-HA-DM.zip",
                           dataFolder = hkShinyOutput)
LegendT2dmEvidenceExplorer::launchEvidenceExplorer(dataFolder = hkShinyOutput,
                                                   blind = TRUE)

# Simple statistics
dataSource <- c("CCAE","MDCD", "MDCR", "OptumDOD", "OptumEHR")
bind_rows(lapply(dataSource, function(db) {
  readRDS(file.path(shinyOutput, paste0("results_date_time_", db, ".rds")))
}))


ccae <- readRDS(file.path(shinyOutput, "cohort_method_result_CCAE.rds"))
sort(unique(ccae$analysis_id))

oc <- readRDS(file.path(shinyOutput, "cohort_method_result_US_Open_Claims.rds"))
sort(unique(oc$analysis_id))

ccae <- readRDS(file.path(shinyOutput, "covariate_balance_t101100000_c201100000_CCAE.rds"))


readRDS(file.path(imrdShinyOutput, paste0("results_date_time_", "UK-IMRD", ".rds")))

