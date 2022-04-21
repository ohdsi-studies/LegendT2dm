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

#' Print cohort definition with specified name
#'
#' @description
#' Outputs a cohort definition into human-readable \code{markdown}
#'
#' @param name                  Cohort name listed as section title
#' @param json                  JSON cohort definition to be printed
#' @param obj                   Cohort object outputted from \code{CirceR} to be printed; can be \code{NULL}
#'                              in which case \code{json} is used.
#' @param withConcepts          Boolean: Include concept lists in output?
#' @param withClosing           Boolean: Add the output from \code{printCohortClose} to end?
#'
#' @export
printCohortDefinitionFromNameAndJson <- function(name, json = NULL, obj = NULL,
                                                 withConcepts = TRUE,
                                                 withClosing = TRUE) {

  if (is.null(obj)) {
    obj <- CirceR::cohortExpressionFromJson(json)
  }

  writeLines(paste("##", name, "\n"))

  # Print main definition
  markdown <- CirceR::cohortPrintFriendly(obj)

  markdown <- gsub("criteria:\\r\\n ", "criteria:\\\r\\\n\\\r\\\n ", markdown)
  markdown <- gsub("old.\\r\\n\\r\\n", "old.\\\r\\\n", markdown)

  markdown <- gsub("The person exits the cohort", "\\\r\\\nThe person also exists the cohort", markdown)
  markdown <- gsub("following events:", "following events:\\\r\\\n", markdown)

  markdown <- sub("### Inclusion Criteria", "### Additional Inclusion Criteria\n", markdown)

  markdown <- unnumberAdditionalCriteria(markdown)
  markdown <- stringr::str_replace_all(
    markdown, "#### (\\d+).",
    function(matched_str) {
      digit <- stringr::str_extract(matched_str, stringr::regex("\\d+"))
      paste0("#### ", utils::as.roman(digit), ".")
    }
  )

  rows <- unlist(strsplit(markdown, "\\r\\n"))
  rows <- gsub("^   ", "", rows)
  markdown <- paste(rows, collapse = "\n")

  writeLines(markdown)

  # Print concept sets

  if (withConcepts) {
    lapply(obj$conceptSets, printConceptSet)
  }

  if (withClosing) {
    printCohortClose()
  }
}

#' Find the subsections corresponding to additional criteria and unnumber them.
unnumberAdditionalCriteria <- function(markdown) {
  markdown <- stringr::str_replace_all(
    markdown, "#### (\\d+).(.*)",
    function(matched_str) { paste(matched_str, "{-}") }
  )
  return(markdown)
}

#' Print concept set
#'
#' @description
#' Outputs a concept set into human-readable \code{markdown}
#'
#' @param conceptSet            JSON concept set definition to be printed
#' @param latexTableFontSize    Font size to use if output will be converted to PDF via \code{latex}
#'
#' @export
printConceptSet <- function(conceptSet,
                            latexTableFontSize = 8) {

  markdown <- CirceR::conceptSetPrintFriendly(conceptSet)
  rows <- unlist(strsplit(markdown, "\\r\\n"))
  rows <- gsub("^\\|", "", rows)
  rows <- gsub("\\|$", "", rows)
  header <- rows[1]
  data <- readr::read_delim(paste(rows[c(2,4:(length(rows)-2))],
                                  collapse = '\n'),
                            delim = '|', col_types = "ccccccc")

  header <- gsub("###", "### Concept:", header)

  tab <- data %>% mutate_if(is.numeric, format, digits = 10) %>% knitr::kable(linesep = "", booktabs = TRUE, longtable = TRUE)

  if (knitr::is_latex_output()) {
    writeLines(header)

    writeLines(tab %>%
                 kableExtra::kable_styling(latex_options = "striped", font_size = latexTableFontSize) %>%
                 kableExtra::column_spec(1, width = "5em") %>%
                 kableExtra::column_spec(2, width = "20em"))
  } else if (knitr::is_html_output()) {
    writeLines(header)

    writeLines(tab %>%
                 kableExtra::kable_styling(bootstrap_options = "striped"))
  } else {
    writeLines(markdown)
  }
}

#' Print cohort closing line
#'
#' @description
#' Outputs a cohort closing line in  \code{markdown}
#'
#' @export
printCohortClose <- function() {
  writeLines("")
  if (knitr::is_html_output()) {
    writeLines("<hr style=\"border:2px solid gray\"> </hr>")
  } else {
    writeLines("------")
  }
  writeLines("")
}

#' Print cohort definition from file name
#'
#' @description
#' Outputs a cohort definition into human-readable \code{markdown}
#'
#' @param info                  List with two entries: \code{name} (text name for printing) and
#'                              \code{jsonFileName} (JSON file name)
#'
#' @export
printCohortDefinition <- function(info) {
  json <- SqlRender::readSql(info$jsonFileName)
  printCohortDefinitionFromNameAndJson(info$name, json)
}

#' Print inclusion criteria
#'
#' @description
#' Outputs inclusion criteria into human-readable \code{markdown}
#'
#' @param obj                   Cohort object outputted from \code{CirceR} to be printed
#'                              in which case \code{json} is used.
#' @param removeDescription           Currently not used (TODO fix)
#'
#' @export
printInclusionCriteria <- function(obj, removeDescription = FALSE) {

  markdown <- CirceR::cohortPrintFriendly(obj)
  markdown <- sub(".*### Inclusion Criteria", "", markdown)
  markdown <- sub("### Cohort Exit.*", "", markdown)
  markdown <- gsub("### \\d+.", "##", markdown)
  markdown <- gsub("criteria:\\r\\n ", "criteria:\\\r\\\n\\\r\\\n ", markdown)

  rows <- unlist(strsplit(markdown, "\\r\\n"))
  rows <- gsub("^   ", "", rows)
  markdown <- paste(rows, collapse = "\n")

  writeLines(markdown)
}

#' Print exit criteria
#'
#' @description
#' Outputs exit criteria into human-readable \code{markdown}
#'
#' @param obj                   Cohort object outputted from \code{CirceR} to be printed
#'                              in which case \code{json} is used.
#'
#' @export
printExitCriteria <- function(obj) {

  markdown <- CirceR::cohortPrintFriendly(obj)
  markdown <- sub(".*### Cohort Exit", "", markdown)
  markdown <- sub("### Cohort Eras.*", "", markdown)
  markdown <- sub("The person exits the cohort", "\\\r\\\nThe person also exists the cohort", markdown)
  markdown <- sub("following events:", "following events:\\\r\\\n", markdown)

  writeLines(markdown)
}
