
#' @export
getAbsStdDiff <- function(connection,
                          resultsDatabaseSchema,
                          targetId,
                          comparatorId,
                          analysisId,
                          outcomeId = 0) {

  sql <- paste0("SET search_path TO ", resultsDatabaseSchema, ";")
  DatabaseConnector::executeSql(connection = connection, sql = sql)

  sql <- "
      SELECT database_id, analysis_id, target_id, comparator_id, outcome_id,
        MAX(ABS(std_diff_after)) as abs_std_diff
      FROM covariate_balance
      WHERE target_id in (@target_id)
      AND comparator_id in (@comparator_id)
      AND analysis_id in (@analysis_id)
      AND outcome_id = @outcome_id
      GROUP BY database_id, analysis_id, target_id, comparator_id, outcome_id"
  sql <- SqlRender::render(sql,
                           target_id = targetId,
                           comparator_id = comparatorId,
                           analysis_id = analysisId,
                           outcome_id = outcomeId)
  sql <- SqlRender::translate(sql, targetDialect = connection@dbms)
  absStdDiff <- DatabaseConnector::querySql(connection, sql)
  colnames(absStdDiff) <- SqlRender::snakeCaseToCamelCase(colnames(absStdDiff))

  remainingAnalysisId <- setdiff(analysisId, c(5,6))
  if (length(remainingAnalysisId) > 0) {
    duplicated <- do.call("rbind",
                          lapply(remainingAnalysisId, function(id) {
                            mappedId <- mapAnalysisIdForBalance(id)
                            slice <- absStdDiff %>% filter(analysisId == mappedId) %>%
                              mutate(analysisId = id)
                            if (id %in% c(7,8,9,18,19)) {
                              slice <- slice %>%
                                mutate(targetId = makeOt2(targetId),
                                       comparatorId = makeOt2(comparatorId))
                            }
                            return(slice)
                          }))
    absStdDiff <- rbind(absStdDiff, duplicated)
  }

  return(absStdDiff)
}

mapAnalysisIdForBalance <- function(analysisId) {
  map <- c(1,5,6,
           4,5,6,
           7,5,6,
           0,
           11,5,6,
           14,5,6,
           17,5,6)
  return(map[analysisId])
}

#' @export
getCovariateBalance <- function(connection,
                                resultsDatabaseSchema,
                                targetId,
                                comparatorId,
                                analysisId,
                                databaseId = NULL,
                                outcomeId = NULL,
                                mapAnalysis = TRUE) {

  sql <- paste0("SET search_path TO ", resultsDatabaseSchema, ";")
  DatabaseConnector::executeSql(connection = connection, sql = sql)

  if (is.null(outcomeId)) {
    outcomeId <- 0
  }

  if (mapAnalysis) {
    analysisId <- mapAnalysisIdForBalance(analysisId)
  }

  sql <- "
      SELECT covariate.database_id, covariate.covariate_id, covariate_name, covariate_analysis_id,
        target_mean_before, comparator_mean_before, std_diff_before,
        target_mean_after, comparator_mean_after, std_diff_after
      FROM covariate_balance
      INNER JOIN covariate
      ON covariate_balance.covariate_id = covariate.covariate_id
      AND covariate_balance.database_id = covariate.database_id
      AND covariate_balance.analysis_id = covariate.analysis_id
      WHERE target_id = @target_id
      AND comparator_id = @comparator_id
      AND covariate.database_id = '@database_id'
      AND covariate.analysis_id = @analysis_id
      AND outcome_id = @outcome_id"
  sql <- SqlRender::render(sql,
                           target_id = targetId,
                           comparator_id = comparatorId,
                           database_id = databaseId,
                           analysis_id = analysisId,
                           outcome_id = outcomeId)
  sql <- SqlRender::translate(sql, targetDialect = connection@dbms)
  balance <- DatabaseConnector::querySql(connection, sql)

  colnames(balance) <- c("databaseId",
                         "covariateId",
                         "covariateName",
                         "analysisId",
                         "beforeMatchingMeanTreated",
                         "beforeMatchingMeanComparator",
                         "beforeMatchingStdDiff",
                         "afterMatchingMeanTreated",
                         "afterMatchingMeanComparator",
                         "afterMatchingStdDiff")
  balance$absBeforeMatchingStdDiff <- abs(balance$beforeMatchingStdDiff)
  balance$absAfterMatchingStdDiff <- abs(balance$afterMatchingStdDiff)

  return(balance)
}

