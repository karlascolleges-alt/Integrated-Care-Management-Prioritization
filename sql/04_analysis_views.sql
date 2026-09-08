/* Creates reusable views for patient review and summary reporting. */

USE DATABASE NIDHI_HEALTHCARE_ANALYTICS;
USE SCHEMA CARE_MANAGEMENT;

CREATE OR REPLACE VIEW VW_PATIENT_PRIORITY_QUEUE AS
SELECT
    r.analysis_date,
    p.patient_id,
    p.patient_name,
    p.insurance_type,
    DATEDIFF(
        'year',
        p.birth_date,
        r.analysis_date
    ) AS approximate_age,
    r.total_encounters_365d,
    r.ed_visits_365d,
    r.inpatient_admissions_365d,
    r.chronic_condition_count,
    r.total_cost_365d,
    r.last_encounter_date,
    r.priority_level,
    r.priority_reason,
    r.recommendation
FROM CARE_MANAGEMENT_RESULT AS r
INNER JOIN PATIENT AS p
    ON p.patient_id = r.patient_id;

CREATE OR REPLACE VIEW VW_PRIORITY_SUMMARY AS
SELECT
    analysis_date,
    priority_level,
    COUNT(*) AS patient_count,
    ROUND(
        AVG(total_encounters_365d),
        2
    ) AS average_encounters,
    ROUND(
        SUM(total_cost_365d),
        2
    ) AS total_cost
FROM CARE_MANAGEMENT_RESULT
GROUP BY
    analysis_date,
    priority_level;

/* Displays the patient review queue. */
SELECT *
FROM VW_PATIENT_PRIORITY_QUEUE
ORDER BY
    CASE priority_level
        WHEN 'High' THEN 1
        WHEN 'Medium' THEN 2
        ELSE 3
    END,
    ed_visits_365d DESC,
    patient_id;

/* Displays the priority summary. */
SELECT *
FROM VW_PRIORITY_SUMMARY
ORDER BY
    CASE priority_level
        WHEN 'High' THEN 1
        WHEN 'Medium' THEN 2
        ELSE 3
    END;

/* Traces one patient from the encounter records to the final result. */
SELECT
    p.patient_name,
    e.encounter_date,
    e.encounter_type,
    e.total_cost,
    r.priority_level,
    r.priority_reason
FROM PATIENT AS p
LEFT JOIN ENCOUNTER AS e
    ON e.patient_id = p.patient_id
INNER JOIN CARE_MANAGEMENT_RESULT AS r
    ON r.patient_id = p.patient_id
WHERE p.patient_id = 1
ORDER BY e.encounter_date;
