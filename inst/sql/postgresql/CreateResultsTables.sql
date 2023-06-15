-- Drop old tables if exists

DROP TABLE IF EXISTS attrition;
DROP TABLE IF EXISTS cm_follow_up_dist;
DROP TABLE IF EXISTS cohort_method_analysis;
DROP TABLE IF EXISTS cohort_method_result;
DROP TABLE IF EXISTS comparison_summary;
DROP TABLE IF EXISTS covariate;
DROP TABLE IF EXISTS covariate_analysis;
DROP TABLE IF EXISTS covariate_balance;
DROP TABLE IF EXISTS database;
DROP TABLE IF EXISTS diagnostics;
DROP TABLE IF EXISTS exposure_of_interest;
DROP TABLE IF EXISTS exposure_summary;
DROP TABLE IF EXISTS kaplan_meier_dist;
DROP TABLE IF EXISTS likelihood_profile;
DROP TABLE IF EXISTS negative_control_outcome;
DROP TABLE IF EXISTS outcome_of_interest;
DROP TABLE IF EXISTS preference_score_dist;
DROP TABLE IF EXISTS propensity_model;
DROP TABLE IF EXISTS ps_auc_assessment;
DROP TABLE IF EXISTS results_date_time;

-- Create tables

CREATE TABLE attrition (
     database_id VARCHAR(255) NOT NULL,
     exposure_id BIGINT NOT NULL,
     target_id BIGINT NOT NULL,
     comparator_id BIGINT NOT NULL,
     outcome_id BIGINT NOT NULL,
     analysis_id INTEGER NOT NULL,
     sequence_number INTEGER NOT NULL,
     description TEXT ,
     subjects INTEGER ,
     PRIMARY KEY(database_id, exposure_id, target_id, comparator_id, outcome_id, analysis_id, sequence_number)
);

CREATE TABLE cm_follow_up_dist (
     database_id VARCHAR(255) NOT NULL,
     target_id BIGINT NOT NULL,
     comparator_id BIGINT NOT NULL,
     outcome_id BIGINT NOT NULL,
     analysis_id INTEGER NOT NULL,
     target_min_days INTEGER ,
     target_p10_days INTEGER ,
     target_p25_days INTEGER ,
     target_median_days INTEGER ,
     target_p75_days INTEGER ,
     target_p90_days INTEGER ,
     target_max_days INTEGER ,
     target_zero_days INTEGER ,
     comparator_min_days INTEGER ,
     comparator_p10_days INTEGER ,
     comparator_p25_days INTEGER ,
     comparator_median_days INTEGER ,
     comparator_p75_days INTEGER ,
     comparator_p90_days INTEGER ,
     comparator_max_days INTEGER ,
     comparator_zero_days INTEGER ,
     PRIMARY KEY(database_id, target_id, comparator_id, outcome_id, analysis_id)
);

CREATE TABLE cohort_method_analysis (
     analysis_id INTEGER NOT NULL,
     description TEXT NOT NULL,
     definition TEXT NOT NULL,
     PRIMARY KEY(analysis_id)
);

CREATE TABLE cohort_method_result (
     database_id VARCHAR(255) NOT NULL,
     target_id BIGINT NOT NULL,
     comparator_id BIGINT NOT NULL,
     outcome_id BIGINT NOT NULL,
     analysis_id INTEGER NOT NULL,
     rr NUMERIC ,
     ci_95_lb NUMERIC ,
     ci_95_ub NUMERIC ,
     p NUMERIC ,
     i_2 NUMERIC ,
     sources VARCHAR(255) ,
     log_rr NUMERIC ,
     se_log_rr NUMERIC ,
     target_subjects INTEGER ,
     comparator_subjects INTEGER ,
     target_days BIGINT ,
     comparator_days BIGINT ,
     target_outcomes INTEGER ,
     comparator_outcomes INTEGER ,
     calibrated_p NUMERIC ,
     calibrated_rr NUMERIC ,
     calibrated_ci_95_lb NUMERIC ,
     calibrated_ci_95_ub NUMERIC ,
     calibrated_log_rr NUMERIC ,
     calibrated_se_log_rr NUMERIC ,
     PRIMARY KEY(database_id, target_id, comparator_id, outcome_id, analysis_id)
);

CREATE TABLE comparison_summary (
     database_id VARCHAR(255) NOT NULL,
     target_id BIGINT NOT NULL,
     comparator_id BIGINT NOT NULL,
     min_date DATE NOT NULL,
     max_date DATE NOT NULL,
     PRIMARY KEY(database_id, target_id, comparator_id)
);

CREATE TABLE covariate (
     database_id VARCHAR(255) NOT NULL,
     analysis_id INTEGER NOT NULL,
     covariate_id BIGINT NOT NULL,
     covariate_analysis_id BIGINT NOT NULL,
     covariate_name TEXT NOT NULL,
     PRIMARY KEY(database_id, analysis_id, covariate_id, covariate_analysis_id)
);

CREATE TABLE covariate_analysis (
     covariate_analysis_id BIGINT NOT NULL,
     analysis_id INTEGER NOT NULL,
     covariate_analysis_name TEXT NOT NULL,
     PRIMARY KEY(covariate_analysis_id, analysis_id)
);

