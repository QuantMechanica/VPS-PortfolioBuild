"""Requeue the stranded-INFRA phases the hourly sweep does NOT cover (Claude, 2026-07-25).

`sweep_enqueue_built_eas.py` Part 2 re-enqueues `verdict='INFRA_FAIL'` rows hourly, but
ONLY for phases Q02/Q03/Q08. Measured stranded population (latest-verdict INFRA_FAIL per
(ea_id, symbol, phase), 2026-07-25): Q02 1509, Q04 1106, Q05 40, Q07 17, Q03 13, Q08 8,
Q06 5. Two gaps this tool closes:

  1. Q04/Q05/Q06/Q07 have NO self-heal path — nothing ever requeues them. This is the bulk
     (1106 Q04 alone). Those pairs are already past Q03, so a rerun that now succeeds is a
     near-free deep-phase win.
  2. Within Q02, the `summary_missing_retries_exhausted` graveyard has accumulated INFRA_FAIL
     rows ABOVE the sweep's <12 cap (`MAX_INFRA_ATTEMPTS`), so the hourly sweep can never
     reach them again. `--include-q02-exhausted` targets exactly those above-cap groups (the
     ones the sweep abandons); below-cap Q02 is left to the hourly sweep so we never
     double-enqueue.

Economics changed since these failures were written: the cold-cache retry (WP-5) is now in
every runner, the shared-bases contention fix is validated, and Q04 writes durable evidence
(WP-7). A rerun today should succeed at a far higher rate than the run that stranded it.

MECHANISM — mirrors the canonical farmctl requeue (the existing-row branch of
`farmctl._enqueue_backtest_ea`, which is how the pipeline already re-runs a phase): the
LATEST INFRA_FAIL row of each stranded (ea, symbol, phase, setfile) group is FLIPPED back to
`status='pending', verdict=NULL, attempt_count=0, evidence_path=NULL, claimed_by=NULL`, its
per-work-item report root moved aside via the `.requeued_*` convention
(`farmctl._archive_work_item_report_root_for_requeue`), and its payload cleaned of stale
runtime keys (`terminal_worker._clear_stale_runtime_payload`). attempt_count is RESET to 0 —
not invented: that is exactly what the cascade requeue and the worker's transient-infra
requeue do, giving the row a fresh retry budget.

SELECTION reuses the sweep's OWN Part-2 predicates (registry status=active, `.DWX`/matrix
symbol via `farmctl._q02_symbol_skip_reason`, setfile on disk, `.ex5` on disk, Q02
requeue-exclusion list, `MAX_INFRA_ATTEMPTS` cap) rather than approximating them. Two extra
guards are MANDATORY because we FLIP existing rows instead of inserting fresh ones (the sweep
inserts attempt_count=0 rows, so it is immune to these): a row is REFUSED when its
`attempt_count >= ATTEMPT_COUNT_POISON_FLOOR` or its payload carries a `LOG_BOMB` marker.
Those are deliberate poison sentinels — the log-bomb path stamps `attempt_count=99` precisely
so a requeue does not re-bomb the journal disk, and the active-timeout reaper stamps 50.
Flipping them blind would re-detonate; we leave them terminal.

WAVE discipline (OWNER 2026-07-29): exactly 5 rows in Wave 1, then exactly 25 rows in Wave 2.
Wave 2 is impossible without a read-only PASS receipt proving all five Wave-1 rows reached real
terminal verdicts with zero recurrent INFRA/INVALID outcomes.  The receipt also binds the exact
next 25 rows and is revalidated immediately before apply. Q08 invalid-report rows are always
BLOCKED, never retryable.  `--limit` and unlimited release are retired.

Modes (default = dry-run, read-only via `mode=ro`, mutates nothing):

    # dry-run Wave 1 (exactly five; writes a reversible snapshot; NO DB writes)
    python tools/strategy_farm/requeue_stranded_infra.py --wave 1 \
        --snapshot-out D:/QM/reports/state/requeue_stranded_infra_snapshot.json

    # read-only Q03..Q08 health/disposition census
    python tools/strategy_farm/requeue_stranded_infra.py --health-census

    # include the Q02 above-sweep-cap graveyard
    python tools/strategy_farm/requeue_stranded_infra.py --include-q02-exhausted

    # execute the flip (Factory OFF + DB quiescent). --snapshot-out is MANDATORY:
    # it is the DURABLE JOURNAL that makes apply crash-safe and revert byte-faithful.
    python tools/strategy_farm/requeue_stranded_infra.py --wave 1 --apply \
        --snapshot-out D:/QM/reports/state/requeue_stranded_infra_wave1.json

    # after all five settle, issue a read-only receipt; BLOCKED receipts cannot open Wave 2
    python tools/strategy_farm/requeue_stranded_infra.py \
        --assess-wave1 D:/QM/reports/state/requeue_stranded_infra_wave1.json \
        --receipt-out D:/QM/reports/state/requeue_stranded_infra_wave1_receipt.json

    # Wave 2 is exactly 25 and bound to the receipt's frozen selection
    python tools/strategy_farm/requeue_stranded_infra.py --wave 2 \
        --wave1-receipt D:/QM/reports/state/requeue_stranded_infra_wave1_receipt.json

    # undo, guarded on the exact post-apply state recorded in the journal
    python tools/strategy_farm/requeue_stranded_infra.py \
        --revert D:/QM/reports/state/requeue_stranded_infra_snapshot.json

CRASH SAFETY (apply/revert ordering):
  APPLY  (a) revalidate every canary row inside a single DB transaction, uncommitted;
         (b) write a DURABLE JOURNAL (--snapshot-out) with, per row, the planned report-root
             archive move (src -> dst), the row's exact pre-apply state, and its exact expected
             post-apply state — flushed + fsynced BEFORE any filesystem move and BEFORE the DB
             commit; (c) perform the report-root archive moves — ANY rename failure is FATAL:
             every move already done this run is compensated (moved back), the DB transaction is
             rolled back, and the tool exits non-zero with per-path errors; (d) only after all
             moves succeed is the DB flip committed; (e) then the journal is marked 'committed'.
             A crash leaves either (journal=planned, DB unchanged, some moves compensable from the
             journal) or (journal=planned/committed, DB committed, all moves done) — both fully
             recoverable from the journal by --revert.
  REVERT (a) load the journal; (b) require each row to still be in the EXACT recorded post-apply
             state — a drifted row (e.g. a worker claimed it) is REFUSED and reported, reverting
             nothing for it; (c) restore report roots FIRST — any un-archive failure aborts the
             revert (with compensation) BEFORE the DB is touched; (d) then restore the DB rows in
             one transaction from the journal's pre-apply states; (e) mark the journal 'reverted'.
             No failure is ever swallowed: every path surfaces paths + reasons and a non-zero exit.
"""
from __future__ import annotations

import argparse
import csv
import datetime as dt
import hashlib
import json
import os
import re
import sqlite3
import sys
import time
from dataclasses import dataclass, field
from pathlib import Path
from typing import Any, Callable

_HERE = Path(__file__).resolve().parent
if str(_HERE) not in sys.path:
    sys.path.insert(0, str(_HERE))

import farmctl  # noqa: E402  (registry helpers, symbol filter, report-root archiver)

# terminal_worker is heavy but side-effect-free at import; reuse its canonical stale-key list
# so payload cleaning tracks the worker's source of truth. Fall back to a local copy.
try:  # pragma: no cover - import wiring
    from terminal_worker import _clear_stale_runtime_payload as _clear_stale_runtime_payload  # type: ignore
except Exception:  # pragma: no cover
    _FALLBACK_STALE_KEYS = (
        "pid", "started_at_iso", "log_path", "claimed_at_iso",
        "claimed_by_worker_pid", "commit_reservation_gb",
        "commit_reservation_until_utc", "terminal",
    )

    def _clear_stale_runtime_payload(payload: dict[str, Any]) -> None:  # type: ignore
        for field_name in _FALLBACK_STALE_KEYS:
            payload.pop(field_name, None)


DEFAULT_DB = Path(r"D:\QM\strategy_farm\state\farm_state.sqlite")
DEFAULT_EAS = Path(r"C:\QM\repo\framework\EAs")
DEFAULT_REGISTRY = Path(r"C:\QM\repo\framework\registry\ea_id_registry.csv")
DEFAULT_WI_REPORTS = Path(r"D:\QM\reports\work_items")
DEFAULT_SNAPSHOT_DIR = Path(r"D:\QM\reports\state")

DEFAULT_DEEP_PHASES = ("Q04", "Q05", "Q06", "Q07")
HEALTH_PHASES = ("Q03", "Q04", "Q05", "Q06", "Q07", "Q08")
Q02_PHASE = "Q02"

# OWNER 2026-07-29 / MNT-007: recovery is deliberately bounded to exactly two
# releases.  There is no "full" or caller-selected apply size any more.
RECOVERY_WAVE_SIZES = {1: 5, 2: 25}
WAVE_RECEIPT_SCHEMA = "qm.mnt007.wave1_receipt.v1"
WAVE_CONTRACT = "MNT-007_STRANDED_INFRA_5_THEN_25"

# Per-group INFRA_FAIL row-count cap. Identical to sweep_enqueue_built_eas.MAX_INFRA_ATTEMPTS
# (=12): a (ea,symbol,setfile) that has stacked >=12 INFRA rows is either a permanent defect
# or already exhausted the sweep. Deep phases refuse at/above it; Q02-exhausted mode SELECTS
# at/above it (that is the sweep's unreachable set).
MAX_INFRA_ATTEMPTS = 12

