import copy
import unittest
from pathlib import Path

from prop_profile import load_json, validate_profile


TASK_ID = "fe4c4db3-9c70-44f8-b26c-5eb59d0a16d2"
ROOT = Path(__file__).resolve().parents[2]
PROFILE_DIR = ROOT / "docs" / "ops" / "evidence" / f"task_{TASK_ID}"
PROFILE_PATHS = (
    PROFILE_DIR / "mffu_rapid_eod_50k_2026-09-22.json",
    PROFILE_DIR / "tradeify_select_flex_50k_2026-09-22.json",
)


class PropProfileTests(unittest.TestCase):
    def test_committed_profiles_are_structurally_valid_and_non_deployable(self):
        for path in PROFILE_PATHS:
            with self.subTest(path=path.name):
                profile = load_json(path)
                self.assertEqual(validate_profile(profile, TASK_ID), [])
                self.assertFalse(profile["deployment"]["deployable"])
                self.assertTrue(profile["unresolved_operational_requirements"])

    def test_unknown_cannot_be_silently_rewritten_as_null(self):
        profile = load_json(PROFILE_PATHS[0])
        profile["phases"]["payout"]["rules"]["first_request_exact_required_profit_usd"]["value"] = None
        errors = validate_profile(profile, TASK_ID)
        self.assertTrue(any("literal string UNKNOWN" in error for error in errors), errors)

    def test_unresolved_profile_cannot_be_marked_deployable(self):
        profile = load_json(PROFILE_PATHS[1])
        profile["deployment"]["deployable"] = True
        errors = validate_profile(profile, TASK_ID)
        self.assertTrue(any("deployable=false" in error for error in errors), errors)

    def test_source_binding_must_resolve_to_declared_official_source(self):
        profile = copy.deepcopy(load_json(PROFILE_PATHS[1]))
        profile["phases"]["evaluation"]["rules"]["profit_target_usd"]["source_ids"] = ["AFFILIATE_BLOG"]
        errors = validate_profile(profile, TASK_ID)
        self.assertTrue(any("unknown source ids" in error for error in errors), errors)


if __name__ == "__main__":
    unittest.main()
