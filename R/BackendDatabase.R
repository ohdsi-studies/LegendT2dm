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
#

#' Grant read-permission on server
#'
#' @details
#' Only PostgreSQL servers are supported.
#'
#'
#' @param connectionDetails   An object of type \code{connectionDetails} as created using the
#'                            \code{\link[DatabaseConnector]{createConnectionDetails}} function in the
#'                            DatabaseConnector package. Can be left NULL if \code{connection} is
#'                            provided.
#' @param schema        Schema name for read-permission
#' @param user          User name for read-permission
#'
#' @export
grantPermissionOnServer <- function(connectionDetails,
                                    schema,
                                    user = "legendt2dm_readonly") {
  sql <- paste0("grant select on all tables in schema ", schema, " to ", user, ";")
  connection <- DatabaseConnector::connect(connectionDetails)
  DatabaseConnector::executeSql(connection, sql)
  DatabaseConnector::disconnect(connection)
}

#' Create a SQL file to construct data model tables on a database server.
#'
#' @details
#' Only PostgreSQL servers are supported.
#'
#' @param specifications Specifications data table
#' @param fileName       Output name for SQL file
#' @param tab            Tab characters to use
#'
#' @export
createDataModelSqlFile <- function(specifications,
                                   fileName,
                                   tab = "    ") {

  zz <- file(fileName, open = "wt")
  capture.output({
    tables <- split(specifications, specifications$tableName)

    writeLines("-- Drop old tables if exists\n")
    for (table in tables) {
      writeLines(sprintf("DROP TABLE IF EXISTS %s;", table$tableName[1]))
    }

    writeLines("\n-- Create tables\n")

    for (table in tables) {

      writeLines(sprintf("CREATE TABLE %s (", table$tableName[1]))

      write.table(table %>% mutate(notNull = ifelse(tolower(.data$isRequired) == "yes", "NOT NULL", ""),
                                   type = toupper(.data$type),
                                   tab = tab) %>%
                    select(.data$tab, .data$fieldName, .data$type, .data$notNull),
                  quote = FALSE, row.names = FALSE, col.names = FALSE, eol = ",\n")

      keys <- paste(table %>% filter(tolower(.data$primaryKey) == "yes") %>% pull(.data$fieldName), collapse = ", ")
      writeLines(sprintf("%s PRIMARY KEY(%s)", tab, keys))
      writeLines(");\n")
    }
  }, file = zz, type = "output")
  close(zz)
}

#' Create the data model tables on a database server.
#'
#' @details
#' Only PostgreSQL servers are supported.
#'
#' @param connectionDetails   An object of type \code{connectionDetails} as created using the
#'                            \code{\link[DatabaseConnector]{createConnectionDetails}} function in the
#'                            DatabaseConnector package. Can be left NULL if \code{connection} is
#'                            provided.
#' @param connection          An object of type \code{connection} as created using the
#'                            \code{\link[DatabaseConnector]{connect}} function in the
#'                            DatabaseConnector package. Can be left NULL if \code{connectionDetails}
#'                            is provided, in which case a new connection will be opened at the start
#'                            of the function, and closed when the function finishes.
#' @param schema         The schema on the postgres server where the tables will be created.
#' @param sqlFileName    File name of table creation SQL within \code{package}.
#' @param package        Package name containing the \code{sqlFileName} file.
#'
#' @export
createDataModelOnServer <- function(connection = NULL,
                                    connectionDetails = NULL,
                                    schema,
                                    sqlFileName,
                                    package = "LegendT2dm") {
  if (is.null(connection)) {
    if (!is.null(connectionDetails)) {
      connection <- DatabaseConnector::connect(connectionDetails)
      on.exit(DatabaseConnector::disconnect(connection))
    } else {
      stop("No connection or connectionDetails provided.")
    }
  }
  schemas <- unlist(
    DatabaseConnector::querySql(
      connection,
      "SELECT schema_name FROM information_schema.schemata;",
      snakeCaseToCamelCase = TRUE
    )[, 1]
  )
  if (!tolower(schema) %in% tolower(schemas)) {
    stop(
      "Schema '",
      schema,
      "' not found on database. Only found these schemas: '",
      paste(schemas, collapse = "', '"),
      "'"
    )
  }
  DatabaseConnector::executeSql(
    connection,
    sprintf("SET search_path TO %s;", schema),
    progressBar = FALSE,
    reportOverallTime = FALSE
  )
  pathToSql <-
    system.file("sql", "postgresql", sqlFileName, package = package)
  sql <- SqlRender::readSql(pathToSql)
  DatabaseConnector::executeSql(connection, sql)
}

