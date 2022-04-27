
## This script will do two things:

### Run the necessary ACHILLES analyses to determine if a database has the requisite data for the LEGEND T2DM study
### Run the DQD for select quality checks to determine if the data is of high enough quality for the study

## This script also makes certain assumptions about your environment and your database
### a. You have an OMOP CDM instance populated with your data
### b. You have a results schema to hold information about your database
### c. You have write access to your results schema
### d. Your results schema sits next to your CDM schema in such a way that aggregate statistics
###    can be computed from your data and written to your results schema
### e. You have a copy of the vocabulary either in your CDM schema or sitting next to it
  
## To start, call the libraries you will need. If you do not have these libraries, please install them

library(Achilles)
library(DataQualityDashboard)
library(DatabaseConnector)
library(SqlRender)

# To install the libraries you will need the remotes package

# install.packages("remotes")
# remotes::install_github("OHDSI/Achilles")
# remotes::install_github("OHDSI/DataQualityDashboard")
# remotes::install_github("OHDSI/DatabaseConnector")
# remotes::install.github("OHDSI/SqlRender")

# Turn off the connection observer in RStudio
options(connectionObserver = NULL)

############# Source this file to add the function to your environment, it will be called later

#### The following section contains variables you need to edit to run this on your database ####

# Set your working directory - it will be created if it doesn't exist
workingDir <- "D:/ASSURE/dbProfile"

if (!dir.exists(workingDir)) {
  dir.create(path = workingDir, recursive = TRUE)
  setwd(workingDir)
} else {
  setwd(workingDir)
}

# The schema where your CDM data is housed
cdmDatabaseSchema <- "your cdm schema" 

# The schema where your vocabulary is stored
vocabDatabaseSchema <- cdmDatabaseSchema

# A schema you have write access to where the achilles results are or will be stored
resultsDatabaseSchema <- "your results schema" 

# A descriptive name of your database
sourceName <- "human readable name to differentiate your db" 

# Create the connection details object for your database
connectionDetails <- DatabaseConnector::createConnectionDetails(dbms = "yourdbms",
                                                                connectionString = "yourconnection",
                                                                user = "user",
                                                                password = "password")

# The CDM version you are using, it works best with v5.3 and v5.4
cdmVersion <- "5.3" 

# Overwrite Achilles tables - if only one Achilles results table exists but not the other one, then 
# setting this option to TRUE will allow the function to overwrite the existing one to generate all 
# analyses of interest. If not, it will just export what is available in the existing table. 
overwrite <- FALSE

# A writeable folder on your machine where the output will be stored - it will be created if it doesn't exist
outputFolder <- "output" 

# Replace this with the number of records that precludes your results from being shared. Usually this is somewhere between 5-10
minCellCount <- 0 

# Please save the 

#### End user variable section ####

# The Achilles tables we will look for to see if the analyses have already been run
achillesTables <- c("ACHILLES_RESULTS", "ACHILLES_RESULTS_DIST") 

# These are the analyses that will be run (if not already available) and the results returned

analysisIds <- c(1,    # Number of persons
                 2,    # Number of persons by gender
                 3,    # Number of persons by year of birth
                 4,    # Number of persons by race
                 5,    # Number of persons by ethnicity
                 117,  # Number of persons with at least one day of observation in each month
                 111,  # Number of persons by observation period start month
                 113,  # Number of persons by number of observation periods
                 108,  # Number of persons by length of observation period, in 30d increments
                 200,  # Number of persons with at least one visit occurrence, by visit_concept_id
                 2004, # Number of distinct patients that overlap between specific domains
                 1801, # Number of measurement occurrence records, by measurement_concept_id
                 1814, # Number of measurement records with no value (numeric, string, or concept)
                 401,  # Number of condition occurrence records, by condition_concept_id
                 601,  # Number of procedure occurrence records, by procedure_concept_id
                 701,  # Number of drug exposure records, by drug_concept_id
                 801,  # Number of observation occurrence records, by observation_concept_id
                 2101, # Number of device exposure records, by device_concept_id
                 1815  # Distribution of numeric values, by measurement_concept_id and unit_concept_id
)

