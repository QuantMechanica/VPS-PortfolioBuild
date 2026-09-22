from __future__ import annotations

from tools.strategy_farm import q09_calendar_pin as pin


def test_successor_pin_is_versioned_and_parent_preserving() -> None:
    binding = pin.payload_binding()

    assert binding["schema"] == "qm.q09-calendar-pin-contract/v2"
    assert binding["bundle_id"] == "q09cal-20150101-20260809-3d44f107363359bb"
    assert binding["content_sha256"] == (
        "7a3243cf14d3ac6786423a48dd50317eed155d9c5360ba1067c55355f9618522"
    )
    assert binding["parent_bundle_id"] != binding["bundle_id"]
    assert binding["publication_reason"] == "APPROVED_CORRECTION"
    assert binding["historical_contracts_preserved"] is True
    assert binding["requalification_required_for_parent_bound_rows"] is True
    assert pin.MANIFEST_PATH.parent.name == pin.BUNDLE_ID
    assert pin.COMMON_RELATIVE_PATH.endswith(f"/{pin.BUNDLE_ID}/events.csv")
