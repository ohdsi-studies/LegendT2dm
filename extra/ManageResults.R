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

Sys.setenv(POSTGRES_PATH = "C:\\Program Files\\PostgreSQL\\13\\bin")

# Class CER results

resultsSchema <- "legendt2dm_class_results"
LegendT2dm::createDataModelOnServer(connectionDetails = connectionDetails,
                                    schema = resultsSchema,
                                    sqlFileName = "CreateResultsTables.sql")

LegendT2dm::grantPermissionOnServer(connectionDetails = connectionDetails,
                                    user = "legend", schema = resultsSchema)

LegendT2dm::grantPermissionOnServer(connectionDetails = connectionDetails,
                                    user = "legendt2dm_readonly", schema = resultsSchema)

LegendT2dm::uploadResultsToDatabase(
  connectionDetails = connectionDetails,
  schema = resultsSchema,
  purgeSiteDataBeforeUploading = FALSE,
  zipFileName = c(
    "d:/LegendT2dmOutput_mdcr3/class/export/Results_class_study_MDCR.zip"),
  specifications = tibble::tibble(read.csv("inst/settings/ResultsModelSpecs.csv"))
)
