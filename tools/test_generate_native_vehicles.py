import json
import unittest

import generate_native_vehicles as generator


class NativeVehicleGeneratorTests(unittest.TestCase):
    def test_pinned_source_is_complete_and_unique(self):
        source = json.loads(generator.SOURCE_PATH.read_text(encoding="utf-8"))
        models = generator.load_source()
        self.assertEqual(len(models), 921)
        self.assertEqual(len({model["model"] for model in models}), 921)
        self.assertEqual(source["commit"], generator.SOURCE_COMMIT)
        self.assertEqual(source["sha256"], generator.SOURCE_SHA256)
        self.assertEqual({model["classId"] for model in models}, set(range(23)))

    def test_normalizes_native_class_type_and_dlc(self):
        model = generator.normalize_model(
            {
                "Name": "adder",
                "Class": "SUPER",
                "ClassId": 7,
                "Type": "CAR",
                "DlcName": "TitleUpdate",
                "DisplayName": {"English": "Adder"},
                "ManufacturerDisplayName": {"English": "Truffade"},
                "Seats": 2,
            }
        )
        self.assertEqual(
            model,
            {
                "model": "adder",
                "name": "Adder",
                "brand": "Truffade",
                "class": "super",
                "type": "automobile",
                "seats": 2,
                "classId": 7,
                "dlc": "TitleUpdate",
                "sourceType": "CAR",
            },
        )

    def test_rejects_class_type_and_model_mismatches(self):
        base = {
            "Name": "adder",
            "Class": "SUPER",
            "ClassId": 7,
            "Type": "CAR",
            "DlcName": "TitleUpdate",
            "DisplayName": {},
            "ManufacturerDisplayName": {},
        }
        with self.assertRaisesRegex(ValueError, "class/class id mismatch"):
            generator.normalize_model({**base, "ClassId": 6})
        with self.assertRaisesRegex(ValueError, "unsupported vehicle type"):
            generator.normalize_model({**base, "Type": "UNKNOWN"})
        with self.assertRaisesRegex(ValueError, "invalid model name"):
            generator.normalize_model({**base, "Name": "../adder"})

    def test_rejects_duplicate_source_models(self):
        row = {
            "Name": "adder",
            "Class": "SUPER",
            "ClassId": 7,
            "Type": "CAR",
            "DlcName": "TitleUpdate",
            "DisplayName": {},
            "ManufacturerDisplayName": {},
        }
        with self.assertRaisesRegex(ValueError, "duplicate model"):
            generator.normalize_dump([row, row])

    def test_generation_is_deterministic(self):
        models = generator.load_source()
        output = generator.render_lua(models)
        self.assertEqual(output, generator.OUTPUT_PATH.read_text(encoding="utf-8"))
        self.assertIn("b8f9dfaee5139fe372f264df4030506d1450fd8a", output)
        self.assertEqual(output.count("\n\t{ "), 921)


if __name__ == "__main__":
    unittest.main()
