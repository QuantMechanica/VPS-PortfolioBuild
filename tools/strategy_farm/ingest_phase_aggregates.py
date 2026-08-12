"""Reconcile on-disk phase `aggregate.json` verdicts into the farm state DB.

A phase runner (e.g. `framework/scripts/q10_confirmation.py`) writes an
`aggregate.json` with the (EA, symbol) verdict but never touches sqlite: the
`work_items` / `ea_metrics` rows are created only by the `terminal_worker`
dispatch that launched the run. When a gate is re-run out-of-band with the
factory OFF (the 2026-07-24/25 Q10 revalidation), the verdicts land on disk and
in no database, so `portfolio/ftmo_qualification.py` — which hard-requires a
Q10 PASS `work_items` row (`STRICT_PHASES`) — rejects otherwise-qualified pairs
as `q10_pass_missing`.

This tool walks the durable aggregate roots for a phase and upserts the missing
rows so the DB again reflects the evidence on disk. It is phase-parameterised
(`--phase`, default Q10) because Q04 will need exactly the same reconciliation
once WP-7 makes its aggregates durable; nothing here is Q10-specific except the
default.

Four design choices carry the whole safety argument (Codex WP-2 review
2026-07-25 hardened all four; round-3 tightened setfile authentication to a
refusal and the guarded revert to all three inserted row kinds):

  * ATOMIC IDEMPOTENCY.  The write path opens ONE `BEGIN IMMEDIATE` transaction,
    re-validates every planned insert against the current committed state inside
    it, and records each ingest in a durable ledger table whose PRIMARY KEY is
    ``(ea_id, symbol, phase, generated_at_utc, evidence_sha256)``. Two
    simultaneous applies therefore serialise on the reserved lock and the second
    sees the first's ledger rows; the ledger key is the durable backstop that
    makes a double-insert impossible even across process crashes. Pairing the
    timestamp with an immutable evidence hash means an aggregate rewritten under
    an unchanged ``generated_at_utc`` is DETECTED (surfaced as an observation),
    not silently skipped.
  * SAFE SUPERSEDE.  A strictly-newer on-disk re-run is ingested ONLY when it
    changes the terminal verdict. When the existing terminal DB row already
    carries the same verdict, the supersede is suppressed and recorded as an
    observation — a second Q10 PASS row would spawn a phantom
    `portfolio_candidates` row and inflate the OWNER Q12 review frontier
    (`agent_router.sync_q11_candidates` keys candidates by work-item id;
    `render_cockpit.q12_review_ready_count` COUNT(*)s them).
  * IMMUTABLE + AUTHENTICATED SETFILE PROVENANCE.  The setfile is resolved from
    the aggregate's OWN per-run ``tester.ini`` (written once, never reused), NOT
    the shared, mutable ``summary.json`` (which a sibling run in the same run_tag
    dir overwrites — that is how QM5_12567/XNGUSD resolved to the XAUUSD setfile).
    EA + symbol identity is validated against the aggregate, a tester.ini with no
    Symbol is REFUSED (``tester_ini_symbol_missing`` — an unprovable symbol), and
    the path must exist; a row whose real setfile cannot be proved is REFUSED,
    never written with an empty ``setfile_path`` (which satisfies NOT NULL but
    violates the work-item contract dispatch/repair/audit depend on). The current
    setfile bytes are then AUTHENTICATED against the run summary's recorded
    ``execution_identity.setfile.source.sha256`` (matched to our setfile by
    basename, since the summary is shared): a proven byte MISMATCH is a hard
    refusal (``setfile_hash_mismatch`` — no edited-after-run laundering), while a
    setfile NO surviving hash can cover is ALSO REFUSED by default
    (``setfile_hash_unavailable``). Destruction of proof by a sibling run that
    overwrote the shared summary is a reason to refuse (or obtain fresh sealed
    evidence), NOT evidence that the run may be authenticated (Codex WP-2
    round-3). The ``--allow-unverified`` flag is the explicit OWNER-exception
    escape hatch: it restores the flagged ingest (``setfile_sha256_verified:
    false`` recorded) and prints a loud per-row warning; it is OFF by default.
  * ``INVALID`` is ingested as ``INVALID`` (status ``failed``), never folded
    into ``FAIL``. Keeping unevaluable/infrastructure outcomes distinct from
    strategy rejections is the premise the rest of the gate-repair programme
    depends on.

PERSISTENT SCHEMA STANCE (a deliberate migration, made explicit, not silent).
This tool creates the ``ingest_phase_aggregate_ledger`` table if absent and
forward-migrates the ``ea_metrics`` columns via ``ea_metrics.ensure_schema``.
Both are DELIBERATE, ADDITIVE-ONLY persistent migrations: created-if-absent,
never dropped or altered by ``--revert``. The rationale is that the ledger is a
crash-safe uniqueness backstop whose entire purpose is to make a double-insert
impossible ACROSS process crashes AND reverts — a backstop a revert could drop
would not be a backstop. ``--revert`` therefore removes only the DATA rows a
given apply inserted (its own work_items / ea_metrics / ledger rows, each guarded
by a fingerprint) and leaves the schema in place. The pre-apply snapshot records
whether the ledger table and each migrated column pre-existed, so the migration a
given apply introduced is explicit in the audit trail.

Dry-run is the default and writes nothing; `--apply` is required to mutate.
Every apply writes a reversible pre-state snapshot under `D:/QM/reports/state/`
BEFORE any schema or data change. The snapshot fingerprints ALL THREE rows each
insert creates (work_items, ea_metrics, ledger); `--revert <snapshot>` performs a
guarded reversal that refuses the whole triple when ANY of the three no longer
matches its ingest-time fingerprint (a per-row reason is reported) or when a
downstream `portfolio_candidates` row references it — it never blindly deletes by
id and never leaves an orphaned half-triple.
"""

from __future__ import annotations

import argparse
import datetime as dt
import hashlib
import json
import os
import re
import sqlite3
import sys
import uuid
from pathlib import Path
from typing import Any

# Reuse the canonical extractor so ingested ea_metrics rows are byte-identical
# to what `ea_metrics.build()` would have produced for the same aggregate.
try:
    import ea_metrics
except ModuleNotFoundError:  # pragma: no cover - packaged import path
    from tools.strategy_farm import ea_metrics  # type: ignore


DB_DEFAULT = Path(r"D:\QM\strategy_farm\state\farm_state.sqlite")
SNAPSHOT_DIR_DEFAULT = Path(r"D:\QM\reports\state")

# The canonical repo EA tree. Every existing Q10 `work_items.setfile_path` is a
# source path under here (e.g. C:\QM\repo\framework\EAs\<slug>\sets\<file>.set);
# tester.ini carries only the setfile basename, so we reconstruct that form.
REPO_EAS_DIR = Path(r"C:\QM\repo\framework\EAs")

