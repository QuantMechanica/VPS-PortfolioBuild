from __future__ import annotations

import json
import re
from pathlib import Path


ROOT = Path(__file__).resolve().parents[3]
EA_DIR = ROOT / "framework" / "EAs" / "QM5_41001_keith-fitschen-aberration-trading-system"
SOURCE = EA_DIR / "QM5_41001_keith-fitschen-aberration-trading-system.mq5"
SPEC = EA_DIR / "SPEC.md"
BUILD_RESULT = ROOT / "artifacts" / "qm5_41001_build_result.json"


def _source() -> str:
    return SOURCE.read_text(encoding="utf-8")


def test_card_execution_and_open_ended_exit_are_wired() -> None:
    source = _source()

    assert "const double max_price_deviation = 3.0 * tick_size;" in source
    assert "QM_EntryConfigure(qm_ea_id," in source
    assert "entry_deviation_points" in source
    assert "req.tp = 0.0;" in source
    assert "strategy_tp_rr_mult" not in source


def test_management_precedes_entry_only_filters() -> None:
    on_tick = _source().split("void OnTick()", 1)[1]

    assert on_tick.index("Strategy_ManageOpenPosition();") < on_tick.index(
        "if(Strategy_NoTradeFilter())"
    )
    assert on_tick.index("if(Strategy_NoTradeFilter())") < on_tick.index(
        "if(!QM_IsNewBar())"
    )


def test_each_declared_strategy_input_has_a_use_site() -> None:
    source = _source()
    names = re.findall(
        r"^input\s+[A-Za-z_][A-Za-z0-9_<>]*\s+(strategy_[A-Za-z0-9_]+)\s*=",
        source,
        flags=re.MULTILINE,
    )

    assert names
    assert all(len(re.findall(rf"\b{re.escape(name)}\b", source)) >= 2 for name in names)


def test_spec_matches_open_ended_source_contract() -> None:
    spec = SPEC.read_text(encoding="utf-8")

    assert "There is no fixed take-profit" in spec
    assert "three symbol trade ticks" in spec
    assert "strategy_tp_rr_mult" not in spec
    assert "EA_RISK_SIZER_UNCONFIGURED" in spec
    assert "EA_INPUT_RISK_MODE_MISMATCH" not in spec


def test_deferred_smoke_has_durable_capacity_evidence() -> None:
    result = json.loads(BUILD_RESULT.read_text(encoding="utf-8"))
    capacity = result["smoke_capacity_evidence"]

    assert result["smoke_result"] == "deferred_p2_smoke"
    assert "8 active work_items" in result["blocked_reason"]
    assert capacity["state_db_uri"].endswith("?mode=ro")
    assert capacity["active_work_items"] == 8
    assert capacity["smoke_launched"] is False
    assert capacity["backtest_enqueued"] is False
