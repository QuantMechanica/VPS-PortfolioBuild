"""Factory bottleneck read-model (``qm.factory-bottleneck/v1``).

Deterministically composes the §60 FACTORY section source
``D:/QM/reports/state/factory_bottleneck.json`` from **read-only** inputs:

  * ``farm_state.sqlite`` (``mode=ro``) — active claims, claimable pending rows
    (pending minus rows carrying an active ``work_item_holds`` hold), pending by
    phase, and the active-hold class histogram.
  * ``D:/QM/reports/state/pipeline_state.json`` — the ``by_gate_v4``
    highest-contiguous-valid-gate frontier census and the ``book_guard`` block
    (candidate counts, shown as a diagnostic — never a goal).
  * ``D:/QM/strategy_farm/state/drain_window.json`` — the current pre-drain
    reservation (GB + EA) that head-of-line-blocks the claim head.
  * ``D:/QM/strategy_farm/logs/terminal_worker_T*.log`` — the latest
    ``claim_result`` per terminal, to count terminals self-parked in
    ``drain_predrain`` while claimable rows wait (the §72 "terminals idle in
    drain_predrain vs claimable pending" signal).
  * resource counters — D: free (``shutil.disk_usage``); RAM free / CPU via
    ``psutil`` when importable, otherwise reported ``UNKNOWN`` (never invented).

This module also owns the small shared read-model loader ``load_readmodel`` and
the ``compute_book_evolution_health`` helper that Mission Control's data contract
imports, so the freshness/health logic has a single source of truth.

The module never opens the DB writable, never starts a process, and writes only
under ``D:/QM/reports/state/``. Missing inputs are explicit
(``NOT_EVALUATED`` / ``UNKNOWN`` / ``EVIDENCE_MISSING``), never zero-forged.

CLI::

    python tools/strategy_farm/factory_bottleneck_readmodel.py build
    python tools/strategy_farm/factory_bottleneck_readmodel.py build --stdout
"""

from __future__ import annotations

import argparse
import datetime as dt
import json
import os
import shutil
import sqlite3
import sys
from pathlib import Path
from typing import Any

SCHEMA_VERSION = "qm.factory-bottleneck/v1"
HEALTH_SCHEMA_VERSION = "qm.book-evolution-health/v1"

# --- canonical paths (module-level so tests can monkeypatch) ---
ROOT = Path(r"D:\QM\strategy_farm")
REPORTS_STATE = Path(r"D:\QM\reports\state")
DB = ROOT / "state" / "farm_state.sqlite"
DRAIN_WINDOW = ROOT / "state" / "drain_window.json"
PIPELINE_STATE = REPORTS_STATE / "pipeline_state.json"
WORKER_LOG_DIR = ROOT / "logs"
OUTPUT_PATH = REPORTS_STATE / "factory_bottleneck.json"
HEALTH_OUTPUT_PATH = REPORTS_STATE / "book_evolution_health.json"

# Book-evolution read-models the health composer grades for freshness.
BOOK_EVOLUTION_DXZ = REPORTS_STATE / "book_evolution_dxz.json"
BOOK_EVOLUTION_FTMO = REPORTS_STATE / "book_evolution_ftmo.json"
FTMO_READINESS = REPORTS_STATE / "ftmo_challenge_readiness.json"
RESEARCH_STATE = REPORTS_STATE / "research_state.json"
# Strategy Wiki completeness read-model (tools/strategy_farm/strategy_wiki_sync.py lint).
STRATEGY_WIKI_SYNC = REPORTS_STATE / "strategy_wiki_sync.json"

FLEET = tuple(f"T{i}" for i in range(1, 11))

# A worker log is only consulted for the live idle-in-drain signal when its
# file was touched within this window; older logs are stale, not evidence.
WORKER_LOG_RECENCY_SEC = 45 * 60
# Bytes of each worker log tail scanned for the latest claim_result record.
WORKER_LOG_TAIL_BYTES = 24 * 1024

# Frontier bands that a terminal can still advance (Q00/Q01 pre-tester and the
# OWNER gates Q15..Q17 are not factory-throughput bands).
FRONTIER_ADVANCEABLE = tuple(f"Q{i:02d}" for i in range(2, 15))

