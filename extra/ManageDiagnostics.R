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
                 "CUIMC", "HK-HA-DM", "HIC Dundee", "Germany_DA")

analysisIds <- c( 1, 2, 3, 4, 5, 6, 7, 8, 9,
                 11,12,13,14,15,16,17,18,19)

diagnostics <- makeDiagnosticsTable(connection = connection,
                                    resultsDatabaseSchema = "legendt2dm_class_results",
                                    tcs = tcs,
                                    outcomeIds = outcomeIds,
                                    analysisIds = analysisIds,
                                    databaseIds = databaseIds)

saveRDS(diagnostics, "diagnostics.rds")
DatabaseConnector::disconnect(connection)

# Start of diagnostics processing

diagnostics <- readRDS("diagnostics.rds")

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

diagnosticsLitNoOc <- diagnosticsLit %>%
  filter(databaseId != "US_Open_Claims")


doMetaAnalysis(legendT2dmConnectionDetails,
               resultsDatabaseSchema = "legendt2dm_class_results",
               maName = "Meta-analysis1",
               maExportFolder = "maHtn",
               diagnosticsFilter = diagnosticsHtn,
               maxCores = 4)

doMetaAnalysis(legendT2dmConnectionDetails,
               resultsDatabaseSchema = "legendt2dm_class_results",
               maName = "Meta-analysis2",
               maExportFolder = "maLit",
               diagnosticsFilter = diagnosticsLit,
               maxCores = 4)

doMetaAnalysis(legendT2dmConnectionDetails,
               resultsDatabaseSchema = "legendt2dm_class_results",
               maName = "Meta-analysis3",
               maExportFolder = "maLitNoOc",
               diagnosticsFilter = diagnosticsLit,
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
    "maLitNoOc/Results_class_study_Meta-analysis3.zip",
    NULL
  ),
  specifications = tibble::tibble(read.csv("inst/settings/ResultsModelSpecs.csv"))
)

# # Remove no outcomes
# diagnostics <- diagnostics %>% filter(is.finite(mdrr))
# nrow(diagnostics)
#
# # Remove MDRR > 2
# diagnostics <- diagnostics %>% filter(mdrr < 2)
# nrow(diagnostics)
#
# ggplot(diagnostics,
#        aes(x=maxAbsStdDiffMean, fill=databaseId)) +
#   geom_histogram() +
#   geom_vline(xintercept=c(0.1,0.2), linetype="dotted")
#
# # Remove stdDiff > 0.1
# diagnostics <- diagnostics %>% filter(maxAbsStdDiffMean < 0.1)
# nrow(diagnostics)
#
# diagnostics %>% group_by(databaseId) %>% tally()
#
# ggplot(diagnostics,
#        aes(x=maxAbsStdDiffMean, fill=databaseId)) +
#   geom_histogram(right = TRUE, bins = 101) +
#   geom_vline(xintercept=c(0.1,0.2), linetype="dotted")

