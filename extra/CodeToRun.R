library(LegendT2dm)

# baseUrlJnj <- "https://atlas.ohdsi.org/WebAPI" # "https://epi.jnj.com:8443/WebAPI"


dbms <- "pdw"
user <- NULL
pw <- NULL
server <- keyring::key_get("pdwServer")
port <- keyring::key_get("pdwPort")
maxCores <- 1
cdmVersion <- "5"
oracleTempSchema <- NULL
connectionDetails <- DatabaseConnector::createConnectionDetails(dbms = dbms,
                                                                server = server,
                                                                user = user,
                                                                password = pw,
                                                                port = port)

cdmDatabaseSchema <- "cdm_ibm_ccae_v1191.dbo"
cohortDatabaseSchema <- "scratch.dbo"
databaseId <- "CCAE"
databaseName <- "IBM Health MarketScan Commercial Claims and Encounters Database"
databaseDescription <- "IBM Health MarketScan® Commercial Claims and Encounters Database (CCAE) represent data from individuals enrolled in United States employer-sponsored insurance health plans. The data includes adjudicated health insurance claims (e.g. inpatient, outpatient, and outpatient pharmacy) as well as enrollment data from large employers and health plans who provide private healthcare coverage to employees, their spouses, and dependents. Additionally, it captures laboratory tests for a subset of the covered lives. This administrative claims database includes a variety of fee-for-service, preferred provider organizations, and capitated health plans."
tablePrefix <- "legend_t2md_ccae"
outputFolder <- "d:/LegendT2dmOutput_ccae2"

# cdmDatabaseSchema <- "cdm_ibm_mdcr_v1192.dbo"
# cohortDatabaseSchema <- "scratch.dbo"
# databaseId<- "MDCR"
# databaseId <- "MDCR"
# databaseName <- "IBM Health MarketScan Medicare Supplemental and Coordination of Benefits Database"
# databaseDescription <- "IBM Health MarketScan® Medicare Supplemental and Coordination of Benefits Database (MDCR) represents health services of retirees in the United States with primary or Medicare supplemental coverage through privately insured fee-for-service, point-of-service, or capitated health plans. These data include adjudicated health insurance claims (e.g. inpatient, outpatient, and outpatient pharmacy). Additionally, it captures laboratory tests for a subset of the covered lives."
# tablePrefix <- "legend_t2md_mdcr"
# outputFolder <- "d:/LegendT2dmOutput_mdcr"

# cdmDatabaseSchema <- "cdm_optum_panther_v1157.dbo"
# cohortDatabaseSchema <- "scratch.dbo"
# databaseId<- "Optum EHR"
# databaseName <- "Optum© de-identified Electronic Health Record Dataset"
# databaseDescription <- "Optum© de-identified Electronic Health Record Dataset represents Humedica’s Electronic Health Record data a medical records database. The medical record data includes clinical information, inclusive of prescriptions as prescribed and administered, lab results, vital signs, body measurements, diagnoses, procedures, and information derived from clinical Notes using Natural Language Processing (NLP)."
# tablePrefix <- "legend_t2md_panther"
# outputFolder <- "d:/LegendT2dmOutput_panther"

# cdmDatabaseSchema <- "cdm_optum_extended_dod_v1194.dbo"
# cohortDatabaseSchema <- "scratch.dbo"
# databaseId<- "Optum"
# databaseName <- "Optum’s Clinformatics® Extended Data Mart"
# databaseDescription <- "Optum Clinformatics Extended DataMart is an adjudicated US administrative health claims database for members of private health insurance, who are fully insured in commercial plans or in administrative services only (ASOs), Legacy Medicare Choice Lives (prior to January 2006), and Medicare Advantage (Medicare Advantage Prescription Drug coverage starting January 2006). The population is primarily representative of commercial claims patients (0-65 years old) with some Medicare (65+ years old) however ages are capped at 90 years. It includes data captured from administrative claims processed from inpatient and outpatient medical services and prescriptions as dispensed, as well as results for outpatient lab tests processed by large national lab vendors who participate in data exchange with Optum. This dataset also provides date of death (month and year only) for members with both medical and pharmacy coverage from the Social Security Death Master File (however after 2011 reporting frequency changed due to changes in reporting requirements) and location information for patients is at the US state level."
# tablePrefix <- "legend_t2md_optum"
# outputFolder <- "d:/LegendT2dmOutput_optum"

