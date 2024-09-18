# LEGEND-T2DM evidence explorer to check out the results

legendT2dmConnectionDetails <- DatabaseConnector::createConnectionDetails(
  dbms = "postgresql",
  server = paste(keyring::key_get("legendt2dmServer"),
                 keyring::key_get("legendt2dmDatabase"),
                 sep = "/"),
  user = keyring::key_get("legendt2dmUser"),
  password = keyring::key_get("legendt2dmPassword"))

LegendT2dmEvidenceExplorer::launchEvidenceExplorer(connectionDetails = legendT2dmConnectionDetails,
                                                   cohorts = 'drug',
                                                   blind = FALSE)

LegendT2dmCohortExplorer::launchCohortExplorer(connectionDetails = legendT2dmConnectionDetails,
                                               cohorts = "drug") #'drug')
