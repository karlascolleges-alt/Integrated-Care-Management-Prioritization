
USE DATABASE NIDHI_HEALTHCARE_ANALYTICS;
USE SCHEMA CARE_MANAGEMENT;

TRUNCATE TABLE PROJECT_CONFIG;
TRUNCATE TABLE PATIENT_DIAGNOSIS;
TRUNCATE TABLE ENCOUNTER;
TRUNCATE TABLE PATIENT;

INSERT INTO PROJECT_CONFIG VALUES (
    1,
    DATE '2025-07-01',
    DATE '2026-06-30',
    3,
    2,
    1,
    1,
    2,
    'Transparent educational thresholds for a human review-priority queue'
);

INSERT INTO PATIENT
    (patient_id, patient_name, birth_date, insurance_type)
VALUES
    (1, 'Patient 001', DATE '1955-04-12', 'Medicare'),
    (2, 'Patient 002', DATE '1948-09-03', 'Medicare'),
    (3, 'Patient 003', DATE '1982-01-21', 'Commercial'),
    (4, 'Patient 004', DATE '1966-11-18', 'Commercial'),
    (5, 'Patient 005', DATE '1990-06-07', 'Commercial'),
    (6, 'Patient 006', DATE '1951-02-28', 'Dual'),
    (7, 'Patient 007', DATE '1974-08-16', 'Medicaid'),
    (8, 'Patient 008', DATE '1988-12-02', 'Commercial'),
    (9, 'Patient 009', DATE '1960-03-14', 'Medicare'),
    (10, 'Patient 010', DATE '1958-10-25', 'Medicare'),
    (11, 'Patient 011', DATE '1996-05-09', 'Commercial'),
    (12, 'Patient 012', DATE '1979-07-30', 'Medicaid'),
    (13, 'Patient 013', DATE '1949-01-11', 'Medicare'),
    (14, 'Patient 014', DATE '1993-09-19', 'Commercial'),
    (15, 'Patient 015', DATE '1969-04-05', 'Commercial');

/* Encounter 12 is intentionally outside the configured analysis window. */
INSERT INTO ENCOUNTER
    (encounter_id, patient_id, encounter_date, encounter_type, total_cost)
VALUES
    (1, 1, DATE '2025-08-10', 'ED', 1450.00),
    (2, 1, DATE '2025-12-03', 'ED', 1700.00),
    (3, 1, DATE '2026-04-15', 'ED', 1550.00),
    (4, 1, DATE '2026-05-02', 'Primary Care', 220.00),
    (5, 2, DATE '2025-09-14', 'Inpatient', 13500.00),
    (6, 2, DATE '2026-02-22', 'Inpatient', 14900.00),
    (7, 2, DATE '2026-04-01', 'Specialist', 460.00),
    (8, 3, DATE '2026-01-18', 'ED', 1200.00),
    (9, 3, DATE '2026-03-08', 'Primary Care', 190.00),
    (10, 4, DATE '2025-11-12', 'Primary Care', 210.00),
    (11, 4, DATE '2026-04-19', 'Specialist', 390.00),
    (12, 5, DATE '2025-04-01', 'ED', 1350.00),
    (13, 5, DATE '2026-02-10', 'Primary Care', 175.00),
    (14, 6, DATE '2025-07-19', 'Inpatient', 16200.00),
    (15, 6, DATE '2025-10-06', 'ED', 1800.00),
    (16, 6, DATE '2026-03-17', 'Inpatient', 17100.00),
    (17, 7, DATE '2026-05-23', 'ED', 1100.00),
    (18, 7, DATE '2026-06-02', 'Primary Care', 200.00),
    (19, 8, DATE '2025-08-27', 'Primary Care', 185.00),
    (20, 8, DATE '2026-03-11', 'Primary Care', 190.00),
    (21, 9, DATE '2025-07-08', 'ED', 1500.00),
    (22, 9, DATE '2025-09-21', 'ED', 1600.00),
    (23, 9, DATE '2026-01-07', 'ED', 1725.00),
    (24, 9, DATE '2026-05-29', 'ED', 1825.00),
    (25, 10, DATE '2025-10-31', 'Specialist', 410.00),
    (26, 10, DATE '2026-04-08', 'Primary Care', 205.00),
    (27, 11, DATE '2026-02-14', 'Specialist', 350.00),
    (28, 12, DATE '2025-12-20', 'ED', 1250.00),
    (29, 12, DATE '2026-03-25', 'Primary Care', 195.00),
    (30, 13, DATE '2025-08-03', 'ED', 1400.00),
    (31, 13, DATE '2025-12-29', 'ED', 1525.00),
    (32, 13, DATE '2026-06-11', 'ED', 1675.00),
    (33, 14, DATE '2026-01-26', 'Primary Care', 180.00),
    (34, 15, DATE '2026-03-02', 'Inpatient', 12100.00),
    (35, 15, DATE '2026-05-20', 'Primary Care', 210.00);

INSERT INTO PATIENT_DIAGNOSIS
    (patient_diagnosis_id, patient_id, diagnosis_code, diagnosis_name, chronic_flag)
VALUES
    (1, 1, 'I10', 'Hypertension', TRUE),
    (2, 1, 'E11.9', 'Type 2 diabetes', TRUE),
    (3, 2, 'I50.9', 'Heart failure', TRUE),
    (4, 2, 'N18.31', 'Chronic kidney disease stage 3', TRUE),
    (5, 3, 'J45.9', 'Asthma', TRUE),
    (6, 4, 'I10', 'Hypertension', TRUE),
    (7, 4, 'E11.9', 'Type 2 diabetes', TRUE),
    (8, 5, 'E78.5', 'Hyperlipidemia', TRUE),
    (9, 6, 'J44.9', 'Chronic lung disease', TRUE),
    (10, 6, 'I50.9', 'Heart failure', TRUE),
    (11, 6, 'N18.31', 'Chronic kidney disease stage 3', TRUE),
    (12, 7, 'F32.9', 'Depressive disorder', TRUE),
    (13, 8, 'I10', 'Hypertension', TRUE),
    (14, 9, 'E11.9', 'Type 2 diabetes', TRUE),
    (15, 9, 'J44.9', 'Chronic lung disease', TRUE),
    (16, 10, 'I10', 'Hypertension', TRUE),
    (17, 10, 'E11.9', 'Type 2 diabetes', TRUE),
    (18, 10, 'N18.31', 'Chronic kidney disease stage 3', TRUE),
    (19, 12, 'J45.9', 'Asthma', TRUE),
    (20, 13, 'I50.9', 'Heart failure', TRUE),
    (21, 15, 'I10', 'Hypertension', TRUE);
