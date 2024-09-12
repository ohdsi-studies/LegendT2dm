
createAnalysesDetails <- function(outputFolder,
                                  removeSubjectsWithPriorOutcome = TRUE,
                                  asUnitTest = FALSE) {

  getId <- function(id, removeSubjectsWithPriorOutcome) {
    ifelse(removeSubjectsWithPriorOutcome, id, id + 10)
  }

  getFile <- function(name, removeSubjectsWithPriorOutcome) {
    paste0(name, ifelse(removeSubjectsWithPriorOutcome, "", "Po"),
           "CmAnalysisList.json")
  }

  getDescription <- function(description, removeSubjectsWithPriorOutcome) {
    ifelse(removeSubjectsWithPriorOutcome,
           description,
           paste0(description, ", with prior outcome"))
  }

  # TODO This is still code-duplicated with CustomCmDataObjectBuilding.R lines 122 - 129
  # TODO getDbCmDataArgs is currently only used in the unit-tests; fix
  pathToCsv <- system.file("settings", "Indications.csv", package = "LegendT2dm")
  indications <- read.csv(pathToCsv)
  filterConceptIds <- as.character(indications$filterConceptIds[indications$indicationId == "class"])
  filterConceptIds <- as.numeric(strsplit(filterConceptIds, split = ";")[[1]])

  # create default covariateSettings
  defaultCovariateSettings =  FeatureExtraction::createDefaultCovariateSettings(
    excludedCovariateConceptIds = filterConceptIds,
    addDescendantsToExclude = TRUE)

  # add continuous age to covariateSettings
  defaultCovariateSettings$DemographicsAge = TRUE

  getDbCmDataArgs <- CohortMethod::createGetDbCohortMethodDataArgs(
    covariateSettings = defaultCovariateSettings
    )

  createStudyPopArgsOnTreatment <- CohortMethod::createCreateStudyPopulationArgs(
    restrictToCommonPeriod = TRUE,
    removeSubjectsWithPriorOutcome = removeSubjectsWithPriorOutcome,
    minDaysAtRisk = 0,
    riskWindowStart = 1,
    riskWindowEnd = 0,
    startAnchor = "cohort start",
    endAnchor = "cohort end")

  createStudyPopArgsItt <- CohortMethod::createCreateStudyPopulationArgs(
    restrictToCommonPeriod = TRUE,
    removeSubjectsWithPriorOutcome = removeSubjectsWithPriorOutcome,
    minDaysAtRisk = 0,
    riskWindowStart = 1,
    riskWindowEnd = 99999,
    startAnchor = "cohort start",
    endAnchor = "cohort end")

  createStudyPopArgsIttLagged <- CohortMethod::createCreateStudyPopulationArgs(
    restrictToCommonPeriod = TRUE,
    removeSubjectsWithPriorOutcome = removeSubjectsWithPriorOutcome,
    minDaysAtRisk = 0,
    riskWindowStart = 365,
    riskWindowEnd = 99999,
    startAnchor = "cohort start",
    endAnchor = "cohort end")

  createPsArgs <- CohortMethod::createCreatePsArgs(
    control = Cyclops::createControl(
      noiseLevel = "silent",
      cvType = "auto",
      tolerance = 2e-07,
      cvRepetitions = 1,
      startingVariance = 0.01,
      resetCoefficients = TRUE, # To maintain reproducibility
                                # irrespective of multi-threading
      seed = 123),
    stopOnError = FALSE,
    maxCohortSizeForFitting = 1e+05,
    excludeCovariateIds = c(1002) # exclude continuous age from PS model
    )

  matchOnPsArgs <- CohortMethod::createMatchOnPsArgs(
    caliper = 0.2,
    caliperScale = "standardized logit",
    allowReverseMatch = TRUE,
    maxRatio = 100)

  stratifyByPsArgs <- CohortMethod::createStratifyByPsArgs(
    numberOfStrata = 10,
    baseSelection = "all")

  fitOutcomeModelArgsMarginal <- CohortMethod::createFitOutcomeModelArgs(
    modelType = "cox",
    stratified = FALSE,
    profileBounds = c(log(0.1), log(10)))

  fitOutcomeModelArgsConditional <- CohortMethod::createFitOutcomeModelArgs(
    modelType = "cox",
    stratified = TRUE,
    profileBounds = c(log(0.1), log(10)))

  cmAnalysis1 <- CohortMethod::createCmAnalysis(
    analysisId = getId(1, removeSubjectsWithPriorOutcome),
    description = getDescription("Unadjusted, on-treatment1", removeSubjectsWithPriorOutcome),
    getDbCohortMethodDataArgs = getDbCmDataArgs,
    createStudyPopArgs = createStudyPopArgsOnTreatment,
    fitOutcomeModel = TRUE,
    fitOutcomeModelArgs = fitOutcomeModelArgsMarginal)

  cmAnalysis2 <- CohortMethod::createCmAnalysis(
    analysisId = getId(2, removeSubjectsWithPriorOutcome),
    description = getDescription("PS matching, on-treatment1", removeSubjectsWithPriorOutcome),
    getDbCohortMethodDataArgs = getDbCmDataArgs,
    createStudyPopArgs = createStudyPopArgsOnTreatment,
    createPs = TRUE,
    createPsArgs = createPsArgs,
    matchOnPs = TRUE,
    matchOnPsArgs = matchOnPsArgs,
    fitOutcomeModel = TRUE,
    fitOutcomeModelArgs = fitOutcomeModelArgsConditional)

  cmAnalysis3 <- CohortMethod::createCmAnalysis(
    analysisId = getId(3, removeSubjectsWithPriorOutcome),
    description = getDescription("PS stratification, on-treatment1", removeSubjectsWithPriorOutcome),
    getDbCohortMethodDataArgs = getDbCmDataArgs,
    createStudyPopArgs = createStudyPopArgsOnTreatment,
    createPs = TRUE,
    createPsArgs = createPsArgs,
    stratifyByPs = TRUE,
    stratifyByPsArgs = stratifyByPsArgs,
    fitOutcomeModel = TRUE,
    fitOutcomeModelArgs = fitOutcomeModelArgsConditional)

  cmAnalysis4 <- CohortMethod::createCmAnalysis(
    analysisId = getId(4, removeSubjectsWithPriorOutcome),
    description = getDescription("Unadjusted, intent-to-treat", removeSubjectsWithPriorOutcome),
    getDbCohortMethodDataArgs = getDbCmDataArgs,
    createStudyPopArgs = createStudyPopArgsItt,
    fitOutcomeModel = TRUE,
    fitOutcomeModelArgs = fitOutcomeModelArgsMarginal)

  cmAnalysis5 <- CohortMethod::createCmAnalysis(
    analysisId = getId(5, removeSubjectsWithPriorOutcome),
    description = getDescription("PS matching, intent-to-treat", removeSubjectsWithPriorOutcome),
    getDbCohortMethodDataArgs = getDbCmDataArgs,
    createStudyPopArgs = createStudyPopArgsItt,
    createPs = TRUE,
    createPsArgs = createPsArgs,
    matchOnPs = TRUE,
    matchOnPsArgs = matchOnPsArgs,
    fitOutcomeModel = TRUE,
    fitOutcomeModelArgs = fitOutcomeModelArgsConditional)

  cmAnalysis6 <- CohortMethod::createCmAnalysis(
    analysisId = getId(6, removeSubjectsWithPriorOutcome),
    description = getDescription("PS stratification, intent-to-treat", removeSubjectsWithPriorOutcome),
    getDbCohortMethodDataArgs = getDbCmDataArgs,
    createStudyPopArgs = createStudyPopArgsItt,
    createPs = TRUE,
    createPsArgs = createPsArgs,
    stratifyByPs = TRUE,
    stratifyByPsArgs = stratifyByPsArgs,
    fitOutcomeModel = TRUE,
    fitOutcomeModelArgs = fitOutcomeModelArgsConditional)

  cmAnalysis7 <- CohortMethod::createCmAnalysis(
    analysisId = getId(7, removeSubjectsWithPriorOutcome),
    description = getDescription("Unadjusted, on-treatment2", removeSubjectsWithPriorOutcome),
    getDbCohortMethodDataArgs = getDbCmDataArgs,
    createStudyPopArgs = createStudyPopArgsOnTreatment,
    fitOutcomeModel = TRUE,
    fitOutcomeModelArgs = fitOutcomeModelArgsMarginal)

  cmAnalysis8 <- CohortMethod::createCmAnalysis(
    analysisId = getId(8, removeSubjectsWithPriorOutcome),
    description = getDescription("PS matching, on-treatment2", removeSubjectsWithPriorOutcome),
    getDbCohortMethodDataArgs = getDbCmDataArgs,
    createStudyPopArgs = createStudyPopArgsOnTreatment,
    createPs = TRUE,
    createPsArgs = createPsArgs,
    matchOnPs = TRUE,
    matchOnPsArgs = matchOnPsArgs,
    fitOutcomeModel = TRUE,
    fitOutcomeModelArgs = fitOutcomeModelArgsConditional)

  cmAnalysis9 <- CohortMethod::createCmAnalysis(
    analysisId = getId(9, removeSubjectsWithPriorOutcome),
    description = getDescription("PS stratification, on-treatment2", removeSubjectsWithPriorOutcome),
    getDbCohortMethodDataArgs = getDbCmDataArgs,
    createStudyPopArgs = createStudyPopArgsOnTreatment,
    createPs = TRUE,
    createPsArgs = createPsArgs,
    stratifyByPs = TRUE,
    stratifyByPsArgs = stratifyByPsArgs,
    fitOutcomeModel = TRUE,
    fitOutcomeModelArgs = fitOutcomeModelArgsConditional)

  cmAnalysis10 <- CohortMethod::createCmAnalysis(
    analysisId = getId(4, removeSubjectsWithPriorOutcome) + 100,
    description = paste0(getDescription("Unadjusted, intent-to-treat", removeSubjectsWithPriorOutcome), ", lagged"),
    getDbCohortMethodDataArgs = getDbCmDataArgs,
    createStudyPopArgs = createStudyPopArgsIttLagged,
    fitOutcomeModel = TRUE,
    fitOutcomeModelArgs = fitOutcomeModelArgsMarginal)

  cmAnalysis11 <- CohortMethod::createCmAnalysis(
    analysisId = getId(5, removeSubjectsWithPriorOutcome) + 100,
    description = paste0(getDescription("PS matching, intent-to-treat", removeSubjectsWithPriorOutcome), ", lagged"),
    getDbCohortMethodDataArgs = getDbCmDataArgs,
    createStudyPopArgs = createStudyPopArgsIttLagged,
    createPs = TRUE,
    createPsArgs = createPsArgs,
    matchOnPs = TRUE,
    matchOnPsArgs = matchOnPsArgs,
    fitOutcomeModel = TRUE,
    fitOutcomeModelArgs = fitOutcomeModelArgsConditional)

  cmAnalysis12 <- CohortMethod::createCmAnalysis(
    analysisId = getId(6, removeSubjectsWithPriorOutcome) + 100,
    description = paste0(getDescription("PS stratification, intent-to-treat", removeSubjectsWithPriorOutcome), ", lagged"),
    getDbCohortMethodDataArgs = getDbCmDataArgs,
    createStudyPopArgs = createStudyPopArgsIttLagged,
    createPs = TRUE,
    createPsArgs = createPsArgs,
    stratifyByPs = TRUE,
    stratifyByPsArgs = stratifyByPsArgs,
    fitOutcomeModel = TRUE,
    fitOutcomeModelArgs = fitOutcomeModelArgsConditional)



  if (asUnitTest) {
    CohortMethod::saveCmAnalysisList(list(cmAnalysis1, cmAnalysis2, cmAnalysis3,
                                          cmAnalysis4, cmAnalysis5, cmAnalysis6),
                                     file.path(outputFolder, ifelse(removeSubjectsWithPriorOutcome,
                                                                    "cmAnalysisList.json",
                                                                    "poCmAnalysisList.json")))
  } else {
    CohortMethod::saveCmAnalysisList(list(cmAnalysis1, cmAnalysis2, cmAnalysis3),
                                     file.path(outputFolder, getFile("ot1", removeSubjectsWithPriorOutcome)))

    CohortMethod::saveCmAnalysisList(list(cmAnalysis4, cmAnalysis5, cmAnalysis6),
                                     file.path(outputFolder, getFile("itt", removeSubjectsWithPriorOutcome)))

    CohortMethod::saveCmAnalysisList(list(cmAnalysis7, cmAnalysis8, cmAnalysis9),
                                     file.path(outputFolder, getFile("ot2", removeSubjectsWithPriorOutcome)))

    CohortMethod::saveCmAnalysisList(list(cmAnalysis10, cmAnalysis11, cmAnalysis12),
                                     file.path(outputFolder, getFile("lag", removeSubjectsWithPriorOutcome)))
  }
}
