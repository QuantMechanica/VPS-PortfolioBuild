"""Pipeline health checks — catch silent failures early.

OWNER 2026-05-17: "wie können wir das in Zukunft früher erkennen". Each
check is a single SQL or filesystem query that returns OK / WARN / FAIL plus
a human-readable detail string and an action_hint. The whole thing runs
every 15 min via QM_StrategyFarm_Health_15min, writes to
D:/QM/strategy_farm/state/health.json (read by render_cockpit.py for a
top-of-page red banner), and appends FAILs to health_alarms.log.

The 10 invariants below cover every silent failure we hit overnight
2026-05-16/17:
  1. codex_review FAIL clustering (we hit 12/12 FAIL silently)
  2. cards_ready stagnation (4 sources idle for hours)
  3. Pump scheduled task non-zero exit (LastResult=112)
  4. P2-PASS without matching P3 work_item (8 ablations stranded)
  5. Ablation grandchildren (2nd-gen `_ablation_NN_ablation_MM`)
  6. Claude-review starvation (builds pending, no review spawn)
  7. MT5 dispatch idle while work_items pending
  8. Codex zero-activity while builds pending
  9. Source pool drained (need to add more sources)
 10. Quota snapshot stale (quota_pull API pull failing)
"""

from __future__ import annotations

import csv
import datetime as dt
import json
import os
import re
import shutil
import sqlite3
import subprocess
import sys
from pathlib import Path

try:
    import farmctl
except ModuleNotFoundError:
    from tools.strategy_farm import farmctl
try:
    import agent_router
except ModuleNotFoundError:
    from tools.strategy_farm import agent_router
try:
    from factory_mutation_lock import (
        DEFAULT_PATH as FACTORY_MUTATION_LOCK_PATH,
        DEFAULT_STALE_REAP_SECONDS as FACTORY_MUTATION_LOCK_DEAD_FAIL_SECONDS,
        inspect_factory_mutation_lock,
    )
except ModuleNotFoundError:
    from tools.strategy_farm.factory_mutation_lock import (
        DEFAULT_PATH as FACTORY_MUTATION_LOCK_PATH,
        DEFAULT_STALE_REAP_SECONDS as FACTORY_MUTATION_LOCK_DEAD_FAIL_SECONDS,
        inspect_factory_mutation_lock,
    )

ROOT = Path(r"D:\QM\strategy_farm")
REPO_ROOT = Path(__file__).resolve().parents[2]
FRAMEWORK_EAS_DIR = REPO_ROOT / "framework" / "EAs"
DB = ROOT / "state" / "farm_state.sqlite"
HEALTH_FILE = ROOT / "state" / "health.json"
ALARMS_LOG = ROOT / "state" / "health_alarms.log"
QUOTA_SNAPSHOT = ROOT / "state" / "quota_snapshot.json"
LOG_DIR = ROOT / "logs"
CODEX_AUTH = Path(r"C:/Users/Administrator/.codex/auth.json")
CODEX_BRIDGE_HEARTBEAT = ROOT / "state" / "codex_bridge_heartbeat.txt"
ZERO_TRADE_DEAD_THRESHOLD = 0.80
ZERO_TRADE_DEAD_MIN_DONE = 5
ZERO_TRADE_REWORK_DEDUP_HOURS = 6
PHASE_ACTIVE_TIMEOUT_MIN = dict(farmctl.PHASE_ACTIVE_TIMEOUT_MIN)
FACTORY_TERMINALS = tuple(f"T{i}" for i in range(1, 11))
MT5_ROOT = Path(os.environ.get("QM_MT5_ROOT", r"D:\QM\mt5"))
TERMINAL_PROFILE_LOG_TAIL_BYTES = 256 * 1024
ACCOUNT_NOT_SPECIFIED_TOKEN = "tester not started because the account is not specified"
MT5_SATURATION_MIN_WORKERS = 7
# Operator safety/quarantine list — terminals here are intentionally offline
# (mirrors start_terminal_workers._disabled_terminals).  It lowers the urgent
# failure floor, but it must not erase missing design capacity: a complete
# enabled subset is WARN whenever fewer than all ten installed slots are usable.
DISABLED_TERMINALS_FILE = ROOT / "state" / "disabled_terminals.txt"
FACTORY_MUTATION_LOCK_LIVE_WARN_SECONDS = 10 * 60.0
FACTORY_ON_CEREMONY_INCOMPLETE_PATH = (
    ROOT / "state" / "FACTORY_ON_CEREMONY_INCOMPLETE.json"
)

# --- WS-F standing vacuousness audit (ULTRACODE 2026-07-26) ------------------
# Detectors that authenticate provenance before flagging a gate as vacuous. Every
# threshold below is deliberately exposed as a named constant so the audit can be
# retuned from one place and so the rollback is "revert these constants". All reads
# are read-only (DB via _connect()'s mode=ro handle; filesystem/live-log tails via
# open('rb')). Nothing here writes the factory DB or anything under T_Live.
#
# ea_metrics is the authoritative phase-evidence store (WP-2 ingester); the full
# aggregate.json (per_seed_detail, unrounded KPIs, stress fields) lives at the row's
# evidence_path under D:\QM\reports\work_items — the on-disk pipeline aggregates are
# purged by the cache sweeper, so the DB row + its evidence_path is the durable pair.
VACUOUSNESS_WINDOW_DAYS = 14          # trailing window (evidence_mtime) for (a)(b)(e)
INVALID_RATE_WINDOW_DAYS = 7          # detector (c) — plan's "trailing-7d INVALID rate"
INVALID_RATE_MIN_SAMPLE = 20          # need this many runs in a phase before judging
INVALID_RATE_WARN_PCT = 10.0
INVALID_RATE_FAIL_PCT = 25.0
# Q05 MEDIUM applies qm_stress_reject_probability=0.00 (gen_stress_setfile LEVEL MED);
# Q06 HARSH applies 0.10 (10% seeded, deterministic, short-circuits before OrderSend).
# So a wired EA MUST drop trades / move PF between Q05 and Q06. Byte-identical KPIs on a
# cohort where a 10% seeded rejection is near-certain to bite => the reject input is not
# honoured (WP-9 basket-stress bypass / 1567 missing-input class). Cohort floor 40:
# P(0 of 40 trades rejected at p=0.10) = 0.9**40 ≈ 1.5%, so below 40 an identical result
# is not yet damning and is reported benign (below_cohort).
STRESS_IDENTITY_COHORT_MIN_TRADES = 40
# WARN surfaces the vacuous sleeves (evidence-quality signal, actionable — retire/fix);
# only a systemic spike escalates to FAIL. The threshold is set above the known legacy
# backlog (~12 pre-fix sleeves on 2026-07-26) so a standing WARN is not a permanent red
# banner, while a genuine new regression (many EAs suddenly ignoring the reject input)
# still FAILs. Retune here; tests patch it low to exercise the FAIL branch.
STRESS_IDENTITY_FAIL_COUNT = 20       # systemic spike escalates WARN -> FAIL
Q07_ZERO_VARIANCE_FAIL_COUNT = 5      # flagged (non-deterministic) zero-variance spike
SEED_AUTH_FAIL_WARN = 1               # any authenticated seed-auth failure warns
SEED_AUTH_FAIL_FAIL_PCT = 5.0         # rate over Q07 runs in-window that escalates to FAIL
EVIDENCE_READ_CAP = 400               # hard cap on evidence-file opens per detector run
# --- Two-tier provenance (Codex round-2, ULTRACODE 2026-07-26) --------------
# Codex challenge: a heuristic match (identical KPIs / zero variance) is only a
# CANDIDATE. It becomes an AUTHENTICATED finding ONLY when the evidence payload
# also cryptographically binds the full deployment identity — EA source, set-file,
# compiled binary, and native report hashes — plus the unrounded KPIs and the
# per-run stress/seed telemetry. The current durable aggregates carry none of
# those sha256 blocks (verified 2026-07-26 against live Q06/Q07 aggregate.json),
# so every live detection publishes as a CANDIDATE. No detector may claim a "true
# positive" / "0 false positives" from the CANDIDATE tier. The pipeline provenance
# schema is nested {"path":..., "sha256":...} blocks (q03_plateau_runner.py), so
# these aliases reach a real AUTHENTICATED tier the moment an aggregate carries them.
PROVENANCE_HASH_ALIASES = {
    "ea":     ("ea_sha256", "source_sha256", "mq5", "source", "ea"),
    "set":    ("set_sha256", "setfile_sha256", "baseline_setfile", "setfile", "set"),
    "binary": ("ex5_sha256", "binary_sha256", "ex5", "binary"),
    "report": ("report_sha256", "native_report_sha256", "report"),
}
TIER_CANDIDATE = "CANDIDATE"
TIER_AUTHENTICATED = "AUTHENTICATED"
# KS divergence kill-switch baseline dormancy (detector d). Live QM EA logs for the DXZ
# book, the deployed manifest, and both baseline search roots used by the EA
# loader (terminal-local first, FILE_COMMON fallback). QM_DXZ_BOOK_MANIFEST
# mirrors live_book_pulse.py's pointer so both consume the same signed book.
LIVE_QM_LOG_DIR = Path(r"C:\QM\mt5\T_Live\MT5_Base\MQL5\Files\QM")
LIVE_TERMINAL_BASELINE_DIR = LIVE_QM_LOG_DIR / "baselines"
LIVE_COMMON_BASELINE_DIR = Path(
    r"C:\Users\Administrator\AppData\Roaming\MetaQuotes\Terminal\Common\Files\QM\baselines"
)
DXZ_BOOK_MANIFEST = Path(
    os.environ.get(
        "QM_DXZ_BOOK_MANIFEST",
        r"D:\QM\reports\portfolio\portfolio_manifest_live_24sleeve_20260724.json",
    )
)
KS_LOG_TAIL_BYTES = 512 * 1024        # bounded tail per live log (latest events only)
KS_LOG_FILE_CAP = 60                  # bounded number of live logs scanned


def _disabled_terminals() -> set[str]:
    try:
        text = DISABLED_TERMINALS_FILE.read_text(encoding="utf-8-sig")
    except (OSError, UnicodeDecodeError):
        return set()
    out: set[str] = set()
    for line in text.splitlines():
        name = line.strip().upper()
        if re.fullmatch(r"T(?:[1-9]|10)", name):
            out.add(name)
    return out


def _utc_now() -> dt.datetime:
    return dt.datetime.now(dt.timezone.utc)


def _parse_utc_ts(value: str | None) -> dt.datetime | None:
    if not value:
        return None
    text = str(value).strip()
    if text.endswith("Z"):
        text = text[:-1] + "+00:00"
    try:
        parsed = dt.datetime.fromisoformat(text)
    except ValueError:
        return None
    if parsed.tzinfo is None:
        parsed = parsed.replace(tzinfo=dt.timezone.utc)
    return parsed.astimezone(dt.timezone.utc)


def _connect() -> sqlite3.Connection:
    """Production DB handle — enforced read-only (URI ``mode=ro`` + ``PRAGMA
    query_only=ON``).

    WS-F (ULTRACODE 2026-07-26, Codex challenge): the health checker only ever
    *queries* the live factory DB (``D:\\QM\\strategy_farm\\state\\farm_state.sqlite``);
    it must never be able to write it. Two independent locks are used because each
    covers a different failure mode: ``mode=ro`` blocks the VFS from opening the
    file for writing at all (so a stray write raises instead of racing the factory's
    writers), and ``PRAGMA query_only=ON`` blocks writes at the SQL layer even if a
    future caller reopened rw. Health OUTPUTS (health.json, alarms log) are written
    in ``run_all()`` through their own separate state paths, never through this
    handle. The empirical read of this exact WAL DB in the Codex challenge confirms
    ``mode=ro`` reads succeed against the live writer."""
    con = sqlite3.connect(f"{DB.as_uri()}?mode=ro", uri=True, timeout=5.0)
    con.row_factory = sqlite3.Row
    con.execute("PRAGMA query_only = ON")
    return con


def _check(name: str, status: str, value, threshold, detail: str, hint: str) -> dict:
    return {
        "name": name,
        "status": status,            # OK | WARN | FAIL
        "value": value,
        "threshold": threshold,
        "detail": detail,
        "action_hint": hint,
    }


def _creationflags_no_window() -> int:
    if sys.platform == "win32" and hasattr(subprocess, "CREATE_NO_WINDOW"):
        return subprocess.CREATE_NO_WINDOW
    return 0


def _tail_has_current_codex_401(log: Path, auth_mtime: float, max_bytes: int = 8192) -> bool:
    """Return true only for 401s that happened after the current auth file.

    Codex live logs can keep being touched after OWNER refreshes `codex login`,
    so comparing only the log file mtime to auth.json mtime keeps stale 401s
    alive until the log ages out. Most Codex log lines start with an ISO UTC
    timestamp; use that when available.
    """
    pattern = re.compile(rb"401 Unauthorized")
    timestamp = re.compile(rb"^(\d{4}-\d{2}-\d{2}T\d{2}:\d{2}:\d{2}(?:\.\d+)?Z)\b")
    log_mtime = log.stat().st_mtime
    with open(log, "rb") as fh:
        fh.seek(max(0, log.stat().st_size - max_bytes))
        tail = fh.read()
    for line in tail.splitlines():
        if not pattern.search(line):
            continue
        if auth_mtime <= 0:
            return True
        m = timestamp.match(line)
        if not m:
            continue
        try:
            seen_at = dt.datetime.fromisoformat(
                m.group(1).decode("ascii").replace("Z", "+00:00")
            ).timestamp()
        except (ValueError, UnicodeDecodeError):
            continue
        if seen_at >= auth_mtime:
            return True
    return False


def _codex_401_cutoff_mtime(auth_mtime: float) -> float:
    """Ignore 401s older than the currently deployed Codex spawn/auth setup."""
    cutoff = auth_mtime
    for path in (Path(__file__), REPO_ROOT / "tools" / "strategy_farm" / "farmctl.py"):
        try:
            cutoff = max(cutoff, path.stat().st_mtime)
        except OSError:
            pass
    return cutoff


def _json_obj(raw: str | None) -> dict:
    if not raw:
        return {}
    try:
        data = json.loads(raw)
    except (TypeError, json.JSONDecodeError):
        return {}
    return data if isinstance(data, dict) else {}


def _codex_review_payload_unreviewable(payload: dict) -> bool:
    """True when a codex_review FAIL came from missing/blocked build artifacts."""
    build_result_path = payload.get("build_result_path")
    if build_result_path:
        br_path = Path(str(build_result_path))
        if not br_path.exists():
            return True
        try:
            build_result = json.loads(br_path.read_text(encoding="utf-8-sig"))
        except (OSError, json.JSONDecodeError):
            return True
        if build_result.get("blocked_reason"):
            return True
        for key in ("mq5_path", "ex5_path"):
            p = build_result.get(key)
            if not p or not Path(str(p)).exists():
                return True
    for key in ("mq5_path", "ex5_path"):
        p = payload.get(key)
        if not p or not Path(str(p)).exists():
            return True
    return False


def _card_frontmatter(path: Path) -> dict[str, str]:
    try:
        text = path.read_text(encoding="utf-8", errors="ignore")
    except OSError:
        return {}
    if not text.startswith("---"):
        return {}
    parts = text.split("---", 2)
    if len(parts) < 3:
        return {}
    fm: dict[str, str] = {}
    for line in parts[1].splitlines():
        if ":" not in line:
            continue
        key, value = line.split(":", 1)
        fm[key.strip()] = value.strip().strip("\"'")
    return fm


def _cards_for_source(source_id: str) -> dict[str, list[Path]]:
    found = {"draft": [], "approved": [], "rejected": []}
    for state, subdir in (
        ("draft", "cards_draft"),
        ("approved", "cards_approved"),
        ("rejected", "cards_rejected"),
    ):
        d = ROOT / "artifacts" / subdir
        if not d.is_dir():
            continue
        for card_path in d.glob("*.md"):
            if _card_frontmatter(card_path).get("source_id") == source_id:
                found[state].append(card_path)
    return found


def _card_pipeline_done(con, card_path: Path, state: str) -> bool:
    if state == "rejected":
        return True
    if state == "draft":
        return False
    fm = _card_frontmatter(card_path)
    ea_id = fm.get("ea_id")
    if not ea_id:
        m = re.match(r"(QM5_\d{4,5})_", card_path.name)
        ea_id = m.group(1) if m else ""
    if not ea_id:
        return False

    rows = con.execute(
        "SELECT kind, status, payload_json FROM tasks WHERE card_id=? ORDER BY created_at ASC",
        (ea_id,),
    ).fetchall()
    build_task = next((r for r in rows if r["kind"] == "build_ea"), None)
    review_task = next((r for r in rows if r["kind"] == "ea_review"), None)
    backtest_task = next((r for r in rows if str(r["kind"]).startswith("backtest_")), None)

    if build_task is None:
        return False
    if build_task["status"] in ("failed", "blocked"):
        return True
    if build_task["status"] != "done":
        return False
    if review_task is None or review_task["status"] != "done":
        return False

    review_payload = _json_obj(review_task["payload_json"])
    verdict_doc = review_payload.get("verdict") or {}
    if isinstance(verdict_doc, str):
        verdict = verdict_doc
    elif isinstance(verdict_doc, dict):
        verdict = str(verdict_doc.get("verdict") or "")
    else:
        verdict = ""
    if verdict != "APPROVE_FOR_BACKTEST":
        return False

    if backtest_task is None:
        return False
    return backtest_task["status"] in ("done", "failed", "blocked")


def _cards_ready_resume_summary(con, source_id: str) -> dict[str, int]:
    cards = _cards_for_source(source_id)
    total = 0
    done = 0
    for state, paths in cards.items():
        for card_path in paths:
            total += 1
            if _card_pipeline_done(con, card_path, state):
                done += 1
    return {"total": total, "done": done, "in_flight": total - done}


def _summary_net_profit_total(summary: dict) -> float | None:
    runs = summary.get("runs")
    if isinstance(runs, list) and runs:
        total = 0.0
        seen = False
        for run in runs:
            if not isinstance(run, dict):
                continue
            value = run.get("net_profit")
            try:
                total += float(value)
                seen = True
            except (TypeError, ValueError):
                continue
        if seen:
            return total
    for key in ("net_profit", "profit"):
        try:
            return float(summary[key])
        except (KeyError, TypeError, ValueError):
            continue
    return None


def _work_item_p2_net_profit(row: sqlite3.Row) -> float | None:
    payload = _json_obj(row["payload_json"])
    recovered = payload.get("recovered_stats")
    if isinstance(recovered, dict):
        try:
            return float(recovered["net_profit"])
        except (KeyError, TypeError, ValueError):
            pass
    evidence_path = row["evidence_path"]
    if not evidence_path:
        return None
    path = Path(evidence_path)
    if not path.exists():
        return None
    try:
        summary = json.loads(path.read_text(encoding="utf-8-sig"))
    except (OSError, json.JSONDecodeError):
        return None
    return _summary_net_profit_total(summary if isinstance(summary, dict) else {})


