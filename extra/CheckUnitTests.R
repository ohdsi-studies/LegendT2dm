# Check unit-tests
library(dplyr)

outputFolder <- "d:/LegendT2dmOutput_mdcr3"

analysisSummary <- read.csv(file.path(outputFolder, "class", "analysisSummary.csv"))
rbind(
  analysisSummary %>% filter(outcomeId == 1, targetId == 101100000, comparatorId == 401100000) %>%
    select(analysisId, rr) %>% arrange(analysisId),
  analysisSummary %>% filter(outcomeId == 6,  targetId == 102100000, comparatorId == 402100000) %>%
    select(analysisId, rr) %>% arrange(analysisId)
)


# Check glycemic control
rbind(
  analysisSummary %>% filter(outcomeId == 5, targetId == 101100000, comparatorId == 401100000) %>%
    select(analysisId, rr) %>% arrange(analysisId),
  analysisSummary %>% filter(outcomeId == 5,  targetId == 102100000, comparatorId == 402100000) %>%
    select(analysisId, rr) %>% arrange(analysisId)
)

# ORIGINAL
# analysisId        rr
# 1          1 0.1794159
# 2          2 0.9767308
# 3          3 0.4762618
# 4          4 0.1758781
# 5          5 1.0040276
# 6          6 0.4615134
# 7          7 0.1721740
# 8          8 1.0113819
# 9          9 0.4771502

# W/ UPDATED OUTCOME
# analysisId        rr
# 1           1 0.1794159
# 2           2 0.9767308
# 3           3 0.4762618
# 4           4 0.1758781
# 5           5 1.0040276
# 6           6 0.4615134
# 7          11 0.1608701
# 8          12 0.9391217
# 9          13 0.4582302
# 10         14 0.1713079
# 11         15 1.0848983
# 12         16 0.4743209
# 13          7 0.1721740
# 14          8 1.0113819
# 15          9 0.4771502
# 16         17 0.1589678
# 17         18 1.0445129
# 18         19 0.4681313
