library(dplyr)

exposuresOfInterest <- readr::read_csv(system.file("settings", "ExposuresOfInterest.csv", package = "LegendT2dm")) %>%
  filter(type == "Drug") %>% select(conceptId) %>% pull()

covarSettings <- FeatureExtraction::createDefaultCovariateSettings(
  excludedCovariateConceptIds = exposuresOfInterest) # TODO Double-check
# short-term == 30, medium-term == 180, long-term == 365

getDbCmDataArgs <- CohortMethod::createGetDbCohortMethodDataArgs(
  covariateSettings = covarSettings)

createOt1StudyPopArgs <- CohortMethod::createCreateStudyPopulationArgs(
  firstExposureOnly = TRUE,
  removeDuplicateSubjects = TRUE,
  removeSubjectsWithPriorOutcome = TRUE,
  minDaysAtRisk = 1)

createOt2StudyPopArgs <- CohortMethod::createCreateStudyPopulationArgs(
  firstExposureOnly = TRUE,
  removeDuplicateSubjects = TRUE, # TODO Need serious help here.
  removeSubjectsWithPriorOutcome = TRUE,
  minDaysAtRisk = 1)

createIttStudyPopArgs <- CohortMethod::createCreateStudyPopulationArgs(
  firstExposureOnly = TRUE,
  removeDuplicateSubjects = TRUE,
  removeSubjectsWithPriorOutcome = TRUE,
  minDaysAtRisk = 1,
  riskWindowEnd = 99999)

createPsArgs <- CohortMethod::createCreatePsArgs(
  stopOnError = FALSE,
  maxCohortSizeForFitting = 100000,
  prior = Cyclops::createPrior(priorType = "laplace",
                               useCrossValidation = TRUE))

fitCrudeOutcomeModelArgs <- CohortMethod::createFitOutcomeModelArgs(
  modelType = "cox",
  stratified = FALSE)

fitPsOutcomeModelArgs <- CohortMethod::createFitOutcomeModelArgs(
  modelType = "cox",
  stratified = TRUE)

stratifyByPsArgs <- CohortMethod::createStratifyByPsArgs(numberOfStrata = 5)

matchByPsArgs <- CohortMethod::createMatchOnPsArgs(
  maxRatio = 1)

# Analysis 1 -- crude/unadjusted

cmAnalysis1 <- CohortMethod::createCmAnalysis(analysisId = 1,
                                              description = "Crude/unadjusted",
                                              getDbCohortMethodDataArgs = getDbCmDataArgs,
                                              createStudyPopArgs = createOt1StudyPopArgs,
                                              createPs = FALSE,
                                              fitOutcomeModel = TRUE,
                                              fitOutcomeModelArgs = fitCrudeOutcomeModelArgs)

# Analysis 2 -- PS match / OT1

cmAnalysis2 <- CohortMethod::createCmAnalysis(analysisId = 2,
                                              description = "PS-match / OT1",
                                              getDbCohortMethodDataArgs = getDbCmDataArgs,
                                              createStudyPopArgs = createOt1StudyPopArgs,
                                              createPs = TRUE,
                                              createPsArgs = createPsArgs,
                                              matchOnPs = TRUE,
                                              matchOnPsArgs = matchByPsArgs,
                                              fitOutcomeModel = TRUE,
                                              fitOutcomeModelArgs = fitPsOutcomeModelArgs)

# Analysis 3 -- PS match / OT2

cmAnalysis3 <- CohortMethod::createCmAnalysis(analysisId = 3,
                                              description = "PS-match / OT2",
                                              getDbCohortMethodDataArgs = getDbCmDataArgs,
                                              createStudyPopArgs = createOt2StudyPopArgs,
                                              createPs = TRUE,
                                              createPsArgs = createPsArgs,
                                              matchOnPs = TRUE,
                                              matchOnPsArgs = matchByPsArgs,
                                              fitOutcomeModel = TRUE,
                                              fitOutcomeModelArgs = fitPsOutcomeModelArgs)

# Analysis 4 -- PS match / ITT

cmAnalysis4 <- CohortMethod::createCmAnalysis(analysisId = 4,
                                              description = "PS-match / ITT",
                                              getDbCohortMethodDataArgs = getDbCmDataArgs,
                                              createStudyPopArgs = createIttStudyPopArgs,
                                              createPs = TRUE,
                                              createPsArgs = createPsArgs,
                                              matchOnPs = TRUE,
                                              matchOnPsArgs = matchByPsArgs,
                                              fitOutcomeModel = TRUE,
                                              fitOutcomeModelArgs = fitPsOutcomeModelArgs)

# Analysis 5 -- PS stratify / OT1

cmAnalysis5 <- CohortMethod::createCmAnalysis(analysisId = 5,
                                              description = "PS-match / OT1",
                                              getDbCohortMethodDataArgs = getDbCmDataArgs,
                                              createStudyPopArgs = createOt1StudyPopArgs,
                                              createPs = TRUE,
                                              createPsArgs = createPsArgs,
                                              stratifyByPs = TRUE,
                                              stratifyByPsArgs = stratifyByPsArgs,
                                              fitOutcomeModel = TRUE,
                                              fitOutcomeModelArgs = fitPsOutcomeModelArgs)

# Analysis 6 -- PS stratify / OT2

cmAnalysis6 <- CohortMethod::createCmAnalysis(analysisId = 6,
                                              description = "PS-match / OT2",
                                              getDbCohortMethodDataArgs = getDbCmDataArgs,
                                              createStudyPopArgs = createOt2StudyPopArgs,
                                              createPs = TRUE,
                                              createPsArgs = createPsArgs,
                                              stratifyByPs = TRUE,
                                              stratifyByPsArgs = stratifyByPsArgs,
                                              fitOutcomeModel = TRUE,
                                              fitOutcomeModelArgs = fitPsOutcomeModelArgs)

# Analysis 7 -- PS stratify / ITT

cmAnalysis7 <- CohortMethod::createCmAnalysis(analysisId = 7,
                                              description = "PS-match / ITT",
                                              getDbCohortMethodDataArgs = getDbCmDataArgs,
                                              createStudyPopArgs = createIttStudyPopArgs,
                                              createPs = TRUE,
                                              createPsArgs = createPsArgs,
                                              stratifyByPs = TRUE,
                                              stratifyByPsArgs = stratifyByPsArgs,
                                              fitOutcomeModel = TRUE,
                                              fitOutcomeModelArgs = fitPsOutcomeModelArgs)

cmAnalysisList <- list(cmAnalysis1,cmAnalysis2,cmAnalysis3,cmAnalysis4,cmAnalysis5,cmAnalysis6,cmAnalysis7)

CohortMethod::saveCmAnalysisList(cmAnalysisList, "cmAnalysisList.json")



