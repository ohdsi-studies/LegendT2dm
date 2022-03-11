library(LegendT2dm)

Sys.setenv(DATABASECONNECTOR_JAR_FOLDER="d:/Drivers")
options(andromedaTempFolder = "d:/andromedaTemp")
oracleTempSchema <- NULL

# cdmDatabaseSchema <- "cdm_truven_ccae_v1709"
# serverSuffix <- "truven_ccae"
# cohortDatabaseSchema <- "scratch_msuchard"
# databaseId <- "CCAE"
# databaseName <- "IBM Health MarketScan Commercial Claims and Encounters Database"
# databaseDescription <- "IBM Health MarketScan® Commercial Claims and Encounters Database (CCAE) represent data from individuals enrolled in United States employer-sponsored insurance health plans. The data includes adjudicated health insurance claims (e.g. inpatient, outpatient, and outpatient pharmacy) as well as enrollment data from large employers and health plans who provide private healthcare coverage to employees, their spouses, and dependents. Additionally, it captures laboratory tests for a subset of the covered lives. This administrative claims database includes a variety of fee-for-service, preferred provider organizations, and capitated health plans."
# tablePrefix <- "legend_t2dm_ccae"
# outputFolder <- "d:/LegendT2dmOutput_ccae3" # DONE

cdmDatabaseSchema <- "cdm_optum_ehr_v1821"
serverSuffix <- "optum_ehr"
cohortDatabaseSchema <- "scratch_msuchard"
databaseId <- "OptumEHR"
databaseName <- "Optum© de-identified Electronic Health Record Dataset"
databaseDescription <- "Optum© de-identified Electronic Health Record Dataset represents Humedica’s Electronic Health Record data a medical records database. The medical record data includes clinical information, inclusive of prescriptions as prescribed and administered, lab results, vital signs, body measurements, diagnoses, procedures, and information derived from clinical Notes using Natural Language Processing (NLP)."
tablePrefix <- "legend_t2dm_optum_ehr"
outputFolder <- "d:/LegendT2dmOutput_optum_ehr2" # DONE

# cdmDatabaseSchema <- "cdm_truven_mdcr_v1838"
# serverSuffix <- "truven_mdcr"
# cohortDatabaseSchema <- "scratch_msuchard"
# databaseId<- "MDCR"
# databaseName <- "IBM Health MarketScan Medicare Supplemental and Coordination of Benefits Database"
# databaseDescription <- "IBM Health MarketScan® Medicare Supplemental and Coordination of Benefits Database (MDCR) represents health services of retirees in the United States with primary or Medicare supplemental coverage through privately insured fee-for-service, point-of-service, or capitated health plans. These data include adjudicated health insurance claims (e.g. inpatient, outpatient, and outpatient pharmacy). Additionally, it captures laboratory tests for a subset of the covered lives."
# tablePrefix <- "legend_t2dm_mdcr"
# outputFolder <- "d:/LegendT2dmOutput_mdcr4" # DONE

# cdmDatabaseSchema <- "cdm_truven_mdcd_v1714"
# serverSuffix <- "truven_mdcd"
# cohortDatabaseSchema <- "scratch_msuchard"
# databaseId<- "MDCD"
# databaseName <- "IBM Health MarketScan® Multi-State Medicaid Database"
# databaseDescription <- "IBM MarketScan® Multi-State Medicaid Database (MDCD) adjudicated US health insurance claims for Medicaid enrollees from multiple states and includes hospital discharge diagnoses, outpatient diagnoses and procedures, and outpatient pharmacy claims as well as ethnicity and Medicare eligibility. Members maintain their same identifier even if they leave the system for a brief period however the dataset lacks lab data."
# tablePrefix <- "legend_t2dm_mdcd"
# outputFolder <- "d:/LegendT2dmOutput_mdcd2" # DONE

# cdmDatabaseSchema <- "cdm_optum_extended_dod_v1825"
# serverSuffix <- "optum_extended_dod"
# cohortDatabaseSchema <- "scratch_msuchard"
# databaseId <- "OptumDod"
# databaseName <- "Optum Clinformatics Extended Data Mart - Date of Death (DOD)"
# databaseDescription <- "Optum Clinformatics Extended DataMart is an adjudicated US administrative health claims database for members of private health insurance, who are fully insured in commercial plans or in administrative services only (ASOs), Legacy Medicare Choice Lives (prior to January 2006), and Medicare Advantage (Medicare Advantage Prescription Drug coverage starting January 2006).  The population is primarily representative of commercial claims patients (0-65 years old) with some Medicare (65+ years old) however ages are capped at 90 years.  It includes data captured from administrative claims processed from inpatient and outpatient medical services and prescriptions as dispensed, as well as results for outpatient lab tests processed by large national lab vendors who participate in data exchange with Optum.  This dataset also provides date of death (month and year only) for members with both medical and pharmacy coverage from the Social Security Death Master File (however after 2011 reporting frequency changed due to changes in reporting requirements) and location information for patients is at the US state level."
# tablePrefix <- "legend_t2dm_optum_dod"
# outputFolder <- "d:/LegendT2dmOutput_optum_dod2" # DONE

connectionDetails <- DatabaseConnector::createConnectionDetails(
  dbms = "redshift",
  server = paste0(keyring::key_get("redshiftServer"), "/", !!serverSuffix),
  port = 5439,
  user = keyring::key_get("redshiftUser"),
  password = keyring::key_get("redshiftPassword"),
  extraSettings = "ssl=true&sslfactory=com.amazon.redshift.ssl.NonValidatingFactory")

# Feasibility assessment ---------------------------------------------------------
# assessPhenotypes(connectionDetails = connectionDetails,
#                  cdmDatabaseSchema = cdmDatabaseSchema,
#                  oracleTempSchema = oracleTempSchema,
#                  cohortDatabaseSchema = cohortDatabaseSchema,
#                  outputFolder = outputFolder,
#                  tablePrefix = tablePrefix,
#                  databaseId = databaseId,
#                  databaseName = databaseName,
#                  databaseDescription = databaseDescription,
#                  createExposureCohorts = TRUE,
#                  runExposureCohortDiagnostics = TRUE,
#                  createOutcomeCohorts = TRUE,
#                  runOutcomeCohortDiagnostics = TRUE)
#
# assessPropensityModels(connectionDetails = connectionDetails,
#                        cdmDatabaseSchema = cdmDatabaseSchema,
#                        oracleTempSchema = oracleTempSchema,
#                        cohortDatabaseSchema = cohortDatabaseSchema,
#                        outputFolder = outputFolder,
#                        indicationId = "class",
#                        tablePrefix = tablePrefix,
#                        databaseId = databaseId,
#                        maxCores = 16)

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
        createExposureCohorts = TRUE,
        createOutcomeCohorts = TRUE,
        fetchAllDataFromServer = TRUE,
        generateAllCohortMethodDataObjects = TRUE,
        runCohortMethod = TRUE,
        computeCovariateBalance = TRUE,
        exportToCsv = TRUE,
        maxCores = 16)