# Hold classes that are deliberately inert and are NOT backlog debt.
BENIGN_HOLD_CODES = frozenset({"PRESCREEN_SKIPPED"})
# Hold classes that indicate a repairable infra problem (not merit).
INFRA_HOLD_PREFIXES = (
    "NEWS_CALENDAR_TAINTED", "Q08_DSR_CONTEXT_UNAVAILABLE",
    "ARTIFACT_BINDING", "RAM_RESERVATION", "COMPILE_EA",
)

# Freshness SLAs used by the health composer (seconds).
SLA_BOOK_EVOLUTION_SEC = 24 * 3600      # book read-models: daily/weekly cadence
SLA_RESEARCH_SEC = 24 * 3600
SLA_FACTORY_BOTTLENECK_SEC = 60 * 60    # this file refreshes /15 min
# D: free-space warning floor (LowWater purge fires at 60 GB).
DISK_WARN_GB = 65.0


# ---------------------------------------------------------------------------
# time helpers
# ---------------------------------------------------------------------------
def _now_utc() -> dt.datetime:
    return dt.datetime.now(dt.timezone.utc)


def _iso(t: dt.datetime) -> str:
    return t.astimezone(dt.timezone.utc).replace(microsecond=0).isoformat()


def _parse_iso(value: str | None) -> dt.datetime | None:
    if not value:
        return None
    try:
        t = dt.datetime.fromisoformat(str(value).replace("Z", "+00:00"))
        if t.tzinfo is None:
            t = t.replace(tzinfo=dt.timezone.utc)
        return t.astimezone(dt.timezone.utc)
    except (TypeError, ValueError):
        return None


def _age_seconds(value: str | None, *, now: dt.datetime) -> int | None:
    t = _parse_iso(value)
    if t is None:
        return None
    return max(0, int((now - t).total_seconds()))


# ---------------------------------------------------------------------------
# shared read-model loader (imported by mission_control_v2_data)
# ---------------------------------------------------------------------------
def load_readmodel(path: Path, *, now: dt.datetime | None = None,
                   sla_sec: int | None = None) -> dict[str, Any]:
    """Fail-soft load of a book-evolution read-model file.

    Returns a fixed shape regardless of file content so consumers never crash:
    an absent or unreadable file yields ``present=False`` +
    ``degraded_reason='EVIDENCE_MISSING'``; a present file surfaces its parsed
    ``payload`` plus a freshness classification derived from
    ``generated_at_utc``.
    """
    now = now or _now_utc()
    path = Path(path)
    result: dict[str, Any] = {
        "present": False,
        "source_path": str(path),
        "generated_at_utc": None,
        "age_seconds": None,
        "staleness": "UNKNOWN",
        "degraded_reason": "EVIDENCE_MISSING",
        "payload": {},
    }
    try:
        raw = path.read_text(encoding="utf-8-sig")
    except FileNotFoundError:
        return result
    except OSError as exc:
        result["degraded_reason"] = f"unreadable: {exc}"
        return result
    try:
        payload = json.loads(raw)
    except json.JSONDecodeError as exc:
        result["degraded_reason"] = f"invalid JSON: {exc}"
        return result
    if not isinstance(payload, dict):
        result["degraded_reason"] = "payload is not an object"
        return result

    result["present"] = True
    result["degraded_reason"] = None
    result["payload"] = payload
    generated = payload.get("generated_at_utc") or payload.get("generated_at")
    result["generated_at_utc"] = generated
    age = _age_seconds(generated, now=now)
    result["age_seconds"] = age
    if age is None:
        result["staleness"] = "UNKNOWN"
    elif sla_sec is None:
        result["staleness"] = "FRESH"
    else:
        result["staleness"] = "FRESH" if age <= sla_sec else "STALE"
    return result


