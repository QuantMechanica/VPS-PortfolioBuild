from __future__ import annotations

from pathlib import Path


ROOT = Path(__file__).resolve().parents[3]
EA_DIR = ROOT / "framework" / "EAs" / "QM5_20012_xauxag-cmtar"
SOURCE = EA_DIR / "QM5_20012_xauxag-cmtar.mq5"
SETFILE = (
    EA_DIR
    / "sets"
    / "QM5_20012_xauxag-cmtar_QM5_20012_XAU_XAG_CMTAR_D1_D1_backtest.set"
)


def _function_body(source: str, signature: str) -> str:
    start = source.index(signature)
    opening = source.index("{", start)
    depth = 0
    for index in range(opening, len(source)):
        if source[index] == "{":
            depth += 1
        elif source[index] == "}":
            depth -= 1
            if depth == 0:
                return source[opening + 1 : index]
    raise AssertionError(f"unterminated function: {signature}")


def test_qm5_20012_routes_only_the_off_chart_leg_through_basket_helper() -> None:
    source = SOURCE.read_text(encoding="utf-8")
    foreign = _function_body(source, "bool Strategy_OpenForeignLeg(")
    prepare = _function_body(source, "bool Strategy_PreparePair(")
    entry = _function_body(source, "bool Strategy_EntrySignal(")
    on_tick = _function_body(source, "void OnTick()")

    assert source.count("QM_BasketOpenPosition(") == 1
    assert "symbol == _Symbol" in foreign
    assert "symbol != g_leg_xag" in foreign
    assert "slot != 1" in foreign
    assert "QM_BasketOpenPosition(qm_ea_id" in foreign

    assert "Strategy_ResolveHostRisk(" in prepare
    assert "host_req.symbol_slot = 0" in prepare
    assert "return Strategy_OpenForeignLeg(g_leg_xag" in prepare
    assert "QM_TM_OpenPosition(" not in prepare
    assert "return Strategy_PreparePair(g_signal_pair_direction, req);" in entry

    assert "QM_TM_OpenPosition(req, out_ticket, 0," in on_tick
    assert "g_host_risk_mode, g_host_risk_value" in on_tick
    assert "!host_opened || !Strategy_PairCompositionValid()" in on_tick
    assert "!Strategy_PairHedgeValid()" in on_tick
    assert "Strategy_ClosePair(QM_EXIT_STRATEGY);" in on_tick
    assert "g_host_risk_mode = QM_RISK_MODE_UNSET;" in on_tick
    assert "g_host_risk_value = 0.0;" in on_tick


def test_qm5_20012_host_risk_share_round_trips_to_joint_sized_lots() -> None:
    source = SOURCE.read_text(encoding="utf-8")
    resolver = _function_body(source, "bool Strategy_ResolveHostRisk(")

    assert "RISK_FIXED > 0.0 && RISK_PERCENT <= 0.0" in resolver
    assert "RISK_PERCENT > 0.0 && RISK_FIXED <= 0.0" in resolver
    assert resolver.count("QM_LotsForRiskAtEntry(g_leg_xau") == 2
    assert "target_lots > full_lots" in resolver
    assert "risk_value = configured_risk_value * target_lots / full_lots" in resolver
    assert "MathAbs(resolved_lots - target_lots) <= volume_step * 0.1" in resolver


def test_qm5_20012_q02_setfile_keeps_fixed_risk_and_news_stale_cap() -> None:
    values: dict[str, str] = {}
    for raw_line in SETFILE.read_text(encoding="utf-8-sig").splitlines():
        line = raw_line.strip()
        if not line or line.startswith(";") or "=" not in line:
            continue
        key, value = line.split("=", 1)
        values[key.strip()] = value.strip()

    assert values["RISK_FIXED"] == "1000"
    assert values["RISK_PERCENT"] == "0"
    assert values["PORTFOLIO_WEIGHT"] == "1"
    assert int(values["qm_news_stale_max_hours"]) <= 336
    assert values["qm_friday_close_enabled"] == "0"
