import csv
import json
import tempfile
import unittest
from pathlib import Path

from pipeline.generate_data import generate_dataset
from pipeline.run_pipeline import build_queue, classify, write_queue


ROOT = Path(__file__).resolve().parents[1]


class LocalPipelineTests(unittest.TestCase):
    def test_generator_is_reproducible(self):
        with tempfile.TemporaryDirectory() as first, tempfile.TemporaryDirectory() as second:
            first_counts = generate_dataset(Path(first), patient_count=25, seed=7)
            generate_dataset(Path(second), patient_count=25, seed=7)
            self.assertEqual(first_counts["patients"], 25)
            self.assertEqual((Path(first) / "patients.csv").read_bytes(), (Path(second) / "patients.csv").read_bytes())

    def test_priority_rules_cover_each_level(self):
        config = json.loads((ROOT / "config" / "pipeline_config.json").read_text())
        self.assertEqual(classify({"ed_visits_365d": 3, "inpatient_admissions_365d": 0, "chronic_condition_count": 0}, config)[0], "High")
        self.assertEqual(classify({"ed_visits_365d": 0, "inpatient_admissions_365d": 0, "chronic_condition_count": 2}, config)[0], "Medium")
        self.assertEqual(classify({"ed_visits_365d": 0, "inpatient_admissions_365d": 0, "chronic_condition_count": 1}, config)[0], "Low")

    def test_pipeline_returns_one_result_per_patient(self):
        with tempfile.TemporaryDirectory() as directory:
            raw = Path(directory) / "raw"
            output = Path(directory) / "queue.csv"
            generate_dataset(raw, patient_count=50, seed=12)
            rows = build_queue(raw, ROOT / "config" / "pipeline_config.json")
            write_queue(rows, output)
            with output.open(newline="", encoding="utf-8") as handle:
                saved = list(csv.DictReader(handle))
            self.assertEqual(len(saved), 50)
            self.assertEqual(len({row["patient_id"] for row in saved}), 50)
            self.assertTrue({row["priority_level"] for row in saved} <= {"High", "Medium", "Low"})


if __name__ == "__main__":
    unittest.main()

