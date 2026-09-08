
USE DATABASE NIDHI_HEALTHCARE_ANALYTICS;
USE SCHEMA CARE_MANAGEMENT;

/* Confirms that all expected source records were loaded. */
SELECT
    'SOURCE COUNTS' AS test_name,
    IFF(
        (SELECT COUNT(*) FROM PATIENT) = 15
        AND (SELECT COUNT(*) FROM ENCOUNTER) = 35
        AND (SELECT COUNT(*) FROM PATIENT_DIAGNOSIS) = 21,
        'PASS',
        'FAIL'
    ) AS test_status;

/* Confirms that every patient has one final result. */
SELECT
    'ONE RESULT PER PATIENT' AS test_name,
    IFF(
        (SELECT COUNT(*) FROM PATIENT)
            = (SELECT COUNT(*) FROM CARE_MANAGEMENT_RESULT),
        'PASS',
        'FAIL'
    ) AS test_status;

/* Confirms the expected High, Medium, and Low totals. */
WITH EXPECTED AS (
    SELECT
        'High' AS priority_level,
        5 AS expected_count

    UNION ALL

    SELECT
        'Medium',
        6

    UNION ALL

    SELECT
        'Low',
        4
),
ACTUAL AS (
    SELECT
        priority_level,
        COUNT(*) AS actual_count
    FROM CARE_MANAGEMENT_RESULT
    GROUP BY priority_level
)
SELECT
    'PRIORITY DISTRIBUTION: ' || e.priority_level AS test_name,
    IFF(
        e.expected_count = COALESCE(a.actual_count, 0),
        'PASS',
        'FAIL'
    ) AS test_status,
    e.expected_count,
    COALESCE(a.actual_count, 0) AS actual_count
FROM EXPECTED AS e
LEFT JOIN ACTUAL AS a
    ON a.priority_level = e.priority_level;

/* Confirms that Patient 005's older ED visit was excluded. */
SELECT
    'OUT-OF-WINDOW ENCOUNTER EXCLUDED' AS test_name,
    IFF(
        ed_visits_365d = 0,
        'PASS',
        'FAIL'
    ) AS test_status
FROM CARE_MANAGEMENT_RESULT
WHERE patient_id = 5;

/*
The following query should return zero rows.
It checks for encounters without a matching patient.
*/
SELECT
    e.*
FROM ENCOUNTER AS e
LEFT JOIN PATIENT AS p
    ON p.patient_id = e.patient_id
WHERE p.patient_id IS NULL;

/*
The following query should return zero rows.
It checks for unsupported encounter types or negative costs.
*/
SELECT *
FROM ENCOUNTER
WHERE encounter_type NOT IN (
    'ED',
    'Inpatient',
    'Primary Care',
    'Specialist'
)
    OR total_cost < 0;

/*
The following query should return zero rows.
It checks for results that contradict the configured priority rules.
*/
SELECT
    r.*
FROM CARE_MANAGEMENT_RESULT AS r
CROSS JOIN PROJECT_CONFIG AS c
WHERE c.config_id = 1
    AND (
        (
            r.priority_level = 'High'
            AND r.ed_visits_365d < c.high_ed_visit_threshold
            AND r.inpatient_admissions_365d
                < c.high_inpatient_threshold
        )
        OR
        (
            r.priority_level = 'Low'
            AND (
                r.ed_visits_365d >= c.medium_ed_visit_threshold
                OR r.inpatient_admissions_365d
                    >= c.medium_inpatient_threshold
                OR r.chronic_condition_count
                    >= c.medium_chronic_threshold
            )
        )
    );
