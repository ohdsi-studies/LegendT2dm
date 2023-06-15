# add a "diagnostics" table on the results database

#schema = "legendt2dm_drug_results"
schema = "legendt2dm_class_results"

connectionDetails <- DatabaseConnector::createConnectionDetails(
  dbms = "postgresql",
  server = paste(keyring::key_get("ohdsiPostgresServer"),
                 keyring::key_get("ohdsiPostgresShinyDatabase"),
                 sep = "/"),
  user = keyring::key_get("ohdsiPostgresUser"),
  password = keyring::key_get("ohdsiPostgresPassword"))

connection = DatabaseConnector::connect(connectionDetails)


##### create an additional diagnostics on the results schema
DatabaseConnector::executeSql(
  connection,
  sprintf("SET search_path TO %s;", schema),
  progressBar = FALSE,
  reportOverallTime = FALSE
)

sql <- "DROP TABLE IF EXISTS diagnostics;
        CREATE TABLE diagnostics (
            database_id VARCHAR(255) NOT NULL,
            analysis_id INTEGER NOT NULL,
            target_id BIGINT NOT NULL,
            comparator_id BIGINT NOT NULL,
            outcome_id BIGINT NOT NULL,
            mdrr NUMERIC ,
            any_outcomes INTEGER ,
            min_equipoise NUMERIC ,
            max_abs_std_diff_mean NUMERIC ,
            ease NUMERIC ,
            pass INTEGER ,
            criteria VARCHAR(255) ,
            PRIMARY KEY(database_id, analysis_id, target_id, comparator_id, outcome_id)
        );"

DatabaseConnector::executeSql(connection, sql)


##### upload drug-level study diagnostics manually to test

diagnostics = readRDS('extra/diagnostics.rds') %>%
  mutate(anyOutcomes = if_else(anyOutcomes, 1, 0), # convert TRUE/FALSE to 0/1
         ease = 0,
         pass = (
           (mdrr < 4.0) &
             (maxAbsStdDiffMean < 0.15) &
             (minEquipoise > 0.25)
         ),
         criteria = "legend-htn: mdrr < 4.0; max_sdm < 0.15; equipoise > 0.25") %>%
  mutate(pass = ifelse(!is.na(pass) && pass, 1, 0)) %>%
  select(-minBoundOnMdrr)

diagnostics$mdrr[which(is.infinite(diagnostics$mdrr))] = NA # manually map Inf to NA

names(diagnostics) = SqlRender::camelCaseToSnakeCase(names(diagnostics))

DatabaseConnector::insertTable(
  connection = connection,
  tableName = paste(schema, "diagnostics", sep = "."),
  data = diagnostics,
  dropTableIfExists = FALSE,
  createTable = FALSE,
  tempTable = FALSE,
  progressBar = TRUE
)

# # sanity check
# sql <- "SELECT COUNT(*) FROM cohort_method_result"
# result_count = DatabaseConnector::querySql(connection, sql)

DatabaseConnector::disconnect(connection)
