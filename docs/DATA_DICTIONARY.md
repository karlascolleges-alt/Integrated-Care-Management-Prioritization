# Data Dictionary

This document explains the purpose and structure of the tables used in the patient care management pipeline.

## Source and Configuration Tables

### `PROJECT_CONFIG`

This table stores the analysis period and the thresholds used to assign patient review priorities.

Grain: one configuration record.

| Column | Meaning |
|---|---|
| `config_id` | Unique configuration identifier |
| `analysis_start_date` | First encounter date included in the analysis |
| `analysis_end_date` | Last encounter date included in the analysis |
| `high_ed_visit_threshold` | ED visit count that produces High priority |
| `high_inpatient_threshold` | Inpatient admission count that produces High priority |
| `medium_ed_visit_threshold` | ED visit count that produces Medium priority |
| `medium_inpatient_threshold` | Inpatient admission count that produces Medium priority |
| `medium_chronic_threshold` | Chronic condition count that produces Medium priority |
| `config_description` | Description of the configuration rules |

### `PATIENT`

This table contains one record for each synthetic patient.

Grain: one patient.

| Column | Meaning |
|---|---|
| `patient_id` | Unique patient identifier |
| `patient_name` | Synthetic patient label |
| `birth_date` | Synthetic patient birth date |
| `insurance_type` | Synthetic insurance category |

### `ENCOUNTER`

This table contains healthcare encounters for the synthetic patients.

Grain: one patient encounter.

| Column | Meaning |
|---|---|
| `encounter_id` | Unique encounter identifier |
| `patient_id` | Patient associated with the encounter |
| `encounter_date` | Date of the encounter |
| `encounter_type` | ED, inpatient, primary care, or specialist encounter |
| `total_cost` | Synthetic encounter cost used for demonstration |

The `total_cost` values are synthetic and do not represent claim payments or financial forecasts.

### `PATIENT_DIAGNOSIS`

This table contains diagnosis records for the synthetic patients.

Grain: one diagnosis record for one patient.

| Column | Meaning |
|---|---|
| `patient_diagnosis_id` | Unique diagnosis record identifier |
| `patient_id` | Patient associated with the diagnosis |
| `diagnosis_code` | Demonstration diagnosis code |
| `diagnosis_name` | Diagnosis description |
| `chronic_flag` | Indicates whether the diagnosis is treated as chronic in the sample data |

The `chronic_flag` is provided by the sample data and is not inferred by the SQL pipeline.

## Output Tables

### `CARE_MANAGEMENT_RESULT`

This table contains the final patient level priority results.

Grain: one patient for one analysis end date.

| Column | Meaning |
|---|---|
| `patient_id` | Patient included in the result |
| `analysis_date` | Analysis end date |
| `total_encounters_365d` | Total encounters included in the analysis period |
| `ed_visits_365d` | Included encounters with an ED encounter type |
| `inpatient_admissions_365d` | Included encounters with an inpatient encounter type |
| `chronic_condition_count` | Number of diagnosis records marked as chronic |
| `total_cost_365d` | Sum of included synthetic encounter costs |
| `last_encounter_date` | Most recent encounter included in the analysis |
| `priority_level` | Assigned High, Medium, or Low review priority |
| `priority_reason` | Rule responsible for the assigned priority |
| `recommendation` | Suggested human review action |

### `ANALYSIS_RUN_AUDIT`

This table stores a summary of each completed analysis run.

Grain: one completed analysis date.

| Column | Meaning |
|---|---|
| `analysis_date` | Date associated with the analysis |
| `config_id` | Configuration used for the analysis |
| `result_count` | Total number of patient results |
| `high_priority_count` | Number of High priority patients |
| `medium_priority_count` | Number of Medium priority patients |
| `low_priority_count` | Number of Low priority patients |
| `created_at` | Timestamp showing when the audit record was created |