def load_book_evolution_readmodels(*, now: dt.datetime | None = None,
                                   paths: dict[str, Path] | None = None
                                   ) -> dict[str, Any]:
    """Load every book-evolution read-model Mission Control binds, fail-soft."""
    now = now or _now_utc()
    paths = paths or {}
    dxz = load_readmodel(paths.get("dxz", BOOK_EVOLUTION_DXZ),
                         now=now, sla_sec=SLA_BOOK_EVOLUTION_SEC)
    ftmo = load_readmodel(paths.get("ftmo", BOOK_EVOLUTION_FTMO),
                          now=now, sla_sec=SLA_BOOK_EVOLUTION_SEC)
    ftmo_readiness = load_readmodel(paths.get("ftmo_readiness", FTMO_READINESS),
                                    now=now, sla_sec=SLA_BOOK_EVOLUTION_SEC)
    research = load_readmodel(paths.get("research", RESEARCH_STATE),
                              now=now, sla_sec=SLA_RESEARCH_SEC)
    bottleneck = load_readmodel(paths.get("bottleneck", OUTPUT_PATH),
                                now=now, sla_sec=SLA_FACTORY_BOTTLENECK_SEC)
    wiki_sync = load_readmodel(paths.get("strategy_wiki_sync", STRATEGY_WIKI_SYNC),
                               now=now, sla_sec=SLA_BOOK_EVOLUTION_SEC)
    return {
        "book_evolution": {"dxz": dxz, "ftmo": ftmo},
        "ftmo_challenge_readiness": ftmo_readiness,
        "research_state": research,
        "factory_bottleneck": bottleneck,
        "strategy_wiki_sync": wiki_sync,
    }


def compute_book_evolution_health(loaded: dict[str, Any]) -> dict[str, Any]:
    """Derive the four Mission Control / Heartbeat health keys from the loaded
    read-models (GREEN/AMBER/RED by freshness, plus three summary keys)."""
    be = loaded.get("book_evolution", {}) or {}
    dxz = be.get("dxz", {}) or {}
    ftmo = be.get("ftmo", {}) or {}
    readiness = loaded.get("ftmo_challenge_readiness", {}) or {}
    research = loaded.get("research_state", {}) or {}
    bottleneck = loaded.get("factory_bottleneck", {}) or {}

    graded = [dxz, ftmo, research, bottleneck]
    present = [g for g in graded if g.get("present")]
    if not present:
        readmodels_state = "RED"
    elif len(present) == len(graded) and not any(
        g.get("staleness") == "STALE" for g in present
    ):
        readmodels_state = "GREEN"
    else:
        readmodels_state = "AMBER"

    if readiness.get("present"):
        rec = str((readiness.get("payload") or {}).get("recommendation")
                  or "UNKNOWN")
    else:
        rec = "EVIDENCE_MISSING"

    if research.get("present"):
        research_freshness = research.get("staleness") or "UNKNOWN"
    else:
        research_freshness = "EVIDENCE_MISSING"

    if bottleneck.get("present"):
        bl = (bottleneck.get("payload") or {}).get("bottlenecks") or []
        top = str(bl[0].get("name")) if bl and isinstance(bl[0], dict) else "NONE"
    else:
        top = "EVIDENCE_MISSING"

    wiki_sync = loaded.get("strategy_wiki_sync", {}) or {}
    if wiki_sync.get("present"):
        wiki_state = str((wiki_sync.get("payload") or {}).get("STRATEGY_WIKI_SYNC")
                         or "UNKNOWN")
    else:
        wiki_state = "EVIDENCE_MISSING"

    return {
        "book_evolution_readmodels": readmodels_state,
        "ftmo_readiness_recommendation": rec,
        "research_state_freshness": research_freshness,
        "factory_bottleneck_top": top,
        "strategy_wiki_sync": wiki_state,
    }


# ---------------------------------------------------------------------------
# database access (read-only)
# ---------------------------------------------------------------------------
def _connect_ro(db: Path) -> sqlite3.Connection:
    con = sqlite3.connect(f"file:{Path(db).as_posix()}?mode=ro", uri=True)
    con.row_factory = sqlite3.Row
    con.execute("PRAGMA busy_timeout=5000")
    con.execute("PRAGMA query_only=ON")
    return con


def _has_table(con: sqlite3.Connection, name: str) -> bool:
    row = con.execute(
        "SELECT 1 FROM sqlite_master WHERE type='table' AND name=?", (name,)
    ).fetchone()
    return row is not None


