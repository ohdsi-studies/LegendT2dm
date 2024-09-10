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

#Sys.setenv(DATABASECONNECTOR_JAR_FOLDER="d:/Drivers")
Sys.setenv(DATABASECONNECTOR_JAR_FOLDER="~/Documents/Drivers/")

### Manage OHDSI Postgres server
connectionDetails <- DatabaseConnector::createConnectionDetails(
  dbms = "postgresql",
  server = paste(keyring::key_get("ohdsiPostgresServer"),
                 keyring::key_get("ohdsiPostgresShinyDatabase"),
                 sep = "/"),
  user = keyring::key_get("ohdsiPostgresUser"),
  password = keyring::key_get("ohdsiPostgresPassword"))


# try using bulk load (need PostGreSQL installed on machine)
#Sys.setenv(POSTGRES_PATH = "C:\\Program Files\\PostgreSQL\\13\\bin")
Sys.setenv(POSTGRES_PATH = "/Library/PostgreSQL/13/bin")
Sys.setenv(DATABASE_CONNECTOR_BULK_UPLOAD = TRUE)

# Drug CES results
resultsSchema <- "legendt2dm_drug_results"

# create the data model first
# DO NOT DO THIS IF NOT NECESSARY! WILL PURGE EVEYTHING----
# LegendT2dm::createDataModelOnServer(connectionDetails = connectionDetails,
#                                     schema = resultsSchema,
#                                     sqlFileName = "CreateResultsTables.sql")

# grant user permission
LegendT2dm::grantPermissionOnServer(connectionDetails = connectionDetails,
                                    user = "legend", schema = resultsSchema)

LegendT2dm::grantPermissionOnServer(connectionDetails = connectionDetails,
                                    user = "legendt2dm_readonly", schema = resultsSchema)


# July 2023 drug-vs-drug CES results upload ----
# Results after for newer data version & package de-bug
# Aug 2024: try using bulk upload for OptumEHR results again....
# Aug 2024: also re-upload VA KM curves
LegendT2dm::uploadResultsToDatabase(
  connectionDetails = connectionDetails,
  schema = resultsSchema,
  purgeSiteDataBeforeUploading =TRUE,
  zipFileName = c(
    #"E:/LegendT2dmOutput_mdcr_drug/drug/export/Results_drug_study_MDCR.zip",
    #"E:/LegendT2dmOutput_ccae_drug/drug/export/Results_drug_study_CCAE.zip"
    #"E:/LegendT2dmOutput_optum_ehr_new/sglt2i/export/Results_sglt2i_study_OptumEHR.zip",
    #"E:/LegendT2dmOutput_optum_dod_new/sglt2i/export/Results_sglt2i_study_OptumDod.zip",
    #"E:/LegendT2dmOutput_mdcd_drug2/drug/export/Results_drug_study_MDCD.zip",
    #"E:/LegendT2dmOutput_mdcr_continuousAge_test/sglt2i/export/Results_sglt2i_study_MDCR.zip",
    #"E:/LegendT2dmOutput_ccae_sglt2i_new/sglt2i/export/Results_sglt2i_study_CCAE.zip",
    #"C:/Users/Admin_FBu2/Downloads/Results_drug_study_DA_GERMANY.zip",
    #"C:/Users/Admin_FBu2/Downloads/Results_drug_study_LPD_FRANCE.zip",
    # "E:/Results_drug_study_LPD_FRANCE.zip",
    # "E:/Results_drug_study_DA_GERMANY.zip",
    # "E:/LegendT2dmOutput_mdcr_drug2/drug/export/Results_drug_study_MDCR.zip",
    # "E:/LegendT2dmOutput_mdcd_drug2/drug/export/Results_drug_study_MDCD.zip",
    #"E:/LegendT2dmOutput_optum_ehr_drug2/drug/export/Results_drug_study_OptumEHR.zip",
    #"C:/Users/Admin_FBu2/Downloads/rzbxa8v1_Results_drug_study_IMRD.zip",
    "~/Downloads/Results_drug_study_VAOMOP.zip",
    NULL
    ),
  #specifications = tibble::tibble(read.csv("inst/settings/ResultsModelSpecs.csv")),
  specifications = tibble::tibble(read.csv("inst/settings/ResultsModelSpecs1.csv")) %>%
    filter(tableName %in%
             #c("kaplan_meier_dist", "covariate_balance")
             #c("preference_score_dist", "propensity_model")
             c("kaplan_meier_dist")
           ),
  #tempFolder = "E:/uploadTemp/"
  tempFolder = "~/Downloads/uploadTemp/",
  defaultChunkSize = 5e6,
  forceOverWriteOfSpecifications = FALSE,
  useTempTable = FALSE
)


