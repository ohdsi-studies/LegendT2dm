library(LegendT2dm)

Sys.setenv(DATABASECONNECTOR_JAR_FOLDER="d:/Drivers")

# baseUrlJnj <- "https://atlas.ohdsi.org/WebAPI" # "https://epi.jnj.com:8443/WebAPI"

oracleTempSchema <- NULL

cdmDatabaseSchema <- "cdm_truven_ccae_v1479"
serverSuffix <- "truven_ccae"
cohortDatabaseSchema <- "scratch_msuchard"
databaseId <- "CCAE"
databaseName <- "IBM Health MarketScan Commercial Claims and Encounters Database"
databaseDescription <- "IBM Health MarketScan® Commercial Claims and Encounters Database (CCAE) represent data from individuals enrolled in United States employer-sponsored insurance health plans. The data includes adjudicated health insurance claims (e.g. inpatient, outpatient, and outpatient pharmacy) as well as enrollment data from large employers and health plans who provide private healthcare coverage to employees, their spouses, and dependents. Additionally, it captures laboratory tests for a subset of the covered lives. This administrative claims database includes a variety of fee-for-service, preferred provider organizations, and capitated health plans."
tablePrefix <- "legend_t2md_ccae"
outputFolder <- "d:/LegendT2dmOutput_ccae7"

# cdmDatabaseSchema <- "cdm_truven_mdcr_v1477"
# serverSuffix <- "truven_mdcr"
# cohortDatabaseSchema <- "scratch_msuchard"
# databaseId<- "MDCR"
# databaseName <- "IBM Health MarketScan Medicare Supplemental and Coordination of Benefits Database"
# databaseDescription <- "IBM Health MarketScan® Medicare Supplemental and Coordination of Benefits Database (MDCR) represents health services of retirees in the United States with primary or Medicare supplemental coverage through privately insured fee-for-service, point-of-service, or capitated health plans. These data include adjudicated health insurance claims (e.g. inpatient, outpatient, and outpatient pharmacy). Additionally, it captures laboratory tests for a subset of the covered lives."
# tablePrefix <- "legend_t2md_mdcr"
# outputFolder <- "d:/LegendT2dmOutput_mdcr7"

connectionDetails <- DatabaseConnector::createConnectionDetails(
  dbms = "redshift",
  server = paste0(keyring::key_get("redshiftServer"), "/", serverSuffix),
  port = 5439,
  user = keyring::key_get("redshiftUser"),
  password = keyring::key_get("redshiftPassword"),
  extraSettings = "ssl=true&sslfactory=com.amazon.redshift.ssl.NonValidatingFactory")

# Feasibility assessment ---------------------------------------------------------
assessPhenotypes(connectionDetails = connectionDetails,
                 cdmDatabaseSchema = cdmDatabaseSchema,
                 oracleTempSchema = oracleTempSchema,
                 cohortDatabaseSchema = cohortDatabaseSchema,
                 outputFolder = outputFolder,
                 tablePrefix = tablePrefix,
                 databaseId = databaseId,
                 databaseName = databaseName,
                 databaseDescription = databaseDescription,
                 createExposureCohorts = TRUE,
                 runExposureCohortDiagnostics = TRUE,
                 createOutcomeCohorts = TRUE,
                 runOutcomeCohortDiagnostics = TRUE)

dataFolder <- paste0(outputFolder, "/outcomeCohortDiagnosticsExport")
CohortDiagnostics::preMergeDiagnosticsFiles(dataFolder = dataFolder)
CohortDiagnostics::launchDiagnosticsExplorer(dataFolder = dataFolder)
