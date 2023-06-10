# add a "diagnostics" table on the results database

schema = "legendt2dm_drug_results"

connectionDetails <- DatabaseConnector::createConnectionDetails(
  dbms = "postgresql",
  server = paste(keyring::key_get("ohdsiPostgresServer"),
                 keyring::key_get("ohdsiPostgresShinyDatabase"),
                 sep = "/"),
  user = keyring::key_get("ohdsiPostgresUser"),
  password = keyring::key_get("ohdsiPostgresPassword"))

connection = DatabaseConnector::connect(connectionDetails)

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
            mdrr DOUBLE PRECISION  ,
            min_bound_on_mdrr INTEGER ,
            any_outcomes INTEGER ,
            min_equipoise NUMERIC ,
            max_abs_std_diff_mean NUMERIC ,
            PRIMARY KEY(database_id, analysis_id, target_id, comparator_id, outcome_id)
        );"

DatabaseConnector::executeSql(connection, sql)

# sql <- "SELECT COUNT(*) FROM cohort_method_result"
# result_count = DatabaseConnector::querySql(connection, sql)

diagnostics = readRDS('extra/diagnostics.rds') %>%
  mutate(minBoundOnMdrr = as.integer(minBoundOnMdrr),
         anyOutcomes = as.integer(anyOutcomes)) # convert TRUE/FALSE to 0/1 here...

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

DatabaseConnector::disconnect(connection)
