LegendT2dm 2.1.0
=======================

Changes:

1. Enable drug-vs-drug comparisons for all drug classes (within and across classes)
2. Fixed a bug for drug-level studies where OT2 studies failed to execute
3. Include continuous age in patient characteristics

LegendT2dm 2.0.1
=======================

Changes:

1. Handle ungraceful crash when all paired exposure cohorts are too small

LegendT2dm 2.0.0
=======================

Changes: 

1. Expand study package to include within-class drug-level CES studies for SGLT2 Inhibitors

LegendT2dm 1.2.0
=======================

Changes: 

1. Add meta-analysis routines
2. Update `LegendT2dmEvidenceExplorer` to display meta-analysis results
3. Add `sources` to `cohort_method_result` in results schema to record which sources are used in a meta-analysis

LegendT2dm 1.1.5
=======================

Changes:

1. Add `database_id` as column to resulting `likelihood_profile` table

LegendT2dm 1.1.4
=======================

Changes:

1. Change `Inf` numeric values to `NA` for upload to database (TODO: Fix)

LegendT2dm 1.1.3
=======================

Changes:

1. Fix `analysisSummary.csv` when using multiple runs

LegendT2dm 1.1.2
=======================

Changes:

1. Add option to execute only `Run_1`

LegendT2dm 1.1.0
=======================

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
