% Generated by roxygen2: do not edit by hand
% Please edit documentation in R/BackendDatabase.R
\name{grantPermissionOnServer}
\alias{grantPermissionOnServer}
\title{Create a SQL file to construct data model tables on a database server.}
\usage{
grantPermissionOnServer(
  connectionDetails,
  schema,
  user = "legendt2dm_readonly"
)
}
\arguments{
\item{specifications}{Specifications data table}

\item{fileName}{Output name for SQL file}

\item{tab}{Tab characters to use}
}
\description{
Create a SQL file to construct data model tables on a database server.
}
\details{
Only PostgreSQL servers are supported.
}
