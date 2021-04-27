# Make ExposuresOfInterest.csv
library(dplyr)

#baseUrlPublic <- keyring::key_get("ohdsiBaseUrl")
baseUrlWebApi <- keyring::key_get("baseUrl")
#baseUrlWebApi <- "http://atlas.ohdsi.org:80/WebAPI"

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

function() {

  idFn <- function(targetId, age, sex, race, cvd, renal, tar, met) {
    cAge <- -1
    if (age == "any") {
      cAge <- 0
    } else if (age == "younger") {
      cAge <- 1
    } else if (age == "middle") {
      cAge <- 2
    } else if (age == "older") {
      cAge <- 3
    } else {
      stop("Unknown age")
    }

    cSex <- -1
    if (sex == "any") {
      cSex <- 0
    } else if (sex == "female") {
      cSex <- 1
    } else if (sex == "male") {
      cSex <- 2
    } else {
      stop("Unknown sex")
    }

    cRace <- -1
    if (race == "any") {
      cRace <- 0
    } else if (race == "black") {
      cRace <- 1
    } else {
      stop("Unknown race")
    }

    cCvd <- -1
    if (cvd == "any") {
      cCvd <- 0
    } else if (cvd == "low") {
      cCvd <- 1
    } else if (cvd == "higher") {
      cCvd <- 2
    } else {
      stop("Unknown cvd")
    }

    cRenal <- -1
    if (renal == "any") {
      cRenal <- 0
    } else if (renal == "without") {
      cRenal <- 1
    } else if (renal == "with") {
      cRenal <- 2
    } else {
      stop("Unknown renal")
    }

    cTar <- -1
    if (tar == "ot1") {
      cTar <- 1
    } else if (tar == "ot2") {
      cTar <- 2
    } else {
      stop("Unknown tar")
    }

    cMet <- -1
    if (met == "with") {
      cMet <- 1
    } else if (met == "no") {
      cMet <- 2
    } else {
      stop("Unknown met")
    }

    result <- paste0(targetId, cTar, cMet, cAge, cSex, cRace, cCvd, cRenal, collapse = "")

    return(result)
  }

  #tab <- readr::read_csv("inst/settings/classComparisonsOld.csv")
  # tab <- tab %>% mutate(met = "prior")
  # tab2 <- tab %>% mutate(met = "none")
  # tab <- rbind(tab, tab2)
  #readr::write_csv(tab, "inst/settings/classComparisons.csv")

  tab <- tab %>%
   # mutate(targetId = targetId * 100,
   #       comparator1Id = comparator1Id * 100,
   #       comparator2Id = comparator2Id * 100,
   #       comparator3Id = comparator3Id * 100) %>%
    rowwise() %>%  mutate(cohortId = idFn(targetId, age, sex, race, cvd, renal, tar, met))
}

# OHDSI's public webAPI is down right now:
# baseCohort <- ROhdsiWebApi::getCohortDefinition(1774646, baseUrl = baseUrlPublic)
# baseCohort <- ROhdsiWebApi::getCohortDefinition(17111, baseUrl = baseUrlWebApi)

# baseCohort <- ROhdsiWebApi::getCohortDefinition(1487, baseUrl = "http://atlas-covid19.ohdsi.org/WebAPI")
# baseCohortJson <- RJSONIO::toJSON(baseCohort$expression, digits = 50)
# SqlRender::writeSql(baseCohortJson, targetFile = "baseCohort.json")
# saveRDS(baseCohort, file = "baseCohort.rds")

# Inclusion rules: Age == 1, Sex == 2, Race == 3, CVD == 4, Renal == 5, PriorMet == 6, NoMet == 7

baseCohort <- readRDS("baseCohort.rds")

generateStats <- TRUE

permutations <- readr::read_csv("inst/settings/classComparisons.csv")
# permutations <- readr::read_csv("inst/settings/testComparisons.csv")
exposuresOfInterestTable <- readr::read_csv("inst/settings/ExposuresOfInterest.csv")
permutations <- inner_join(permutations, exposuresOfInterestTable %>% select(cohortId, shortName), by = c("targetId" = "cohortId"))

makeName <- function(permutation) {
  paste0(permutation$shortName, ": ", permutation$tar, ", ", permutation$met, " prior met, ",
         permutation$age, " age, ", permutation$sex, " sex, ", permutation$race, " race, ",
         permutation$cvd, " cv risk, ", permutation$renal, " renal")
}

