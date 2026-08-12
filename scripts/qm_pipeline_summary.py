"""Daily QuantMechanica pipeline summary — process-driven, no AI reasoning.

Reads structured state from disk and produces a Markdown report covering
the 24 items in the OWNER's daily-summary requirement. Designed to be
chained into the existing QM_DailyStatusMail task (which already runs at
23:00 UTC and ships an HTML mail).

Inputs (read-only):
    D:/QM/reports/state/pipeline_state.json       (built by build_pipeline_state.py)
    D:/QM/reports/pipeline/dispatch_state.json    (dispatcher state)
    D:/QM/reports/state/last_check_state.json     (aggregator MT5 + report state)
    C:/QM/repo/docs/ops/pipeline_health/<YYYY-MM-DD>.jsonl (watchdog history)
    C:/QM/repo/framework/registry/ea_id_registry.csv
    C:/QM/repo/public-data/public-snapshot.json   (last published snapshot mtime)

Output:
    D:/QM/strategy_farm/dashboards/daily/<YYYY-MM-DD>_pipeline_summary.md   (canonical)
    stdout                                                              (with --stdout)

Usage:
    python qm_pipeline_summary.py                       # write file
    python qm_pipeline_summary.py --stdout              # print to stdout, no file
    python qm_pipeline_summary.py --date 2026-05-11     # generate for given date
"""
from __future__ import annotations

import argparse
import csv
import json
import sys
from datetime import datetime, timedelta, timezone
from pathlib import Path

REPO_ROOT = Path(r"C:/QM/repo")
PIPELINE_ROOT = Path(r"D:/QM/reports/pipeline")
STATE_DIR = Path(r"D:/QM/reports/state")
STATE_FILE = STATE_DIR / "pipeline_state.json"
DISPATCH_STATE = PIPELINE_ROOT / "dispatch_state.json"
LAST_CHECK_FILE = STATE_DIR / "last_check_state.json"
WATCHDOG_DIR = REPO_ROOT / "docs" / "ops" / "pipeline_health"
PUBLIC_SNAPSHOT = REPO_ROOT / "public-data" / "public-snapshot.json"
CARDS_DIR = REPO_ROOT / "strategy-seeds" / "cards"
EA_REGISTRY = REPO_ROOT / "framework" / "registry" / "ea_id_registry.csv"
DAILY_OUT = Path(r"D:/QM/strategy_farm/dashboards/daily")


def read_json_safe(path: Path) -> dict | None:
    if not path.is_file():
        return None
    try:
        return json.loads(path.read_text(encoding="utf-8-sig"))
    except Exception:
        return None


def date_str(d: datetime) -> str:
    return d.strftime("%Y-%m-%d")


def cards_added_in_window(start: datetime, end: datetime) -> list[str]:
    out = []
    if not CARDS_DIR.is_dir():
        return out
    for p in sorted(CARDS_DIR.iterdir()):
        if p.is_file() and p.suffix == ".md":
            mtime = datetime.fromtimestamp(p.stat().st_mtime, tz=timezone.utc)
            if start <= mtime < end:
                out.append(p.stem)
    return out


def registry_built_in_window(start: datetime, end: datetime) -> list[str]:
    if not EA_REGISTRY.is_file():
        return []
    out = []
    with EA_REGISTRY.open(encoding="utf-8-sig", newline="") as f:
        for row in csv.DictReader(f):
            ts = row.get("created_at") or ""
            try:
                t = datetime.fromisoformat(ts.replace("Z", "+00:00"))
                if t.tzinfo is None:
                    t = t.replace(tzinfo=timezone.utc)
                if start <= t < end:
                    out.append(row.get("ea_id", "?"))
            except ValueError:
                continue
    return out


