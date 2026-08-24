from __future__ import annotations

import csv
import hashlib
import re
from pathlib import Path


REPO = Path(__file__).resolve().parents[3]
EA_DIR = REPO / "framework" / "EAs" / "QM5_40008_aqr-value-and-momentum-everywhere"
SOURCE = EA_DIR / "QM5_40008_aqr-value-and-momentum-everywhere.mq5"
CARD = REPO / "strategy-seeds" / "cards" / "approved" / "QM5_40008_aqr-value-and-momentum-everywhere.md"
SETS = EA_DIR / "sets"
MAGIC_REGISTRY = REPO / "framework" / "registry" / "magic_numbers.csv"

EXPECTED_SLOTS = {
    0: ("SP500.DWX", 400080000),
    1: ("NDX.DWX", 400080001),
    2: ("XTIUSD.DWX", 400080002),
    3: ("EURUSD.DWX", 400080003),
}

STRATEGY_INPUTS = (
    "strategy_daily_loss_halt_pct",
    "strategy_daily_hard_stop_pct",
    "strategy_total_dd_stop_pct",
    "strategy_signal_tf",
    "InpMomDays",
    "InpValDays",
    "InpSMAPeriod",
    "InpScoreThresholdLong",
    "InpScoreThresholdShort",
    "InpATRPeriod",
    "InpATRMultiplier",
    "InpSpreadATRMult",
    "strategy_rollover_start_hhmm",
    "strategy_rollover_end_hhmm",
    "strategy_max_slippage_ticks",
)


def _set_values(path: Path) -> dict[str, str]:
    values: dict[str, str] = {}
    for raw in path.read_text(encoding="utf-8-sig").splitlines():
        line = raw.strip()
        if not line or line.startswith(";") or "=" not in line:
            continue
        key, value = line.split("=", 1)
        values[key.strip()] = value.strip()
    return values


def test_approved_identity_and_card_mechanic_are_bound() -> None:
    card = CARD.read_text(encoding="utf-8-sig")
    assert re.search(r"(?m)^ea_id:\s*QM5_40008\s*$", card)
    assert re.search(r"(?m)^slug:\s*aqr-value-and-momentum-everywhere\s*$", card)
    assert re.search(r"(?m)^g0_status:\s*APPROVED\s*$", card)
    assert "0.50 \\times \\text{Rank}(M_t) + 0.50 \\times \\text{Rank}(V_t)" in card
    assert "Slippage Tolerance**: Max 3.0 ticks" in card


def test_source_is_card_faithful_and_framework_managed() -> None:
    source = SOURCE.read_text(encoding="utf-8-sig")

    for symbol in ("SP500.DWX", "NDX.DWX", "XTIUSD.DWX", "EURUSD.DWX"):
        assert f'"{symbol}"' in source
    assert "0.50 * norm_rank_m + 0.50 * norm_rank_v" in source
    assert "valid_count != UNIVERSE_SIZE" in source
    assert "req.tp     = 0.0" in source
    assert "QM_IsNewCalendarPeriod(PERIOD_MN1, _Symbol)" in source
    assert "QM_CalendarPeriodKey(PERIOD_MN1, _Symbol, 0)" in source
    assert "QM_EntryConfigure(qm_ea_id" in source
    assert "strategy_max_slippage_ticks * tick_size / point" in source
    assert "QM_KillSwitchInit(qm_ea_id, QM_FrameworkMagic(), strategy_daily_hard_stop_pct, strategy_total_dd_stop_pct" in source
    assert "QM_FrameworkTrackOpenPositionMae();" in source
    assert "QM_Magic(" not in source  # framework magic is resolver-backed; no local formula
    assert "OrderSend(" not in source
    assert not re.search(r"\b(tensorflow|torch|sklearn|keras|onnx)\b", source, re.IGNORECASE)
    assert "IsNewQuarter(const datetime" not in source

    gate = source.index("if(!QM_IsNewBar(_Symbol, strategy_signal_tf))")
    assert gate < source.index("AdvanceState_OnNewBar();", gate)
    assert gate < source.index("Strategy_ExitSignal()", gate)


def test_every_declared_strategy_input_has_code_and_setfile_use_sites() -> None:
    source = SOURCE.read_text(encoding="utf-8-sig")
    declared = set(
        re.findall(
            r"(?m)^input\s+(?:ENUM_TIMEFRAMES|int|double)\s+([A-Za-z_]\w*)\s*=",
            source,
        )
    )
    assert set(STRATEGY_INPUTS) <= declared

    for name in STRATEGY_INPUTS:
        assert len(re.findall(rf"\b{re.escape(name)}\b", source)) >= 2, name

    for path in sorted(SETS.glob("*.set")):
        values = _set_values(path)
        for name in STRATEGY_INPUTS:
            assert name in values, f"{path.name}: missing {name}"


def test_raw_series_exceptions_are_explicitly_closed_bar_scoped() -> None:
    source = SOURCE.read_text(encoding="utf-8-sig")
    for number, line in enumerate(source.splitlines(), start=1):
        if re.search(r"\b(?:iBars|iClose|CopyRates)\s*\(", line):
            assert "perf-allowed" in line, f"raw series call lacks exception at line {number}"


def test_magic_registry_matches_the_exact_four_asset_universe() -> None:
    with MAGIC_REGISTRY.open(encoding="utf-8-sig", newline="") as handle:
        rows = [
            row
            for row in csv.DictReader(handle)
            if row["ea_id"] == "40008" and row["status"].lower() == "active"
        ]
    actual = {
        int(row["symbol_slot"]): (row["symbol"], int(row["magic"]))
        for row in rows
    }
    assert actual == EXPECTED_SLOTS


def test_backtest_sets_bind_source_hash_fixed_risk_and_slots() -> None:
    source_hash = hashlib.sha256(SOURCE.read_bytes()).hexdigest()
    paths = sorted(SETS.glob("*.set"))
    assert len(paths) == len(EXPECTED_SLOTS)

    for slot, (symbol, _magic) in EXPECTED_SLOTS.items():
        path = SETS / f"QM5_40008_aqr-value-and-momentum-everywhere_{symbol}_D1_backtest.set"
        assert path in paths
        text = path.read_text(encoding="utf-8-sig")
        values = _set_values(path)
        assert f"; build_hash:   {source_hash}" in text
        assert values["qm_ea_id"] == "40008"
        assert values["qm_magic_slot_offset"] == str(slot)
        assert float(values["RISK_FIXED"]) > 0.0
        assert float(values["RISK_PERCENT"]) == 0.0
        assert values["strategy_max_slippage_ticks"] == "3"
