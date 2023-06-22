Sys.setenv(POSTGRES_PATH = "C:\\Program Files\\PostgreSQL\\13\\bin")

# Class diagnostics

classSchema <- "legendt2dm_class_diagnostics"
LegendT2dm::createDataModelOnServer(connectionDetails = connectionDetails,
                                    schema = classSchema,
                                    sqlFileName = "CreateCohortDiagnosticsTables.sql")

LegendT2dm::grantPermissionOnServer(connectionDetails = connectionDetails,
                                    user = "legend", schema = classSchema)

LegendT2dm::grantPermissionOnServer(connectionDetails = connectionDetails,
                                    user = "legendt2dm_readonly", schema = classSchema)

CohortDiagnostics::uploadResults(
  connectionDetails = connectionDetails,
  schema = classSchema,
  zipFileName = "d:/LegendT2dmOutput_optum_ehr1/class/cohortDiagnosticsExport/Results_class_exposures_OptumEHR.zip")

CohortDiagnostics::uploadResults(
  connectionDetails = connectionDetails,
  schema = classSchema,
  zipFileName = "d:/LegendT2dmOutput_optum_dod1/class/cohortDiagnosticsExport/Results_class_exposures_OptumDod.zip")

CohortDiagnostics::uploadResults(
  connectionDetails = connectionDetails,
  schema = classSchema,
  zipFileName = "d:/LegendT2dmOutput_mdcd1/class/cohortDiagnosticsExport/Results_class_exposures_MDCD.zip")

CohortDiagnostics::uploadResults(
  connectionDetails = connectionDetails,
  schema = classSchema,
  zipFileName = "d:/LegendT2dmOutput_mdcr1/class/cohortDiagnosticsExport/Results_class_exposures_MDCR.zip")

CohortDiagnostics::uploadResults(
  connectionDetails = connectionDetails,
  schema = classSchema,
  zipFileName = "d:/LegendT2dmOutput_ccae1/class/cohortDiagnosticsExport/Results_class_exposures_CCAE.zip")

CohortDiagnostics::uploadResults(
  connectionDetails = connectionDetails,
  schema = classSchema,
  zipFileName = "d:/LegendT2dmOutput_IQVIA/Results_class_exposures_Germany_DA.zip")

CohortDiagnostics::uploadResults(
  connectionDetails = connectionDetails,
  schema = classSchema,
  zipFileName = "d:/LegendT2dmOutput_IQVIA/Results_class_exposures_Australia_LPD.zip")

CohortDiagnostics::uploadResults(
  connectionDetails = connectionDetails,
  schema = classSchema,
  zipFileName = "d:/LegendT2dmOutput_IQVIA/Results_class_exposures_France_LPD.zip")

CohortDiagnostics::uploadResults(
  connectionDetails = connectionDetails,
  schema = classSchema,
  zipFileName = "d:/LegendT2dmOutput_IQVIA/Results_class_exposures_US_Open_Claims.zip")

CohortDiagnostics::uploadResults(
  connectionDetails = connectionDetails,
  schema = classSchema,
  zipFileName = "d:/LegendT2dmOutput_SFTP/gj0iqfy3_Results_class_exposures_CUIMC.zip")

CohortDiagnostics::uploadResults(
  connectionDetails = connectionDetails,
  schema = classSchema,
  zipFileName = "d:/LegendT2dmOutput_SFTP/tkq5la4h_Results_class_exposures_UK-IMRD.zip")

CohortDiagnostics::uploadResults(
  connectionDetails = connectionDetails,
  schema = classSchema,
  zipFileName = "d:/LegendT2dmOutput_SFTP/x8db42kr_Results_class_exposures_HK-HA-DM.zip")

CohortDiagnostics::uploadResults(
  connectionDetails = connectionDetails,
  schema = classSchema,
  zipFileName = "d:/LegendT2dmOutput_SFTP/56d4ju1v_Results_class_exposures_SG_KTPH.zip")

CohortDiagnostics::uploadResults(
  connectionDetails = connectionDetails,
  schema = classSchema,
  zipFileName = "d:/LegendT2dmOutput_SFTP/fixed_Results_class_exposures_HIC-Dundee.zip")

CohortDiagnostics::uploadResults(
  connectionDetails = connectionDetails,
  schema = classSchema,
  zipFileName = "d:/LegendT2dmOutput_SFTP/0z4r1kpn_Results_class_exposures_JHM.zip")

# CohortDiagnostics::uploadResults(
#   connectionDetails = connectionDetails,
#   schema = classSchema,
#   zipFileName = "d:/LegendT2dmOutput_SFTP/9gkhynbo_Results_class_exposures_VA-OMOP.zip")

CohortDiagnostics::uploadResults(
  connectionDetails = connectionDetails,
  schema = classSchema,
  zipFileName = "d:/LegendT2dmOutput_SFTP/Results_class_exposures_VA-OMOP_patched.zip")

CohortDiagnostics::uploadResults(
  connectionDetails = connectionDetails,
  schema = classSchema,
  zipFileName = "d:/LegendT2dmOutput_SFTP/db46ulzp_Results_class_exposures_SIDIAP.zip")

