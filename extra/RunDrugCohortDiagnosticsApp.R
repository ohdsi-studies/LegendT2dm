# launch cohort diagnostics app locally

outputFolder =  "E:/LegendT2dmOutput_mdcr_DPP4I_2"
cohortDiagnosticsFolder = "/DPP4I/cohortDiagnosticsExport"
#exportedFile = "Results_DPP4I_exposures_MDCR.zip"

CohortDiagnostics::preMergeDiagnosticsFiles(dataFolder = file.path(outputFolder,
                                                                   cohortDiagnosticsFolder))

CohortDiagnostics::launchDiagnosticsExplorer(dataFolder =  file.path(outputFolder,
                                                                     cohortDiagnosticsFolder))

# CohortDiagnostics::launchDiagnosticsExplorer(connectionDetails = appConnectionDetails,
#                                              resultsDatabaseSchema = "legendt2dm_class_diagnostics")
#
# CohortDiagnostics::launchDiagnosticsExplorer(connectionDetails = appConnectionDetails,
#                                              resultsDatabaseSchema = "legendt2dm_outcome_diagnostics")
