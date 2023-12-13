# study diagnostics & meta analysis for drug-level CES

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

# set indication Id here
# doing this for all drug-v-drug
## OPEN CLAIMS results still pending...
indicationId = "drug"
tcoFileName = sprintf("%sTcosOfInterest.csv", indicationId)

resultsSchema = "legendt2dm_drug_results"

tcs <- read.csv(system.file("settings", tcoFileName,
                            package = "LegendT2dm")) %>%
  dplyr::select(targetId, comparatorId)

outcomeIds <- read.csv(system.file("settings", "OutcomesOfInterest.csv",
                                   package = "LegendT2dm")) %>%
  dplyr::select(cohortId) %>% pull(cohortId)

# databaseIds <- c("OptumEHR", "MDCR", "OptumDod", "UK_IMRD", "MDCD",
#                  "CCAE", "US_Open_Claims", "SIDIAP", "VA-OMOP", "France_LPD",
#                  "CUIMC", "HK-HA-DM", "HIC Dundee", "Germany_DA")

databaseIdsDrug <- c("OptumEHR", "MDCR", "OptumDod", "MDCD",
                     "CCAE", "OPENCLAIMS", "DA_Germany", "LPD_France")

analysisIds <- c( 1, 2, 3, 4, 5, 6, 7, 8, 9,
                  11,12,13,14,15,16,17,18,19)

diagnostics <- makeDiagnosticsTable(connection = connection,
                                    resultsDatabaseSchema = resultsSchema,
                                    tcs = tcs,
                                    outcomeIds = outcomeIds,
                                    analysisIds = analysisIds,
                                    databaseIds = databaseIdsDrug)

saveRDS(diagnostics, "extra/diagnostics.rds")
DatabaseConnector::disconnect(connection)

# Start of diagnostics processing & do meta analysis
## NOTE: still waiting for results from Open Claims! Done partially for now

diagnostics <- readRDS("extra/diagnostics.rds")

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
  filter(databaseId != "OPENCLAIMS")

# (1) using LEGEND-HTN data-driven diagnostics rule
doMetaAnalysis(legendT2dmConnectionDetails,
               resultsDatabaseSchema = "legendt2dm_drug_results",
               maName = "Meta-analysis1",
               maExportFolder = "maHtn",
               diagnosticsFilter = diagnosticsHtn,
               indicationId = "drug",
               maxCores = 8)

# (2) using literature-common rules of thumb
doMetaAnalysis(legendT2dmConnectionDetails,
               resultsDatabaseSchema = "legendt2dm_drug_results",
               maName = "Meta-analysis2",
               maExportFolder = "maLit",
               diagnosticsFilter = diagnosticsLit,
               indicationId = "drug",
               maxCores = 8)

# (3) exclude Open Claims
doMetaAnalysis(legendT2dmConnectionDetails,
               resultsDatabaseSchema = "legendt2dm_drug_results",
               maName = "Meta-analysis3",
               maExportFolder = "maLitNoOc",
               diagnosticsFilter = diagnosticsLit,
               indicationId = "drug",
               maxCores = 4)

doMetaAnalysis(legendT2dmConnectionDetails,
               resultsDatabaseSchema = "legendt2dm_drug_results",
               maName = "Meta-analysis0",
               maExportFolder = "maAll",
               diagnosticsFilter = NULL,
               indicationId = "drug",
               maxCores = 4)

# connect to results database and upload meta analysis results
writeableConnectionDetails <- DatabaseConnector::createConnectionDetails(
  dbms = "postgresql",
  server = paste(keyring::key_get("ohdsiPostgresServer"),
                 keyring::key_get("ohdsiPostgresShinyDatabase"),
                 sep = "/"),
  user = keyring::key_get("ohdsiPostgresUser"),
  password = keyring::key_get("ohdsiPostgresPassword"))

LegendT2dm::uploadResultsToDatabase(
  connectionDetails = writeableConnectionDetails,
  schema = "legendt2dm_drug_results",
  purgeSiteDataBeforeUploading = TRUE,
  zipFileName = c(
    "maAll/Results_drug_study_Meta-analysis0.zip",
    # "maHtn/Results_drug_study_Meta-analysis1.zip",
    # "maLit/Results_drug_study_Meta-analysis2.zip",
    #"maLitNoOc/Results_drug_study_Meta-analysis3.zip",
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

