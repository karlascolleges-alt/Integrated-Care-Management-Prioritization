"""Generate deterministic synthetic healthcare data for local pipeline testing."""

from __future__ import annotations

import argparse
import csv
import random
from datetime import date, timedelta
from pathlib import Path


INSURANCE_TYPES = ("Commercial", "Medicare", "Medicaid", "Self-pay")
ENCOUNTER_TYPES = ("Outpatient", "ED", "Inpatient")
DIAGNOSES = (
    ("I10", "Essential hypertension", True),
    ("E11.9", "Type 2 diabetes", True),
    ("J45.909", "Asthma", True),
    ("I50.9", "Heart failure", True),
    ("Z00.00", "Routine examination", False),
)


def write_csv(path: Path, fieldnames: list[str], rows: list[dict]) -> None:
    path.parent.mkdir(parents=True, exist_ok=True)
    with path.open("w", newline="", encoding="utf-8") as handle:
        writer = csv.DictWriter(handle, fieldnames=fieldnames)
        writer.writeheader()
        writer.writerows(rows)


def generate_dataset(output_dir: Path, patient_count: int = 2000, seed: int = 42) -> dict[str, int]:
    """Create patients, encounters, and diagnoses using a repeatable random seed."""
    if patient_count < 1:
        raise ValueError("patient_count must be at least 1")
    rng = random.Random(seed)
    end_date = date(2026, 6, 30)
    patients: list[dict] = []
    encounters: list[dict] = []
    diagnoses: list[dict] = []
    encounter_id = 1
    diagnosis_id = 1

    for patient_id in range(1, patient_count + 1):
        patients.append({
            "patient_id": patient_id,
            "patient_name": f"Synthetic Patient {patient_id:04d}",
            "birth_date": (date(1940, 1, 1) + timedelta(days=rng.randint(0, 24000))).isoformat(),
            "insurance_type": rng.choice(INSURANCE_TYPES),
        })
        for _ in range(rng.randint(0, 7)):
            encounter_type = rng.choices(ENCOUNTER_TYPES, weights=(65, 25, 10), k=1)[0]
            encounters.append({
                "encounter_id": encounter_id,
                "patient_id": patient_id,
                "encounter_date": (end_date - timedelta(days=rng.randint(0, 500))).isoformat(),
                "encounter_type": encounter_type,
                "total_cost": f"{rng.uniform(80, 18000):.2f}",
            })
            encounter_id += 1
        for code, name, chronic in rng.sample(DIAGNOSES, k=rng.randint(0, 3)):
            diagnoses.append({
                "patient_diagnosis_id": diagnosis_id,
                "patient_id": patient_id,
                "diagnosis_code": code,
                "diagnosis_name": name,
                "chronic_flag": str(chronic).lower(),
            })
            diagnosis_id += 1

    write_csv(output_dir / "patients.csv", list(patients[0]), patients)
    write_csv(output_dir / "encounters.csv", ["encounter_id", "patient_id", "encounter_date", "encounter_type", "total_cost"], encounters)
    write_csv(output_dir / "diagnoses.csv", ["patient_diagnosis_id", "patient_id", "diagnosis_code", "diagnosis_name", "chronic_flag"], diagnoses)
    return {"patients": len(patients), "encounters": len(encounters), "diagnoses": len(diagnoses)}


if __name__ == "__main__":
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--patients", type=int, default=2000)
    parser.add_argument("--seed", type=int, default=42)
    parser.add_argument("--output", type=Path, default=Path("data/raw"))
    args = parser.parse_args()
    counts = generate_dataset(args.output, args.patients, args.seed)
    print(f"Generated {counts['patients']} patients, {counts['encounters']} encounters, and {counts['diagnoses']} diagnoses.")