# attempt_count column poison floor. Natural retries live in 0..2 (MAX_WORK_ITEM_RETRIES=3).
# The log-bomb path stamps attempt_count=99 and the active-timeout reaper stamps 50 as
# deliberate "do not re-run" sentinels; anything >= this floor is a sentinel, never a real
# retry count. Flipping such a row re-detonates the exact failure it was quarantined for.
ATTEMPT_COUNT_POISON_FLOOR = 12

# Deeper phase first (Q07 is closest to a survivor). Mirrors terminal_worker._phase_rank order.
PHASE_DEPTH = {
    "Q13": 13, "Q12": 12, "Q11": 11, "Q10": 10, "Q09_NEWS": 9.5,
    "Q09_PORTFOLIO": 9.4, "Q09": 9, "Q08": 8, "Q07": 7, "Q06": 6,
    "Q05": 5, "Q04": 4, "Q03": 3, "Q02": 2,
}

SETFILE_MISSING = "setfile_missing"


def _utc_now() -> str:
    return dt.datetime.now(dt.UTC).replace(microsecond=0).isoformat()


def _canonical_sha256(value: Any) -> str:
    encoded = json.dumps(value, sort_keys=True, separators=(",", ":"), ensure_ascii=False)
    return hashlib.sha256(encoded.encode("utf-8")).hexdigest().upper()


def _file_sha256(path: Path) -> str:
    digest = hashlib.sha256()
    with Path(path).open("rb") as fh:
        for chunk in iter(lambda: fh.read(1024 * 1024), b""):
            digest.update(chunk)
    return digest.hexdigest().upper()


def _json_obj(raw: Any) -> dict[str, Any]:
    if isinstance(raw, dict):
        return raw
    try:
        value = json.loads(raw or "{}")
    except (TypeError, json.JSONDecodeError):
        return {}
    return value if isinstance(value, dict) else {}


def _ea_int(ea_id: Any) -> int | None:
    text = str(ea_id).strip()
    if text.startswith("QM5_"):
        text = text.split("_", 2)[1]
    try:
        return int(text)
    except (TypeError, ValueError):
        return None


@dataclass
class Config:
    db: Path = DEFAULT_DB
    eas_root: Path = DEFAULT_EAS
    registry_path: Path = DEFAULT_REGISTRY
    wi_reports_root: Path = DEFAULT_WI_REPORTS
    registry: dict[int, tuple[str, str]] = field(default_factory=dict)
    ea_dirs: dict[str, list[Path]] = field(default_factory=dict)

    @classmethod
    def build(cls, **kw: Any) -> "Config":
        cfg = cls(**kw)
        cfg.registry = _load_registry(cfg.registry_path)
        cfg.ea_dirs = _build_ea_dirs(cfg.eas_root)
        return cfg


def _load_registry(path: Path) -> dict[int, tuple[str, str]]:
    """ea_id(int) -> (status_lower, slug). Same parse the sweep uses."""
    reg: dict[int, tuple[str, str]] = {}
    try:
        fh = path.open(encoding="utf-8-sig")
    except OSError:
        return reg
    with fh:
        for row in csv.DictReader(fh):
            raw = (row.get("ea_id") or "").strip()
            try:
                status = row["status"].strip().lower()
                slug = row["slug"].strip()
            except KeyError:
                continue
            m = re.fullmatch(r"(?:QM5_)?(\d+)", raw)
            if m:
                reg[int(m.group(1))] = (status, slug)
    return reg


def _build_ea_dirs(eas_root: Path) -> dict[str, list[Path]]:
    """ea_id_str -> [candidate build dirs], mirroring sweep Part 1 (skips _obsolete_)."""
    out: dict[str, list[Path]] = {}
    try:
        entries = sorted(eas_root.iterdir())
    except OSError:
        return out
    for d in entries:
        if not d.is_dir() or "_obsolete_" in d.name.lower():
            continue
        m = re.match(r"QM5_(\d+)", d.name)
        if not m:
            continue
        out.setdefault(f"QM5_{m.group(1)}", []).append(d)
    return out


def _ea_has_ex5(cfg: Config, ea_id: str) -> bool:
    """True if a non-obsolete build dir for this EA holds a compiled .ex5.

    Prefers the registered-slug dir (DL-069), like the sweep's Part 1.
    """
    dirs = cfg.ea_dirs.get(ea_id)
    if not dirs:
        return False
    num = _ea_int(ea_id)
    _status, slug = cfg.registry.get(num, (None, None)) if num is not None else (None, None)
    pick = None
    if slug:
        for d in dirs:
            if d.name == f"{ea_id}_{slug}":
                pick = d
                break
    if pick is None:
        pick = dirs[0]
    try:
        return any(pick.rglob("*.ex5"))
    except OSError:
        return False


# --------------------------------------------------------------------------- selection

_STRANDED_SQL = """
SELECT x.ea_id, x.symbol, x.phase, x.setfile_path, COUNT(*) AS infra_count,
       MAX(x.updated_at) AS latest_ts,
       (SELECT z.id FROM work_items z
        WHERE z.ea_id=x.ea_id AND z.phase=x.phase AND z.symbol=x.symbol
          AND ifnull(z.setfile_path,'')=ifnull(x.setfile_path,'')
          AND z.verdict='INFRA_FAIL'
        ORDER BY z.updated_at DESC, z.id DESC LIMIT 1) AS latest_id
FROM work_items x
WHERE x.phase=?
  AND x.verdict='INFRA_FAIL'
  AND NOT EXISTS (
      SELECT 1 FROM work_items y
      WHERE y.ea_id=x.ea_id AND y.phase=x.phase AND y.symbol=x.symbol
        AND ifnull(y.setfile_path,'')=ifnull(x.setfile_path,'')
        AND y.status IN ('pending','active'))
  AND NOT EXISTS (
      SELECT 1 FROM work_items y
      WHERE y.ea_id=x.ea_id AND y.phase=x.phase AND y.symbol=x.symbol
        AND ifnull(y.setfile_path,'')=ifnull(x.setfile_path,'')
        AND y.status='done' AND y.verdict!='INFRA_FAIL')
GROUP BY x.ea_id, x.symbol, x.setfile_path
"""


def _fetch_row(conn: sqlite3.Connection, wid: str) -> sqlite3.Row | None:
    return conn.execute(
        "SELECT id, ea_id, symbol, phase, setfile_path, status, verdict, attempt_count, "
        "evidence_path, claimed_by, payload_json, updated_at FROM work_items WHERE id=?",
        (wid,),
    ).fetchone()


def _poison_pill_quarantined(
    conn: sqlite3.Connection, ea_id: str, symbol: str, phase: str,
) -> bool:
    """Return active quarantine state; old/test DBs without the table fail open."""
    try:
        row = conn.execute(
            "SELECT 1 FROM poison_pill_quarantine "
            "WHERE ea_id=? AND symbol=? AND phase=? AND active=1 LIMIT 1",
            (ea_id, symbol, phase),
        ).fetchone()
    except sqlite3.OperationalError as exc:
        if "no such table" in str(exc).lower():
            return False
        raise
    return row is not None


def _payload_reason(payload: dict[str, Any]) -> str | None:
    return payload.get("final_failure") or payload.get("verdict_reason")


def _plan_archive_dst(cfg: Config, work_item_id: str, now_iso: str) -> tuple[Path | None, Path | None]:
    """Compute (src, dst) for moving a stale per-work-item report root aside, WITHOUT moving.

    Splitting the destination computation from the move (see _do_rename) lets apply record the
    full src -> dst archive map in the durable journal BEFORE any filesystem mutation, so a crash
    mid-move is compensable. Returns (None, None) when there is no report root to archive.

    The `.requeued_<stamp>` destination convention is byte-identical to
    farmctl._archive_work_item_report_root_for_requeue; the two stay in lockstep in production
    (default root == D:/QM/reports/work_items) and cfg.wi_reports_root keeps it testable.
    """
    report_root = cfg.wi_reports_root / str(work_item_id)
    if not report_root.exists():
        return None, None
    safe_stamp = re.sub(r"[^0-9A-Za-z]+", "", now_iso)[:32] or str(int(time.time()))
    archive = report_root.with_name(f"{report_root.name}.requeued_{safe_stamp}")
    suffix = 0
    while archive.exists():
        suffix += 1
        archive = report_root.with_name(f"{report_root.name}.requeued_{safe_stamp}_{suffix}")
    return report_root, archive


def _do_rename(src: Path, dst: Path) -> None:
    """The single 'intended' filesystem move — archive (apply) or un-archive (revert).

    Isolated (a) so failure-injection tests can target exactly one move, and (b) so compensation
    (move-back) can use a raw ``Path.rename`` that is NOT subject to that injection and stays
    reliable even when this hook is patched to fail.
    """
    Path(src).rename(dst)


def _write_journal(path: Path, plan: dict[str, Any]) -> None:
    """Durably persist the plan+journal via atomic tmp-write + fsync + os.replace.

    fsync guarantees the bytes reach disk before we proceed to filesystem moves / DB commit;
    os.replace is atomic on the same volume so a crash never leaves a torn journal.
    """
    path = Path(path)
    path.parent.mkdir(parents=True, exist_ok=True)
    tmp = path.with_name(path.name + ".tmp")
    data = json.dumps(plan, indent=1, sort_keys=True)
    with open(tmp, "w", encoding="utf-8") as fh:
        fh.write(data)
        fh.flush()
        os.fsync(fh.fileno())
    os.replace(tmp, path)