# Durable idempotency ledger. Its composite PRIMARY KEY is the uniqueness
# constraint that makes a concurrent/crash double-insert impossible.
LEDGER_TABLE = "ingest_phase_aggregate_ledger"
_LEDGER_SCHEMA = f"""
CREATE TABLE IF NOT EXISTS {LEDGER_TABLE} (
    ea_id                   TEXT NOT NULL,
    symbol                  TEXT NOT NULL,
    phase                   TEXT NOT NULL,
    generated_at_utc        TEXT NOT NULL,
    evidence_sha256         TEXT NOT NULL,
    work_item_id            TEXT NOT NULL,
    setfile_path            TEXT NOT NULL,
    ingest_source_aggregate TEXT NOT NULL,
    ingested_at_utc         TEXT NOT NULL,
    PRIMARY KEY (ea_id, symbol, phase, generated_at_utc, evidence_sha256)
);
CREATE INDEX IF NOT EXISTS ix_{LEDGER_TABLE}_wi ON {LEDGER_TABLE}(work_item_id);
"""

# Both roots are live. The pipeline root nests one QM5_<id> level under a fixed
# base; the work_items root nests aggregates arbitrarily deep under per-run
# (and archived `.requeued_*`) directories, so it needs a recursive glob.
AGGREGATE_ROOTS: tuple[tuple[Path, str], ...] = (
    (Path(r"D:\QM\reports\pipeline"), "QM5_*/{phase}/*/aggregate.json"),
    (Path(r"D:\QM\reports\work_items"), "**/{phase}/*/aggregate.json"),
)

# Verdicts that represent an unevaluable / infrastructure outcome rather than a
# terminal strategy judgement. They land as status='failed' (mirroring the
# 1584:2 convention already in the table) which also keeps them out of the
# `status='done'` filter ftmo_qualification uses to find real passes.
NON_TERMINAL_VERDICTS = frozenset({"INVALID", "INFRA_FAIL"})

# work_items statuses that carry a settled verdict (used to decide whether a
# strictly-newer re-run genuinely changes the outcome — see supersede logic).
TERMINAL_STATUSES = frozenset({"done", "failed"})


def _utc_now() -> str:
    return dt.datetime.now(dt.timezone.utc).replace(microsecond=0).isoformat()


def _parse_ts(value: str | None) -> dt.datetime | None:
    """Parse an ISO-8601 timestamp to an aware datetime; None if unparseable."""
    if not value:
        return None
    text = value.strip()
    if text.endswith("Z"):
        text = text[:-1] + "+00:00"
    try:
        parsed = dt.datetime.fromisoformat(text)
    except ValueError:
        return None
    if parsed.tzinfo is None:
        parsed = parsed.replace(tzinfo=dt.timezone.utc)
    return parsed


def _load_json(path: Path) -> dict | None:
    """Load a JSON object, fail-closed. Any unreadable or non-JSON path (including
    a UTF-16 HTML evidence path decoded as UTF-8 — the live QM5_20002/EURUSD Q04
    row `137b7aac-...` points its evidence at a UTF-16 `report.htm`) yields None,
    never an exception, so a caller treats it as "no parseable content" and falls
    back to the next source in its chain. `UnicodeDecodeError` is a `ValueError`,
    not an `OSError`/`JSONDecodeError`, so it must be caught explicitly."""
    try:
        data = json.loads(path.read_text(encoding="utf-8-sig"))
    except (OSError, UnicodeDecodeError, json.JSONDecodeError):
        return None
    return data if isinstance(data, dict) else None


def _sha256_file(path: Path) -> str | None:
    """Hash the raw bytes of a file; None if unreadable. This is the immutable
    evidence identity paired with generated_at_utc in the idempotency key."""
    try:
        return hashlib.sha256(path.read_bytes()).hexdigest()
    except OSError:
        return None


def _ea_label(raw: Any) -> str:
    """Aggregates carry a bare int ea_id; both tables key on the QM5_ label."""
    return f"QM5_{int(raw)}"


def _fingerprint_row(wi: dict) -> str:
    """Deterministic content hash of a work_items row we insert, so a guarded
    revert can prove the row is byte-for-byte what we wrote before deleting it."""
    return hashlib.sha256(
        json.dumps(wi, sort_keys=True, ensure_ascii=False).encode("utf-8")
    ).hexdigest()


# --------------------------------------------------------------------------- #
# Setfile provenance (immutable per-run tester.ini, NOT shared summary.json)   #
# --------------------------------------------------------------------------- #

def _parse_tester_ini(path: Path) -> dict[str, str]:
    """Parse a run's tester.ini `[Tester]` section into key→value pairs."""
    out: dict[str, str] = {}
    try:
        text = path.read_text(encoding="utf-8-sig")
    except OSError:
        return out
    for raw in text.splitlines():
        line = raw.strip()
        if not line or line.startswith("[") or "=" not in line:
            continue
        key, _, value = line.partition("=")
        out[key.strip()] = value.strip()
    return out


# Refusal reasons a resolve can return, with the human note surfaced in reports.
_REFUSE_NOTES = {
    "setfile_unresolved": (
        "no immutable tester.ini setfile identity that exists on disk; refusing "
        "rather than writing an empty setfile_path"
    ),
    "tester_ini_symbol_missing": (
        "tester.ini carries no Symbol; the run's traded symbol cannot be proven, "
        "so the row is refused rather than ingested with an unprovable identity"
    ),
    "setfile_hash_mismatch": (
        "current setfile bytes do not match the run summary's recorded setfile "
        "sha256; refusing a setfile that appears to have been edited after the run"
    ),
    "setfile_hash_unavailable": (
        "no surviving recorded setfile sha256 covers this setfile (the shared, "
        "mutable summary was overwritten by a sibling run), so provenance cannot "
        "be authenticated; refusing by default — destruction of proof is not "
        "authentication. Re-run with --allow-unverified only under an explicit "
        "OWNER exception"
    ),
}


def _recorded_setfile_sha256(aggregate: dict, report_htm: Path, setfile_name: str) -> str | None:
    """Recover the setfile hash the run recorded, if one survives and is provably
    OURS. The run's ``summary.json`` carries
    ``execution_identity.setfile.source.sha256`` alongside the setfile source
    ``path``. That summary is SHARED and mutable across sibling runs in one
    run_tag dir (the same reason we never trust its bare setfile identity — see
    _resolve_setfile), so a recorded hash is authoritative for THIS row only when
    the recorded setfile basename equals the one our immutable tester.ini named.
    Returns the lower-cased hex hash, or None when no such hash survives (→ REFUSED
    as ``setfile_hash_unavailable`` by default; ingested flagged only under the
    ``--allow-unverified`` OWNER exception)."""
    summary_path = aggregate.get("summary_path")
    summary = (
        Path(str(summary_path)) if summary_path
        else report_htm.parent.parent.parent / "summary.json"
    )
    data = _load_json(summary)
    if not data:
        return None
    ident = data.get("execution_identity")
    if not isinstance(ident, dict):
        return None
    setfile = ident.get("setfile")
    if not isinstance(setfile, dict):
        return None
    source = setfile.get("source")
    if not isinstance(source, dict):
        return None
    recorded_path = source.get("path")
    recorded_sha = source.get("sha256")
    if not recorded_path or not recorded_sha:
        return None
    # Guard the shared/mutable summary: the recorded setfile must be the one our
    # per-run tester.ini named, else the hash belongs to a sibling run.
    if Path(str(recorded_path)).name.lower() != setfile_name.lower():
        return None
    return str(recorded_sha).strip().lower()