fixTableMetadataForBackwardCompatibility <- function(table, tableName) {
  if (tableName %in% c("cohort", "phenotype_description")) {
    if (!'metadata' %in% colnames(table)) {
      data <- list()
      for (i in (1:nrow(table))) {
        data[[i]] <- table[i,]
        colnamesDf <- colnames(data[[i]])
        metaDataList <- list()
        for (j in (1:length(colnamesDf))) {
          metaDataList[[colnamesDf[[j]]]] = data[[i]][colnamesDf[[j]]] %>% dplyr::pull()
        }
        data[[i]]$metadata <-
          RJSONIO::toJSON(metaDataList, pretty = TRUE, digits = 23)
      }
      table <- dplyr::bind_rows(data)
    }
    if ('referent_concept_id' %in% colnames(table)) {
      table <- table %>%
        dplyr::select(-.data$referent_concept_id)
    }
  }
  if (tableName %in% c('covariate_value', 'temporal_covariate_value')) {
    if (!'sum_value' %in% colnames(table)) {
      table$sum_value <- -1
    }
  }
  return(table)
}

checkFixColumnNames <-
  function(table,
           tableName,
           zipFileName,
           convertFromCamelCase,
           specifications) {
    if (tableName %in% c('cohort', 'phenotype_description',
                         'covariate_value', 'temporal_covariate_value')) {
      table <- fixTableMetadataForBackwardCompatibility(table = table,
                                                        tableName = tableName)
    }

    if (convertFromCamelCase) {
      colnames(table) <- SqlRender::camelCaseToSnakeCase(colnames(table)) # MAS ADDED
    }

    observeredNames <- colnames(table)[order(colnames(table))]

    tableSpecs <- specifications %>%
      dplyr::filter(.data$tableName == !!tableName)

    optionalNames <- tableSpecs %>%
      dplyr::filter(.data$optional == "Yes") %>%
      dplyr::select(.data$fieldName)

    expectedNames <- tableSpecs %>%
      dplyr::select(.data$fieldName) %>%
      dplyr::anti_join(dplyr::filter(optionalNames, !.data$fieldName %in% observeredNames),
                       by = "fieldName") %>%
      dplyr::arrange(.data$fieldName) %>%
      dplyr::pull()

    if (!(all(expectedNames %in% observeredNames))) {
      stop(
        sprintf(
          "Column names of table %s in zip file %s do not match specifications.\n- Observed columns: %s\n- Expected columns: %s",
          tableName,
          zipFileName,
          paste(observeredNames, collapse = ", "),
          paste(expectedNames, collapse = ", ")
        )
      )
    }

    table <- table %>% select(expectedNames)

    return(table)
  }

checkAndFixDataTypes <-
  function(table,
           tableName,
           zipFileName,
           specifications) {
    tableSpecs <- specifications %>%
      filter(.data$tableName == !!tableName)

    observedTypes <- sapply(table, class)
    for (i in 1:length(observedTypes)) {
      fieldName <- names(observedTypes)[i]
      expectedType <-
        gsub("\\(.*\\)", "", tolower(tableSpecs$type[tableSpecs$fieldName == fieldName]))
      if (expectedType == "bigint" || expectedType == "float") {
        if (observedTypes[i] != "numeric" && observedTypes[i] != "double") {
          ParallelLogger::logDebug(
            sprintf(
              "Field %s in table %s in zip file %s is of type %s, but was expecting %s. Attempting to convert.",
              fieldName,
              tableName,
              zipFileName,
              observedTypes[i],
              expectedType
            )
          )
          table <- mutate_at(table, i, as.numeric)
        }
      } else if (expectedType == "int") {
        if (observedTypes[i] != "integer") {
          ParallelLogger::logDebug(
            sprintf(
              "Field %s in table %s in zip file %s is of type %s, but was expecting %s. Attempting to convert.",
              fieldName,
              tableName,
              zipFileName,
              observedTypes[i],
              expectedType
            )
          )
          table <- mutate_at(table, i, as.integer)
        }
      } else if (expectedType == "varchar") {
        if (observedTypes[i] != "character") {
          ParallelLogger::logDebug(
            sprintf(
              "Field %s in table %s in zip file %s is of type %s, but was expecting %s. Attempting to convert.",
              fieldName,
              tableName,
              zipFileName,
              observedTypes[i],
              expectedType
            )
          )
          table <- mutate_at(table, i, as.character)
        }
      } else if (expectedType == "date") {
        if (observedTypes[i] != "Date") {
          ParallelLogger::logDebug(
            sprintf(
              "Field %s in table %s in zip file %s is of type %s, but was expecting %s. Attempting to convert.",
              fieldName,
              tableName,
              zipFileName,
              observedTypes[i],
              expectedType
            )
          )
          table <- mutate_at(table, i, as.Date, origin = "1970-01-01")
        }
      }
    }
    return(table)
  }

