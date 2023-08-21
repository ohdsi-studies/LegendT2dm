# Copyright 2021 Observational Health Data Sciences and Informatics
#
# This file is part of LegendT2dm
#
# Licensed under the Apache License, Version 2.0 (the "License");
# you may not use this file except in compliance with the License.
# You may obtain a copy of the License at
#
#     http://www.apache.org/licenses/LICENSE-2.0
#
# Unless required by applicable law or agreed to in writing, software
# distributed under the License is distributed on an "AS IS" BASIS,
# WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
# See the License for the specific language governing permissions and
# limitations under the License.

#' Fetch all data on the cohorts for analysis
#'
#' @details
#' This function will create covariates and fetch outcomes and person information from the server.
#'
#' @param connectionDetails      An object of type \code{connectionDetails} as created using the
#'                               \code{\link[DatabaseConnector]{createConnectionDetails}} function in
#'                               the DatabaseConnector package.
#' @param cdmDatabaseSchema      Schema name where your patient-level data in OMOP CDM format resides.
#'                               Note that for SQL Server, this should include both the database and
#'                               schema name, for example 'cdm_data.dbo'.
#' @param cohortDatabaseSchema   Schema name where intermediate data can be stored. You will need to
#'                               have write priviliges in this schema. Note that for SQL Server, this
#'                               should include both the database and schema name, for example
#'                               'cdm_data.dbo'.
#' @param oracleTempSchema       Should be used in Oracle to specify a schema where the user has write
#'                               priviliges for storing temporary tables.
#' @param indicationId           A string denoting the indicationId.
#' @param tablePrefix            A prefix to be used for all table names created for this study.
#' @param useSample              Use the sampled cohort table instead of the main cohort table (for PS
#'                               model feasibility).
#' @param forceNewObjects        Force recreation of \code{CohortMethod} data objects?
#' @param studyEndDate           Optionally specify a study end date
#' @param outputFolder           Schema name where intermediate data can be stored. You will need to
#'                               have write priviliges in this schema. Note that for SQL Server, this
#'                               should include both the database and schema name, for example
#'                               'cdm_data.dbo'.
#'
#' @export
fetchAllDataFromServer <- function(connectionDetails,
                                   cdmDatabaseSchema,
                                   cohortDatabaseSchema,
                                   oracleTempSchema,
                                   indicationId = "class",
                                   tablePrefix = "legendt2dm",
                                   useSample = FALSE,
                                   forceNewObjects = FALSE,
                                   studyEndDate = "",
                                   outputFolder) {

    # For efficiency reasons, we fetch all necessary data from the server in one go. We take the union
    # of all exposure cohorts, extract the union as well as the covariates and outcomes for union. Then,
    # when constructing the CohortMethodData object, we split them up for the respective target-comparator
    # pairs.
    # Covariates that are to be excluded during the data fetch for the union (so those that apply to all
    # TCs) are specified in inst/settings/indications.csv. Covariates that are to be excluded when
    # constructing the CohortMethodData objects (so those specific to a TC) are stored in the file
    # filterConceps.rds.

    ParallelLogger::logInfo("Fetching all data from the server")
    indicationFolder <- file.path(outputFolder, indicationId)
    exposureSummary <- read.csv(file.path(indicationFolder,
                                          "pairedExposureSummaryFilteredBySize.csv"))

    outcomeFold <- file.path(outputFolder, "outcome")
    counts <- read.csv(file.path(outcomeFold, "cohortCounts.csv"))
    outcomeIds <- counts$cohortDefinitionId

    if (useSample) {
        # Sample is used for feasibility assessment
        cohortTable <- paste(tablePrefix, tolower(indicationId), "sample_cohort", sep = "_")
        covariatesFolder <- file.path(indicationFolder, "sampleCovariates.zip")
        cohortsFolder <- file.path(indicationFolder, "sampleCohorts")
        outcomesFolder <- file.path(indicationFolder, "sampleOutcomes.zip")
    } else {
        cohortTable <- paste(tablePrefix, tolower(indicationId), "cohort", sep = "_")
        covariatesFolder <- file.path(indicationFolder, "allCovariates.zip")
        cohortsFolder <- file.path(indicationFolder, "allCohorts")
        outcomesFolder <- file.path(indicationFolder, "allOutcomes.zip")
    }

    conn <- DatabaseConnector::connect(connectionDetails)
    on.exit(DatabaseConnector::disconnect(conn))

    # Upload comparisons with enough data ---------------------------------------------------------
    uniqueCohortTable <- data.frame(cohortDefinitionId = unique(c(exposureSummary$targetId,
                                                                  exposureSummary$comparatorId)))
    colnames(uniqueCohortTable) <- SqlRender::camelCaseToSnakeCase(colnames(uniqueCohortTable))
    DatabaseConnector::insertTable(connection = conn,
                                   tableName = "#comparisons",
                                   data = uniqueCohortTable,
                                   dropTableIfExists = TRUE,
                                   createTable = TRUE,
                                   tempTable = TRUE,
                                   oracleTempSchema = oracleTempSchema)

    # Lump persons of interest into one table -----------------------------------------------------
    sql <- SqlRender::loadRenderTranslateSql("UnionExposureCohorts.sql",
                                             "LegendT2dm",
                                             dbms = connectionDetails$dbms,
                                             oracleTempSchema = oracleTempSchema,
                                             cohort_database_schema = cohortDatabaseSchema,
                                             # cdm_database_schema = cdmDatabaseSchema,
                                             cohort_table = cohortTable)
    DatabaseConnector::executeSql(conn, sql, progressBar = FALSE, reportOverallTime = FALSE)

    # allExposureCohorts <- DatabaseConnector::querySql(conn, sql = "SELECT * FROM #exposure_cohorts;")
    # saveRDS(allExposureCohorts, "backup.rds")

    # Drop comparisons temp table ----------------------------------------------------------------
    sql <- "TRUNCATE TABLE #comparisons; DROP TABLE #comparisons;"
    sql <- SqlRender::translate(sql = sql,
                                targetDialect = connectionDetails$dbms,
                                oracleTempSchema = oracleTempSchema)
    DatabaseConnector::executeSql(conn, sql, progressBar = FALSE, reportOverallTime = FALSE)

    # Construct covariates ---------------------------------------------------------------------
    pathToCsv <- system.file("settings", "Indications.csv", package = "LegendT2dm")
    indications <- read.csv(pathToCsv)
    filterConceptIds <- as.character(indications$filterConceptIds[indications$indicationId == indicationId])
    filterConceptIds <- as.numeric(strsplit(filterConceptIds, split = ";")[[1]])

    # Specify covariates for analyses
    defaultCovariateSettings <- FeatureExtraction::createDefaultCovariateSettings(excludedCovariateConceptIds = filterConceptIds,
                                                                                  addDescendantsToExclude = TRUE)

    # add continuous age to covariates
    defaultCovariateSettings$DemographicsAge = TRUE

    # Add subgroupCovariateSettings here (see Legend package )
    covariateSettings <- list(defaultCovariateSettings)

    if (!file.exists(covariatesFolder) || forceNewObjects) {
        covariates <- FeatureExtraction::getDbCovariateData(connection = conn,
                                                            oracleTempSchema = oracleTempSchema,
                                                            cdmDatabaseSchema = cdmDatabaseSchema,
                                                            cdmVersion = 5,
                                                            cohortTable = "#exposure_cohorts",
                                                            cohortTableIsTemp = TRUE,
                                                            rowIdField = "row_id",
                                                            covariateSettings = covariateSettings,
                                                            aggregated = FALSE)
        FeatureExtraction::saveCovariateData(covariates, covariatesFolder)
    }

    # Retrieve cohorts -------------------------------------------------------------------------
    ParallelLogger::logInfo("Retrieving cohorts")
    start <- Sys.time()
    if (!file.exists(cohortsFolder)) {
        dir.create(cohortsFolder)
    }
    getCohorts <- function(i) {
        targetId <- exposureSummary$targetId[i]
        comparatorId <- exposureSummary$comparatorId[i]
        fileName <- file.path(cohortsFolder, paste0("cohorts_t", targetId, "_c", comparatorId, ".zip"))
        if (!file.exists(fileName) || forceNewObjects) {
            renderedSql <- SqlRender::loadRenderTranslateSql("CreateCohorts.sql",
                                                             packageName = "CohortMethod",
                                                             dbms = connectionDetails$dbms,
                                                             tempEmulationSchema = oracleTempSchema,
                                                             cdm_database_schema = cdmDatabaseSchema,
                                                             exposure_database_schema = cohortDatabaseSchema,
                                                             exposure_table = cohortTable,
                                                             cdm_version = 5,
                                                             target_id = targetId,
                                                             comparator_id = comparatorId,
                                                             study_start_date = "",
                                                             study_end_date = studyEndDate,
                                                             first_only = TRUE,
                                                             remove_duplicate_subjects = "keep first",  # TODO Check change "FALSE"
                                                             washout_period = 0,
                                                             restrict_to_common_period = FALSE)
            DatabaseConnector::executeSql(conn, renderedSql)

            andromeda <- Andromeda::andromeda()

            cohortSql <- SqlRender::loadRenderTranslateSql("GetCohorts.sql",
                                                           packageName = "LegendT2dm",
                                                           dbms = connectionDetails$dbms,
                                                           tempEmulationSchema = oracleTempSchema,
                                                           cdm_version = 5,
                                                           target_id = targetId,
                                                           sampled = FALSE)
            DatabaseConnector::querySqlToAndromeda(conn, cohortSql,
                                                              andromeda, "cohorts",
                                                              snakeCaseToCamelCase = TRUE)
            # ParallelLogger::logDebug("Fetched cohort total rows in target is ", sum(cohorts$treatment), ", total rows in comparator is ", sum(!cohorts$treatment))
            # saveRDS(cohorts, fileName)
            # ParallelLogger::logDebug("Saved ", fileName)

            # fileName <- file.path(cohortsFolder, paste0("outcomes_t", targetId, "_c", comparatorId, ".rds"))
            outcomeCohortTable <- paste(tablePrefix, "outcome", "cohort", sep = "_")
            outcomeSql <- SqlRender::loadRenderTranslateSql("GetOutcomes.sql",
                                                            packageName = "LegendT2dm",
                                                            dbms = connectionDetails$dbms,
                                                            tempEmulationSchema = oracleTempSchema,
                                                            cdm_database_schema = cdmDatabaseSchema,
                                                            outcome_database_schema = cohortDatabaseSchema,
                                                            outcome_table = outcomeCohortTable,
                                                            outcome_ids = outcomeIds,
                                                            cdm_version = 5,
                                                            sampled = FALSE)
            DatabaseConnector::querySqlToAndromeda(conn, outcomeSql,
                                                               andromeda, "outcomes",
                                                               snakeCaseToCamelCase = TRUE)
            # ParallelLogger::logDebug("Fetched outcomes total count is ", nrow(outcomes))
            # saveRDS(list(cohorts = cohorts, outcomes = outcomes), fileName)
            Andromeda::saveAndromeda(andromeda, fileName)
            ParallelLogger::logDebug("Saved ", fileName)
        }

        return(NULL)
    }
    plyr::llply(1:nrow(exposureSummary), getCohorts, .progress = "text")
    delta <- Sys.time() - start
    writeLines(paste("Retrieving cohorts took", signif(delta, 3), attr(delta, "units")))

    # # Create single file with unique rowId - cohort definition ID combinations:
    # allCohorts <- data.frame()
    # for (i in 1:nrow(exposureSummary)) {
    #     targetId <- exposureSummary$targetId[i]
    #     comparatorId <- exposureSummary$comparatorId[i]
    #     fileName <- file.path(cohortsFolder, paste0("cohorts_t", targetId, "_c", comparatorId, ".rds"))
    #     cohorts <- readRDS(fileName)
    #     idxTarget <- !(cohorts$rowId %in% allCohorts$rowId[allCohorts$cohortId == targetId]) & cohorts$treatment ==
    #         1
    #     idxComparator <- !(cohorts$rowId %in% allCohorts$rowId[allCohorts$cohortId == comparatorId]) &
    #         cohorts$treatment == 0
    #     if (any(idxTarget) | any(idxComparator)) {
    #         cohorts$cohortId <- targetId
    #         cohorts$cohortId[cohorts$treatment == 0] <- comparatorId
    #         cohorts$treatment <- NULL
    #         allCohorts <- rbind(allCohorts, cohorts[idxTarget | idxComparator, ])
    #     }
    # }
    # saveRDS(allCohorts, file.path(cohortsFolder, "allCohorts.rds"))

    # Retrieve outcomes -------------------------------------------------------------------
    # ParallelLogger::logInfo("Retrieving outcomes")
    #
    # if (!file.exists(outcomesFolder) || forceNewObjects) {
    #     outcomeCohortTable <- paste(tablePrefix, "outcome", "cohort", sep = "_")
    #     sql <- SqlRender::loadRenderTranslateSql("GetOutcomes.sql",
    #                                              "LegendT2dm",
    #                                              dbms = connectionDetails$dbms,
    #                                              oracleTempSchema = oracleTempSchema,
    #                                              cdm_database_schema = cdmDatabaseSchema,
    #                                              outcome_database_schema = cohortDatabaseSchema,
    #                                              outcome_table = outcomeCohortTable,
    #                                              outcome_ids = outcomeIds)
    #
    #     outcomes <- Andromeda::andromeda()
    #     DatabaseConnector::querySqlToAndromeda(conn, sql,
    #                                            andromeda = outcomes,
    #                                            andromedaTableName = "outcomes",
    #                                            snakeCaseToCamelCase = TRUE)
    #     Andromeda::saveAndromeda(outcomes, fileName = outcomesFolder)
    # }

    #
    # # Retrieve filter concepts ---------------------------------------------------------
    # if (indicationId == "Hypertension") {
    #     # First-line therapy only: hypertension drugs already filtered at data fetch
    #     filterConcepts <- data.frame(conceptId = -1, filterConceptId = -1, filterConceptName = "")
    #     saveRDS(filterConcepts, file.path(indicationFolder, "filterConceps.rds"))
    # } else {
    #    # Cut
    # }

    # Drop exposure_cohorts temp table ----------------------------------------------------------------
    sql <- "TRUNCATE TABLE #exposure_cohorts; DROP TABLE #exposure_cohorts;"
    sql <- SqlRender::translate(sql = sql,
                                targetDialect = connectionDetails$dbms,
                                oracleTempSchema = oracleTempSchema)
    DatabaseConnector::executeSql(conn, sql, progressBar = FALSE, reportOverallTime = FALSE)
}

