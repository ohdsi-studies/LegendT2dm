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

  markdown <- sub("### Inclusion Criteria", "### Additional Inclusion Criteria", markdown)
  markdown <- gsub("#### \\d+.", "*", markdown)

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

#' @export
printConceptSet <- function(conceptSet) {

  markdown <- CirceR::conceptSetPrintFriendly(conceptSet)
  rows <- unlist(strsplit(markdown, "\\r\\n"))
  rows <- gsub("^\\|", "", rows)
  header <- rows[1]
  data <- readr::read_delim(paste(rows[c(2,4:(length(rows)-2))],
                                  collapse = '\n'), delim = '|',)

  header <- gsub("###", "### Concept:", header)

  tab <- data %>% mutate_if(is.numeric, format, digits = 10) %>% kable(linesep = "", booktabs = TRUE, longtable = TRUE)

  if (knitr::is_latex_output()) {
    writeLines(header)

    writeLines(tab %>%
                 kable_styling(latex_options = "striped", font_size = latex_table_font_size) %>%
                 column_spec(1, width = "5em") %>%
                 column_spec(2, width = "20em"))
  } else if (knitr::is_html_output()) {
    writeLines(header)

    writeLines(tab %>%
                 kable_styling(bootstrap_options = "striped"))
  } else {
    writeLines(markdown)
  }
}

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

#' @export
printCohortDefinition <- function(info) {
  json <- SqlRender::readSql(info$jsonFileName)
  printCohortDefinitionFromNameAndJson(info$name, json)
}

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

#' @export
printExitCriteria <- function(obj) {

  markdown <- CirceR::cohortPrintFriendly(obj)
  markdown <- sub(".*### Cohort Exit", "", markdown)
  markdown <- sub("### Cohort Eras.*", "", markdown)
  markdown <- sub("The person exits the cohort", "\\\r\\\nThe person also exists the cohort", markdown)
  markdown <- sub("following events:", "following events:\\\r\\\n", markdown)

  writeLines(markdown)
}
