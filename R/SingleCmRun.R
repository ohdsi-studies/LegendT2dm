
executeSingleCmRun <- function(message,
                               folder,
                               exposureSummary,
                               cmAnalysisListFile,
                               outcomeIds,
                               outcomeIdsOfInterest,
                               copyPsFileFolder = "",
                               convertPsFileNames = FALSE,
                               indicationFolder,
                               maxCores) {

  copyCmDataFiles <- function(exposures, source, destination) {
    lapply(1:nrow(exposures), function(i) {
      fileName <- file.path(source,
                            sprintf("CmData_l1_t%s_c%s.zip",
                                    exposures[i,]$targetId,
                                    exposures[i,]$comparatorId))
      success <- file.copy(fileName, destination, overwrite = TRUE,
                           copy.date = TRUE)
      if (!success) {
        stop("Error copying file: ", fileName)
      }
    })
  }

  deleteCmDataFiles <- function(exposures, source) {
    lapply(1:nrow(exposures), function(i) {
      fileName <- file.path(source,
                            sprintf("CmData_l1_t%s_c%s.zip",
                                    exposures[i,]$targetId,
                                    exposures[i,]$comparatorId))
      file.remove(fileName)

    })
  }

  ParallelLogger::logInfo(paste0("Executing CohortMethod for ", message))

  runCmFolder <- file.path(indicationFolder, "cmOutput", folder)
  if (!dir.exists(runCmFolder)) {
    dir.create(runCmFolder, recursive = TRUE)
  }

  copyCmDataFiles(exposureSummary,
                  file.path(indicationFolder, "cmOutput"),
                  runCmFolder)

  runTcoList <- lapply(1:nrow(exposureSummary), function(i) {
    CohortMethod::createTargetComparatorOutcomes(targetId = exposureSummary[i,]$targetId,
                                                 comparatorId = exposureSummary[i,]$comparatorId,
                                                 outcomeIds = outcomeIds)
  })

  if (copyPsFileFolder != "") {

    psFileList <- list.files(file.path(indicationFolder, "cmOutput", copyPsFileFolder),
                             "^Ps_l1_s1_p2_t\\d*_c\\d*.rds", # copies just shared ps model
                             full.names = TRUE, ignore.case = TRUE)

    if (convertPsFileNames) {

      lapply(psFileList, function(sourceFile) {
        sourceTargetId <-  sub("_c.*", "", sub(".*_t", "", sourceFile))
        sourceComparatorId <- sub(".rds", "", sub(".*_c", "", sourceFile))
        destinationTargetId <- makeOt2(sourceTargetId)
        destinationComparatorId <- makeOt2(sourceComparatorId)
        destinationFile <- sub(copyPsFileFolder, folder,
                               sub(sourceTargetId, destinationTargetId,
                                   sub(sourceComparatorId, destinationComparatorId, sourceFile)))
        file.copy(from = sourceFile,
                  to = destinationFile,
                  copy.date = TRUE)
      })
      ParallelLogger::logInfo(paste0("*** Copied and renamed ", length(psFileList), " PS files"))

    } else {
      file.copy(from = psFileList,
                to = runCmFolder,
                copy.date = TRUE)
      ParallelLogger::logInfo(paste0("*** Copied ", length(psFileList), " PS files"))
    }
  }

  runCmAnalysisList <- CohortMethod::loadCmAnalysisList(cmAnalysisListFile)

  CohortMethod::runCmAnalyses(connectionDetails = NULL,
                              cdmDatabaseSchema = NULL,
                              exposureDatabaseSchema = NULL,
                              exposureTable = NULL,
                              outcomeDatabaseSchema = NULL,
                              outcomeTable = NULL,
                              outputFolder = runCmFolder,
                              oracleTempSchema = NULL,
                              cmAnalysisList = runCmAnalysisList,
                              cdmVersion = 5,
                              targetComparatorOutcomesList = runTcoList,
                              getDbCohortMethodDataThreads = 1,
                              createStudyPopThreads = min(4, maxCores),
                              createPsThreads = max(1, round(maxCores/10)),
                              psCvThreads = min(10, maxCores),
                              trimMatchStratifyThreads = min(10, maxCores),
                              prefilterCovariatesThreads = min(5, maxCores),
                              fitOutcomeModelThreads = min(10, maxCores),
                              outcomeCvThreads = min(10, maxCores),
                              refitPsForEveryOutcome = FALSE,
                              refitPsForEveryStudyPopulation = TRUE,
                              prefilterCovariates = TRUE,
                              outcomeIdsOfInterest = outcomeIdsOfInterest)

  deleteCmDataFiles(exposureSummary, runCmFolder)
}
