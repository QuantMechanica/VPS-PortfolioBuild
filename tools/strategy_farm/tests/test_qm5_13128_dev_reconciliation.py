from __future__ import annotations

import re
from pathlib import Path


REPO = Path(__file__).resolve().parents[3]
EA_DIR = REPO / "framework" / "EAs" / "QM5_13128_pre-fomc-drift-ndx"
SOURCE = EA_DIR / "QM5_13128_pre-fomc-drift-ndx.mq5"
SETFILE = (
    EA_DIR
    / "sets"
    / "QM5_13128_pre-fomc-drift-ndx_NDX.DWX_H1_dev_reconciliation_candidate.set"
)


def _inputs(path: Path) -> dict[str, str]:
    result: dict[str, str] = {}
    for raw in path.read_text(encoding="utf-8-sig").splitlines():
        line = raw.strip()
        if not line or line.startswith(";") or "=" not in line:
            continue
        key, value = line.split("=", 1)
        result[key.strip()] = value.strip()
    return result


def test_candidate_contract_is_fixed_risk_and_owner_ratified_news_exemption() -> None:
    values = _inputs(SETFILE)
    assert float(values["RISK_FIXED"]) > 0
    assert float(values["RISK_PERCENT"]) == 0
    assert values["qm_news_temporal"] == "QM_NEWS_TEMPORAL_OFF"
    assert values["qm_news_compliance"] == "QM_NEWS_COMPLIANCE_NONE"
    assert values["qm_news_mode_legacy"] == "QM_NEWS_OFF"
    assert int(values["qm_news_stale_max_hours"]) <= 336
    assert values["strategy_entry_hour"] == "21"
    assert values["strategy_exit_hour"] == "20"


def test_source_has_2026_meetings_and_fail_closed_horizon() -> None:
    source = SOURCE.read_text(encoding="utf-8-sig")
    dates_match = re.search(r"const int g_event_dates\[\]\s*=\s*\{(.*?)\};", source, re.S)
    assert dates_match is not None
    dates = {int(value) for value in re.findall(r"\b20\d{6}\b", dates_match.group(1))}
    assert {
        20260128,
        20260318,
        20260429,
        20260617,
        20260729,
        20260916,
        20261028,
        20261209,
    }.issubset(dates)
    assert "g_event_calendar_valid_through_key = 20261231" in source
    assert "SETUP_DATA_STALE" in source


def test_source_exposes_minimum_replay_diagnostics_and_current_build_hooks() -> None:
    source = SOURCE.read_text(encoding="utf-8-sig")
    on_tick = re.search(r"void OnTick\(\)\s*\{(.*?)\n\s*\}", source, re.S)
    assert on_tick is not None
    body = on_tick.group(1)
    assert body.index("QM_FrameworkTrackOpenPositionMae();") < body.index(
        "QM_KillSwitchCheck()"
    )
    assert "ZeroMemory(req);" in source
    assert "ENTRY_GATE_DIAGNOSTIC" in source
    assert "ENTRY_GATE_READY" in source
    assert "FOMC_ENTRY_ORDER_RESULT" in source
    assert "FOMC_FLAT_EXIT_RESULT" in source
    assert "OWNER_RATIFIED_EVENT_ANCHORED_EXEMPTION" in source
