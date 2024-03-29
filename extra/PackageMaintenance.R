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


# Create SQL files for data models
createDataModelSqlFile(specifications = read.csv("inst/settings/ResultsModelSpecs.csv"),
                       fileName = "inst/sql/postgresql/CreateResultsTables.sql")

createDataModelSqlFile(specifications = read.csv("inst/settings/PsAssessmentModelSpecs.csv"),
                       fileName = "inst/sql/postgresql/CreatePsAssessmentTables.sql")

createDataModelSqlFile(specifications = read.csv(system.file("settings",
                                                             "resultsDataModelSpecification.csv",
                                                             package = "CohortDiagnostics")),
                       fileName = "inst/sql/postgresql/CreateCohortDiagnosticsTables.sql")

### Manage OHDSI Postgres server
connectionDetails <- DatabaseConnector::createConnectionDetails(
  dbms = "postgresql",
  server = paste(keyring::key_get("ohdsiPostgresServer"),
                 keyring::key_get("ohdsiPostgresShinyDatabase"),
                 sep = "/"),
  user = keyring::key_get("ohdsiPostgresUser"),
  password = keyring::key_get("ohdsiPostgresPassword"))

Sys.setenv(POSTGRES_PATH = "C:\\Program Files\\PostgreSQL\\13\\bin")