CREATE TABLE covariate_balance (
     database_id VARCHAR(255) NOT NULL,
     target_id BIGINT NOT NULL,
     comparator_id BIGINT NOT NULL,
     outcome_id BIGINT NOT NULL,
     analysis_id INTEGER NOT NULL,
     covariate_id BIGINT NOT NULL,
     target_mean_before NUMERIC NOT NULL,
     comparator_mean_before NUMERIC NOT NULL,
     std_diff_before NUMERIC NOT NULL,
     target_mean_after NUMERIC NOT NULL,
     comparator_mean_after NUMERIC NOT NULL,
     std_diff_after NUMERIC NOT NULL,
     PRIMARY KEY(database_id, target_id, comparator_id, outcome_id, analysis_id, covariate_id)
);

CREATE TABLE database (
     database_id VARCHAR(255) NOT NULL,
     database_name VARCHAR(255) NOT NULL,
     description TEXT NOT NULL,
     vocabulary_version VARCHAR(255) ,
     min_obs_period_date DATE ,
     max_obs_period_date DATE ,
     study_package_version VARCHAR(255) ,
     is_meta_analysis INTEGER NOT NULL,
     PRIMARY KEY(database_id)
);

CREATE TABLE diagnostics (
     database_id VARCHAR(255) NOT NULL,
     target_id BIGINT NOT NULL,
     comparator_id BIGINT NOT NULL,
     outcome_id BIGINT NOT NULL,
     analysis_id INTEGER NOT NULL,
     any_outcomes INTEGER ,
     mdrr NUMERIC ,
     max_abs_std_diff_mean NUMERIC ,
     min_equipoise NUMERIC ,
     ease NUMERIC ,
     pass INTEGER ,
     criteria VARCHAR(255) ,
     PRIMARY KEY(database_id, target_id, comparator_id, outcome_id, analysis_id)
);

CREATE TABLE exposure_of_interest (
     exposure_id BIGINT NOT NULL,
     exposure_name TEXT NOT NULL,
     definition TEXT NOT NULL,
     PRIMARY KEY(exposure_id)
);

CREATE TABLE exposure_summary (
     database_id VARCHAR(255) NOT NULL,
     exposure_id BIGINT NOT NULL,
     min_date DATE NOT NULL,
     max_date DATE NOT NULL,
     PRIMARY KEY(database_id, exposure_id)
);

CREATE TABLE kaplan_meier_dist (
     database_id VARCHAR(255) NOT NULL,
     target_id BIGINT NOT NULL,
     comparator_id BIGINT NOT NULL,
     outcome_id BIGINT NOT NULL,
     analysis_id INTEGER NOT NULL,
     time INTEGER NOT NULL,
     target_at_risk INTEGER ,
     comparator_at_risk INTEGER ,
     target_survival NUMERIC NOT NULL,
     target_survival_lb NUMERIC NOT NULL,
     target_survival_ub NUMERIC NOT NULL,
     comparator_survival NUMERIC NOT NULL,
     comparator_survival_lb NUMERIC NOT NULL,
     comparator_survival_ub NUMERIC NOT NULL,
     PRIMARY KEY(database_id, target_id, comparator_id, outcome_id, analysis_id, time)
);

CREATE TABLE likelihood_profile (
     database_id VARCHAR(255) NOT NULL,
     target_id BIGINT NOT NULL,
     comparator_id BIGINT NOT NULL,
     outcome_id BIGINT NOT NULL,
     analysis_id INTEGER NOT NULL,
     point TEXT NOT NULL,
     value TEXT NOT NULL,
     PRIMARY KEY(database_id, target_id, comparator_id, outcome_id, analysis_id)
);

CREATE TABLE negative_control_outcome (
     outcome_id BIGINT NOT NULL,
     concept_id BIGINT NOT NULL,
     outcome_name TEXT NOT NULL,
     PRIMARY KEY(outcome_id, concept_id)
);

CREATE TABLE outcome_of_interest (
     outcome_id INT NOT NULL,
     outcome_name TEXT NOT NULL,
     description TEXT ,
     definition TEXT NOT NULL,
     PRIMARY KEY(outcome_id)
);

CREATE TABLE preference_score_dist (
     database_id VARCHAR(255) NOT NULL,
     target_id BIGINT NOT NULL,
     comparator_id BIGINT NOT NULL,
     analysis_id INTEGER NOT NULL,
     preference_score NUMERIC NOT NULL,
     target_density NUMERIC NOT NULL,
     comparator_density NUMERIC NOT NULL,
     PRIMARY KEY(database_id, target_id, comparator_id, analysis_id, preference_score)
);

CREATE TABLE propensity_model (
     database_id VARCHAR(255) NOT NULL,
     target_id BIGINT NOT NULL,
     comparator_id BIGINT NOT NULL,
     analysis_id INTEGER NOT NULL,
     covariate_id BIGINT NOT NULL,
     coefficient NUMERIC NOT NULL,
     PRIMARY KEY(database_id, target_id, comparator_id, analysis_id, covariate_id)
);

CREATE TABLE ps_auc_assessment (
     database_id VARCHAR(255) NOT NULL,
     target_id BIGINT NOT NULL,
     comparator_id BIGINT NOT NULL,
     analysis_id INTEGER NOT NULL,
     auc NUMERIC NOT NULL,
     equipoise NUMERIC NOT NULL,
     PRIMARY KEY(database_id, target_id, comparator_id, analysis_id)
);

CREATE TABLE results_date_time (
     database_id VARCHAR(255) NOT NULL,
     date_time VARCHAR(255) NOT NULL,
     package_version VARCHAR(255) NOT NULL,
     PRIMARY KEY(database_id)
);