# ## only upload the covariate balance table (10GB) to see if it works?
# LegendT2dm::uploadResultsToDatabaseFromCsv(
#   connectionDetails = connectionDetails,
#   schema = resultsSchema,
#   purgeSiteDataBeforeUploading =TRUE,
#   exportFolder = "F:/LegendT2dmOutput_optum_ehr_drug2/drug/export/",
#   tableNames = c("covariate_balance"),
#   specifications = tibble::tibble(read.csv("inst/settings/ResultsModelSpecs1.csv")) %>%
#     filter(tableName %in% c("covariate_balance")),
#   chunkSize = 1e6,
#   forceOverWriteOfSpecifications = TRUE
# )


## May 2024: upload all Open Claims drug-v-drug results
## Sept 2024: try again with covariate_balance and KM
LegendT2dm::uploadResultsToDatabase(
  connectionDetails = connectionDetails,
  schema = resultsSchema,
  purgeSiteDataBeforeUploading =FALSE,
  zipFileName = c(
    "~/Downloads/OpenClaims_Results_CES/Results_drug_study_OPENCLAIMS_1.zip",
    #"~/Downloads/OpenClaims_Results_CES/Results_drug_study_OPENCLAIMS_2.zip",
    #"~/Downloads/OpenClaims_Results_CES/Results_drug_study_OPENCLAIMS_3.zip",
    #"~/Downloads/OpenClaims_Results_CES/Results_drug_study_OPENCLAIMS_4.zip",
    #"~/Downloads/OpenClaims_Results_CES/Results_drug_study_OPENCLAIMS_5.zip",
    #"~/Downloads/OpenClaims_Results_CES/Results_drug_study_OPENCLAIMS_6.zip",
    #"~/Downloads/OpenClaims_Results_CES/Results_drug_study_OPENCLAIMS_8.zip",
    #"~/Downloads/OpenClaims_Results_CES/Results_drug_study_OPENCLAIMS_9.zip",
    #"~/Downloads/OpenClaims_Results_CES/Results_drug_study_OPENCLAIMS_10.zip",
    NULL
  ),
  specifications = tibble::tibble(read.csv("inst/settings/ResultsModelSpecs1.csv")) %>%
    # filter(!tableName %in% c("database",
    #                          "covariate_analysis",
    #                          "negative_control_outcome",
    #                          "outcome_of_interest",
    #                          "results_date_time", # don't upload shared tables
    #                          NULL,
    #                          # "covariate",
    #                          # "attrition",
    #                          # "cohort_method_result",
    #                          # "preference_score_dist",
    #                          NULL,
    #                          "kaplan_meier_dist", # not uploading KM curves for now; takes too long
    #                          "diagnostics", # will upload diagnostics later once generated
    #                          NULL)
    filter(tableName %in% c(#"covariate_balance",
                            "kaplan_meier_dist",
                            NULL) # re-do balance table + upload KM curves
           ),
  #tempFolder = "d:/uploadTemp/" # folder for temporary data storage during upload
  tempFolder = "~/Downloads/uploadTemp/",
  defaultChunkSize = 5e6,
  forceOverWriteOfSpecifications = FALSE,
  useTempTable = TRUE
)

## Aug 2024: upload KM curves for open claims results
LegendT2dm::uploadResultsToDatabase(
  connectionDetails = connectionDetails,
  schema = resultsSchema,
  purgeSiteDataBeforeUploading =FALSE,
  zipFileName = c(
    "d:/LegendT2dm_OpenClaims_results/Results_drug_study_OPENCLAIMS_1.zip",
    "d:/LegendT2dm_OpenClaims_results/Results_drug_study_OPENCLAIMS_5.zip", # prioritize GLP1RAs in chunk 5-8
    "d:/LegendT2dm_OpenClaims_results/Results_drug_study_OPENCLAIMS_6.zip",
    #"d:/LegendT2dm_OpenClaims_results/Results_drug_study_OPENCLAIMS_8.zip",
    #"d:/LegendT2dm_OpenClaims_results/Results_drug_study_OPENCLAIMS_9.zip",
    #"d:/LegendT2dm_OpenClaims_results/Results_drug_study_OPENCLAIMS_10.zip",
    NULL
  ),
  specifications = tibble::tibble(read.csv("inst/settings/ResultsModelSpecs1.csv")) %>%
    filter(tableName %in% c("kaplan_meier_dist",
                            NULL)
    ),
  tempFolder = "E:/uploadTemp/", # folder for temporary data storage during upload
  defaultChunkSize = 1e5 # force small chunk size for KM curve table
)


