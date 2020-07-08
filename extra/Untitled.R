# Make ExposuresOfInterest.csv
library(dplyr)

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

readr::read_csv("inst/settings/ExcludedIngredientConcepts.csv") %>% pull(cohortId) %>% paste0(collapse = ";")