def phase_result_files_in_window(start: datetime, end: datetime) -> list[dict]:
    """Find <ea>/<phase>/*_result.json files modified in the date window."""
    out = []
    if not PIPELINE_ROOT.is_dir():
        return out
    for ea_dir in sorted(PIPELINE_ROOT.iterdir()):
        if not (ea_dir.is_dir() and ea_dir.name.startswith("QM5_")):
            continue
        for phase_dir in ea_dir.iterdir():
            if not phase_dir.is_dir():
                continue
            for result_file in phase_dir.glob("*_result.json"):
                mtime = datetime.fromtimestamp(result_file.stat().st_mtime, tz=timezone.utc)
                if start <= mtime < end:
                    data = read_json_safe(result_file) or {}
                    verdict = data.get("verdict") or (
                        "DRY" if (data.get("counts", {}) or {}).get("DRY") else "UNKNOWN"
                    )
                    out.append({
                        "ea": ea_dir.name,
                        "phase_dir": phase_dir.name,
                        "phase": data.get("phase", phase_dir.name),
                        "verdict": str(verdict).upper(),
                        "file": str(result_file),
                        "mtime_utc": mtime.isoformat(),
                    })
    return out


def watchdog_summary(date_str_target: str) -> dict:
    jsonl_path = WATCHDOG_DIR / f"{date_str_target}.jsonl"
    if not jsonl_path.is_file():
        return {"samples": 0, "stale_alarms": 0, "alarm_kinds": {}, "max_idle_subs": 0}
    samples = 0
    alarm_kinds = {}
    max_idle_subs = 0
    for line in jsonl_path.read_text(encoding="utf-8").splitlines():
        try:
            obj = json.loads(line)
        except Exception:
            continue
        samples += 1
        idle = sum(1 for s in obj.get("sub_agents", []) if s.get("alarm"))
        if idle > max_idle_subs:
            max_idle_subs = idle
        for a in obj.get("alarms", []) or []:
            k = a.get("kind", "?")
            alarm_kinds[k] = alarm_kinds.get(k, 0) + 1
    return {
        "samples": samples,
        "alarm_kinds": alarm_kinds,
        "max_idle_subs": max_idle_subs,
    }


def section(title: str, content: str) -> str:
    return f"### {title}\n\n{content}\n"