permuteTC <- function(cohort, permutation, ingredientLevel = FALSE) {

  c1Id <- floor(permutation$comparator1Id / 10)
  c2Id <- floor(permutation$comparator2Id / 10)
  c3Id <- floor(permutation$comparator3Id / 10)

  # Remove unused alternative within-class
  if (ingredientLevel) {

    targetId <- permutation$targetId
    classId <- floor(targetId / 10)

    classSet <- cohort$expression$ConceptSets[[classId]]
    targetSet <- classSet
    excludeSet <- classSet

    drugInfo <- exposuresOfInterestTable %>% filter(cohortId == targetId)
    name <- drugInfo %>% pull(name)
    conceptId <- drugInfo %>% pull(conceptId)

    targetSet$name <- name
    excludeSet$name <- paste(excludeSet$name, "excluding", name)
    excludeSet$id <- 15

    targetSet$expression$items <- plyr::compact(
      lapply(targetSet$expression$items, function(item) {
        if (item$concept$CONCEPT_ID == conceptId) {
          item
        } else {
          NULL
        }
      }))

    excludeSet$expression$items <- plyr::compact(
      lapply(excludeSet$expression$items, function(item) {
        if (item$concept$CONCEPT_ID != conceptId) {
          item
        } else {
          NULL
        }
      }))

    cohort$expression$ConceptSets[[classId]] <- targetSet
    cohort$expression$ConceptSets[[15]] <- excludeSet

    tId <- classId

  } else {
    cohort$expression$AdditionalCriteria$CriteriaList[[8]] <- NULL
    cohort$expression$ConceptSets[[15]] <- NULL
    tId <- floor(permutation$targetId / 10)
  }

  cohort$expression$PrimaryCriteria$CriteriaList[[1]]$DrugExposure$CodesetId <- tId
  cohort$expression$AdditionalCriteria$CriteriaList[[1]]$Criteria$DrugExposure$CodesetId <- c1Id
  cohort$expression$AdditionalCriteria$CriteriaList[[2]]$Criteria$DrugExposure$CodesetId <- c2Id
  cohort$expression$AdditionalCriteria$CriteriaList[[3]]$Criteria$DrugExposure$CodesetId <- c3Id

  cohort$expression$EndStrategy$CustomEra[1] <- tId

  delta <- 0

  age <- 1 - delta
  if (permutation$age == "younger") {
    cohort$expression$InclusionRules[[age]]$name <- "Lower age group"
    cohort$expression$InclusionRules[[age]]$description <- NULL
    cohort$expression$InclusionRules[[age]]$expression$DemographicCriteriaList[[1]]$Age$Op <- "lt"
    cohort$expression$InclusionRules[[age]]$expression$DemographicCriteriaList[[2]] <- NULL
  } else if (permutation$age == "middle") {
    cohort$expression$InclusionRules[[age]]$name <- "Middle age group"
    cohort$expression$InclusionRules[[age]]$description <- NULL
    cohort$expression$InclusionRules[[age]]$expression$DemographicCriteriaList[[1]]$Age$Op <- "gte"
    # cohort$expression$InclusionRules[[age]]$expression$DemographicCriteriaList[[2]]$Age$Op <- ""
  } else if (permutation$age == "older") {
    cohort$expression$InclusionRules[[age]]$name <- "Older age group"
    cohort$expression$InclusionRules[[age]]$description <- NULL
    cohort$expression$InclusionRules[[age]]$expression$DemographicCriteriaList[[2]]$Age$Op <- "gte"
    cohort$expression$InclusionRules[[age]]$expression$DemographicCriteriaList[[1]] <- NULL
  } else if (permutation$age == "any") {
    cohort$expression$InclusionRules[[age]] <- NULL
    delta <- delta + 1
  } else {
    stop("Unknown age type")
  }

  sex <- 2 - delta
  if (permutation$sex == "female") {
    cohort$expression$InclusionRules[[sex]]$name <- "Female stratum"
    cohort$expression$InclusionRules[[sex]]$description <- NULL
    cohort$expression$InclusionRules[[sex]]$expression$DemographicCriteriaList[[1]]$Gender[[1]]$CONCEPT_ID <- 8532
    cohort$expression$InclusionRules[[sex]]$expression$DemographicCriteriaList[[1]]$Gender[[1]]$CONCEPT_NAME <- "female"
  } else if (permutation$sex == "male") {
    cohort$expression$InclusionRules[[sex]]$name <- "Male stratum"
    cohort$expression$InclusionRules[[sex]]$description <- NULL
    cohort$expression$InclusionRules[[sex]]$expression$DemographicCriteriaList[[1]]$Gender[[1]]$CONCEPT_ID <- 8507
    cohort$expression$InclusionRules[[sex]]$expression$DemographicCriteriaList[[1]]$Gender[[1]]$CONCEPT_NAME <- "male"
  } else if (permutation$sex == "any") {
    cohort$expression$InclusionRules[[sex]] <- NULL
    delta <- delta + 1
  } else {
    stop("Unknown sex type")
  }

  race <- 3 - delta
  if (permutation$race == "black") {
    cohort$expression$InclusionRules[[race]]$name <- "Race stratum"
    cohort$expression$InclusionRules[[race]]$description <- NULL
  } else if (permutation$race == "any") {
    cohort$expression$InclusionRules[[race]] <- NULL
    delta <- delta + 1
  } else {
    stop("Unknown race type")
  }

  cvd <- 4 - delta
  if (permutation$cvd == "low") {
    cohort$expression$InclusionRules[[cvd]]$name <- "Low cardiovascular risk"
    cohort$expression$InclusionRules[[cvd]]$description <- NULL
    cohort$expression$InclusionRules[[cvd]]$expression$Type <- "ALL"

    cohort$expression$InclusionRules[[cvd]]$expression$CriteriaList[[1]]$Occurrence$Type <- 0
    cohort$expression$InclusionRules[[cvd]]$expression$CriteriaList[[1]]$Occurrence$Count <- 0

    cohort$expression$InclusionRules[[cvd]]$expression$CriteriaList[[2]]$Occurrence$Type <- 0
    cohort$expression$InclusionRules[[cvd]]$expression$CriteriaList[[2]]$Occurrence$Count <- 0
  } else if (permutation$cvd == "higher") {
    cohort$expression$InclusionRules[[cvd]]$name <- "Higher cardiovascular risk"
    cohort$expression$InclusionRules[[cvd]]$description <- NULL
    cohort$expression$InclusionRules[[cvd]]$expression$Type <- "ANY"

    cohort$expression$InclusionRules[[cvd]]$expression$CriteriaList[[1]]$Occurrence$Type <- 2
    cohort$expression$InclusionRules[[cvd]]$expression$CriteriaList[[1]]$Occurrence$Count <- 1

    cohort$expression$InclusionRules[[cvd]]$expression$CriteriaList[[2]]$Occurrence$Type <- 2
    cohort$expression$InclusionRules[[cvd]]$expression$CriteriaList[[2]]$Occurrence$Count <- 1
  } else if (permutation$cvd == "any") {
    cohort$expression$InclusionRules[[cvd]] <- NULL
    delta <- delta  + 1
  } else {
    stop("Unknown CVD risk type")
  }

  renal <- 5 - delta
  if (permutation$renal == "without") {
    cohort$expression$InclusionRules[[renal]]$name <- "Without renal impairment"
    cohort$expression$InclusionRules[[renal]]$description <- NULL
    cohort$expression$InclusionRules[[renal]]$expression$CriteriaList[[1]]$Occurrence$Type <- 0
    cohort$expression$InclusionRules[[renal]]$expression$CriteriaList[[1]]$Occurrence$Count <- 0
  } else if (permutation$renal == "with") {
    cohort$expression$InclusionRules[[renal]]$name <- "Renal impairment"
    cohort$expression$InclusionRules[[renal]]$description <- NULL
  } else if (permutation$renal == "any") {
    cohort$expression$InclusionRules[[renal]] <- NULL
    delta <- delta  + 1
  } else {
    stop("Unknown renal type")
  }

  met <- 6 - delta
  if (permutation$met == "with") {
    # Do nothing
    cohort$expression$InclusionRules[[met]]$description <- NULL
    cohort$expression$InclusionRules[[met + 1]] <- NULL
    delta <- delta + 1
  } else if (permutation$met == "no") {
    cohort$expression$InclusionRules[[met + 1]]$description <- NULL
    cohort$expression$InclusionRules[[met]] <- NULL
    delta <- delta + 1
  } else if (permutation$met == "test") {
    cohort$expression$InclusionRules[[met]]$description <- NULL
    cohort$expression$InclusionRules[[met]]$expression$Type <- "AT_MOST"
    cohort$expression$InclusionRules[[met]]$expression$Count <- 0
    cohort$expression$InclusionRules[[met + 1]] <- NULL
  } else {
    stop("Unknown metformin type")
  }

  if (permutation$tar == "ot1") {
    cohort$expression$CensoringCriteria <- list()
  } else if (permutation$tar == "ot2") {

    includedConcepts <- as.numeric(unlist(strsplit(exposuresOfInterestTable %>%
                                                     filter(cohortId == permutation$targetId) %>%
                                                     pull(includedConceptIds),
                                                   ";")))
    items <- cohort$expression$ConceptSets[[14]]$expression$items

    tmp <-
      lapply(items, function(item) {
        if (item$concept$CONCEPT_ID %in% includedConcepts) {
          NULL
        } else {
          item
        }
      })
    cohort$expression$ConceptSets[[14]]$expression$items <- plyr::compact(tmp)
  } else {
    stop("Unknown TAR")
  }

  cohort$name <- makeName(permutation)
  # cohort$name <- paste0(cohort$name, " T: ", permutation$shortName, " CVD: ", permutation$cvd, " Age: ", permutation$age)
  return(cohort)
}