_JOURNAL_STATE_FIELDS = (
    "status", "verdict", "attempt_count", "evidence_path", "claimed_by",
    "payload_json", "updated_at",
)


def _row_state(row: sqlite3.Row | None) -> dict[str, Any]:
    """Extract the exact mutable state we snapshot into the journal (pre/post-apply)."""
    if row is None:
        return {k: None for k in _JOURNAL_STATE_FIELDS}
    return {k: row[k] for k in _JOURNAL_STATE_FIELDS}


def _state_matches(current: dict[str, Any], expected: dict[str, Any]) -> bool:
    """Exact byte-faithful equality across every journalled field (drift detector)."""
    return all(current.get(k) == expected.get(k) for k in _JOURNAL_STATE_FIELDS)


def _has_log_bomb_marker(payload: dict[str, Any]) -> bool:
    if str(payload.get("verdict_reason") or "").upper() == "LOG_BOMB":
        return True
    return any(str(r).upper() == "LOG_BOMB" for r in (payload.get("reason_classes") or []))


def _is_q08_invalid_report(payload: dict[str, Any]) -> bool:
    """Return True for the non-retryable Q08 invalid-report family.

    The legacy writer used several shapes: ``phase_runner_invalid_report`` in a
    reason field, ``INVALID_REPORT`` in ``reason_classes``, and later the
    explicit ``invalid_report_reclassified`` / ``invalid_report_reasons`` keys.
    Treat every one as the same fail-closed boundary.  This deliberately does
    not infer invalidity from a missing evidence file alone.
    """
    if payload.get("invalid_report_reclassified") is True:
        return True
    if payload.get("invalid_report_reasons"):
        return True
    values: list[Any] = [
        payload.get("verdict_reason"), payload.get("final_failure"),
        payload.get("prior_failure"), payload.get("reason"), payload.get("reason_class"),
        payload.get("transient_infra_signature"),
    ]
    for key in ("reason_classes", "reasons"):
        value = payload.get(key)
        values.extend(value if isinstance(value, list) else [value])
    for value in values:
        upper = str(value or "").upper()
        tokens = set(re.sub(r"[^A-Z0-9]+", " ", upper).split())
        if "INVALID_REPORT" in upper or "INVALID" in tokens:
            return True
    return False


def _later_phase_successor(
    conn: sqlite3.Connection, ea_id: str, symbol: str, phase: str,
) -> sqlite3.Row | None:
    """Find pair-level progression beyond ``phase``.

    Once a pair reached a deeper phase, its lower-phase INFRA row is historical
    even when a stale setfile path makes it look stranded.  It must never be
    resurrected by a recovery sweep.
    """
    depth = PHASE_DEPTH.get(phase, -1)
    later = tuple(p for p, p_depth in PHASE_DEPTH.items() if p_depth > depth)
    if not later:
        return None
    placeholders = ",".join("?" for _ in later)
    return conn.execute(
        f"SELECT id, phase, status, verdict, updated_at FROM work_items "
        f"WHERE ea_id=? AND symbol=? AND phase IN ({placeholders}) "
        f"ORDER BY updated_at DESC, id DESC LIMIT 1",
        (ea_id, symbol, *later),
    ).fetchone()


def _classify_group(
    cfg: Config,
    conn: sqlite3.Connection,
    group: sqlite3.Row,
    *,
    is_q02: bool,
    symbol_skip_fn: Callable[[str], str | None],
) -> dict[str, Any]:
    ea_id = str(group["ea_id"])
    symbol = str(group["symbol"])
    infra_count = int(group["infra_count"] or 0)
    latest_id = group["latest_id"]
    row = _fetch_row(conn, latest_id) if latest_id else None
    setfile = row["setfile_path"] if row else group["setfile_path"]
    payload = _json_obj(row["payload_json"] if row else None)
    attempt_count = int(row["attempt_count"] or 0) if row else 0
    report_root = cfg.wi_reports_root / str(latest_id) if latest_id else None
    artifact_survives = bool(report_root and report_root.exists())

    info: dict[str, Any] = {
        "work_item_id": latest_id,
        "ea_id": ea_id,
        "symbol": symbol,
        "phase": group["phase"] if "phase" in group.keys() else None,
        "setfile_path": setfile,
        "infra_count": infra_count,
        "attempt_count": attempt_count,
        "latest_ts": group["latest_ts"],
        "prior_verdict_reason": _payload_reason(payload),
        "artifact_survives": artifact_survives,
        "report_root": str(report_root) if report_root else None,
        "decision": "REFUSE",
        "reason": None,
        # exact prior mutable state for a byte-faithful guarded revert
        "prior_state": {
            "status": row["status"] if row else None,
            "verdict": row["verdict"] if row else None,
            "attempt_count": attempt_count,
            "evidence_path": row["evidence_path"] if row else None,
            "claimed_by": row["claimed_by"] if row else None,
            "payload_json": row["payload_json"] if row else None,
            "updated_at": row["updated_at"] if row else None,
        },
    }

    if row is None:
        info["reason"] = "latest_infra_row_vanished"
        return info
    if row["verdict"] != "INFRA_FAIL" or row["status"] not in ("done", "failed"):
        info["reason"] = "latest_row_not_terminal_infra"
        return info

    phase = str(row["phase"] or info.get("phase") or "")
    successor = _later_phase_successor(conn, ea_id, symbol, phase)
    if successor is not None:
        info["reason"] = "historical_phase_advanced"
        info["superseded_by"] = {
            "work_item_id": successor["id"], "phase": successor["phase"],
            "status": successor["status"], "verdict": successor["verdict"],
        }
        return info

    # OWNER 2026-07-29: Q08 invalid reports are INVALID evidence, not transient
    # infrastructure.  They are blocked even if still mislabeled INFRA_FAIL.
    if phase == "Q08" and _is_q08_invalid_report(payload):
        info["reason"] = "q08_invalid_report_non_retryable"
        return info

    skip = symbol_skip_fn(symbol)
    if skip:
        info["reason"] = skip
        return info

    num = _ea_int(ea_id)
    status = cfg.registry.get(num, (None, None))[0] if num is not None else None
    if status != "active":
        info["reason"] = f"registry_status={status}"
        return info

    if not setfile or not Path(setfile).is_file():
        info["reason"] = SETFILE_MISSING
        return info
    if not _ea_has_ex5(cfg, ea_id):
        info["reason"] = "no_ex5"
        return info

    # Poison sentinels: never re-run a quarantined row (log-bomb=99, reaper timeout=50).
    if attempt_count >= ATTEMPT_COUNT_POISON_FLOOR:
        info["reason"] = "poison_attempt_count_sentinel"
        return info
    if _has_log_bomb_marker(payload):
        info["reason"] = "log_bomb_marker"
        return info

    if is_q02:
        if farmctl.is_q02_requeue_excluded(ea_id):
            info["reason"] = "requeue_excluded_q02"
            return info
        # Q02 mode only targets the sweep-UNREACHABLE above-cap graveyard; below-cap Q02 is
        # left to the hourly sweep so we never double-enqueue.
        if infra_count < MAX_INFRA_ATTEMPTS:
            info["reason"] = "below_sweep_cap_left_to_hourly_sweep"
            return info
    else:
        if infra_count >= MAX_INFRA_ATTEMPTS:
            info["reason"] = "infra_retry_cap_reached"
            return info

    info["decision"] = "REQUEUE"
    info["reason"] = "stranded_infra_eligible"
    return info


def _order_key(entry: dict[str, Any], priority_fn: Callable[[str], float]) -> tuple:
    depth = PHASE_DEPTH.get(str(entry.get("phase")), 0)
    return (-depth, -priority_fn(str(entry["ea_id"])), str(entry["ea_id"]), str(entry["symbol"]))


def _open_ro(db: Path) -> sqlite3.Connection:
    conn = sqlite3.connect(f"file:{db}?mode=ro", uri=True, timeout=10)
    conn.row_factory = sqlite3.Row
    return conn


def _default_priority_fn() -> Callable[[str], float]:
    try:
        import strategy_priority as _sp  # type: ignore
        scores = _sp.compute_scores()

        def _fn(ea_id: str) -> float:
            return float(scores.get(ea_id, {}).get("score", 0.0))
        return _fn
    except Exception:
        return lambda _ea_id: 0.0