def _authenticate_setfile(
    aggregate: dict, report_htm: Path, setfile_name: str, candidate: Path
) -> tuple[bool, bool]:
    """Authenticate the current setfile bytes against the run's recorded hash.

    Returns ``(verified, mismatch)``:
      * ``(True,  False)`` — current bytes match a surviving recorded hash;
      * ``(False, True)``  — a surviving hash exists and the bytes DIFFER; this is
        a hard refusal (an edited-after-run setfile must never be laundered in);
      * ``(False, False)`` — no surviving hash applied to this setfile, so the
        provenance is recorded as unverified (the run happened — the limitation
        must be visible, not fatal).
    """
    recorded = _recorded_setfile_sha256(aggregate, report_htm, setfile_name)
    if recorded is None:
        return False, False
    current = _sha256_file(candidate)
    if current is None:  # path exists but bytes unreadable — cannot prove mismatch
        return False, False
    if current.lower() == recorded:
        return True, False
    return False, True


def _resolve_setfile(aggregate: dict, allow_unverified: bool = False) -> dict:
    """Recover AND authenticate the setfile that actually ran, from the
    aggregate's OWN per-run ``tester.ini`` (immutable), NOT the shared, mutable
    ``summary.json``.

    A run's ``summary.json`` is overwritten by any sibling run that reuses the
    same run_tag dir (e.g. XAUUSD and XNGUSD both under 20260724_215508), so it
    cannot prove which setfile produced THIS (ea, symbol) verdict — that is
    exactly how QM5_12567/XNGUSD resolved to the XAUUSD setfile. The tester.ini
    sitting next to the aggregate's ``report_htm`` is written once per run and
    never reused.

    ``allow_unverified`` is the explicit OWNER-exception escape hatch: OFF by
    default, a setfile no surviving hash can cover is REFUSED
    (``setfile_hash_unavailable``); ON, it is ingested flagged
    (``sha256_verified=False``). A proven byte MISMATCH is always a hard refusal.

    Returns ``{"path", "refuse_reason", "sha256_verified"}``:
      * ``refuse_reason`` non-None ⇒ the row is REFUSED and ``path`` is None
        (``setfile_unresolved`` / ``tester_ini_symbol_missing`` /
        ``setfile_hash_mismatch`` / ``setfile_hash_unavailable``);
      * otherwise ``path`` is the repo-source setfile path (the form
        dispatch/repair/audit expect) and ``sha256_verified`` says whether the
        current bytes were authenticated against a surviving recorded hash.
    """
    def refuse(reason: str) -> dict:
        return {"path": None, "refuse_reason": reason, "sha256_verified": False}

    report_htm = aggregate.get("report_htm")
    if not report_htm:
        return refuse("setfile_unresolved")
    report_htm_path = Path(str(report_htm))
    tester_ini = report_htm_path.parent / "tester.ini"
    if not tester_ini.exists():
        return refuse("setfile_unresolved")
    ini = _parse_tester_ini(tester_ini)
    setfile_name = ini.get("ExpertParameters") or ""
    expert = ini.get("Expert") or ""            # e.g. 'QM\\QM5_12567_cum-rsi2-commodity'
    ini_symbol = (ini.get("Symbol") or "").upper()
    if not setfile_name or not expert:
        return refuse("setfile_unresolved")
    # Never accept a nested/absolute ExpertParameters — we only reconstruct the
    # canonical repo source path from a bare basename.
    if setfile_name != Path(setfile_name).name:
        return refuse("setfile_unresolved")
    slug = expert.replace("/", "\\").split("\\")[-1]   # 'QM5_12567_cum-rsi2-commodity'

    # Identity guard 1: the EA in the tester.ini must be the aggregate's EA.
    try:
        agg_ea = int(aggregate["ea_id"])
    except (KeyError, TypeError, ValueError):
        return refuse("setfile_unresolved")
    slug_match = re.match(r"QM5_(\d+)", slug)
    if not slug_match or int(slug_match.group(1)) != agg_ea:
        return refuse("setfile_unresolved")

    # Identity guard 2: the tester.ini symbol must be present AND the aggregate's
    # symbol. A missing Symbol makes the identity guard vacuous — a run whose
    # traded symbol cannot be proven from its own tester.ini must not be ingested.
    if not ini_symbol:
        return refuse("tester_ini_symbol_missing")
    agg_symbol = str(aggregate.get("symbol") or "").upper()
    if agg_symbol and ini_symbol != agg_symbol:
        return refuse("setfile_unresolved")

    candidate = REPO_EAS_DIR / slug / "sets" / setfile_name
    if not candidate.exists():
        return refuse("setfile_unresolved")

    # Content authentication: the current bytes must not silently differ from the
    # setfile the run recorded. A proven mismatch is a hard refusal, and by
    # default so is a setfile no surviving hash can cover — destruction of proof
    # by a sibling is not authentication (Codex WP-2 round-3). --allow-unverified
    # is the explicit OWNER-exception path that restores the flagged ingest.
    verified, mismatch = _authenticate_setfile(
        aggregate, report_htm_path, setfile_name, candidate
    )
    if mismatch:
        return refuse("setfile_hash_mismatch")
    if not verified and not allow_unverified:
        return refuse("setfile_hash_unavailable")
    return {"path": str(candidate), "refuse_reason": None, "sha256_verified": verified}


# --------------------------------------------------------------------------- #
# Candidate discovery + idempotency                                           #
# --------------------------------------------------------------------------- #

def _discover_files(phase: str) -> list[Path]:
    found: list[Path] = []
    seen: set[str] = set()
    for base, pattern in AGGREGATE_ROOTS:
        if not base.exists():
            continue
        for path in base.glob(pattern.format(phase=phase)):
            key = str(path.resolve()).lower()
            if key not in seen:
                seen.add(key)
                found.append(path)
    return found


def _candidate_by_triple(phase: str) -> dict[tuple[str, str], dict]:
    """Collapse all on-disk aggregates for the phase to one candidate per
    (ea_id, symbol) — the file with the newest ``generated_at_utc``. Older
    siblings (archived requeues, prior runs) are superseded by their own newer
    disk copy and never ingested twice."""
    candidates: dict[tuple[str, str], dict] = {}
    for path in _discover_files(phase):
        aggregate = _load_json(path)
        if not aggregate:
            continue
        try:
            ea_id = _ea_label(aggregate["ea_id"])
        except (KeyError, TypeError, ValueError):
            continue
        symbol = str(aggregate.get("symbol") or "").upper()
        verdict = str(aggregate.get("verdict") or "")
        if not symbol or not verdict:
            continue
        gen = _parse_ts(aggregate.get("generated_at_utc"))
        if gen is None:
            continue
        key = (ea_id, symbol)
        prior = candidates.get(key)
        if prior is None or gen > prior["generated_at"]:
            candidates[key] = {
                "ea_id": ea_id,
                "symbol": symbol,
                "verdict": verdict,
                "generated_at": gen,
                "generated_at_utc": aggregate.get("generated_at_utc"),
                "evidence_sha256": _sha256_file(path),
                "reason": aggregate.get("reason"),
                "path": path,
                "aggregate": aggregate,
            }
    return candidates