def collect_queue_state(con: sqlite3.Connection) -> dict[str, Any]:
    """Active claims, claimable pending (pending minus active-held), and the
    active-hold class histogram."""
    active = int(
        con.execute("SELECT COUNT(*) FROM work_items WHERE status='active'")
        .fetchone()[0]
    )
    pending_total = int(
        con.execute("SELECT COUNT(*) FROM work_items WHERE status='pending'")
        .fetchone()[0]
    )

    held_ids: set[str] = set()
    holds_by_class: dict[str, int] = {}
    if _has_table(con, "work_item_holds"):
        for row in con.execute(
            "SELECT work_item_id, hold_code FROM work_item_holds "
            "WHERE released_at IS NULL"
        ):
            wid = row["work_item_id"]
            if wid is not None:
                held_ids.add(str(wid))
            code = str(row["hold_code"] or "UNKNOWN")
            holds_by_class[code] = holds_by_class.get(code, 0) + 1

    # claimable = pending rows without an active hold.
    claimable = 0
    for row in con.execute("SELECT id FROM work_items WHERE status='pending'"):
        if str(row["id"]) not in held_ids:
            claimable += 1

    pending_by_phase: dict[str, int] = {}
    for row in con.execute(
        "SELECT phase, COUNT(*) AS n FROM work_items WHERE status='pending' "
        "GROUP BY phase"
    ):
        pending_by_phase[str(row["phase"] or "UNKNOWN")] = int(row["n"])

    return {
        "active": active,
        "pending_total": pending_total,
        "claimable_pending": claimable,
        "held_pending_or_other": len(held_ids),
        "pending_by_phase": pending_by_phase,
        "holds_by_class": holds_by_class,
    }


# ---------------------------------------------------------------------------
# frontier (from pipeline_state.json)
# ---------------------------------------------------------------------------
def load_frontier(path: Path | None = None, *, now: dt.datetime | None = None
                  ) -> dict[str, Any]:
    now = now or _now_utc()
    rm = load_readmodel(path or PIPELINE_STATE, now=now)
    if not rm.get("present"):
        return {
            "by_gate_v4": "NOT_EVALUATED",
            "book_guard": "NOT_EVALUATED",
            "source_path": rm.get("source_path"),
            "degraded_reason": rm.get("degraded_reason"),
        }
    payload = rm.get("payload") or {}
    by_gate = payload.get("by_gate_v4")
    op = payload.get("operator_surface") or {}
    book_guard = op.get("book_guard") if isinstance(op, dict) else None
    return {
        "by_gate_v4": by_gate if isinstance(by_gate, dict) else "NOT_EVALUATED",
        "book_guard": book_guard if isinstance(book_guard, dict) else "NOT_EVALUATED",
        "source_path": rm.get("source_path"),
        "generated_at_utc": rm.get("generated_at_utc"),
        "degraded_reason": None,
    }


def _largest_frontier_band(by_gate: Any) -> dict[str, Any] | None:
    if not isinstance(by_gate, dict):
        return None
    best_gate = None
    best_count = -1
    for gate in FRONTIER_ADVANCEABLE:
        count = int(by_gate.get(gate) or 0)
        if count > best_count:
            best_count = count
            best_gate = gate
    if best_gate is None or best_count <= 0:
        return None
    return {"gate": best_gate, "count": best_count}


# ---------------------------------------------------------------------------
# idle-in-drain signal (from worker logs + drain_window.json)
# ---------------------------------------------------------------------------
def _iter_log_records(path: Path) -> list[dict]:
    """Parse the JSON records in a worker log tail (CR/LF-delimited)."""
    try:
        size = path.stat().st_size
        with path.open("rb") as fh:
            if size > WORKER_LOG_TAIL_BYTES:
                fh.seek(size - WORKER_LOG_TAIL_BYTES)
            blob = fh.read()
    except OSError:
        return []
    text = blob.decode("utf-8", errors="replace")
    records: list[dict] = []
    for chunk in text.replace("\r", "\n").split("\n"):
        chunk = chunk.strip()
        if not chunk or not chunk.startswith("{"):
            continue
        try:
            obj = json.loads(chunk)
        except json.JSONDecodeError:
            continue
        if isinstance(obj, dict):
            records.append(obj)
    return records