allCohortsSql <-
  do.call("rbind",
          lapply(1:nrow(permutations), function(i) {
            cohortDefinition <- permuteTC(baseCohort, permutations[i,])
            cohortSql <- ROhdsiWebApi::getCohortSql(cohortDefinition,
                                                    baseUrlWebApi,
                                                    generateStats = generateStats)
            return(cohortSql)
          }))

allCohortsJson <-
  do.call("rbind",
          lapply(1:nrow(permutations), function(i) {
            cohortDefinition <- permuteTC(baseCohort, permutations[i,])
            cohortJson <- RJSONIO::toJSON(cohortDefinition$expression, indent = 2, digits = 10)
            return(cohortJson)
          }))



permutations$json <- allCohortsJson
permutations$sql <- allCohortsSql

permutations <- permutations %>%
  mutate(name = paste0("ID", as.integer(cohortId)))

permutations$atlasName <- makeName(permutations)

for (i in 1:nrow(permutations)) {
  row <- permutations[i,]
  sqlFileName <- file.path("inst/sql/sql_server/class", paste(row$name, "sql", sep = "."))
  SqlRender::writeSql(row$sql, sqlFileName)
  jsonFileName <- file.path("inst/cohorts/class", paste(row$name, "json", sep = "."))
  SqlRender::writeSql(row$json, jsonFileName)
}

