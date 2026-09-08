"""Validate synthetic inputs and create a local care-management queue."""

from __future__ import annotations

import argparse
import csv
import json
import logging
from collections import defaultdict
from datetime import date, datetime
from pathlib import Path


LOGGER = logging.getLogger("care_management_pipeline")
REQUIRED_COLUMNS = {
    "patients.csv": {"patient_id", "patient_name", "birth_date", "insurance_type"},
    "encounters.csv": {"encounter_id", "patient_id", "encounter_date", "encounter_type", "total_cost"},
    "diagnoses.csv": {"patient_diagnosis_id", "patient_id", "diagnosis_code", "diagnosis_name", "chronic_flag"},
}


def read_csv(path: Path) -> list[dict[str, str]]:
    if not path.exists():
        raise FileNotFoundError(f"Required input file is missing: {path}")
    with path.open(newline="", encoding="utf-8") as handle:
        reader = csv.DictReader(handle)
        missing = REQUIRED_COLUMNS[path.name] - set(reader.fieldnames or [])
        if missing:
            raise ValueError(f"{path.name} is missing required columns: {sorted(missing)}")
        return list(reader)


def load_config(path: Path) -> dict:
    with path.open(encoding="utf-8") as handle:
        config = json.load(handle)
    if date.fromisoformat(config["analysis_start_date"]) > date.fromisoformat(config["analysis_end_date"]):
        raise ValueError("analysis_start_date must be on or before analysis_end_date")
    return config


def classify(features: dict, config: dict) -> tuple[str, str, str]:
    if features["ed_visits_365d"] >= config["high_ed_visit_threshold"]:
        return "High", "3+ emergency-department visits", "Priority care-manager review"
    if features["inpatient_admissions_365d"] >= config["high_inpatient_threshold"]:
        return "High", "2+ inpatient admissions", "Priority care-manager review"
    if features["ed_visits_365d"] >= config["medium_ed_visit_threshold"]:
        return "Medium", "1+ emergency-department visit", "Routine outreach and needs review"
    if features["inpatient_admissions_365d"] >= config["medium_inpatient_threshold"]:
        return "Medium", "1+ inpatient admission", "Routine outreach and needs review"
    if features["chronic_condition_count"] >= config["medium_chronic_threshold"]:
        return "Medium", "2+ chronic conditions", "Routine outreach and needs review"
    return "Low", "No review threshold met", "Continue routine monitoring"


def build_queue(input_dir: Path, config_path: Path) -> list[dict]:
    config = load_config(config_path)
    start = date.fromisoformat(config["analysis_start_date"])
    end = date.fromisoformat(config["analysis_end_date"])
    patients = read_csv(input_dir / "patients.csv")
    encounters = read_csv(input_dir / "encounters.csv")
    diagnoses = read_csv(input_dir / "diagnoses.csv")
    patient_ids = {row["patient_id"] for row in patients}
    if len(patient_ids) != len(patients):
        raise ValueError("patients.csv contains duplicate patient_id values")

    encounter_seen: set[str] = set()
    summaries = defaultdict(lambda: {"total": 0, "ed": 0, "inpatient": 0, "cost": 0.0, "last": None})
    rejected = 0
    for row in encounters:
        if row["encounter_id"] in encounter_seen:
            continue
        encounter_seen.add(row["encounter_id"])
        if row["patient_id"] not in patient_ids or row["encounter_type"] not in {"Outpatient", "ED", "Inpatient"}:
            rejected += 1
            continue
        encounter_date = date.fromisoformat(row["encounter_date"])
        if not start <= encounter_date <= end:
            continue
        summary = summaries[row["patient_id"]]
        summary["total"] += 1
        summary["ed"] += int(row["encounter_type"] == "ED")
        summary["inpatient"] += int(row["encounter_type"] == "Inpatient")
        summary["cost"] += float(row["total_cost"])
        summary["last"] = encounter_date if summary["last"] is None else max(summary["last"], encounter_date)

    chronic_codes: dict[str, set[str]] = defaultdict(set)
    for row in diagnoses:
        if row["patient_id"] in patient_ids and row["chronic_flag"].lower() == "true":
            chronic_codes[row["patient_id"]].add(row["diagnosis_code"])

    queue: list[dict] = []
    for patient in patients:
        patient_id = patient["patient_id"]
        summary = summaries[patient_id]
        features = {
            "ed_visits_365d": summary["ed"],
            "inpatient_admissions_365d": summary["inpatient"],
            "chronic_condition_count": len(chronic_codes[patient_id]),
        }
        priority, reason, recommendation = classify(features, config)
        queue.append({
            "patient_id": patient_id,
            "total_encounters_365d": summary["total"],
            **features,
            "total_cost_365d": f"{summary['cost']:.2f}",
            "last_encounter_date": summary["last"].isoformat() if summary["last"] else "",
            "priority_level": priority,
            "priority_reason": reason,
            "recommendation": recommendation,
        })
    LOGGER.info("Processed %s patients; rejected %s invalid encounter rows", len(queue), rejected)
    return queue


def write_queue(rows: list[dict], output_path: Path) -> None:
    if not rows:
        raise ValueError("The pipeline produced no rows")
    output_path.parent.mkdir(parents=True, exist_ok=True)
    with output_path.open("w", newline="", encoding="utf-8") as handle:
        writer = csv.DictWriter(handle, fieldnames=list(rows[0]))
        writer.writeheader()
        writer.writerows(rows)


def configure_logging(log_path: Path) -> None:
    log_path.parent.mkdir(parents=True, exist_ok=True)
    logging.basicConfig(level=logging.INFO, format="%(asctime)s %(levelname)s %(message)s", handlers=[logging.FileHandler(log_path, encoding="utf-8"), logging.StreamHandler()])


if __name__ == "__main__":
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--input", type=Path, default=Path("data/raw"))
    parser.add_argument("--config", type=Path, default=Path("config/pipeline_config.json"))
    parser.add_argument("--output", type=Path, default=Path("data/processed/patient_priority_queue.csv"))
    args = parser.parse_args()
    configure_logging(Path("logs") / f"pipeline_{datetime.now():%Y%m%d_%H%M%S}.log")
    results = build_queue(args.input, args.config)
    write_queue(results, args.output)
    print(f"Wrote {len(results)} patient records to {args.output}")

