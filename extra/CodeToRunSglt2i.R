library(LegendT2dm)

Sys.setenv(DATABASECONNECTOR_JAR_FOLDER="s:/DatabaseDrivers")

# Run-once: set-up your database driver
DatabaseConnector::downloadJdbcDrivers(dbms = "postgresql")

# Optional: specify where the temporary files (used by the Andromeda package) will be created:
options(andromedaTempFolder = "s:/AndromedaTemp")

# Maximum number of cores to be used:
maxCores <- min(4, parallel::detectCores()) # Or more depending on your hardware

# Minimum cell count when exporting data:
minCellCount <- 5

# Patch for Oracle (if necessary)
oracleTempSchema <- NULL

# The folder where the study intermediate and result files will be written:
outputFolder <- "s:/LegendT2dmStudy"

# Details for connecting to the server:
# See ?DatabaseConnector::createConnectionDetails for help
connectionDetails <- DatabaseConnector::createConnectionDetails(dbms = "postgresql",
                                                                server = "some.server.com/ohdsi",
                                                                user = "joe",
                                                                password = "secret")

# The name of the database schema where the CDM data can be found:
cdmDatabaseSchema <- "cdm_synpuf"

# The name of the database schema and table where the study-specific cohorts will be instantiated:
cohortDatabaseSchema <- "scratch.dbo"
tablePrefix <- "legendt2dm_study"

# Some meta-information that will be used by the export function:
databaseId <- "Synpuf"
databaseName <- "Medicare Claims Synthetic Public Use Files (SynPUFs)"
databaseDescription <- "Medicare Claims Synthetic Public Use Files (SynPUFs) were created to allow interested parties to gain familiarity using Medicare claims data while protecting beneficiary privacy. These files are intended to promote development of software and applications that utilize files in this format, train researchers on the use and complexities of Centers for Medicare and Medicaid Services (CMS) claims, and support safe data mining innovations. The SynPUFs were created by combining randomized information from multiple unique beneficiaries and changing variable values. This randomization and combining of beneficiary information ensures privacy of health information."

# For some database platforms (e.g. Oracle): define a schema that can be used to emulate temp tables:
options(sqlRenderTempEmulationSchema = NULL)

# Feasibility assessment ---------------------------------------------------------
## exposure and outcome cohorts diagnostics
assessPhenotypes(connectionDetails = connectionDetails,
                 cdmDatabaseSchema = cdmDatabaseSchema,
                 oracleTempSchema = oracleTempSchema,
                 cohortDatabaseSchema = cohortDatabaseSchema,
                 outputFolder = outputFolder,
                 tablePrefix = tablePrefix,
                 indicationId = 'sglt2i',
                 databaseId = databaseId,
                 databaseName = databaseName,
                 databaseDescription = databaseDescription,
                 createExposureCohorts = TRUE,
                 runExposureCohortDiagnostics = TRUE,
                 createOutcomeCohorts = TRUE,
                 runOutcomeCohortDiagnostics = TRUE)

## upload diagnostics to the shared FTP
uploadPhenotypeResults(cohort = "sglt2i",
                       outputFolder, privateKeyFileName = "s:/private.key", userName = "legendt2dm")
uploadPhenotypeResults(cohort = "outcome",
                       outputFolder, privateKeyFileName = "s:/private.key", userName = "legendt2dm")

## inspect diagnostics locally
CohortDiagnostics::preMergeDiagnosticsFiles(dataFolder = file.path(outputFolder, "sglt2i/cohortDiagnosticsExport"))
LegendT2dmCohortExplorer::launchCohortExplorer(cohorts = "sglt2i",
                                               dataFolder = file.path(outputFolder, "sglt2i/cohortDiagnosticsExport"))

CohortDiagnostics::preMergeDiagnosticsFiles(dataFolder = file.path(outputFolder, "outcome/cohortDiagnosticsExport"))
LegendT2dmCohortExplorer::launchCohortExplorer(cohorts = "outcome",
                                               dataFolder = file.path(outputFolder, "outcome/cohortDiagnosticsExport"))

## propensity score models assessment
assessPropensityModels(connectionDetails = connectionDetails,
                       cdmDatabaseSchema = cdmDatabaseSchema,
                       oracleTempSchema = oracleTempSchema,
                       cohortDatabaseSchema = cohortDatabaseSchema,
                       outputFolder = outputFolder,
                       indicationId = "sglt2i",
                       tablePrefix = tablePrefix,
                       databaseId = databaseId,
                       maxCores = maxCores)

## upload PS assessment results
uploadPsAssessmentResults(cohort = "sglt2i",
                          outputFolder, privateKeyFileName = "s:/private.key", userName = "legendt2dm")


# run CES for sglt2i -----------------------------------------------------------
execute(connectionDetails = connectionDetails,
        cdmDatabaseSchema = cdmDatabaseSchema,
        oracleTempSchema = oracleTempSchema,
        cohortDatabaseSchema = cohortDatabaseSchema,
        outputFolder = outputFolder,
        indicationId = "sglt2i",
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
        maxCores = maxCores)