def render_summary(date_str_target: str) -> str:
    target = datetime.strptime(date_str_target, "%Y-%m-%d").replace(tzinfo=timezone.utc)
    start = target
    end = target + timedelta(days=1)

    state = read_json_safe(STATE_FILE) or {}
    dispatch = read_json_safe(DISPATCH_STATE) or {}
    last_check = read_json_safe(LAST_CHECK_FILE) or {}
    snapshot = read_json_safe(PUBLIC_SNAPSHOT) or {}
    wd = watchdog_summary(date_str_target)

    cards_today = cards_added_in_window(start, end)
    eas_built_today = registry_built_in_window(start, end)
    results_today = phase_result_files_in_window(start, end)

    # Group result events by phase + verdict
    by_phase_verdict: dict[tuple[str, str], list[dict]] = {}
    for r in results_today:
        phase = r["phase"]
        verdict = r["verdict"]
        by_phase_verdict.setdefault((phase, verdict), []).append(r)

    def phase_count(phase_label: str, verdict_label: str) -> int:
        return len(by_phase_verdict.get((phase_label, verdict_label), []))

    # MT5 & agents
    mt5 = (state.get("mt5") or {})
    mt5_running = sorted([k for k, v in mt5.items() if v.get("running")])
    mt5_idle = sorted([k for k, v in mt5.items() if not v.get("running")])

    agents_wd = state.get("agents_watchdog", {})
    by_status = state.get("by_status", {})

    # Dedup / pipeline progress
    disp = state.get("dispatch", {})

    # Publication state
    pub_mtime = (
        datetime.fromtimestamp(PUBLIC_SNAPSHOT.stat().st_mtime, tz=timezone.utc).isoformat()
        if PUBLIC_SNAPSHOT.is_file()
        else "none"
    )

    # Build report
    lines = []
    lines.append(f"# QuantMechanica daily pipeline summary — {date_str_target}\n")
    lines.append(f"_Generated {datetime.now(timezone.utc).isoformat()} from disk state. No agent reasoning._\n")

    lines.append(section(
        "Research → Build",
        f"- Strategies researched (cards mtime within day): **{len(cards_today)}**" + (
            f"\n  - " + ", ".join(cards_today) if cards_today else ""
        ) + f"\n- Strategy cards total (snapshot): **{state.get('strategy_cards_count', 0)}**"
          f"\n- EAs registered today: **{len(eas_built_today)}**" + (
              f"\n  - " + ", ".join(eas_built_today) if eas_built_today else ""
          ) + f"\n- EAs registered total: **{state.get('eas_registered_count', 0)}**"
        f"\n- EAs with at least one phase result: **{state.get('eas_with_reports_count', 0)}**"
    ))

    lines.append(section(
        "Baseline (P2)",
        f"- Queued (pending dispatcher matrix jobs at end of day): **{disp.get('pending_matrix_jobs', 0)}**"
        f"\n- Completed today (result files written): **{sum(1 for r in results_today if r['phase'].startswith('P2'))}**"
        f"\n- Passed today: **{phase_count('P2', 'PASS')}**"
        f"\n- Failed today: **{phase_count('P2', 'FAIL') + phase_count('P2', 'INVALID')}**"
        f"\n- Dry-run today (no real execution): **{phase_count('P2', 'DRY')}**"
    ))

    lines.append(section(
        "Sweep (P3)",
        f"- Completed today: **{sum(1 for r in results_today if r['phase'] == 'P3')}**"
        f"\n- Passed today: **{phase_count('P3', 'PASS')}**"
        f"\n- Failed today: **{phase_count('P3', 'FAIL')}**"
    ))

    lines.append(section(
        "Forward / Robustness (P3.5, P4)",
        f"- P3.5 (cross-sectional) completed today: **{sum(1 for r in results_today if r['phase'] == 'P3.5')}**"
        f"\n- P3.5 passed today: **{phase_count('P3.5', 'PASS')}**"
        f"\n- P4 walk-forward completed today: **{sum(1 for r in results_today if r['phase'] == 'P4')}**"
        f"\n- P4 passed today: **{phase_count('P4', 'PASS')}**"
    ))

    lines.append(section(
        "News-filter (P8) — V5 end-of-pipeline mode selection",
        f"- Completed today: **{sum(1 for r in results_today if r['phase'] == 'P8')}**"
        f"\n- Mode selected today: **{phase_count('P8', 'PASS')}** (verdict MODE_SELECTED)"
    ))

    # Live-eligibility & gating
    ready_count = by_status.get("READY", 0)
    blocked_count = by_status.get("BLOCKED", 0)
    review_count = by_status.get("REVIEW_REQUIRED", 0)
    lines.append(section(
        "Live-eligibility — manual OWNER gates (P9/P9b/P10)",
        f"- EAs at PIPELINE_PASSED (final_verdict=READY): **{ready_count}**"
        f"\n- EAs BLOCKED from live eligibility: **{blocked_count}**"
        f"\n- EAs needing REVIEW_REQUIRED: **{review_count}**"
        f"\n- T6 AutoTrading toggle: **OWNER + Board-Advisor only (Hard Rule). No automation.**"
    ))

    # Deduplication / skipped
    dedup_total = disp.get('dedup_entries', 0)
    lines.append(section(
        "Deduplication & skips",
        f"- Total deduped test keys in dispatcher: **{dedup_total}**"
        f"  (these are identical ea+version+symbol+phase+config combinations that the dispatcher refuses to re-run)"
        f"\n- Recent runs window: **{disp.get('recent_runs_count', 0)}**"
    ))

    # MT5 saturation
    mt5_total = 10
    lines.append(section(
        "MT5 saturation",
        f"- Terminals running: **{len(mt5_running)} / {mt5_total}** ({', '.join(mt5_running) or 'none'})"
        f"\n- Terminals idle: **{', '.join(mt5_idle) or 'none'}**"
        f"\n- Sub-agents online (runs ≥1 in last 2h): **{agents_wd.get('online_count', 0)} / {agents_wd.get('total_count', 0)}**"
        f"\n- Sub-agents idle ≥2h: **{agents_wd.get('offline_count', 0)}**"
        f"\n- Active watchdog alarm kinds: " + (
            ", ".join(agents_wd.get("active_alarms", [])) or "none"
        )
    ))

    # Publication
    lines.append(section(
        "Local dashboard & strategy archive",
        f"- Hourly task `QM_StrategyFarm_Dashboard_Hourly` regenerates `D:/QM/strategy_farm/dashboards/current.html` + `strategies.html`"
        f"\n- See `LastTaskResult` in scheduled-tasks query for failure detection"
    ))

    lines.append(section(
        "Website publication (quantmechanica.com)",
        f"- `public-data/public-snapshot.json` last written: **{pub_mtime}**"
        f"\n- Snapshot phase label: **{snapshot.get('phase', 'unknown')}**"
        f"\n- Publication task `QM_Public_Snapshot_Hourly` fires hourly (state-build at :05, publish at :07)"
    ))

    # Token-saving & stale tasks
    lines.append(section(
        "Watchdog observations (today)",
        f"- Watchdog samples: **{wd['samples']}** (15-min cadence ⇒ ≤ 96 / day)"
        f"\n- Max idle sub-agents in any sample: **{wd['max_idle_subs']}**"
        f"\n- Alarm kind frequencies: " + (
            ", ".join(f"{k}={v}" for k, v in wd['alarm_kinds'].items()) or "none"
        )
    ))

    # Blockers
    blockers = []
    for ea in state.get("per_ea", []):
        if ea.get("status") == "BLOCKED" and ea.get("phase_blockers"):
            blockers.append(f"  - {ea['ea_id']}: " + ", ".join(
                f"{b.get('phase','?')}={b.get('verdict','?')}" for b in ea["phase_blockers"]
            ))
    lines.append(section(
        "Blockers (per-EA)",
        ("\n".join(blockers) if blockers else "_None_")
    ))

    # Next recommended actions — deterministic from state, no AI inference
    next_actions = []
    if state.get("agents_watchdog", {}).get("offline_count", 0) >= 3:
        next_actions.append("Re-engage sub-agents (Phase Orchestrator currently Disabled; OWNER decision required to re-enable).")
    if len(mt5_running) < 7:
        next_actions.append(f"Bring factory terminals online ({mt5_total - len(mt5_running)} dark, target >=7/10) for parallel backtests.")
    if ready_count > 0:
        next_actions.append(f"OWNER P9 review for {ready_count} READY EA(s).")
    if any(ea.get("status") == "REVIEW_REQUIRED" for ea in state.get("per_ea", [])):
        next_actions.append("Human review needed for REVIEW_REQUIRED EAs.")
    _pending = dispatch.get("pending_matrix_jobs", []) or []
    if isinstance(_pending, (list, dict)) and len(_pending) > 0:
        next_actions.append(f"Dispatcher has {len(_pending)} pending matrix jobs — confirm consumer running.")
    lines.append(section(
        "Next recommended actions",
        ("\n".join(f"- {x}" for x in next_actions) if next_actions else "_None_")
    ))

    return "\n".join(lines)


def main() -> int:
    ap = argparse.ArgumentParser()
    ap.add_argument("--date", default=datetime.now(timezone.utc).strftime("%Y-%m-%d"))
    ap.add_argument("--stdout", action="store_true", help="Print to stdout; do not write file.")
    args = ap.parse_args()

    body = render_summary(args.date)

    if args.stdout:
        if hasattr(sys.stdout, "reconfigure"):
            sys.stdout.reconfigure(encoding="utf-8", errors="strict")
        print(body)
        return 0

    DAILY_OUT.mkdir(parents=True, exist_ok=True)
    out = DAILY_OUT / f"{args.date}_pipeline_summary.md"
    tmp = out.with_suffix(".md.tmp")
    tmp.write_text(body, encoding="utf-8")
    tmp.replace(out)
    print(f"Wrote {out}")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