def _existing_generated_at(row: sqlite3.Row) -> dt.datetime | None:
    """The comparison timestamp for an existing DB row: prefer a value we
    persisted at ingest, then the row's own evidence aggregate, then updated_at
    as a last resort so a purged aggregate still blocks a spurious re-insert."""
    try:
        payload = json.loads(row["payload_json"] or "{}")
    except (TypeError, json.JSONDecodeError):
        payload = {}
    stamped = _parse_ts(payload.get("generated_at_utc"))
    if stamped is not None:
        return stamped
    evidence = row["evidence_path"]
    if evidence:
        aggregate = _load_json(Path(evidence))
        if aggregate:
            gen = _parse_ts(aggregate.get("generated_at_utc"))
            if gen is not None:
                return gen
    return _parse_ts(row["updated_at"])


def _existing_rows(conn: sqlite3.Connection, phase: str) -> dict[tuple[str, str], list[sqlite3.Row]]:
    rows = conn.execute(
        "SELECT * FROM work_items WHERE phase=?",
        (phase,),
    ).fetchall()
    by_triple: dict[tuple[str, str], list[sqlite3.Row]] = {}
    for row in rows:
        key = (str(row["ea_id"]), str(row["symbol"] or "").upper())
        by_triple.setdefault(key, []).append(row)
    return by_triple


def _existing_ledger(conn: sqlite3.Connection, phase: str) -> dict[tuple[str, str], set[tuple[str, str]]]:
    """Prior ingests recorded by THIS tool: (ea, symbol) → {(gen_utc, sha256)}.
    Missing table (first-ever run) → empty."""
    out: dict[tuple[str, str], set[tuple[str, str]]] = {}
    try:
        rows = conn.execute(
            f"SELECT ea_id, symbol, generated_at_utc, evidence_sha256 "
            f"FROM {LEDGER_TABLE} WHERE phase=?",
            (phase,),
        ).fetchall()
    except sqlite3.OperationalError:
        return out
    for row in rows:
        key = (str(row["ea_id"]), str(row["symbol"] or "").upper())
        out.setdefault(key, set()).add((row["generated_at_utc"], row["evidence_sha256"]))
    return out


def _latest_terminal_verdict(prior_rows: list[sqlite3.Row]) -> str | None:
    """Verdict of the newest settled DB row for the pair, ordered exactly as
    ftmo_qualification._latest_phase_row (updated_at, created_at, id — all DESC).
    None if no row carries a terminal verdict yet."""
    terminal = [
        r for r in prior_rows
        if str(r["status"] or "") in TERMINAL_STATUSES and r["verdict"]
    ]
    if not terminal:
        return None
    terminal.sort(
        key=lambda r: (str(r["updated_at"] or ""), str(r["created_at"] or ""), str(r["id"] or "")),
        reverse=True,
    )
    return str(terminal[0]["verdict"])


def _persisted_hashes_at(
    prior_rows: list[sqlite3.Row],
    prior_max: dt.datetime,
    ledger_at_key: set[tuple[str, str]],
    gen_utc: str | None,
) -> set[str]:
    """Evidence hashes we IMMUTABLY recorded for the pair at ``prior_max`` — from
    the durable ledger and from each DB row's persisted ``evidence_sha256``. These
    are the anchors that tell an idempotent re-scan (same hash) from a
    same-timestamp aggregate rewrite (different hash). We never re-hash the file
    on disk, because a file rewritten in place would match itself and hide the
    change."""
    hashes: set[str] = set()
    if gen_utc is not None:
        hashes |= {h for (g, h) in ledger_at_key if g == gen_utc}
    for row in prior_rows:
        gen = _existing_generated_at(row)
        if gen is not None and gen == prior_max:
            try:
                payload = json.loads(row["payload_json"] or "{}")
            except (TypeError, json.JSONDecodeError):
                payload = {}
            recorded = payload.get("evidence_sha256")
            if recorded:
                hashes.add(str(recorded))
    return hashes


# --------------------------------------------------------------------------- #
# Row construction                                                            #
# --------------------------------------------------------------------------- #

def _build_rows(candidate: dict, phase: str, now: str, setfile_path: str,
                setfile_sha256_verified: bool) -> dict:
    """Produce the work_items + ea_metrics rows for one ingested aggregate.

    Insert-only: a fresh uuid means we can never overwrite a terminal_worker
    row, and revert is an unambiguous DELETE of these ids. ``setfile_path`` is
    resolved and validated by the caller (never empty — see _resolve_setfile).
    ``setfile_sha256_verified`` records whether the current setfile bytes were
    authenticated against the run's recorded hash (false => a surviving hash did
    not cover this setfile; the provenance limitation is made visible, not fatal).
    """
    aggregate = candidate["aggregate"]
    path = candidate["path"]
    verdict = candidate["verdict"]
    ea_id = candidate["ea_id"]
    symbol = candidate["symbol"]
    work_item_id = str(uuid.uuid4())

    status = "failed" if verdict in NON_TERMINAL_VERDICTS else "done"
    reason = candidate["reason"]

    payload = {
        "verdict_reason": reason,  # WP-2: reason lives under verdict_reason, not `reason`
        "evidence_provenance": "phase_runner",
        # INVALID/INFRA_FAIL are infrastructure outcomes; do not mislabel them
        # as strategy verdicts even though verdict!='INFRA_FAIL' here.
        "verdict_taxonomy": "infra" if verdict in NON_TERMINAL_VERDICTS else "strategy",
        # Persist the idempotency key so a future run can compare without
        # re-reading (or needing) the aggregate file.
        "generated_at_utc": candidate["generated_at_utc"],
        "evidence_sha256": candidate["evidence_sha256"],
        "setfile_provenance": "tester_ini",
        # Whether the current setfile bytes were authenticated against the run's
        # recorded execution_identity.setfile.source.sha256 (WP-2 defect 3).
        "setfile_sha256_verified": setfile_sha256_verified,
        "ingested_by": "ingest_phase_aggregates.py",
        "ingested_at_utc": now,
        "ingest_source_aggregate": str(path),
    }

    work_items_row = {
        "id": work_item_id,
        "kind": "backtest",
        "phase": phase,
        "ea_id": ea_id,
        "symbol": symbol,
        "setfile_path": setfile_path,
        "status": status,
        "verdict": verdict,
        "attempt_count": 0,
        "parent_task_id": None,
        "evidence_path": str(path),
        "claimed_by": None,
        "payload_json": json.dumps(payload, sort_keys=True),
        "created_at": now,
        "updated_at": now,
    }

    # Reuse the canonical extractor: identical head/detail/source to build().
    head, detail, source = ea_metrics.extract_one(phase, str(path))
    try:
        evidence_mtime: float | None = os.path.getmtime(path)
    except OSError:
        evidence_mtime = None
    ea_metrics_row = {
        "work_item_id": work_item_id,
        "ea_id": ea_id,
        "phase": phase,
        "symbol": symbol,
        "verdict": verdict,
        "status": status,
        "net_profit": head.get("net_profit"),
        "profit_factor": head.get("profit_factor"),
        "trades": head.get("trades"),
        "drawdown_money": head.get("drawdown_money"),
        "drawdown_pct": head.get("drawdown_pct"),
        "sharpe": head.get("sharpe"),
        "detail_json": json.dumps(detail, ensure_ascii=False) if detail else None,
        "source": source,
        "evidence_path": str(path),
        "evidence_mtime": evidence_mtime,
        "extracted_at": now,
        "is_ablation": 0,
        "parent_work_item_id": None,
    }
    return {"work_items": work_items_row, "ea_metrics": ea_metrics_row}