#' @export
getMainResultsTable <- function(connection,
                                resultsDatabaseSchema,
                                outcomeIds) {

  sql <- paste0("SET search_path TO ", resultsDatabaseSchema, ";")
  DatabaseConnector::executeSql(connection = connection, sql = sql)

  sql <- paste0(
    "SELECT * FROM cohort_method_result WHERE outcome_id IN (",
    paste(outcomeIds, collapse = ","),
    ")")

  cmTable <- DatabaseConnector::querySql(connection, sql)
  colnames(cmTable) <- SqlRender::snakeCaseToCamelCase(colnames(cmTable))

  # Add derived quantities
  alpha <- 0.05
  power <- 0.8
  z1MinAlpha <- qnorm(1 - alpha/2)
  zBeta <- -qnorm(1 - power)
  pA <- cmTable$targetSubjects / (cmTable$targetSubjects + cmTable$comparatorSubjects)
  pB <- 1 - pA
  totalEvents <- abs(cmTable$targetOutcomes) + abs(cmTable$comparatorOutcomes)
  cmTable$mdrr <- exp(sqrt((zBeta + z1MinAlpha)^2/(totalEvents * pA * pB)))
  cmTable$targetYears <- cmTable$targetDays / 365.25
  cmTable$comparatorYears <- cmTable$comparatorDays / 365.25
  cmTable$targetIr <- 1000 * cmTable$targetOutcomes / cmTable$targetYears
  cmTable$comparatorIr <- 1000 * cmTable$comparatorOutcomes / cmTable$comparatorYears
  cmTable$minBoundOnMdrr <- (cmTable$targetOutcomes < 0 | cmTable$comparatorOutcomes < 0)

  return(cmTable)
}

#' @export
computeEquipoise <- function(connection,
                             resultsDatabaseSchema,
                             targetIds, comparatorIds,
                             equipoiseMin = 0.3,
                             equipoiseMax = 0.7) {

  sql <- paste0("SET search_path TO ", resultsDatabaseSchema, ";")
  DatabaseConnector::executeSql(connection = connection, sql = sql)

  sql <- "select psd1.database_id,
  psd1.target_id,
  psd1.comparator_id,
  sum(case when preference_score between @min and @max then target_density else 0 end)/sum(target_density) as target_equipoise,
  sum(case when preference_score between @min and @max then comparator_density else 0 end)/sum(comparator_density) as comparator_equipoise,
  case when sum(case when preference_score between @min and @max then target_density else 0 end)/sum(target_density) < sum(case when preference_score between @min and @max then comparator_density else 0 end)/sum(comparator_density)
    then sum(case when preference_score between @min and @max then target_density else 0 end)/sum(target_density)
    else sum(case when preference_score between @min and @max then comparator_density else 0 end)/sum(comparator_density)
    end as min_equipoise
  from preference_score_dist psd1
  where target_id in (@target_id)
  and comparator_id in (@comparator_id)
  group by psd1.database_id, psd1.target_id, psd1.comparator_id
  order by psd1.target_id, psd1.comparator_id, psd1.database_id"

  sql <- SqlRender::render(sql,
                           target_id = targetIds,
                           comparator_id = comparatorIds,
                           min = equipoiseMin,
                           max = equipoiseMax)

  sql <- SqlRender::translate(sql, targetDialect = connection@dbms)
  eq <- querySql(connection, sql)

  colnames(eq) <- SqlRender::snakeCaseToCamelCase(colnames(eq))
  return(eq)
}

