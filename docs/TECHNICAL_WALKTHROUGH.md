# Technical Walkthrough

This document explains how I designed the patient care management pipeline and the reasoning behind its main SQL decisions.

## 1. Define What Each Row Represents

I started by defining the grain of each table:

- `PATIENT` contains one row per patient.
- `ENCOUNTER` contains one row per hospital or outpatient visit.
- `PATIENT_DIAGNOSIS` contains one row per recorded diagnosis.
- `CARE_MANAGEMENT_RESULT` contains one row per patient for each analysis date.

Defining the grain helped me determine how the tables should be joined and prevented incorrect patient counts.

## 2. Store Rules Separately

I stored the analysis dates and priority thresholds in `PROJECT_CONFIG`.

This allows the dates or thresholds to be changed without rewriting the main transformation query. It also makes the rules easier to find, review, and test.

## 3. Aggregate Before Joining

Patients can have multiple encounters and multiple diagnoses. Joining both detailed tables directly could multiply the records.

For example, a patient with three encounters and two diagnoses could produce six joined rows. This could incorrectly increase the patient’s encounter counts and total costs.

I prevented this by creating two separate summaries:

- `ENCOUNTER_SUMMARY` calculates encounter counts, ED visits, inpatient admissions, total cost, and the latest encounter date.
- `DIAGNOSIS_SUMMARY` calculates the number of chronic conditions.

Each summary first produces one row per patient. I then join those patient level summaries using `patient_id`.

## 4. Keep Every Patient in the Analysis

I used the `PATIENT` table as the starting point and connected encounters with a `LEFT JOIN`.

This keeps patients in the final result even when they have no encounters during the selected analysis period.

I placed the encounter date condition inside the join:

```sql
LEFT JOIN ENCOUNTER AS e
    ON e.patient_id = p.patient_id
    AND e.encounter_date BETWEEN c.analysis_start_date
    AND c.analysis_end_date
```

Placing the date condition inside the join limits the encounters being counted without removing patients who have no matching encounters.

## 5. Calculate Patient Measures

I used Snowflake’s `COUNT_IF` function to count specific encounter types:

```sql
COUNT_IF(e.encounter_type = 'ED')
```

```sql
COUNT_IF(e.encounter_type = 'Inpatient')
```

I also calculated:

- Total encounters
- Chronic condition count
- Total synthetic encounter cost
- Most recent encounter date

`COALESCE` converts missing numerical totals to zero when a patient has no matching records.

## 6. Assign Priorities Transparently

I used a `CASE` expression that checks the High priority rules before the Medium priority rules.

A patient receives High priority when they have:

- At least three ED visits, or
- At least two inpatient admissions

A patient who does not meet a High rule receives Medium priority when they have:

- At least one ED visit, or
- At least one inpatient admission, or
- At least two chronic conditions

All remaining patients receive Low priority.

I used a second `CASE` expression to create `priority_reason`. This shows the rule responsible for each patient’s classification.

## 7. Create Reusable Views

I created two views:

- `VW_PATIENT_PRIORITY_QUEUE` provides detailed results for patient review.
- `VW_PRIORITY_SUMMARY` provides the number of patients in each priority category.

The detailed view includes utilization counts, chronic condition counts, total cost, the latest encounter date, the assigned priority, and the reason for that priority.

## 8. Record Each Run

The result table includes `analysis_date`, allowing results to be associated with a specific analysis period.

`ANALYSIS_RUN_AUDIT` records:

- Total patient results
- High priority count
- Medium priority count
- Low priority count
- The configuration used for the analysis

This provides a simple record of what each analysis run produced.

## 9. Validate the Results

The final SQL file checks:

- The expected number of source records
- One final result for every patient
- The expected priority distribution
- Exclusion of an encounter outside the analysis period
- Encounters without a matching patient
- Invalid encounter types
- Negative costs
- Results that contradict the configured priority rules

The first validation queries return `PASS` or `FAIL`. The exception queries should return zero rows.

## Tradeoffs and Limitations

- The priority rules are easy to understand, but they do not predict a patient’s clinical needs.
- The synthetic dataset is useful for testing and explaining the logic, but it is not large enough for performance benchmarking.
- `CREATE OR REPLACE` makes the project easy to rerun, but it should not be used on tables containing important production data.
- The output is intended to support human review rather than make automatic care decisions.
# Technical Walkthrough

## Local Python companion pipeline

The local workflow complements the Snowflake implementation without pretending to replace it. It makes the project runnable without cloud credentials and lets the continuous-integration workflow exercise the same major business rules.

### Synthetic data generation

`pipeline/generate_data.py` creates three normalized CSV sources: patients, encounters, and diagnoses. A fixed random seed makes the generated data reproducible, which means a failed test can be investigated against the same records. The default run creates 2,000 patients, while the record count can be changed from the command line.

### Validation and transformation

`pipeline/run_pipeline.py` performs the following steps:

1. Confirms that every required file and column exists.
2. Rejects duplicate patient identifiers because the final grain requires one row per patient.
3. Deduplicates encounters by encounter identifier.
4. Rejects encounters with orphaned patient identifiers or unsupported encounter types.
5. Excludes encounters outside the configured analysis window.
6. Aggregates encounters and chronic diagnoses separately to avoid join inflation.
7. Applies the same ordered High, Medium, and Low priority rules used by the SQL pipeline.
8. Writes one explainable result for each patient.

Thresholds and analysis dates live in `config/pipeline_config.json`. Keeping them outside the Python functions makes rule changes easier to review and test.

### Dashboard

`app/dashboard.py` opens the reference queue by default and accepts a newly generated queue through the sidebar. It presents record counts, estimated utilization cost, priority distribution, reason distribution, a filterable table, and a patient-level explanation. It is a review interface, not a clinical recommendation engine.

### Automated checks

The original tests continue to confirm the 15-row reference results. The added tests verify reproducible generation, all three priority levels, one-row-per-patient output, and an end-to-end 50-patient run. GitHub Actions also exercises a temporary 100-patient run after parsing the Snowflake SQL.
