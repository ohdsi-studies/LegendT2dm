# Copyright 2020 Observational Health Data Sciences and Informatics
#
# This file is part of Andromeda
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

# Format and check code
OhdsiRTools::formatRFolder()
OhdsiRTools::checkUsagePackage("LegendT2dm")
OhdsiRTools::updateCopyrightYearFolder()
devtools::spell_check()

baseUrl <- "http://atlas-covid19.ohdsi.org:80/WebAPI"
baseUrl <- keyring::key_get("baseUrl")


# Import outcome definitions
ROhdsiWebApi::authorizeWebApi(baseUrl = baseUrl, authMethod = "windows")
ROhdsiWebApi::insertCohortDefinitionSetInPackage(fileName = "inst/settings/OutcomesOfInterest.csv",
                                                baseUrl = baseUrl,
                                                insertTableSql = FALSE,
                                                insertCohortCreationR = FALSE,
                                                generateStats = FALSE,
                                                packageName = "LegendT2dm")


# # Create manual and vignette
# unlink("extras/LegendT2dm")
# shell("R CMD Rd2pdf ./ --output=extras/LegendT2dm")
#
# dir.create("inst/doc", recursive = TRUE)
# rmarkdown::render("vignettes/UsingLegendT2dm.Rmd",
#                   output_file = "../inst/doc/UsingLegendT2dm.pdf",
#                   rmarkdown::pdf_document(latex_engine = "pdflatex",
#                                           toc = TRUE,
#                                           number_sections = TRUE))
# unlink("inst/doc/UsingLegendT2dm.tex")
#
# pkgdown::build_site(preview = FALSE)
# OhdsiRTools::fixHadesLogo()
#
# # Release package:
# devtools::check_win_devel()
#
# devtools::check_rhub()
#
# devtools::release()

### Manage OHDSI Postgres server
connectionDetails <- DatabaseConnector::createConnectionDetails(
  dbms = "postgresql",
  server = paste(keyring::key_get("ohdsiPostgresServer"),
                 keyring::key_get("ohdsiPostgresShinyDatabase"),
                 sep = "/"),
  user = keyring::key_get("ohdsiPostgresUser"),
  password = keyring::key_get("ohdsiPostgresPassword"))

grantPermission <- function(connectionDetails,schema) {
  sql <- paste0("grant select on all tables in schema ", schema, " to legendt2dm_readonly;")
  connection <- DatabaseConnector::connect(connectionDetails)
  DatabaseConnector::executeSql(connection, sql)
  DatabaseConnector::disconnect(connection)
}

createPsModelAssessmentTable <- function(connectionDetails, schema) {
  sql <- paste0("SET search_path TO ", schema, ";")
  connection <- DatabaseConnector::connect(connectionDetails)
  DatabaseConnector::executeSql(connection, sql)
  pathToSql <-
    system.file("sql", "postgresql", "CreatePsAssessmentTables.sql", package = "LegendT2dm")
  sql <- SqlRender::readSql(pathToSql)
  DatabaseConnector::executeSql(connection, sql)
  DatabaseConnector::disconnect(connection)
}

Sys.setenv(POSTGRES_PATH = "C:\\Program Files\\PostgreSQL\\13\\bin")

# Create cohort diagnostics on remote database
if (FALSE) { # Do this once!

  # Class

  classSchema <- "legendt2dm_class_diagnostics"

  # CohortDiagnostics::createResultsDataModel(connectionDetails = connectionDetails, schema = classSchema)

  createPsModelAssessmentTable(connectionDetails = connectionDetails, schema = classSchema)

  grantPermission(connectionDetails = connectionDetails, schema = classSchema)

  CohortDiagnostics::uploadResults(
    connectionDetails = connectionDetails,
    schema = classSchema,
    zipFileName = "d:/LegendT2dmOutput_ccae7/classCohortDiagnosticsExport/Results_CCAE.zip")

  CohortDiagnostics::uploadResults(
    connectionDetails = connectionDetails,
    schema = classSchema,
    zipFileName = "d:/LegendT2dmOutput_mdcr7/classCohortDiagnosticsExport/Results_MDCR.zip")

  CohortDiagnostics::uploadResults(
    connectionDetails = connectionDetails,
    schema = classSchema,
    zipFileName = "d:/LegendT2dmOutput_optum_ehr7/classCohortDiagnosticsExport/Results_OptumEhr.zip")

#  #  PS Assessment
#
#   specification <- read.csv("inst/settings/PsAssessmentModelSpecs.csv")
#
#   LegendT2dm::uploadResults(
#     connectionDetails = connectionDetails,
#     schema = classSchema,
#     convertFromCamelCase = TRUE,
#     purgeSiteDataBeforeUploading = FALSE,
#     zipFileName = "~/Dropbox/Projects/LegendT2dm_Diagnostics/CCAE/assessPropensityScoreExport/classPropensityModelAssessment_CCAE.zip",
#     specifications = tibble::tibble(read.csv("inst/settings/PsAssessmentModelSpecs.csv"))
#   )

  conn <- DatabaseConnector::connect(connectionDetails = connectionDetails)
  sql <- "SELECT * FROM legendt2dm_class_diagnostics.ps_auc_assessment;"
  tmp <- DatabaseConnector::querySql(conn, sql)
  DatabaseConnector::disconnect(conn)
   # Outcome

  outcomeSchema <- "legendt2dm_outcome_diagnostics"
  CohortDiagnostics::createResultsDataModel(connectionDetails = connectionDetails, schema = outcomeSchema)

  grantPermission(connectionDetails = connectionDetails, schema = outcomeSchema)

  CohortDiagnostics::uploadResults(
    connectionDetails = connectionDetails,
    schema = outcomeSchema,
    zipFileName = "d:/LegendT2dmOutput_ccae7/outcomeCohortDiagnosticsExport/Results_CCAE.zip")

  CohortDiagnostics::uploadResults(
    connectionDetails = connectionDetails,
    schema = outcomeSchema,
    zipFileName = "d:/LegendT2dmOutput_mdcr7/outcomeCohortDiagnosticsExport/Results_MDCR.zip")

  CohortDiagnostics::uploadResults(
    connectionDetails = connectionDetails,
    schema = outcomeSchema,
    zipFileName = "d:/LegendT2dmOutput_optum_ehr7/outcomeCohortDiagnosticsExport/Results_OptumEhr.zip")

}
