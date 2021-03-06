createAnalysesDetails <- function(outputFolder) {

  # Dummy argument that is never used because data objects have already been created:
  getDbCmDataArgs <- CohortMethod::createGetDbCohortMethodDataArgs(
    covariateSettings = FeatureExtraction::createCovariateSettings(useDemographicsGender = TRUE))

  createStudyPopArgsOnTreatment <- CohortMethod::createCreateStudyPopulationArgs(
    restrictToCommonPeriod = TRUE,
    removeSubjectsWithPriorOutcome = TRUE,
    minDaysAtRisk = 1,
    riskWindowStart = 1,
    riskWindowEnd = 0,
    startAnchor = "cohort start",
    endAnchor = "cohort end")

  createStudyPopArgsItt <- CohortMethod::createCreateStudyPopulationArgs(
    restrictToCommonPeriod = TRUE,
    removeSubjectsWithPriorOutcome = TRUE,
    minDaysAtRisk = 1,
    riskWindowStart = 1,
    riskWindowEnd = 9999,
    startAnchor = "cohort start",
    endAnchor = "cohort end")

  createPsArgs <- CohortMethod::createCreatePsArgs(
    control = Cyclops::createControl(
      noiseLevel = "silent",
      cvType = "auto",
      tolerance = 2e-07,
      cvRepetitions = 1,
      startingVariance = 0.01,
      seed = 123),
    stopOnError = FALSE,
    maxCohortSizeForFitting = 1e+05)

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
    analysisId = 1,
    description = "Unadjusted, on-treatment1",
    getDbCohortMethodDataArgs = getDbCmDataArgs,
    createStudyPopArgs = createStudyPopArgsOnTreatment,
    fitOutcomeModel = TRUE,
    fitOutcomeModelArgs = fitOutcomeModelArgsMarginal)

  cmAnalysis2 <- CohortMethod::createCmAnalysis(
    analysisId = 2,
    description = "PS matching, on-treatment1",
    getDbCohortMethodDataArgs = getDbCmDataArgs,
    createStudyPopArgs = createStudyPopArgsOnTreatment,
    createPs = TRUE,
    createPsArgs = createPsArgs,
    matchOnPs = TRUE,
    matchOnPsArgs = matchOnPsArgs,
    fitOutcomeModel = TRUE,
    fitOutcomeModelArgs = fitOutcomeModelArgsMarginal)

  cmAnalysis3 <- CohortMethod::createCmAnalysis(
    analysisId = 3,
    description = "PS stratification, on-treatment1",
    getDbCohortMethodDataArgs = getDbCmDataArgs,
    createStudyPopArgs = createStudyPopArgsOnTreatment,
    createPs = TRUE,
    createPsArgs = createPsArgs,
    stratifyByPs = TRUE,
    stratifyByPsArgs = stratifyByPsArgs,
    fitOutcomeModel = TRUE,
    fitOutcomeModelArgs = fitOutcomeModelArgsConditional)

  cmAnalysis4 <- CohortMethod::createCmAnalysis(
    analysisId = 4,
    description = "Unadjusted, intent-to-treat",
    getDbCohortMethodDataArgs = getDbCmDataArgs,
    createStudyPopArgs = createStudyPopArgsItt,
    fitOutcomeModel = TRUE,
    fitOutcomeModelArgs = fitOutcomeModelArgsMarginal)

  cmAnalysis5 <- CohortMethod::createCmAnalysis(
    analysisId = 5,
    description = "PS matching, intent-to-treat",
    getDbCohortMethodDataArgs = getDbCmDataArgs,
    createStudyPopArgs = createStudyPopArgsItt,
    createPs = TRUE,
    createPsArgs = createPsArgs,
    matchOnPs = TRUE,
    matchOnPsArgs = matchOnPsArgs,
    fitOutcomeModel = TRUE,
    fitOutcomeModelArgs = fitOutcomeModelArgsMarginal)

  cmAnalysis6 <- CohortMethod::createCmAnalysis(
    analysisId = 6,
    description = "PS stratification, intent-to-treat",
    getDbCohortMethodDataArgs = getDbCmDataArgs,
    createStudyPopArgs = createStudyPopArgsItt,
    createPs = TRUE,
    createPsArgs = createPsArgs,
    stratifyByPs = TRUE,
    stratifyByPsArgs = stratifyByPsArgs,
    fitOutcomeModel = TRUE,
    fitOutcomeModelArgs = fitOutcomeModelArgsConditional)

  cmAnalysis7 <- CohortMethod::createCmAnalysis(
    analysisId = 7,
    description = "Unadjusted, on-treatment2",
    getDbCohortMethodDataArgs = getDbCmDataArgs,
    createStudyPopArgs = createStudyPopArgsOnTreatment,
    fitOutcomeModel = TRUE,
    fitOutcomeModelArgs = fitOutcomeModelArgsMarginal)

  cmAnalysis8 <- CohortMethod::createCmAnalysis(
    analysisId = 8,
    description = "PS matching, on-treatment2",
    getDbCohortMethodDataArgs = getDbCmDataArgs,
    createStudyPopArgs = createStudyPopArgsOnTreatment,
    createPs = TRUE,
    createPsArgs = createPsArgs,
    matchOnPs = TRUE,
    matchOnPsArgs = matchOnPsArgs,
    fitOutcomeModel = TRUE,
    fitOutcomeModelArgs = fitOutcomeModelArgsMarginal)

  cmAnalysis9 <- CohortMethod::createCmAnalysis(
    analysisId = 9,
    description = "PS stratification, on-treatment2",
    getDbCohortMethodDataArgs = getDbCmDataArgs,
    createStudyPopArgs = createStudyPopArgsOnTreatment,
    createPs = TRUE,
    createPsArgs = createPsArgs,
    stratifyByPs = TRUE,
    stratifyByPsArgs = stratifyByPsArgs,
    fitOutcomeModel = TRUE,
    fitOutcomeModelArgs = fitOutcomeModelArgsConditional)

  CohortMethod::saveCmAnalysisList(list(cmAnalysis1, cmAnalysis2, cmAnalysis3),
                                   file.path(outputFolder, "ot1CmAnalysisList.json"))

  CohortMethod::saveCmAnalysisList(list(cmAnalysis4, cmAnalysis5, cmAnalysis6),
                                   file.path(outputFolder, "ittCmAnalysisList.json"))

  CohortMethod::saveCmAnalysisList(list(cmAnalysis7, cmAnalysis8, cmAnalysis9),
                                   file.path(outputFolder, "ot2CmAnalysisList.json"))
}
