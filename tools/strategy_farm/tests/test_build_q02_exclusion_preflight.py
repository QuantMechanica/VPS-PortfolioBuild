from __future__ import annotations

import json
import sys
from pathlib import Path
from unittest import mock


HERE = Path(__file__).resolve().parent
sys.path.insert(0, str(HERE.parent))

import farmctl  # noqa: E402


def _write_card(
    root: Path,
    *,
    ea_id: str,
    target_symbols: str,
    expected_trades: int,
) -> Path:
    cards = root / "artifacts" / "cards_approved"
    cards.mkdir(parents=True, exist_ok=True)
    card = cards / f"{ea_id}_claim-preflight.md"
    card.write_text(
        f"""---
ea_id: {ea_id}
slug: claim-preflight
source_id: Q02-EXCLUSION-PREFLIGHT-TEST
target_symbols: [{target_symbols}]
g0_status: APPROVED
r1_track_record: PASS
r2_mechanical: PASS
r3_data_available: PASS
r4_ml_forbidden: PASS
expected_trades_per_year_per_symbol: {expected_trades}
---

# Build claim preflight fixture

## Entry
Enter on the H1 close when the fixed signal is positive.

## Exit
Exit on the next H1 close.

## Stop Loss
One fixed ATR stop.

## Position Sizing
Use fixed risk sizing.

| Kriterium | Status | Begründung |
|---|---|---|
| R1 Track Record | PASS | source lineage |
| R2 Mechanical | PASS | deterministic |
| R3 Data Available | PASS | declared DWX symbols |
| R4 ML Forbidden | PASS | no ML |
""",
        encoding="utf-8",
    )
    return card


def _task_row(ea_id: str, card: Path) -> dict[str, str]:
    return {
        "id": f"task-{ea_id}",
        "kind": "build_ea",
        "status": "pending",
        "card_id": ea_id,
        "payload_json": json.dumps({"ea_id": ea_id, "card_path": str(card)}),
    }


def test_file_listed_build_row_is_refused_with_q02_excluded(tmp_path: Path) -> None:
    root = tmp_path / "farm"
    card = _write_card(
        root,
        ea_id="QM5_99010",
        target_symbols="XAUUSD.DWX",
        expected_trades=12,
    )
    exclusion_file = root / "state" / "requeue_excluded_eas.txt"
    exclusion_file.parent.mkdir(parents=True)
    exclusion_file.write_text("QM5_99010\n", encoding="utf-8")

    with mock.patch.object(
        farmctl,
        "load_requeue_excluded_eas",
        return_value=farmctl.load_requeue_excluded_eas(exclusion_file),
    ):
        guard = farmctl._build_task_claim_guard(root, _task_row("QM5_99010", card))

    assert guard["claimable"] is False
    assert guard["code"] == "Q02_EXCLUDED"
    assert guard["q02_exclusion_sources"] == ["requeue_excluded_eas"]


def test_fx_only_card_over_100_is_refused_but_non_excluded_card_is_unaffected(
    tmp_path: Path,
) -> None:
    root = tmp_path / "farm"
    excluded = _write_card(
        root,
        ea_id="QM5_99011",
        target_symbols="EURUSD.DWX, USDJPY.DWX",
        expected_trades=101,
    )
    allowed = _write_card(
        root,
        ea_id="QM5_99012",
        target_symbols="XAUUSD.DWX",
        expected_trades=101,
    )

    excluded_guard = farmctl._build_task_claim_guard(
        root,
        _task_row("QM5_99011", excluded),
    )
    allowed_guard = farmctl._build_task_claim_guard(
        root,
        _task_row("QM5_99012", allowed),
    )

    assert excluded_guard["claimable"] is False
    assert excluded_guard["code"] == "Q02_EXCLUDED"
    assert excluded_guard["q02_exclusion_sources"] == ["fx_only_expected_trades_gt_100"]
    assert allowed_guard["claimable"] is True
    assert allowed_guard["code"] == "eligible"


def test_explicit_override_allows_policy_owner_path(tmp_path: Path) -> None:
    root = tmp_path / "farm"
    card = _write_card(
        root,
        ea_id="QM5_99013",
        target_symbols="GBPUSD.DWX",
        expected_trades=200,
    )

    guard = farmctl._build_task_claim_guard(
        root,
        _task_row("QM5_99013", card),
        allow_q02_excluded=True,
    )

    assert guard["claimable"] is True
    assert guard["code"] == "eligible_q02_exclusion_override"
    assert guard["q02_exclusion_sources"] == ["fx_only_expected_trades_gt_100"]