#### Everything below this line in the function called in line 238. Please source the file to make the function available and
## skip to link 238

dbProfileAchilles <- function (){
  
  if (!dir.exists(outputFolder)) {
    dir.create(path = outputFolder, recursive = TRUE)
  }
  
  ## First we will test to see if the Achilles tables already exist. 
  
  resultsTables <- tryCatch(
    expr = {
      conn <- DatabaseConnector::connect(connectionDetails)
      as.data.frame(DatabaseConnector::getTableNames(conn, resultsDatabaseSchema)) 
    },
    error = function(e){
      message(paste("Results schema does not exist or you do not have access. Please check your parameters"))
      message(e)
      resultsTables <- as.data.frame(NA)
      return(resultsTables)
    }
  )
  
  colnames(resultsTables) <- "resultsTables"
  
  resultsTables$achillesTables <- ifelse(resultsTables$resultsTables %in% achillesTables, 1, 0)
  
  if(!is.na(resultsTables[1,1])){
    
    if(sum(resultsTables$achillesTables) == length(achillesTables)){ #check for both results tables
      
      writeLines("All achilles tables present, now checking required analyses")
      
      missingAnalyses <- Achilles::listMissingAnalyses(connectionDetails,
                                                       resultsDatabaseSchema)
      
      missingAnalyses$requiredAnalyses <- ifelse(missingAnalyses$ANALYSIS_ID %in% analysisIds, 1, 0)
      
      analysesToRun <- subset(missingAnalyses, requiredAnalyses==1)
      
      writeLines(paste("Running Analyses", analysesToRun$ANALYSIS_ID))
      
      Achilles::achilles(connectionDetails,
                         cdmDatabaseSchema = cdmDatabaseSchema,
                         vocabDatabaseSchema = vocabDatabaseSchema,
                         createTable = FALSE,
                         resultsDatabaseSchema = resultsDatabaseSchema,
                         sourceName = sourceName,
                         updateGivenAnalysesOnly = TRUE,
                         analysisIds = analysesToRun$ANALYSIS_ID,
                         cdmVersion = cdmVersion,
                         outputFolder = outputFolder
      )
    } else if (overwrite) { 
      
      writeLines("One or more achilles tables are missing, running entire package for the required analyses and regenerating tables")
      
      Achilles::achilles(connectionDetails,
                         cdmDatabaseSchema = cdmDatabaseSchema,
                         vocabDatabaseSchema = vocabDatabaseSchema,
                         resultsDatabaseSchema = resultsDatabaseSchema,
                         sourceName = sourceName,
                         analysisIds = analysisIds,
                         cdmVersion = cdmVersion,
                         outputFolder = outputFolder
      )
      
    } else if (!overwrite){
      
      tryCatch(
        expr = {
          writeLines("One or more achilles tables are missing, attempting to update analyses without regenerating tables")
          
          missingAnalyses <- Achilles::listMissingAnalyses(connectionDetails,
                                                           resultsDatabaseSchema)
          
          missingAnalyses$requiredAnalyses <- ifelse(missingAnalyses$ANALYSIS_ID %in% analysisIds, 1, 0)
          
          analysesToRun <- subset(missingAnalyses, requiredAnalyses==1)
          
          writeLines(paste("Running Analyses", analysesToRun$ANALYSIS_ID))
          
          Achilles::achilles(connectionDetails,
                             cdmDatabaseSchema = cdmDatabaseSchema,
                             vocabDatabaseSchema = vocabDatabaseSchema,
                             createTable = FALSE,
                             resultsDatabaseSchema = resultsDatabaseSchema,
                             sourceName = sourceName,
                             updateGivenAnalysesOnly = TRUE,
                             analysisIds = analysesToRun$ANALYSIS_ID,
                             cdmVersion = cdmVersion,
                             outputFolder = outputFolder
          )
        },
        error = function(e){
          message(paste("An attempt was made to update missing analyses but the table could not be overwritten. Try setting overwrite = TRUE. Any results exported are most likely incomplete."))
          message(e)
        }
      )
      
    }
    
  }else {
    
    writeLines("No Achilles tables detected, running entire package for the required analyses")
    
    Achilles::achilles(connectionDetails,
                       cdmDatabaseSchema = cdmDatabaseSchema,
                       vocabDatabaseSchema = vocabDatabaseSchema,
                       resultsDatabaseSchema = resultsDatabaseSchema,
                       sourceName = sourceName,
                       analysisIds = analysisIds,
                       cdmVersion = cdmVersion,
                       outputFolder = outputFolder
    )
  }
  
  
  Achilles::exportResultsToCSV(connectionDetails,
                               resultsDatabaseSchema = resultsDatabaseSchema,
                               analysisIds = analysisIds,
                               minCellCount = minCellCount,
                               exportFolder = outputFolder
  )
}

