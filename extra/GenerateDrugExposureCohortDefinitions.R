# generates drug-level exposure cohorts
# derived from `GenerateExposureCohortDefinitions.R`

# Generates:
#   [className]CohortsToCreate.csv
#   [className]TcosOfInterest.csv
#
# Requires at input:
#   classGeneratorList.csv
#   ExposuresOfInterest.csv

library(dplyr)

# set ATLAS web API link
baseUrl = "https://atlas-demo.ohdsi.org/WebAPI"

keyring::key_set_with_value('baseUrl', password = baseUrl)
baseUrlWebApi <- keyring::key_get("baseUrl")

# load in base cohort
baseCohort <- readRDS("inst/settings/baseCohort.rds")

generateStats <- TRUE

# start from drug-level permutations and exposures
permutations <- readr::read_csv("extra/classGeneratorList.csv")
exposuresOfInterestTable <- readr::read_csv("inst/settings/ExposuresOfInterest.csv")

## DEBUG: fill in `includedConceptIds` for drug-level exposure cohorts
exposuresOfInterestTable <- exposuresOfInterestTable %>%
  mutate(includedConceptIds = if_else(type == "Drug", as.character(conceptId), includedConceptIds))

permutations <- inner_join(permutations, exposuresOfInterestTable %>%
                             select(cohortId, shortName),
                           by = c("targetId" = "cohortId"))

# helper function to create cohort names
makeName <- function(permutation) {
  paste0(permutation$shortName, ": ", permutation$tar, ", ", permutation$met, " prior met, ",
         permutation$age, " age, ", permutation$sex, " sex, ", permutation$race, " race, ",
         permutation$cvd, " cv risk, ", permutation$renal, " renal")
}

# another helper function to generate `shortName` (used as `atlasName` for creating cohort)
makeShortName <- function(permutation) {
  paste0(permutation$shortName,
         ifelse(permutation$age == "any" &
                  permutation$sex == "any" &
                  permutation$race == "any" &
                  permutation$cvd == "any" &
                  permutation$renal == "any", " main", ""),
         ifelse(permutation$tar == "ot2", " ot2", ""),
         ifelse(permutation$met == "no", " no-met", ""),
         ifelse(permutation$age != "any", paste0(" ", permutation$age, "-age"), ""),
         ifelse(permutation$sex != "any", paste0(" ", permutation$sex), ""),
         ifelse(permutation$race != "any", " black", ""),
         ifelse(permutation$cvd != "any", paste0(" ", permutation$cvd, "-cvr"), ""),
         ifelse(permutation$renal != "any", paste0(" ", permutation$renal, "-rdz"), ""))
}

# function to create permute drug-level target-comparator pairs----
createPermutationsForDrugs <- function(classId){
  drugsForClass <- exposuresOfInterestTable %>%
    filter(cohortId > classId, cohortId < (classId + 10)) %>%
    mutate(classId = classId)
  permutationsForDrugs <- drugsForClass %>%
    left_join(permutations, by = c("classId" ="targetId")) %>%
    mutate(targetId = cohortId.x,
           cohortId = cohortId.y,
           includedConceptIds = conceptId,
           shortName = name) %>%
    select(-type, -shortName.x, -order, -includedConceptIds, -conceptId, -cohortId.x, -cohortId.y, -shortName.y) %>%
    rowwise() %>%
    mutate(cohortId = as.integer(sub(paste0("^",classId), targetId, cohortId))) %>%
    mutate(name = paste0("ID", as.integer(cohortId)))
}

