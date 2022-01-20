# Check unit-tests
library(dplyr)

outputFolder <- "d:/LegendT2dmOutput_mdcr2"

analysisSummary <- read.csv(file.path(outputFolder, "class", "analysisSummary.csv"))
rbind(
  analysisSummary %>% filter(outcomeId == 1, targetId == 101100000, comparatorId == 401100000) %>%
    select(analysisId, rr) %>% arrange(analysisId),
  analysisSummary %>% filter(outcomeId == 6,  targetId == 102100000, comparatorId == 402100000) %>%
    select(analysisId, rr) %>% arrange(analysisId)
)
