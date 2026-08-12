from __future__ import annotations

import json
import sys
from pathlib import Path
from unittest import mock


HERE = Path(__file__).resolve().parent
sys.path.insert(0, str(HERE.parent))

import farmctl  # noqa: E402


def _card_text(
    *,
    ea_id: str = "QM5_99001",
    slug: str = "mnt012-guard",
    g0: str = "APPROVED",
    fm_r3: str = "PASS",
    body_r3: str = "PASS",
) -> str:
    return f"""---
ea_id: {ea_id}
slug: {slug}
source_id: MNT012-TEST-SOURCE
target_symbols: [EURUSD.DWX]
g0_status: {g0}
r1_track_record: PASS
r2_mechanical: PASS
r3_data_available: {fm_r3}
r4_ml_forbidden: PASS
expected_trades_per_year_per_symbol: 12
---

# MNT-012 guard card

## Entry
Enter on the H1 close when the fixed signal is positive.

## Exit
Exit on the next H1 close.

## Stop Loss
One fixed ATR stop.

## Position Sizing
Fixed fractional risk sizing.

| Kriterium | Status | Begründung |
|---|---|---|
| R1 Track Record | PASS | source lineage |
| R2 Mechanical | PASS | deterministic |
| R3 Data Available | {body_r3} | explicit data gate |
| R4 ML Forbidden | PASS | no ML |
"""


def _write_approved_card(root: Path, **kwargs: str) -> Path:
    cards = root / "artifacts" / "cards_approved"
    cards.mkdir(parents=True, exist_ok=True)
    ea_id = kwargs.get("ea_id", "QM5_99001")
    slug = kwargs.get("slug", "mnt012-guard")
    path = cards / f"{ea_id}_{slug}.md"
    path.write_text(_card_text(**kwargs), encoding="utf-8")
    return path


def _task_row(task_id: str, card_path: Path | str, **payload_updates: object) -> dict[str, str]:
    payload: dict[str, object] = {
        "ea_id": "QM5_99001",
        "card_path": str(card_path),
    }
    payload.update(payload_updates)
    return {
        "id": task_id,
        "kind": "build_ea",
        "status": "pending",
        "card_id": "QM5_99001",
        "payload_json": json.dumps(payload),
    }


def test_pending_payload_blocked_reason_is_not_claimable() -> None:
    guard = farmctl._build_task_claim_guard(
        None,
        _task_row("blocked-reason", "unused.md", blocked_reason="r3_missing"),
        require_card=False,
    )

    assert guard["claimable"] is False
    assert guard["code"] == "active_blocked_reason"


def test_pending_payload_blocked_at_with_last_reason_matches_zombie_shape() -> None:
    guard = farmctl._build_task_claim_guard(
        None,
        _task_row(
            "blocked-at",
            "unused.md",
            blocked_at_utc="2026-07-25T11:49:18+00:00",
            last_blocked_reason="r3_missing_lumber_and_ief_dwx_series",
        ),
        require_card=False,
    )

    assert guard["claimable"] is False
    assert guard["code"] == "active_blocked_at_utc"
    assert "r3_missing_lumber_and_ief_dwx_series" in guard["reason"]


def test_last_blocked_reason_without_active_marker_remains_retryable(tmp_path: Path) -> None:
    root = tmp_path / "farm"
    card = _write_approved_card(root)
    guard = farmctl._build_task_claim_guard(
        root,
        _task_row("retry", card, last_blocked_reason="codex_review_fail"),
    )

    assert guard["claimable"] is True
    assert guard["code"] == "eligible"


def test_frontmatter_pass_body_r3_unknown_is_fail_closed(tmp_path: Path) -> None:
    root = tmp_path / "farm"
    card = _write_approved_card(root, body_r3="UNKNOWN")
    fm = farmctl.parse_card_frontmatter(card)

    consistency = farmctl.strategy_card_r_gate_consistency(card, fm)

    assert consistency["ok"] is False
    assert "r3_data_available_body_not_PASS:UNKNOWN" in consistency["errors"]
    assert any("r3_data_available_frontmatter_body_mismatch" in item for item in consistency["errors"])
    assert farmctl._card_r_gate_ready(fm, card) is False
    assert farmctl._build_task_claim_guard(root, _task_row("contradiction", card))["claimable"] is False


