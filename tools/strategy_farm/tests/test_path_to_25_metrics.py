from __future__ import annotations

import datetime as dt
import hashlib
import re
import sqlite3
from pathlib import Path

from tools.strategy_farm import book_build_guard, heartbeat_snapshot, morning_brief
from tools.strategy_farm import path_to_25, render_cockpit_v2


DDL = """
CREATE TABLE work_items (
    id TEXT PRIMARY KEY,
    phase TEXT NOT NULL,
    ea_id TEXT NOT NULL,
    symbol TEXT NOT NULL,
    status TEXT NOT NULL,
    verdict TEXT,
    payload_json TEXT,
    created_at TEXT NOT NULL,
    updated_at TEXT NOT NULL,
    gate_contract_version TEXT
);
CREATE TABLE work_item_holds (
    work_item_id TEXT PRIMARY KEY,
    active INTEGER NOT NULL
);
"""


def _fixture_db(path: Path) -> Path:
    now = dt.datetime.now(dt.timezone.utc).replace(microsecond=0)
    created = now - dt.timedelta(days=2)
    updated = created + dt.timedelta(hours=24)
    con = sqlite3.connect(path)
    con.executescript(DDL)

    def add(
        row_id: str, phase: str, ea: str, status: str = "done",
        verdict: str | None = "PASS", payload: str = "{}",
        created_at: dt.datetime = created, updated_at: dt.datetime = updated,
    ) -> None:
        con.execute(
            "INSERT INTO work_items VALUES (?,?,?,?,?,?,?,?,?,?)",
            (
                row_id, phase, ea, "EURUSD.DWX", status, verdict, payload,
                created_at.isoformat(), updated_at.isoformat(), "v4",
            ),
        )

    # 24 fully qualified pairs plus one pair at Q13.  Every completed phase is
    # exactly 24h so the remaining Q14 path has a deterministic 0.10-day ETA
    # with ten terminals.
    gates = tuple(f"Q{i:02d}" for i in range(2, 15))
    for index in range(25):
        ea = f"QM5_{900000 + index}"
        last = 14 if index < 24 else 13
        for gate in gates:
            if int(gate[1:]) > last:
                continue
            verdict = "PASS"
            if gate == "Q14":
                verdict = "KEEP_INCUMBENT" if index % 2 == 0 else "CHALLENGER_PROMOTED"
            add(f"{ea}-{gate}", gate, ea, verdict=verdict)

    add("news-locked", "Q10_NEWS", "QM5_910001", verdict="CONFIG_LOCKED")
    add("news-review", "Q10_NEWS", "QM5_910002", verdict="REVIEW_REQUIRED")
    add("news-open", "Q10_NEWS", "QM5_910003", status="active", verdict=None,
        created_at=now, updated_at=now)
    con.execute("INSERT INTO work_item_holds VALUES (?,1)", ("news-open",))

    for gate in ("Q12", "Q13", "Q14"):
        add(f"{gate}-pending", gate, f"QM5_92{gate[1:]}", status="pending", verdict=None,
            created_at=now, updated_at=now)

    rerun_payload = '{"rerun_reason":"rb-backfill-planner:rerun_infra"}'
    add("backfill-open", "Q03", "QM5_930001", status="pending", verdict=None,
        payload=rerun_payload, created_at=now, updated_at=now)
    add("backfill-done", "Q03", "QM5_930002", status="done", verdict="INFRA_FAIL",
        payload=rerun_payload, created_at=now, updated_at=now)
    con.commit()
    con.close()
    return path


def test_path_to_25_metrics_fixture_is_complete_and_read_only(
    tmp_path: Path, monkeypatch
) -> None:
    db = _fixture_db(tmp_path / "farm.sqlite")
    before = hashlib.sha256(db.read_bytes()).hexdigest()
    monkeypatch.setattr(book_build_guard, "_count_strategy_families", lambda rows: 3)

    metrics = path_to_25.path_to_25_metrics(db)

    assert hashlib.sha256(db.read_bytes()).hexdigest() == before
    assert metrics["qualified_pairs"] == 24
    assert metrics["distinct_eas"] == 24
    assert metrics["families"] == 3
    assert metrics["frontier_histogram"]["Q14"] == 24
    assert metrics["frontier_histogram"]["Q13"] == 1
    assert metrics["news_gate"] == {
        "conclusive_verdicts_7d": 27,
        "pass_7d": 26,
        "pending": 1,
        "holds": 1,
    }
    assert metrics["opt_fork"]["Q12"] == {"pending": 1, "done": 25}
    assert metrics["opt_fork"]["Q13"] == {"pending": 1, "done": 25}
    assert metrics["opt_fork"]["Q14"] == {"pending": 1, "done": 24}
    assert metrics["opt_fork"]["terminal_verdicts"] == {
        "CHALLENGER_PROMOTED": 12,
        "KEEP_INCUMBENT": 12,
    }
    assert metrics["backfill"] == {"enqueued_today": 2, "rerun_infra_open": 1}
    assert metrics["eta_days"] == 0.1


def _render_metrics() -> dict:
    return {
        "qualified_pairs": 7,
        "distinct_eas": 6,
        "families": 4,
        "frontier_histogram": {"Q08": 11, "Q11": 3, "Q14": 7},
        "news_gate": {
            "conclusive_verdicts_7d": 5, "pass_7d": 2, "pending": 9, "holds": 3,
        },
        "opt_fork": {
            "Q12": {"pending": 3, "done": 8},
            "Q13": {"pending": 2, "done": 6},
            "Q14": {"pending": 1, "done": 7},
            "terminal_verdicts": {"KEEP_INCUMBENT": 7},
        },
        "backfill": {"enqueued_today": 10, "rerun_infra_open": 4},
        "eta_days": 18.5,
    }


def test_all_owner_surfaces_render_the_shared_metrics(tmp_path: Path) -> None:
    metrics = _render_metrics()
    cockpit = render_cockpit_v2.render({
        "schema_version": "qm.mission_control.v2",
        "generated_at": "2026-08-23T10:00:00+00:00",
        "path_to_25": metrics,
    })
    heartbeat = heartbeat_snapshot.render_markdown({
        "ts": "2026-08-23T10:00:00+00:00",
        "flags": [],
        "path_to_25": metrics,
    })
    owner_html = morning_brief.render_path_to_25_section(metrics)
    scratch_cockpit = tmp_path / "cockpit_path_to_25.html"
    scratch_cockpit.write_text(cockpit, encoding="utf-8", newline="\n")

    for rendered in (cockpit, heartbeat, owner_html):
        assert "Weg zu 25" in rendered
        assert "Q12" in rendered and "Q13" in rendered and "Q14" in rendered
        assert re.search(r"\bP[0-9]\b", rendered) is None
    assert "#2954d4" in cockpit
    assert scratch_cockpit.is_file() and scratch_cockpit.stat().st_size == len(
        cockpit.encode("utf-8")
    )
    assert "7 / 25" in heartbeat
    assert "7<span" in owner_html and "/25" in owner_html
    assert "RERUN_INFRA" in cockpit and "RERUN_INFRA" in owner_html
