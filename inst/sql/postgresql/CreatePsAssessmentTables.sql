-- Drop old tables if exists

DROP TABLE IF EXISTS ps_auc_assessment;
DROP TABLE IF EXISTS ps_covariate_assessment;

-- Create tables

CREATE TABLE ps_auc_assessment (
     database_id VARCHAR(255) NOT NULL,
     target_id BIGINT NOT NULL,
     comparator_id BIGINT NOT NULL,
     auc NUMERIC NOT NULL,
     equipoise NUMERIC NOT NULL,
     comparison TEXT ,
     PRIMARY KEY(database_id, target_id, comparator_id)
);

CREATE TABLE ps_covariate_assessment (
     target_id BIGINT NOT NULL,
     comparator_id BIGINT NOT NULL,
     database_id VARCHAR(255) NOT NULL,
     covariate_id BIGINT NOT NULL,
     comparison TEXT ,
     covariate_name TEXT ,
     coefficient NUMERIC ,
     PRIMARY KEY(target_id, comparator_id, database_id, covariate_id)
);

