from __future__ import annotations

import csv
import re
from pathlib import Path

from tools.strategy_farm import build_gate_hardening as gate


REPO = Path(__file__).resolve().parents[3]
LABEL = "QM5_12940_bressert-cycle-trigger-line-h4-card"
EA_DIR = REPO / "framework" / "EAs" / LABEL
EA = EA_DIR / f"{LABEL}.mq5"
MAGIC_REGISTRY = REPO / "framework" / "registry" / "magic_numbers.csv"
MAGIC_RESOLVER = REPO / "framework" / "include" / "QM" / "QM_MagicResolver.mqh"


def _source() -> str:
    return EA.read_text(encoding="utf-8")


def _executable_source() -> str:
    source = _source()
    source = re.sub(r"/\*.*?\*/", "", source, flags=re.DOTALL)
    return re.sub(r"//[^\r\n]*", "", source)


def _compact(value: str) -> str:
    return "".join(value.split())


def _function_slice(source: str, start: str, end: str) -> str:
    return source[source.index(start) : source.index(end)]


def _set_values(path: Path) -> dict[str, str]:
    values: dict[str, str] = {}
    for raw_line in path.read_text(encoding="utf-8-sig").splitlines():
        line = raw_line.strip()
        if not line or line.startswith(";") or "=" not in line:
            continue
        key, value = line.split("=", 1)
        values[key.strip()] = value.strip()
    return values


def test_every_declared_strategy_input_has_an_executable_use_site() -> None:
    source = _executable_source()
    names = re.findall(r"\binput\s+\w+\s+(strategy_[A-Za-z0-9_]+)\s*=", source)

    assert names
    assert len(names) == len(set(names))
    unused = [name for name in names if len(re.findall(rf"\b{re.escape(name)}\b", source)) < 2]
    assert unused == []


def test_cooldown_is_consumed_only_after_an_accepted_entry() -> None:
    source = _executable_source()
    entry_hook = _function_slice(
        source,
        "bool Strategy_EntrySignal",
        "bool Strategy_RebuildTradeState",
    )
    on_tick = _compact(_function_slice(source, "void OnTick", "void OnTimer"))

    assert "g_bars_since_last_long = 0" not in entry_hook
    assert "g_bars_since_last_short = 0" not in entry_hook
    accepted = "if(QM_TM_OpenPosition(req,ticket)){"
    assert accepted in on_tick
    accepted_body = on_tick[on_tick.index(accepted) :]
    assert accepted_body.index("g_bars_since_last_long=0;") > accepted_body.index(accepted)
    assert accepted_body.index("g_bars_since_last_short=0;") > accepted_body.index(accepted)


def test_partial_close_success_is_the_only_t1_activation_path() -> None:
    source = _compact(_executable_source())
    success_gate = (
        "if(QM_TM_PartialClose(ticket,half_vol,QM_EXIT_PARTIAL))"
        "g_trade_state.t1_hit=true;"
    )

    assert source.count(success_gate) == 2
    assert "QM_TM_NormalizeVolume(_Symbol,current_vol*0.5)" in source
    assert "if(g_trade_state.t1_hit)" in source


def test_t1_and_partial_state_are_reconstructed_from_durable_trade_history() -> None:
    source = _source()

    for required in (
        "Strategy_EntryComment",
        "Strategy_ParseT1Comment",
        "POSITION_COMMENT",
        "POSITION_IDENTIFIER",
        "HistorySelectByPosition",
        "DEAL_COMMENT",
        "ORDER_COMMENT",
        "DEAL_ENTRY_OUT",
        "initial_volume",
        "closing_volume",
    ):
        assert required in source
    assert "g_trade_state.t1_price = g_long_t1" not in source
    assert "g_trade_state.t1_price = g_short_t1" not in source


def test_indicator_buffers_have_runtime_arraysize_proofs() -> None:
    raw = _source()
    parsed = gate.SourceFile(
        path=EA,
        raw=raw,
        code=gate.strip_comments_preserve_lines(raw),
    )

    assert gate.check_indicator_buffer_bounds(parsed) == []
    assert "rawk_len > ArraySize(rawk)" in raw
    assert "rawk2_len > ArraySize(rawk2)" in raw
    assert "k1_count > ArraySize(k1)" in raw
    assert "s >= ArraySize(k1)" in raw


def test_framework_risk_magic_and_management_order_remain_conformant() -> None:
    source = _executable_source()
    on_tick = _compact(_function_slice(source, "void OnTick", "void OnTimer"))

    assert "#include <QM/QM_Common.mqh>" in source
    assert "input double RISK_PERCENT" in source
    assert "input double RISK_FIXED" in source
    assert "QM_FrameworkInit(qm_ea_id,qm_magic_slot_offset,RISK_PERCENT,RISK_FIXED" in _compact(source)
    assert "QM_FrameworkMagic()" in source
    assert "qm_ea_id * 10000" not in source
    assert on_tick.index("QM_FrameworkTrackOpenPositionMae();") < on_tick.index(
        "Strategy_ManageOpenPosition();"
    )
    assert on_tick.index("Strategy_ManageOpenPosition();") < on_tick.index(
        "if(Strategy_NoTradeFilter())return;"
    )
    assert gate.check_duplicate_new_bar_entry_gate(
        gate.SourceFile(path=EA, raw=source, code=gate.strip_comments_preserve_lines(source))
    ) == []


def test_registered_slots_and_backtest_setfiles_are_unchanged_and_fixed_risk() -> None:
    with MAGIC_REGISTRY.open(newline="", encoding="utf-8-sig") as handle:
        rows = [row for row in csv.DictReader(handle) if row["ea_id"] == "12940"]

    assert len(rows) == 13
    assert {row["status"] for row in rows} == {"active"}
    assert {int(row["symbol_slot"]) for row in rows} == set(range(13))
    assert {int(row["magic"]) for row in rows} == set(range(129400000, 129400013))
    assert "129400000" in MAGIC_RESOLVER.read_text(encoding="utf-8")

    setfiles = sorted((EA_DIR / "sets").glob("*_backtest.set"))
    assert len(setfiles) == 13
    for setfile in setfiles:
        values = _set_values(setfile)
        assert float(values["RISK_FIXED"]) == 1000.0
        assert float(values["RISK_PERCENT"]) == 0.0