def _plan(
    cfg: Config,
    *,
    phases: tuple[str, ...],
    include_q02_exhausted: bool,
    limit: int,
    symbol_skip_fn: Callable[[str], str | None] | None = None,
    priority_fn: Callable[[str], float] | None = None,
) -> dict[str, Any]:
    if symbol_skip_fn is None:
        symbol_skip_fn = lambda s: farmctl._q02_symbol_skip_reason(s, allow_logical_basket=True)
    if priority_fn is None:
        priority_fn = _default_priority_fn()

    effective_phases = list(phases)
    if include_q02_exhausted and Q02_PHASE not in effective_phases:
        effective_phases.append(Q02_PHASE)

    conn = _open_ro(cfg.db)
    try:
        pending_at_start = conn.execute(
            "SELECT COUNT(*) FROM work_items WHERE status='pending'").fetchone()[0]
        open_at_start = conn.execute(
            "SELECT COUNT(*) FROM work_items WHERE status IN ('pending','active')").fetchone()[0]
        per_phase: dict[str, dict[str, Any]] = {}
        eligible: list[dict[str, Any]] = []
        for phase in effective_phases:
            is_q02 = phase == Q02_PHASE
            groups = [
                group for group in conn.execute(_STRANDED_SQL, (phase,)).fetchall()
                if not _poison_pill_quarantined(
                    conn, str(group["ea_id"]), str(group["symbol"]), str(group["phase"])
                )
            ]
            classified = [
                _classify_group(cfg, conn, g, is_q02=is_q02, symbol_skip_fn=symbol_skip_fn)
                for g in groups
            ]
            for c in classified:
                c["phase"] = phase
            ph_eligible = [c for c in classified if c["decision"] == "REQUEUE"]
            ph_refused = [c for c in classified if c["decision"] == "REFUSE"]
            refuse_reasons: dict[str, int] = {}
            for c in ph_refused:
                refuse_reasons[c["reason"]] = refuse_reasons.get(c["reason"], 0) + 1
            per_phase[phase] = {
                "stranded_groups": len(classified),
                "eligible": len(ph_eligible),
                "refused": len(ph_refused),
                "refuse_reasons": refuse_reasons,
                "eligible_artifact_survives": sum(1 for c in ph_eligible if c["artifact_survives"]),
                "eligible_artifact_purged": sum(1 for c in ph_eligible if not c["artifact_survives"]),
            }
            eligible.extend(ph_eligible)
    finally:
        conn.close()

    eligible.sort(key=lambda e: _order_key(e, priority_fn))
    canary = eligible if limit == 0 else eligible[:limit]

    # Snapshot prior state only for the rows apply will actually flip (the canary).
    prior_state = {c["work_item_id"]: c["prior_state"] for c in canary}
    canary_by_phase: dict[str, int] = {}
    for c in canary:
        canary_by_phase[c["phase"]] = canary_by_phase.get(c["phase"], 0) + 1

    return {
        "tool": "requeue_stranded_infra.py",
        "generated_at_utc": _utc_now(),
        "db": str(cfg.db),
        "phases": effective_phases,
        "include_q02_exhausted": include_q02_exhausted,
        "limit": limit,
        "max_infra_attempts": MAX_INFRA_ATTEMPTS,
        "attempt_count_poison_floor": ATTEMPT_COUNT_POISON_FLOOR,
        "pending_at_start": pending_at_start,
        "open_at_start": open_at_start,
        "per_phase": per_phase,
        "eligible_total": len(eligible),
        "canary_count": len(canary),
        "canary_by_phase": canary_by_phase,
        "canary_artifact_survives": sum(1 for c in canary if c["artifact_survives"]),
        "canary_artifact_purged": sum(1 for c in canary if not c["artifact_survives"]),
        "projected_pending_after_full": pending_at_start + len(eligible),
        "projected_pending_after_canary": pending_at_start + len(canary),
        "canary": canary,
        "eligible": eligible,
        "prior_state": prior_state,
        "applied": None,
    }


def _is_real_verdict_row(row: sqlite3.Row | dict[str, Any]) -> bool:
    verdict = str(row["verdict"] or "").strip().upper()
    return str(row["status"] or "").lower() in {"done", "failed"} and bool(verdict) \
        and verdict != "INFRA_FAIL"


def _health_census(
    cfg: Config,
    *,
    phases: tuple[str, ...] = HEALTH_PHASES,
    symbol_skip_fn: Callable[[str], str | None] | None = None,
    conn: sqlite3.Connection | None = None,
) -> dict[str, Any]:
    """Read-only disposition census for every Q03..Q08 INFRA-bearing group.

    A current infra-only group is one with no real verdict, no pending/active
    successor in the same group, and no pair-level progression to a deeper
    phase.  Every such group is deterministically classified as RETRY, BLOCKED,
    or RETIRED.  Superseded groups remain visible as historical exclusions.
    """
    if symbol_skip_fn is None:
        symbol_skip_fn = lambda s: farmctl._q02_symbol_skip_reason(s, allow_logical_basket=True)
    own_conn = conn is None
    if own_conn:
        conn = _open_ro(cfg.db)
    assert conn is not None

    target = tuple(dict.fromkeys(phases))
    all_known = tuple(
        p for p, depth in PHASE_DEPTH.items()
        if depth >= min(PHASE_DEPTH.get(q, 3) for q in target)
    )
    placeholders = ",".join("?" for _ in all_known)
    try:
        rows = conn.execute(
            "SELECT id, ea_id, symbol, phase, setfile_path, status, verdict, attempt_count, "
            "evidence_path, claimed_by, payload_json, updated_at FROM work_items "
            f"WHERE phase IN ({placeholders})",
            all_known,
        ).fetchall()

        groups: dict[tuple[str, str, str, str], list[sqlite3.Row]] = {}
        pair_rows: dict[tuple[str, str], list[sqlite3.Row]] = {}
        target_set = set(target)
        for row in rows:
            pair_rows.setdefault((str(row["ea_id"]), str(row["symbol"])), []).append(row)
            if row["phase"] in target_set:
                key = (
                    str(row["ea_id"]), str(row["symbol"]), str(row["phase"]),
                    str(row["setfile_path"] or ""),
                )
                groups.setdefault(key, []).append(row)

        per_phase: dict[str, dict[str, Any]] = {
            phase: {
                "infra_groups": 0,
                "current_infra_only": 0,
                "dispositions": {"RETRY": 0, "BLOCKED": 0, "RETIRED": 0, "REAL_VERDICT": 0},
                "historical_exclusions": {},
                "q08_invalid_report_blocked": 0,
                "unresolved": 0,
            }
            for phase in target
        }
        current_cases: list[dict[str, Any]] = []
        historical_examples: list[dict[str, Any]] = []
        q08_invalid_retryable = 0
        infra_pairs = {phase: set() for phase in target}
        current_pairs = {phase: set() for phase in target}
        historical_pairs = {phase: set() for phase in target}

        for (ea_id, symbol, phase, setfile_key), group_rows in groups.items():
            infra_rows = [r for r in group_rows if str(r["verdict"] or "").upper() == "INFRA_FAIL"]
            if not infra_rows:
                continue
            stats = per_phase[phase]
            stats["infra_groups"] += 1
            infra_pairs[phase].add((ea_id, symbol))
            latest_infra = max(infra_rows, key=lambda r: (str(r["updated_at"] or ""), str(r["id"])))
            real_rows = [r for r in group_rows if _is_real_verdict_row(r)]
            open_rows = [r for r in group_rows if str(r["status"] or "").lower() in {"pending", "active"}]
            phase_depth = PHASE_DEPTH.get(phase, -1)
            later_rows = [
                r for r in pair_rows.get((ea_id, symbol), [])
                if PHASE_DEPTH.get(str(r["phase"]), -1) > phase_depth
            ]

            historical_reason: str | None = None
            disposition: str
            reason: str
            if real_rows:
                disposition, reason = "REAL_VERDICT", "superseded_by_real_verdict"
                historical_reason = reason
            elif open_rows:
                disposition, reason = "RETRY", "successor_in_flight"
            elif later_rows:
                disposition, reason = "BLOCKED", "historical_phase_advanced"
                historical_reason = reason
            else:
                stats["current_infra_only"] += 1
                current_pairs[phase].add((ea_id, symbol))
                synthetic_group = {
                    "ea_id": ea_id, "symbol": symbol, "phase": phase,
                    "setfile_path": setfile_key or None,
                    "infra_count": len(infra_rows), "latest_ts": latest_infra["updated_at"],
                    "latest_id": latest_infra["id"],
                }
                classified = _classify_group(
                    cfg, conn, synthetic_group, is_q02=False, symbol_skip_fn=symbol_skip_fn,
                )
                reason = str(classified["reason"] or "unclassified")
                registry_status = cfg.registry.get(_ea_int(ea_id), (None, None))[0]
                if registry_status != "active":
                    disposition = "RETIRED"
                elif classified["decision"] == "REQUEUE":
                    disposition = "RETRY"
                else:
                    disposition = "BLOCKED"
                payload = _json_obj(latest_infra["payload_json"])
                if phase == "Q08" and _is_q08_invalid_report(payload):
                    if disposition == "RETRY":
                        q08_invalid_retryable += 1
                    stats["q08_invalid_report_blocked"] += 1
                current_cases.append({
                    "ea_id": ea_id,
                    "symbol": symbol,
                    "phase": phase,
                    "setfile_path": setfile_key or None,
                    "latest_work_item_id": latest_infra["id"],
                    "latest_updated_at": latest_infra["updated_at"],
                    "infra_rows": len(infra_rows),
                    "disposition": disposition,
                    "reason": reason,
                    "registry_status": registry_status,
                    "evidence_present": bool(latest_infra["evidence_path"]),
                })

            if disposition not in stats["dispositions"]:
                stats["unresolved"] += 1
            else:
                stats["dispositions"][disposition] += 1
            if historical_reason:
                historical_pairs[phase].add((ea_id, symbol))
                hist = stats["historical_exclusions"]
                hist[historical_reason] = hist.get(historical_reason, 0) + 1
                if len(historical_examples) < 100:
                    historical_examples.append({
                        "ea_id": ea_id, "symbol": symbol, "phase": phase,
                        "latest_work_item_id": latest_infra["id"],
                        "reason": historical_reason,
                    })
    finally:
        if own_conn:
            conn.close()

    disposition_totals = {"RETRY": 0, "BLOCKED": 0, "RETIRED": 0, "REAL_VERDICT": 0}
    for phase, stats in per_phase.items():
        stats["infra_pairs"] = len(infra_pairs[phase])
        stats["current_infra_only_pairs"] = len(current_pairs[phase])
        stats["historical_exclusion_pairs"] = len(historical_pairs[phase])
        for name in disposition_totals:
            disposition_totals[name] += int(stats["dispositions"][name])
    unresolved = sum(int(stats["unresolved"]) for stats in per_phase.values())
    invariant_ok = unresolved == 0 and q08_invalid_retryable == 0
    return {
        "schema_version": "qm.mnt007.health_census.v1",
        "generated_at_utc": _utc_now(),
        "db": str(cfg.db),
        "phases": list(target),
        "read_only": True,
        "per_phase": per_phase,
        "disposition_totals": disposition_totals,
        "current_infra_only_total": sum(
            int(stats["current_infra_only"]) for stats in per_phase.values()
        ),
        "current_infra_only_pair_phase_total": sum(
            int(stats["current_infra_only_pairs"]) for stats in per_phase.values()
        ),
        "historical_exclusion_total": sum(
            sum(int(n) for n in stats["historical_exclusions"].values())
            for stats in per_phase.values()
        ),
        "historical_exclusion_pair_phase_total": sum(
            int(stats["historical_exclusion_pairs"]) for stats in per_phase.values()
        ),
        "current_cases": sorted(
            current_cases,
            key=lambda item: (PHASE_DEPTH.get(item["phase"], 0), item["ea_id"], item["symbol"]),
        ),
        "historical_examples": historical_examples,
        "invariant": {
            "name": "every_current_infra_only_group_has_disposition",
            "status": "PASS" if invariant_ok else "FAIL",
            "allowed_current_dispositions": ["RETRY", "BLOCKED", "RETIRED"],
            "unresolved": unresolved,
            "q08_invalid_report_retryable": q08_invalid_retryable,
        },
    }