#' @export
makeDiagnosticsTable <- function(connection,
                                 resultsDatabaseSchema,
                                 tcs,
                                 databaseIds,
                                 analysisIds = c(5,6),
                                 outcomeIds) {

  ParallelLogger::logInfo("Computing equipoise")

  equipoise <- computeEquipoise(connection = connection,
                                resultsDatabaseSchema = resultsDatabaseSchema,
                                targetId = tcs$targetId,
                                comparatorId = tcs$comparatorId)

  ParallelLogger::logInfo("\n", "Computing balance")

  arguments <- merge(merge(tcs, data.frame(analysisId = analysisIds)), data.frame(databaseId = databaseIds))

  absStdDiff <- getAbsStdDiff(connection = connection,
                              resultsDatabaseSchema = resultsDatabaseSchema,
                              targetId = tcs$targetId,
                              comparatorId = tcs$comparatorId,
                              analysisId = analysisIds) %>%
    select(-outcomeId) %>% rename(maxAbsStdDiffMean = absStdDiff)

  merged1 <- arguments %>% left_join(equipoise %>% select(-targetEquipoise, -comparatorEquipoise),
                                    by = c("databaseId", "targetId", "comparatorId"))

  merged2 <- merged1 %>% left_join(absStdDiff,
                                 by = c("databaseId", "targetId", "comparatorId", "analysisId"))

  ParallelLogger::logInfo("\n", "Computing MDRR")

  cm <- getMainResultsTable(connection = connection,
                            resultsDatabaseSchema = resultsDatabaseSchema,
                            outcomeIds = outcomeIds) %>%
    mutate(anyOutcomes = !(targetOutcomes == 0 & comparatorOutcomes == 0)) %>%
    select(databaseId, analysisId, targetId, comparatorId, outcomeId, mdrr, minBoundOnMdrr, anyOutcomes)

  merged3 <- cm %>% inner_join(merged2, by = c("databaseId", "targetId", "comparatorId", "analysisId")) %>%
    arrange(databaseId, analysisId, targetId, comparatorId)

  return(merged3)
}

develop <- function() {

  library(dplyr)

  legendT2dmConnectionDetails <- DatabaseConnector::createConnectionDetails(
    dbms = "postgresql",
    server = paste(keyring::key_get("legendt2dmServer"),
                   keyring::key_get("legendt2dmDatabase"),
                   sep = "/"),
    user = keyring::key_get("legendt2dmUser"),
    password = keyring::key_get("legendt2dmPassword"))

  connection <- DatabaseConnector::connect(legendT2dmConnectionDetails)

#   balanceTable <- getCovariateBalance(connection = connection,
#                                       resultsDatabaseSchema = "legendt2dm_class_results",
#                                       targetId = 101100000,
#                                       comparatorId = 201100000,
#                                       analysisId = 5,
#                                       databaseId = "CCAE")


  tcs <- read.csv(system.file("settings", "classTcosOfInterest.csv", package = "LegendT2dm")) %>% dplyr::select(targetId, comparatorId)
  outcomeIds <- read.csv(system.file("settings", "OutcomesOfInterest.csv", package = "LegendT2dm")) %>% dplyr::select(cohortId) %>% pull(cohortId)

  databaseIds <- c("OptumEHR", "MDCR", "OptumDod", "UK_IMRD", "MDCD", "CCAE", "US_Open_Claims", "SIDIAP")

  diagnostics <- makeDiagnosticsTable(connection = connection,
                                      resultsDatabaseSchema = "legendt2dm_class_results",
                                      tcs = tcs,
                                      outcomeIds = outcomeIds,
                                      analysisIds = c(5,6),
                                      databaseIds = databaseIds)

  saveRDS(diagnostics, "diagnostics.Rds")

  DatabaseConnector::disconnect(connection)


  diagnostics <- readRDS("diagnostics.Rds")

  # Remove no outcomes
  diagnostics <- diagnostics %>% filter(is.finite(mdrr))
  nrow(diagnostics)

  # Remove MDRR > 2
  diagnostics <- diagnostics %>% filter(mdrr < 2)
  nrow(diagnostics)

  ggplot(diagnostics,
         aes(x=maxAbsStdDiffMean, fill=databaseId)) +
    geom_histogram() +
    geom_vline(xintercept=c(0.1,0.2), linetype="dotted")

  # Remove stdDiff > 0.1
  diagnostics <- diagnostics %>% filter(maxAbsStdDiffMean < 0.1)
  nrow(diagnostics)

  diagnostics %>% group_by(databaseId) %>% tally()

  ggplot(diagnostics,
         aes(x=maxAbsStdDiffMean, fill=databaseId)) +
    geom_histogram(right = TRUE, bins = 101) +
    geom_vline(xintercept=c(0.1,0.2), linetype="dotted")

}