def test_matching_pass_body_and_frontmatter_are_claimable(tmp_path: Path) -> None:
    root = tmp_path / "farm"
    card = _write_approved_card(root)
    fm = farmctl.parse_card_frontmatter(card)

    consistency = farmctl.strategy_card_r_gate_consistency(card, fm)

    assert consistency["ok"] is True
    assert farmctl._card_r_gate_ready(fm, card) is True
    assert farmctl._build_task_claim_guard(root, _task_row("ready", card))["claimable"] is True


def test_prebuild_reports_body_frontmatter_r3_conflict(tmp_path: Path) -> None:
    root = tmp_path / "farm"
    card = _write_approved_card(root, body_r3="UNKNOWN")

    result = farmctl.prebuild_validate_card(root, card, farmctl.parse_card_frontmatter(card))

    assert result["ok"] is False
    assert "r3_data_available_body_not_PASS:UNKNOWN" in result["errors"]


def test_approve_rejects_r3_conflict_without_mutating_card(tmp_path: Path) -> None:
    root = tmp_path / "farm"
    draft_dir = root / "artifacts" / "cards_draft"
    draft_dir.mkdir(parents=True)
    card = draft_dir / "QM5_99001_mnt012-guard.md"
    card.write_text(_card_text(g0="PENDING", body_r3="UNKNOWN"), encoding="utf-8")
    before = card.read_bytes()

    result = farmctl.approve_card(root, str(card), "test approval")

    assert result["approved"] is False
    assert result["reason"] == "r_gate_body_frontmatter_conflict"
    assert card.read_bytes() == before
    assert not (root / "artifacts" / "cards_approved" / card.name).exists()


def test_claude_selector_excludes_active_block_marker(tmp_path: Path) -> None:
    root = tmp_path / "farm"
    card = _write_approved_card(root)
    ready = _task_row("ready", card)
    blocked = _task_row(
        "blocked",
        card,
        blocked_at_utc="2026-07-25T11:49:18+00:00",
        last_blocked_reason="r3_missing",
    )

    candidates = farmctl._claude_buildable_pending_rows([blocked, ready], root=root)

    assert [row["id"] for row in candidates] == ["ready"]


def test_spawn_wrapper_rejects_marker_before_claim_or_spawn(tmp_path: Path) -> None:
    root = tmp_path / "farm"
    row = _task_row(
        "blocked",
        "unused.md",
        blocked_at_utc="2026-07-25T11:49:18+00:00",
        last_blocked_reason="r3_missing",
    )
    spawn_fn = mock.Mock(return_value={"spawned": True})

    result = farmctl._spawn_with_build_dispatch_claim(
        root,
        row,
        agent="codex",
        spawn_fn=spawn_fn,
    )

    assert result["spawned"] is False
    assert result["reason"] == "build_task_not_claimable:active_blocked_at_utc"
    spawn_fn.assert_not_called()
    assert not (root / "state" / "build_dispatch_claims").exists()


def test_record_build_result_rejects_pending_active_block_marker(tmp_path: Path) -> None:
    root = tmp_path / "farm"
    farmctl.init_db(root)
    now = farmctl.utc_now()
    payload = {
        "ea_id": "QM5_99001",
        "blocked_at_utc": "2026-07-25T11:49:18+00:00",
        "last_blocked_reason": "r3_missing",
    }
    with farmctl.connect(root) as conn:
        conn.execute(
            """
            INSERT INTO tasks(id, kind, status, source_id, card_id, payload_json, created_at, updated_at)
            VALUES ('blocked-result', 'build_ea', 'pending', NULL, 'QM5_99001', ?, ?, ?)
            """,
            (json.dumps(payload), now, now),
        )
        conn.commit()
    result_file = tmp_path / "result.json"
    result_file.write_text(
        json.dumps({"task_id": "blocked-result", "ea_id": "QM5_99001"}),
        encoding="utf-8",
    )

    result = farmctl.record_build_result(root, "blocked-result", str(result_file))

    assert result["recorded"] is False
    assert result["reason"] == "build_task_not_recordable:active_blocked_at_utc"
    with farmctl.connect(root) as conn:
        row = conn.execute("SELECT status, payload_json FROM tasks WHERE id='blocked-result'").fetchone()
    assert row["status"] == "pending"
    assert json.loads(row["payload_json"]) == payload
