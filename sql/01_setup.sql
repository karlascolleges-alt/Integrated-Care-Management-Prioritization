CREATE DATABASE IF NOT EXISTS NIDHI_HEALTHCARE_ANALYTICS;
CREATE SCHEMA IF NOT EXISTS NIDHI_HEALTHCARE_ANALYTICS.CARE_MANAGEMENT;

USE DATABASE NIDHI_HEALTHCARE_ANALYTICS;
USE SCHEMA CARE_MANAGEMENT;

CREATE OR REPLACE TABLE PROJECT_CONFIG (
    config_id                      INTEGER      NOT NULL,
    analysis_start_date            DATE         NOT NULL,
    analysis_end_date              DATE         NOT NULL,
    high_ed_visit_threshold        INTEGER      NOT NULL,
    high_inpatient_threshold       INTEGER      NOT NULL,
    medium_ed_visit_threshold      INTEGER      NOT NULL,
    medium_inpatient_threshold     INTEGER      NOT NULL,
    medium_chronic_threshold       INTEGER      NOT NULL,
    config_description             VARCHAR(200) NOT NULL,
    CONSTRAINT pk_project_config PRIMARY KEY (config_id)
);

CREATE OR REPLACE TABLE PATIENT (
    patient_id       INTEGER      NOT NULL,
    patient_name     VARCHAR(30)  NOT NULL,
    birth_date       DATE         NOT NULL,
    insurance_type   VARCHAR(20)  NOT NULL,
    CONSTRAINT pk_patient PRIMARY KEY (patient_id)
);

CREATE OR REPLACE TABLE ENCOUNTER (
    encounter_id     INTEGER       NOT NULL,
    patient_id       INTEGER       NOT NULL,
    encounter_date   DATE          NOT NULL,
    encounter_type   VARCHAR(20)   NOT NULL,
    total_cost       NUMBER(10, 2) NOT NULL,
    CONSTRAINT pk_encounter PRIMARY KEY (encounter_id),
    CONSTRAINT fk_encounter_patient
        FOREIGN KEY (patient_id) REFERENCES PATIENT (patient_id)
);

CREATE OR REPLACE TABLE PATIENT_DIAGNOSIS (
    patient_diagnosis_id   INTEGER      NOT NULL,
    patient_id             INTEGER      NOT NULL,
    diagnosis_code         VARCHAR(10)  NOT NULL,
    diagnosis_name         VARCHAR(100) NOT NULL,
    chronic_flag           BOOLEAN      NOT NULL,
    CONSTRAINT pk_patient_diagnosis PRIMARY KEY (patient_diagnosis_id),
    CONSTRAINT fk_diagnosis_patient
        FOREIGN KEY (patient_id) REFERENCES PATIENT (patient_id)
);

/*
The result grain is one patient for one analysis date. The date is included in
the key so later runs can be retained rather than replacing all history.
*/
CREATE OR REPLACE TABLE CARE_MANAGEMENT_RESULT (
    patient_id                    INTEGER       NOT NULL,
    analysis_date                 DATE          NOT NULL,
    total_encounters_365d         INTEGER       NOT NULL,
    ed_visits_365d                INTEGER       NOT NULL,
    inpatient_admissions_365d     INTEGER       NOT NULL,
    chronic_condition_count       INTEGER       NOT NULL,
    total_cost_365d                NUMBER(12, 2) NOT NULL,
    last_encounter_date            DATE,
    priority_level                VARCHAR(10)   NOT NULL,
    priority_reason               VARCHAR(100)  NOT NULL,
    recommendation                VARCHAR(100)  NOT NULL,
    calculated_at                 TIMESTAMP_NTZ NOT NULL DEFAULT CURRENT_TIMESTAMP(),
    CONSTRAINT pk_care_result PRIMARY KEY (patient_id, analysis_date),
    CONSTRAINT fk_result_patient
        FOREIGN KEY (patient_id) REFERENCES PATIENT (patient_id)
);

/* One audit row summarizes one completed analysis date. */
CREATE OR REPLACE TABLE ANALYSIS_RUN_AUDIT (
    analysis_date        DATE          NOT NULL,
    config_id            INTEGER       NOT NULL,
    result_count         INTEGER       NOT NULL,
    high_priority_count  INTEGER       NOT NULL,
    medium_priority_count INTEGER      NOT NULL,
    low_priority_count   INTEGER       NOT NULL,
    completed_at         TIMESTAMP_NTZ NOT NULL DEFAULT CURRENT_TIMESTAMP(),
    CONSTRAINT pk_analysis_run_audit PRIMARY KEY (analysis_date)
);