##### End of function


## Running the next line will call a function that checks your Achilles tables and runs the necessary analyses

dbProfileAchilles()

checkNames <- c("measurePersonCompleteness",
                "cdmField",
                "isRequired",
                "cdmDatatype",
                "isPrimaryKey",
                "isForeignKey",
                "fkDomain",
                "fkClass",
                "isStandardValidConcept",
                "standardConceptRecordCompleteness",
                "sourceConceptRecordCompleteness",
                "plausibleValueLow",
                "plausibleValueHigh",
                "plausibleTemporalAfter",
                "plausibleDuringLife"
                )

tablesToExclude <- c("DEVICE_EXPOSURE",
                      "VISIT_DETAIL",
                      "NOTE",
                      "NOTE_NLP",
                      "OBSERVATION",
                      "SPECIMEN",
                      "FACT_RELATIONSHIP",
                      "LOCATION",
                      "CARE_SITE",
                      "PROVIDER",
                      "PAYER_PLAN_PERIOD",
                      "COST",
                      "DOSE_ERA",
                      "CONDITION_ERA"
                      )

if(cdmVersion == "5.3"){cdmVersion <- "5.3.1"}

DataQualityDashboard::executeDqChecks(connectionDetails,
                                      cdmDatabaseSchema = cdmDatabaseSchema,
                                      resultsDatabaseSchema = resultsDatabaseSchema,
                                      cdmSourceName = sourceName,
                                      outputFolder = outputFolder,
                                      verboseMode = TRUE,
                                      writeToTable = FALSE,
                                      checkNames = c("plausibleValueHigh"),
                                      tablesToExclude = tablesToExclude,
                                      conceptCheckThresholdLoc = "D:/ASSURE/dbProfile/dqdThresholds/OMOP_CDMv5.3.1_Concept_Level_Legend.csv",
                                      cdmVersion = "5.3.1"
                                      )

#### Everything below this line in the function called in line 94. Please source the file to make the function available

