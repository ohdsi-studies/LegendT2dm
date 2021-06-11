
DROP TABLE IF EXISTS ps_auc_assessment;
DROP TABLE IF EXISTS ps_covariate_assessment;

CREATE TABLE ps_auc_assessment (
			target_id BIGINT NOT NULL,
			comparator_id BIGINT NOT NULL,
			database_id VARCHAR NOT NULL,
			auc FLOAT,
			equipoise FLOAT,
			PRIMARY KEY(database_id, target_id, comparator_id)
);

CREATE TABLE ps_covariate_assessment (
			target_id BIGINT NOT NULL,
			comparator_id BIGINT NOT NULL,
			database_id VARCHAR NOT NULL,
			coefficient FLOAT,
			covariate_id BIGINT NOT NULL,
			covariate_name VARCHAR,
			PRIMARY KEY(database_id, target_id, comparator_id)
);
