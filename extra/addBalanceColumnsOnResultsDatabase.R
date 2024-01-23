# add additional columns to the "covariate_balance" table on the results database

schema = "legendt2dm_drug_results"
#schema = "legendt2dm_class_results"

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

sql <- "ALTER TABLE covariate_balance
        ADD COLUMN interaction_covariate_id BIGINT ,
        ADD COLUMN target_sd_before NUMERIC ,
        ADD COLUMN comparator_sd_before NUMERIC ,
        ADD COLUMN mean_before NUMERIC ,
        ADD COLUMN sd_before NUMERIC ,
        ADD COLUMN target_sd_after NUMERIC ,
        ADD COLUMN comparator_sd_after NUMERIC ,
        ADD COLUMN mean_after NUMERIC ,
        ADD COLUMN sd_after NUMERIC ,
        ADD COLUMN target_sum_before NUMERIC ,
        ADD COLUMN comparator_sum_before NUMERIC ,
        ADD COLUMN target_sum_after NUMERIC ,
        ADD COLUMN comparator_sum_after NUMERIC;"

DatabaseConnector::executeSql(connection, sql)

DatabaseConnector::disconnect(connection)

## test it by uploading one table
outputFolder = "rrr"
balanceExportPath = file.path(outputFolder, "drug", "export", "covariate_balance.csv")
balance = readr::read_csv(balanceExportPath)

names(balance) = SqlRender::camelCaseToSnakeCase(names(diagnostics))

DatabaseConnector::insertTable(
  connection = connection,
  tableName = paste(schema, "covariate_balance", sep = "."),
  data = balance,
  dropTableIfExists = FALSE,
  createTable = FALSE,
  tempTable = FALSE,
  progressBar = TRUE
)


exportFolder = "~/Downloads/export_example/"
tablesNames = c("covariate")

uploadResultsToDatabaseFromCsv(connectionDetails = connectionDetails,
                               schema = schema,
                               exportFolder = exportFolder, tableNames = c("covariate"),
                               specifications = read_csv("inst/settings/ResultsModelSpecs1.csv"))

## check on uploaded portion
sql <- "SELECT * FROM covariate_balance
        WHERE covariate_id = 1002
        AND database_id = 'OptumEHR';"

sel_bal <- DatabaseConnector::querySql(connection, sql)
names(sel_bal) = tolower(names(sel_bal))
