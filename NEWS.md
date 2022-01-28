LegendT2dm 1.1.0

Changes:

1. Do not limit `Glycemic control` cohort to first occurrence
2. Add with-prior-outcome analyses for `Glycemic control`
3. Expose `endStudyDate` in `execute()` for EHR data sources with end-of-observation dates
4. Set `minDaysAtRisk` to 0 so that initial OT and ITT populations are the same to improve reproducibility as an ATLAS-generated study, since only a single PS model is constructed for both populations
5. Report # of persons with 0 days at risk in `cm_follow_up_table`
6. Include data/time of results in returned artifacts
7. Fix negative control calibration in results export

LegendT2dm 1.0.4
=======================

Changes:

1. Fix custom data pull

LegendT2dm 1.0.2
=======================

Changes:

1. Patch `CohortDiagnostics` to exploit cast `cohortConceptIds` to 32-bit for BigQuery


LegendT2dm 1.0.1
=======================

Changes:

1. Patch `CohortDiagnostics` to truncated `sum_value` and `mean` columns in `covariate_balance.csv` to `minCellCount`
2. Add `NEWS.md` file
3. Patch path-specification error in `upload*` functions

LegendT2dm 0.0.1
=======================

Initial version