# --------------------------------------------------------------------------- #
# Planning                                                                    #
# --------------------------------------------------------------------------- #

def _public_action(action: dict) -> dict:
    """Strip internal-only keys (the row payload and the datetime) before an
    action is serialised to JSON or a snapshot."""
    return {k: v for k, v in action.items() if k not in ("_rows", "generated_at")}


def plan(conn: sqlite3.Connection, phase: str, now: str,
         allow_unverified: bool = False) -> dict:
    candidates = _candidate_by_triple(phase)
    existing = _existing_rows(conn, phase)
    ledger = _existing_ledger(conn, phase)

    actions: list[dict] = []
    skipped: list[dict] = []
    observations: list[dict] = []
    refused: list[dict] = []

    for key in sorted(candidates):
        candidate = candidates[key]
        prior_rows = existing.get(key, [])
        prior_gens = [g for g in (_existing_generated_at(r) for r in prior_rows) if g is not None]
        prior_max = max(prior_gens) if prior_gens else None

        gen = candidate["generated_at"]
        gen_utc = candidate["generated_at_utc"]
        ev_hash = candidate["evidence_sha256"]
        base = {
            "ea_id": candidate["ea_id"],
            "symbol": candidate["symbol"],
            "verdict": candidate["verdict"],
            "generated_at_utc": gen_utc,
            "evidence_sha256": ev_hash,
        }

        # (0) Durable idempotency: we already ingested this exact evidence.
        if ev_hash is not None and (gen_utc, ev_hash) in ledger.get(key, set()):
            skipped.append({**base, "reason": "already_in_ingest_ledger"})
            continue

        if prior_max is None:
            action = "insert_new"
        elif gen < prior_max:
            skipped.append({
                **base,
                "existing_generated_at_utc": prior_max.isoformat(),
                "reason": "db_row_newer",
            })
            continue
        elif gen == prior_max:
            # Equal timestamp => idempotent, UNLESS the aggregate was rewritten
            # under an unchanged generated_at_utc (different content hash). That
            # is an ambiguous provenance event: surface it, do not ingest (the
            # timestamp did not advance, so which run is authoritative is unclear).
            persisted = _persisted_hashes_at(prior_rows, prior_max, ledger.get(key, set()), gen_utc)
            if ev_hash is not None and persisted and ev_hash not in persisted:
                observations.append({
                    **base,
                    "type": "same_timestamp_content_changed",
                    "existing_generated_at_utc": prior_max.isoformat(),
                    "existing_evidence_sha256": sorted(persisted),
                    "note": "aggregate rewritten at an unchanged generated_at_utc; "
                            "not ingested — verify which run is authoritative",
                })
            else:
                skipped.append({
                    **base,
                    "existing_generated_at_utc": prior_max.isoformat(),
                    "reason": "db_row_equal",
                })
            continue
        else:  # gen > prior_max — a strictly-newer on-disk re-run
            # WP-2 defect 2: a supersede that does not change the terminal
            # verdict buys nothing and each extra Q10 PASS row spawns a phantom
            # portfolio_candidate (sync_q11_candidates keys by work-item id;
            # q12_review_ready_count COUNT(*)s), inflating the OWNER frontier.
            existing_verdict = _latest_terminal_verdict(prior_rows)
            if existing_verdict is not None and existing_verdict == candidate["verdict"]:
                observations.append({
                    **base,
                    "type": "supersede_suppressed_same_verdict",
                    "existing_generated_at_utc": prior_max.isoformat(),
                    "existing_verdict": existing_verdict,
                    "note": "newer on-disk re-run holds the same terminal verdict as "
                            "the DB row; not inserted to avoid a duplicate Q10 row / "
                            "phantom Q12 portfolio candidate",
                })
                continue
            action = "supersede"

        # Resolve + authenticate the setfile from the immutable per-run tester.ini.
        # Refuse the row (distinct reason) rather than write an empty setfile_path
        # (violates the work-item contract dispatch/repair/audit/cascade depend on)
        # or ingest a symbol we cannot prove or bytes that fail their recorded hash.
        resolved = _resolve_setfile(candidate["aggregate"], allow_unverified)
        if resolved["refuse_reason"]:
            reason = resolved["refuse_reason"]
            refused.append({
                **base,
                "reason": reason,
                "report_htm": candidate["aggregate"].get("report_htm"),
                "note": _REFUSE_NOTES.get(reason, "row refused"),
            })
            continue
        setfile_path = resolved["path"]
        setfile_sha256_verified = resolved["sha256_verified"]

        rows = _build_rows(candidate, phase, now, setfile_path, setfile_sha256_verified)
        actions.append({
            "action": action,
            **base,
            "generated_at": gen,  # internal only (stripped by _public_action)
            "existing_generated_at_utc": prior_max.isoformat() if prior_max else None,
            "work_item_id": rows["work_items"]["id"],
            "evidence_path": rows["work_items"]["evidence_path"],
            "setfile_path": setfile_path,
            "setfile_sha256_verified": setfile_sha256_verified,
            "profit_factor": rows["ea_metrics"]["profit_factor"],
            "trades": rows["ea_metrics"]["trades"],
            "drawdown_pct": rows["ea_metrics"]["drawdown_pct"],
            "_rows": rows,
        })

    counts: dict[str, dict[str, int]] = {}
    for act in actions:
        counts.setdefault(act["action"], {}).setdefault(act["verdict"], 0)
        counts[act["action"]][act["verdict"]] += 1

    return {
        "phase": phase,
        "allow_unverified": allow_unverified,
        "files_found": len(_discover_files(phase)),
        "candidate_triples": len(candidates),
        "existing_triples": len(existing),
        "counts": counts,
        "actions": actions,
        "skipped": skipped,
        "observations": observations,
        "refused": refused,
    }


# --------------------------------------------------------------------------- #
# Apply (snapshot-guarded, one BEGIN IMMEDIATE txn, never run without --apply) #
# --------------------------------------------------------------------------- #

def _schema_state(conn: sqlite3.Connection) -> dict:
    """Record, before we touch schema, whether our additive objects pre-exist —
    so the snapshot documents exactly what the apply introduced."""
    ledger_exists = conn.execute(
        "SELECT 1 FROM sqlite_master WHERE type='table' AND name=?", (LEDGER_TABLE,)
    ).fetchone() is not None
    try:
        ea_cols = {r[1] for r in conn.execute("PRAGMA table_info(ea_metrics)").fetchall()}
    except sqlite3.OperationalError:
        ea_cols = set()
    return {
        "ledger_table_preexisted": ledger_exists,
        "ea_metrics_had_is_ablation": "is_ablation" in ea_cols,
        "ea_metrics_had_parent_work_item_id": "parent_work_item_id" in ea_cols,
    }