def _selection_contract(plan: dict[str, Any]) -> dict[str, Any]:
    rows = [
        {
            "work_item_id": row["work_item_id"],
            "ea_id": row["ea_id"],
            "symbol": row["symbol"],
            "phase": row["phase"],
            "setfile_path": row.get("setfile_path"),
            "prior_state": row.get("prior_state"),
        }
        for row in plan.get("canary", [])
    ]
    return {
        "size": len(rows),
        "work_item_ids": [row["work_item_id"] for row in rows],
        "rows": rows,
        "sha256": _canonical_sha256(rows),
    }


def _assess_wave1(
    cfg: Config,
    journal_path: Path,
    *,
    phases: tuple[str, ...],
    include_q02_exhausted: bool,
    symbol_skip_fn: Callable[[str], str | None] | None = None,
    priority_fn: Callable[[str], float] | None = None,
) -> dict[str, Any]:
    """Read-only Wave-1 outcome assessment and Wave-2 candidate binding."""
    journal_path = Path(journal_path).resolve()
    source = json.loads(journal_path.read_text(encoding="utf-8"))
    wave = source.get("recovery_wave") or {}
    entries = ((source.get("journal") or {}).get("entries") or {})
    blockers: list[str] = []
    if source.get("tool") != "requeue_stranded_infra.py":
        blockers.append("source_not_requeue_stranded_infra_journal")
    if int(wave.get("number") or 0) != 1 or int(wave.get("size") or 0) != 5:
        blockers.append("source_not_exact_wave1_size_5")
    if (source.get("journal") or {}).get("state") != "committed":
        blockers.append("wave1_journal_not_committed")
    if int((source.get("applied") or {}).get("requeued") or -1) != 5:
        blockers.append("wave1_applied_count_not_5")
    if len(entries) != 5:
        blockers.append("wave1_journal_entry_count_not_5")

    outcomes: list[dict[str, Any]] = []
    conn = _open_ro(cfg.db)
    try:
        for wid, entry in sorted(entries.items()):
            row = _fetch_row(conn, wid)
            if row is None:
                outcomes.append({
                    "work_item_id": wid, "phase": entry.get("phase"),
                    "status": None, "verdict": None, "classification": "MISSING",
                })
                blockers.append(f"wave1_row_missing:{wid}")
                continue
            status = str(row["status"] or "").lower()
            verdict = str(row["verdict"] or "").upper()
            payload = _json_obj(row["payload_json"])
            if status in {"pending", "active"}:
                classification = "IN_FLIGHT"
                blockers.append(f"wave1_not_terminal:{wid}:{status}")
            elif verdict == "INFRA_FAIL":
                classification = "INFRA_FAIL"
                blockers.append(f"wave1_infra_recurrence:{wid}")
            elif not verdict:
                classification = "NO_VERDICT"
                blockers.append(f"wave1_terminal_without_verdict:{wid}")
            elif verdict in {"INVALID", "INVALID_REPORT", "NO_HISTORY", "NO_REAL_TICKS"}:
                classification = "INVALID"
                blockers.append(f"wave1_invalid_outcome:{wid}:{verdict}")
            elif str(row["phase"]) == "Q08" and _is_q08_invalid_report(payload):
                classification = "INVALID"
                blockers.append(f"wave1_q08_invalid_report:{wid}")
            else:
                classification = "REAL_VERDICT"
            outcomes.append({
                "work_item_id": wid,
                "ea_id": row["ea_id"],
                "symbol": row["symbol"],
                "phase": row["phase"],
                "status": row["status"],
                "verdict": row["verdict"],
                "updated_at": row["updated_at"],
                "classification": classification,
            })
    finally:
        conn.close()

    health = _health_census(cfg, symbol_skip_fn=symbol_skip_fn)
    if health["invariant"]["status"] != "PASS":
        blockers.append("health_disposition_invariant_failed")
    if int(health["invariant"]["q08_invalid_report_retryable"]) != 0:
        blockers.append("q08_invalid_report_exposed_to_retry")

    wave2_plan = _plan(
        cfg,
        phases=phases,
        include_q02_exhausted=include_q02_exhausted,
        limit=RECOVERY_WAVE_SIZES[2],
        symbol_skip_fn=symbol_skip_fn,
        priority_fn=priority_fn,
    )
    selection = _selection_contract(wave2_plan)
    if selection["size"] != RECOVERY_WAVE_SIZES[2]:
        blockers.append(
            f"wave2_requires_exactly_25_eligible:found={selection['size']}"
        )

    real_count = sum(1 for row in outcomes if row["classification"] == "REAL_VERDICT")
    infra_count = sum(1 for row in outcomes if row["classification"] == "INFRA_FAIL")
    invalid_count = sum(1 for row in outcomes if row["classification"] == "INVALID")
    scope = {
        "phases": list(phases),
        "include_q02_exhausted": bool(include_q02_exhausted),
    }
    decision_basis = {
        "source_journal_sha256": _file_sha256(journal_path),
        "db": str(Path(cfg.db).resolve()),
        "scope": scope,
        "outcomes": outcomes,
        "health_invariant": health["invariant"],
        "wave2_selection": selection,
        "blockers": sorted(set(blockers)),
    }
    return {
        "gate": "PASS" if not blockers else "BLOCKED",
        "blockers": sorted(set(blockers)),
        "source_journal": str(journal_path),
        "source_journal_sha256": decision_basis["source_journal_sha256"],
        "scope": scope,
        "wave1": {
            "expected_size": RECOVERY_WAVE_SIZES[1],
            "outcomes": outcomes,
            "terminal_real_verdicts": real_count,
            "infra_recurrences": infra_count,
            "invalid_outcomes": invalid_count,
            "yield_pct": round(100.0 * real_count / RECOVERY_WAVE_SIZES[1], 3),
            "infra_rate_pct": round(100.0 * infra_count / RECOVERY_WAVE_SIZES[1], 3),
        },
        "wave2": {
            "exact_size": RECOVERY_WAVE_SIZES[2],
            "selection": selection,
        },
        "health_census": health,
        "decision_digest": _canonical_sha256(decision_basis),
    }


def _write_wave1_receipt(
    cfg: Config,
    journal_path: Path,
    receipt_path: Path,
    *,
    phases: tuple[str, ...],
    include_q02_exhausted: bool,
    symbol_skip_fn: Callable[[str], str | None] | None = None,
    priority_fn: Callable[[str], float] | None = None,
) -> dict[str, Any]:
    assessment = _assess_wave1(
        cfg,
        journal_path,
        phases=phases,
        include_q02_exhausted=include_q02_exhausted,
        symbol_skip_fn=symbol_skip_fn,
        priority_fn=priority_fn,
    )
    receipt = {
        "schema_version": WAVE_RECEIPT_SCHEMA,
        "contract": WAVE_CONTRACT,
        "generated_at_utc": _utc_now(),
        "read_only_assessment": True,
        "db": str(Path(cfg.db).resolve()),
        "assessment": assessment,
    }
    _write_journal(receipt_path, receipt)
    return receipt


