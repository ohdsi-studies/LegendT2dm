working_directory <- "/workdir"
study_package_directory <- "/workdir/LegendT2dm"
r_env_cache_folder <- "/workdir/renv_cache"
renv_package_version <- '0.13.2'
renv_vesion <- "v5"
r_version <- "R-4.0"
linux_version <- "x86_64-pc-linux-gnu"
renv_final_path <- paste(r_env_cache_folder,
                         renv_vesion,
                         r_version,
                         linux_version,
                         sep="/")

setwd(working_directory)
.libPaths(renv_final_path)


jsonPath <- "/workdir/gcloud/application_default_credentials.json"
bqDriverPath <- "/workdir/workdir/bq_jdbc"
project_id <- "allennlp"
dataset_id <- "jdposada_explore"

connectionString <-  BQJdbcConnectionStringR::createBQConnectionString(projectId = project_id,
                                              defaultDataset = dataset_id,
                                              authType = 2,
                                              jsonCredentialsPath = jsonPath)

connectionDetails <- DatabaseConnector::createConnectionDetails(dbms="bigquery",
                                                                connectionString=connectionString,
                                                                user="",
                                                                password='',
                                                                pathToDriver = bqDriverPath)

# Create a connection
connection <- DatabaseConnector::connect(connectionDetails)

# Test with a sql query to the care site table

sql <- "
SELECT
 COUNT(1) as counts
FROM
 `bigquery-public-data.cms_synthetic_patient_data_omop.care_site`
"

counts <- DatabaseConnector::querySql(connection, sql)

print(counts)