# rJava::.jinit(parameters="-Xmx100g", force.init = TRUE)
# options(java.parameters = c("-Xms200g", "-Xmx200g"))

library(LegendT2dm)

Sys.setenv(DATABASECONNECTOR_JAR_FOLDER="d:/Drivers")
options(andromedaTempFolder = "d:/andromedaTemp")
oracleTempSchema <- NULL

# Sep 2024:
# cdmDatabaseSchema <- "cdm_truven_mdcd_v3038"
# serverSuffix <- "truven_mdcd"
# cohortDatabaseSchema <- "scratch_msuchard"
# databaseId<- "MDCD"
# databaseName <- "IBM Health MarketScan® Multi-State Medicaid Database"
# databaseDescription <- "IBM MarketScan® Multi-State Medicaid Database (MDCD) adjudicated US health insurance claims for Medicaid enrollees from multiple states and includes hospital discharge diagnoses, outpatient diagnoses and procedures, and outpatient pharmacy claims as well as ethnicity and Medicare eligibility. Members maintain their same identifier even if they leave the system for a brief period however the dataset lacks lab data."
# tablePrefix <- "legend_t2dm_mdcd_2024"
# outputFolder <- "d:/LegendT2dmOutput_mdcd_thyroid"

# cdmDatabaseSchema <- "cdm_optum_ehr_v2541"
# serverSuffix <- "optum_ehr"
# cohortDatabaseSchema <- "scratch_msuchard"
# databaseId <- "OptumEHR"
# databaseName <- "Optum© de-identified Electronic Health Record Dataset"
# databaseDescription <- "Optum© de-identified Electronic Health Record Dataset represents Humedica’s Electronic Health Record data a medical records database. The medical record data includes clinical information, inclusive of prescriptions as prescribed and administered, lab results, vital signs, body measurements, diagnoses, procedures, and information derived from clinical Notes using Natural Language Processing (NLP)."
# tablePrefix <- "legend_t2dm_optum_ehr_2024"
# outputFolder <- "d:/LegendT2dmOutput_optum_ehr_thyroid"

cdmDatabaseSchema <- "cdm_truven_ccae_v3046"
serverSuffix <- "truven_ccae"
cohortDatabaseSchema <- "scratch_msuchard"
databaseId <- "CCAE"
databaseName <- "IBM Health MarketScan Commercial Claims and Encounters Database"
databaseDescription <- "IBM Health MarketScan® Commercial Claims and Encounters Database (CCAE) represent data from individuals enrolled in United States employer-sponsored insurance health plans. The data includes adjudicated health insurance claims (e.g. inpatient, outpatient, and outpatient pharmacy) as well as enrollment data from large employers and health plans who provide private healthcare coverage to employees, their spouses, and dependents. Additionally, it captures laboratory tests for a subset of the covered lives. This administrative claims database includes a variety of fee-for-service, preferred provider organizations, and capitated health plans."
tablePrefix <- "legend_t2dm_ccae_2024"
outputFolder <- "d:/LegendT2dmOutput_ccae_thyroid"

conn <- DatabaseConnector::createConnectionDetails(
  dbms = "redshift",
  server = paste0(keyring::key_get("redshiftServer"), "/", !!serverSuffix),
  port = 5439,
  user = keyring::key_get("redshiftUser"),
  password = keyring::key_get("redshiftPassword"),
  extraSettings = "ssl=true&sslfactory=com.amazon.redshift.ssl.NonValidatingFactory",
  pathToDriver = 'D:/Drivers')

# ## DO NOT RUN: connecting to database
# connection = DatabaseConnector::connect(conn)
# DatabaseConnector::disconnect(connection)

# Feasibility assessment ---------------------------------------------------------
# assessPhenotypes(connectionDetails = conn,
#                  cdmDatabaseSchema = cdmDatabaseSchema,
#                  oracleTempSchema = oracleTempSchema,
#                  cohortDatabaseSchema = cohortDatabaseSchema,
#                  outputFolder = outputFolder,
#                  tablePrefix = tablePrefix,
#                  indicationId = "class",
#                  databaseId = databaseId,
#                  databaseName = databaseName,
#                  databaseDescription = databaseDescription,
#                  createExposureCohorts = TRUE,
#                  runExposureCohortDiagnostics = FALSE,
#                  createOutcomeCohorts = TRUE,
#                  runOutcomeCohortDiagnostics = FALSE)
#
# assessPropensityModels(connectionDetails = conn,
#                        cdmDatabaseSchema = cdmDatabaseSchema,
#                        tablePrefix = tablePrefix,
#                        indicationId = 'drug',
#                        oracleTempSchema = oracleTempSchema,
#                        cohortDatabaseSchema = cohortDatabaseSchema,
#                        outputFolder = outputFolder,
#                        databaseId = databaseId,
#                        maxCores = 16)

## full-on execution of CES; run all sections of analyses
execute(connectionDetails = conn,
        cdmDatabaseSchema = cdmDatabaseSchema,
        oracleTempSchema = oracleTempSchema,
        cohortDatabaseSchema = cohortDatabaseSchema,
        outputFolder = outputFolder,
        indicationId = "class",
        databaseId = databaseId,
        databaseName = databaseName,
        databaseDescription = databaseDescription,
        minCohortSize = 1000,
        tablePrefix = tablePrefix,
        createExposureCohorts = TRUE,
        createOutcomeCohorts = TRUE,
        fetchAllDataFromServer = TRUE,
        generateAllCohortMethodDataObjects = TRUE,
        runCohortMethod = TRUE,
        runSections = c(1:7),
        computeCovariateBalance = TRUE,
        exportToCsv = TRUE,
        maxCores = 10)

execute(connectionDetails = conn,
        cdmDatabaseSchema = cdmDatabaseSchema,
        oracleTempSchema = oracleTempSchema,
        cohortDatabaseSchema = cohortDatabaseSchema,
        outputFolder = outputFolder,
        indicationId = "class",
        databaseId = databaseId,
        databaseName = databaseName,
        databaseDescription = databaseDescription,
        minCohortSize = 1000,
        tablePrefix = tablePrefix,
        createExposureCohorts = FALSE,
        createOutcomeCohorts = FALSE,
        fetchAllDataFromServer = FALSE,
        generateAllCohortMethodDataObjects = FALSE,
        runCohortMethod = FALSE,
        runSections = c(1:7),
        computeCovariateBalance = FALSE,
        exportToCsv = TRUE,
        maxCores = 10)

