
library(LegendT2dm)



dbms <- "pdw"
user <- NULL
pw <- NULL
server <- Sys.getenv("PDW_SERVER")
port <- Sys.getenv("PDW_PORT")
maxCores <- 1
cdmVersion <- "5"
oracleTempSchema <- NULL
connectionDetails <- DatabaseConnector::createConnectionDetails(dbms = dbms,
                                                                server = server,
                                                                user = user,
                                                                password = pw,
                                                                port = port)

indicationId <- "T2DM"

cdmDatabaseSchema <- "cdm_truven_ccae_v778.dbo"
cohortDatabaseSchema <- "scratch.dbo"
databaseName <- "CCAE"
databaseName <- "Truven Health MarketScan Commercial Claims and Encounters Database"
databaseDescription <- "Truven Health MarketScan® Commercial Claims and Encounters Database (CCAE) represent data from individuals enrolled in United States employer-sponsored insurance health plans. The data includes adjudicated health insurance claims (e.g. inpatient, outpatient, and outpatient pharmacy) as well as enrollment data from large employers and health plans who provide private healthcare coverage to employees, their spouses, and dependents. Additionally, it captures laboratory tests for a subset of the covered lives. This administrative claims database includes a variety of fee-for-service, preferred provider organizations, and capitated health plans."
#outcomeDatabaseSchema <- "scratch.dbo"
#outcomeTable <- "msuchard_legend_t2dm_ccae"
tablePrefix <- "legend_t2md_ccae"
outputFolder <- "d:/LegendT2dmOutput_ccae"
#exposureDatabaseSchema <- cdmDatabaseSchema

#exposureTable = "drug_era"
#exportFolder <- file.path(outputFolder, "export")



# Feasibility assessment ---------------------------------------------------------
assessPhenotypes(connectionDetails = connectionDetails,
                 cdmDatabaseSchema = cdmDatabaseSchema,
                 oracleTempSchema = oracleTempSchema,
                 cohortDatabaseSchema = cohortDatabaseSchema,
                 outputFolder = outputFolder,
                 indicationId = indicationId,
                 tablePrefix = tablePrefix,
                 baseUrl = baseUrlJnj,
                 databaseId = databaseId)