def _ensure_ledger_schema(conn: sqlite3.Connection) -> None:
    conn.executescript(_LEDGER_SCHEMA)


def _write_snapshot(
    snapshot_dir: Path,
    db_path: Path,
    phase: str,
    now: str,
    result: dict,
    conn: sqlite3.Connection,
    schema_pre: dict,
) -> Path:
    """Dump the reversible pre-state BEFORE any schema or data change. Inserts
    use fresh uuids, so revert deletes those ids from work_items, ea_metrics and
    the ledger — but only after the guarded revert proves ALL THREE rows are
    unmodified and the work item is unreferenced downstream. Each revert item
    therefore carries a fingerprint for each of the three rows it will insert, so
    a post-hoc edit to ANY of them blocks the delete."""
    affected = {(a["ea_id"], a["symbol"]) for a in result["actions"]}
    pre_state = []
    for ea_id, symbol in sorted(affected):
        rows = conn.execute(
            "SELECT id, phase, verdict, status, updated_at, evidence_path "
            "FROM work_items WHERE ea_id=? AND symbol=? AND phase=?",
            (ea_id, symbol, phase),
        ).fetchall()
        pre_state.append({
            "ea_id": ea_id,
            "symbol": symbol,
            "existing_rows": [dict(r) for r in rows],
        })

    revert_items = []
    for act in result["actions"]:
        wi = act["_rows"]["work_items"]
        em = act["_rows"]["ea_metrics"]
        # The ledger row apply() inserts, reconstructed here from the same values
        # and the same `now` so its fingerprint matches the committed row exactly.
        ledger_row = {
            "ea_id": act["ea_id"],
            "symbol": act["symbol"],
            "phase": phase,
            "generated_at_utc": act["generated_at_utc"],
            "evidence_sha256": act["evidence_sha256"],
            "work_item_id": act["work_item_id"],
            "setfile_path": wi["setfile_path"],
            "ingest_source_aggregate": wi["evidence_path"],
            "ingested_at_utc": now,
        }
        revert_items.append({
            "work_item_id": act["work_item_id"],
            "fingerprint": _fingerprint_row(wi),
            "ea_metrics_fingerprint": _fingerprint_row(em),
            "ledger_fingerprint": _fingerprint_row(ledger_row),
            "ledger_key": {
                "ea_id": act["ea_id"],
                "symbol": act["symbol"],
                "phase": phase,
                "generated_at_utc": act["generated_at_utc"],
                "evidence_sha256": act["evidence_sha256"],
            },
        })

    snapshot = {
        "tool": "ingest_phase_aggregates.py",
        "phase": phase,
        "db_path": str(db_path),
        "generated_at_utc": now,
        "schema_pre": schema_pre,
        "revert": {
            "instruction": (
                "Run: ingest_phase_aggregates.py --revert <this-file> --db <db>. "
                "It deletes a listed work_item_id (+ its ea_metrics and ledger "
                "rows) ONLY when all three still match their recorded fingerprints "
                "and no portfolio_candidates row references it; if any of the three "
                "was modified it refuses the whole triple with a per-row reason. "
                "Additive schema (ledger table, ea_metrics columns) is a deliberate "
                "persistent migration and is intentionally NOT reverted."
            ),
            "items": revert_items,
            "inserted_work_item_ids": [a["work_item_id"] for a in result["actions"]],
        },
        "planned_actions": [_public_action(a) for a in result["actions"]],
        "observations": result.get("observations", []),
        "refused": result.get("refused", []),
        "pre_state": pre_state,
    }
    snapshot_dir.mkdir(parents=True, exist_ok=True)
    stamp = now.replace(":", "").replace("-", "").replace("+0000", "Z")
    # A short unique suffix so two applies in the same wall-clock second do not
    # overwrite each other's revert record (the winner's snapshot must survive).
    path = snapshot_dir / f"ingest_phase_aggregates_{phase}_{stamp}_{uuid.uuid4().hex[:8]}.json"
    path.write_text(json.dumps(snapshot, indent=2, sort_keys=True), encoding="utf-8")
    return path


def _still_insertable(conn: sqlite3.Connection, phase: str, act: dict) -> bool:
    """Re-validate one planned action inside the write transaction. False if a
    concurrent apply / terminal worker already covered the pair (durable ledger
    hit, or a work_items row now newer-or-equal)."""
    ea_id, symbol = act["ea_id"], act["symbol"]
    if conn.execute(
        f"SELECT 1 FROM {LEDGER_TABLE} "
        "WHERE ea_id=? AND symbol=? AND phase=? AND generated_at_utc=? AND evidence_sha256=?",
        (ea_id, symbol, phase, act["generated_at_utc"], act["evidence_sha256"]),
    ).fetchone():
        return False
    rows = conn.execute(
        "SELECT * FROM work_items WHERE ea_id=? AND symbol=? AND phase=?",
        (ea_id, symbol, phase),
    ).fetchall()
    gens = [g for g in (_existing_generated_at(r) for r in rows) if g is not None]
    prior_max = max(gens) if gens else None
    if prior_max is not None and act["generated_at"] <= prior_max:
        return False
    return True


