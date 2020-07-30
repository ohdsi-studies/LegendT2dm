# Make ExposuresOfInterest.csv
library(dplyr)


baseUrlPublic <- keyring::key_get("ohdsiBaseUrl")
baseUrlJnj <- keyring::key_get("baseUrl")


function() {
  exp <- readr::read_csv("inst/settings/ExposuresOfInterest.csv") %>% group_by(class) %>% arrange(class,name)

  dpp4isConceptIds <- exp %>% filter(class == "DPP4Is") %>% arrange(cohortId) %>% pull(cohortId) %>% paste0(collapse = ";")
  glp1rasConceptIds <- exp %>% filter(class == "GLP1RAs") %>% arrange(cohortId) %>% pull(cohortId) %>% paste0(collapse = ";")
  sglt2isConceptIds <- exp %>% filter(class == "SGLT2Is") %>% arrange(cohortId) %>% pull(cohortId) %>% paste0(collapse = ";")
  susConceptIds <- exp %>% filter(class == "SUs") %>% arrange(cohortId) %>% pull(cohortId) %>% paste0(collapse = ";")

  exp[!is.na(exp$shortName) & exp$shortName == "DPP4Is", "includedConceptIds"] <- dpp4isConceptIds
  exp[!is.na(exp$shortName) & exp$shortName == "GLP1RAs", "includedConceptIds"] <- glp1rasConceptIds
  exp[!is.na(exp$shortName) & exp$shortName == "SGLT2Is", "includedConceptIds"] <- sglt2isConceptIds
  exp[!is.na(exp$shortName) & exp$shortName == "SUs", "includedConceptIds"] <- susConceptIds

  readr::write_csv(exp, "inst/settings/tmp.csv")

  readr::read_csv("inst/settings/ExcludedIngredientConcepts.csv") %>% arrange(conceptId) %>% pull(conceptId) %>% paste0(collapse = ";")

}

# OHDSI's public webAPI is down right now:
# baseCohort <- ROhdsiWebApi::getCohortDefinition(1774646, baseUrl = baseUrlPublic)
baseCohort <- ROhdsiWebApi::getCohortDefinition(17111, baseUrl = baseUrlJnj)


#saveRDS(baseCohort, file = "baseCohort.rds")

generateStats <- TRUE

permutations <- readr::read_csv("inst/settings/classComparisons.csv")
exposuresOfInterest <- readr::read_csv("inst/settings/ExposuresOfInterest.csv") %>% select(cohortId, shortName)
permutations <- inner_join(permutations, exposuresOfInterest, by = c("targetId" = "cohortId"))

permuteTC <- function(cohort,
                      permutation) {
  cohort$expression$PrimaryCriteria$CriteriaList[[1]]$DrugExposure$CodesetId <- permutation$targetId
  cohort$expression$AdditionalCriteria$CriteriaList[[1]]$Criteria$DrugExposure$CodesetId <- permutation$comparator1Id
  cohort$expression$AdditionalCriteria$CriteriaList[[2]]$Criteria$DrugExposure$CodesetId <- permutation$comparator2Id
  cohort$expression$AdditionalCriteria$CriteriaList[[3]]$Criteria$DrugExposure$CodesetId <- permutation$comparator3Id

  if (permutation$cvd == "high") {
    # Do nothing
  } else if (permutation$cvd == "low") {
    cohort$expression$InclusionRules[[2]]$name <- "Low cardiovascular risk"
    cohort$expression$InclusionRules[[2]]$description <- "Identify patients at low cardiovascular risk (based on Ryan et al. 2018 Diabetes Obes Metab)"
    cohort$expression$InclusionRules[[2]]$expression$Type <- "ALL"

    cohort$expression$InclusionRules[[2]]$expression$CriteriaList[[1]]$Occurrence$Type <- 0
    cohort$expression$InclusionRules[[2]]$expression$CriteriaList[[1]]$Occurrence$Count <- 0

    cohort$expression$InclusionRules[[2]]$expression$CriteriaList[[2]]$Occurrence$Type <- 0
    cohort$expression$InclusionRules[[2]]$expression$CriteriaList[[2]]$Occurrence$Count <- 0
  } else if (permutation$cvd == "all") {
    cohort$expression$InclusionRules[[2]] <- NULL
  } else {
    stop("Unknown CVD risk type")
  }

  if (permutation$age == "older") {
    # Do nothing
  } else if (permutation$age == "younger") {
    cohort$expression$InclusionRules[[1]]$expression$DemographicCriteriaList[[1]]$Age$Op <- "lt"
  } else if (permutation$age == "all") {
    cohort$expression$InclusionRules[[1]] <- NULL
  } else {
    stop("Unknown age type")
  }

  cohort$name <- paste0(cohort$name, " T: ", permutation$shortName, " CVD: ", permutation$cvd, " Age: ", permutation$age)
  return(cohort)
}

allCohortsSql <-
  do.call("rbind",
          lapply(1:nrow(permutations), function(i) {
            cohortDefinition <- permuteTC(baseCohort, permutations[i,])
            cohortSql <- ROhdsiWebApi::getCohortSql(cohortDefinition,
                                                    baseUrlJnj,
                                                    generateStats = generateStats)
            return(cohortSql)
          }))

allCohortsJson <-
  do.call("rbind",
          lapply(1:nrow(permutations), function(i) {
            cohortDefinition <- permuteTC(baseCohort, permutations[i,])
            cohortJson <- RJSONIO::toJSON(cohortDefinition$expression)
            return(cohortJson)
            #return(cohortDefinition)
          }))


permutations$json <- allCohortsJson
readr::write_csv(permutations, path = "inst/settings/classComparisonsWithJson.csv")

permutations$sql <- allCohortsSql
permutations <- permutations %>%
  mutate(atlasName = paste0(shortName, " CVD: ", cvd, " Age: ", age)) %>%
  mutate(name = paste0("ID", cohortId))

for (i in 1:nrow(permutations)) {
  row <- permutations[i,]
  sqlFileName <- file.path("inst/sql/sql_server", paste(row$name, "sql", sep = "."))
  SqlRender::writeSql(row$sql, sqlFileName)
  jsonFileName <- file.path("inst/cohorts", paste(row$name, "json", sep = "."))
  SqlRender::writeSql(row$json, jsonFileName)
}

cohortsToCreate <- permutations %>% mutate(atlasId = cohortId) %>%
  select(atlasId, atlasName, cohortId, name)

readr::write_csv(cohortsToCreate, file.path("inst/settings", "CohortsToCreate.csv"))

comparisons <- readr::read_csv("inst/settings/classComparisonsWithJson.csv")



