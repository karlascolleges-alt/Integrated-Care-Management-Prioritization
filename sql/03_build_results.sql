/* Builds a reproducible patient level review list from the configured window. */

USE DATABASE NIDHI_HEALTHCARE_ANALYTICS;
USE SCHEMA CARE_MANAGEMENT;

DELETE FROM CARE_MANAGEMENT_RESULT
WHERE analysis_date = (
    SELECT analysis_end_date
    FROM PROJECT_CONFIG
    WHERE config_id = 1
);

INSERT INTO CARE_MANAGEMENT_RESULT (
    patient_id,
    analysis_date,
    total_encounters_365d,
    ed_visits_365d,
    inpatient_admissions_365d,
    chronic_condition_count,
    total_cost_365d,
    last_encounter_date,
    priority_level,
    priority_reason,
    recommendation
)
WITH CONFIG AS (
    SELECT *
    FROM PROJECT_CONFIG
    WHERE config_id = 1
),
ENCOUNTER_SUMMARY AS (
    SELECT
        p.patient_id,
        COUNT(e.encounter_id) AS total_encounters_365d,
        COALESCE(COUNT_IF(e.encounter_type = 'ED'), 0) AS ed_visits_365d,
        COALESCE(COUNT_IF(e.encounter_type = 'Inpatient'), 0)
            AS inpatient_admissions_365d,
        COALESCE(SUM(e.total_cost), 0) AS total_cost_365d,
        MAX(e.encounter_date) AS last_encounter_date
    FROM PATIENT AS p
    CROSS JOIN CONFIG AS c
    LEFT JOIN ENCOUNTER AS e
        ON e.patient_id = p.patient_id
        AND e.encounter_date BETWEEN c.analysis_start_date
        AND c.analysis_end_date
    GROUP BY p.patient_id
),
DIAGNOSIS_SUMMARY AS (
    SELECT
        p.patient_id,
        COALESCE(
            COUNT_IF(d.chronic_flag = TRUE),
            0
        ) AS chronic_condition_count
    FROM PATIENT AS p
    LEFT JOIN PATIENT_DIAGNOSIS AS d
        ON d.patient_id = p.patient_id
    GROUP BY p.patient_id
),
PATIENT_FEATURES AS (
    SELECT
        e.patient_id,
        c.analysis_end_date AS analysis_date,
        e.total_encounters_365d,
        e.ed_visits_365d,
        e.inpatient_admissions_365d,
        d.chronic_condition_count,
        e.total_cost_365d,
        e.last_encounter_date,
        CASE
            WHEN e.ed_visits_365d >= c.high_ed_visit_threshold
                OR e.inpatient_admissions_365d
                    >= c.high_inpatient_threshold
                THEN 'High'
            WHEN e.ed_visits_365d >= c.medium_ed_visit_threshold
                OR e.inpatient_admissions_365d
                    >= c.medium_inpatient_threshold
                OR d.chronic_condition_count
                    >= c.medium_chronic_threshold
                THEN 'Medium'
            ELSE 'Low'
        END AS priority_level,
        CASE
            WHEN e.ed_visits_365d >= c.high_ed_visit_threshold
                THEN '3+ emergency-department visits'
            WHEN e.inpatient_admissions_365d
                >= c.high_inpatient_threshold
                THEN '2+ inpatient admissions'
            WHEN e.ed_visits_365d >= c.medium_ed_visit_threshold
                THEN '1+ emergency-department visit'
            WHEN e.inpatient_admissions_365d
                >= c.medium_inpatient_threshold
                THEN '1+ inpatient admission'
            WHEN d.chronic_condition_count
                >= c.medium_chronic_threshold
                THEN '2+ chronic conditions'
            ELSE 'No review threshold met'
        END AS priority_reason
    FROM ENCOUNTER_SUMMARY AS e
    INNER JOIN DIAGNOSIS_SUMMARY AS d
        ON d.patient_id = e.patient_id
    CROSS JOIN CONFIG AS c
)
SELECT
    patient_id,
    analysis_date,
    total_encounters_365d,
    ed_visits_365d,
    inpatient_admissions_365d,
    chronic_condition_count,
    total_cost_365d,
    last_encounter_date,
    priority_level,
    priority_reason,
    CASE
        WHEN priority_level = 'High'
            THEN 'Priority care-manager review'
        WHEN priority_level = 'Medium'
            THEN 'Routine outreach and needs review'
        ELSE 'Continue routine monitoring'
    END AS recommendation
FROM PATIENT_FEATURES;

DELETE FROM ANALYSIS_RUN_AUDIT
WHERE analysis_date = (
    SELECT analysis_end_date
    FROM PROJECT_CONFIG
    WHERE config_id = 1
);

INSERT INTO ANALYSIS_RUN_AUDIT (
    analysis_date,
    config_id,
    result_count,
    high_priority_count,
    medium_priority_count,
    low_priority_count
)
SELECT
    r.analysis_date,
    1 AS config_id,
    COUNT(*) AS result_count,
    COUNT_IF(r.priority_level = 'High') AS high_priority_count,
    COUNT_IF(r.priority_level = 'Medium') AS medium_priority_count,
    COUNT_IF(r.priority_level = 'Low') AS low_priority_count
FROM CARE_MANAGEMENT_RESULT AS r
WHERE r.analysis_date = (
    SELECT analysis_end_date
    FROM PROJECT_CONFIG
    WHERE config_id = 1
)
GROUP BY r.analysis_date;
