INSERT INTO @cohort_database_schema.@cohort_table (
	subject_id,
	cohort_definition_id,
	cohort_start_date,
	cohort_end_date
	)
SELECT person_id AS subject_id,
	ancestor_concept_id AS cohort_definition_id,
	MIN(condition_start_date) AS cohort_start_date,
	MIN(condition_end_date) AS cohort_end_date
FROM @cdm_database_schema.condition_occurrence
INNER JOIN @cdm_database_schema.concept_ancestor
	ON condition_concept_id = descendant_concept_id
WHERE ancestor_concept_id IN (@outcome_ids)
GROUP BY person_id,
	ancestor_concept_id;
