#!/usr/bin/env python3
"""Active immutable calendar pin for newly sealed Q09/Q10 news work.

The pin is a versioned evaluation-input contract.  Historical plans and
verdicts retain the bundle recorded in their own manifests; only plans sealed
after this contract is activated use the successor below.
"""

from __future__ import annotations

from pathlib import Path
from typing import Any


CONTRACT_SCHEMA = "qm.q09-calendar-pin-contract/v2"
BUNDLE_ID = "q09cal-20150101-20260809-3d44f107363359bb"
CONTENT_SHA256 = "7a3243cf14d3ac6786423a48dd50317eed155d9c5360ba1067c55355f9618522"
MANIFEST_SHA256 = "50e16cfbb8ebdf56093cbae8f05d0972f666c257c8034bd6cdcb393e679c2015"
PARENT_BUNDLE_ID = "q09cal-20150101-20260809-0bb19b5bb9790b76"
PARENT_CONTENT_SHA256 = (
    "86b2c0b595fd6011a2fe64b7da07f933e755294136a16f584d75389b66c56ce1"
)
PUBLICATION_REASON = "APPROVED_CORRECTION"
DECISION_ID = "FABLE-DEC-NEWS-ARCHIVE-DST-CORRECTION-20260922"
HYPOTHESIS = (
    "Correcting the 82 proven one-hour-early USD releases removes false "
    "blackout timing without changing any Q10 selection threshold."
)

BUNDLE_ROOT = Path(r"D:\QM\data\news_calendar\q09_bundles")
MANIFEST_PATH = BUNDLE_ROOT / BUNDLE_ID / "manifest.json"
COMMON_RELATIVE_PATH = f"QM/q09_news/{BUNDLE_ID}/events.csv"


def payload_binding() -> dict[str, Any]:
    """Return the immutable contract marker stamped on newly created rows."""

    return {
        "schema": CONTRACT_SCHEMA,
        "decision_id": DECISION_ID,
        "bundle_id": BUNDLE_ID,
        "content_sha256": CONTENT_SHA256,
        "manifest_sha256": MANIFEST_SHA256,
        "parent_bundle_id": PARENT_BUNDLE_ID,
        "parent_content_sha256": PARENT_CONTENT_SHA256,
        "publication_reason": PUBLICATION_REASON,
        "hypothesis": HYPOTHESIS,
        "historical_contracts_preserved": True,
        "requalification_required_for_parent_bound_rows": True,
    }
