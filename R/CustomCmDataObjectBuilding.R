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
    counts <- read.csv(file.path(indicationFolder, "cohortCounts.csv"))
    outcomeIds <- counts$cohortDefinitionId

    if (useSample) {
        # Sample is used for feasibility assessment
        pairedCohortTable <- paste(tablePrefix, tolower(indicationId), "sample_cohort", sep = "_")
        covariatesFolder <- file.path(indicationFolder, "sampleCovariates")
        cohortsFolder <- file.path(indicationFolder, "sampleCohorts")
        outcomesFolder <- file.path(indicationFolder, "sampleOutcomes")
    } else {
        pairedCohortTable <- paste(tablePrefix, tolower(indicationId), "pair_cohort", sep = "_")
        covariatesFolder <- file.path(indicationFolder, "allCovariates")
        cohortsFolder <- file.path(indicationFolder, "allCohorts")
        outcomesFolder <- file.path(indicationFolder, "allOutcomes")
    }

    conn <- DatabaseConnector::connect(connectionDetails)
    on.exit(DatabaseConnector::disconnect(conn))

    # Upload comparisons with enough data ---------------------------------------------------------
    table <- exposureSummary[, c("targetId", "comparatorId")]
    colnames(table) <- SqlRender::camelCaseToSnakeCase(colnames(table))
    DatabaseConnector::insertTable(connection = conn,
                                   tableName = "#comparisons",
                                   data = table,
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
                                             paired_cohort_table = pairedCohortTable)
    DatabaseConnector::executeSql(conn, sql, progressBar = FALSE, reportOverallTime = FALSE)


    # Drop comparisons temp table ----------------------------------------------------------------
    sql <- "TRUNCATE TABLE #comparisons; DROP TABLE #comparisons;"
    sql <- SqlRender::translateSql(sql = sql,
                                   targetDialect = connectionDetails$dbms,
                                   oracleTempSchema = oracleTempSchema)$sql
    DatabaseConnector::executeSql(conn, sql, progressBar = FALSE, reportOverallTime = FALSE)

    # Construct covariates ---------------------------------------------------------------------
    pathToCsv <- system.file("settings", "Indications.csv", package = "Legend")
    indications <- read.csv(pathToCsv)
    filterConceptIds <- as.character(indications$filterConceptIds[indications$indicationId == indicationId])
    filterConceptIds <- as.numeric(strsplit(filterConceptIds, split = ";")[[1]])
    defaultCovariateSettings <- FeatureExtraction::createDefaultCovariateSettings(excludedCovariateConceptIds = filterConceptIds,
                                                                                  addDescendantsToExclude = TRUE)

    # Add subgroupCovariateSettings here (see Legend package )
    covariateSettings <- list(defaultCovariateSettings)

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

    # Retrieve cohorts -------------------------------------------------------------------------
    ParallelLogger::logInfo("Retrieving cohorts")
    start <- Sys.time()
    if (!file.exists(cohortsFolder)) {
        dir.create(cohortsFolder)
    }
    getCohorts <- function(i) {
        targetId <- exposureSummary$targetId[i]
        comparatorId <- exposureSummary$comparatorId[i]
        fileName <- file.path(cohortsFolder, paste0("cohorts_t", targetId, "_c", comparatorId, ".rds"))
        if (!file.exists(fileName)) {
            sql <- SqlRender::loadRenderTranslateSql("GetExposureCohorts.sql",
                                                     "LegendT2dm",
                                                     dbms = connectionDetails$dbms,
                                                     oracleTempSchema = oracleTempSchema,
                                                     cdm_database_schema = cdmDatabaseSchema,
                                                     cohort_database_schema = cohortDatabaseSchema,
                                                     paired_cohort_table = pairedCohortTable,
                                                     target_id = targetId,
                                                     comparator_id = comparatorId)
            cohorts <- DatabaseConnector::querySql(conn, sql)
            colnames(cohorts) <- SqlRender::snakeCaseToCamelCase(colnames(cohorts))
            saveRDS(cohorts, fileName)
        }
        return(NULL)
    }
    plyr::llply(1:nrow(exposureSummary), getCohorts, .progress = "text")
    delta <- Sys.time() - start
    writeLines(paste("Retrieving cohorts took", signif(delta, 3), attr(delta, "units")))

    # Create single file with unique rowId - cohort definition ID combinations:
    allCohorts <- data.frame()
    for (i in 1:nrow(exposureSummary)) {
        targetId <- exposureSummary$targetId[i]
        comparatorId <- exposureSummary$comparatorId[i]
        fileName <- file.path(cohortsFolder, paste0("cohorts_t", targetId, "_c", comparatorId, ".rds"))
        cohorts <- readRDS(fileName)
        idxTarget <- !(cohorts$rowId %in% allCohorts$rowId[allCohorts$cohortId == targetId]) & cohorts$treatment ==
            1
        idxComparator <- !(cohorts$rowId %in% allCohorts$rowId[allCohorts$cohortId == comparatorId]) &
            cohorts$treatment == 0
        if (any(idxTarget) | any(idxComparator)) {
            cohorts$cohortId <- targetId
            cohorts$cohortId[cohorts$treatment == 0] <- comparatorId
            cohorts$treatment <- NULL
            allCohorts <- rbind(allCohorts, cohorts[idxTarget | idxComparator, ])
        }
    }
    saveRDS(allCohorts, file.path(cohortsFolder, "allCohorts.rds"))

    # Retrieve outcomes -------------------------------------------------------------------
    ParallelLogger::logInfo("Retrieving outcomes")
    outcomeCohortTable <- paste(tablePrefix, "outcome", "cohort", sep = "_")
    sql <- SqlRender::loadRenderTranslateSql("GetOutcomes.sql",
                                             "LegendT2dm",
                                             dbms = connectionDetails$dbms,
                                             oracleTempSchema = oracleTempSchema,
                                             cdm_database_schema = cdmDatabaseSchema,
                                             outcome_database_schema = cohortDatabaseSchema,
                                             outcome_table = outcomeCohortTable,
                                             outcome_ids = outcomeIds)
    outcomes <- DatabaseConnector::querySql.ffdf(conn, sql)
    colnames(outcomes) <- SqlRender::snakeCaseToCamelCase(colnames(outcomes))
    ffbase::save.ffdf(outcomes, dir = outcomesFolder)
    ff::close.ffdf(outcomes)

    # Retrieve filter concepts ---------------------------------------------------------
    if (indicationId == "Hypertension") {
        # First-line therapy only: hypertension drugs already filtered at data fetch
        filterConcepts <- data.frame(conceptId = -1, filterConceptId = -1, filterConceptName = "")
        saveRDS(filterConcepts, file.path(indicationFolder, "filterConceps.rds"))
    } else {
        ParallelLogger::logInfo("Retrieving filter concepts")
        pathToCsv <- system.file("settings", "ExposuresOfInterest.csv", package = "Legend")
        exposuresOfInterest <- read.csv(pathToCsv)
        exposuresOfInterest <- exposuresOfInterest[exposuresOfInterest$indicationId == indicationId, ]
        getDescendants <- function(i) {
            if (exposuresOfInterest$includedConceptIds[i] == "") {
                ancestor <- data.frame(ancestorConceptId = exposuresOfInterest$cohortId[i],
                                       descendantConceptId = exposuresOfInterest$conceptId[i])
            } else {
                descendantConceptIds <- as.numeric(strsplit(as.character(exposuresOfInterest$includedConceptIds[i]),
                                                            ";")[[1]])
                ancestor <- data.frame(ancestorConceptId = exposuresOfInterest$cohortId[i],
                                       descendantConceptId = descendantConceptIds)
            }
            return(ancestor)
        }
        ancestor <- lapply(1:nrow(exposuresOfInterest), getDescendants)
        ancestor <- do.call("rbind", ancestor)
        sql <- SqlRender::loadRenderTranslateSql("GetFilterConcepts.sql",
                                                 "Legend",
                                                 dbms = connectionDetails$dbms,
                                                 oracleTempSchema = oracleTempSchema,
                                                 cdm_database_schema = cdmDatabaseSchema,
                                                 exposure_concept_ids = unique(ancestor$descendantConceptId))
        filterConcepts <- DatabaseConnector::querySql(conn, sql)
        colnames(filterConcepts) <- SqlRender::snakeCaseToCamelCase(colnames(filterConcepts))
        filterConcepts <- merge(ancestor, data.frame(descendantConceptId = filterConcepts$conceptId,
                                                     filterConceptId = filterConcepts$filterConceptId,
                                                     filterConceptName = filterConcepts$filterConceptName))
        filterConcepts <- data.frame(cohortId = filterConcepts$ancestorConceptId,
                                     filterConceptId = filterConcepts$filterConceptId,
                                     filterConceptName = filterConcepts$filterConceptName)
        saveRDS(filterConcepts, file.path(indicationFolder, "filterConceps.rds"))
    }

    # Drop exposure_cohorts temp table ----------------------------------------------------------------
    sql <- "TRUNCATE TABLE #exposure_cohorts; DROP TABLE #exposure_cohorts;"
    sql <- SqlRender::translateSql(sql = sql,
                                   targetDialect = connectionDetails$dbms,
                                   oracleTempSchema = oracleTempSchema)$sql
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
#' @param maxCores       How many parallel cores should be used? If more cores are made available this
#'                       can speed up the analyses.
#'
#' @export
generateAllCohortMethodDataObjects <- function(outputFolder,
                                               indicationId = "Depression",
                                               useSample = FALSE,
                                               maxCores = 4) {
    ParallelLogger::logInfo("Constructing CohortMethodData objects")
    indicationFolder <- file.path(outputFolder, indicationId)
    start <- Sys.time()
    exposureSummary <- read.csv(file.path(indicationFolder, "pairedExposureSummaryFilteredBySize.csv"))

    createObject <- function(i, exposureSummary, indicationFolder, useSample) {
        targetId <- exposureSummary$targetId[i]
        comparatorId <- exposureSummary$comparatorId[i]
        if (useSample) {
            # Sample is used for feasibility assessment
            folderName <- file.path(indicationFolder,
                                    "cmSampleOutput",
                                    paste0("CmData_l1_t", targetId, "_c", comparatorId))
        } else {
            folderName <- file.path(indicationFolder,
                                    "cmOutput",
                                    paste0("CmData_l1_t", targetId, "_c", comparatorId))
        }
        if (!file.exists(folderName)) {
            cmData <- Legend:::constructCohortMethodDataObject(targetId = targetId,
                                                               comparatorId = comparatorId,
                                                               indicationFolder = indicationFolder,
                                                               useSample = useSample)
            CohortMethod::saveCohortMethodData(cmData, folderName, compress = TRUE)
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
        covariatesFolder <- file.path(indicationFolder, "sampleCovariates")
        cohortsFolder <- file.path(indicationFolder, "sampleCohorts")
        outcomesFolder <- file.path(indicationFolder, "sampleOutcomes")
    } else {
        covariatesFolder <- file.path(indicationFolder, "allCovariates")
        cohortsFolder <- file.path(indicationFolder, "allCohorts")
        outcomesFolder <- file.path(indicationFolder, "allOutcomes")
    }
    # copying cohorts
    ParallelLogger::logTrace("Copying cohorts")
    fileName <- file.path(cohortsFolder, paste0("cohorts_t", targetId, "_c", comparatorId, ".rds"))
    cohorts <- readRDS(fileName)
    targetPersons <- length(unique(cohorts$subjectId[cohorts$treatment == 1]))
    comparatorPersons <- length(unique(cohorts$subjectId[cohorts$treatment == 0]))
    targetExposures <- length(cohorts$subjectId[cohorts$treatment == 1])
    comparatorExposures <- length(cohorts$subjectId[cohorts$treatment == 0])
    counts <- data.frame(description = "Starting cohorts",
                         targetPersons = targetPersons,
                         comparatorPersons = comparatorPersons,
                         targetExposures = targetExposures,
                         comparatorExposures = comparatorExposures)
    metaData <- list(targetId = targetId, comparatorId = comparatorId, attrition = counts)
    attr(cohorts, "metaData") <- metaData

    # Subsetting outcomes
    ParallelLogger::logTrace("Subsetting outcomes")
    outcomes <- NULL
    ffbase::load.ffdf(dir = outcomesFolder)  # Loads outcomes
    ff::open.ffdf(outcomes, readonly = TRUE)
    idx <- ffbase::`%in%`(outcomes$rowId, ff::as.ff(cohorts$rowId))
    if (ffbase::any.ff(idx)) {
        outcomes <- ff::as.ram(outcomes[idx, ])
    } else {
        outcomes <- as.data.frame(outcomes[1, ])
        outcomes <- outcomes[T == F, ]
    }
    if (!useSample) {
        # Add injected outcomes (no signal injection when doing sampling)
        injectionSummary <- read.csv(file.path(indicationFolder, "signalInjectionSummary.csv"),
                                     stringsAsFactors = FALSE)
        injectionSummary <- injectionSummary[injectionSummary$exposureId == targetId |
                                                 injectionSummary$exposureId == comparatorId, ]
        injectionSummary <- injectionSummary[injectionSummary$outcomesToInjectFile != "", ]

        if (nrow(injectionSummary) > 0) {
            # Add original (background) negative control outcomes
            bgOutcomes <- merge(outcomes, injectionSummary[, c("outcomeId", "newOutcomeId")])
            bgOutcomes$outcomeId <- bgOutcomes$newOutcomeId
            outcomes <- rbind(outcomes, bgOutcomes[, colnames(outcomes)])

            # Add additional outcomes
            synthOutcomes <- lapply(injectionSummary$outcomesToInjectFile, readRDS)
            synthOutcomes <- do.call("rbind", synthOutcomes)
            colnames(synthOutcomes)[colnames(synthOutcomes) == "cohortStartDate"] <- "eventDate"
            colnames(synthOutcomes)[colnames(synthOutcomes) == "cohortDefinitionId"] <- "outcomeId"
            synthOutcomes <- merge(synthOutcomes, cohorts[, c("rowId", "subjectId", "cohortStartDate")])
            synthOutcomes$daysToEvent <- synthOutcomes$eventDate - synthOutcomes$cohortStartDate
            outcomes <- rbind(outcomes, synthOutcomes[, colnames(outcomes)])
        }
    }
    metaData <- data.frame(outcomeIds = unique(outcomes$outcomeId))
    attr(outcomes, "metaData") <- metaData

    # Subsetting covariates
    ParallelLogger::logTrace("Subsetting covariates")
    covariateData <- FeatureExtraction::loadCovariateData(covariatesFolder)
    idx <- ffbase::`%in%`(covariateData$covariates$rowId, ff::as.ff(cohorts$rowId))
    covariates <- covariateData$covariates[idx, ]

    # Filtering covariates
    ParallelLogger::logTrace("Filtering covariates")
    filterConcepts <- readRDS(file.path(indicationFolder, "filterConceps.rds"))
    filterConcepts <- filterConcepts[filterConcepts$cohortId %in% c(targetId, comparatorId), ]
    filterConceptIds <- unique(filterConcepts$filterConceptId)
    if (length(filterConceptIds) == 0) {
        covariateRef <- covariateData$covariateRef
    } else {
        idx <- ffbase::`%in%`(covariateData$covariateRef$conceptId, ff::as.ff(filterConceptIds))
        covariateRef <- covariateData$covariateRef[!idx, ]
        filterCovariateIds <- covariateData$covariateRef$covariateId[idx, ]
        idx <- !ffbase::`%in%`(covariates$covariateId, filterCovariateIds)
        covariates <- covariates[idx, ]
    }
    result <- list(cohorts = cohorts,
                   outcomes = outcomes,
                   covariates = covariates,
                   covariateRef = covariateRef,
                   analysisRef = ff::clone.ffdf(covariateData$analysisRef),
                   metaData = covariateData$metaData)

    class(result) <- "cohortMethodData"
    return(result)
}