def _validate_wave2_receipt(
    cfg: Config,
    receipt_path: Path,
    *,
    phases: tuple[str, ...],
    include_q02_exhausted: bool,
    symbol_skip_fn: Callable[[str], str | None] | None = None,
    priority_fn: Callable[[str], float] | None = None,
) -> dict[str, Any]:
    """Fail closed unless a fresh, exact Wave-1 PASS binds the next 25 rows."""
    receipt_path = Path(receipt_path).resolve()
    receipt = json.loads(receipt_path.read_text(encoding="utf-8"))
    if receipt.get("schema_version") != WAVE_RECEIPT_SCHEMA or receipt.get("contract") != WAVE_CONTRACT:
        raise RuntimeError("wave-2 receipt schema/contract mismatch")
    if str(Path(receipt.get("db") or "").resolve()) != str(Path(cfg.db).resolve()):
        raise RuntimeError("wave-2 receipt is bound to a different DB")
    recorded = receipt.get("assessment") or {}
    if recorded.get("gate") != "PASS":
        raise RuntimeError(
            "wave-2 blocked by Wave-1 receipt: " + ", ".join(recorded.get("blockers") or ["unknown"])
        )
    expected_scope = {
        "phases": list(phases),
        "include_q02_exhausted": bool(include_q02_exhausted),
    }
    if recorded.get("scope") != expected_scope:
        raise RuntimeError("wave-2 receipt recovery scope differs from requested scope")

    fresh = _assess_wave1(
        cfg,
        Path(recorded["source_journal"]),
        phases=phases,
        include_q02_exhausted=include_q02_exhausted,
        symbol_skip_fn=symbol_skip_fn,
        priority_fn=priority_fn,
    )
    if fresh.get("gate") != "PASS":
        raise RuntimeError(
            "wave-2 live revalidation failed: " + ", ".join(fresh.get("blockers") or ["unknown"])
        )
    if fresh.get("decision_digest") != recorded.get("decision_digest"):
        raise RuntimeError("wave-2 receipt decision basis drifted since assessment")
    return {
        "receipt_path": str(receipt_path),
        "receipt_sha256": _file_sha256(receipt_path),
        "decision_digest": fresh["decision_digest"],
        "selection": fresh["wave2"]["selection"],
    }


def _plan_wave(
    cfg: Config,
    *,
    wave: int,
    phases: tuple[str, ...],
    include_q02_exhausted: bool,
    wave1_receipt: Path | None = None,
    symbol_skip_fn: Callable[[str], str | None] | None = None,
    priority_fn: Callable[[str], float] | None = None,
) -> dict[str, Any]:
    if wave not in RECOVERY_WAVE_SIZES:
        raise RuntimeError(f"unsupported recovery wave {wave}; allowed: 1, 2")
    gate: dict[str, Any] | None = None
    if wave == 2:
        if wave1_receipt is None:
            raise RuntimeError("wave 2 requires --wave1-receipt")
        gate = _validate_wave2_receipt(
            cfg,
            wave1_receipt,
            phases=phases,
            include_q02_exhausted=include_q02_exhausted,
            symbol_skip_fn=symbol_skip_fn,
            priority_fn=priority_fn,
        )
    elif wave1_receipt is not None:
        raise RuntimeError("--wave1-receipt is valid only with --wave 2")

    size = RECOVERY_WAVE_SIZES[wave]
    plan = _plan(
        cfg,
        phases=phases,
        include_q02_exhausted=include_q02_exhausted,
        limit=size,
        symbol_skip_fn=symbol_skip_fn,
        priority_fn=priority_fn,
    )
    selection = _selection_contract(plan)
    blockers: list[str] = []
    if selection["size"] != size:
        blockers.append(f"wave_{wave}_requires_exactly_{size}_eligible:found={selection['size']}")
    if gate is not None and selection["sha256"] != gate["selection"]["sha256"]:
        blockers.append("wave_2_selection_does_not_match_receipt")
    health = _health_census(cfg, symbol_skip_fn=symbol_skip_fn)
    if health["invariant"]["status"] != "PASS":
        blockers.append("health_disposition_invariant_failed")
    plan["recovery_wave"] = {
        "contract": WAVE_CONTRACT,
        "number": wave,
        "size": size,
        "status": "READY" if not blockers else "BLOCKED",
        "blockers": blockers,
        "selection": selection,
    }
    plan["wave_gate"] = gate
    plan["health_census"] = health
    return plan


def _print_plan(plan: dict[str, Any]) -> None:
    wave = plan.get("recovery_wave") or {}
    wave_text = (
        f"wave={wave.get('number')} exact_size={wave.get('size')} status={wave.get('status')}, "
        if wave else ""
    )
    print(f"stranded-INFRA requeue plan  ({wave_text}phases={','.join(plan['phases'])}, "
          f"q02_exhausted={plan['include_q02_exhausted']})")
    print(f"open items at start: {plan['open_at_start']}  (pending={plan['pending_at_start']})")
    print("")
    hdr = f"{'phase':6} {'stranded':>8} {'eligible':>8} {'refused':>7}  artifact(surv/purge)"
    print(hdr)
    print("-" * len(hdr))
    for phase in plan["phases"]:
        pp = plan["per_phase"].get(phase)
        if not pp:
            continue
        print(f"{phase:6} {pp['stranded_groups']:>8} {pp['eligible']:>8} {pp['refused']:>7}  "
              f"{pp['eligible_artifact_survives']}/{pp['eligible_artifact_purged']}")
        if pp["refuse_reasons"]:
            for reason, n in sorted(pp["refuse_reasons"].items(), key=lambda kv: -kv[1]):
                print(f"         refuse: {reason} = {n}")
    print("")
    print(f"eligible total: {plan['eligible_total']}   canary selected: {plan['canary_count']} "
          f"by phase {plan['canary_by_phase']}")
    print(f"canary artifact survives/purged: "
          f"{plan['canary_artifact_survives']}/{plan['canary_artifact_purged']}")
    print(f"queue impact: pending {plan['pending_at_start']} -> "
          f"{plan['projected_pending_after_canary']} (bounded wave)")
    if wave.get("blockers"):
        print("wave blockers: " + "; ".join(wave["blockers"]))
    health = plan.get("health_census") or {}
    if health:
        print(f"health census Q03-Q08: invariant={health['invariant']['status']} "
              f"current_infra_only={health['current_infra_only_total']} "
              f"historical={health['historical_exclusion_total']}")
    print("")
    print("canary list (deepest phase first):")
    print(f"  {'phase':6} {'ea_id':12} {'symbol':14} {'infra':>5} {'att':>4} art  prior_reason")
    for c in plan["canary"][:80]:
        art = "S" if c["artifact_survives"] else "-"
        print(f"  {c['phase']:6} {c['ea_id']:12} {str(c['symbol'])[:14]:14} "
              f"{c['infra_count']:>5} {c['attempt_count']:>4}  {art}   "
              f"{str(c['prior_verdict_reason'])[:60]}")
    if len(plan["canary"]) > 80:
        print(f"  ... {len(plan['canary']) - 80} more")


# --------------------------------------------------------------------------- apply / revert

def _revalidate(cfg: Config, conn: sqlite3.Connection, entry: dict[str, Any]) -> str | None:
    """Transaction-local re-check. Returns None if still eligible, else a refusal reason."""
    phase = str(entry["phase"])
    is_q02 = phase == Q02_PHASE
    row = _fetch_row(conn, entry["work_item_id"])
    if row is None:
        return "row_vanished"
    if row["verdict"] != "INFRA_FAIL" or row["status"] not in ("done", "failed"):
        return "no_longer_terminal_infra"
    ea_id, symbol, setfile = str(row["ea_id"]), str(row["symbol"]), row["setfile_path"]
    # a sibling may have been claimed/promoted between plan and apply
    pa = conn.execute(
        "SELECT 1 FROM work_items WHERE ea_id=? AND phase=? AND symbol=? "
        "AND ifnull(setfile_path,'')=ifnull(?, '') AND status IN ('pending','active') LIMIT 1",
        (ea_id, phase, symbol, setfile),
    ).fetchone()
    if pa:
        return "sibling_pending_active"
    dn = conn.execute(
        "SELECT 1 FROM work_items WHERE ea_id=? AND phase=? AND symbol=? "
        "AND ifnull(setfile_path,'')=ifnull(?, '') AND status='done' AND verdict!='INFRA_FAIL' LIMIT 1",
        (ea_id, phase, symbol, setfile),
    ).fetchone()
    if dn:
        return "sibling_done_non_infra"
    if _poison_pill_quarantined(conn, ea_id, symbol, phase):
        return "poison_pill_quarantined"
    if _later_phase_successor(conn, ea_id, symbol, phase) is not None:
        return "historical_phase_advanced"
    if farmctl._q02_symbol_skip_reason(symbol, allow_logical_basket=True):
        return "symbol_skip"
    num = _ea_int(ea_id)
    if (cfg.registry.get(num, (None, None))[0] if num is not None else None) != "active":
        return "registry_inactive"
    if not setfile or not Path(setfile).is_file():
        return SETFILE_MISSING
    if not _ea_has_ex5(cfg, ea_id):
        return "no_ex5"
    if int(row["attempt_count"] or 0) >= ATTEMPT_COUNT_POISON_FLOOR:
        return "poison_attempt_count_sentinel"
    payload = _json_obj(row["payload_json"])
    if phase == "Q08" and _is_q08_invalid_report(payload):
        return "q08_invalid_report_non_retryable"
    if _has_log_bomb_marker(payload):
        return "log_bomb_marker"
    if is_q02:
        if farmctl.is_q02_requeue_excluded(ea_id):
            return "requeue_excluded_q02"
    return None


def _build_flip_payload(entry: dict[str, Any], row: sqlite3.Row, now: str,
                        archive_dst: Path | None) -> str:
    """Clean stale runtime keys + stamp requeue provenance; return the new payload_json string.

    Preserves the verified flip payload shape: stale runtime keys cleared, requeue provenance
    stamped, prior INFRA verdict/reason retained, archive destination recorded when present.
    """
    payload = _json_obj(row["payload_json"])
    _clear_stale_runtime_payload(payload)
    payload["requeued_by"] = "requeue_stranded_infra"
    payload["requeued_at_utc"] = now
    payload["requeue_reason"] = (
        "q02_above_sweep_cap" if entry["phase"] == Q02_PHASE else "stranded_infra_deep_phase"
    )
    payload["requeue_prior_verdict"] = "INFRA_FAIL"
    prior_reason = _payload_reason(payload)
    if prior_reason:
        payload["requeue_prior_verdict_reason"] = prior_reason
    if archive_dst is not None:
        payload["archived_report_root_on_requeue"] = str(archive_dst)
    return json.dumps(payload, sort_keys=True)