# cdmDatabaseSchema <- "cdm_ibm_mdcd_v1259.dbo"
# cohortDatabaseSchema <- "scratch.dbo"
# databaseId <- "MDCD"
# databaseName <- "IBM Health MarketScan® Multi-State Medicaid Database"
# databaseDescription <- "IBM Health MarketScan® Multi-State Medicaid Database (MDCD) adjudicated US health insurance claims for Medicaid enrollees from multiple states and includes hospital discharge diagnoses, outpatient diagnoses and procedures, and outpatient pharmacy claims as well as ethnicity and Medicare eligibility. Members maintain their same identifier even if they leave the system for a brief period however the dataset lacks lab data. [For further information link to RWE site for Truven MDCD."
# tablePrefix <- "legend_t2md_mdcd"
# outputFolder <- "d:/LegendT2dmOutput_mdcd2"


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
#                  createCohorts = FALSE,
#                  runCohortDiagnostics = TRUE)



cohortTable <- paste(tablePrefix, "cohort", sep = "_")

CohortDiagnostics::instantiateCohortSet(connectionDetails = connectionDetails,
                                        cdmDatabaseSchema = cdmDatabaseSchema,
                                        cohortDatabaseSchema = cohortDatabaseSchema,
                                        oracleTempSchema = oracleTempSchema,
                                        cohortTable = cohortTable,
                                        packageName = "LegendT2dm",
                                        cohortToCreateFile = "settings/testCohortsToCreate.csv",
                                        generateInclusionStats = TRUE,
                                        inclusionStatisticsFolder = outputFolder)

sql <- SqlRender::loadRenderTranslateSql("GetCounts.sql",
                                         "LegendT2dm",
                                         dbms = connectionDetails$dbms,
                                         oracleTempSchema = oracleTempSchema,
                                         cdm_database_schema = cdmDatabaseSchema,
                                         work_database_schema = cohortDatabaseSchema,
                                         study_cohort_table = cohortTable)
connection <- DatabaseConnector::connect(connectionDetails)
counts <- DatabaseConnector::querySql(connection, sql, snakeCaseToCamelCase = TRUE)
DatabaseConnector::disconnect(connection)
counts$databaseId <- databaseId
#counts <- addCohortNames(counts)
write.csv(counts, file.path(outputFolder, "testCohortCounts.csv"), row.names = FALSE)

CohortDiagnostics::runCohortDiagnostics(packageName = "LegendT2dm",
                                        cohortToCreateFile = "settings/testCohortsToCreate.csv",
                                        connectionDetails = connectionDetails,
                                        cdmDatabaseSchema = cdmDatabaseSchema,
                                        oracleTempSchema = oracleTempSchema,
                                        cohortDatabaseSchema = cohortDatabaseSchema,
                                        cohortTable = paste(tablePrefix, "cohort", sep = "_"),
                                        inclusionStatisticsFolder = outputFolder,
                                        exportFolder = file.path(outputFolder, "testCohortDiagnosticsExport"),
                                        databaseId = databaseId,
                                        databaseName = databaseName,
                                        databaseDescription = databaseDescription,
                                        runInclusionStatistics = TRUE,
                                        runBreakdownIndexEvents = TRUE,
                                        runIncludedSourceConcepts = TRUE,
                                        runCohortCharacterization = TRUE,
                                        #runTemporalCohortCharacterization = TRUE,
                                        runCohortOverlap = FALSE,
                                        runOrphanConcepts = TRUE,
                                        runIncidenceRate = TRUE,
                                        runTimeDistributions = TRUE,
                                        minCellCount = 5)

LegendT2dm::launchCohortExplorer(connectionDetails = connectionDetails,
                                        cdmDatabaseSchema = cdmDatabaseSchema,
                                        cohortDatabaseSchema = cohortDatabaseSchema,
                                        cohortTable = paste(tablePrefix, "cohort", sep = "_"),
                                        cohortId = 101300000, # c(201300000, 301300000, 401300000),
                                        sampleSize = 100)