def detect_idle_in_drain(log_dir: Path | None = None, *,
                         now: dt.datetime | None = None) -> dict[str, Any]:
    """Count fleet terminals whose latest recent ``claim_result`` shows them
    self-parked (``no_pending_claimable`` while skipping RAM/longrun rows)."""
    now = now or _now_utc()
    log_dir = Path(log_dir or WORKER_LOG_DIR)
    idle_terminals: list[str] = []
    scanned: list[str] = []
    for term in FLEET:
        path = log_dir / f"terminal_worker_{term}.log"
        try:
            mtime = path.stat().st_mtime
        except OSError:
            continue
        if (now.timestamp() - mtime) > WORKER_LOG_RECENCY_SEC:
            continue  # stale log — not live evidence
        scanned.append(term)
        latest_claim = None
        for rec in reversed(_iter_log_records(path)):
            if rec.get("stage_event") == "claim_result" or rec.get("event") == "claim_result":
                latest_claim = rec
                break
        if latest_claim is None:
            continue
        reason = str(latest_claim.get("reason") or "")
        skips = latest_claim.get("skips") or {}
        skipped = int(skips.get("ram_class_skipped") or 0) + int(
            skips.get("longrun_cap_skipped") or 0
        )
        if reason == "no_pending_claimable" and skipped > 0:
            idle_terminals.append(term)

    return {
        "idle_in_drain": len(idle_terminals),
        "idle_terminals": idle_terminals,
        "logs_scanned": scanned,
        "recency_window_seconds": WORKER_LOG_RECENCY_SEC,
    }


def load_drain_window(path: Path | None = None) -> dict[str, Any]:
    rm = load_readmodel(path or DRAIN_WINDOW)
    if not rm.get("present"):
        return {"reservation_gb": None, "ea_id": None, "opened_iso": None,
                "present": False}
    pre = (rm.get("payload") or {}).get("pre_drain") or {}
    return {
        "reservation_gb": pre.get("reservation_gb"),
        "ea_id": pre.get("ea_id"),
        "opened_iso": pre.get("opened_iso"),
        "present": True,
    }


# ---------------------------------------------------------------------------
# resource counters
# ---------------------------------------------------------------------------
def collect_resources() -> dict[str, Any]:
    resources: dict[str, Any] = {
        "cpu_pct": "UNKNOWN",
        "ram_free_gb": "UNKNOWN",
        "d_free_gb": "UNKNOWN",
    }
    try:
        usage = shutil.disk_usage("D:/")
        resources["d_free_gb"] = round(usage.free / (1024 ** 3), 1)
    except OSError:
        pass
    try:
        import psutil  # type: ignore

        resources["cpu_pct"] = round(float(psutil.cpu_percent(interval=0.3)), 1)
        vm = psutil.virtual_memory()
        resources["ram_free_gb"] = round(vm.available / (1024 ** 3), 1)
    except Exception:  # noqa: BLE001 — psutil optional; never invent values
        pass
    return resources


# ---------------------------------------------------------------------------
# bottleneck ranking
# ---------------------------------------------------------------------------
def _as_int(value: Any) -> int:
    """Coerce a counter to int; explicit sentinels (NOT_EVALUATED/...) -> 0."""
    if isinstance(value, bool):
        return 0
    if isinstance(value, int):
        return value
    if isinstance(value, float):
        return int(value)
    return 0