def _is_zero_trade_failure_payload(payload_json: str | None, evidence_path: str | None) -> bool:
    invalid_report_reasons = {"NO_HISTORY", "NO_REAL_TICKS", "INVALID_REPORT"}
    if payload_json and "MIN_TRADES_NOT_MET" in payload_json:
        data = _json_obj(payload_json)
        reason_classes = data.get("reason_classes") or []
        explicit_reasons = {
            str(data.get("verdict_reason") or "").upper(),
            str(data.get("reason_class") or "").upper(),
            str(data.get("reason") or "").upper(),
        }
        explicit_reasons.update(str(r).upper() for r in reason_classes)
        if explicit_reasons & invalid_report_reasons:
            return False
        return True
    if not evidence_path:
        return False
    path = Path(evidence_path)
    if not path.exists() or path.stat().st_size <= 0:
        return False
    try:
        text = path.read_text(encoding="utf-8", errors="ignore")
    except OSError:
        return False
    if "MIN_TRADES_NOT_MET" in text:
        return not any(reason in text for reason in invalid_report_reasons)
    try:
        data = json.loads(text)
    except json.JSONDecodeError:
        return False
    if not isinstance(data, dict):
        return False
    reason_classes = data.get("reason_classes") or []
    if any(str(r).upper() in invalid_report_reasons for r in reason_classes):
        return False
    if any(str(r).upper() == "MIN_TRADES_NOT_MET" for r in reason_classes):
        return True
    reason = str(data.get("reason_class") or data.get("reason") or "").upper()
    if reason in invalid_report_reasons:
        return False
    return "MIN_TRADES_NOT_MET" in reason


def _build_lane_block_reason(con) -> tuple[str | None, str]:
    """Why the codex BUILD lane would be blocked right now, INDEPENDENT of auth.

    Returns (reason, detail) with reason in {'dirty_guard', 'backpressure', None}.
    Lets chk_codex_auth_broken stop mislabeling a dirty-guard / backpressure build
    stall as an auth failure — auth is judged separately by the 401 signal. The #1
    recurring build-stall cause is repo_dirty_build_guard, NOT auth
    (project_qm_dirty_guard_build_deadlock 2026-06-04/09)."""
    try:
        dirty = farmctl._repo_dirty_status()
        if dirty.get("blocked"):
            entries = dirty.get("entries") or []
            n = dirty.get("count", len(entries))
            return "dirty_guard", (
                f"repo_dirty_build_guard blocked by {n} uncommitted file(s): "
                f"{', '.join(e.strip() for e in entries[:3])}")
    except Exception:
        pass
    try:
        pending = con.execute("SELECT COUNT(*) FROM work_items WHERE status='pending'").fetchone()[0]
        active = con.execute("SELECT COUNT(*) FROM work_items WHERE status='active'").fetchone()[0]
        soft = farmctl.BUILD_BACKPRESSURE_PENDING_SOFT_LIMIT
        hard = farmctl.BUILD_BACKPRESSURE_PENDING_HARD_LIMIT
        act_thr = farmctl.BUILD_BACKPRESSURE_ACTIVE_WORK_ITEM_LIMIT
        if pending >= hard or (pending >= soft and active >= act_thr):
            return "backpressure", (
                f"new builds intentionally paused by backpressure "
                f"({pending} pending work_items, {active} active)")
    except Exception:
        pass
    return None, ""


def _is_codex_auth_broken(con) -> bool:
    """Shared helper: TRUE only when auth is genuinely the cause (real 401s, or a
    silent+stale pipeline NOT explained by the dirty-guard/backpressure). Used by
    downstream checks for cascade suppression — so a dirty-guard/backpressure stall
    no longer masquerades as 'codex_auth_broken upstream'."""
    import time as _t
    auth_path = CODEX_AUTH
    auth_mtime = auth_path.stat().st_mtime if auth_path.exists() else 0.0
    cutoff_mtime = _codex_401_cutoff_mtime(auth_mtime)
    n_401 = 0
    for log in LOG_DIR.glob("codex_*.live.log"):
        try:
            log_mtime = log.stat().st_mtime
            if _t.time() - log_mtime > 900:
                continue
            if _tail_has_current_codex_401(log, cutoff_mtime):
                n_401 += 1
        except OSError:
            continue
    auth_age_h = None
    if auth_path.exists():
        try:
            auth_age_h = (_t.time() - auth_mtime) / 3600
        except OSError:
            pass
    n_pending = con.execute(
        "SELECT COUNT(*) FROM tasks WHERE kind='build_ea' AND status='pending'"
    ).fetchone()[0]
    # Real "codex is alive" signal: a build_ea task reached a terminal state
    # (done OR failed — both prove codex spawned and ran) in the last 3h. The old
    # heuristic counted live `codex` processes, but those are transient (one per
    # build, gone between builds) so an instantaneous 0 is normal; and auth.json
    # mtime is not rewritten on every use (long-lived access token), so file age
    # is a poor proxy. Together they cried wolf while builds were flowing.
    cutoff_3h = (_utc_now() - dt.timedelta(hours=3)).strftime("%Y-%m-%dT%H:%M:%SZ")
    recent_build_activity = con.execute(
        "SELECT COUNT(*) FROM tasks WHERE kind='build_ea' "
        "AND status IN ('done','failed') AND updated_at >= ?", (cutoff_3h,)
    ).fetchone()[0]
    if n_401 >= 2:
        return True
    silent = (n_pending >= 1 and recent_build_activity == 0
              and auth_age_h is not None and auth_age_h > 12)
    if silent:
        # Only count silence as auth when the build lane is NOT blocked by the
        # dirty-guard or throttled by backpressure (those are the real, non-auth causes).
        reason, _ = _build_lane_block_reason(con)
        return reason is None
    return False


def chk_codex_review_fail_rate(con) -> dict:
    """Codex review FAIL rate. Distinguish two classes:

    SYSTEM FAIL — phantom field check, schema drift, prompt-vs-producer
      mismatch. Fire RED. Example past incident: build_result missing
      `status` field that didn't exist.

    STRATEGY QUALITY — smoke_sanity 0-trade etc. The review IS doing its
      job catching weak strategy ideas. Pump §4b short-circuits these
      before codex_review is even spawned, but if some leak through that's
      not a system bug, just normal upstream noise. WARN/OK, not FAIL.

    Method: count FAILs by section. If section_fails are dominated by
    smoke_sanity (≥80% of FAILs touch it and no other section), call it
    strategy-quality. Else system.
    """
    cutoff = (_utc_now() - dt.timedelta(hours=1)).strftime("%Y-%m-%dT%H:%M:%SZ")
    rows = con.execute(
        "SELECT payload_json, updated_at FROM tasks WHERE kind='codex_review' AND status='done' "
        "AND updated_at >= ?", (cutoff,)
    ).fetchall()
    n = len(rows)
    n_fail = 0
    fails_smoke_only = 0
    fails_other = 0
    system_fail_cards: set[str] = set()
    for r in rows:
        try:
            p = json.loads(r["payload_json"])
        except Exception:
            continue
        if (p.get("verdict") or "").upper() != "FAIL":
            continue
        if _codex_review_payload_unreviewable(p):
            continue
        mq5_path = p.get("mq5_path")
        reviewed_at = _parse_utc_ts(r["updated_at"])
        if mq5_path and reviewed_at:
            try:
                source_mtime = dt.datetime.fromtimestamp(Path(mq5_path).stat().st_mtime, dt.timezone.utc)
            except OSError:
                source_mtime = None
            if source_mtime and source_mtime > reviewed_at:
                continue
        reviewed_at = reviewed_at or _parse_utc_ts(r["updated_at"])
        if reviewed_at:
            prompt_path = REPO_ROOT / "tools" / "strategy_farm" / "prompts" / "codex_review_ea.md"
            try:
                prompt_mtime = dt.datetime.fromtimestamp(prompt_path.stat().st_mtime, dt.timezone.utc)
            except OSError:
                prompt_mtime = None
            if prompt_mtime and prompt_mtime > reviewed_at:
                continue
        n_fail += 1
        secs = p.get("sections") or {}
        failed_secs = {k for k, v in secs.items() if v == "FAIL"}
        if not failed_secs:
            continue
        # Strategy-quality classification: ONLY smoke_sanity (or smoke + build_result
        # which co-fail when smoke had 0 trades) failed
        if failed_secs and failed_secs.issubset({"smoke_sanity", "build_result"}):
            fails_smoke_only += 1
        else:
            fails_other += 1
            card_id = str(p.get("ea_id") or p.get("card_id") or p.get("build_task_id") or "UNKNOWN")
            system_fail_cards.add(card_id)
    rate = n_fail / n if n > 0 else 0
    if n < 3:
        return _check("codex_review_fail_rate_1h", "OK", round(rate, 2), 0.8,
                      f"{n_fail}/{n} FAIL (low volume)", "")
    if len(system_fail_cards) >= 2:
        return _check("codex_review_fail_rate_1h", "FAIL", round(rate, 2), 0.8,
                      f"{fails_other}/{n} system-class FAILs across {len(system_fail_cards)} EAs in last hour",
                      "Inspect verdicts that FAIL on framework_corset, magic_registry, "
                      "or forbidden_grep — those indicate Codex producing bad code or "
                      "a schema drift, NOT just strategy quality")
    if fails_other >= 1:
        return _check("codex_review_fail_rate_1h", "WARN", round(rate, 2), 0.8,
                      f"{fails_other}/{n} system-class FAIL(s) on one EA: {', '.join(sorted(system_fail_cards))}",
                      "One EA is blocked for mechanical rework; watch for recurrence on a second EA.")
    if rate >= 0.8 and fails_smoke_only >= 3:
        # All FAILs are strategy-quality (0-trade). Pump §4b should be
        # short-circuiting most of these BEFORE codex_review now, so this
        # rate should drop. Surface as WARN.
        return _check("codex_review_fail_rate_1h", "WARN", round(rate, 2), 0.8,
                      f"{fails_smoke_only}/{n} FAIL all on smoke_sanity (strategy quality)",
                      "Strategies producing 0 trades. Pump §4b will short-circuit "
                      "future ones before codex_review spawns. Watch the pattern — "
                      "if persists, consider tightening G0 trade-frequency check.")
    return _check("codex_review_fail_rate_1h", "OK", round(rate, 2), 0.8,
                  f"{n_fail}/{n} FAIL ({fails_smoke_only} strategy-quality, {fails_other} system)", "")


def chk_cards_ready_stagnation(con) -> dict:
    """Sources stuck in cards_ready > 4h.

    `cards_ready` is an intentional pause while that source's current card
    batch moves through G0/build/review/P2. Only alarm when the source has no
    traceable cards or when all cards reached pipeline-end and resume-mining
    still did not flip it back to active.
    """
    auth_broken = _is_codex_auth_broken(con)

    cutoff = (_utc_now() - dt.timedelta(hours=4)).strftime("%Y-%m-%dT%H:%M:%SZ")
    rows = con.execute(
        "SELECT id, title, updated_at FROM sources "
        "WHERE status='cards_ready' AND updated_at < ?", (cutoff,)
    ).fetchall()
    actionable = []
    waiting = 0
    for r in rows:
        summary = _cards_ready_resume_summary(con, r["id"])
        if summary["total"] == 0 or summary["in_flight"] == 0:
            actionable.append((r, summary))
        else:
            waiting += 1
    n = len(actionable)
    if auth_broken and n >= 1:
        return _check("cards_ready_stagnation", "WARN", n, 3,
                      f"{n} actionable cards_ready sources (codex_auth_broken upstream), {waiting} waiting on in-flight cards",
                      "Will resume once OWNER runs `codex login` and codex circuit breaker clears")
    if n >= 3:
        return _check("cards_ready_stagnation", "FAIL", n, 3,
                      f"{n} actionable cards_ready sources need resume/reconciliation; {waiting} legitimately waiting",
                      "Run `python tools/strategy_farm/farmctl.py resume-mining`; if still present, "
                      "fix missing source_id frontmatter or stuck resume state.")
    if n >= 1:
        return _check("cards_ready_stagnation", "WARN", n, 1,
                      f"{n} actionable cards_ready source(s), {waiting} waiting on in-flight cards",
                      "Next resume-mining cycle should flip actionable sources back to active.")
    detail = "no actionable stagnation"
    if waiting:
        detail = f"{waiting} old cards_ready source(s) waiting on in-flight cards"
    return _check("cards_ready_stagnation", "OK", 0, 3, detail, "")


def _pid_alive_no_signal(pid: int) -> bool:
    """PID liveness via OpenProcess/GetExitCodeProcess. Never use os.kill(pid, 0)
    on Windows — CPython maps unsupported signals to TerminateProcess and can
    kill the probed process (see run_agent_orchestration_task.process_alive)."""
    if pid <= 0 or sys.platform != "win32":
        return False
    import ctypes
    PROCESS_QUERY_LIMITED_INFORMATION = 0x1000
    STILL_ACTIVE = 259
    handle = ctypes.windll.kernel32.OpenProcess(
        PROCESS_QUERY_LIMITED_INFORMATION, False, int(pid))
    if not handle:
        return False
    try:
        code = ctypes.c_ulong()
        ok = ctypes.windll.kernel32.GetExitCodeProcess(handle, ctypes.byref(code))
        return bool(ok) and code.value == STILL_ACTIVE
    finally:
        ctypes.windll.kernel32.CloseHandle(handle)


def chk_work_items_timestamp_sanity(con) -> dict:
    """Future created_at or non-ISO updated_at rows in work_items.

    Recommended by FULL_SYSTEM_FTMO_READINESS_AUDIT_2026-07-09 (3 rows then),
    never implemented; the anomaly grew 63x to 189 before the 2026-07-24 audit
    repaired it (evidence: docs/ops/source_harvest/audit/evidence/dbrepair__*.json).
    Guard against recurrence: any writer stamping sentinel/epoch timestamps."""
    horizon = (dt.datetime.now(dt.timezone.utc) + dt.timedelta(days=1)).isoformat()
    n_future = con.execute(
        "SELECT COUNT(*) FROM work_items WHERE created_at > ?", (horizon,)).fetchone()[0]
    n_noniso = con.execute(
        "SELECT COUNT(*) FROM work_items WHERE updated_at NOT LIKE '____-__-__%' "
        "OR created_at NOT LIKE '____-__-__%'").fetchone()[0]
    total = int(n_future) + int(n_noniso)
    if total:
        return _check("work_items_timestamp_sanity", "WARN", total, 0,
                      f"{n_future} future created_at + {n_noniso} non-ISO timestamp rows",
                      "Find the writer (enqueue path) stamping bad timestamps; repair per "
                      "docs/ops/source_harvest/audit/evidence/dbrepair__before.json pattern")
    return _check("work_items_timestamp_sanity", "OK", 0, 0, "timestamps sane", "")


def chk_pump_task_health() -> dict:
    """Scheduled task QM_StrategyFarm_Pump_5min LastResult must be 0, and the
    pump lock must not be orphaned by a dead PID (audit 2026-07-24 FB-06: a
    killed pump run left logs/pump_task.lock behind; 3 cycles silently no-opped
    on the not-yet-stale lock while LastResult=0 masked the outage)."""
    try:
        out = subprocess.run(
            ["powershell.exe", "-NoProfile", "-Command",
             "(Get-ScheduledTaskInfo -TaskName 'QM_StrategyFarm_Pump_5min').LastTaskResult"],
            capture_output=True, text=True, timeout=15,
            creationflags=_creationflags_no_window(),
        )
        result = int((out.stdout or "0").strip() or "0")
    except Exception as exc:
        return _check("pump_task_lastresult", "WARN", "?", 0,
                      f"could not query task: {exc}",
                      "Run Get-ScheduledTask QM_StrategyFarm_Pump_5min manually")
    if result == 267009:  # 0x41301, Task Scheduler: task is currently running.
        return _check("pump_task_lastresult", "OK", result, 0,
                      "pump task currently running", "")
    if result != 0:
        return _check("pump_task_lastresult", "FAIL", result, 0,
                      f"pump last exit code {result} (non-zero)",
                      "Run canonical pump manually: python C:\\QM\\repo\\tools\\strategy_farm\\farmctl.py pump; "
                      "check error output. Code 112 = ERROR_DISK_FULL (also: any script abort)")
    lock_path = ROOT / "logs" / "pump_task.lock"
    if lock_path.exists():
        try:
            age_sec = dt.datetime.now().timestamp() - lock_path.stat().st_mtime
            pid_txt = lock_path.read_text(encoding="ascii", errors="ignore").strip()
            pid = int(pid_txt) if pid_txt.isdigit() else 0
        except OSError:
            age_sec, pid = 0.0, 0
        if not _pid_alive_no_signal(pid):
            # run_pump_task LOCK_STALE_SECONDS=1200 self-heals; beyond that a
            # surviving lock means the staleness path itself is broken -> FAIL.
            sev = "FAIL" if age_sec > 1200 else "WARN"
            return _check("pump_task_lastresult", sev, f"orphan_lock_pid={pid}", 0,
                          f"pump_task.lock held by dead PID {pid}, age {int(age_sec)}s; "
                          "pump cycles no-op until the 1200s stale threshold clears it",
                          "If FAIL: verify no pump is running, then delete "
                          "D:\\QM\\strategy_farm\\logs\\pump_task.lock")
    return _check("pump_task_lastresult", "OK", 0, 0, "last run exit 0", "")


def chk_factory_mutation_lock() -> dict:
    """Alarm on a stale global mutation lock without mutating farm state."""

    snapshot = inspect_factory_mutation_lock(FACTORY_MUTATION_LOCK_PATH)
    state = str(snapshot.get("status") or "unknown")
    age_value = snapshot.get("age_seconds")
    age_known = isinstance(age_value, (int, float))
    age_seconds = float(age_value) if age_known else 0.0
    record = snapshot.get("record") if isinstance(snapshot.get("record"), dict) else {}
    pid = record.get("pid", "?")
    owner = record.get("owner", "?")
    value = f"{state}:pid={pid}:age={int(age_seconds)}s"

    if state == "absent":
        return _check(
            "factory_mutation_lock",
            "OK",
            "absent",
            int(FACTORY_MUTATION_LOCK_DEAD_FAIL_SECONDS),
            "global mutation lock absent",
            "",
        )

    if state in {"dead", "reused"}:
        severity = (
            "FAIL"
            if age_seconds >= FACTORY_MUTATION_LOCK_DEAD_FAIL_SECONDS
            else "WARN"
        )
        return _check(
            "factory_mutation_lock",
            severity,
            value,
            int(FACTORY_MUTATION_LOCK_DEAD_FAIL_SECONDS),
            f"mutation lock owner {owner!r} PID {pid} is {state}; "
            f"record age {int(age_seconds)}s",
            "Let the next normal mutator perform the audited content-CAS reap; "
            "then inspect D:\\QM\\reports\\state\\mutation_lock_reaps.jsonl. "
            "Do not delete a live or unreadable lock.",
        )

    if state == "invalid":
        severity = (
            "FAIL"
            if age_seconds >= FACTORY_MUTATION_LOCK_DEAD_FAIL_SECONDS
            else "WARN"
        )
        return _check(
            "factory_mutation_lock",
            severity,
            value,
            int(FACTORY_MUTATION_LOCK_DEAD_FAIL_SECONDS),
            f"readable mutation lock has an invalid record, age {int(age_seconds)}s: "
            f"{snapshot.get('error', 'unknown parse error')}",
            "Inspect the record and owner identity; automatic reap deliberately "
            "fails closed for invalid content.",
        )

    # A currently held Windows lock is deliberately unreadable because its live
    # owner denies sharing. Prolonged live/unreadable ownership warns, but is
    # never reaped or promoted to dead-holder FAIL without positive PID proof.
    if state in {"live", "unreadable", "unknown"}:
        severity = (
            "WARN"
            if (
                not age_known
                or age_seconds >= FACTORY_MUTATION_LOCK_LIVE_WARN_SECONDS
            )
            else "OK"
        )
        detail = (
            f"mutation lock state={state}, owner={owner!r}, PID={pid}, "
            f"age={int(age_seconds)}s"
        )
        if state == "unreadable":
            detail += "; no-sharing handle may be held by a live mutator"
            if not age_known:
                detail += "; lock age could not be inspected"
        return _check(
            "factory_mutation_lock",
            severity,
            value,
            int(FACTORY_MUTATION_LOCK_LIVE_WARN_SECONDS),
            detail,
            (
                "If the age keeps rising, identify the owning mutator and wait for "
                "its guarded operation; never reap without a readable record and "
                "positive dead-PID proof."
                if severity == "WARN"
                else ""
            ),
        )

    return _check(
        "factory_mutation_lock",
        "WARN",
        value,
        int(FACTORY_MUTATION_LOCK_LIVE_WARN_SECONDS),
        f"unexpected mutation lock inspection state: {state}",
        "Inspect FACTORY_MUTATION.lock and health check implementation.",
    )


