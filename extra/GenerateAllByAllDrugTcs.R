# generates drug-level TC pairs
# derived from `GenerateExposureCohortDefinitions.R`

# Generates:
#   drugTcosOfInterest.csv
#   drugCohortsToCreate.csv
#
# Requires at input:
#   classGeneratorList.csv
#   ExposuresOfInterest.csv

library(dplyr)

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

# start from drug-level permutations and exposures
strata <- readr::read_csv("extra/classGeneratorList.csv")  %>%
  filter(targetId == 10) %>%
  mutate(stratumId = substring(cohortId, 3, 9)) %>%
  select(stratumId, age, sex, race, cvd, renal, tar, met)

exposuresOfInterestTable <- readr::read_csv("inst/settings/ExposuresOfInterest.csv")
# permutations <- inner_join(permutations, exposuresOfInterestTable %>%
#                              select(cohortId, shortName),
#                            by = c("targetId" = "cohortId"))

# generate drugCohortsToCreate table by combining drug cohorts within each class----
classNames = exposuresOfInterestTable %>%
  filter(type == 'Drug') %>% pull(class) %>%
  unique() %>% tolower()

cohortsTable = NULL
filePath = "inst/settings"

for(cl in classNames){
  classFileName = sprintf("%sCohortsToCreate.csv", cl)

  cohortsTable = bind_rows(cohortsTable,
                           readr::read_csv(file.path(filePath, classFileName)))
}

fileName = sprintf("%sCohortsToCreate.csv", "drug")
readr::write_csv(cohortsTable, file.path(filePath, fileName)) # save it


# generate drugTcosOfInterest table ----
allDrugs <- exposuresOfInterestTable %>%
  filter(type == "Drug", !(cohortId %in% c(10,20,30,40))) %>%
  select(cohortId, name)

allPairs <- as.list(data.frame(combn(allDrugs$cohortId, 2)))

tcos <- do.call("rbind", lapply(allPairs, function(ids) {
  tName <- allDrugs %>% filter(cohortId == ids[1]) %>% pull(name)
  cName <- allDrugs %>% filter(cohortId == ids[2]) %>% pull(name)
  tStrata <- strata %>%
    mutate(targetId = paste0(ids[1], stratumId),
           comparatorId = paste0(ids[2], stratumId),
           outcomeIds = -1,
           excludedCovariateConceptIds = NA) %>%
    mutate(shortName = tName)

  tStrata <- tStrata %>% mutate(shortName = tName)
  tStrata$targetName <- makeShortName(tStrata)

  tStrata <- tStrata %>% mutate(shortName = cName)
  tStrata$comparatorName <- makeShortName(tStrata)

  tStrata <- tStrata %>%
    select(targetId, comparatorId,
           outcomeIds, excludedCovariateConceptIds,
           targetName, comparatorName)

  return(tStrata)
}))

filePath = "inst/settings/"
fileName = sprintf('%sTcosOfInterest.csv', "drug") # file path

readr::write_csv(tcos, file.path(filePath, fileName)) # save it