def apply(db_path: Path, snapshot_dir: Path, phase: str,
          allow_unverified: bool = False) -> dict:
    now = _utc_now()
    # 1) Plan read-only for the snapshot + report.
    ro = sqlite3.connect(f"file:{db_path}?mode=ro", uri=True)
    ro.row_factory = sqlite3.Row
    try:
        result = plan(ro, phase, now, allow_unverified)
    finally:
        ro.close()

    # Manual transaction control (isolation_level=None) so BEGIN IMMEDIATE is
    # the single write transaction and additive schema commits before it.
    conn = sqlite3.connect(str(db_path), timeout=60, isolation_level=None)
    conn.row_factory = sqlite3.Row
    conn.execute("PRAGMA busy_timeout=60000")
    inserted: list[str] = []
    revalidation_skipped: list[dict] = []
    try:
        # 2) Snapshot BEFORE any schema or data change (WP-2 defect 4).
        schema_pre = _schema_state(conn)
        snapshot_path = _write_snapshot(snapshot_dir, db_path, phase, now, result, conn, schema_pre)

        # 3) Additive, idempotent schema — after the snapshot, before the txn.
        _ensure_ledger_schema(conn)
        ea_metrics.ensure_schema(conn)

        # 4) One atomic write transaction: revalidate then insert (WP-2 defect 1).
        conn.execute("BEGIN IMMEDIATE")
        for act in result["actions"]:
            if not _still_insertable(conn, phase, act):
                revalidation_skipped.append(_public_action(act))
                continue
            wi = act["_rows"]["work_items"]
            em = act["_rows"]["ea_metrics"]
            conn.execute(
                """INSERT INTO work_items
                     (id, kind, phase, ea_id, symbol, setfile_path, status, verdict,
                      attempt_count, parent_task_id, evidence_path, claimed_by,
                      payload_json, created_at, updated_at)
                   VALUES (:id, :kind, :phase, :ea_id, :symbol, :setfile_path, :status,
                           :verdict, :attempt_count, :parent_task_id, :evidence_path,
                           :claimed_by, :payload_json, :created_at, :updated_at)""",
                wi,
            )
            conn.execute(
                """INSERT INTO ea_metrics
                     (work_item_id, ea_id, phase, symbol, verdict, status,
                      net_profit, profit_factor, trades, drawdown_money, drawdown_pct,
                      sharpe, detail_json, source, evidence_path, evidence_mtime,
                      extracted_at, is_ablation, parent_work_item_id)
                   VALUES (:work_item_id, :ea_id, :phase, :symbol, :verdict, :status,
                           :net_profit, :profit_factor, :trades, :drawdown_money,
                           :drawdown_pct, :sharpe, :detail_json, :source, :evidence_path,
                           :evidence_mtime, :extracted_at, :is_ablation, :parent_work_item_id)
                   ON CONFLICT(work_item_id) DO NOTHING""",
                em,
            )
            # The ledger PRIMARY KEY is the durable uniqueness backstop.
            conn.execute(
                f"""INSERT INTO {LEDGER_TABLE}
                      (ea_id, symbol, phase, generated_at_utc, evidence_sha256,
                       work_item_id, setfile_path, ingest_source_aggregate, ingested_at_utc)
                    VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?)""",
                (act["ea_id"], act["symbol"], phase, act["generated_at_utc"],
                 act["evidence_sha256"], act["work_item_id"], wi["setfile_path"],
                 wi["evidence_path"], now),
            )
            inserted.append(act["work_item_id"])
        conn.execute("COMMIT")
    except Exception:
        try:
            conn.execute("ROLLBACK")
        except sqlite3.OperationalError:
            pass
        raise
    finally:
        conn.close()

    result["snapshot_path"] = str(snapshot_path)
    result["applied"] = True
    result["inserted_work_item_ids"] = inserted
    result["revalidation_skipped"] = revalidation_skipped
    return result


# --------------------------------------------------------------------------- #
# Guarded revert                                                              #
# --------------------------------------------------------------------------- #

_WI_KEYS = (
    "id", "kind", "phase", "ea_id", "symbol", "setfile_path", "status", "verdict",
    "attempt_count", "parent_task_id", "evidence_path", "claimed_by", "payload_json",
    "created_at", "updated_at",
)

# The exact key set _build_rows produces for the ea_metrics row (order-independent
# because _fingerprint_row sorts keys). Must match the ea_metrics dict 1:1.
_EA_METRICS_KEYS = (
    "work_item_id", "ea_id", "phase", "symbol", "verdict", "status",
    "net_profit", "profit_factor", "trades", "drawdown_money", "drawdown_pct",
    "sharpe", "detail_json", "source", "evidence_path", "evidence_mtime",
    "extracted_at", "is_ablation", "parent_work_item_id",
)

# The exact key set apply() inserts into the ledger (see the INSERT below).
_LEDGER_KEYS = (
    "ea_id", "symbol", "phase", "generated_at_utc", "evidence_sha256",
    "work_item_id", "setfile_path", "ingest_source_aggregate", "ingested_at_utc",
)


def _wi_dict_from_row(row: sqlite3.Row) -> dict:
    """Reconstruct the exact dict shape _build_rows inserted, for fingerprinting."""
    return {k: row[k] for k in _WI_KEYS}


def _em_dict_from_row(row: sqlite3.Row) -> dict:
    """Reconstruct the ea_metrics dict shape, for the guarded-revert fingerprint."""
    return {k: row[k] for k in _EA_METRICS_KEYS}


def _ledger_dict_from_row(row: sqlite3.Row) -> dict:
    """Reconstruct the ledger row dict shape, for the guarded-revert fingerprint."""
    return {k: row[k] for k in _LEDGER_KEYS}


def revert(db_path: Path, snapshot_path: Path) -> dict:
    """Guarded reversal of a prior apply. Deletes an inserted triple (work_items +
    ea_metrics + ledger) ONLY when ALL THREE rows still match the fingerprints
    recorded at ingest AND no portfolio_candidates row references the work item —
    otherwise it refuses the whole triple and reports a per-row reason, never
    blindly deleting by id and never leaving an orphaned half-triple."""
    snap = json.loads(Path(snapshot_path).read_text(encoding="utf-8"))
    if snap.get("tool") != "ingest_phase_aggregates.py":
        raise SystemExit(f"not an ingest_phase_aggregates snapshot: {snapshot_path}")
    items = snap.get("revert", {}).get("items", [])

    conn = sqlite3.connect(str(db_path), timeout=60, isolation_level=None)
    conn.row_factory = sqlite3.Row
    conn.execute("PRAGMA busy_timeout=60000")
    deleted: list[str] = []
    refused: list[dict] = []
    absent: list[str] = []
    try:
        pc_exists = conn.execute(
            "SELECT 1 FROM sqlite_master WHERE type='table' AND name='portfolio_candidates'"
        ).fetchone() is not None
        conn.execute("BEGIN IMMEDIATE")
        for item in items:
            wid = item["work_item_id"]
            wi_row = conn.execute("SELECT * FROM work_items WHERE id=?", (wid,)).fetchone()
            if wi_row is None:
                absent.append(wid)
                continue

            # Guard 1: EACH of the three rows we inserted must still be byte-for-byte
            # what we ingested. A post-hoc edit to ANY of them (including the sibling
            # ea_metrics / ledger rows Codex WP-2 flagged as previously unguarded)
            # blocks the whole triple, so we never destroy modified evidence and
            # never leave an orphaned half-triple. Reasons are collected per row.
            mismatched: list[str] = []
            if _fingerprint_row(_wi_dict_from_row(wi_row)) != item.get("fingerprint"):
                mismatched.append("modified_since_ingestion")
            if "ea_metrics_fingerprint" in item:
                em_row = conn.execute(
                    "SELECT * FROM ea_metrics WHERE work_item_id=?", (wid,)
                ).fetchone()
                if em_row is None or (
                    _fingerprint_row(_em_dict_from_row(em_row))
                    != item.get("ea_metrics_fingerprint")
                ):
                    mismatched.append("ea_metrics_modified_since_ingestion")
            if "ledger_fingerprint" in item:
                led_row = conn.execute(
                    f"SELECT * FROM {LEDGER_TABLE} WHERE work_item_id=?", (wid,)
                ).fetchone()
                if led_row is None or (
                    _fingerprint_row(_ledger_dict_from_row(led_row))
                    != item.get("ledger_fingerprint")
                ):
                    mismatched.append("ledger_modified_since_ingestion")
            if mismatched:
                refused.append({
                    "work_item_id": wid,
                    "reason": mismatched[0],
                    "rows_modified": mismatched,
                })
                continue

            # Guard 2: no downstream candidate may reference it.
            if pc_exists:
                refs = conn.execute(
                    "SELECT COUNT(*) AS c FROM portfolio_candidates WHERE q11_work_item_id=?",
                    (wid,),
                ).fetchone()["c"]
                if refs:
                    refused.append({
                        "work_item_id": wid,
                        "reason": f"downstream_portfolio_candidates:{refs}",
                    })
                    continue
            conn.execute("DELETE FROM work_items WHERE id=?", (wid,))
            conn.execute("DELETE FROM ea_metrics WHERE work_item_id=?", (wid,))
            conn.execute(f"DELETE FROM {LEDGER_TABLE} WHERE work_item_id=?", (wid,))
            deleted.append(wid)
        conn.execute("COMMIT")
    except Exception:
        try:
            conn.execute("ROLLBACK")
        except sqlite3.OperationalError:
            pass
        raise
    finally:
        conn.close()
    return {
        "snapshot": str(snapshot_path),
        "db_path": str(db_path),
        "deleted": deleted,
        "refused": refused,
        "absent": absent,
    }