def rank_bottlenecks(*, queue: dict, frontier: dict, drain: dict,
                     idle: dict, resources: dict) -> list[dict[str, Any]]:
    candidates: list[dict[str, Any]] = []

    idle_n = _as_int(idle.get("idle_in_drain"))
    claimable = _as_int(queue.get("claimable_pending"))
    reservation_gb = drain.get("reservation_gb")
    drain_ea = drain.get("ea_id")
    if idle_n >= 1 and claimable >= 1:
        candidates.append({
            "name": "unwinnable_reservation_head_of_line_block",
            "severity": "CRITICAL",
            "evidence": (
                f"{idle_n}/{len(FLEET)} terminals self-parked in drain_predrain "
                f"(reservation {reservation_gb} GB, ea {drain_ea}) while "
                f"{claimable} claimable pending rows wait unclaimed"
            ),
            "cost": (
                f"~{idle_n}/{len(FLEET)} MT5 terminals idle — direct factory "
                "throughput loss on both frontier progression and backlog hygiene"
            ),
        })

    band = _largest_frontier_band(frontier.get("by_gate_v4"))
    if band is not None:
        candidates.append({
            "name": f"frontier_band_{band['gate']}",
            "severity": "HIGH",
            "evidence": (
                f"{band['count']} pairs have {band['gate']} as their highest "
                "contiguous valid gate (largest advanceable frontier band)"
            ),
            "cost": (
                "book-quality frontier progression concentrates here; advancing "
                f"{band['gate']} is the highest-leverage compute allocation"
            ),
        })

    holds = queue.get("holds_by_class") or {}
    worst = None
    worst_count = 0
    for code, count in holds.items():
        if code in BENIGN_HOLD_CODES:
            continue
        if int(count) > worst_count:
            worst_count = int(count)
            worst = code
    if worst is not None and worst_count > 0:
        candidates.append({
            "name": f"hold_backlog_{worst}",
            "severity": "MEDIUM",
            "evidence": f"{worst_count} rows held under {worst} (largest "
                        "non-benign active-hold class)",
            "cost": "repairable backlog consuming no compute but blocking those "
                    "pairs until deterministically dispositioned",
        })

    d_free = resources.get("d_free_gb")
    if isinstance(d_free, (int, float)) and d_free <= DISK_WARN_GB:
        candidates.append({
            "name": "disk_free_near_lowwater",
            "severity": "MEDIUM",
            "evidence": f"D: free {d_free} GB (LowWater purge fires at 60 GB)",
            "cost": "cache-purge pressure; a stall here can wedge the tester",
        })

    ranked = candidates[:3]
    for i, entry in enumerate(ranked, start=1):
        entry["rank"] = i
    return ranked


def collect_infra_problems(queue: dict, resources: dict) -> list[dict[str, Any]]:
    problems: list[dict[str, Any]] = []
    holds = queue.get("holds_by_class") or {}
    for code, count in sorted(holds.items()):
        if any(code.startswith(pfx) for pfx in INFRA_HOLD_PREFIXES):
            problems.append({"hold_code": code, "count": int(count)})
    d_free = resources.get("d_free_gb")
    if isinstance(d_free, (int, float)) and d_free <= DISK_WARN_GB:
        problems.append({
            "hold_code": "DISK_FREE_NEAR_LOWWATER",
            "count": None,
            "detail": f"D: free {d_free} GB (<= {DISK_WARN_GB} GB)",
        })
    return problems


# ---------------------------------------------------------------------------
# assembly
# ---------------------------------------------------------------------------
def build_factory_bottleneck(db: Path | None = None, *,
                             now: dt.datetime | None = None,
                             pipeline_state_path: Path | None = None,
                             drain_window_path: Path | None = None,
                             worker_log_dir: Path | None = None
                             ) -> dict[str, Any]:
    now = now or _now_utc()
    db = Path(db) if db is not None else DB

    degraded: list[str] = []
    try:
        con = _connect_ro(db)
        try:
            queue = collect_queue_state(con)
        finally:
            con.close()
    except sqlite3.Error as exc:
        queue = {
            "active": "NOT_EVALUATED",
            "pending_total": "NOT_EVALUATED",
            "claimable_pending": "NOT_EVALUATED",
            "pending_by_phase": {},
            "holds_by_class": {},
        }
        degraded.append(f"db unavailable: {exc}")

    frontier = load_frontier(pipeline_state_path, now=now)
    drain = load_drain_window(drain_window_path)
    idle = detect_idle_in_drain(worker_log_dir, now=now)
    resources = collect_resources()

    bottlenecks = rank_bottlenecks(
        queue=queue, frontier=frontier, drain=drain, idle=idle,
        resources=resources,
    )
    infra_problems = collect_infra_problems(queue, resources)

    book_guard = frontier.get("book_guard")
    candidate_diagnostic: dict[str, Any] = {"note": "diagnostic, not a goal"}
    if isinstance(book_guard, dict):
        candidate_diagnostic.update({
            "qualified_pairs": book_guard.get("qualified_pairs"),
            "distinct_eas": book_guard.get("distinct_eas"),
            "strategy_families": book_guard.get("strategy_families"),
        })
    else:
        candidate_diagnostic["qualified_pairs"] = "NOT_EVALUATED"

    return {
        "schema": SCHEMA_VERSION,
        "generated_at_utc": _iso(now),
        "frontier": {
            "by_gate_v4": frontier.get("by_gate_v4"),
            "candidate_counts_diagnostic": candidate_diagnostic,
            "source_path": frontier.get("source_path"),
            "generated_at_utc": frontier.get("generated_at_utc"),
        },
        "bottlenecks": bottlenecks,
        "terminals": {
            "active": queue.get("active"),
            "idle_in_drain": idle.get("idle_in_drain"),
            "idle_terminals": idle.get("idle_terminals"),
            "claimable_pending": queue.get("claimable_pending"),
            "logs_scanned": idle.get("logs_scanned"),
        },
        "resources": resources,
        "infra_problems": infra_problems,
        "drain_window": drain,
        "degraded_reasons": degraded,
    }


