# LEGEND-T2DM evidence explorer to check out the results

Sys.setenv(DATABASECONNECTOR_JAR_FOLDER="d:/Drivers")

# ONLY NEED TO RUN ONCE
# keyring::key_set_with_value("legendt2dmUser", password = "legendt2dm_readonly")
# keyring::key_set_with_value("legendt2dmPassword", password = "AB93DFCC42D632")
# keyring::key_set_with_value("legendt2dmServer", password = "shinydb.cqnqzwtn5s1q.us-east-1.rds.amazonaws.com")
# keyring::key_set_with_value("legendt2dmDatabase", password = "shinydb")

legendT2dmConnectionDetails <- DatabaseConnector::createConnectionDetails(
  dbms = "postgresql",
  server = paste(keyring::key_get("legendt2dmServer"),
                 keyring::key_get("legendt2dmDatabase"),
                 sep = "/"),
  user = keyring::key_get("legendt2dmUser"),
  password = keyring::key_get("legendt2dmPassword"))

# results
## set `cohorts = 'drug'` for drug-vs-drug results
LegendT2dmEvidenceExplorer::launchEvidenceExplorer(connectionDetails = legendT2dmConnectionDetails,
                                                   cohorts = 'class',
                                                   blind = FALSE)
# cohort diagnostics
## set `cohorts = 'drug'` for drug-vs-drug cohorts
LegendT2dmCohortExplorer::launchCohortExplorer(connectionDetails = legendT2dmConnectionDetails,
                                               cohorts = 'class')

