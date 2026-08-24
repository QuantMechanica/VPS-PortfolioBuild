from __future__ import annotations

import csv
import hashlib
import json
import re
from pathlib import Path


REPO = Path(__file__).resolve().parents[3]
LABEL = "QM5_9932_bandy-roc-zscore-normalised-mr-index"
EA_DIR = REPO / "framework" / "EAs" / LABEL
SOURCE = EA_DIR / f"{LABEL}.mq5"
SPEC = EA_DIR / "SPEC.md"
CARD = EA_DIR / "docs" / "strategy_card.md"
SETS = EA_DIR / "sets"
MAGIC_REGISTRY = REPO / "framework" / "registry" / "magic_numbers.csv"

AUTHORIZED_SYMBOL_SLOTS = {
    "NDX.DWX": "1",
    "SP500.DWX": "2",
    "WS30.DWX": "4",
}

STRATEGY_INPUTS = (
    "strategy_roc_period",
    "strategy_zscore_lookback",
    "strategy_entry_z",
    "strategy_exit_z",
    "strategy_regime_sma_period",
    "strategy_atr_period",
    "strategy_atr_stop_mult",
    "strategy_time_stop_bars",
    "strategy_min_stdev",
    "strategy_warmup_bars",
)


def _executable_source() -> str:
    source = SOURCE.read_text(encoding="utf-8")
    source = re.sub(r"/\*.*?\*/", "", source, flags=re.DOTALL)
    return re.sub(r"//[^\r\n]*", "", source)


def _set_values(path: Path) -> dict[str, str]:
    values: dict[str, str] = {}
    for raw in path.read_text(encoding="utf-8-sig").splitlines():
        line = raw.strip()
        if line and not line.startswith(";") and "=" in line:
            key, value = line.split("=", 1)
            values[key.strip()] = value.strip()
    return values


def test_approved_card_and_spec_bind_exact_d1_index_universe() -> None:
    card = CARD.read_text(encoding="utf-8")
    spec = SPEC.read_text(encoding="utf-8")

    assert "g0_status: APPROVED" in card
    target_section = card.split("## Target symbols", 1)[1].split("## Concepts", 1)[0]
    assert set(re.findall(r"\b([A-Z0-9]+\.DWX)\b", target_section)) == set(
        AUTHORIZED_SYMBOL_SLOTS
    )
    spec_universe = spec.split("## 3. Symbol Universe", 1)[1].split("## 4. Timeframe", 1)[0]
    assert set(re.findall(r"`([A-Z0-9]+\.DWX)`", spec_universe)) == set(
        AUTHORIZED_SYMBOL_SLOTS
    )
    assert "| Base timeframe | `D1` |" in spec


def test_card_mechanism_and_every_strategy_input_are_executable() -> None:
    source = _executable_source()
    names = re.findall(r"(?m)^\s*input\s+\w+\s+(strategy_[A-Za-z0-9_]+)\s*=", source)

    assert tuple(names) == STRATEGY_INPUTS
    for name in names:
        assert len(re.findall(rf"\b{re.escape(name)}\b", source)) >= 2, name

    assert "100.0 * (recent_close - earlier_close) / earlier_close" in source
    assert "(roc_series[0] - mean) / stdev" in source
    assert "zscore > strategy_entry_z" in source
    assert "closed_price <= regime_sma" in source
    assert "zscore >= strategy_exit_z" in source
    assert "held_bars >= strategy_time_stop_bars" in source
    assert "QM_StopATRFromValue" in source
    assert "req.type               = QM_BUY" in source
    assert "req.type               = QM_SELL" not in source