checkAndFixDuplicateRows <-
  function(table,
           tableName,
           zipFileName,
           specifications) {
    primaryKeys <- specifications %>%
      dplyr::filter(.data$tableName == !!tableName &
                      .data$primaryKey == "Yes") %>%
      dplyr::select(.data$fieldName) %>%
      dplyr::pull()
    duplicatedRows <- duplicated(table[, primaryKeys])
    if (any(duplicatedRows)) {
      warning(
        sprintf(
          "Table %s in zip file %s has duplicate rows. Removing %s records.",
          tableName,
          zipFileName,
          sum(duplicatedRows)
        )
      )
      return(table[!duplicatedRows,])
    } else {
      return(table)
    }
  }

appendNewRows <-
  function(data,
           newData,
           tableName,
           specifications) {
    if (nrow(data) > 0) {
      primaryKeys <- specifications %>%
        dplyr::filter(.data$tableName == !!tableName &
                        .data$primaryKey == "Yes") %>%
        dplyr::select(.data$fieldName) %>%
        dplyr::pull()
      newData <- newData %>%
        dplyr::anti_join(data, by = primaryKeys)
    }
    return(dplyr::bind_rows(data, newData))
  }

naToEmpty <- function(x) {
  x[is.na(x)] <- ""
  return(x)
}

naToZero <- function(x) {
  x[is.na(x)] <- 0
  return(x)
}

#' Upload results to the database server.
#'
#' @description
#' Requires the results data model tables have been created using the \code{\link{createResultsDataModel}} function.
#'
#' Set the POSTGRES_PATH environmental variable to the path to the folder containing the psql executable to enable
#' bulk upload (recommended).
#'
#' @param connectionDetails   Object of type \code{connectionDetails} as created using the
#'                            \code{\link[DatabaseConnector]{createConnectionDetails}} function in the
#'                            DatabaseConnector package.
#' @param schema         Schema on the postgres server where the tables have been created.
#' @param zipFileName    Name of single or vector of multiple zip files.
#' @param specifications Specification of results tables
#' @param forceOverWriteOfSpecifications  If TRUE, specifications of the phenotypes, cohort definitions, and analysis
#'                       will be overwritten if they already exist on the database. Only use this if these specifications
#'                       have changed since the last upload.
#' @param purgeSiteDataBeforeUploading If TRUE, before inserting data for a specific databaseId all the data for
#'                       that site will be dropped. This assumes the input zip file contains the full data for that
#'                       data site.
#' @param convertFromCamelCase  Convert column names from camelCase to snake_case when uploading?                       .
#' @param tempFolder     Folder on the local file system where the zip files are extracted to. Will be cleaned
#'                       up when the function is finished. Can be used to specify a temp folder on a drive that
#'                       has sufficient space if the default system temp space is too limited.
#'
#'
#' @export
uploadResultsToDatabase <- function(connectionDetails,
                                    schema,
                                    zipFileName,
                                    specifications,
                                    forceOverWriteOfSpecifications = FALSE,
                                    purgeSiteDataBeforeUploading = FALSE,
                                    convertFromCamelCase = FALSE,
                                    tempFolder = tempdir()) {

  if (length(zipFileName) > 1) {
    for (i in 1:length(zipFileName)) {
      uploadResultsToDatabaseImpl(connectionDetails = connectionDetails,
                                  schema = schema,
                                  zipFileName = zipFileName[i],
                                  specifications = specifications,
                                  forceOverWriteOfSpecifications = forceOverWriteOfSpecifications,
                                  purgeSiteDataBeforeUploading = purgeSiteDataBeforeUploading,
                                  convertFromCamelCase = convertFromCamelCase,
                                  tempFolder = file.path(tempFolder, i))
    }
  } else {
    uploadResultsToDatabaseImpl(connectionDetails = connectionDetails,
                                schema = schema,
                                zipFileName = zipFileName,
                                specifications = specifications,
                                forceOverWriteOfSpecifications = forceOverWriteOfSpecifications,
                                purgeSiteDataBeforeUploading = purgeSiteDataBeforeUploading,
                                convertFromCamelCase = convertFromCamelCase,
                                tempFolder = tempFolder)
  }
}