## Only upload results for "main" OT1/ITT cohorts, to save some time
#library(dplyr)
allCohorts = readr::read_csv("inst/settings/drugCohortsToCreate.csv")
selectedCohorts = bind_rows(
  allCohorts %>%
    filter(stringr::str_ends(atlasName, "main")),
  allCohorts %>%
    filter(stringr::str_starts(name, "sglt2i"), stringr::str_ends(atlasName, "main ot2"))
)

selectedCohortIds = selectedCohorts %>% pull(cohortId)

LegendT2dm::uploadResultsToDatabase(
  connectionDetails = connectionDetails,
  schema = resultsSchema,
  purgeSiteDataBeforeUploading =FALSE,
  zipFileName = c(
    #"d:/LegendT2dm_OpenClaims_results/Results_drug_study_OPENCLAIMS_10.zip", # tried this; should have worked
    "d:/LegendT2dm_OpenClaims_results/Results_drug_study_OPENCLAIMS_4.zip",
    "d:/LegendT2dm_OpenClaims_results/Results_drug_study_OPENCLAIMS_5.zip", # prioritize GLP1RAs in chunk 5-8
    #"d:/LegendT2dm_OpenClaims_results/Results_drug_study_OPENCLAIMS_6.zip",
    #"d:/LegendT2dm_OpenClaims_results/Results_drug_study_OPENCLAIMS_8.zip", # this has some GLP1 and SGLT2
    #"d:/LegendT2dm_OpenClaims_results/Results_drug_study_OPENCLAIMS_9.zip", # need to re-upload SGLT2i
    NULL
  ),
  specifications = tibble::tibble(read.csv("inst/settings/ResultsModelSpecs1.csv")) %>%
    filter(!tableName %in% c("database",
                             "covariate_analysis",
                             "negative_control_outcome",
                             "outcome_of_interest",
                             "results_date_time", # don't upload shared tables
                             NULL,
                             # "covariate",
                             # "attrition",
                             # "cohort_method_result",
                             # "preference_score_dist",
                             NULL,
                             "kaplan_meier_dist", # not uploading KM curves for now; takes too long
                             "diagnostics", # will upload diagnostics later once generated
                             NULL)
    ),
  tempFolder = "d:/uploadTemp/", # folder for temporary data storage during upload
  forceOverWriteOfSpecifications = TRUE,
  exposureCohortIds = selectedCohortIds
)


# cana vs empa for OptumEHR
selectedCohortIds = c(311100000, 331100000,
                      312100000, 332100000) # cana vs empa stuff

# LegendT2dm::uploadResultsToDatabase(
#   connectionDetails = connectionDetails,
#   schema = resultsSchema,
#   purgeSiteDataBeforeUploading =FALSE,
#   zipFileName = c(
#     "E:/LegendT2dmOutput_optum_ehr_drug2/drug/export/Results_drug_study_OptumEHR.zip",
#     NULL
#   ),
#   specifications = tibble::tibble(read.csv("inst/settings/ResultsModelSpecs1.csv")) %>%
#     filter(tableName %in% c("covariate_balance")),
#   tempFolder = "d:/uploadTemp/",
#   exposureCohortIds = selectedCohortIds
# )

## try to upload just that chunk between cana vs empa OT1 ....
LegendT2dm::uploadResultsToDatabaseFromCsv(
  connectionDetails = connectionDetails,
  schema = resultsSchema,
  purgeSiteDataBeforeUploading =FALSE,
  exportFolder = "E:/LegendT2dm_OptumEhr_temp/",
  tableNames = c("covariate_balance"),
  specifications = tibble::tibble(read.csv("inst/settings/ResultsModelSpecs1.csv")) %>%
    filter(tableName %in% c("covariate_balance")),
  chunkSize = 1e6,
  forceOverWriteOfSpecifications = TRUE
)

# try to upload just covariate balance file for VA
LegendT2dm::uploadResultsToDatabaseFromCsv(
  connectionDetails = connectionDetails,
  schema = resultsSchema,
  purgeSiteDataBeforeUploading =TRUE,
  exportFolder = "~/Downloads/drug_VAOMOP/",
  tableNames = c("covariate_balance"),
  specifications = tibble::tibble(read.csv("inst/settings/ResultsModelSpecs1.csv")) %>%
    filter(tableName %in% c("covariate_balance")),
  chunkSize = 5e5,
  forceOverWriteOfSpecifications = FALSE
)



# locally examine OptumEHR drug-v-drug results
optumEHRZipFile =  "E:/LegendT2dmOutput_optum_ehr_drug2/drug/export/Results_drug_study_OptumEHR.zip"
LegendT2dm::prepareForEvidenceExplorer(resultsZipFile = optumEHRZipFile,
                                       dataFolder = "E:/LegendT2dmOutput_optum_ehr_drug2/EvidenceExplorer/")



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