def test_framework_magic_risk_mae_buffer_and_performance_contracts() -> None:
    source = SOURCE.read_text(encoding="utf-8")

    assert "#include <QM/QM_Common.mqh>" in source
    assert "QM_FrameworkTrackOpenPositionMae();" in source
    assert "input double RISK_PERCENT               = 0.0;" in source
    assert "input double RISK_FIXED                 = 1000.0;" in source
    assert "QM_FrameworkMagic()" in source
    assert "qm_ea_id * 10000" not in source
    assert "ArraySize(rates) < bars_needed" in source
    assert "ArraySize(roc_series) < strategy_zscore_lookback" in source
    assert not re.search(r"\b(?:tensorflow|torch|sklearn|keras|onnx)\b", source, re.I)

    for line in source.splitlines():
        if re.search(r"\b(?:iBars|CopyRates)\s*\(", line):
            assert "// perf-allowed" in line, line


def test_only_card_authorized_setfiles_are_delivered_at_fixed_backtest_risk() -> None:
    setfiles = sorted(SETS.glob("*_backtest.set"))
    symbols = {
        path.name.split(f"{LABEL}_", 1)[1].split("_D1_backtest.set", 1)[0]
        for path in setfiles
    }
    assert symbols == set(AUTHORIZED_SYMBOL_SLOTS)

    for path in setfiles:
        symbol = path.name.split(f"{LABEL}_", 1)[1].split("_D1_backtest.set", 1)[0]
        values = _set_values(path)
        assert values["qm_ea_id"] == "9932"
        assert values["qm_magic_slot_offset"] == AUTHORIZED_SYMBOL_SLOTS[symbol]
        assert values["RISK_FIXED"] == "1000"
        assert values["RISK_PERCENT"] == "0"
        assert all(name in values for name in STRATEGY_INPUTS)
        assert (
            "; build_hash:   20553e4da0339eb9a8d5a949a230b67c5980cd7957bcdf607f6700613e970a34"
            in path.read_text(encoding="utf-8-sig")
        )

    with MAGIC_REGISTRY.open(newline="", encoding="utf-8-sig") as handle:
        active_rows = {
            (row["symbol"], row["symbol_slot"], row["magic"])
            for row in csv.DictReader(handle)
            if row["ea_id"] == "9932" and row["status"] == "active"
        }
    for symbol, slot in AUTHORIZED_SYMBOL_SLOTS.items():
        assert (symbol, slot, str(99320000 + int(slot))) in active_rows


def test_truthful_build_identity_binds_exact_repaired_source_and_binary() -> None:
    result = json.loads((EA_DIR / "build_result.json").read_text(encoding="utf-8"))
    identity = json.loads((EA_DIR / "build_identity.json").read_text(encoding="utf-8"))

    assert result["task_id"] == "c71f308a-76be-456f-8ae7-a5d7c3abc4e0"
    assert result["rework_task_id"] == "1db5da1a-e87a-486f-a6f6-2224724a09fe"
    assert result["symbols_delivered"] == sorted(AUTHORIZED_SYMBOL_SLOTS)
    assert result["build_check_passed"] is False
    assert result["compile_succeeded"] is True
    assert result["isolated_compile"]["result"] == "0 errors, 0 warnings"
    assert identity["build_check_failure_class"] == "LIVE_FACTORY_AD_HOC_COMPILE_REFUSED"
    assert identity["mq5_sha256"] == result["mq5_sha256"]
    assert identity["ex5_sha256"] == result["ex5_sha256"]
    assert hashlib.sha256(SOURCE.read_bytes()).hexdigest() == result["mq5_sha256"]
    assert hashlib.sha256((EA_DIR / f"{LABEL}.ex5").read_bytes()).hexdigest() == result[
        "ex5_sha256"
    ]
    assert hashlib.sha256(SPEC.read_bytes()).hexdigest() == identity["spec_md_sha256"]
    assert hashlib.sha256(CARD.read_bytes()).hexdigest() == identity["strategy_card_sha256"]
    for symbol, expected_hash in identity["setfile_sha256"].items():
        setfile = SETS / f"{LABEL}_{symbol}_D1_backtest.set"
        assert hashlib.sha256(setfile.read_bytes()).hexdigest() == expected_hash
