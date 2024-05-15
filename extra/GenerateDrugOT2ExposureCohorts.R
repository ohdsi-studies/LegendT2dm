#  code to generate exposure cohorts for drug-level OT2 analysis only
# for bug-fix!

# will generate
#   drugot2CohortsToCreate.csv
#   drugot2TcosOfInterest.csv

# require input
#   drugCohortsToCreate.csv
#   drugTcosOfInterest.csv

library(dplyr)

cohortTable = readr::read_csv("inst/settings/drugCohortsToCreate.csv")
tcoTable = readr::read_csv("inst/settings/drugTcosOfInterest.csv")

cohortTableOt2 = cohortTable %>%
  filter(stringr::str_detect(atlasName, "ot2"))

tcoTableOt2 = tcoTable %>%
  filter(stringr::str_detect(targetName, "ot2"))

readr::write_csv(cohortTableOt2, "inst/settings/drugOt2CohortsToCreate.csv")
readr::write_csv(tcoTableOt2, "inst/settings/drugOt2TcosOfInterest.csv")