uploadResultsToDatabaseImpl <- function(connectionDetails, schema, zipFileName, specifications,
                                        forceOverWriteOfSpecifications, purgeSiteDataBeforeUploading,
                                        convertFromCamelCase, tempFolder) {
  start <- Sys.time()
  connection <- DatabaseConnector::connect(connectionDetails)
  on.exit(DatabaseConnector::disconnect(connection))

  unzipFolder <- tempfile("unzipTempFolder", tmpdir = tempFolder)
  dir.create(path = unzipFolder, recursive = TRUE)
  on.exit(unlink(unzipFolder, recursive = TRUE), add = TRUE)

  ParallelLogger::logInfo("Unzipping ", zipFileName)
  zip::unzip(zipFileName, exdir = unzipFolder)

  if (purgeSiteDataBeforeUploading) {
    database <-
      readr::read_csv(file = file.path(unzipFolder, "database.csv"),
                      col_types = readr::cols())
    colnames(database) <-
      SqlRender::snakeCaseToCamelCase(colnames(database))
    databaseId <- database$databaseId
  }

  uploadTable <- function(tableName) {
    ParallelLogger::logInfo("Uploading table ", tableName)

    primaryKey <- specifications %>%
      filter(.data$tableName == !!tableName &
               .data$primaryKey == "Yes") %>%
      select(.data$fieldName) %>%
      pull()

    if (purgeSiteDataBeforeUploading &&
        "database_id" %in% primaryKey) {
      deleteAllRecordsForDatabaseId(
        connection = connection,
        schema = schema,
        tableName = tableName,
        databaseId = databaseId
      )
    }

    csvFileName <- paste0(tableName, ".csv")
    if (csvFileName %in% list.files(unzipFolder)) {
      env <- new.env()
      env$schema <- schema
      env$tableName <- tableName
      env$primaryKey <- primaryKey
      if (purgeSiteDataBeforeUploading &&
          "database_id" %in% primaryKey) {
        env$primaryKeyValuesInDb <- NULL
      } else {
        sql <- "SELECT DISTINCT @primary_key FROM @schema.@table_name;"
        sql <- SqlRender::render(
          sql = sql,
          primary_key = primaryKey,
          schema = schema,
          table_name = tableName
        )
        primaryKeyValuesInDb <-
          DatabaseConnector::querySql(connection, sql)
        colnames(primaryKeyValuesInDb) <-
          tolower(colnames(primaryKeyValuesInDb))
        env$primaryKeyValuesInDb <- primaryKeyValuesInDb
      }

      uploadChunk <- function(chunk, pos) {
        ParallelLogger::logInfo("- Preparing to upload rows ",
                                pos,
                                " through ",
                                pos + nrow(chunk) - 1)

        chunk <- checkFixColumnNames(
          table = chunk,
          tableName = env$tableName,
          zipFileName = zipFileName,
          specifications = specifications,
          convertFromCamelCase = convertFromCamelCase
        )
        chunk <- checkAndFixDataTypes(
          table = chunk,
          tableName = env$tableName,
          zipFileName = zipFileName,
          specifications = specifications
        )
        chunk <- checkAndFixDuplicateRows(
          table = chunk,
          tableName = env$tableName,
          zipFileName = zipFileName,
          specifications = specifications
        )

        # Primary key fields cannot be NULL, so for some tables convert NAs to empty or zero:
        toEmpty <- specifications %>%
          filter(
            .data$tableName == env$tableName &
              .data$emptyIsNa == "No" & grepl("varchar", .data$type)
          ) %>%
          select(.data$fieldName) %>%
          pull()
        if (length(toEmpty) > 0) {
          chunk <- chunk %>%
            dplyr::mutate_at(toEmpty, naToEmpty)
        }

        tozero <- specifications %>%
          filter(
            .data$tableName == env$tableName &
              .data$emptyIsNa == "No" &
              .data$type %in% c("int", "bigint", "float", "numeric")
          ) %>%
          select(.data$fieldName) %>%
          pull()
        if (length(tozero) > 0) {
          chunk <- chunk %>%
            dplyr::mutate_at(tozero, naToZero)
        }

        # Check if inserting data would violate primary key constraints:
        if (!is.null(env$primaryKeyValuesInDb)) {
          primaryKeyValuesInChunk <- unique(chunk[env$primaryKey])
          duplicates <- inner_join(env$primaryKeyValuesInDb,
                                   primaryKeyValuesInChunk,
                                   by = env$primaryKey)
          if (nrow(duplicates) != 0) {
            if ("database_id" %in% env$primaryKey ||
                forceOverWriteOfSpecifications) {
              ParallelLogger::logInfo(
                "- Found ",
                nrow(duplicates),
                " rows in database with the same primary key ",
                "as the data to insert. Deleting from database before inserting."
              )
              deleteFromServer(
                connection = connection,
                schema = env$schema,
                tableName = env$tableName,
                keyValues = duplicates
              )

            } else {
              ParallelLogger::logInfo(
                "- Found ",
                nrow(duplicates),
                " rows in database with the same primary key ",
                "as the data to insert. Removing from data to insert."
              )
              chunk <- chunk %>%
                anti_join(duplicates, by = env$primaryKey)
            }
            # Remove duplicates we already dealt with:
            env$primaryKeyValuesInDb <- env$primaryKeyValuesInDb %>%
              anti_join(duplicates, by = env$primaryKey)
          }
        }
        if (nrow(chunk) == 0) {
          ParallelLogger::logInfo("- No data left to insert")
        } else {
          DatabaseConnector::insertTable(
            connection = connection,
            tableName = paste(env$schema, env$tableName, sep = "."),
            data = chunk,
            dropTableIfExists = FALSE,
            createTable = FALSE,
            tempTable = FALSE,
            progressBar = TRUE
          )
        }
      }
      readr::read_csv_chunked(
        file = file.path(unzipFolder, csvFileName),
        callback = uploadChunk,
        chunk_size = 1e7,
        col_types = readr::cols(),
        guess_max = 1e6,
        progress = FALSE
      )

      # chunk <- readr::read_csv(file = file.path(unzipFolder, csvFileName),
      # col_types = readr::cols(),
      # guess_max = 1e6)

    }
  }
  invisible(lapply(unique(specifications$tableName), uploadTable))
  delta <- Sys.time() - start
  writeLines(paste("Uploading data took", signif(delta, 3), attr(delta, "units")))
}