#' Construct all cohortMethodData object
#'
#' @details
#' This function constructs all cohortMethodData objects using the data fetched earlier using the
#' \code{\link{fetchAllDataFromServer}} function.
#'
#' @param outputFolder   Name of local folder to place results; make sure to use forward slashes (/)
#' @param indicationId   A string denoting the indicationId.
#' @param useSample      Use the sampled cohort table instead of the main cohort table (for PS model
#'                       feasibility).
#' @param restrictToOt1  Limit \code{CohortMethod} data objects to only comparisons that use On-Treatment-1?
#' @param maxCores       How many parallel cores should be used? If more cores are made available this
#'                       can speed up the analyses.
#'
#' @importFrom tibble tibble
#'
#' @export
generateAllCohortMethodDataObjects <- function(outputFolder,
                                               indicationId = "legendt2dm",
                                               useSample = FALSE,
                                               restrictToOt1 = FALSE,
                                               maxCores = 4) {
    ParallelLogger::logInfo("Constructing CohortMethodData objects")
    indicationFolder <- file.path(outputFolder, indicationId)
    start <- Sys.time()
    exposureSummary <- read.csv(file.path(indicationFolder, "pairedExposureSummaryFilteredBySize.csv"))

    if (useSample) {
        folderName <- file.path(indicationFolder, "cmSampleOutput")
    } else {
        folderName <- file.path(indicationFolder, "cmOutput")
    }

    if (!dir.exists(folderName)) {
        dir.create(folderName, recursive = TRUE)
    }

    createObject <- function(i, exposureSummary, indicationFolder, useSample) {
        targetId <- exposureSummary$targetId[i]
        comparatorId <- exposureSummary$comparatorId[i]
        fileName <- file.path(folderName, paste0("CmData_l1_t", targetId, "_c", comparatorId, ".zip"))

        execute <- !restrictToOt1 || isOt1(targetId)

        if (!file.exists(fileName) && execute) {
            cmData <- constructCohortMethodDataObject(targetId = targetId,
                                                      comparatorId = comparatorId,
                                                      indicationFolder = indicationFolder,
                                                      useSample = useSample)
            CohortMethod::saveCohortMethodData(cmData, fileName)
        }
        return(NULL)
    }

    cluster <- ParallelLogger::makeCluster(min(maxCores, 8))
    ParallelLogger::clusterApply(cluster = cluster,
                                 x = 1:nrow(exposureSummary),
                                 fun = createObject,
                                 exposureSummary = exposureSummary,
                                 indicationFolder = indicationFolder,
                                 useSample = useSample)
    ParallelLogger::stopCluster(cluster)
    delta <- Sys.time() - start
    ParallelLogger::logInfo(paste("Generating all CohortMethodData objects took",
                                  signif(delta, 3),
                                  attr(delta, "units")))
}

