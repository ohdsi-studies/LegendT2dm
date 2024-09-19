library(dplyr)
library(LegendT2dm)

legendT2dmConnectionDetails <- DatabaseConnector::createConnectionDetails(
  dbms = "postgresql",
  server = paste(keyring::key_get("legendt2dmServer"),
                 keyring::key_get("legendt2dmDatabase"),
                 sep = "/"),
  user = keyring::key_get("legendt2dmUser"),
  password = keyring::key_get("legendt2dmPassword"))

connection <- DatabaseConnector::connect(legendT2dmConnectionDetails)

tcs <- read.csv(system.file("settings", "classTcosOfInterest.csv",
                            package = "LegendT2dm")) %>%
  dplyr::select(targetId, comparatorId)
outcomeIds <- read.csv(system.file("settings", "OutcomesOfInterest.csv",
                                   package = "LegendT2dm")) %>%
  dplyr::select(cohortId) %>% pull(cohortId)

databaseIds <- c("OptumEHR", "MDCR", "OptumDod", "UK_IMRD", "MDCD",
                 "CCAE", "US_Open_Claims", "SIDIAP", "VA-OMOP", "France_LPD",
                 "CUIMC", "HK-HA-DM", "HIC Dundee", "Germany_DA", "TMUCRD")

analysisIds <- c( 1, 2, 3, 4, 5, 6, 7, 8, 9,
                 11,12,13,14,15,16,17,18,19)

diagnostics <- makeDiagnosticsTable(connection = connection,
                                    resultsDatabaseSchema = "legendt2dm_class_results",
                                    tcs = tcs,
                                    outcomeIds = outcomeIds,
                                    analysisIds = analysisIds,
                                    databaseIds = databaseIds)
DatabaseConnector::disconnect(connection)

saveRDS(diagnostics, "diagnostics.rds")
diagnostics <- readRDS("diagnostics.rds")

diagnosticsCsv <- diagnostics %>%
  mutate(anyOutcomes = ifelse(anyOutcomes, 1, 0)) %>%
  mutate(pass = ( # Add LEGEND-HTN criteria
    (is.finite(mdrr)) &
      (!is.na(maxAbsStdDiffMean)) &
      (mdrr < 4.0) &
      (maxAbsStdDiffMean < 0.15) &
      (minEquipoise > 0.25))) %>%
  mutate(pass = ifelse(pass, 1, 0)) %>%
  select(-minBoundOnMdrr) %>%
  mutate(ease = 0, ## TODO
         criteria = "legend-htn: mdrr < 4.0 & sdm < 0.15 & equip > 0.25")

colnames(diagnosticsCsv) <- SqlRender::camelCaseToSnakeCase(colnames(diagnosticsCsv))
readr::write_csv(diagnosticsCsv, "diagnostics.csv")
DatabaseConnector::createZipFile(zipFile = "diagnostics.zip", files = "diagnostics.csv")

# Add to shinydb

connectionDetails <- DatabaseConnector::createConnectionDetails(
  dbms = "postgresql",
  server = paste(keyring::key_get("ohdsiPostgresServer"),
                 keyring::key_get("ohdsiPostgresShinyDatabase"),
                 sep = "/"),
  user = keyring::key_get("ohdsiPostgresUser"),
  password = keyring::key_get("ohdsiPostgresPassword"))

