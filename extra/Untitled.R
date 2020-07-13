# Make ExposuresOfInterest.csv
library(dplyr)


baseUrlPublic <- "http://atlas-demo.ohdsi.org:80/WebAPI"
baseUrlJnj <- "https://epi.jnj.com:8443/WebAPI"


function() {
exp <- readr::read_csv("inst/settings/ExposuresOfInterest.csv") %>% group_by(class) %>% arrange(class,name)

dpp4isConceptIds <- exp %>% filter(class == "DPP4Is") %>% arrange(cohortId) %>% pull(cohortId) %>% paste0(collapse = ";")
glp1rasConceptIds <- exp %>% filter(class == "GLP1RAs") %>% arrange(cohortId) %>% pull(cohortId) %>% paste0(collapse = ";")
sglt2isConceptIds <- exp %>% filter(class == "SGLT2Is") %>% arrange(cohortId) %>% pull(cohortId) %>% paste0(collapse = ";")
susConceptIds <- exp %>% filter(class == "SUs") %>% arrange(cohortId) %>% pull(cohortId) %>% paste0(collapse = ";")

exp[!is.na(exp$shortName) & exp$shortName == "DPP4Is", "includedConceptIds"] <- dpp4isConceptIds
exp[!is.na(exp$shortName) &exp$shortName == "GLP1RAs", "includedConceptIds"] <- glp1rasConceptIds
exp[!is.na(exp$shortName) &exp$shortName == "SGLT2Is", "includedConceptIds"] <- sglt2isConceptIds
exp[!is.na(exp$shortName) &exp$shortName == "SUs", "includedConceptIds"] <- susConceptIds

readr::write_csv(exp, "inst/settings/tmp.csv")

readr::read_csv("inst/settings/ExcludedIngredientConcepts.csv") %>% arrange(conceptId) %>% pull(conceptId) %>% paste0(collapse = ";")

}

baseCohort <- ROhdsiWebApi::getCohortDefinition(1774646, baseUrl = baseUrlPublic)
#saveRDS(baseCohort, file = "baseCohort.rds")

permutations <- readr::read_csv("classComparisons.csv")
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
    # TODO
  } else if (permutation$age == "all") {
    cohort$expression$InclusionRules[[1]] <- NULL
  } else {
    stop("Unknown age type")
  }

  cohort$name <- paste0(cohort$name, " T: ", permutation$shortName, " CVD: ", permutation$cvd, " Age: ", permutation$age)
  return(cohort)
}

c1 <- permuteTC(baseCohort, permutations[12,])
ROhdsiWebApi::postCohortDefinition(c1$name, c1, baseUrl = baseUrlJnj)

