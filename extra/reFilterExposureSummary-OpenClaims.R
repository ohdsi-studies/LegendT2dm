# R script for post-hoc management of the exposure summary file
# on OPEN CLAIMS

library(LegendT2dm)

## path for the ORIGINAL output folder (before staged execution)
originalOutputFolder = "legendT2dmOutput/"

## set up the leading path for the staged execution folders (default is same as original output folder)
outputFolderHeader = originalOutputFolder
outputFolderHeader = stringr::str_remove(outputFolderHeader, "/$")

## number sequence for the staged execution output folders
## e.g., if doing this for chunks 3-10, then use c(3:10)
subFolderNumSequence = c(3:10)

## visit all staged execution output folders and re-filter exposure summary file
for(s in subFolderNumSequence){
  newOutputFolder = paste0(outputFolderHeader, "-", s)
  filterByExposureCohortsSize(outputFolder = newOutputFolder,
                              indicationId = "drug",
                              minCohortSize = 1000,
                              summaryFile = "pairedExposureSummaryFilteredBySize.csv")
}