# --------------------------------------------------------------------------- #
# Reporting                                                                   #
# --------------------------------------------------------------------------- #

def _render_human(result: dict, *, dry_run: bool) -> str:
    lines: list[str] = []
    mode = "DRY-RUN (no writes)" if dry_run else "APPLIED"
    lines.append(f"ingest_phase_aggregates {result['phase']} - {mode}")
    lines.append(
        f"  files_found={result['files_found']} "
        f"candidate_triples={result['candidate_triples']} "
        f"existing_triples={result['existing_triples']}"
    )
    counts = result["counts"]
    for action in ("insert_new", "supersede"):
        by_verdict = counts.get(action, {})
        total = sum(by_verdict.values())
        detail = ", ".join(f"{v}={n}" for v, n in sorted(by_verdict.items()))
        lines.append(f"  {action}: {total}" + (f"  ({detail})" if detail else ""))
    lines.append(f"  skipped (idempotent): {len(result['skipped'])}")
    lines.append(f"  observations (surfaced, not ingested): {len(result.get('observations', []))}")
    lines.append(f"  refused: {len(result.get('refused', []))}")
    unverified = [a for a in result["actions"] if not a.get("setfile_sha256_verified")]
    if result.get("allow_unverified"):
        lines.append(
            f"  setfile sha256: verified={len(result['actions']) - len(unverified)} "
            f"UNVERIFIED(ingested under --allow-unverified OWNER exception)={len(unverified)}"
        )
        # Loud, per-row, so an OWNER-exception ingest can never pass unnoticed.
        for act in unverified:
            lines.append(
                f"  !!! OWNER-EXCEPTION (--allow-unverified): INGESTING UNVERIFIED "
                f"setfile provenance for {act['ea_id']} {act['symbol']} - no surviving "
                f"recorded hash covers this setfile; proof was NOT authenticated"
            )
    else:
        lines.append(
            f"  setfile sha256: verified={len(result['actions']) - len(unverified)} "
            f"(unverified rows are REFUSED by default; use --allow-unverified to ingest)"
        )
    if not dry_run:
        lines.append(f"  inserted: {len(result.get('inserted_work_item_ids', []))}")
        lines.append(f"  revalidation-skipped: {len(result.get('revalidation_skipped', []))}")
    if result.get("snapshot_path"):
        lines.append(f"  snapshot: {result['snapshot_path']}")
    lines.append("")
    lines.append("  would-add (ea_id, symbol) verdict [action] pf/trades/dd% sha256:")
    for act in result["actions"]:
        lines.append(
            f"    {act['ea_id']:12} {act['symbol']:12} {act['verdict']:8} "
            f"[{act['action']}] pf={act['profit_factor']} "
            f"trades={act['trades']} dd%={act['drawdown_pct']} "
            f"sha256={'verified' if act.get('setfile_sha256_verified') else 'UNVERIFIED'}"
        )
    for obs in result.get("observations", []):
        lines.append(
            f"  OBSERVED [{obs.get('type')}] {obs.get('ea_id')} {obs.get('symbol')} "
            f"{obs.get('verdict')}: {obs.get('note')}"
        )
    for ref in result.get("refused", []):
        lines.append(
            f"  REFUSED {ref.get('ea_id')} {ref.get('symbol')} {ref.get('verdict')}: "
            f"{ref.get('reason')}"
        )
    return "\n".join(lines)


def main(argv: list[str] | None = None) -> int:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--phase", default="Q10", help="Pipeline phase to reconcile (default Q10)")
    parser.add_argument("--db", type=Path, default=DB_DEFAULT)
    parser.add_argument("--snapshot-dir", type=Path, default=SNAPSHOT_DIR_DEFAULT)
    parser.add_argument(
        "--apply", action="store_true",
        help="Write the rows. Omitted => dry-run (the default), which writes nothing.",
    )
    parser.add_argument(
        "--revert", type=Path, default=None,
        help="Guarded reversal of a prior apply snapshot JSON (deletes only unmodified, "
             "un-referenced inserted rows).",
    )
    parser.add_argument(
        "--allow-unverified", action="store_true",
        help="OWNER-EXCEPTION escape hatch (default OFF): ingest rows whose setfile "
             "provenance cannot be authenticated (no surviving recorded hash) instead "
             "of refusing them, recording setfile_sha256_verified:false and printing a "
             "loud per-row warning. A proven hash MISMATCH is still always refused.",
    )
    parser.add_argument("--json", action="store_true", help="Machine-readable output")
    args = parser.parse_args(argv)

    phase = args.phase.strip().upper()

    if args.revert is not None:
        result = revert(args.db, args.revert)
        print(json.dumps(result, indent=2, sort_keys=True))
        return 0

    if args.apply:
        result = apply(args.db, args.snapshot_dir, phase, allow_unverified=args.allow_unverified)
        dry_run = False
    else:
        now = _utc_now()
        conn = sqlite3.connect(f"file:{args.db}?mode=ro", uri=True)
        conn.row_factory = sqlite3.Row
        try:
            result = plan(conn, phase, now, allow_unverified=args.allow_unverified)
        finally:
            conn.close()
        dry_run = True

    # Loud per-row warning on stderr so an OWNER-exception ingest is never silent,
    # including in --json mode.
    if args.allow_unverified:
        for act in result["actions"]:
            if not act.get("setfile_sha256_verified"):
                print(
                    f"!!! OWNER-EXCEPTION (--allow-unverified): UNVERIFIED setfile "
                    f"provenance ingested for {act['ea_id']} {act['symbol']} - proof "
                    f"was NOT authenticated",
                    file=sys.stderr,
                )

    # Machine-readable output must not carry the internal _rows payload.
    public = dict(result)
    public["actions"] = [_public_action(a) for a in result["actions"]]
    public["dry_run"] = dry_run
    net_new = result["counts"].get("insert_new", {})
    supersede = result["counts"].get("supersede", {})
    public["summary"] = {
        "net_new": net_new,
        "supersede": supersede,
        "skipped": len(result["skipped"]),
        "observations": len(result.get("observations", [])),
        "refused": len(result.get("refused", [])),
        "allow_unverified": bool(args.allow_unverified),
    }

    if args.json:
        print(json.dumps(public, indent=2, sort_keys=True))
    else:
        print(_render_human(result, dry_run=dry_run))
    return 0


if __name__ == "__main__":
    sys.exit(main())
