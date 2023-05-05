# It is recommended to specify the environmental variable:
#
#    DATABASECONNECTOR_JAR_FOLDER=<folder-of-your-choice>
#
# in `.Renviron` located in the user's home directory.
# Then to install the required `postgresql` JDBC drivers, use:
#
#    DatabaseConnector::downloadJdbcDrivers(dbms = "postgresql")
#
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
