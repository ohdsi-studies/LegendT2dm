# OHDSI shinydb legendt2dm read-only credentials
appConnectionDetails <- DatabaseConnector::createConnectionDetails(
  dbms = "postgresql",
  server = paste(keyring::key_get("legendt2dmServer"),
                 keyring::key_get("legendt2dmDatabase"),
                 sep = "/"),
  user = keyring::key_get("legendt2dmUser"),
  password = keyring::key_get("legendt2dmPassword"))

LegendT2dm::launchDiagnosticsExplorer(connectionDetails = appConnectionDetails,
                                      resultsDatabaseSchema = "legendt2dm_class_diagnostics")

LegendT2dm::launchDiagnosticsExplorer(connectionDetails = appConnectionDetails,
                                      resultsDatabaseSchema = "legendt2dm_outcome_diagnostics")

dataFolder <- "~/Dropbox/Projects/LegendT2dm_Diagnostics/CCAE/cohortDiagnosticsExport"
CohortDiagnostics::preMergeDiagnosticsFiles(dataFolder = dataFolder)
LegendT2dm::launchDiagnosticsExplorer(dataFolder = dataFolder)

dataFolder <- "~/Dropbox/Projects/LegendT2dm_Diagnostics/CCAE/outcomeDiagnosticsExport"
CohortDiagnostics::preMergeDiagnosticsFiles(dataFolder = dataFolder)
LegendT2dm::launchDiagnosticsExplorer(dataFolder = dataFolder)
CohortDiagnostics::launchDiagnosticsExplorer(dataFolder = dataFolder)

dataFolder <- "~/Dropbox/Projects/LegendT2dm_Diagnostics/MDCR/cohortDiagnosticsExport"
CohortDiagnostics::preMergeDiagnosticsFiles(dataFolder = dataFolder)
LegendT2dm::launchDiagnosticsExplorer(dataFolder = dataFolder)

# Look at test (metformin) cohorts
dataFolder <- "~/Dropbox/Projects/LegendT2dm_Diagnostics/CCAE/testCohortDiagnosticsExport"
CohortDiagnostics::preMergeDiagnosticsFiles(dataFolder = dataFolder)
LegendT2dm::launchDiagnosticsExplorer(dataFolder = dataFolder)