deleteFromServer <-
  function(connection, schema, tableName, keyValues) {
    createSqlStatement <- function(i) {
      sql <- paste0(
        "DELETE FROM ",
        schema,
        ".",
        tableName,
        "\nWHERE ",
        paste(paste0(
          colnames(keyValues), " = '", keyValues[i,], "'"
        ), collapse = " AND "),
        ";"
      )
      return(sql)
    }
    batchSize <- 1000
    for (start in seq(1, nrow(keyValues), by = batchSize)) {
      end <- min(start + batchSize - 1, nrow(keyValues))
      sql <- sapply(start:end, createSqlStatement)
      sql <- paste(sql, collapse = "\n")
      DatabaseConnector::executeSql(
        connection,
        sql,
        progressBar = FALSE,
        reportOverallTime = FALSE,
        runAsBatch = TRUE
      )
    }
  }

deleteAllRecordsForDatabaseId <- function(connection,
                                          schema,
                                          tableName,
                                          databaseId) {
  sql <-
    "SELECT COUNT(*) FROM @schema.@table_name WHERE database_id = '@database_id';"
  sql <- SqlRender::render(
    sql = sql,
    schema = schema,
    table_name = tableName,
    database_id = databaseId
  )
  databaseIdCount <-
    DatabaseConnector::querySql(connection, sql)[, 1]
  if (databaseIdCount != 0) {
    ParallelLogger::logInfo(
      sprintf(
        "- Found %s rows in  database with database ID '%s'. Deleting all before inserting.",
        databaseIdCount,
        databaseId
      )
    )
    sql <-
      "DELETE FROM @schema.@table_name WHERE database_id = '@database_id';"
    sql <- SqlRender::render(
      sql = sql,
      schema = schema,
      table_name = tableName,
      database_id = databaseId
    )
    DatabaseConnector::executeSql(connection,
                                  sql,
                                  progressBar = FALSE,
                                  reportOverallTime = FALSE)
  }
}