def _apply(cfg: Config, plan: dict[str, Any], journal_path: Path) -> dict[str, Any]:
    """Crash-safe, byte-faithful apply. See the module docstring for the (a)..(e) ordering.

    journal_path is the durable journal (== --snapshot-out) written BEFORE any filesystem move
    and BEFORE the DB commit. Raises RuntimeError on any failure with per-path detail; every
    partial filesystem move is compensated and the DB transaction rolled back before raising.
    """
    journal_path = Path(journal_path)
    recovery_wave = plan.get("recovery_wave") or {}
    if recovery_wave:
        if recovery_wave.get("status") != "READY":
            raise RuntimeError(
                "recovery wave is not READY: "
                + ", ".join(recovery_wave.get("blockers") or ["unknown blocker"])
            )
        expected_size = int(recovery_wave.get("size") or 0)
        if len(plan.get("canary") or []) != expected_size:
            raise RuntimeError(
                f"recovery wave must contain exactly {expected_size} rows; "
                f"found {len(plan.get('canary') or [])}"
            )
        if int(recovery_wave.get("number") or 0) == 2:
            gate = plan.get("wave_gate") or {}
            receipt_path = gate.get("receipt_path")
            if not receipt_path or _file_sha256(Path(receipt_path)) != gate.get("receipt_sha256"):
                raise RuntimeError("wave-2 receipt missing or changed after planning")
            fresh_gate = _validate_wave2_receipt(
                cfg,
                Path(receipt_path),
                phases=tuple(plan.get("phases") or ()),
                include_q02_exhausted=bool(plan.get("include_q02_exhausted")),
            )
            if fresh_gate["decision_digest"] != gate.get("decision_digest"):
                raise RuntimeError("wave-2 gate drifted after planning")
            if fresh_gate["selection"]["sha256"] != recovery_wave["selection"]["sha256"]:
                raise RuntimeError("wave-2 selected rows no longer match receipt")
    canary = plan.get("canary") or []
    now = _utc_now()
    if not canary:
        print("nothing to apply: no eligible rows in canary")
        plan["journal"] = {"state": "committed", "applied_at_utc": now, "entries": {}}
        plan["applied"] = {"requeued": 0, "archived_report_roots": {}, "applied_at_utc": now}
        _write_journal(journal_path, plan)
        return plan["applied"]

    conn = sqlite3.connect(cfg.db, timeout=30)
    conn.row_factory = sqlite3.Row
    entries: dict[str, dict[str, Any]] = {}
    staged: list[tuple[str, str]] = []  # (wid, new_payload_json), applied at commit time
    try:
        conn.execute("BEGIN IMMEDIATE")
        # (a) revalidate EVERY row inside the transaction, uncommitted. Fail closed.
        for entry in canary:
            reason = _revalidate(cfg, conn, entry)
            if reason is not None:
                raise RuntimeError(
                    f"row {entry['work_item_id']} ({entry['ea_id']}/{entry['symbol']} "
                    f"{entry['phase']}) no longer eligible at apply (reason={reason}); "
                    f"aborting, no writes committed"
                )
        # (a) plan: compute per-row archive map, pre-apply state, expected post-apply state.
        #     No filesystem moves and no DB writes happen in this pass.
        for entry in canary:
            wid = entry["work_item_id"]
            row = _fetch_row(conn, wid)
            pre_state = _row_state(row)
            src, dst = _plan_archive_dst(cfg, wid, now)
            new_payload_json = _build_flip_payload(entry, row, now, dst)
            post_state = {
                "status": "pending", "verdict": None, "attempt_count": 0,
                "evidence_path": None, "claimed_by": None,
                "payload_json": new_payload_json, "updated_at": now,
            }
            entries[wid] = {
                "ea_id": entry["ea_id"], "symbol": entry["symbol"], "phase": entry["phase"],
                "archive_src": str(src) if dst is not None else None,
                "archive_dst": str(dst) if dst is not None else None,
                "pre_apply": pre_state, "post_apply": post_state,
            }
            staged.append((wid, new_payload_json))

        # (b) DURABLE JOURNAL before any move / commit: full archive map + pre + post states.
        plan["journal"] = {"state": "planned", "applied_at_utc": now, "entries": entries}
        plan["applied"] = None
        _write_journal(journal_path, plan)

        # (c) perform the report-root archive moves. ANY rename failure is FATAL.
        completed: list[tuple[Path, Path]] = []  # (dst, src) done this run, for compensation
        for wid, e in entries.items():
            if e["archive_dst"] is None:
                continue
            src, dst = Path(e["archive_src"]), Path(e["archive_dst"])
            try:
                _do_rename(src, dst)
                completed.append((dst, src))
            except OSError as ex:
                errors = [f"{src} -> {dst}: {ex}"]
                for cdst, csrc in reversed(completed):  # compensate: move everything back
                    try:
                        cdst.rename(csrc)
                    except OSError as cex:
                        errors.append(f"COMPENSATE FAILED {cdst} -> {csrc}: {cex}")
                raise RuntimeError(
                    "apply aborted: report-root archive move failed; DB rolled back, prior moves "
                    "compensated (journal left 'planned' for recovery). errors:\n  "
                    + "\n  ".join(errors)
                ) from ex

        # (d) only after ALL moves succeed, commit the DB flip.
        for wid, new_payload_json in staged:
            cur = conn.execute(
                "UPDATE work_items SET status='pending', verdict=NULL, attempt_count=0, "
                "evidence_path=NULL, claimed_by=NULL, payload_json=?, updated_at=? "
                "WHERE id=? AND verdict='INFRA_FAIL' AND status IN ('done','failed')",
                (new_payload_json, now, wid),
            )
            if cur.rowcount != 1:
                # Must not happen (write lock held since BEGIN IMMEDIATE); compensate + abort.
                errors = [f"row {wid}: expected exactly 1 flipped, got {cur.rowcount}"]
                for cdst, csrc in reversed(completed):
                    try:
                        cdst.rename(csrc)
                    except OSError as cex:
                        errors.append(f"COMPENSATE FAILED {cdst} -> {csrc}: {cex}")
                raise RuntimeError(
                    "apply aborted: unexpected row state at flip; DB rolled back, moves "
                    "compensated. " + "; ".join(errors)
                )
        conn.commit()
    except BaseException:
        conn.rollback()
        conn.close()
        raise
    conn.close()

    # (e) mark the journal 'committed' now that DB + filesystem agree.
    archived = {wid: e["archive_dst"] for wid, e in entries.items()}
    plan["journal"]["state"] = "committed"
    plan["applied"] = {
        "requeued": len(staged), "archived_report_roots": archived, "applied_at_utc": now,
    }
    _write_journal(journal_path, plan)
    print(f"requeued {len(staged)} row(s) to status='pending' (attempt_count=0) at {now}")
    return plan["applied"]