constructCohortMethodDataObject <- function(targetId, comparatorId, indicationFolder, useSample) {
    ParallelLogger::logInfo("Creating cohort method data object for target ", targetId, " and comparator ", comparatorId)
    if (useSample) {
        # Sample is used for feasibility assessment
        covariatesFolder <- file.path(indicationFolder, "sampleCovariates.zip")
        cohortsFolder <- file.path(indicationFolder, "sampleCohorts")
        outcomesFolder <- file.path(indicationFolder, "sampleOutcomes.zip")
    } else {
        covariatesFolder <- file.path(indicationFolder, "allCovariates.zip")
        cohortsFolder <- file.path(indicationFolder, "allCohorts")
        outcomesFolder <- file.path(indicationFolder, "allOutcomes.zip")
    }
    # copying cohorts
    ParallelLogger::logTrace("Copying cohorts")

    fileName <- file.path(cohortsFolder, paste0("cohorts_t", targetId, "_c", comparatorId, ".zip"))
    andromeda <- Andromeda::loadAndromeda(fileName)
    targetPersons <- length(unique(andromeda$cohorts %>% filter(.data$treatment == 1) %>%
                                       select(.data$personSeqId) %>% pull()))
    comparatorPersons <- length(unique(andromeda$cohorts %>% filter(.data$treatment == 0) %>%
                                           select(.data$personSeqId) %>% pull()))
    targetExposures <- length(andromeda$cohorts %>% filter(.data$treatment == 1) %>%
                                  select(.data$personSeqId) %>% pull())
    comparatorExposures <- length(andromeda$cohorts %>% filter(.data$treatment == 0) %>%
                                      select(.data$personSeqId) %>% pull())

    counts <- tibble(description = "Starting cohorts",
                     targetPersons = targetPersons,
                     comparatorPersons = comparatorPersons,
                     targetExposures = targetExposures,
                     comparatorExposures = comparatorExposures)

    metaData <- list(populationSize = targetPersons + comparatorPersons,
                     cohortId = -1,
                     targetId = targetId,
                     studyStartDate = "",
                     studyEndDate = "",
                     comparatorId = comparatorId,
                     attrition = counts)

    # # Subsetting outcomes
    # ParallelLogger::logTrace("Subsetting outcomes")
    #
    # andromeda <- Andromeda::loadAndromeda(outcomesFolder) %>% Andromeda::copyAndromeda()
    # andromeda$cohorts <- cohorts
    #
    # andromeda$outcomes <- andromeda$outcomes %>%
    #     inner_join(andromeda$cohorts %>% select(.data$rowId), by = "rowId")

    if (!useSample) {

        # Add injected outcomes (no signal injection when doing sampling)

        # injectionSummary <- read.csv(file.path(indicationFolder, "signalInjectionSummary.csv"),
        #                              stringsAsFactors = FALSE)
        # injectionSummary <- injectionSummary[injectionSummary$exposureId == targetId |
        #                                          injectionSummary$exposureId == comparatorId, ]
        # injectionSummary <- injectionSummary[injectionSummary$outcomesToInjectFile != "", ]
        #
        # if (nrow(injectionSummary) > 0) {
        #     # Add original (background) negative control outcomes
        #     bgOutcomes <- merge(outcomes, injectionSummary[, c("outcomeId", "newOutcomeId")])
        #     bgOutcomes$outcomeId <- bgOutcomes$newOutcomeId
        #     outcomes <- rbind(outcomes, bgOutcomes[, colnames(outcomes)])
        #
        #     # Add additional outcomes
        #     synthOutcomes <- lapply(injectionSummary$outcomesToInjectFile, readRDS)
        #     synthOutcomes <- do.call("rbind", synthOutcomes)
        #     colnames(synthOutcomes)[colnames(synthOutcomes) == "cohortStartDate"] <- "eventDate"
        #     colnames(synthOutcomes)[colnames(synthOutcomes) == "cohortDefinitionId"] <- "outcomeId"
        #     synthOutcomes <- merge(synthOutcomes, cohorts[, c("rowId", "subjectId", "cohortStartDate")])
        #     synthOutcomes$daysToEvent <- synthOutcomes$eventDate - synthOutcomes$cohortStartDate
        #     outcomes <- rbind(outcomes, synthOutcomes[, colnames(outcomes)])
        # }
    }

    metaData$outcomeIds = distinct(andromeda$outcomes %>% select(.data$outcomeId)) %>%
        arrange(.data$outcomeId) %>% pull()

    attr(andromeda, "metaData") <- metaData

    # Subsetting covariates
    ParallelLogger::logTrace("Subsetting covariates")
    covariateData <- FeatureExtraction::loadCovariateData(covariatesFolder)

    andromeda$analysisRef <- covariateData$analysisRef

    # OLD CODE
    # andromeda$covariates <- covariateData$covariates %>%
    #     inner_join(andromeda$cohorts %>% select(.data$rowId), by = "rowId", copy = TRUE)

    # NEW CODE (start)
    rowIds <- andromeda$cohorts %>% pull(.data$rowId)

    subsetCovariates <- function(batch) {
      subset <- batch %>% filter(.data$rowId %in% rowIds)

      if ("covariates" %in% names(andromeda)) {
        Andromeda::appendToTable(andromeda$covariates, subset)
      } else {
        andromeda$covariates <- subset
      }

      return(NULL)
    }

    invisible(Andromeda::batchApply(covariateData$covariates, subsetCovariates, batchSize = 1e+07))
    # NEW CODE (end)

    andromeda$covariateRef <- covariateData$covariateRef %>%
        inner_join(andromeda$covariates %>% distinct(.data$covariateId), by = "covariateId", copy = TRUE)

    # Filtering covariates
    if (FALSE) {   # TODO: Not yet implemented
        ParallelLogger::logTrace("Filtering covariates")

        stop("Not yet implemented")

        # filterConcepts <- readRDS(file.path(indicationFolder, "filterConceps.rds"))
        # filterConcepts <- filterConcepts[filterConcepts$cohortId %in% c(targetId, comparatorId), ]
        # filterConceptIds <- unique(filterConcepts$filterConceptId)
        # if (length(filterConceptIds) == 0) {
        #     covariateRef <- covariateData$covariateRef
        # } else {
        #     idx <- ffbase::`%in%`(covariateData$covariateRef$conceptId, ff::as.ff(filterConceptIds))
        #     covariateRef <- covariateData$covariateRef[!idx, ]
        #     filterCovariateIds <- covariateData$covariateRef$covariateId[idx, ]
        #     idx <- !ffbase::`%in%`(covariates$covariateId, filterCovariateIds)
        #     covariates <- covariates[idx, ]
        # }
    }

    class(andromeda) <- "CohortMethodData"
    attr(class(andromeda), "package") <- "CohortMethod"

    return(andromeda)
}
