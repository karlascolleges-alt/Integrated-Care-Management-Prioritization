import csv
import unittest
from collections import Counter
from pathlib import Path


ROOT = Path(__file__).resolve().parents[1]


class ExpectedOutputTests(unittest.TestCase):
    def test_queue_has_one_row_per_patient(self):
        path = ROOT / "sample_output" / "patient_priority_queue.csv"

        with path.open(newline="", encoding="utf-8") as handle:
            rows = list(csv.DictReader(handle))

        self.assertEqual(len(rows), 15)
        self.assertEqual(
            len({row["patient_id"] for row in rows}),
            15
        )
        self.assertEqual(
            Counter(row["priority_level"] for row in rows),
            Counter({"High": 5, "Medium": 6, "Low": 4})
        )

    def test_old_ed_visit_is_excluded(self):
        path = ROOT / "sample_output" / "patient_priority_queue.csv"

        with path.open(newline="", encoding="utf-8") as handle:
            rows = {
                row["patient_id"]: row
                for row in csv.DictReader(handle)
            }

        self.assertEqual(
            rows["5"]["ed_visits_365d"],
            "0"
        )


if __name__ == "__main__":
    unittest.main()