classCohortsToCreate <- permutations %>%
  mutate(atlasId = cohortId,
         name = paste0("class/", name)) %>%
  select(atlasId, atlasName, cohortId, name)

# readr::write_csv(classCohortsToCreate, "inst/settings/classCohortsToCreate.csv")
readr::write_csv(classCohortsToCreate, "inst/settings/testCohortsToCreate.csv")
# TODO Move to separate file

# Generate ingredient-level cohorts
permutations <- readr::read_csv("inst/settings/classComparisons.csv")
exposuresOfInterestTable <- readr::read_csv("inst/settings/ExposuresOfInterest.csv")
permutations <- inner_join(permutations, exposuresOfInterestTable %>% select(cohortId, shortName), by = c("targetId" = "cohortId"))

permutations <- permutations %>% filter(cohortId == 101100000)

classId <- 10
drugsForClass <- exposuresOfInterestTable %>% filter(cohortId > classId, cohortId < (classId + 10)) %>% mutate(classId = classId)
permutationsForDrugs <- drugsForClass %>% left_join(permutations, by = c("classId" ="targetId")) %>%
  mutate(targetId = cohortId.x,
         cohortId = cohortId.y,
         includedConceptIds = conceptId,
         shortName = name) %>%
  select(-type, -shortName.x, -order, -includedConceptIds, -conceptId, -cohortId.x, -cohortId.y, -shortName.y) %>%
  rowwise() %>%
  mutate(cohortId = as.integer(sub(paste0("^",classId), targetId, cohortId))) %>%
  mutate(name = paste0("ID", as.integer(cohortId)))

permutationsForDrugs$json <-
  do.call("rbind",
          lapply(1:nrow(permutationsForDrugs), function(i) {
            cohortDefinition <- permuteTC(baseCohort, permutationsForDrugs[i,], ingredientLevel = TRUE)
            cohortJson <- RJSONIO::toJSON(cohortDefinition$expression, indent = 2, digits = 10)
            return(cohortJson)
            #return(cohortDefinition)
          }))

for (i in 1:nrow(permutationsForDrugs)) {
  row <- permutationsForDrugs[i,]
  # sqlFileName <- file.path("inst/sql/sql_server/class", paste(row$name, "sql", sep = "."))
  # SqlRender::writeSql(row$sql, sqlFileName)
  jsonFileName <- file.path("inst/cohorts/drug", paste(row$name, "json", sep = "."))
  SqlRender::writeSql(row$json, jsonFileName)
}

# cohortsToCreate <- permutations %>% mutate(atlasId = cohortId) %>%
#   select(atlasId, atlasName, cohortId, name)
#
# readr::write_csv(cohortsToCreate, file.path("inst/settings", "CohortsToCreate.csv"))

#comparisons <- readr::read_csv("inst/settings/classComparisonsWithJson.csv")