CohortDiagnostics::uploadResults(
  connectionDetails = connectionDetails,
  schema = classSchema,
  zipFileName = "d:/LegendT2dmOutput_SFTP/go15dnyv_Results_class_exposures_STARR.zip")

CohortDiagnostics::uploadResults(
  connectionDetails = connectionDetails,
  schema = classSchema,
  zipFileName = "d:/LegendT2dmOutput_SFTP/Results_class_exposures_China_WD_230403.zip")

# Outcome diagnostics

outcomeSchema <- "legendt2dm_outcome_diagnostics"
LegendT2dm::createDataModelOnServer(connectionDetails = connectionDetails,
                                    schema = outcomeSchema,
                                    sqlFileName = "CreateCohortDiagnosticsTables.sql")

LegendT2dm::grantPermissionOnServer(connectionDetails = connectionDetails,
                                    user = "legend", schema = outcomeSchema)

LegendT2dm::grantPermissionOnServer(connectionDetails = connectionDetails,
                                    user = "legendt2dm_readonly", schema = outcomeSchema)

CohortDiagnostics::uploadResults(
  connectionDetails = connectionDetails,
  schema = outcomeSchema,
  zipFileName = "d:/LegendT2dmOutput_optum_ehr1/outcome/cohortDiagnosticsExport/Results_outcomes_OptumEHR.zip")

CohortDiagnostics::uploadResults(
  connectionDetails = connectionDetails,
  schema = outcomeSchema,
  zipFileName = "d:/LegendT2dmOutput_optum_dod1/outcome/cohortDiagnosticsExport/Results_outcomes_OptumDod.zip")

CohortDiagnostics::uploadResults(
  connectionDetails = connectionDetails,
  schema = outcomeSchema,
  zipFileName = "d:/LegendT2dmOutput_mdcd1/outcome/cohortDiagnosticsExport/Results_outcomes_MDCD.zip")

CohortDiagnostics::uploadResults(
  connectionDetails = connectionDetails,
  schema = outcomeSchema,
  zipFileName = "d:/LegendT2dmOutput_mdcr1/outcome/cohortDiagnosticsExport/Results_outcomes_MDCR.zip")

CohortDiagnostics::uploadResults(
  connectionDetails = connectionDetails,
  schema = outcomeSchema,
  zipFileName = "d:/LegendT2dmOutput_ccae1/outcome/cohortDiagnosticsExport/Results_outcomes_CCAE.zip")

CohortDiagnostics::uploadResults(
  connectionDetails = connectionDetails,
  schema = outcomeSchema,
  zipFileName = "d:/LegendT2dmOutput_IQVIA/Results_outcomes_Germany_DA.zip")

CohortDiagnostics::uploadResults(
  connectionDetails = connectionDetails,
  schema = outcomeSchema,
  zipFileName = "d:/LegendT2dmOutput_IQVIA/Results_outcomes_Australia_LPD.zip")

CohortDiagnostics::uploadResults(
  connectionDetails = connectionDetails,
  schema = outcomeSchema,
  zipFileName = "d:/LegendT2dmOutput_IQVIA/Results_outcomes_France_LPD.zip")

CohortDiagnostics::uploadResults(
  connectionDetails = connectionDetails,
  schema = outcomeSchema,
  zipFileName = "d:/LegendT2dmOutput_IQVIA/Results_outcomes_US_Open_Claims.zip")

CohortDiagnostics::uploadResults(
  connectionDetails = connectionDetails,
  schema = outcomeSchema,
  zipFileName = "d:/LegendT2dmOutput_SFTP/urvmnap2_Results_outcomes_CUIMC.zip")

CohortDiagnostics::uploadResults(
  connectionDetails = connectionDetails,
  schema = outcomeSchema,
  zipFileName = "d:/LegendT2dmOutput_SFTP/1kb6ezdp_Results_outcomes_UK-IMRD.zip")

CohortDiagnostics::uploadResults(
  connectionDetails = connectionDetails,
  schema = outcomeSchema,
  zipFileName = "d:/LegendT2dmOutput_SFTP/5kjc7zg0_Results_outcomes_HK-HA-DM.zip")

CohortDiagnostics::uploadResults(
  connectionDetails = connectionDetails,
  schema = outcomeSchema,
  zipFileName = "d:/LegendT2dmOutput_SFTP/4ouldb7r_Results_outcomes_SG_KTPH.zip")

# TODO Add VA, JHU, HIC, SIDIAP, STARR, China_WD

# PS Assessment

classPsSchema <- "legendt2dm_class_diagnostics"
LegendT2dm::createDataModelOnServer(connectionDetails = connectionDetails,
                                    schema = classPsSchema,
                                    sqlFileName = "CreatePsAssessmentTables.sql")

LegendT2dm::grantPermissionOnServer(connectionDetails = connectionDetails,
                                    user = "legend", schema = classPsSchema)

LegendT2dm::grantPermissionOnServer(connectionDetails = connectionDetails,
                                    user = "legendt2dm_readonly", schema = classPsSchema)

