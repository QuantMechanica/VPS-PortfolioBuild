"""Current-child summary markers outrank filesystem timestamp granularity."""

from __future__ import annotations

import json
import os
import time
from pathlib import Path

from framework.scripts import q05_stress_medium as q05
from framework.scripts import q08_5_neighborhood_runner as q08_5


IDENTITY = {
    "ea_id": 1001,
    "expert": r"QM\QM5_1001_demo",
    "symbol": "EURUSD.DWX",
    "period": "H1",
    "terminal": "T2",
    "runs": [{"status": "OK", "total_trades": 20}],
}


def _old_identity_summary(tmp_path: Path) -> Path:
    summary = tmp_path / "summary.json"
    summary.parent.mkdir(parents=True, exist_ok=True)
    summary.write_text(json.dumps(IDENTITY), encoding="utf-8")
    os.utime(summary, (1.0, 1.0))
    return summary


def test_q05_accepts_identity_matched_marker_from_current_child(tmp_path: Path) -> None:
    summary = _old_identity_summary(tmp_path)

    selected = q05._summary_from_run_smoke_output(
        f"run_smoke.summary={summary}\n",
        started_at=time.time(),
        ea_id=1001,
        ea_expert=IDENTITY["expert"],
        symbol=IDENTITY["symbol"],
        period=IDENTITY["period"],
        terminal=IDENTITY["terminal"],
    )

    assert selected == summary


def test_q08_accepts_identity_matched_marker_from_current_child(tmp_path: Path) -> None:
    summary = _old_identity_summary(tmp_path)

    selected = q08_5._summary_from_run_smoke_output(
        f"run_smoke.summary={summary}\n",
        started_at=time.time(),
        ea_id=1001,
        ea_expert=IDENTITY["expert"],
        symbol=IDENTITY["symbol"],
        period=IDENTITY["period"],
        terminal=IDENTITY["terminal"],
    )

    assert selected == summary


def test_directory_fallback_still_rejects_stale_summary(tmp_path: Path) -> None:
    summary = _old_identity_summary(tmp_path / "QM5_1001" / "old")

    selected_q05 = q05._find_latest_matching_summary(
        tmp_path,
        started_at=time.time(),
        ea_id=1001,
        ea_expert=IDENTITY["expert"],
        symbol=IDENTITY["symbol"],
        period=IDENTITY["period"],
        terminal=IDENTITY["terminal"],
    )
    selected_q08 = q08_5.latest_run_smoke_summary(
        tmp_path,
        1001,
        time.time(),
        ea_expert=IDENTITY["expert"],
        symbol=IDENTITY["symbol"],
        period=IDENTITY["period"],
        terminal=IDENTITY["terminal"],
    )

    assert selected_q05 is None
    assert selected_q08 is None
