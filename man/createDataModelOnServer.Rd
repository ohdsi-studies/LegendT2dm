% Generated by roxygen2: do not edit by hand
% Please edit documentation in R/BackendDatabase.R
\name{createDataModelOnServer}
\alias{createDataModelOnServer}
\title{Create the data model tables on a database server.}
\usage{
createDataModelOnServer(
  connection = NULL,
  connectionDetails = NULL,
  schema,
  sqlFileName,
  package = "LegendT2dm"
)
}
\arguments{
\item{schema}{The schema on the postgres server where the tables will be created.}
}
\description{
Create the data model tables on a database server.
}
\details{
Only PostgreSQL servers are supported.
}