# another function to actually permute the target-comparator pairs----
permuteTC <- function(cohort, permutation, ingredientLevel = FALSE) {

  c1Id <- floor(permutation$comparator1Id / 10)
  c2Id <- floor(permutation$comparator2Id / 10)
  c3Id <- floor(permutation$comparator3Id / 10)

  delta <- 0

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
    cohort$expression$InclusionRules[[1]] <- NULL
    delta <- delta + 1
    cohort$expression$ConceptSets[[15]] <- NULL
    tId <- floor(permutation$targetId / 10)
  }

  cohort$expression$PrimaryCriteria$CriteriaList[[1]]$DrugExposure$CodesetId <- tId

  # cohort$expression$AdditionalCriteria$CriteriaList[[1]]$Criteria$DrugExposure$CodesetId <- c1Id
  # cohort$expression$AdditionalCriteria$CriteriaList[[2]]$Criteria$DrugExposure$CodesetId <- c2Id
  # cohort$expression$AdditionalCriteria$CriteriaList[[3]]$Criteria$DrugExposure$CodesetId <- c3Id

  target <- 2 - delta - 1
  cohort$expression$InclusionRules[[target + tId]] <- NULL
  cohort$expression$EndStrategy$CustomEra[1] <- tId
  delta <- delta + 1

  # AdditionalCriteria: [1,2,3] other drug classes
  # [4]: codesetId 12 (type 2 diabetes mellitus)
  # [5]: codesetId 11 (type 1 diabetes mellitus)
  # [6]: codesetId 10 (2nd diabetes mellitus)
  # [7]: codesetId 5 (other anti-diabetes)
  # [8]: codesetId 15 (other drugs in class) if not null
  # end ...


  # Want to move: [1,2,3,7,8]

  # moveList <- c(cohort$expression$AdditionalCriteria$CriteriaList[[1]],
  #               cohort$expression$AdditionalCriteria$CriteriaList[[2]],
  #               cohort$expression$AdditionalCriteria$CriteriaList[[3]],
  #               cohort$expression$AdditionalCriteria$CriteriaList[[7]])
  #
  # if (length(cohort$expression$AdditionalCriteria$CriteriaList) == 8) {
  #   moveList <- c(moveList, cohort$expression$AdditionalCriteria$CriteriaList[[8]])
  # }
  #
  # cohort$expression$AdditionalCriteria$CriteriaList <- list(cohort$expression$AdditionalCriteria$CriteriaList[[4]],
  #                                                           cohort$expression$AdditionalCriteria$CriteriaList[[5]],
  #                                                           cohort$expression$AdditionalCriteria$CriteriaList[[6]])

  age <- 7 - delta
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

  sex <- 8 - delta
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

  race <- 9 - delta
  if (permutation$race == "black") {
    cohort$expression$InclusionRules[[race]]$name <- "Race stratum"
    cohort$expression$InclusionRules[[race]]$description <- NULL
  } else if (permutation$race == "any") {
    cohort$expression$InclusionRules[[race]] <- NULL
    delta <- delta + 1
  } else {
    stop("Unknown race type")
  }

  cvd <- 10 - delta
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

  renal <- 11 - delta
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

  met <- 12 - delta
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
    delta <- delta + 1
  } else {
    stop("Unknown metformin type")
  }

  insulin <- 13 - delta
  cohort$expression$InclusionRules[[insulin]]$description <- NULL

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



# !! #------
# specify drug class here
# e.g., GLP1RAs:
#classIds = c(20)

# or, DPP4i
#classIds = c(10)

# also, for SU
#classIds = c(40)

# DEBUG: test with SGLT2i
classIds = c(30)

# then create permutations for the desired drug class
permutationsForDrugs <- lapply(classIds, createPermutationsForDrugs) %>%
  bind_rows()

# generate the needed JSON and SQL files to create the drug-level exposure cohorts
permutationsForDrugs$json <-
  do.call("rbind",
          lapply(1:nrow(permutationsForDrugs), function(i) {
            cohortDefinition <- permuteTC(baseCohort, permutationsForDrugs[i,], ingredientLevel = TRUE)
            cohortJson <- RJSONIO::toJSON(cohortDefinition$expression, indent = 2, digits = 10)
            return(cohortJson)
            #return(cohortDefinition)
          }))

permutationsForDrugs$sql <-
  do.call("rbind",
          lapply(1:nrow(permutationsForDrugs), function(i) {
            cohortDefinition <- permuteTC(baseCohort, permutationsForDrugs[i,], ingredientLevel = TRUE)
            cohortSql <- ROhdsiWebApi::getCohortSql(cohortDefinition,
                                                    baseUrlWebApi,
                                                    generateStats = generateStats)
          }))

# save SQL and JSON files under class name (e.g., "DPP4I") folder
## need to create the directory for this class first
this.class = tolower(permutationsForDrugs[1,]$class)
if(!dir.exists(file.path("inst/sql/sql_server", this.class))){
  dir.create(file.path("inst/sql/sql_server", this.class))
}
if(!dir.exists(file.path("inst/cohorts", this.class))){
  dir.create(file.path("inst/cohorts", this.class))
}

## and then save JSON and SQL files
for (i in 1:nrow(permutationsForDrugs)) {
  row <- permutationsForDrugs[i,]
  sqlFileName <- file.path("inst/sql/sql_server", tolower(row$class), paste(row$name, "sql", sep = "."))
  SqlRender::writeSql(row$sql, sqlFileName)
  jsonFileName <- file.path("inst/cohorts", tolower(row$class), paste(row$name, "json", sep = "."))
  SqlRender::writeSql(row$json, jsonFileName)
}

