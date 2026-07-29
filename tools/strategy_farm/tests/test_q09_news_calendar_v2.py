import json
import sys
import tempfile
import unittest
from pathlib import Path


REPO = Path(__file__).resolve().parents[3]
sys.path.insert(0, str(REPO / "tools" / "strategy_farm"))

import q09_news_calendar as calendar  # noqa: E402


CSV = """datetime,currency,event_name,impact
2024-02-01 13:30:00,USD,NFP,high
2024-01-01 09:00:00,EUR,CPI,medium
2024-02-01 13:30:00,USD,NFP,high
"""


def write_receipt(path: Path, *, correction: bool = False) -> None:
    receipt = {
        "approved_by": "OWNER",
        "approved_at": "2026-07-29T08:00:00Z",
        "reason": "sealed public calendar publication",
    }
    if correction:
        receipt["correction_reason"] = "approved source correction ticket CAL-17"
    path.write_text(json.dumps(receipt), encoding="utf-8")


class Q09NewsCalendarV2Tests(unittest.TestCase):
    def test_publish_is_content_addressed_immutable_and_idempotent(self) -> None:
        with tempfile.TemporaryDirectory() as temporary:
            root = Path(temporary)
            source = root / "source.csv"
            receipt = root / "receipt.json"
            source.write_text(CSV, encoding="utf-8")
            write_receipt(receipt)
            plan = calendar.build_bundle_plan(
                source_csv=source,
                receipt_path=receipt,
                coverage_from_utc="2020-01-01T00:00:00Z",
                coverage_to_utc="2025-01-01T00:00:00Z",
                publication_reason="INITIAL",
            )
            first = calendar.publish_bundle(plan, root / "bundles")
            self.assertEqual(first["publication_status"], "PUBLISHED")
            self.assertEqual(first["row_count"], 2)
            second = calendar.publish_bundle(plan, root / "bundles")
            self.assertEqual(second["publication_status"], "ALREADY_PRESENT")
            self.assertEqual(first["manifest_sha256"], second["manifest_sha256"])

    def test_hash_mismatch_fails_closed(self) -> None:
        with tempfile.TemporaryDirectory() as temporary:
            root = Path(temporary)
            source = root / "source.csv"
            receipt = root / "receipt.json"
            source.write_text(CSV, encoding="utf-8")
            write_receipt(receipt)
            plan = calendar.build_bundle_plan(
                source_csv=source,
                receipt_path=receipt,
                coverage_from_utc="2020-01-01T00:00:00Z",
                coverage_to_utc="2025-01-01T00:00:00Z",
                publication_reason="INITIAL",
            )
            calendar.publish_bundle(plan, root / "bundles")
            events = root / "bundles" / plan["bundle_id"] / "events.csv"
            events.chmod(0o666)
            events.write_bytes(events.read_bytes() + b"tampered\n")
            with self.assertRaises(calendar.CalendarBundleError):
                calendar.verify_bundle(events.parent)

    def test_new_version_requires_explicit_extension_or_approved_correction(self) -> None:
        with tempfile.TemporaryDirectory() as temporary:
            root = Path(temporary)
            source = root / "source.csv"
            receipt = root / "receipt.json"
            source.write_text(CSV, encoding="utf-8")
            write_receipt(receipt)
            parent_plan = calendar.build_bundle_plan(
                source_csv=source,
                receipt_path=receipt,
                coverage_from_utc="2020-01-01T00:00:00Z",
                coverage_to_utc="2025-01-01T00:00:00Z",
                publication_reason="INITIAL",
            )
            parent = calendar.publish_bundle(parent_plan, root / "bundles")
            parent_manifest = Path(parent["manifest_path"])
            with self.assertRaises(calendar.CalendarBundleError):
                calendar.build_bundle_plan(
                    source_csv=source,
                    receipt_path=receipt,
                    coverage_from_utc="2020-01-01T00:00:00Z",
                    coverage_to_utc="2026-01-01T00:00:00Z",
                    publication_reason="HORIZON_EXTENSION",
                )
            extension = calendar.build_bundle_plan(
                source_csv=source,
                receipt_path=receipt,
                coverage_from_utc="2020-01-01T00:00:00Z",
                coverage_to_utc="2026-01-01T00:00:00Z",
                publication_reason="HORIZON_EXTENSION",
                parent_manifest_path=parent_manifest,
            )
            self.assertNotEqual(extension["bundle_id"], parent_plan["bundle_id"])
            with self.assertRaises(calendar.CalendarBundleError):
                calendar.build_bundle_plan(
                    source_csv=source,
                    receipt_path=receipt,
                    coverage_from_utc="2020-01-01T00:00:00Z",
                    coverage_to_utc="2025-01-01T00:00:00Z",
                    publication_reason="APPROVED_CORRECTION",
                    parent_manifest_path=parent_manifest,
                )
            correction_receipt = root / "correction.json"
            write_receipt(correction_receipt, correction=True)
            corrected = calendar.build_bundle_plan(
                source_csv=source,
                receipt_path=correction_receipt,
                coverage_from_utc="2020-01-01T00:00:00Z",
                coverage_to_utc="2025-01-01T00:00:00Z",
                publication_reason="APPROVED_CORRECTION",
                parent_manifest_path=parent_manifest,
            )
            self.assertEqual(corrected["manifest"]["parent_bundle_id"], parent_plan["bundle_id"])
            self.assertNotEqual(corrected["bundle_id"], parent_plan["bundle_id"])

    def test_common_provisioning_is_hash_verified_and_never_overwrites(self) -> None:
        with tempfile.TemporaryDirectory() as temporary:
            root = Path(temporary)
            source = root / "source.csv"
            receipt = root / "receipt.json"
            source.write_text(CSV, encoding="utf-8")
            write_receipt(receipt)
            plan = calendar.build_bundle_plan(
                source_csv=source,
                receipt_path=receipt,
                coverage_from_utc="2020-01-01T00:00:00Z",
                coverage_to_utc="2025-01-01T00:00:00Z",
                publication_reason="INITIAL",
            )
            calendar.publish_bundle(plan, root / "bundles")
            bundle = root / "bundles" / plan["bundle_id"]
            relative = f"q09_news/{plan['bundle_id']}/events.csv"
            first = calendar.provision_to_common(bundle, root / "common", relative)
            self.assertEqual(first["status"], "PROVISIONED")
            second = calendar.provision_to_common(bundle, root / "common", relative)
            self.assertEqual(second["status"], "ALREADY_PRESENT")
            target = Path(first["path"])
            target.chmod(0o666)
            target.write_text("contradiction", encoding="utf-8")
            with self.assertRaises(calendar.CalendarBundleError):
                calendar.provision_to_common(bundle, root / "common", relative)
            with self.assertRaises(calendar.CalendarBundleError):
                calendar.provision_to_common(bundle, root / "common", "../escape.csv")


if __name__ == "__main__":
    unittest.main()