def chk_factory_on_ceremony_incomplete() -> dict:
    """Fail while a Factory_ON mutation window lacks certified completion."""

    path = FACTORY_ON_CEREMONY_INCOMPLETE_PATH
    try:
        if not path.exists():
            return _check(
                "factory_on_ceremony_incomplete",
                "OK",
                "absent",
                "absent",
                "Factory_ON ceremony-incomplete marker absent",
                "",
            )
        if not path.is_file():
            raise ValueError("marker path exists but is not a regular file")
        payload = json.loads(path.read_text(encoding="utf-8-sig"))
        if not isinstance(payload, dict):
            raise ValueError("marker root is not an object")
    except (OSError, UnicodeError, json.JSONDecodeError, ValueError) as exc:
        return _check(
            "factory_on_ceremony_incomplete",
            "FAIL",
            "invalid",
            "absent",
            f"Factory_ON ceremony marker is present but invalid/unreadable: {exc}",
            "Treat the factory as CRITICAL. Do not enable orchestration tasks manually; "
            "inspect the marker and the last Factory_ON attempt.",
        )

    expected_tasks = {
        "QM_StrategyFarm_CodexOrchestration_15min",
        "QM_StrategyFarm_GeminiOrchestration_15min",
        "QM_StrategyFarm_ClaudeOrchestration_15min",
        "QM_StrategyFarm_CodexFleetPacer",
        "QM_StrategyFarm_AgyGovernor",
    }
    observed_tasks = payload.get("quiet_zone_tasks")
    observed_task_set = (
        {str(item) for item in observed_tasks}
        if isinstance(observed_tasks, list)
        else set()
    )
    identity_valid = (
        payload.get("schema_version") == 1
        and payload.get("kind") == "qm.factory_on_ceremony_incomplete"
        and payload.get("state") == "CRITICAL"
        and payload.get("quiet_zone_release_certified") is False
        and observed_task_set == expected_tasks
    )
    ceremony_id = str(payload.get("ceremony_id") or "unknown")
    created_at = str(payload.get("created_at_utc") or "unknown")
    identity_note = "valid" if identity_valid else "INVALID"
    return _check(
        "factory_on_ceremony_incomplete",
        "FAIL",
        ceremony_id,
        "absent",
        "Factory_ON ceremony is incomplete; AI orchestration quiet-zone release is "
        f"not certified (marker={identity_note}, created_at={created_at}, "
        f"ceremony_id={ceremony_id}).",
        "Treat this as CRITICAL. Do not enable lanes manually. Claude must inspect "
        "the failed ceremony and use a fresh OWNER-authorized canonical Factory_ON "
        "decision; only a fully successful ceremony clears the marker.",
    )


CUSTOM_HISTORY_REPAIR_WARN_24H = 10
CUSTOM_HISTORY_REPAIR_FAIL_24H = 50


def chk_custom_history_repairs() -> dict:
    """DL-085 self-heal telemetry: archive repairs are routine, a RISING rate
    means a new eater class is active and needs forensics before it outruns
    the master tree's ability to vouch."""
    try:
        from custom_history_master import count_recent_repairs
    except ImportError:  # pragma: no cover
        from tools.strategy_farm.custom_history_master import count_recent_repairs
    try:
        count = count_recent_repairs(ROOT, hours=24.0)
    except Exception as exc:
        return _check("custom_history_repairs_24h", "WARN", "unreadable", CUSTOM_HISTORY_REPAIR_WARN_24H,
                      f"repair receipts unreadable: {exc!r}",
                      "Inspect state/custom_history_repairs.jsonl")
    status = "OK"
    if count > CUSTOM_HISTORY_REPAIR_FAIL_24H:
        status = "FAIL"
    elif count > CUSTOM_HISTORY_REPAIR_WARN_24H:
        status = "WARN"
    return _check(
        "custom_history_repairs_24h",
        status,
        count,
        CUSTOM_HISTORY_REPAIR_WARN_24H,
        f"{count} master-repairs in 24h (DL-085 self-heal)",
        "" if status == "OK" else
        "Rising repair rate = active archive eater; run dual forensics "
        "(docs/ops/evidence/2026-08-14_claude_archive_eater_forensics.md) "
        "before it exceeds master coverage.",
    )


def chk_usn_journal_d() -> dict:
    """The 08-14 forensics died on D: having no USN journal. Keep it alive."""
    try:
        proc = subprocess.run(
            ["fsutil", "usn", "queryjournal", "D:"],
            capture_output=True, text=True, timeout=20,
            creationflags=_creationflags_no_window(),
        )
    except (OSError, subprocess.SubprocessError) as exc:
        return _check("usn_journal_d", "WARN", "probe_error", 0,
                      f"fsutil probe failed: {exc!r}", "")
    active = proc.returncode == 0
    return _check(
        "usn_journal_d",
        "OK" if active else "FAIL",
        "active" if active else "absent",
        0,
        "NTFS change journal on D:" + (" active" if active else " ABSENT - deletions are forensically invisible"),
        "" if active else "fsutil usn createjournal m=0x8000000 a=0x800000 D: (admin)",
    )


def chk_p2_pass_no_p3(con) -> dict:
    """Profitable Q02-PASS work_items that lack a corresponding Q03 work_item.

    Q02 PASS only means the smoke/backtest completed and met the minimum
    trade gate. Rows with non-positive net profit are intentionally not
    promoted by the pump profit filter, so the detector must not count them
    as stranded promotion work.
    """
    rows = con.execute(
        """
        SELECT w.* FROM work_items w
        WHERE w.status='done' AND w.verdict='PASS' AND w.phase IN ('P2', 'Q02')
          AND NOT EXISTS (
            SELECT 1 FROM work_items w2
            WHERE w2.ea_id=w.ea_id
              AND w2.symbol=w.symbol
              AND w2.setfile_path=w.setfile_path
              AND w2.phase IN ('P3', 'Q03')
          )
        """
    ).fetchall()
    promotable = [r for r in rows if (_work_item_p2_net_profit(r) or 0.0) > 0.0]
    n = len(promotable)
    if n >= 10:
        return _check("p2_pass_no_p3", "FAIL", n, 10,
                      f"{n} profitable Q02-PASS work_items without Q03 promotion",
                      "Pump §10c is failing or backlogged; run farmctl pump manually")
    if n >= 3:
        return _check("p2_pass_no_p3", "WARN", n, 3,
                      f"{n} profitable Q02-PASS without Q03 promotion (pump catches up gradually)",
                      "Next pump cycle (≤5 min) should promote them")
    return _check("p2_pass_no_p3", "OK", n, 10, f"{n} pending promotion", "")