dbProfileAchilles <- function (){
  
  if (!dir.exists(outputFolder)) {
    dir.create(path = outputFolder, recursive = TRUE)
  }
  
  ## First we will test to see if the Achilles tables already exist. 
  
  resultsTables <- tryCatch(
                            expr = {
                              conn <- DatabaseConnector::connect(connectionDetails)
                              as.data.frame(DatabaseConnector::getTableNames(conn, resultsDatabaseSchema)) 
                            },
                            error = function(e){
                              message(paste("Results schema does not exist or you do not have access. Please check your parameters"))
                              message(e)
                              resultsTables <- as.data.frame(NA)
                              return(resultsTables)
                            }
                          )
  
  colnames(resultsTables) <- "resultsTables"
  
  resultsTables$achillesTables <- ifelse(resultsTables$resultsTables %in% achillesTables, 1, 0)
  
  if(!is.na(resultsTables[1,1])){
    
    if(sum(resultsTables$achillesTables) == length(achillesTables)){ #check for both results tables
      
      writeLines("All achilles tables present, now checking required analyses")
      
      missingAnalyses <- Achilles::listMissingAnalyses(connectionDetails,
                                                       resultsDatabaseSchema)
      
      missingAnalyses$requiredAnalyses <- ifelse(missingAnalyses$ANALYSIS_ID %in% analysisIds, 1, 0)
      
      analysesToRun <- subset(missingAnalyses, requiredAnalyses==1)
      
      writeLines(paste("Running Analyses", analysesToRun$ANALYSIS_ID))
      
      Achilles::achilles(connectionDetails,
                         cdmDatabaseSchema = cdmDatabaseSchema,
                         vocabDatabaseSchema = vocabDatabaseSchema,
                         createTable = FALSE,
                         resultsDatabaseSchema = resultsDatabaseSchema,
                         sourceName = sourceName,
                         updateGivenAnalysesOnly = TRUE,
                         analysisIds = analysesToRun$ANALYSIS_ID,
                         cdmVersion = cdmVersion,
                         outputFolder = outputFolder
                        )
    } else if (overwrite) { 
      
      writeLines("One or more achilles tables are missing, running entire package for the required analyses and regenerating tables")
      
      Achilles::achilles(connectionDetails,
                         cdmDatabaseSchema = cdmDatabaseSchema,
                         vocabDatabaseSchema = vocabDatabaseSchema,
                         resultsDatabaseSchema = resultsDatabaseSchema,
                         sourceName = sourceName,
                         analysisIds = analysisIds,
                         cdmVersion = cdmVersion,
                         outputFolder = outputFolder
                        )
      
    } else if (!overwrite){
          
      tryCatch(
        expr = {
          writeLines("One or more achilles tables are missing, attempting to update analyses without regenerating tables")
          
          missingAnalyses <- Achilles::listMissingAnalyses(connectionDetails,
                                                           resultsDatabaseSchema)
          
          missingAnalyses$requiredAnalyses <- ifelse(missingAnalyses$ANALYSIS_ID %in% analysisIds, 1, 0)
          
          analysesToRun <- subset(missingAnalyses, requiredAnalyses==1)
          
          writeLines(paste("Running Analyses", analysesToRun$ANALYSIS_ID))
          
          Achilles::achilles(connectionDetails,
                             cdmDatabaseSchema = cdmDatabaseSchema,
                             vocabDatabaseSchema = vocabDatabaseSchema,
                             createTable = FALSE,
                             resultsDatabaseSchema = resultsDatabaseSchema,
                             sourceName = sourceName,
                             updateGivenAnalysesOnly = TRUE,
                             analysisIds = analysesToRun$ANALYSIS_ID,
                             cdmVersion = cdmVersion,
                             outputFolder = outputFolder
                            )
        },
        error = function(e){
          message(paste("An attempt was made to update missing analyses but the table could not be overwritten. Try setting overwrite = TRUE. Any results exported are most likely incomplete."))
          message(e)
        }
      )
      
    }

  }else {
    
    writeLines("No Achilles tables detected, running entire package for the required analyses")
    
    Achilles::achilles(connectionDetails,
                       cdmDatabaseSchema = cdmDatabaseSchema,
                       vocabDatabaseSchema = vocabDatabaseSchema,
                       resultsDatabaseSchema = resultsDatabaseSchema,
                       sourceName = sourceName,
                       analysisIds = analysisIds,
                       cdmVersion = cdmVersion,
                       outputFolder = outputFolder
                      )
  }
  
  
  Achilles::exportResultsToCSV(connectionDetails,
                               resultsDatabaseSchema = resultsDatabaseSchema,
                               analysisIds = analysisIds,
                               minCellCount = minCellCount,
                               exportFolder = outputFolder
  )
}