def write_text_atomic(path: Path, rendered: str) -> None:
    path = Path(path)
    path.parent.mkdir(parents=True, exist_ok=True)
    temp = path.with_name(f".{path.name}.{os.getpid()}.tmp")
    temp.write_text(rendered, encoding="utf-8", newline="\n")
    os.replace(temp, path)


def write_health_readmodel(*, now: dt.datetime | None = None,
                           output_path: Path | None = None,
                           paths: dict[str, Path] | None = None) -> dict[str, Any]:
    """Compose + persist ``book_evolution_health.json`` (consumed by the vault
    Heartbeat; the cockpit reads the same keys via the MC contract)."""
    now = now or _now_utc()
    loaded = load_book_evolution_readmodels(now=now, paths=paths)
    keys = compute_book_evolution_health(loaded)
    doc = {
        "schema": HEALTH_SCHEMA_VERSION,
        "generated_at_utc": _iso(now),
        **keys,
        "detail": {
            "dxz": loaded["book_evolution"]["dxz"].get("staleness"),
            "ftmo": loaded["book_evolution"]["ftmo"].get("staleness"),
            "ftmo_readiness_present": loaded["ftmo_challenge_readiness"].get("present"),
            "research_present": loaded["research_state"].get("present"),
            "factory_bottleneck_present": loaded["factory_bottleneck"].get("present"),
        },
    }
    write_text_atomic(output_path or HEALTH_OUTPUT_PATH,
                      json.dumps(doc, indent=2, ensure_ascii=False) + "\n")
    return doc


# ---------------------------------------------------------------------------
# CLI
# ---------------------------------------------------------------------------
def main(argv: list[str] | None = None) -> int:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("command", choices=["build"], help="build the read-model")
    parser.add_argument("--db", type=Path, default=None,
                        help="override farm_state.sqlite path")
    parser.add_argument("--output", type=Path, default=OUTPUT_PATH,
                        help="factory_bottleneck.json output path")
    parser.add_argument("--no-health", action="store_true",
                        help="skip writing book_evolution_health.json")
    parser.add_argument("--stdout", action="store_true",
                        help="also print the read-model to stdout")
    args = parser.parse_args(argv)

    now = _now_utc()
    doc = build_factory_bottleneck(args.db, now=now)
    rendered = json.dumps(doc, indent=2, ensure_ascii=False) + "\n"
    write_text_atomic(args.output, rendered)
    if not args.no_health:
        # health composer reads the just-written factory_bottleneck.json.
        write_health_readmodel(now=now)
    if args.stdout:
        sys.stdout.write(rendered)

    top = doc["bottlenecks"][0]["name"] if doc["bottlenecks"] else "none"
    _err = sys.stderr if sys.stderr is not None else open(os.devnull, "w", encoding="utf-8")
    _err.write(
        f"[factory_bottleneck] active={doc['terminals'].get('active')} "
        f"idle_in_drain={doc['terminals'].get('idle_in_drain')} "
        f"claimable={doc['terminals'].get('claimable_pending')} "
        f"top={top} -> {args.output}\n"
    )
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
