# OHDSI shinydb legendt2dm read-only credentials
appConnectionDetails <- DatabaseConnector::createConnectionDetails(
  dbms = "postgresql",
  server = paste(keyring::key_get("legendt2dmServer"),
                 keyring::key_get("legendt2dmDatabase"),
                 sep = "/"),
  user = keyring::key_get("legendt2dmUser"),
  password = keyring::key_get("legendt2dmPassword"))

CohortDiagnostics::launchDiagnosticsExplorer(connectionDetails = appConnectionDetails,
                                      resultsDatabaseSchema = "legendt2dm_class_diagnostics")

CohortDiagnostics::launchDiagnosticsExplorer(connectionDetails = appConnectionDetails,
                                      resultsDatabaseSchema = "legendt2dm_outcome_diagnostics")