def chk_ea_metrics_fresh(con) -> dict:
    """ea_metrics is the normalized metric layer that powers the Strategy Archive
    (real Net/PF/trades on ea_<id>.html + strategies.html) AND the §10c Q02->Q03
    promotion profit pre-filter. It is refreshed inline by the 5-min pump and the
    hourly dashboard render — both wrapped in try/except, so a silent extractor
    failure would leave it stale: blank archive numbers and (worse) missed
    profitable promotions. This makes that staleness observable.

    Docs: docs/ops/EA_METRICS_ARCHIVE_LAYER_2026-06-22.md.
    """
    STALE_MIN = 90  # pump refreshes every 5min; >90min ⇒ both refreshers failing
    tbl = con.execute(
        "SELECT name FROM sqlite_master WHERE type='table' AND name='ea_metrics'"
    ).fetchone()
    if not tbl:
        return _check("ea_metrics_fresh", "WARN", None, STALE_MIN,
                      "ea_metrics table absent — Strategy Archive numbers blank, "
                      "Q02→Q03 promotion falls back to legacy scan",
                      "python tools/strategy_farm/ea_metrics.py build --full")
    row = con.execute(
        "SELECT COUNT(1) AS n, MAX(extracted_at) AS last FROM ea_metrics"
    ).fetchone()
    count = row["n"] or 0
    last = _parse_utc_ts(row["last"])
    if count == 0 or last is None:
        return _check("ea_metrics_fresh", "WARN", count, STALE_MIN,
                      "ea_metrics empty / no extracted_at — extractor has not run",
                      "python tools/strategy_farm/ea_metrics.py build --full")
    age_min = int((_utc_now() - last).total_seconds() // 60)
    if age_min > STALE_MIN:
        return _check("ea_metrics_fresh", "WARN", age_min, STALE_MIN,
                      f"ea_metrics last refreshed {age_min}m ago (>{STALE_MIN}m); "
                      f"pump §10c / render refresh likely failing ({count} rows)",
                      "Run python tools/strategy_farm/ea_metrics.py build and check "
                      "pump logs; see docs/ops/EA_METRICS_ARCHIVE_LAYER_2026-06-22.md")
    return _check("ea_metrics_fresh", "OK", age_min, STALE_MIN,
                  f"{count} rows, refreshed {age_min}m ago", "")


def chk_ablation_grandchildren(con) -> dict:
    """work_items whose setfile_path has TWO `_ablation_` or `_grid_` tokens
    = depth-tracker bug, ablation child got re-ablated."""
    rows = con.execute("SELECT id, setfile_path FROM work_items WHERE status='pending'").fetchall()
    pat = re.compile(r"(_ablation_|_grid_).*(_ablation_|_grid_)")
    n = sum(1 for r in rows if r["setfile_path"] and pat.search(r["setfile_path"]))
    if n > 0:
        return _check("ablation_grandchildren", "FAIL", n, 0,
                      f"{n} work_items have grandchild setfile names",
                      "Depth filter regressed — check pump §10a/§10b setfile_path NOT LIKE clauses")
    return _check("ablation_grandchildren", "OK", 0, 0, "no grandchildren", "")


def _parse_task_payload(payload_json) -> dict | None:
    """RATIFIED payload contract for the starvation check (2026-07-26, batch-3
    review): only VALID JSON OBJECTS count, and keys are read at TOP LEVEL only.
    This deliberately supersedes the legacy SQL LIKE substring semantics (which
    were format-sensitive on JSON spacing yet case-insensitive on the verdict):
    the farm's own task writers emit canonical flat json.dumps objects, so a
    malformed payload is producer breakage to surface elsewhere, not signal."""
    try:
        parsed = json.loads(payload_json or "")
    except (TypeError, ValueError):
        return None
    return parsed if isinstance(parsed, dict) else None


def _count_starved_builds(tasks) -> int:
    """Count done build_ea tasks that a done codex_review PASSed (top-level
    verdict == "PASS", case-sensitive, naming the build via top-level
    build_task_id) but that no ea_review of ANY status covers."""
    builds: list[str] = []
    codex_passed: set[str] = set()
    reviewed: set[str] = set()
    for t in tasks:
        kind = t["kind"]
        if kind == "build_ea":
            if t["status"] == "done":
                builds.append(t["id"])
        elif kind == "codex_review":
            if t["status"] == "done":
                p = _parse_task_payload(t["payload_json"])
                tid = p.get("build_task_id") if p else None
                # build_task_id must be a non-empty STRING (batch-4 review: a
                # list/dict-valued ID crashed the check instead of not matching)
                if p and p.get("verdict") == "PASS" and isinstance(tid, str) and tid:
                    codex_passed.add(tid)
        elif kind == "ea_review":
            p = _parse_task_payload(t["payload_json"])
            tid = p.get("build_task_id") if p else None
            if isinstance(tid, str) and tid:
                reviewed.add(tid)
    return sum(1 for b in builds if b in codex_passed and b not in reviewed)


def chk_claude_review_starved(con) -> dict:
    """Lots of done builds with passing codex_review but no Claude review
    spawn — Claude is silently absent or the gate logic is wrong."""
    cutoff = (_utc_now() - dt.timedelta(hours=4)).strftime("%Y-%m-%dT%H:%M:%SZ")
    # Build_ea done with PASSed codex_review but no ea_review yet — in-memory
    # resolution (replaces the old N^2 LIKE scan) under the RATIFIED payload
    # contract documented on _parse_task_payload / _count_starved_builds.
    tasks = con.execute(
        "SELECT id, kind, status, payload_json FROM tasks "
        "WHERE kind IN ('build_ea', 'codex_review', 'ea_review')"
    ).fetchall()
    n_starved = _count_starved_builds(tasks)

    # Last claude_review spawn (any kind) — proxy via ea_review tasks created
    n_recent = con.execute(
        "SELECT COUNT(*) FROM tasks WHERE kind='ea_review' AND created_at >= ?",
        (cutoff,),
    ).fetchone()[0]
    if (ROOT / "CLAUDE_DISABLED.flag").exists():
        return _check("claude_review_starved", "OK", n_starved, 5,
                      f"{n_starved} builds past Codex review; Claude disabled, Codex routing active",
                      "")
    if n_starved >= 3 and n_recent == 0:
        return _check("claude_review_starved", "FAIL", n_starved, 3,
                      f"{n_starved} builds awaiting Claude review, 0 spawned in last 4h",
                      "Pump §5c gate broken or Claude blocked; check active_claude_count "
                      "and MAX_PARALLEL_CLAUDE in farmctl pump output")
    if n_starved >= 5:
        return _check("claude_review_starved", "WARN", n_starved, 5,
                      f"{n_starved} builds waiting for Claude review",
                      "Pump may fill up to 3 Claude review sessions; backlog should drain as slots free")
    return _check("claude_review_starved", "OK", n_starved, 3, "no starvation", "")


def chk_mt5_dispatch_idle(con) -> dict:
    """Dispatch idle = pending queue piling up with no progress.

    Smarter check than "is terminal64 alive right now" — MT5 spawns
    transiently per backtest, so terminal64=0 between launches doesn't
    mean idle. Look at:
      (a) Pending count vs active rows — many pending, no active = idle.
      (b) IF active rows exist, check pwsh.exe parents (run_smoke.ps1
          workers) are alive — that's the real signal MT5 work is in
          flight. terminal64 may be 0 just between runs.
      (c) Per-work_item recent log activity also confirms progress.

    Previous logic alarmed on "0 terminal64" — false-positive when pwsh
    workers were mid-backtest with terminal64 transiently absent.
    """
    n_pending = con.execute(
        "SELECT COUNT(*) FROM work_items WHERE status='pending'"
    ).fetchone()[0]
    if n_pending < 5:
        return _check("mt5_dispatch_idle", "OK", n_pending, 5,
                      f"{n_pending} pending (low queue)", "")
    rows = list(con.execute(
        "SELECT id, claimed_by, updated_at FROM work_items WHERE status='active'"
    ))
    if not rows:
        return _check("mt5_dispatch_idle", "FAIL", n_pending, 5,
                      f"{n_pending} pending, 0 active — dispatcher idle",
                      "Run farmctl pump (or wait for next 5-min cycle).")
    # Active rows exist. Check pwsh.exe worker procs (run_smoke.ps1 parents).
    # They wrap terminal64.exe and outlive each terminal64 spawn.
    try:
        import subprocess as _sp
        out = _sp.run(
            ["powershell.exe", "-NoProfile", "-Command",
             "(Get-Process -Name pwsh -ErrorAction SilentlyContinue).Count"],
            capture_output=True, text=True, timeout=10,
        )
        n_pwsh = int((out.stdout or "0").strip() or "0")
    except Exception:
        n_pwsh = -1
    # Also check work_item live_log activity in last 5 min — proves work is
    # actually progressing, not just zombie pwsh.
    fresh_wi_logs = 0
    try:
        import time as _t
        for f in LOG_DIR.glob("work_item_*.log"):
            if _t.time() - f.stat().st_mtime < 300:
                fresh_wi_logs += 1
    except Exception:
        pass
    if n_pwsh >= len(rows) or fresh_wi_logs >= 1:
        return _check("mt5_dispatch_idle", "OK", n_pending, 5,
                      f"{n_pending} pending, {len(rows)} active, {n_pwsh} pwsh workers, "
                      f"{fresh_wi_logs} fresh work_item logs", "")
    # Active rows but no pwsh workers AND no fresh logs → truly stranded
    return _check("mt5_dispatch_idle", "FAIL", len(rows), 0,
                  f"{n_pending} pending, {len(rows)} active, {n_pwsh} pwsh, "
                  f"{fresh_wi_logs} fresh logs — workers dead",
                  "Stranded active work_items. Inline PID check should "
                  "release them next pump cycle.")


def chk_mt5_worker_saturation(con) -> dict:
    """At least 2/3 of the enabled fleet must run; design loss remains WARN.

    The factory has ten installed terminal_worker daemons, but the
    disabled_terminals.txt safety list can deliberately park some. A fully
    alive enabled subset avoids a false factory-down FAIL, while the missing
    installed capacity remains visible as WARN. T_Live is deliberately outside
    this regex and must never be counted.
    """
    try:
        out = subprocess.run(
            [
                "powershell.exe",
                "-NoProfile",
                "-Command",
                "Get-CimInstance Win32_Process | "
                "Where-Object { $_.CommandLine -match 'terminal_worker.py' } | "
                "Select-Object ProcessId,CommandLine | ConvertTo-Json -Compress",
            ],
            capture_output=True,
            text=True,
            timeout=15,
            creationflags=_creationflags_no_window(),
        )
        raw = (out.stdout or "").strip()
        rows = json.loads(raw) if raw else []
    except Exception as exc:
        return _check("mt5_worker_saturation", "FAIL", 0, MT5_SATURATION_MIN_WORKERS,
                      f"could not scan terminal_worker.py processes: {exc!r}",
                      "Run tools/strategy_farm/start_terminal_workers.py --dedupe")
    if isinstance(rows, dict):
        rows = [rows]
    running: set[str] = set()
    for row in rows if isinstance(rows, list) else []:
        cmd = str(row.get("CommandLine") or "")
        match = re.search(r"--terminal\s+(T(?:[1-9]|10))\b", cmd, re.IGNORECASE)
        if match:
            running.add(match.group(1).upper())
    disabled = _disabled_terminals()
    enabled = [t for t in FACTORY_TERMINALS if t not in disabled]
    enabled_expected = len(enabled) or len(FACTORY_TERMINALS)
    design_expected = len(FACTORY_TERMINALS)
    # 2/3 of the enabled fleet, never stricter than the full-fleet floor of 7.
    min_workers = min(
        MT5_SATURATION_MIN_WORKERS,
        max(1, -(-2 * enabled_expected // 3)),
    )
    running_enabled = {t for t in running if t not in disabled}
    count = len(running_enabled)
    detail = (
        f"{count}/{design_expected} design terminal_worker capacity alive; "
        f"{count}/{enabled_expected} enabled daemons alive "
        f"({', '.join(sorted(running_enabled)) or 'none'})"
    )
    if disabled:
        detail += (
            f" // {len(disabled)} unavailable by disabled_terminals.txt "
            f"safety/quarantine policy: {', '.join(sorted(disabled))}"
        )
    if count < min_workers:
        return _check("mt5_worker_saturation", "FAIL", count, min_workers,
                      detail,
                      "Run `python tools/strategy_farm/start_terminal_workers.py --dedupe`; inspect worker logs if any slot stays dark.")
    if count < enabled_expected:
        return _check("mt5_worker_saturation", "WARN", count, design_expected,
                      detail,
                      "Fleet is above 2/3 of enabled capacity but not fully saturated; restart missing workers when convenient.")
    if enabled_expected < design_expected:
        return _check(
            "mt5_worker_saturation",
            "WARN",
            count,
            design_expected,
            detail,
            "Enabled workers are healthy, but design capacity is reduced; resolve or explicitly ratify each quarantined terminal.",
        )
    return _check("mt5_worker_saturation", "OK", count, design_expected, detail, "")


def _bounded_log_tail_text(path: Path, max_bytes: int = TERMINAL_PROFILE_LOG_TAIL_BYTES) -> str:
    """Read a bounded UTF-8/UTF-16 MT5 log tail; failures return empty text."""
    try:
        size = path.stat().st_size
        with path.open("rb") as handle:
            if size > max_bytes:
                start = size - max_bytes
                if start % 2:
                    start += 1
                handle.seek(start)
            raw = handle.read()
    except OSError:
        return ""
    if not raw:
        return ""
    sample = raw[:512]
    if sample.count(0) > len(sample) // 4:
        return raw.decode("utf-16-le", errors="ignore")
    return raw.decode("utf-8-sig", errors="ignore")


def chk_terminal_account_profiles(
    mt5_root: Path | None = None,
    terminals: tuple[str, ...] | None = None,
    disabled: set[str] | None = None,
) -> dict:
    """Read-only detection of missing portable-terminal account profiles.

    Each enabled T1-T10 slot must have its account/server files and explicit
    Login/Server keys. Runtime truth comes from the latest terminal log: only an
    ACCOUNT_NOT_SPECIFIED token after the latest tester.ini launch marker is
    actionable, so stale failures from an earlier run cannot poison the probe.
    T_Live is structurally outside ``FACTORY_TERMINALS``.
    """
    root = mt5_root or MT5_ROOT
    selected = terminals or FACTORY_TERMINALS
    disabled_set = _disabled_terminals() if disabled is None else disabled
    enabled = [str(t).upper() for t in selected if str(t).upper() not in disabled_set]
    runtime_failures: list[str] = []
    runtime_pending: list[str] = []
    config_gaps: list[str] = []
    inspected_logs = 0

    for terminal in enabled:
        terminal_root = root / terminal
        config_root = terminal_root / "Config"
        accounts = config_root / "accounts.dat"
        servers = config_root / "servers.dat"
        common = config_root / "common.ini"
        for label, path in (("accounts.dat", accounts), ("servers.dat", servers)):
            try:
                if not path.is_file() or path.stat().st_size <= 0:
                    config_gaps.append(f"{terminal}:{label}_missing_or_empty")
            except OSError:
                config_gaps.append(f"{terminal}:{label}_unreadable")
        try:
            common_text = common.read_text(encoding="utf-8-sig", errors="ignore")
        except OSError:
            common_text = ""
        if not re.search(r"(?mi)^Login=\d+\s*$", common_text):
            config_gaps.append(f"{terminal}:common.ini_Login_missing")
        if not re.search(r"(?mi)^Server=\S+\s*$", common_text):
            config_gaps.append(f"{terminal}:common.ini_Server_missing")

        logs_dir = terminal_root / "logs"
        try:
            candidates = [p for p in logs_dir.glob("*.log") if p.is_file()]
            latest = max(candidates, key=lambda p: p.stat().st_mtime) if candidates else None
        except OSError:
            latest = None
        if latest is None:
            config_gaps.append(f"{terminal}:terminal_log_missing")
            continue
        text = _bounded_log_tail_text(latest).lower()
        if not text:
            config_gaps.append(f"{terminal}:{latest.name}_tail_unreadable")
            continue
        inspected_logs += 1
        launch_at = max(
            text.rfind("successfully initialized from start config"),
            text.rfind("launched with"),
        )
        failure_at = text.rfind(ACCOUNT_NOT_SPECIFIED_TOKEN)
        if launch_at < 0:
            runtime_pending.append(f"{terminal}:{latest.name}:no_tester_launch_marker")
        elif failure_at > launch_at:
            runtime_failures.append(f"{terminal}:{latest.name}")
        else:
            current_launch = text[launch_at:]
            ready = any(token in current_launch for token in (
                "authorized on ",
                "automatic testing started",
                "last test passed with result",
            ))
            if not ready:
                runtime_pending.append(f"{terminal}:{latest.name}")

    hint = (
        "Quarantine each affected factory slot, then repair its portable account "
        "profile only in an OWNER-approved stopped-state window; health must never "
        "stop/start terminals or touch AutoTrading."
    )
    if runtime_failures:
        return _check(
            "terminal_account_profiles",
            "FAIL",
            len(runtime_failures),
            0,
            "latest launch is account-unconfigured on " + ", ".join(runtime_failures),
            hint,
        )
    if config_gaps:
        return _check(
            "terminal_account_profiles",
            "WARN",
            len(config_gaps),
            0,
            "profile preflight gaps: " + ", ".join(config_gaps),
            hint,
        )
    if runtime_pending:
        return _check(
            "terminal_account_profiles",
            "WARN",
            len(runtime_pending),
            0,
            "latest launch has not yet proved account readiness on "
            + ", ".join(runtime_pending),
            hint,
        )
    return _check(
        "terminal_account_profiles",
        "OK",
        inspected_logs,
        len(enabled),
        f"{inspected_logs}/{len(enabled)} enabled T1-T10 profiles have config and no current-launch account fault",
        "",
    )


def _parse_utc_datetime(value: str | None) -> dt.datetime | None:
    if not value:
        return None
    text = str(value).strip()
    try:
        if text.endswith("Z"):
            text = text[:-1] + "+00:00"
        parsed = dt.datetime.fromisoformat(text)
        if parsed.tzinfo is None:
            parsed = parsed.replace(tzinfo=dt.timezone.utc)
        return parsed.astimezone(dt.timezone.utc)
    except ValueError:
        try:
            return dt.datetime.strptime(text, "%Y-%m-%d %H:%M:%S").replace(tzinfo=dt.timezone.utc)
        except ValueError:
            return None


def chk_active_row_age(con) -> dict:
    rows = con.execute(
        """
        SELECT id, phase, ea_id, symbol, claimed_by, payload_json, updated_at
        FROM work_items
        WHERE status='active'
        """
    ).fetchall()
    now = _utc_now()
    offenders = []
    for r in rows:
        phase = str(r["phase"] or "")
        timeout_min = farmctl._active_timeout_min_for_work_item(phase, r["payload_json"])
        if timeout_min is None:
            continue
        updated = _parse_utc_datetime(r["updated_at"])
        if updated is None:
            continue
        age_min = (now - updated).total_seconds() / 60.0
        if age_min > timeout_min:
            offenders.append((age_min, timeout_min, r))
    if not offenders:
        return _check("active_row_age", "OK", 0, 1, "no active rows beyond phase timeout", "")
    worst_age, worst_timeout, worst = max(offenders, key=lambda x: x[0])
    status = "FAIL" if worst_age > (2 * worst_timeout) else "WARN"
    detail = (
        f"{len(offenders)} active rows exceed phase timeout; worst "
        f"{worst['ea_id']} {worst['symbol']} {worst['phase']} "
        f"terminal={worst['claimed_by']} age={worst_age:.1f}m timeout={worst_timeout}m"
    )
    return _check("active_row_age", status, round(worst_age, 1), worst_timeout,
                  detail, "Run farmctl pump; active_timeouts should fail hung rows and release MT5 slots")


def chk_codex_zero_activity(con) -> dict:
    """Codex 0 active + build_ea pending > 0 = codex stuck.

    Suppressed when codex_auth_broken is firing — that's the upstream
    cause of 0 codex, not a separate problem. Same for cards_ready
    stagnation downstream.
    """
    # Upstream check: codex auth broken takes precedence
    auth_broken = _is_codex_auth_broken(con)

    # Real activity signal, not an instantaneous `Get-Process codex` snapshot:
    # codex procs are transient (one per build, gone between builds), so 0 live
    # procs is normal and with builds always pending it cried wolf permanently
    # (same root cause fixed in codex_auth_broken). "Active" = a build_ea reached
    # a terminal state (done/failed = codex ran) in the last 3h.
    cutoff_3h = (_utc_now() - dt.timedelta(hours=3)).strftime("%Y-%m-%dT%H:%M:%SZ")
    recent_build_activity = con.execute(
        "SELECT COUNT(*) FROM tasks WHERE kind='build_ea' "
        "AND status IN ('done','failed') AND updated_at >= ?", (cutoff_3h,)
    ).fetchone()[0]
    n_pending_builds = con.execute(
        "SELECT COUNT(*) FROM tasks WHERE kind='build_ea' AND status='pending'"
    ).fetchone()[0]
    if auth_broken and recent_build_activity == 0:
        return _check("codex_zero_activity", "WARN", 0, 1,
                      "no codex build activity in 3h (auth_broken upstream)",
                      "Downstream of codex_auth_broken — recovers once OWNER runs `codex login`")
    if recent_build_activity == 0 and n_pending_builds >= 3:
        return _check("codex_zero_activity", "FAIL", 0, 1,
                      f"0 codex build activity in 3h but {n_pending_builds} pending build_ea tasks",
                      "Run farmctl pump manually; check codex.cmd is on PATH and codex CLI works")
    return _check("codex_zero_activity", "OK", recent_build_activity, 1,
                  f"{recent_build_activity} codex builds in 3h, {n_pending_builds} pending", "")


def chk_source_pool(con) -> dict:
    """Pending source pool < 10 = we'll run dry, need to seed more."""
    n = con.execute(
        "SELECT COUNT(*) FROM sources WHERE status='pending'"
    ).fetchone()[0]
    if n == 0:
        return _check("source_pool_drained", "FAIL", n, 10,
                      "0 pending sources — research will starve",
                      "Seed more sources: see tools/strategy_farm/seed_*.py examples")
    if n < 10:
        return _check("source_pool_drained", "WARN", n, 10,
                      f"only {n} pending sources",
                      "Add more sources before pool drains")
    return _check("source_pool_drained", "OK", n, 10, f"{n} pending sources", "")


def chk_zerotrade_rework_backlog(con) -> dict:
    """EAs with recurrent Q02 zero/min-trade FAILs must have a recent rework task.

    WARN if any EA crosses the 80% / 5-sample threshold without a rework
    task in the last 6 hours. FAIL if more than 10 EAs are in that state,
    which indicates a systemic build/strategy-class issue rather than a
    single bad EA.
    """
    # 14-day bound for the same reason as _detect_zerotrade_dead_eas: the
    # classifier reads evidence files from disk per row, and an all-history
    # sweep crawled for 30+ minutes on a cold cache (2026-08-15).
    rows = con.execute(
        """
        SELECT ea_id, status, verdict, payload_json, evidence_path
        FROM work_items
        WHERE phase IN ('Q02', 'P2') AND status IN ('done', 'failed')
          AND datetime(updated_at) >= datetime('now', '-14 days')
        ORDER BY ea_id
        """
    ).fetchall()
    grouped: dict[str, dict[str, int]] = {}
    for row in rows:
        ea_id = row["ea_id"]
        bucket = grouped.setdefault(ea_id, {"done": 0, "zt": 0})
        bucket["done"] += 1
        if (
            (row["verdict"] or "").upper() == "FAIL"
            and _is_zero_trade_failure_payload(row["payload_json"], row["evidence_path"])
        ):
            bucket["zt"] += 1

    cutoff = (_utc_now() - dt.timedelta(hours=ZERO_TRADE_REWORK_DEDUP_HOURS)).replace(microsecond=0).isoformat()
    backlog = []
    for ea_id, stats in sorted(grouped.items()):
        done = int(stats["done"] or 0)
        zt = int(stats["zt"] or 0)
        if done < ZERO_TRADE_DEAD_MIN_DONE or (zt / done) < ZERO_TRADE_DEAD_THRESHOLD:
            continue
        prior_attempts = con.execute(
            """
            SELECT COUNT(*) FROM tasks
            WHERE card_id=? AND kind='build_ea'
              AND payload_json LIKE '%ZERO_TRADE_RECURRENT%'
            """,
            (ea_id,),
        ).fetchone()[0]
        if prior_attempts >= 3:
            continue
        existing = con.execute(
            """
            SELECT id FROM tasks
            WHERE card_id=? AND kind='build_ea'
              AND payload_json LIKE '%ZERO_TRADE_RECURRENT%'
              AND (created_at >= ? OR status='pending')
            ORDER BY created_at DESC LIMIT 1
            """,
            (ea_id, cutoff),
        ).fetchone()
        if existing:
            continue
        backlog.append(f"{ea_id}:{zt}/{done}")

    n = len(backlog)
    detail = ", ".join(backlog[:10]) if backlog else "no uncovered recurrent zero-trade EAs"
    if n > 10:
        return _check("zerotrade_rework_backlog", "FAIL", n, 10,
                      f"{n} EAs need zero-trade rework tasks ({detail})",
                      "Run farmctl pump; if backlog remains, inspect detector or widespread EA entry bugs.")
    if n > 0:
        return _check("zerotrade_rework_backlog", "WARN", n, 1,
                      f"{n} EA(s) need zero-trade rework tasks ({detail})",
                      "Next pump cycle should create build_ea + codex_inbox auto-rework tasks.")
    return _check("zerotrade_rework_backlog", "OK", 0, 1, detail, "")


def _has_auto_build_task_file(ea_id: str) -> bool:
    inbox = ROOT / "codex_inbox"
    for rel in ("", ".processing", ".archive"):
        d = inbox / rel if rel else inbox
        if d.is_dir() and any(d.glob(f"auto-build-{ea_id}-*.md")):
            return True
    return False


def _has_auto_build_task(con, ea_id: str) -> bool:
    row = con.execute(
        """
        SELECT 1 FROM tasks
        WHERE kind='build_ea'
          AND card_id=?
          AND status IN ('pending', 'active', 'done', 'blocked')
        LIMIT 1
        """,
        (ea_id,),
    ).fetchone()
    return bool(row)


def chk_unbuilt_cards_count(con) -> dict:
    """Build-ready approved cards with no matching .ex5 and no auto-build task."""
    cards_dir = ROOT / "artifacts" / "cards_approved"
    if not cards_dir.is_dir():
        return _check("unbuilt_cards_count", "OK", 0, 3,
                      "cards_approved missing or empty", "")
    unbuilt = []
    not_build_ready = 0
    for card_md in sorted(cards_dir.glob("QM5_*.md")):
        m = re.match(r"(QM5_\d{4,5})_(.+)\.md$", card_md.name)
        if not m:
            continue
        ea_id, slug = m.group(1), m.group(2)
        label = f"{ea_id}_{slug}"
        ex5 = FRAMEWORK_EAS_DIR / label / f"{label}.ex5"
        if ex5.exists() or _has_auto_build_task_file(ea_id) or _has_auto_build_task(con, ea_id):
            continue
        fm = _card_frontmatter(card_md)
        if not farmctl._card_r_gate_ready(fm):
            not_build_ready += 1
            continue
        unbuilt.append(ea_id)
    n = len(unbuilt)
    detail = ", ".join(unbuilt[:10]) if unbuilt else "no approved cards waiting for auto-build task"
    if not_build_ready:
        detail = f"{detail}; {not_build_ready} approved cards are waiting on R-gates"
    pending_work_items = con.execute(
        "SELECT COUNT(*) FROM work_items WHERE status='pending'"
    ).fetchone()[0]
    pending_builds = con.execute(
        "SELECT COUNT(*) FROM tasks WHERE kind='build_ea' AND status='pending'"
    ).fetchone()[0]
    try:
        out = subprocess.run(
            ["powershell.exe", "-NoProfile", "-Command",
             "(Get-Process -Name codex -ErrorAction SilentlyContinue).Count"],
            capture_output=True, text=True, timeout=10,
            creationflags=_creationflags_no_window(),
        )
        active_codex = int((out.stdout or "0").strip() or "0")
    except Exception:
        active_codex = 0
    # Only report a genuine backpressure pause when the REAL build gate would trip
    # (farmctl BUILD_BACKPRESSURE_PENDING_SOFT_LIMIT, currently 8000). The old fixed
    # 1000 threshold falsely claimed "paused by backpressure" at any deep-ish queue,
    # masking the real reason builds were idle (Codex throttle / no buildable cards).
    _bp_soft = getattr(farmctl, "BUILD_BACKPRESSURE_PENDING_SOFT_LIMIT", 8000)
    if n > 10 and pending_work_items >= _bp_soft:
        return _check("unbuilt_cards_count", "OK", n, 10,
                      f"{n} approved cards await build, paused by MT5 backpressure ({pending_work_items} pending work_items >= {_bp_soft}; {detail})",
                      "")
    if n > 10 and (pending_builds > 0 or active_codex >= getattr(farmctl, "MAX_PARALLEL_CODEX", 3)):
        return _check("unbuilt_cards_count", "WARN", n, 10,
                      f"{n} approved cards await build, Codex/build queue saturated (codex={active_codex}, pending_builds={pending_builds}; {detail})",
                      "No manual action while Codex slots are full; pump will emit auto-build tasks when a slot frees.")
    if n > 10:
        return _check("unbuilt_cards_count", "FAIL", n, 10,
                      f"{n} approved cards lack .ex5 and auto-build task ({detail})",
                      "Run farmctl pump; it should emit up to 2 auto-build bridge tasks per cycle.")
    if n > 3:
        return _check("unbuilt_cards_count", "WARN", n, 3,
                      f"{n} approved cards lack .ex5 and auto-build task ({detail})",
                      "Next pump cycles should drain this via auto-build .md tasks.")
    return _check("unbuilt_cards_count", "OK", n, 3, detail, "")


def chk_unenqueued_eas_count(con) -> dict:
    """Reviewed and built EAs that still have no P2 work_items."""
    rows = con.execute(
        """
        SELECT card_id, id AS review_task_id, payload_json
        FROM tasks
        WHERE kind='ea_review' AND status='done'
        ORDER BY updated_at DESC, id DESC
        """
    ).fetchall()
    waiting = []
    seen_eas = set()
    for r in rows:
        ea_id = r["card_id"]
        if not ea_id:
            continue
        if ea_id in seen_eas:
            continue
        seen_eas.add(ea_id)
        try:
            review_payload = json.loads(r["payload_json"] or "{}")
        except json.JSONDecodeError:
            continue
        verdict_doc = review_payload.get("verdict") or {}
        if verdict_doc.get("verdict") != "APPROVE_FOR_BACKTEST":
            continue
        candidates = sorted(p for p in FRAMEWORK_EAS_DIR.glob(f"{ea_id}_*") if p.is_dir())
        if not candidates:
            continue
        ea_dir = candidates[0]
        ex5 = ea_dir / f"{ea_dir.name}.ex5"
        if not ex5.exists():
            continue
        logical_symbol = ""
        manifest_path = ea_dir / "basket_manifest.json"
        if manifest_path.exists():
            try:
                manifest = json.loads(manifest_path.read_text(encoding="utf-8-sig"))
            except (OSError, json.JSONDecodeError):
                manifest = {}
            logical_symbol = str(manifest.get("logical_symbol") or "").strip() if isinstance(manifest, dict) else ""
        if logical_symbol:
            wi_count = con.execute(
                "SELECT COUNT(*) FROM work_items WHERE ea_id=? AND phase IN ('P2', 'Q02') AND symbol=?",
                (ea_id, logical_symbol),
            ).fetchone()[0]
        else:
            wi_count = con.execute(
                "SELECT COUNT(*) FROM work_items WHERE ea_id=? AND phase IN ('P2', 'Q02')",
                (ea_id,),
            ).fetchone()[0]
        if wi_count > 0:
            continue
        if logical_symbol:
            terminal_task_exists = con.execute(
                """
                SELECT 1 FROM tasks
                WHERE kind IN ('backtest_p2', 'backtest_q02')
                  AND card_id=?
                  AND status IN ('done', 'failed')
                  AND payload_json LIKE ?
                LIMIT 1
                """,
                (ea_id, f"%{logical_symbol}%"),
            ).fetchone()
        else:
            terminal_task_exists = con.execute(
                """
                SELECT 1 FROM tasks
                WHERE kind IN ('backtest_p2', 'backtest_q02')
                  AND card_id=?
                  AND status IN ('done', 'failed')
                LIMIT 1
                """,
                (ea_id,),
            ).fetchone()
        if terminal_task_exists:
            continue
        waiting.append(ea_id)
    n = len(waiting)
    detail = ", ".join(waiting[:10]) if waiting else "no reviewed built EAs waiting for P2 enqueue"
    if n > 10:
        return _check("unenqueued_eas_count", "FAIL", n, 10,
                      f"{n} reviewed built EAs have no P2 work_items ({detail})",
                      "Run farmctl pump; it should enqueue up to 3 EAs into P2 per cycle.")
    if n > 3:
        return _check("unenqueued_eas_count", "WARN", n, 3,
                      f"{n} reviewed built EAs have no P2 work_items ({detail})",
                      "Next pump cycles should enqueue P2 work_items.")
    return _check("unenqueued_eas_count", "OK", n, 3, detail, "")


def chk_codex_bridge_heartbeat(con) -> dict:
    """Direct build-lane liveness (legacy /goal bridge RETIRED 2026-05-17).

    state/codex_bridge_heartbeat.txt was written by the interactive Codex /goal
    bridge, decommissioned in the pipeline-rewrite era — nothing touches the file
    anymore, so its age grows forever. It must never page anyone toward "restart
    the bridge": 2026-07-14 a dirty-guard build stall surfaced here as FAIL
    "heartbeat stale 57d / inspect the interactive Codex bridge" — a pure
    mislabel, the real cause was repo_dirty_build_guard. The check now judges
    the DIRECT pump lane and, when silent, classifies the real cause via
    _build_lane_block_reason (same cry-wolf hardening as codex_auth_broken).
    Silent-lane severity stays WARN — codex_zero_activity already FAILs on
    (0 activity + pending builds); a second FAIL here would just double-page.
    """
    # Real activity signal, not an instantaneous `Get-Process codex` snapshot
    # (transient procs flip OK<->FAIL randomly — cry-wolf fixed 2026-06-09).
    _cutoff_3h = (_utc_now() - dt.timedelta(hours=3)).strftime("%Y-%m-%dT%H:%M:%SZ")
    direct_codex_active = con.execute(
        "SELECT COUNT(*) FROM tasks WHERE kind='build_ea' "
        "AND status IN ('done','failed') AND updated_at >= ?", (_cutoff_3h,)
    ).fetchone()[0] > 0
    relic = ""
    if CODEX_BRIDGE_HEARTBEAT.exists():
        relic_days = (_utc_now().timestamp() - CODEX_BRIDGE_HEARTBEAT.stat().st_mtime) / 86400.0
        relic = f" (legacy /goal bridge retired 2026-05-17; heartbeat relic {relic_days:.0f}d old)"
    if direct_codex_active:
        return _check("codex_bridge_heartbeat", "OK", 0, 1,
                      f"direct pump Codex active{relic}", "")
    n_pending = con.execute(
        "SELECT COUNT(*) FROM tasks WHERE kind='build_ea' AND status='pending'"
    ).fetchone()[0]
    if n_pending == 0:
        return _check("codex_bridge_heartbeat", "OK", 0, 1,
                      f"build lane idle, no pending builds{relic}", "")
    # Silent lane WITH pending builds: name the real cause, never the retired bridge.
    if _is_codex_auth_broken(con):
        return _check("codex_bridge_heartbeat", "WARN", 1, 1,
                      f"no direct build activity in 3h, {n_pending} pending "
                      f"(codex_auth_broken upstream){relic}",
                      "Downstream of codex_auth_broken — recovers once OWNER runs `codex login`.")
    reason, rdetail = _build_lane_block_reason(con)
    if reason == "dirty_guard":
        return _check("codex_bridge_heartbeat", "WARN", 1, 1,
                      f"no direct build activity in 3h, {n_pending} pending — {rdetail}{relic}",
                      "Build lane blocked by repo_dirty_build_guard: commit/clean the tree. "
                      "Uncommitted SOURCE never self-heals via the pump "
                      "(project_qm_dirty_guard_build_deadlock). Do NOT restart the retired bridge.")
    if reason == "backpressure":
        return _check("codex_bridge_heartbeat", "OK", 0, 1,
                      f"builds paused by backpressure (intentional){relic}", "")
    return _check("codex_bridge_heartbeat", "WARN", 1, 1,
                  f"no direct build activity in 3h, {n_pending} pending, cause unconfirmed{relic}",
                  "See codex_zero_activity; check the pump/orchestration task and the codex CLI. "
                  "The legacy interactive bridge is retired — do NOT restart it.")


def chk_agent_lane_heartbeat(con) -> dict:
    """Expose enabled router lanes that routing suppresses due to stale heartbeat."""
    threshold_hours = agent_router.LANE_HEARTBEAT_STALE_HOURS
    now_ts = dt.datetime.now(dt.UTC).timestamp()
    stale: list[tuple[str, float]] = []
    rows = con.execute(
        """
        SELECT agent_id
        FROM agent_registry
        WHERE enabled=1 AND max_parallel > 0
        ORDER BY agent_id
        """
    ).fetchall()
    for row in rows:
        agent_id = str(row[0])
        heartbeat = ROOT / "state" / f"lane_{agent_id}_heartbeat.json"
        if not heartbeat.exists():
            # Match agent_router._lane_heartbeat_stale: missing is no prior
            # liveness evidence, not proof that a lane died.
            continue
        try:
            age_hours = max(0.0, (now_ts - heartbeat.stat().st_mtime) / 3600)
        except OSError:
            continue
        if age_hours > threshold_hours:
            stale.append((agent_id, age_hours))

    if stale:
        detail = ", ".join(f"{agent_id}={age:.1f}h" for agent_id, age in stale)
        return _check(
            "agent_lane_heartbeat_stale",
            "WARN",
            len(stale),
            0,
            f"enabled router lane heartbeat stale beyond {threshold_hours}h: {detail}",
            "Inspect/re-run the affected lane's scheduled orchestration task; "
            "0x800710E0 indicates interactive-queue death. Do not restart MT5 terminals.",
        )
    return _check(
        "agent_lane_heartbeat_stale",
        "OK",
        0,
        0,
        f"no enabled router lane heartbeat older than {threshold_hours}h",
        "",
    )


def chk_disk_free_space(con) -> dict:
    """D: free-space watchdog for reports/log growth."""
    free_gb = shutil.disk_usage("D:/").free / (1024 ** 3)
    value = round(free_gb, 1)
    # Thresholds raised after the 2026-06-19 disk-full meltdown: MT5 fails tick
    # generation ("no disk space", exit 100018) well before 0GB, so alarm early.
    # FAIL aligns with the worker disk circuit-breaker (DISK_MIN_FREE_GB=40): below
    # it workers pause-purge instead of running, i.e. the factory is stalling.
    if free_gb < 40:
        return _check("disk_free_gb", "FAIL", value, 40,
                      f"D: free {free_gb:.1f}GB < 40GB (workers pause-purge below this; MT5 tick-gen at risk)",
                      "Tester tick-caches are filling D:. Hourly purge (QM_StrategyFarm_TesterCachePurge) "
                      "should hold it; if free keeps dropping run it now and check D:/QM/mt5/T*/Tester + "
                      "reports/logs. NEVER delete state/farm_state.sqlite or cards_approved/.")
    if free_gb < 80:
        return _check("disk_free_gb", "WARN", value, 80,
                      f"D: free {free_gb:.1f}GB < 80GB warn",
                      "Disk filling — watch tester caches; the hourly purge should hold it.")
    return _check("disk_free_gb", "OK", value, 80,
                  f"D: free {free_gb:.1f}GB", "")


def chk_p_pass_stagnation(con) -> dict:
    """Information hint about recent Q03+ PASS verdict flow.

    Absence of later-stage survivors is output quality, not pipeline health.
    This check is therefore informational and returns OK while the factory is
    moving work through Q02.
    """
    cutoff_6h = (_utc_now() - dt.timedelta(hours=6)).strftime("%Y-%m-%dT%H:%M:%S")
    cutoff_12h = (_utc_now() - dt.timedelta(hours=12)).strftime("%Y-%m-%dT%H:%M:%S")
    phases = (
        "Q03", "Q04", "Q05", "Q06", "Q07", "Q08", "Q09", "Q10", "Q11",
        "P3", "P3.5", "P4", "P5", "P5b", "P5c", "P6", "P7", "P8",
    )
    placeholders = ",".join("?" for _ in phases)
    n_recent_p3plus = con.execute(
        f"""
        SELECT COUNT(*) FROM work_items
        WHERE phase IN ({placeholders})
          AND verdict='PASS'
          AND updated_at >= ?
        """,
        (*phases, cutoff_6h),
    ).fetchone()[0]
    if n_recent_p3plus == 0:
        n_12h = con.execute(
            f"""
            SELECT COUNT(*) FROM work_items
            WHERE phase IN ({placeholders})
              AND verdict='PASS'
              AND updated_at >= ?
            """,
            (*phases, cutoff_12h),
        ).fetchone()[0]
        n_ever = con.execute(
            f"""
            SELECT COUNT(*) FROM work_items
            WHERE phase IN ({placeholders}) AND verdict='PASS'
            """,
            phases,
        ).fetchone()[0]
        if n_ever == 0:
            return _check("p_pass_stagnation", "OK", 0, 1,
                          "0 Q03+ PASS ever — pre-survivor output state, pipeline health unaffected",
                          "")
        return _check("p_pass_stagnation", "OK", n_recent_p3plus, 1,
                      f"0 Q03+ PASS in last {'6h' if n_12h>0 else '12h'} ({n_ever} historical)",
                      "")
    return _check("p_pass_stagnation", "OK", n_recent_p3plus, 1,
                  f"{n_recent_p3plus} Q03+ PASS in last 6h", "")


def chk_phase_infra_graveyard(con) -> dict:
    """Catch a gate whose *plumbing* is broken — high INFRA_FAIL volume with
    ~0 PASS in the same window.

    This is the canary the Q04 3-day stall needed. `p_pass_stagnation` stays
    OK on absence-of-survivors (output quality), and it goes green as long as
    *any* Q03+ phase produces a PASS — so a downstream gate that is 100%
    INFRA_FAIL (a crashing runner / arg mismatch / missing input) is invisible
    to it. INFRA_FAIL means the runner never produced a verdict at all, which
    is infrastructure, not strategy quality. A phase that has processed real
    volume in the window but is almost entirely INFRA_FAIL is a broken gate.

    FAIL when, for any phase: window volume (PASS+FAIL+INFRA_FAIL) >= MIN_VOL
    AND INFRA_FAIL/volume >= INFRA_RATIO AND PASS == 0 in the window.
    """
    MIN_VOL = 30
    INFRA_RATIO = 0.9
    WINDOW_H = 6
    cutoff = (_utc_now() - dt.timedelta(hours=WINDOW_H)).strftime("%Y-%m-%dT%H:%M:%S")
    rows = con.execute(
        """
        SELECT phase,
               SUM(CASE WHEN verdict='INFRA_FAIL' THEN 1 ELSE 0 END) AS infra,
               SUM(CASE WHEN verdict='PASS' THEN 1 ELSE 0 END) AS passed,
               COUNT(*) AS total
        FROM work_items
        WHERE verdict IS NOT NULL AND updated_at >= ?
        GROUP BY phase
        """,
        (cutoff,),
    ).fetchall()
    graveyards = []
    for r in rows:
        phase, infra, passed, total = r[0], r[1] or 0, r[2] or 0, r[3] or 0
        if total >= MIN_VOL and passed == 0 and infra / total >= INFRA_RATIO:
            graveyards.append((phase, infra, total))
    if graveyards:
        graveyards.sort(key=lambda x: x[1], reverse=True)
        worst = graveyards[0]
        detail = "; ".join(f"{p}: {i}/{t} INFRA_FAIL, 0 PASS/{WINDOW_H}h"
                           for p, i, t in graveyards)
        return _check("phase_infra_graveyard", "FAIL", worst[1], MIN_VOL,
                      detail,
                      "A gate runner is failing before producing any verdict "
                      "(crashing runner, CLI arg mismatch, or missing input) — "
                      "NOT a strategy-quality issue. Read a recent "
                      "work_item_<id>.log for that phase; check the phase "
                      "runner spawn args in farmctl._phase_runner_cmd_for_work_item.")
    return _check("phase_infra_graveyard", "OK", 0, MIN_VOL,
                  "no gate is INFRA_FAIL-saturated", "")


def chk_q02_stranded_exhausted_pairs(con) -> dict:
    """Detect Q02 pairs that exhausted the ordinary INFRA retry budget and vanished.

    Storage has two names for this gate: canonical ``Q02`` and legacy ``P2``.
    They form one logical history and therefore must be grouped together.  A
    pair is stranded only when it has no pending/active successor, at least the
    canonical retry cap worth of ``INFRA_FAIL`` rows, and *no other terminal
    disposition*.  The last condition deliberately treats ``ZERO_TRADES`` /
    ``MIN_TRADES_NOT_MET`` as the frequency-floor/retire lane and ``INVALID`` as
    a non-retryable evidence disposition.  Neither is retryable infrastructure.

    The query expresses an invariant rather than pinning a fleet count: every
    exhausted infra-only pair must either have an open successor or a non-infra
    terminal disposition.  This remains valid as the live census changes.
    """
    retry_cap = 12  # sweep_enqueue_built_eas.MAX_INFRA_ATTEMPTS
    row = con.execute(
        """
        SELECT COUNT(*)
        FROM (
            SELECT ea_id, symbol
            FROM work_items
            WHERE phase IN ('Q02', 'P2')
            GROUP BY ea_id, symbol
            HAVING SUM(
                       CASE
                           WHEN status IN ('done', 'failed')
                            AND verdict IS NOT NULL
                            AND TRIM(verdict) <> ''
                            AND UPPER(verdict) <> 'INFRA_FAIL'
                           THEN 1 ELSE 0
                       END
                   )=0
               AND SUM(CASE WHEN status IN ('pending','active') THEN 1 ELSE 0 END)=0
               AND SUM(CASE WHEN UPPER(verdict)='INFRA_FAIL' THEN 1 ELSE 0 END) >= ?
        )
        """,
        (retry_cap,),
    ).fetchone()
    stranded = int(row[0] or 0)
    if stranded:
        return _check(
            "q02_stranded_exhausted_pairs", "FAIL", stranded, 0,
            f"{stranded} Q02/P2 EA/symbol pairs have no non-infra terminal "
            f"disposition, no queued successor, and >= {retry_cap} INFRA_FAIL rows",
            "Classify the cohort by row-bound aggregate and verdict_reason; "
            "route valid zero-trade outcomes to RETIRE/frequency-floor and INVALID "
            "outcomes to evidence repair; run an OWNER-sized governed canary "
            "before any bulk infra requeue.",
        )
    return _check(
        "q02_stranded_exhausted_pairs", "OK", 0, 0,
        "no retry-exhausted Q02/P2 pair has vanished without a non-infra disposition", "",
    )


def chk_codex_auth_broken(con) -> dict:
    """Detect Codex authentication failures.

    Two signals (either trips alarm):
      a) Recent codex_*.live.log files contain 401 Unauthorized (auth
         actively failing right now)
      b) `auth.json` age > 12h AND there are pending build_ea tasks but
         0 codex procs (pipeline silent because circuit breaker is
         suppressing 401 spam, but auth is still stale)
    """
    import time as _t
    auth_path = CODEX_AUTH
    auth_mtime = auth_path.stat().st_mtime if auth_path.exists() else 0.0
    cutoff_mtime = _codex_401_cutoff_mtime(auth_mtime)
    n_401 = 0
    for log in LOG_DIR.glob("codex_*.live.log"):
        try:
            log_mtime = log.stat().st_mtime
            age = _t.time() - log_mtime
            if age > 900:
                continue
            if _tail_has_current_codex_401(log, cutoff_mtime):
                n_401 += 1
        except OSError:
            continue

    # Signal (b): auth.json stale + pipeline silent on codex
    auth_age_h: float | None = None
    if auth_path.exists():
        try:
            auth_age_h = (_t.time() - auth_mtime) / 3600
        except OSError:
            pass
    n_pending = con.execute(
        "SELECT COUNT(*) FROM tasks WHERE kind='build_ea' AND status='pending'"
    ).fetchone()[0]
    # Real activity signal instead of an instantaneous codex-process snapshot:
    # codex processes are transient (one per build), so 0 live procs is normal
    # between builds and auth.json mtime is not rewritten on every use. Only flag
    # a stall when NO build_ea reached a terminal state (done/failed) in 3h.
    cutoff_3h = (_utc_now() - dt.timedelta(hours=3)).strftime("%Y-%m-%dT%H:%M:%SZ")
    recent_build_activity = con.execute(
        "SELECT COUNT(*) FROM tasks WHERE kind='build_ea' "
        "AND status IN ('done','failed') AND updated_at >= ?", (cutoff_3h,)
    ).fetchone()[0]
    pipeline_silent_on_codex = (recent_build_activity == 0 and n_pending >= 1
                                and auth_age_h is not None and auth_age_h > 12)

    # Real auth failure: actual 401s in recent codex logs.
    if n_401 >= 2:
        detail = f"{n_401} recent 401-logs" + (f", auth_age={auth_age_h:.1f}h" if auth_age_h else "")
        return _check("codex_auth_broken", "FAIL", n_401, 1, detail,
                      "Run `codex login` interactively on the VPS. The pump circuit "
                      "breaker is preventing new spawns until then.")
    # Silent build lane + stale auth but NO 401s. Do NOT blame auth blindly — classify
    # the real cause first (the #1 recurring one is the dirty-guard deadlock; backpressure
    # is intentional). This is the cry-wolf fix: auth is only asserted with 401 evidence.
    if pipeline_silent_on_codex:
        reason, rdetail = _build_lane_block_reason(con)
        base = (f"{n_pending} builds pending, 0 build activity in 3h"
                + (f", auth_age={auth_age_h:.1f}h" if auth_age_h else "") + ", n_401=0")
        if reason == "dirty_guard":
            return _check("codex_auth_broken", "WARN", 1, 1,
                          f"NOT auth — {rdetail} ({base})",
                          "Build lane blocked by repo_dirty_build_guard, not auth. Commit/clean "
                          "the artifact; the pump auto-commit should self-heal "
                          "(project_qm_dirty_guard_build_deadlock).")
        if reason == "backpressure":
            return _check("codex_auth_broken", "OK", 0, 1,
                          f"builds paused by backpressure (intentional), not auth — {rdetail}", "")
        return _check("codex_auth_broken", "WARN", 1, 1,
                      f"codex build lane silent, cause unconfirmed (no 401s, no dirty-guard, "
                      f"no backpressure) — {base}",
                      "Auth may be stale; if it persists run `codex login`. Also check the "
                      "codex orchestration task + build queue.")
    if n_401 == 1:
        return _check("codex_auth_broken", "WARN", 1, 1,
                      "1 recent codex log has 401 — could be transient",
                      "Watch for more. If recurs, OWNER must `codex login`.")
    return _check("codex_auth_broken", "OK", 0, 1,
                  f"no 401 errors; auth_age={auth_age_h:.1f}h" if auth_age_h else "no 401", "")


def chk_quota_snapshot_fresh() -> dict:
    """Quota snapshot from quota_pull.py (headless API pull) — stale = pulls
    failing (expired token mid-refresh, or chatgpt.com Cloudflare block)."""
    if not QUOTA_SNAPSHOT.exists():
        return _check("quota_snapshot_fresh", "WARN", "missing", 300,
                      "quota_snapshot.json missing",
                      "Check QM_StrategyFarm_QuotaPull task; run quota_pull.py manually")
    try:
        snap = json.loads(QUOTA_SNAPSHOT.read_text(encoding="utf-8"))
    except Exception as exc:
        return _check("quota_snapshot_fresh", "WARN", "unreadable", 300,
                      f"snapshot unreadable: {exc}", "Check quota_pull.py output")
    now = _utc_now()
    ages: dict = {}
    sources = ["codex"]
    claude_disabled = (ROOT / "CLAUDE_DISABLED.flag").exists()
    if not claude_disabled:
        sources.append("claude")
    for src in sources:
        s = snap.get(src) or {}
        ra = s.get("received_at")
        if ra:
            try:
                t = dt.datetime.fromisoformat(ra.replace("Z", "+00:00"))
                ages[src] = int((now - t).total_seconds())
            except Exception:
                pass
    max_age = max(ages.values()) if ages else None
    if max_age is None:
        return _check("quota_snapshot_fresh", "WARN", "no timestamps", 300,
                      "no received_at timestamps in snapshot",
                      "Check QM_StrategyFarm_QuotaPull task; run quota_pull.py")
    if max_age > 600:  # > 10 min
        src_detail = ", ".join(f"{src}={ages.get(src, '?')}s" for src in sources)
        if ages.get("codex", 10**9) <= 600 and ages.get("claude", 0) > 600:
            return _check("quota_snapshot_fresh", "WARN", max_age, 600,
                          f"claude snapshot stale but codex snapshot fresh ({src_detail})",
                          "Claude usage pull failing — check quota_pull.py token/anthropic-beta")
        return _check("quota_snapshot_fresh", "FAIL", max_age, 600,
                      f"oldest enabled snapshot {max_age}s old ({src_detail})",
                      "Check QM_StrategyFarm_QuotaPull task; run quota_pull.py to see the error")
    if max_age > 300:
        return _check("quota_snapshot_fresh", "WARN", max_age, 300,
                      f"oldest enabled snapshot {max_age}s old",
                      "quota_pull may be lagging — check the 5-min task")
    src_detail = ", ".join(f"{src}={ages.get(src, '?')}s" for src in sources)
    if claude_disabled:
        src_detail += "; claude disabled"
    return _check("quota_snapshot_fresh", "OK", max_age, 300,
                  src_detail, "")


# ---------------------------------------------------------------------------

def chk_stranded_ea_improvements() -> dict:
    """DL-069: flag EAs where a higher-version on-disk dir exists but is NOT the
    active-registered canonical build — an improvement built but never promoted in
    magic_numbers.csv, so the resolver still runs the older build."""
    import csv as _csv
    from collections import defaultdict
    reg = REPO_ROOT / "framework" / "registry" / "magic_numbers.csv"
    active_by_ea: dict[str, set] = defaultdict(set)
    if reg.exists():
        try:
            with reg.open(encoding="utf-8-sig", newline="") as f:
                for row in _csv.DictReader(f):
                    if str(row.get("status") or "active").strip().lower() == "retired":
                        continue
                    eid = str(row.get("ea_id") or "").strip()
                    slug = str(row.get("ea_slug") or "").strip()
                    if eid and slug:
                        active_by_ea[eid].add(slug)
        except OSError:
            pass

    def _ver(name: str) -> int:
        mm = re.search(r"_v(\d+)(?:$|_)", name)
        return int(mm.group(1)) if mm else 1

    dirs: dict[tuple, list] = defaultdict(list)
    for p in FRAMEWORK_EAS_DIR.glob("QM5_*"):
        if p.is_dir():
            m = re.match(r"(QM5_(\d+))_", p.name)
            if m:
                dirs[(m.group(1), m.group(2))].append(p.name)
    stranded = []
    for (ea_label, num), names in dirs.items():
        if len(names) < 2:
            continue
        active = active_by_ea.get(num, set())
        registered = [n for n in names if (n[len(ea_label) + 1:] if n.startswith(ea_label + "_") else n) in active]
        pool = registered or names
        canon_v = max(_ver(n) for n in pool)
        if any(_ver(n) > canon_v for n in names):
            stranded.append(ea_label)
    n = len(stranded)
    if n == 0:
        return _check("stranded_ea_improvements", "OK", 0, 0, "no un-promoted higher-version dirs", "")
    return _check("stranded_ea_improvements", "WARN", n, 0,
                  f"{n} EAs have a higher-version dir not active-registered: {sorted(stranded)[:8]}",
                  "Register the improved slug (active) in magic_numbers.csv or remove the un-promoted dir (DL-069).")


def _normalized_registry_ea_id(value: object) -> str:
    text = str(value or "").strip().upper()
    if text.startswith("QM5_"):
        text = text[4:]
    return text if text.isdigit() else ""


def chk_ea_id_slug_uniqueness(repo_root: Path | None = None) -> dict:
    """Enforce one numeric EA ID -> at most one distinct active slug.

    A duplicate is FAIL only when at least two slugs are fully materialized:
    each has both active magic rows and its exact ``QM5_<id>_<slug>`` directory.
    Registry-only duplicates remain WARN because the resolver cannot build them,
    but they still represent ambiguous ownership that should be retired.
    """

    root = repo_root or REPO_ROOT
    registry = root / "framework" / "registry" / "ea_id_registry.csv"
    magics = root / "framework" / "registry" / "magic_numbers.csv"
    eas_dir = root / "framework" / "EAs"
    if not registry.is_file():
        return _check(
            "ea_id_slug_uniqueness",
            "WARN",
            None,
            0,
            f"registry missing: {registry}",
            "check framework/registry/ea_id_registry.csv",
        )

    active_registry: dict[str, set[str]] = {}
    with registry.open(encoding="utf-8-sig", newline="") as handle:
        for row in csv.DictReader(handle):
            if str(row.get("status") or "").strip().lower() != "active":
                continue
            ea_id = _normalized_registry_ea_id(row.get("ea_id"))
            slug = str(row.get("slug") or "").strip().lower()
            if ea_id and slug:
                active_registry.setdefault(ea_id, set()).add(slug)

    active_magics: dict[str, set[str]] = {}
    if magics.is_file():
        with magics.open(encoding="utf-8-sig", newline="") as handle:
            for row in csv.DictReader(handle):
                if str(row.get("status") or "").strip().lower() != "active":
                    continue
                ea_id = _normalized_registry_ea_id(row.get("ea_id"))
                slug = str(row.get("ea_slug") or "").strip().lower()
                if ea_id and slug:
                    active_magics.setdefault(ea_id, set()).add(slug)

    on_disk: dict[str, set[str]] = {}
    if eas_dir.is_dir():
        for path in eas_dir.iterdir():
            if not path.is_dir():
                continue
            match = re.fullmatch(r"QM5_(\d+)_(.+)", path.name, flags=re.IGNORECASE)
            if not match:
                continue
            ea_id = _normalized_registry_ea_id(match.group(1))
            slug = match.group(2).strip().lower()
            if ea_id and slug:
                on_disk.setdefault(ea_id, set()).add(slug)

    duplicates = {
        ea_id: slugs for ea_id, slugs in active_registry.items() if len(slugs) > 1
    }
    if not duplicates:
        return _check(
            "ea_id_slug_uniqueness",
            "OK",
            0,
            0,
            "every active numeric ea_id maps to at most one distinct active slug",
            "",
        )

    live: list[str] = []
    orphaned: list[str] = []
    for ea_id in sorted(duplicates, key=lambda value: (int(value), value)):
        slugs = duplicates[ea_id]
        materialized = (
            slugs
            & active_magics.get(ea_id, set())
            & on_disk.get(ea_id, set())
        )
        rendered = f"{ea_id}:{sorted(slugs)}"
        if len(materialized) >= 2:
            live.append(f"{rendered} materialized={sorted(materialized)}")
        else:
            orphaned.append(rendered)

    if live:
        orphan_note = (
            f"; plus {len(orphaned)} registry-only duplicate(s)"
            if orphaned
            else ""
        )
        return _check(
            "ea_id_slug_uniqueness",
            "FAIL",
            len(live),
            0,
            "live dual-slug EA ID collision(s): " + "; ".join(live) + orphan_note,
            "Re-key one fully materialized slug to a freshly reserved ea_id, then "
            "regenerate QM_MagicResolver.mqh before compiling.",
        )

    return _check(
        "ea_id_slug_uniqueness",
        "WARN",
        len(orphaned),
        0,
        "registry-only duplicate active ea_id row(s): " + "; ".join(orphaned),
        "Retire orphan duplicate registry rows; no current dual-magic/on-disk collision.",
    )


_LSM_HEALTH_FILE = Path(r"D:\QM\reports\state\lsm_health.json")


def chk_lsm_session_health() -> dict:
    """Session-infrastructure health from QM_StrategyFarm_LsmHealthProbe (6h cadence).

    Surfaces the probe verdict ('ok'/'degrading'/'critical') and flags a stale probe
    (>8h since last run) as WARN.  Probe checks: qwinsta exit code (error 87 = LSM
    degradation), three QM task LastTaskResult+cadence-lag (FactoryWatchdog included),
    Win32_LogonSession presence, CreateProcess viability.
    """
    if not _LSM_HEALTH_FILE.exists():
        return _check("lsm_session_health", "WARN", "missing", "ok",
                      "lsm_health.json missing — LsmHealthProbe has not run yet",
                      "Register+run: install_hygiene_and_lsm_tasks.ps1 -RunLsmNow")
    try:
        data = json.loads(_LSM_HEALTH_FILE.read_text(encoding="utf-8-sig"))
    except Exception as exc:
        return _check("lsm_session_health", "WARN", "unreadable", "ok",
                      f"lsm_health.json unreadable: {exc!r}", "")

    probed_at = _parse_utc_ts(data.get("probed_at"))
    age_h = round((_utc_now() - probed_at).total_seconds() / 3600, 1) if probed_at else None
    if age_h is None or age_h > 8:
        return _check("lsm_session_health", "WARN", age_h, 8,
                      f"lsm_health.json stale ({age_h}h old) — LsmHealthProbe may have stopped",
                      "Check QM_StrategyFarm_LsmHealthProbe LastTaskResult")

    verdict = str(data.get("verdict") or "unknown")
    qwinsta = data.get("qwinsta_ok")
    tasks_failing = data.get("tasks_failing_count", 0)
    tasks_checked = data.get("tasks_checked", 0)
    logon_ok = data.get("logon_session_ok")
    spawn_ok = data.get("spawn_ok")
    qwinsta_err = data.get("qwinsta_error")
    detail = (f"verdict={verdict} qwinsta_ok={qwinsta} qwinsta_error={qwinsta_err} "
              f"tasks_failing={tasks_failing}/{tasks_checked} "
              f"logon_session_ok={logon_ok} spawn_ok={spawn_ok} age={age_h}h")
    if verdict == "critical":
        return _check("lsm_session_health", "FAIL", verdict, "ok", detail,
                      "LSM is critically degraded; expect 0x800710E0 / qwinsta error 87. "
                      "Plan a controlled hygiene reboot (Saturday 07:00 automation or manual).")
    if verdict == "degrading":
        return _check("lsm_session_health", "WARN", verdict, "ok", detail,
                      "LSM degradation in progress — monitor; hygiene reboot planned Saturday.")
    return _check("lsm_session_health", "OK", verdict, "ok", detail, "")


# ===========================================================================
# WS-F standing vacuousness audit — five provenance-authenticated detectors.
# Each emits one _check tuple; read-only DB + filesystem/live-log tails. The
# guiding rule (Codex challenge): never flag naive equality/zero-variance as
# corrupt — authenticate provenance (distinct runs, unrounded KPIs, stress
# telemetry, min cohort, or q07's own seed-auth evidence) first, and emit a
# reason-specific benign class when the identity is legitimate.
# ===========================================================================


def _read_json_path(path) -> dict | None:
    """Load a JSON file read-only; None on any error. utf-8-sig tolerant."""
    if not path:
        return None
    try:
        data = json.loads(Path(path).read_text(encoding="utf-8-sig"))
    except (OSError, json.JSONDecodeError, ValueError, UnicodeError):
        return None
    return data if isinstance(data, dict) else None


def _ea_id_int(value) -> int | None:
    """Coerce an ea_id field ('QM5_1567', '1567', 1567) to its integer id.

    The 'QM5_' prefix is stripped FIRST — a naive first-number match would return
    the 5 of 'QM5', mislabelling every row in the evidence trail."""
    if value is None:
        return None
    s = str(value)
    m = re.match(r"\s*QM5_(\d+)", s, re.IGNORECASE)
    if m:
        return int(m.group(1))
    m = re.search(r"(\d+)", s)
    return int(m.group(1)) if m else None


def _norm_symbol(sym) -> str:
    """Normalise a symbol for cross-source matching: strip a trailing '.DWX'
    broker suffix and upper-case (manifest 'XAUUSD.DWX' == live-log 'XAUUSD')."""
    s = str(sym or "").strip().upper()
    if s.endswith(".DWX"):
        s = s[:-4]
    return s


def _window_cutoff_ts(days: int) -> float:
    return _utc_now().timestamp() - days * 86400


def _extract_hash(ev: dict | None, aliases: tuple[str, ...]) -> str | None:
    """Pull one sha256 out of an evidence payload, tolerating both a flat
    ``{"ex5_sha256": "..."}`` field and the pipeline's nested
    ``{"ex5": {"path": ..., "sha256": ...}}`` provenance block. Returns None when
    the payload carries no such hash (i.e. provenance for that facet is unbound)."""
    if not isinstance(ev, dict):
        return None
    for a in aliases:
        v = ev.get(a)
        if isinstance(v, str) and v.strip():
            return v.strip()
        if isinstance(v, dict):
            h = v.get("sha256") or v.get("hash")
            if isinstance(h, str) and h.strip():
                return h.strip()
    return None


# A bound provenance hash must be a real sha256 digest: exactly 64 lowercase hex
# chars. Presence of *some* non-empty string is NOT authentication (Codex round-3
# WSF2: ea=set=ex5=report="x" previously returned AUTHENTICATED). Uppercase, short,
# long, or non-hex all fail with reason code `malformed_hash`.
_SHA256_HEX_RE = re.compile(r"^[0-9a-f]{64}$")
# Facets that pin the *deployment identity* (must be identical across paired runs).
# The generated set is intentionally per-run identity: Q05 carries rejection=0.0,
# Q06 carries rejection=0.1, and Q07 changes the seed.  Requiring equal set hashes
# made every correctly stressed pair impossible to authenticate.  Each set hash is
# still mandatory and syntactically validated below; only EA source and binary must
# remain identical.  Native reports likewise must differ across paired runs.
_PROV_IDENTITY_FACETS = ("ea", "binary")


def _valid_sha256(h) -> bool:
    """True iff ``h`` is a syntactically valid sha256 digest (64 lowercase hex chars).
    This is the syntactic floor of authentication — it does not by itself prove the
    digest matches an on-disk artifact, but a value failing it can never be trusted."""
    return isinstance(h, str) and bool(_SHA256_HEX_RE.match(h))


def _provenance_tier(
    payloads, *, unrounded_ok: bool, telemetry_ok: bool
) -> tuple[str, list[str]]:
    """Classify a heuristic detection into the CANDIDATE vs AUTHENTICATED tier.

    Codex round-3 (WSF2) contract — the AUTHENTICATED tier is *real validation*, never
    presence-checking. A detection is AUTHENTICATED only when EVERY condition holds:
      (1) each facet hash (EA source, set-file, compiled binary, native report) on
          every backing payload is a valid 64-hex lowercase sha256 — a present but
          non-conforming value is `malformed_hash`; an absent one is `<facet>_hash`;
      (2) when >=2 paired runs back the finding, they bind the SAME EA/binary identity
          tuple — generated stress/seed set hashes are each mandatory but are expected
          to differ by phase;
      (3) those paired runs carry DISTINCT report hashes — an identical report hash is
          one run re-read, not a genuine pair, and is `report_hash_not_distinct`;
      (4) the caller confirms UNROUNDED KPIs were compared (`unrounded_kpis`) and the
          per-run stress/seed telemetry is present (`telemetry`).
    Anything missing => CANDIDATE, with every violated reason code named so the gap is
    explicit rather than silently downgraded. `payloads` is one evidence dict or an
    iterable of them (all must satisfy the boundary to authenticate)."""
    if isinstance(payloads, dict) or payloads is None:
        payloads = [payloads]
    payloads = list(payloads)
    missing: list[str] = []
    if not unrounded_ok:
        missing.append("unrounded_kpis")
    if not telemetry_ok:
        missing.append("telemetry")
    if not payloads or any(p is None for p in payloads):
        missing.append("evidence_payload")
        return TIER_CANDIDATE, missing

    # (1) Per facet, per payload: the hash must be PRESENT and a valid 64-hex sha256.
    #     Absent => unbound `<facet>_hash`; present-but-not-64-hex => `malformed_hash`.
    facet_hashes: dict[str, list] = {}
    for facet, aliases in PROVENANCE_HASH_ALIASES.items():
        vals = [_extract_hash(p, aliases) for p in payloads]
        facet_hashes[facet] = vals
        if any(v is None for v in vals):
            missing.append(f"{facet}_hash")
        elif any(not _valid_sha256(v) for v in vals):
            missing.append("malformed_hash")

    # (2)+(3) Paired-run identity binding only applies when >=2 runs back the finding.
    if len(payloads) >= 2:
        # (2) EA/binary identity must be IDENTICAL across the paired runs.  The
        # generated set is phase/seed-specific and therefore must not be equal-gated.
        for facet in _PROV_IDENTITY_FACETS:
            vals = facet_hashes[facet]
            if all(v is not None for v in vals) and len(set(vals)) != 1:
                missing.append("identity_mismatch")
                break
        # (3) Each run's report hash must be DISTINCT (identical => one run, not a pair).
        reports = facet_hashes["report"]
        if all(v is not None for v in reports) and len(set(reports)) != len(reports):
            missing.append("report_hash_not_distinct")

    # Stable, de-duplicated reason list (`malformed_hash` can be hit on many facets).
    missing = list(dict.fromkeys(missing))
    tier = TIER_AUTHENTICATED if not missing else TIER_CANDIDATE
    return tier, missing


def chk_q05_q06_stress_identity(con) -> dict:
    """(a) Vacuous Q06 stress gate: HARSH 10% seeded trade-rejection yields KPIs
    byte-identical to the unstressed Q05 MEDIUM run (reject_prob 0.00), on a cohort
    where the rejection was near-certain to bite — i.e. the EA does not honour
    qm_stress_reject_probability (WP-9 basket-stress bypass / 1567 missing-input class).

    Heuristic match (CANDIDATE tier) requires: (1) two DISTINCT runs (different
    summary/report provenance — not shared evidence), (2) UNROUNDED pf+dd_money+trades
    all equal from the evidence files (not just DB-rounded), (3) stress telemetry
    present (Q06 reject probability > 0), (4) trades >= cohort floor. Legitimate
    identities are reported with a benign reason (rounded_equality, below_cohort,
    stress_not_configured, distinct_kpis) and never flag.

    Two-tier output (Codex round-2): a match is only ever a CANDIDATE unless the
    evidence ALSO binds the full provenance tuple (EA/set/binary/report sha256 +
    unrounded KPIs + stress telemetry) — then it is AUTHENTICATED. The current durable
    aggregates carry no such hashes, so live findings publish as source-corroborated
    CANDIDATES. This detector never claims a "true positive"; that word is reserved for
    the AUTHENTICATED tier."""
    cutoff = _window_cutoff_ts(VACUOUSNESS_WINDOW_DAYS)

    def latest(phase: str) -> dict:
        out: dict = {}
        for r in con.execute(
            "SELECT ea_id, symbol, profit_factor, trades, evidence_path, evidence_mtime "
            "FROM ea_metrics WHERE phase=? AND evidence_mtime IS NOT NULL "
            "AND evidence_mtime >= ? ORDER BY evidence_mtime ASC",
            (phase, cutoff),
        ):
            out[(r["ea_id"], r["symbol"])] = r
        return out

    q05, q06 = latest("Q05"), latest("Q06")
    reads = 0
    flagged: list[tuple] = []
    benign = {"rounded_equality": 0, "below_cohort": 0,
              "stress_not_configured": 0, "distinct_kpis": 0, "evidence_unavailable": 0}
    for key in sorted(set(q05) & set(q06)):
        a, b = q05[key], q06[key]
        if a["profit_factor"] is None or b["profit_factor"] is None:
            continue
        # Cheap DB pre-filter: only rows whose already-rounded PF AND trade count
        # coincide can be raw-identical. Everything else is the healthy majority.
        if not (a["profit_factor"] == b["profit_factor"] and a["trades"] == b["trades"]):
            benign["distinct_kpis"] += 1
            continue
        if reads + 2 > EVIDENCE_READ_CAP:
            break
        ev5, ev6 = _read_json_path(a["evidence_path"]), _read_json_path(b["evidence_path"])
        reads += 2
        if not ev5 or not ev6 or ev5.get("pf") is None or ev6.get("pf") is None:
            benign["evidence_unavailable"] += 1
            continue
        raw_ident = (ev5.get("pf") == ev6.get("pf")
                     and ev5.get("dd_money") == ev6.get("dd_money")
                     and ev5.get("trades") == ev6.get("trades"))
        if not raw_ident:
            benign["rounded_equality"] += 1
            continue
        rp6 = ev6.get("rejection_probability")
        if not rp6 or float(rp6) <= 0:
            benign["stress_not_configured"] += 1
            continue
        if int(ev6.get("trades") or 0) < STRESS_IDENTITY_COHORT_MIN_TRADES:
            benign["below_cohort"] += 1
            continue
        s5 = ev5.get("summary_path") or ev5.get("report_path")
        s6 = ev6.get("summary_path") or ev6.get("report_path")
        reason = "shared_evidence" if (s5 and s5 == s6) else "harsh_reject_no_effect"
        # unrounded KPIs were just compared (raw_ident) and stress telemetry (rp6>0)
        # is present, so the tier turns purely on whether the provenance hashes bind.
        tier, missing = _provenance_tier((ev5, ev6), unrounded_ok=True, telemetry_ok=True)
        flagged.append((_ea_id_int(key[0]), key[1], ev6.get("pf"), ev6.get("trades"),
                        reason, tier, missing))

    n = len(flagged)
    candidates = [f for f in flagged if f[5] == TIER_CANDIDATE]
    authenticated = [f for f in flagged if f[5] == TIER_AUTHENTICATED]
    top = "; ".join(f"{e}/{s} pf={pf} tr={tr} {rz} tier={tier}"
                    for e, s, pf, tr, rz, tier, _m in flagged[:6])
    benign_str = " ".join(f"{k}={v}" for k, v in benign.items() if v)
    unbound = sorted({m for _e, _s, _p, _t, _r, _tier, mm in flagged for m in mm})
    detail = (f"db={DB} window={VACUOUSNESS_WINDOW_DAYS}d evidence_reads={reads} "
              f"stress_identity={n} candidates={len(candidates)} "
              f"authenticated={len(authenticated)} unbound_provenance={unbound} "
              f"benign[{benign_str}] {top}").strip()
    hint = ("Vacuous Q06 CANDIDATES: 10% seeded trade-rejection changed nothing on a cohort "
            "where it must have (source-corroborated by distinct runs, provenance hashes NOT yet "
            "bound). Authenticate the EA/set/binary/report hashes then audit "
            "qm_stress_reject_probability wiring or retire the sleeve.")
    if n == 0:
        return _check("q05q06_stress_identity", "OK", 0, STRESS_IDENTITY_FAIL_COUNT, detail, "")
    status = "FAIL" if n >= STRESS_IDENTITY_FAIL_COUNT else "WARN"
    return _check("q05q06_stress_identity", status, n, STRESS_IDENTITY_FAIL_COUNT, detail, hint)


def _classify_q07_zero_variance(verdict, agg_reason, ev) -> str:
    """Consume q07_multiseed's own per-seed authentication evidence to name why a
    zero-variance Q07 aggregate is zero-variance. Never re-derives seed identity
    from filenames — reads the stored per_seed_detail.invalid_reason (which
    q07_multiseed computed from the report's effective-seed cell + the HARSH set-file
    label) and the per-seed summary provenance."""
    if ev is None:
        rz = str(agg_reason or "")
        if "effective_seed_mismatch" in rz:
            return "seed_alias"
        if "seed_evidence_missing" in rz:
            return "set_mismatch"
        return "evidence_unavailable"
    psd = ev.get("per_seed_detail") or []
    reasons = [str(s.get("invalid_reason") or "") for s in psd]
    summaries = [s.get("summary_path") or s.get("report_path") for s in psd]
    if any("effective_seed_mismatch" in x for x in reasons):
        # all seeds ran the same effective seed — the classic Q07 paper-stamp
        return "seed_alias"
    if any("seed_evidence_missing" in x for x in reasons):
        # report unreadable/absent => stale_report; HARSH label named a wrong seed => set_mismatch
        if any(("harsh_label=" in x and "harsh_label=None" not in x) for x in reasons):
            return "set_mismatch"
        return "stale_report"
    present = [s for s in summaries if s]
    if len(present) >= 2 and len(set(present)) < len(present):
        return "shared_evidence"
    if len(psd) < 2 or len(present) < len(psd):
        return "insufficient_seed_evidence"
    # Five authenticated, distinct-run seeds with identical PF: legitimate for a
    # deterministic EA (Codex: zero cross-seed variance can be legitimate).
    return "deterministic_by_design"


_Q07_ZV_FLAG_REASONS = {"seed_alias", "set_mismatch", "stale_report", "shared_evidence"}


def chk_q07_zero_variance(con) -> dict:
    """(b) Vacuous Q07: zero cross-seed PF variance. Legitimate for a deterministic EA
    (deterministic_by_design, benign). Flagged only for corruption:
    seed_alias (effective seed collapsed to one), set_mismatch / stale_report (seed
    evidence broken), or shared_evidence (seeds share a run). Consumes
    q07_multiseed's per-seed invalid_reason; does not re-derive seed identity.

    Two-tier output (Codex round-2): each flagged corruption finding is a CANDIDATE
    unless the aggregate binds the full provenance tuple (EA/set/binary/report sha256).
    The seed-auth telemetry IS consumed here, but the deployment hashes are absent from
    current aggregates, so flagged findings publish as CANDIDATES, not "true positives"."""
    cutoff = _window_cutoff_ts(VACUOUSNESS_WINDOW_DAYS)
    rows = con.execute(
        "SELECT ea_id, symbol, verdict, evidence_path, detail_json FROM ea_metrics "
        "WHERE phase='Q07' AND evidence_mtime IS NOT NULL AND evidence_mtime >= ? "
        "ORDER BY evidence_mtime DESC",
        (cutoff,),
    ).fetchall()
    reads = 0
    flagged: list[tuple] = []
    classes: dict[str, int] = {}
    for r in rows:
        dj = _json_obj(r["detail_json"])
        metrics = dj.get("metrics") or {}
        var, spread = metrics.get("variance_pct"), metrics.get("spread")
        if not (var == 0 or spread == 0):
            continue
        ev = None
        if reads < EVIDENCE_READ_CAP:
            ev = _read_json_path(r["evidence_path"])
            reads += 1
        reason = _classify_q07_zero_variance(r["verdict"], dj.get("reason"), ev)
        classes[reason] = classes.get(reason, 0) + 1
        if reason in _Q07_ZV_FLAG_REASONS:
            # seed telemetry present iff ev carries per_seed_detail; hashes still absent.
            has_seed_ev = bool(isinstance(ev, dict) and ev.get("per_seed_detail"))
            tier, missing = _provenance_tier(
                ev, unrounded_ok=has_seed_ev, telemetry_ok=has_seed_ev)
            flagged.append((_ea_id_int(r["ea_id"]), r["symbol"], reason, tier, missing))

    n = len(flagged)
    candidates = [f for f in flagged if f[3] == TIER_CANDIDATE]
    authenticated = [f for f in flagged if f[3] == TIER_AUTHENTICATED]
    top = "; ".join(f"{e}/{s} {rz} tier={tier}" for e, s, rz, tier, _m in flagged[:6])
    classes_str = " ".join(f"{k}={v}" for k, v in sorted(classes.items()))
    unbound = sorted({m for _e, _s, _r, _tier, mm in flagged for m in mm})
    detail = (f"db={DB} window={VACUOUSNESS_WINDOW_DAYS}d evidence_reads={reads} "
              f"flagged={n} candidates={len(candidates)} authenticated={len(authenticated)} "
              f"unbound_provenance={unbound} classes[{classes_str}] {top}").strip()
    hint = ("Zero-variance Q07 CANDIDATES that are NOT deterministic-by-design: seed alias / "
            "broken seed evidence let all seeds collapse (provenance hashes NOT yet bound). "
            "Re-run Q07 with the fixed injector before trusting PASS.")
    if n == 0:
        return _check("q07_zero_variance", "OK", 0, Q07_ZERO_VARIANCE_FAIL_COUNT, detail, "")
    status = "FAIL" if n >= Q07_ZERO_VARIANCE_FAIL_COUNT else "WARN"
    return _check("q07_zero_variance", status, n, Q07_ZERO_VARIANCE_FAIL_COUNT, detail, hint)


def chk_phase_invalid_rate_7d(con) -> dict:
    """(c) Trailing-7d INVALID rate per phase. A phase emitting INVALID (missing /
    unauthenticatable evidence — a run that produced no gradeable verdict) above
    threshold means the gate executes but does not actually test. Read-only DB;
    keyed on evidence_mtime so it tracks when runs were produced, not when re-ingested."""
    cutoff = _window_cutoff_ts(INVALID_RATE_WINDOW_DAYS)
    rows = con.execute(
        "SELECT phase, SUM(CASE WHEN verdict='INVALID' THEN 1 ELSE 0 END) inv, "
        "COUNT(*) tot FROM ea_metrics WHERE evidence_mtime IS NOT NULL "
        "AND evidence_mtime >= ? GROUP BY phase",
        (cutoff,),
    ).fetchall()
    worst_phase, worst_rate = None, 0.0
    parts: list[str] = []
    for r in rows:
        tot, inv = (r["tot"] or 0), (r["inv"] or 0)
        if tot < INVALID_RATE_MIN_SAMPLE:
            continue
        rate = 100.0 * inv / tot
        parts.append(f"{r['phase']}={inv}/{tot}={rate:.1f}%")
        if rate > worst_rate:
            worst_rate, worst_phase = rate, r["phase"]
    detail = (f"db={DB} window={INVALID_RATE_WINDOW_DAYS}d min_sample={INVALID_RATE_MIN_SAMPLE} "
              f"warn>={INVALID_RATE_WARN_PCT}% fail>={INVALID_RATE_FAIL_PCT}% "
              f"worst={worst_phase}:{worst_rate:.1f}% [{' '.join(parts)}]")
    hint = ("A phase's trailing-7d INVALID rate is high: the gate runs but yields no verdict "
            "(unauthenticatable / missing evidence). Investigate the phase runner / tester health.")
    if worst_rate >= INVALID_RATE_FAIL_PCT:
        return _check("phase_invalid_rate_7d", "FAIL", round(worst_rate, 1), INVALID_RATE_FAIL_PCT, detail, hint)
    if worst_rate >= INVALID_RATE_WARN_PCT:
        return _check("phase_invalid_rate_7d", "WARN", round(worst_rate, 1), INVALID_RATE_WARN_PCT, detail, hint)
    return _check("phase_invalid_rate_7d", "OK", round(worst_rate, 1), INVALID_RATE_WARN_PCT, detail, "")


def _baseline_file_for(directory: Path, ea_id: int, symbol: str) -> Path | None:
    symc = str(symbol).replace(".", "_")
    cands = [Path(directory) / f"QM5_{ea_id}_{symc}.json"]
    if symc.upper().endswith("_DWX"):
        cands.append(Path(directory) / f"QM5_{ea_id}_{symc[:-4]}.json")
    for c in cands:
        if c.is_file():
            return c
    return None


def _baseline_resolution_for(ea_id: int, symbol: str) -> dict:
    """Resolve exactly as the EA does: terminal-local first, Common fallback.

    A simultaneous, byte-divergent mirror is a hard configuration defect even
    when the currently loaded hash matches the terminal-local winner.
    """
    local_path = _baseline_file_for(LIVE_TERMINAL_BASELINE_DIR, ea_id, symbol)
    common_path = _baseline_file_for(LIVE_COMMON_BASELINE_DIR, ea_id, symbol)
    effective_path = local_path or common_path
    effective_doc = _read_json_path(effective_path) if effective_path else None
    divergent = False
    if local_path and common_path:
        try:
            divergent = local_path.read_bytes() != common_path.read_bytes()
        except OSError:
            divergent = True
    return {
        "hash": str(effective_doc["hash"]) if effective_doc and effective_doc.get("hash") else None,
        "source": "terminal_local" if local_path else ("file_common" if common_path else None),
        "effective_path": str(effective_path) if effective_path else None,
        "terminal_path": str(local_path) if local_path else None,
        "common_path": str(common_path) if common_path else None,
        "mirror_divergent": divergent,
    }


def _baseline_hash_for(ea_id: int, symbol: str) -> str | None:
    """Backward-compatible scalar accessor for tests/diagnostics."""
    return _baseline_resolution_for(ea_id, symbol).get("hash")


def _scan_ks_events(log_dir: Path) -> tuple[dict, str]:
    """Latest KS_BASELINE_LOADED/ABSENT event per (ea_id, norm_symbol) from the live QM
    EA JSONL logs. Strictly read-only (open 'rb', bounded tail). Returns ({}, status)
    when the dir is missing/empty so the caller fails to UNKNOWN, never green."""
    log_dir = Path(log_dir)
    if not log_dir.is_dir():
        return {}, "log_dir_missing"
    logs = sorted(log_dir.glob("QM5_*.log"))
    if not logs:
        return {}, "no_logs"
    observed: dict = {}
    files_read = 0
    for lf in logs:
        if files_read >= KS_LOG_FILE_CAP:
            break
        try:
            size = lf.stat().st_size
            with open(lf, "rb") as fh:
                fh.seek(max(0, size - KS_LOG_TAIL_BYTES))
                tail = fh.read().decode("utf-8", errors="ignore")
        except OSError:
            continue
        files_read += 1
        for line in tail.splitlines():
            if "KS_BASELINE" not in line:
                continue
            try:
                rec = json.loads(line)
            except (json.JSONDecodeError, ValueError):
                continue
            event = rec.get("event")
            if event not in ("KS_BASELINE_LOADED", "KS_BASELINE_ABSENT"):
                continue
            ea = _ea_id_int(rec.get("ea_id"))
            if ea is None:
                continue
            key = (ea, _norm_symbol(rec.get("symbol")))
            ts = str(rec.get("ts_utc") or "")
            prev = observed.get(key)
            if prev is None or ts >= prev["ts"]:
                payload = rec.get("payload") or {}
                observed[key] = {"event": event, "ts": ts, "hash": payload.get("hash")}
    return observed, "ok"


def chk_ks_baseline_dormancy() -> dict:
    """(d) KS divergence kill-switch dormancy on live sleeves. Binds each manifest sleeve
    to its on-disk baseline hash and requires an observed KS_BASELINE_LOADED event whose
    payload hash matches — file-exists is explicitly NOT the check. Missing manifest or
    live logs => UNKNOWN/WARN (never green-by-absence). hash_mismatch (a live EA loaded a
    baseline that no longer matches the deployed one) escalates to FAIL."""
    manifest = _read_json_path(DXZ_BOOK_MANIFEST)
    if not manifest or not isinstance(manifest.get("sleeves"), list):
        return _check("ks_baseline_dormancy", "WARN", "manifest_unavailable", "loaded",
                      f"manifest={DXZ_BOOK_MANIFEST} unreadable — cannot bind expected live sleeves",
                      "Restore the signed DXZ book manifest; KS dormancy cannot be judged without it.")
    expected: dict = {}
    for s in manifest["sleeves"]:
        ea, sym = _ea_id_int(s.get("ea_id")), s.get("symbol")
        if ea is None or not sym:
            continue
        expected[(ea, _norm_symbol(sym))] = _baseline_resolution_for(ea, sym)

    observed, log_status = _scan_ks_events(LIVE_QM_LOG_DIR)
    if log_status != "ok":
        return _check("ks_baseline_dormancy", "WARN", log_status, "loaded",
                      f"live_qm_logs={LIVE_QM_LOG_DIR} status={log_status} — cannot confirm "
                      "loaded baselines (never green by absence)",
                      "Live KS event logs unavailable; confirm T_Live is up and writing QM logs.")

    loaded_ok = 0
    dormant: list[str] = []
    no_file: list[str] = []
    mismatch: list[str] = []
    mirror_divergent: list[str] = []
    sources: dict[str, int] = {}
    for (ea, nsym), baseline in sorted(expected.items()):
        label = f"{ea}/{nsym}"
        exp_hash = baseline.get("hash")
        source = str(baseline.get("source") or "none")
        sources[source] = sources.get(source, 0) + 1
        if baseline.get("mirror_divergent"):
            mirror_divergent.append(label)
        obs = observed.get((ea, nsym))
        if exp_hash is None:
            no_file.append(label)
            continue
        if obs is None or obs["event"] == "KS_BASELINE_ABSENT":
            dormant.append(label)
            continue
        if str(obs.get("hash") or "") != str(exp_hash):
            mismatch.append(label)
            continue
        loaded_ok += 1

    total = len(expected)
    dormant_total = len(dormant) + len(no_file)
    detail = (f"manifest={DXZ_BOOK_MANIFEST.name} live_logs={LIVE_QM_LOG_DIR} sleeves={total} "
              f"loader_precedence=terminal_local_then_file_common baseline_sources={sources} "
              f"loaded_ok={loaded_ok} dormant={len(dormant)} no_baseline_file={len(no_file)} "
              f"hash_mismatch={len(mismatch)} mirror_divergent={len(mirror_divergent)} "
              f"dormant_list={dormant[:8]} "
              f"nofile={no_file[:8]} mismatch={mismatch[:8]}")
    hint = ("Live sleeves without a loaded KS baseline run with the divergence kill-switch DORMANT. "
            "Generate/deploy the Q10 baseline (gen_q10_baseline.py --deploy-live, OWNER-gated) and "
            "confirm KS_BASELINE_LOADED in the live QM logs.")
    if mismatch or mirror_divergent:
        value = f"hash_mismatch={len(mismatch)},mirror_divergent={len(mirror_divergent)}"
        return _check("ks_baseline_dormancy", "FAIL", value, 0, detail,
                      "KS baseline roots disagree or a live sleeve loaded a hash other than the "
                      "effective terminal-local/Common baseline. Reconcile to one source of truth. " + hint)
    if dormant_total:
        return _check("ks_baseline_dormancy", "WARN", dormant_total, 0, detail, hint)
    return _check("ks_baseline_dormancy", "OK", 0, 0, detail, "")


def chk_seed_auth_failure_rate(con) -> dict:
    """(e) Q07 seed-authentication failure rate. Counts in-window Q07 runs whose stored
    reason carries an authenticated seed-auth failure (effective_seed_mismatch — the
    tester ran a seed different from the one requested; or seed_evidence_missing — the
    run could not be authenticated). Consumes q07_multiseed's own evidence; never
    re-derives seed identity. Read-only DB."""
    cutoff = _window_cutoff_ts(VACUOUSNESS_WINDOW_DAYS)
    rows = con.execute(
        "SELECT ea_id, symbol, verdict, detail_json FROM ea_metrics WHERE phase='Q07' "
        "AND evidence_mtime IS NOT NULL AND evidence_mtime >= ?",
        (cutoff,),
    ).fetchall()
    total = len(rows)
    failures: list[tuple] = []
    for r in rows:
        reason = str((_json_obj(r["detail_json"]) or {}).get("reason") or "")
        if "effective_seed_mismatch" in reason or "seed_evidence_missing" in reason:
            failures.append((_ea_id_int(r["ea_id"]), r["symbol"]))
    n = len(failures)
    rate = (100.0 * n / total) if total else 0.0
    detail = (f"db={DB} window={VACUOUSNESS_WINDOW_DAYS}d q07_runs={total} seed_auth_failures={n} "
              f"rate={rate:.1f}% warn>={SEED_AUTH_FAIL_WARN} fail>={SEED_AUTH_FAIL_FAIL_PCT}% "
              f"offenders={failures[:6]}")
    hint = ("Q07 seed authentication failing: the tester did not run the requested effective seed "
            "(injector regression / seed-alias laundering). Fix the seed injector before trusting Q07 PASSes.")
    if total == 0:
        # Zero denominator => the failure RATE is undefined, not zero. Emitting OK here
        # would be green-by-absence (Codex round-2). Surface UNKNOWN as a WARN (never OK):
        # the health summary only counts OK/WARN/FAIL, so WARN is the only non-green status
        # that stays visible instead of being silently dropped.
        return _check("seed_auth_failure_rate", "WARN", "UNKNOWN", SEED_AUTH_FAIL_FAIL_PCT,
                      detail + " -> UNKNOWN (no Q07 runs in window; rate undefined, not OK)",
                      "No Q07 runs in the window: seed-auth health is UNKNOWN. Confirm Q07 is "
                      "running and re-check once runs land in-window.")
    if rate >= SEED_AUTH_FAIL_FAIL_PCT:
        return _check("seed_auth_failure_rate", "FAIL", round(rate, 1), SEED_AUTH_FAIL_FAIL_PCT, detail, hint)
    if n >= SEED_AUTH_FAIL_WARN:
        return _check("seed_auth_failure_rate", "WARN", n, SEED_AUTH_FAIL_WARN, detail, hint)
    return _check("seed_auth_failure_rate", "OK", 0, SEED_AUTH_FAIL_FAIL_PCT, detail, "")


# --- Agent-task state-machine liveness (census 2026-07-27 ranks 4/5/8/9) ------
# The deterministic router selects only BACKLOG/TODO; RECYCLE, APPROVED and
# PIPELINE have no router exit, so a task can sit in one indefinitely. This
# invariant makes that visible: it counts limbo-state tasks (with a staleness
# split) and any directory-valued artifact_path (rank 9, which timed out the
# build-guardrail scan). Remediation is the explicit, dry-run-first
# `agent_router.py reconcile-exits`, never a silent bulk move.
STRANDED_LIMBO_STATES = ("RECYCLE", "APPROVED", "PIPELINE")
STRANDED_TASK_STALE_DAYS = 3
# Set above the known ~700-row legacy backlog (census 2026-07-27) so today's
# inherited tail reads as an actionable WARN, not a permanent red banner, while
# genuine growth beyond it (a new leak) escalates to FAIL. Retune here.
STRANDED_TASK_FAIL_TOTAL = 900


def chk_agent_task_state_stranded(con) -> dict:
    """Agent tasks parked in a router-exitless limbo state (RECYCLE/APPROVED/
    PIPELINE), plus directory-valued artifact paths. Surfaces the census rank
    4/5/8/9 dead ends so work never strands invisibly."""
    tbl = con.execute(
        "SELECT name FROM sqlite_master WHERE type='table' AND name='agent_tasks'"
    ).fetchone()
    if not tbl:
        return _check("agent_task_state_stranded", "OK", 0, STRANDED_TASK_FAIL_TOTAL,
                      "agent_tasks table absent", "")
    placeholders = ",".join("?" for _ in STRANDED_LIMBO_STATES)
    by_state = {
        r["state"]: int(r["n"])
        for r in con.execute(
            f"SELECT state, COUNT(*) n FROM agent_tasks WHERE state IN ({placeholders}) GROUP BY state",
            STRANDED_LIMBO_STATES,
        ).fetchall()
    }
    total = sum(by_state.values())
    stale_cutoff = (_utc_now() - dt.timedelta(days=STRANDED_TASK_STALE_DAYS)).strftime("%Y-%m-%dT%H:%M:%SZ")
    stale = con.execute(
        f"SELECT COUNT(*) FROM agent_tasks WHERE state IN ({placeholders}) AND updated_at < ?",
        (*STRANDED_LIMBO_STATES, stale_cutoff),
    ).fetchone()[0]
    dir_artifacts = 0
    for r in con.execute(
        "SELECT artifact_path FROM agent_tasks WHERE artifact_path IS NOT NULL AND artifact_path != ''"
    ).fetchall():
        first = str(r["artifact_path"]).split(";")[0].strip()
        if not first:
            continue
        p = Path(first)
        if not p.is_absolute():
            p = REPO_ROOT / first
        try:
            if p.is_dir():
                dir_artifacts += 1
        except OSError:
            continue
    order = ", ".join(f"{s}={by_state.get(s, 0)}" for s in STRANDED_LIMBO_STATES)
    detail = (f"limbo tasks: {order} total={total} (>{STRANDED_TASK_STALE_DAYS}d stale={stale}); "
              f"directory_artifacts={dir_artifacts}")
    hint = ("Report/apply exits with `python tools/strategy_farm/agent_router.py reconcile-exits` "
            "(dry-run first); RECYCLE->TODO re-queues builds and is an OWNER capacity decision. "
            "See docs/ops/evidence/2026-07-27_state_machine_exits_fix.md")
    if total >= STRANDED_TASK_FAIL_TOTAL:
        return _check("agent_task_state_stranded", "FAIL", total, STRANDED_TASK_FAIL_TOTAL, detail, hint)
    if total > 0 or dir_artifacts > 0:
        return _check("agent_task_state_stranded", "WARN", total, STRANDED_TASK_FAIL_TOTAL, detail, hint)
    return _check("agent_task_state_stranded", "OK", 0, STRANDED_TASK_FAIL_TOTAL, detail, "")


# --- Pending tail-age + summary-missing classification detectors (census ranks 1/3) ---
# The queue drains in aggregate (net-negative most days) but an inherited tail of old
# pending rows does NOT resolve FIFO: within Q02 the claim order is deliberately
# priority-first (frontier/winner/metal>index>fx), with created_at only the final
# tie-break, and ~87% of the old tail is `recovery_class`-tagged and idle-capped by the
# ratified Operating-Rule-22 throttle. That ordering is intentional; the fix for rank 3
# is to make the tail's AGE visible, not to change the claim path. See
# docs/ops/evidence/2026-07-27_failure_classification_fix.md.
PENDING_TAIL_STALE_DAYS = 14
# Above the inherited >14d tail (census 1,458; measured ~1,410 on 2026-07-27) so the
# standing recovery-capped backlog reads as an actionable amber while genuine REGROWTH
# (a new leak / a drain stall) escalates to red. Retune here.
PENDING_TAIL_FAIL_TOTAL = 1900

# Rising-unclassified detector: new Q02 summary-missing terminals must land with a
# failure_class (the forward classifier stamps one on every exhaustion). A recent window
# where a large share carry NO failure_class means the classifier regressed; a large
# share of failure_class=UNCLASSIFIED means a new failure mode the signatures don't cover.
SM_UNCLASSIFIED_WINDOW_H = 48
SM_UNCLASSIFIED_MIN_VOL = 20
SM_MISSING_CLASS_FAIL_FRAC = 0.50
SM_UNCLASSIFIED_WARN_FRAC = 0.50


def chk_pending_tail_age(con) -> dict:
    """Surface the old-pending tail and the claim-time age credit."""
    cutoff = (_utc_now() - dt.timedelta(days=PENDING_TAIL_STALE_DAYS)).strftime("%Y-%m-%dT%H:%M:%SZ")
    old = con.execute(
        "SELECT COUNT(*) FROM work_items WHERE status='pending' AND created_at < ?",
        (cutoff,),
    ).fetchone()[0]
    if not old:
        return _check("pending_tail_age", "OK", 0, PENDING_TAIL_FAIL_TOTAL,
                      f"no pending row older than {PENDING_TAIL_STALE_DAYS}d", "")
    by_phase = {
        r["phase"]: int(r["n"])
        for r in con.execute(
            "SELECT phase, COUNT(*) n FROM work_items WHERE status='pending' AND created_at < ? "
            "GROUP BY phase ORDER BY n DESC",
            (cutoff,),
        ).fetchall()
    }
    recovery = con.execute(
        "SELECT COUNT(*) FROM work_items WHERE status='pending' AND created_at < ? "
        "AND payload_json LIKE '%\"recovery_class\":%'",
        (cutoff,),
    ).fetchone()[0]
    oldest = con.execute(
        "SELECT MIN(created_at) FROM work_items WHERE status='pending'"
    ).fetchone()[0]
    max_age_weeks = con.execute(
        "SELECT MAX(MAX(0, CAST(COALESCE(julianday('now') - julianday(created_at), 0) / 7 AS INTEGER))) "
        "FROM work_items WHERE status='pending'"
    ).fetchone()[0] or 0
    phase_str = ", ".join(f"{k}={v}" for k, v in list(by_phase.items())[:5])
    detail = (f"{old} pending >{PENDING_TAIL_STALE_DAYS}d ({phase_str}); recovery_class={recovery} "
              f"(idle-capped by design); oldest_created={oldest}; "
              f"max_age_credit_weeks={max_age_weeks}")
    hint = ("Claim-time effective priority subtracts one point per whole age week; "
            "recovery_class rows remain Operating-Rule-22 idle-capped. Investigate "
            "only if this grows while the queue is otherwise draining.")
    if old >= PENDING_TAIL_FAIL_TOTAL:
        return _check("pending_tail_age", "FAIL", old, PENDING_TAIL_FAIL_TOTAL, detail, hint)
    return _check("pending_tail_age", "WARN", old, PENDING_TAIL_FAIL_TOTAL, detail, hint)


def chk_q02_summary_missing_unclassified(con) -> dict:
    """Catch a rising unclassified-failure rate (census rank 1). Every new Q02
    summary-missing terminal must carry a failure_class from the forward classifier;
    a recent window where many carry none (classifier regressed) or many are UNCLASSIFIED
    (a new failure mode the signatures miss) surfaces here."""
    cutoff = (_utc_now() - dt.timedelta(hours=SM_UNCLASSIFIED_WINDOW_H)).strftime("%Y-%m-%dT%H:%M:%SZ")
    rows = con.execute(
        "SELECT payload_json FROM work_items "
        "WHERE phase='Q02' AND verdict IN ('INFRA_FAIL','INVALID') AND updated_at >= ? "
        "AND json_extract(payload_json,'$.final_failure')='summary_missing_retries_exhausted'",
        (cutoff,),
    ).fetchall()
    vol = len(rows)
    missing = 0
    unclassified = 0
    for r in rows:
        try:
            p = json.loads(r["payload_json"] or "{}")
        except (json.JSONDecodeError, TypeError):
            p = {}
        cls = p.get("failure_class")
        if not cls:
            missing += 1
        elif cls == "UNCLASSIFIED":
            unclassified += 1
    if vol < SM_UNCLASSIFIED_MIN_VOL:
        return _check("q02_summary_missing_unclassified", "OK", 0, SM_MISSING_CLASS_FAIL_FRAC,
                      f"only {vol} recent summary-missing terminals (<{SM_UNCLASSIFIED_MIN_VOL}); no signal", "")
    miss_frac = missing / vol
    unc_frac = unclassified / vol
    detail = (f"{vol} summary-missing terminals in {SM_UNCLASSIFIED_WINDOW_H}h: "
              f"no failure_class={missing} ({miss_frac:.0%}), UNCLASSIFIED={unclassified} ({unc_frac:.0%})")
    hint = ("no failure_class => forward classifier regressed (farmctl.classify_summary_missing_run "
            "not wired at the exhaustion boundary); high UNCLASSIFIED => a new summary-missing "
            "signature the classifier does not yet cover. See "
            "docs/ops/evidence/2026-07-27_failure_classification_fix.md")
    if miss_frac >= SM_MISSING_CLASS_FAIL_FRAC:
        return _check("q02_summary_missing_unclassified", "FAIL", round(miss_frac, 2),
                      SM_MISSING_CLASS_FAIL_FRAC, detail, hint)
    if unc_frac >= SM_UNCLASSIFIED_WARN_FRAC:
        return _check("q02_summary_missing_unclassified", "WARN", round(unc_frac, 2),
                      SM_UNCLASSIFIED_WARN_FRAC, detail, hint)
    return _check("q02_summary_missing_unclassified", "OK", round(max(miss_frac, unc_frac), 2),
                  SM_MISSING_CLASS_FAIL_FRAC, detail, "")


ALL_CHECKS = [
    ("ea_id_slug_uniqueness", chk_ea_id_slug_uniqueness, False),
    ("stranded_ea_improvements", chk_stranded_ea_improvements, False),
    ("codex_review_fail_rate", chk_codex_review_fail_rate, True),  # needs con
    ("cards_ready_stagnation", chk_cards_ready_stagnation, True),
    ("pump_task_health",       chk_pump_task_health,       False),
    ("factory_mutation_lock",  chk_factory_mutation_lock,  False),
    ("factory_on_ceremony_incomplete", chk_factory_on_ceremony_incomplete, False),
    ("custom_history_repairs_24h", chk_custom_history_repairs, False),
    ("usn_journal_d",          chk_usn_journal_d,          False),
    ("work_items_timestamp_sanity", chk_work_items_timestamp_sanity, True),
    ("p2_pass_no_p3",          chk_p2_pass_no_p3,          True),
    ("ea_metrics_fresh",       chk_ea_metrics_fresh,       True),
    ("ablation_grandchildren", chk_ablation_grandchildren, True),
    ("claude_review_starved",  chk_claude_review_starved,  True),
    ("mt5_dispatch_idle",      chk_mt5_dispatch_idle,      True),
    ("mt5_worker_saturation",  chk_mt5_worker_saturation,  True),
    ("terminal_account_profiles", chk_terminal_account_profiles, False),
    ("active_row_age",         chk_active_row_age,         True),
    ("codex_zero_activity",    chk_codex_zero_activity,    True),
    ("source_pool",            chk_source_pool,            True),
    ("zerotrade_rework_backlog", chk_zerotrade_rework_backlog, True),
    ("unbuilt_cards_count",    chk_unbuilt_cards_count,    True),
    ("unenqueued_eas_count",   chk_unenqueued_eas_count,   True),
    ("codex_bridge_heartbeat", chk_codex_bridge_heartbeat, True),
    ("agent_lane_heartbeat",   chk_agent_lane_heartbeat,   True),
    ("disk_free_space",        chk_disk_free_space,        True),
    ("p_pass_stagnation",      chk_p_pass_stagnation,      True),
    ("phase_infra_graveyard",  chk_phase_infra_graveyard,  True),
    ("q02_stranded_exhausted_pairs", chk_q02_stranded_exhausted_pairs, True),
    ("quota_snapshot_fresh",   chk_quota_snapshot_fresh,   False),
    ("lsm_session_health",     chk_lsm_session_health,     False),
    ("codex_auth_broken",      chk_codex_auth_broken,      True),
    # WS-F standing vacuousness audit (ULTRACODE 2026-07-26)
    ("q05q06_stress_identity", chk_q05_q06_stress_identity, True),
    ("q07_zero_variance",      chk_q07_zero_variance,       True),
    ("phase_invalid_rate_7d",  chk_phase_invalid_rate_7d,   True),
    ("ks_baseline_dormancy",   chk_ks_baseline_dormancy,    False),
    ("seed_auth_failure_rate", chk_seed_auth_failure_rate,  True),
    # Agent-task state-machine liveness (census 2026-07-27 ranks 4/5/8/9)
    ("agent_task_state_stranded", chk_agent_task_state_stranded, True),
    # Failure-classification + tail detectors (census 2026-07-27 ranks 1/3)
    ("pending_tail_age", chk_pending_tail_age, True),
    ("q02_summary_missing_unclassified", chk_q02_summary_missing_unclassified, True),
]


def run_all() -> dict:
    """Run all health checks. Returns the result dict and writes health.json.

    The DB handle is read-only (see _connect). If the read-only connect itself fails
    (e.g. the factory DB is absent), con-needing checks degrade to a single WARN each
    rather than crashing the whole pass — health OUTPUT still gets written."""
    try:
        con = _connect()
    except sqlite3.Error:
        con = None
    results = []
    try:
        for name, fn, needs_con in ALL_CHECKS:
            try:
                if needs_con and con is None:
                    results.append(_check(name, "WARN", "no_db", "ok",
                                          f"read-only DB connect failed: {DB}",
                                          "Confirm farm_state.sqlite exists and is readable."))
                    continue
                results.append(fn(con) if needs_con else fn())
            except Exception as exc:
                results.append(_check(fn.__name__, "WARN", "exception", "?",
                                      f"check raised: {exc!r}",
                                      "Investigate health.py — check code"))
    finally:
        if con is not None:
            con.close()

    summary = {"ok": 0, "warn": 0, "fail": 0}
    for r in results:
        key = r["status"].lower()
        if key in summary:
            summary[key] += 1
    overall = "FAIL" if summary["fail"] > 0 else ("WARN" if summary["warn"] > 0 else "OK")

    payload = {
        "checked_at": _utc_now().strftime("%Y-%m-%dT%H:%M:%SZ"),
        "overall": overall,
        "summary": summary,
        "checks": results,
    }
    HEALTH_FILE.parent.mkdir(parents=True, exist_ok=True)
    HEALTH_FILE.write_text(json.dumps(payload, indent=2, sort_keys=True), encoding="utf-8")

    # Append alarms to log
    fails = [r for r in results if r["status"] == "FAIL"]
    if fails:
        ALARMS_LOG.parent.mkdir(parents=True, exist_ok=True)
        with ALARMS_LOG.open("a", encoding="utf-8") as f:
            for r in fails:
                f.write(f"{payload['checked_at']}\t{r['name']}\t{r['value']}\t{r['detail']}\n")
    return payload
