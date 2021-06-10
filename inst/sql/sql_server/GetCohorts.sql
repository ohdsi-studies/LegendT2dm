/************************************************************************
Copyright 2021 Observational Health Data Sciences and Informatics

This file is part of LegendT2dm

Licensed under the Apache License, Version 2.0 (the "License");
you may not use this file except in compliance with the License.
You may obtain a copy of the License at

    http://www.apache.org/licenses/LICENSE-2.0

Unless required by applicable law or agreed to in writing, software
distributed under the License is distributed on an "AS IS" BASIS,
WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
See the License for the specific language governing permissions and
limitations under the License.
************************************************************************/

{DEFAULT @cdm_version = '5'}
{DEFAULT @target_id = ''}
{DEFAULT @sampled = FALSE}

SELECT #exposure_cohorts.row_id,
	person_seq_id,
	CAST(cohort.subject_id AS VARCHAR(30)) AS person_id,
{@cdm_version == "4"} ? {
	CASE WHEN cohort.cohort_concept_id = @target_id THEN 1 ELSE 0 END AS treatment,
} : {
	CASE WHEN cohort.cohort_definition_id = @target_id THEN 1 ELSE 0 END AS treatment,
}
	cohort.cohort_start_date,
	days_from_obs_start,
	days_to_cohort_end,
	days_to_obs_end,
	cohort.row_id AS cm_row_id
{@sampled} ? {
FROM #cohort_sample cohort
} : {
FROM #cohort_person cohort
}
INNER JOIN (
	SELECT subject_id,
		ROW_NUMBER() OVER (ORDER BY subject_id) AS person_seq_id
	FROM (
		SELECT DISTINCT subject_id
{@sampled} ? {
		FROM #cohort_sample
} : {
		FROM #cohort_person
}
		) tmp
	) unique_ids
	ON cohort.subject_id = unique_ids.subject_id
INNER JOIN #exposure_cohorts
  ON cohort.subject_id = #exposure_cohorts.subject_id
  AND cohort.cohort_start_date = #exposure_cohorts.cohort_start_date
ORDER BY cohort.subject_id