connection <- DatabaseConnector::connect(connectionDetails)
DatabaseConnector::executeSql(connection, sql = "
  SET search_path TO legendt2dm_class_results;
  DROP TABLE IF EXISTS diagnostics;
  CREATE TABLE diagnostics (
     database_id VARCHAR(255) NOT NULL,
     target_id BIGINT NOT NULL,
     comparator_id BIGINT NOT NULL,
     outcome_id BIGINT NOT NULL,
     analysis_id INTEGER NOT NULL,
     any_outcomes INTEGER ,
     mdrr NUMERIC ,
     max_abs_std_diff_mean NUMERIC ,
     min_equipoise NUMERIC ,
     ease NUMERIC ,
     pass INTEGER ,
     criteria VARCHAR(255) ,
     PRIMARY KEY(database_id, target_id, comparator_id, outcome_id, analysis_id)
  );")
DatabaseConnector::disconnect(connection)

resultsSchema <- "legendt2dm_class_results"
LegendT2dm::uploadResultsToDatabase(
  connectionDetails = connectionDetails,
  schema = resultsSchema,
  purgeSiteDataBeforeUploading = FALSE,
  zipFileName = "diagnostics.zip",
  specifications = tibble::tibble(read.csv("inst/settings/ResultsModelSpecs.csv")))

# Start of diagnostics processing

diagnosticsHtn <- diagnostics %>%
  filter(is.finite(mdrr)) %>%
  filter(!is.na(maxAbsStdDiffMean)) %>%
  mutate(pass = (
    (mdrr < 4.0) &
      (maxAbsStdDiffMean < 0.15) &
      (minEquipoise > 0.25)
  ))

diagnosticsLit <- diagnostics %>%
  filter(is.finite(mdrr)) %>%
  filter(!is.na(maxAbsStdDiffMean)) %>%
  mutate(pass = (
    (mdrr < 10.0) &
    (maxAbsStdDiffMean < 0.10) &
    (minEquipoise > 0.5)
  ))

diagnosticsHtnNoOc <- diagnosticsHtn %>%
  filter(databaseId != "US_Open_Claims")

diagnosticsLitNoOc <- diagnosticsLit %>%
  filter(databaseId != "US_Open_Claims")

# (1) using LEGEND-HTN data-driven diagnostics rule

doMetaAnalysis(legendT2dmConnectionDetails,
               resultsDatabaseSchema = "legendt2dm_class_results",
               maName = "Meta-analysis1",
               maExportFolder = "maHtn",
               diagnosticsFilter = diagnosticsHtn,
               maxCores = 4)

# (2) using literature-common rules of thumb
doMetaAnalysis(legendT2dmConnectionDetails,
               resultsDatabaseSchema = "legendt2dm_class_results",
               maName = "Meta-analysis2",
               maExportFolder = "maLit",
               diagnosticsFilter = diagnosticsLit,
               maxCores = 4)

# (3) exclude Open Claims
doMetaAnalysis(legendT2dmConnectionDetails,
               resultsDatabaseSchema = "legendt2dm_class_results",
               maName = "Meta-analysis3",
               maExportFolder = "maHtnNoOc",
               diagnosticsFilter = diagnosticsHtnNoOc,
               maxCores = 4)

doMetaAnalysis(legendT2dmConnectionDetails,
               resultsDatabaseSchema = "legendt2dm_class_results",
               maName = "Meta-analysis4",
               maExportFolder = "maLitNoOc",
               diagnosticsFilter = diagnosticsLitNoOc,
               maxCores = 4)

doMetaAnalysis(legendT2dmConnectionDetails,
               resultsDatabaseSchema = "legendt2dm_class_results",
               maName = "Meta-analysis0",
               maExportFolder = "maAll",
               diagnosticsFilter = NULL,
               maxCores = 4)

writeableConnectionDetails <- DatabaseConnector::createConnectionDetails(
  dbms = "postgresql",
  server = paste(keyring::key_get("ohdsiPostgresServer"),
                 keyring::key_get("ohdsiPostgresShinyDatabase"),
                 sep = "/"),
  user = keyring::key_get("ohdsiPostgresUser"),
  password = keyring::key_get("ohdsiPostgresPassword"))

LegendT2dm::uploadResultsToDatabase(
  connectionDetails = writeableConnectionDetails,
  schema = "legendt2dm_class_results",
  purgeSiteDataBeforeUploading = TRUE,
  zipFileName = c(
    "maAll/Results_class_study_Meta-analysis0.zip",
    "maHtn/Results_class_study_Meta-analysis1.zip",
    "maLit/Results_class_study_Meta-analysis2.zip",
    "maHtnNoOc/Results_class_study_Meta-analysis3.zip",
    "maLitNoOc/Results_class_study_Meta-analysis4.zip",
    NULL
  ),
  specifications = tibble::tibble(read.csv("inst/settings/ResultsModelSpecs.csv"))
)
