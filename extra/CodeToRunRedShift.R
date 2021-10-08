library(LegendT2dm)

Sys.setenv(DATABASECONNECTOR_JAR_FOLDER="d:/Drivers")
options(andromedaTempFolder = "d:/andromedaTemp")
oracleTempSchema <- NULL

# cdmDatabaseSchema <- "cdm_truven_ccae_v1479"
# serverSuffix <- "truven_ccae"
# cohortDatabaseSchema <- "scratch_msuchard"
# databaseId <- "CCAE"
# databaseName <- "IBM Health MarketScan Commercial Claims and Encounters Database"
# databaseDescription <- "IBM Health MarketScan® Commercial Claims and Encounters Database (CCAE) represent data from individuals enrolled in United States employer-sponsored insurance health plans. The data includes adjudicated health insurance claims (e.g. inpatient, outpatient, and outpatient pharmacy) as well as enrollment data from large employers and health plans who provide private healthcare coverage to employees, their spouses, and dependents. Additionally, it captures laboratory tests for a subset of the covered lives. This administrative claims database includes a variety of fee-for-service, preferred provider organizations, and capitated health plans."
# tablePrefix <- "legend_t2dm_ccae"
# outputFolder <- "d:/LegendT2dmOutput_ccae12"

# cdmDatabaseSchema <- "cdm_optum_ehr_v1562"
# serverSuffix <- "optum_ehr"
# cohortDatabaseSchema <- "scratch_msuchard"
# databaseId <- "OptumEHR"
# databaseName <- "Optum© de-identified Electronic Health Record Dataset"
# databaseDescription <- "Optum© de-identified Electronic Health Record Dataset represents Humedica’s Electronic Health Record data a medical records database. The medical record data includes clinical information, inclusive of prescriptions as prescribed and administered, lab results, vital signs, body measurements, diagnoses, procedures, and information derived from clinical Notes using Natural Language Processing (NLP)."
# tablePrefix <- "legend_t2dm_optum_ehr"
# outputFolder <- "d:/LegendT2dmOutput_optum_ehr12"

cdmDatabaseSchema <- "cdm_truven_mdcr_v1477"
serverSuffix <- "truven_mdcr"
cohortDatabaseSchema <- "scratch_msuchard"
databaseId<- "MDCR"
databaseName <- "IBM Health MarketScan Medicare Supplemental and Coordination of Benefits Database"
databaseDescription <- "IBM Health MarketScan® Medicare Supplemental and Coordination of Benefits Database (MDCR) represents health services of retirees in the United States with primary or Medicare supplemental coverage through privately insured fee-for-service, point-of-service, or capitated health plans. These data include adjudicated health insurance claims (e.g. inpatient, outpatient, and outpatient pharmacy). Additionally, it captures laboratory tests for a subset of the covered lives."
tablePrefix <- "legend_t2dm_mdcr"
outputFolder <- "d:/LegendT2dmOutput_mdcr14"

connectionDetails <- DatabaseConnector::createConnectionDetails(
  dbms = "redshift",
  server = paste0(keyring::key_get("redshiftServer"), "/", !!serverSuffix),
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

assessPropensityModels(connectionDetails = connectionDetails,
                       cdmDatabaseSchema = cdmDatabaseSchema,
                       oracleTempSchema = oracleTempSchema,
                       cohortDatabaseSchema = cohortDatabaseSchema,
                       outputFolder = outputFolder,
                       indicationId = "class",
                       tablePrefix = tablePrefix,
                       databaseId = databaseId,
                       maxCores = 16)

execute(connectionDetails = connectionDetails,
        cdmDatabaseSchema = cdmDatabaseSchema,
        oracleTempSchema = oracleTempSchema,
        cohortDatabaseSchema = cohortDatabaseSchema,
        outputFolder = outputFolder,
        indicationId = "class",
        databaseId = databaseId,
        databaseName = databaseName,
        databaseDescription = databaseDescription,
        tablePrefix = tablePrefix,
        imputeExposureLengthWhenMissing = FALSE,
        createExposureCohorts = FALSE,
        createOutcomeCohorts = FALSE,
        fetchAllDataFromServer = TRUE,
        generateAllCohortMethodDataObjects = TRUE,
        runCohortMethod = TRUE,
        computeCovariateBalance = TRUE,
        exportToCsv = TRUE,
        maxCores = 16)