# save drug-level cohorts to [className]cohortsToCreate.csv file
this.class = permutationsForDrugs$class[1] %>% tolower() # this line defines name of drug class
permutationsForDrugs$atlasName <- makeShortName(permutationsForDrugs) # add `atlasName` as short cohort name
drugCohortsToCreate <- permutationsForDrugs %>%
  mutate(atlasId = cohortId,
         name = sprintf('%s/%s',this.class,name)) %>%
  select(atlasId, atlasName, cohortId, name) # creates the cohortsToCreate table

filePath = "inst/settings/"
fileName = sprintf('%sCohortsToCreate.csv', this.class) # file path
readr::write_csv(drugCohortsToCreate,
                 file.path(filePath, fileName)) # write the file as `[className]cohortsToCreate.csv`

# check out some example cohort definitions
## PLEASE UPDATE INGREDIENT NAME FOR EACH DRUG-CLASS!
## (examples here are within the GLP1RA class)
#permutationsForDrugs$atlasName <- makeShortName(permutationsForDrugs)
printCohortDefinitionFromNameAndJson(name = "albiglutide main",
                                     json = permutationsForDrugs$json[1])
printCohortDefinitionFromNameAndJson(name = "albiglutide younger-age",
                                     json = permutationsForDrugs$json[2])


# generate drug-level TCOs-----
# function to create TCO triplets
makeTCOsDrug <- function(tarId, metId, ageId, sexId, raceId, cvdId, renalId) {

  baseTs <- permutationsForDrugs %>%
    filter(tar == tarId,
           age == ageId, sex == sexId, race == raceId, cvd == cvdId,
           renal == renalId, met == metId)

  tab <- as.data.frame(t(combn(baseTs$cohortId, m = 2)))
  names(tab) <- c("targetId", "comparatorId")
  tab$outcomeIds <- -1
  tab$excludedCovariateConceptIds <- NA

  tab <- tab %>% inner_join(permutationsForDrugs %>% select(cohortId, atlasName) %>% rename(targetId = cohortId),
                            by = "targetId") %>%
    rename(targetName = atlasName)

  tab <- tab %>% inner_join(permutationsForDrugs %>% select(cohortId, atlasName) %>% rename(comparatorId = cohortId),
                            by = "comparatorId") %>%
    rename(comparatorName = atlasName)

  return(tab)
}

# use the function to create all TCOs
drugTcos <- rbind(
  # Order: tar, met, age, sex, race, cvd, renal
  #
  # OT1
  # Main
  makeTCOsDrug("ot1", "with", "any", "any", "any", "any", "any"),
  # Age
  makeTCOsDrug("ot1", "with", "younger", "any", "any", "any", "any"),
  makeTCOsDrug("ot1", "with", "middle", "any", "any", "any", "any"),
  makeTCOsDrug("ot1", "with", "older", "any", "any", "any", "any"),
  # Sex
  makeTCOsDrug("ot1", "with", "any", "female", "any", "any", "any"),
  makeTCOsDrug("ot1", "with", "any", "male", "any", "any", "any"),
  # Race
  makeTCOsDrug("ot1", "with", "any", "any", "black", "any", "any"),
  # CV risk
  makeTCOsDrug("ot1", "with", "any", "any", "any", "low", "any"),
  makeTCOsDrug("ot1", "with", "any", "any", "any", "higher", "any"),
  # Renal dz
  makeTCOsDrug("ot1", "with", "any", "any", "any", "any", "without"),
  makeTCOsDrug("ot1", "with", "any", "any", "any", "any", "with"),
  #
  # OT2
  # Main
  makeTCOsDrug("ot2", "with", "any", "any", "any", "any", "any"),
  # Age
  makeTCOsDrug("ot2", "with", "younger", "any", "any", "any", "any"),
  makeTCOsDrug("ot2", "with", "middle", "any", "any", "any", "any"),
  makeTCOsDrug("ot2", "with", "older", "any", "any", "any", "any"),
  # Sex
  makeTCOsDrug("ot2", "with", "any", "female", "any", "any", "any"),
  makeTCOsDrug("ot2", "with", "any", "male", "any", "any", "any"),
  # Race
  makeTCOsDrug("ot2", "with", "any", "any", "black", "any", "any"),
  # CV risk
  makeTCOsDrug("ot2", "with", "any", "any", "any", "low", "any"),
  makeTCOsDrug("ot2", "with", "any", "any", "any", "higher", "any"),
  # Renal dz
  makeTCOsDrug("ot2", "with", "any", "any", "any", "any", "without"),
  makeTCOsDrug("ot2", "with", "any", "any", "any", "any", "with")
)


# save TCOs for the desired drug class
this.class = tolower(permutationsForDrugs$class[1])
filePath = "inst/settings/"
fileName = sprintf('%sTcosOfInterest.csv', this.class) # file path

readr::write_csv(drugTcos, file.path(filePath, fileName)) # save it



