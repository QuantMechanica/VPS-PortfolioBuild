"""Universe-expansion Q02 entry gate accepts a config list of OWNER decisions.

2026-09-18: ``enqueue_universe_expansion_q02`` was hard-bound to the single
literal ``OWNER-DEC-13036-XAU``. A later, broader OWNER authorization (Fable
full executive authority, 2026-09-17) could not use this exact-row path without
either forging the older id or duplicating the whole function. The gate now
checks membership in ``UNIVERSE_EXPANSION_ACCEPTED_OWNER_DECISIONS``.

These tests exercise only the decision-id gate, which is the first check in
the function and returns before any farm-DB connection is opened, so `root`
is a bare tmp_path and no state-mutating call is made.
"""
from pathlib import Path

from tools.strategy_farm import farmctl


def _call(tmp_path: Path, owner_decision: str) -> dict:
    return farmctl.enqueue_universe_expansion_q02(
        tmp_path,
        "QM5_1",
        target_symbol="EURUSD.DWX",
        target_timeframe="H1",
        target_setfile=str(tmp_path / "missing.set"),
        native_pass_work_item_id="native-1",
        owner_decision=owner_decision,
        expected_current_ex5_sha256="0" * 64,
    )


def test_rejects_an_owner_decision_outside_the_accepted_list(tmp_path: Path) -> None:
    result = _call(tmp_path, "OWNER-DEC-NOT-ACCEPTED")

    assert result["enqueued"] is False
    assert result["reason"] == "universe_expansion_owner_decision_mismatch"
    assert result["expected"] == list(farmctl.UNIVERSE_EXPANSION_ACCEPTED_OWNER_DECISIONS)
    assert result["actual"] == "OWNER-DEC-NOT-ACCEPTED"


def test_every_configured_owner_decision_clears_the_gate(tmp_path: Path) -> None:
    for owner_decision in farmctl.UNIVERSE_EXPANSION_ACCEPTED_OWNER_DECISIONS:
        result = _call(tmp_path, owner_decision)
        # Whatever this refuses on next (QM5_1 has no built EA artifact in this
        # sandbox) is unrelated to this ticket; only the decision gate matters.
        assert result["enqueued"] is False
        assert result["reason"] != "universe_expansion_owner_decision_mismatch"


def test_accepted_list_contains_the_original_and_the_fable_authority_decision() -> None:
    assert farmctl.UNIVERSE_EXPANSION_OWNER_DECISION == "OWNER-DEC-13036-XAU"
    assert farmctl.UNIVERSE_EXPANSION_OWNER_DECISION in farmctl.UNIVERSE_EXPANSION_ACCEPTED_OWNER_DECISIONS
    assert (
        "OWNER-DEC-FABLE-FULL-EXECUTIVE-AUTHORITY-20260917"
        in farmctl.UNIVERSE_EXPANSION_ACCEPTED_OWNER_DECISIONS
    )
