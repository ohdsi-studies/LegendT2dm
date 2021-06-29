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
{DEFAULT @cohort_database_schema = 'scratch.dbo'}
{DEFAULT @original_cohort_table = 'cohort'}
{DEFAULT @sampled_cohort_table = 'sample_cohort'}
{DEFAULT @sample_size = 1000}

-- Sample cohorts. Store in @cohort_database_schema.@sampled_cohort_table
IF OBJECT_ID('@cohort_database_schema.@sampled_cohort_table', 'U') IS NOT NULL
	DROP TABLE @cohort_database_schema.@sampled_cohort_table;


--HINT DISTRIBUTE_ON_KEY(subject_id)
SELECT cohort_definition_id,
	subject_id,
	cohort_start_date,
	cohort_end_date
INTO @cohort_database_schema.@sampled_cohort_table
FROM (
	SELECT ROW_NUMBER() OVER (
			PARTITION BY cohort_definition_id
			ORDER BY NEWID()
			) AS rn,
		cohort_definition_id,
		subject_id,
		cohort_start_date,
		cohort_end_date
	FROM @cohort_database_schema.@original_cohort_table
	) tmp
WHERE rn <= @sample_size;