def _revert(cfg: Config, journal_path: Path) -> dict[str, Any]:
    """Crash-safe, byte-faithful revert. See the module docstring for the (a)..(e) ordering.

    Returns a result dict with keys: exit_code (0 = clean, non-zero = any drift/error),
    restored, skipped_drifted, unarchive_errors. Never swallows a failure — drifted rows and
    un-archive failures are surfaced with paths/reasons and force a non-zero exit_code.
    """
    journal_path = Path(journal_path)
    plan = json.loads(journal_path.read_text(encoding="utf-8"))
    journal = plan.get("journal")
    if not journal:
        raise RuntimeError(
            f"{journal_path} has no 'journal' section (pre-crash-safety snapshot?); "
            f"cannot revert byte-faithfully"
        )
    state = journal.get("state")
    entries: dict[str, dict[str, Any]] = journal.get("entries") or {}
    if state == "reverted":
        print("journal already marked 'reverted'; nothing to do")
        return {"exit_code": 0, "restored": 0, "skipped_drifted": [], "unarchive_errors": []}
    if not entries:
        print("journal has no entries; nothing to revert")
        return {"exit_code": 0, "restored": 0, "skipped_drifted": [], "unarchive_errors": []}

    conn = sqlite3.connect(cfg.db, timeout=30)
    conn.row_factory = sqlite3.Row
    restored = 0
    skipped: list[dict[str, Any]] = []
    fs_restored: list[tuple[Path, Path]] = []  # (src, dst) un-archived this run, for compensation
    try:
        # Hold a write lock for the whole revert so no worker can claim a row mid-way (closes the
        # classify -> filesystem -> DB-write window). No rows are written until the UPDATEs below.
        conn.execute("BEGIN IMMEDIATE")

        # (b) classify each row against the EXACT recorded states. Under the write lock this is a
        #     consistent snapshot. 'committed' rows still need the DB flip undone; 'already_pre'
        #     rows (crashed apply that never committed) only need filesystem compensation.
        committed_rows: list[tuple[str, dict[str, Any]]] = []
        already_pre: list[tuple[str, dict[str, Any]]] = []
        for wid, e in entries.items():
            cur_state = _row_state(_fetch_row(conn, wid))
            if _state_matches(cur_state, e["post_apply"]):
                committed_rows.append((wid, e))
            elif _state_matches(cur_state, e["pre_apply"]):
                already_pre.append((wid, e))
            else:
                skipped.append({
                    "work_item_id": wid, "ea_id": e.get("ea_id"),
                    "symbol": e.get("symbol"), "phase": e.get("phase"),
                    "current_status": cur_state.get("status"),
                    "current_verdict": cur_state.get("verdict"),
                    "reason": "row_drifted_from_expected_post_apply_state",
                })

        # (c) restore report roots FIRST — BEFORE the DB is written. Any failure aborts here.
        unarchive_errors: list[str] = []
        for wid, e in committed_rows + already_pre:
            dst = e.get("archive_dst")
            if not dst:
                continue  # nothing was archived for this row
            src, dstp = Path(e["archive_src"]), Path(dst)
            if src.exists():
                continue  # already restored (idempotent re-run / crash recovery)
            if not dstp.exists():
                unarchive_errors.append(
                    f"{wid}: archive {dstp} missing and original root {src} absent")
                continue
            try:
                _do_rename(dstp, src)
                fs_restored.append((src, dstp))
            except OSError as ex:
                unarchive_errors.append(f"{wid}: {dstp} -> {src}: {ex}")

        if unarchive_errors:
            # Compensate the un-archives already done this run so filesystem stays consistent with
            # the (still untouched) DB, then abort BEFORE any DB write.
            comp_errors: list[str] = []
            for src, dstp in reversed(fs_restored):
                try:
                    src.rename(dstp)
                except OSError as cex:
                    comp_errors.append(f"COMPENSATE FAILED {src} -> {dstp}: {cex}")
            conn.rollback()
            conn.close()
            msg = ("revert aborted: report-root un-archive failed BEFORE any DB write:\n  "
                   + "\n  ".join(unarchive_errors))
            if comp_errors:
                msg += "\n  " + "\n  ".join(comp_errors)
            print(msg, file=sys.stderr)
            return {"exit_code": 1, "restored": 0, "skipped_drifted": skipped,
                    "unarchive_errors": unarchive_errors}

        # (d) restore the DB rows from the journal's pre-apply states, in one transaction.
        for wid, e in committed_rows:
            st = e["pre_apply"]
            cur = conn.execute(
                "UPDATE work_items SET status=?, verdict=?, attempt_count=?, evidence_path=?, "
                "claimed_by=?, payload_json=?, updated_at=? "
                "WHERE id=? AND status='pending' AND verdict IS NULL AND attempt_count=0 "
                "AND claimed_by IS NULL AND evidence_path IS NULL",
                (st["status"], st["verdict"], st["attempt_count"], st["evidence_path"],
                 st["claimed_by"], st["payload_json"], st["updated_at"], wid),
            )
            if cur.rowcount != 1:
                raise RuntimeError(
                    f"revert aborted: row {wid} changed under the write lock during DB restore "
                    f"(rowcount={cur.rowcount}); filesystem already restored — re-run --revert"
                )
            restored += 1
        conn.commit()
    except BaseException:
        conn.rollback()
        conn.close()
        raise
    conn.close()

    # (e) journal bookkeeping: 'reverted' ONLY when nothing was refused. A partial
    # revert keeps state 'partially_reverted' so a later --revert re-processes the
    # remaining entries (already-restored rows classify as exact pre-apply and are
    # skipped; formerly drifted rows revert once they again match the journalled
    # post-apply state). Adversarial review 2026-07-26 batch 3: an unconditional
    # 'reverted' made the rerun a silent exit-0 no-op with one entry unreverted.
    journal["state"] = "reverted" if not skipped else "partially_reverted"
    journal["reverted_at_utc"] = _utc_now()
    journal["skipped_drifted"] = skipped
    _write_journal(journal_path, plan)

    for s in skipped:
        print(f"REFUSED revert for {s['work_item_id']} ({s['ea_id']}/{s['symbol']} {s['phase']}): "
              f"drifted from expected post-apply state "
              f"(status={s['current_status']}, verdict={s['current_verdict']}); reverted nothing "
              f"for it", file=sys.stderr)
    print(f"reverted {restored} row(s) to their prior INFRA_FAIL state; "
          f"restored {len(fs_restored)} archived report root(s); "
          f"skipped {len(skipped)} drifted row(s)")
    return {"exit_code": 1 if skipped else 0, "restored": restored,
            "skipped_drifted": skipped, "unarchive_errors": []}


def main(argv: list[str] | None = None) -> int:
    ap = argparse.ArgumentParser(description=__doc__.split("\n", 1)[0])
    ap.add_argument("--db", type=Path, default=DEFAULT_DB)
    ap.add_argument("--eas-root", type=Path, default=DEFAULT_EAS)
    ap.add_argument("--registry", type=Path, default=DEFAULT_REGISTRY)
    ap.add_argument("--wi-reports-root", type=Path, default=DEFAULT_WI_REPORTS)
    ap.add_argument("--phases", default=",".join(DEFAULT_DEEP_PHASES),
                    help="comma list of deep phases to sweep (default Q04,Q05,Q06,Q07)")
    ap.add_argument("--include-q02-exhausted", action="store_true",
                    help="also requeue Q02 groups ABOVE the sweep's INFRA cap (its unreachable set)")
    ap.add_argument("--wave", type=int, choices=sorted(RECOVERY_WAVE_SIZES), default=1,
                    help="bounded recovery wave: 1 = exactly 5, 2 = exactly 25")
    ap.add_argument("--wave1-receipt", type=Path,
                    help="required PASS receipt for --wave 2")
    ap.add_argument("--assess-wave1", type=Path,
                    help="read-only assessment of a committed Wave-1 journal")
    ap.add_argument("--receipt-out", type=Path,
                    help="durable Wave-1 assessment receipt (required with --assess-wave1)")
    ap.add_argument("--health-census", action="store_true",
                    help="print the read-only Q03-Q08 disposition census and exit")
    ap.add_argument("--limit", type=int, default=None, help=argparse.SUPPRESS)
    ap.add_argument("--apply", action="store_true",
                    help="execute the flip (Factory OFF + DB quiescent). Default is dry-run.")
    ap.add_argument("--revert", type=Path, help="revert using a snapshot from a prior --apply")
    ap.add_argument("--snapshot-out", type=Path,
                    help="write the reversible plan/snapshot JSON here (dry-run and --apply)")
    args = ap.parse_args(argv)

    cfg = Config.build(db=args.db, eas_root=args.eas_root,
                       registry_path=args.registry, wi_reports_root=args.wi_reports_root)

    if args.limit is not None:
        print("--limit was retired by MNT-007; applies are fixed to --wave 1 (5) then "
              "--wave 2 (25).", file=sys.stderr)
        return 2

    phases = tuple(p.strip() for p in args.phases.split(",") if p.strip())

    if args.health_census:
        if args.apply or args.revert or args.assess_wave1 or args.receipt_out:
            print("--health-census is read-only and cannot be combined with mutation/receipt modes",
                  file=sys.stderr)
            return 2
        census = _health_census(cfg)
        print(json.dumps(census, indent=1, sort_keys=True))
        if args.snapshot_out is not None:
            _write_journal(args.snapshot_out, census)
            print(f"health census written: {args.snapshot_out}")
        return 0 if census["invariant"]["status"] == "PASS" else 1

    if args.assess_wave1 is not None:
        if args.apply or args.revert or args.wave1_receipt:
            print("--assess-wave1 is a standalone read-only mode", file=sys.stderr)
            return 2
        if args.receipt_out is None:
            print("--assess-wave1 requires --receipt-out", file=sys.stderr)
            return 2
        try:
            receipt = _write_wave1_receipt(
                cfg,
                args.assess_wave1,
                args.receipt_out,
                phases=phases,
                include_q02_exhausted=args.include_q02_exhausted,
            )
        except (OSError, ValueError, KeyError, RuntimeError, json.JSONDecodeError) as ex:
            print(f"Wave-1 assessment failed closed: {ex}", file=sys.stderr)
            return 1
        print(json.dumps(receipt, indent=1, sort_keys=True))
        print(f"Wave-1 receipt written: {args.receipt_out}")
        return 0 if receipt["assessment"]["gate"] == "PASS" else 1

    if args.receipt_out is not None:
        print("--receipt-out is valid only with --assess-wave1", file=sys.stderr)
        return 2

    if args.revert is not None:
        try:
            return int(_revert(cfg, args.revert)["exit_code"])
        except RuntimeError as ex:
            print(f"revert failed: {ex}", file=sys.stderr)
            return 1

    # A durable journal is MANDATORY before any mutation.
    if args.apply and args.snapshot_out is None:
        print("--apply requires --snapshot-out: a durable journal must be written "
              "before any DB mutation. Aborting, no writes performed.", file=sys.stderr)
        return 2

    try:
        plan = _plan_wave(
            cfg,
            wave=args.wave,
            phases=phases,
            include_q02_exhausted=args.include_q02_exhausted,
            wave1_receipt=args.wave1_receipt,
        )
    except (OSError, ValueError, KeyError, RuntimeError, json.JSONDecodeError) as ex:
        print(f"wave planning failed closed: {ex}", file=sys.stderr)
        return 2
    _print_plan(plan)

    if args.apply:
        if plan["recovery_wave"]["status"] != "READY":
            print("--apply refused: exact bounded wave is not READY", file=sys.stderr)
            return 2
        # _apply owns the journal: it writes 'planned' before any move/commit, then 'committed'.
        try:
            _apply(cfg, plan, args.snapshot_out)
        except RuntimeError as ex:
            print(f"apply failed: {ex}", file=sys.stderr)
            return 1
        print(f"journal written: {args.snapshot_out}")
    else:
        if args.snapshot_out is not None:
            _write_journal(args.snapshot_out, plan)
            print(f"\nsnapshot written: {args.snapshot_out}")
        print("\n[dry-run] no DB writes performed. Re-run with --apply after Factory OFF to execute.")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
