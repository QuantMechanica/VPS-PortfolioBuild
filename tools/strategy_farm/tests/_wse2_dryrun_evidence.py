"""WS-E2 evidence generator (NOT a scheduled artifact). Renders the live-truth
status lamp against the REAL production state files (D:\\QM\\reports\\state\\*,
the news calendar, and the config-driven deploy-stamp / manifest) — it NEVER
calls night_balance()/collect() (those read T_Live) and NEVER probes a process.
It stubs the non-live sections so the full mail renders for visual inspection.

Usage: python _wse2_dryrun_evidence.py <out_dir>
"""
from __future__ import annotations

import importlib.util
import json
import sys
from pathlib import Path

ROOT = Path(__file__).resolve().parents[3]
MODULE_PATH = ROOT / "tools" / "strategy_farm" / "morning_brief.py"
spec = importlib.util.spec_from_file_location("mb_evidence", MODULE_PATH)
mb = importlib.util.module_from_spec(spec)
spec.loader.exec_module(mb)

out = Path(sys.argv[1]) if len(sys.argv) > 1 else Path(".")
out.mkdir(parents=True, exist_ok=True)

live = mb.live_status()   # real defaults: state files only, no T_Live, no probe

data = {
    "live": live,
    "night": {"equity": None, "equity_ts": None, "delta_prev": None,
              "ea_logs_today": None, "ea_logs_total": None, "deals": None,
              "err_lines": None, "journal_date": None, "journal_age_sec": None},
    "since": mb._yesterday_18(),
    "frontier": {"fresh_pass": [], "in_flight": [], "fresh_count": 0, "inflight_count": 0},
    "factory": {"color": mb.EMERALD, "label": "GRÜN", "workers": 10, "d_free": 200.0,
                "infra": 0.0, "reason": "stub (evidence render — factory section not exercised)"},
    "actions": [],
    "quota": {"claude": {"week_pct": 40}, "codex": {"week_pct": 50}},
    "heartbeats": [],
    "now_local": "EVIDENCE", "tz": "W. Europe",
    "date_h": "EVIDENCE", "date_iso": "2026-07-26",
}

subject = mb.build_subject(data)
html = mb.render_html(data)
text = mb.render_text(data)

(out / "dryrun_live_status.json").write_text(
    json.dumps(live, indent=2, ensure_ascii=False), encoding="utf-8")
(out / "dryrun_morning_brief.html").write_text(html, encoding="utf-8")
(out / "dryrun_morning_brief.txt").write_text(text, encoding="utf-8")
(out / "dryrun_subject.txt").write_text(subject + "\n", encoding="utf-8")

print("SUBJECT:", subject)
print("resolved manifest:", live["manifest_path"])
print("expected_sleeves:", live["expected_sleeves"], "account:", live["account"])
print("deploy_authenticated:", live["deploy_authenticated"])
print("overall:", live["overall"], "| summary:", live["summary"])
print("wrote evidence to:", out)
