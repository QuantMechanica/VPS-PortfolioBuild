#!/usr/bin/env python
"""ULTRACODE WS-A one-shot recovery-class classifier (provenance-safe, reversible).

Tags pending Q02 work_items that belong to the documented RECOVERY lineages with a
payload marker (`recovery_class`) so the shared claim ordering
(`farmctl.pending_claim_order_sql`) sorts them LAST (idle-only) and the durable
rolling ledger caps them to at most 1 of the last `CLAIM_RECOVERY_WINDOW` successful
claims (Operating Rule 22 — recovery on idle capacity only, never pre-empting eligible
priority/frontier work).

Recovery lineages (EXACT — matched on the explicit `payload["enqueued_by"]` provenance
field, never by string-guessing verdict reasons):

    * stranded_infra_fail   (e.g. "claude_sweep_enqueue_2026-06-10.stranded_infra_fail")
    * deferred_promotion    (e.g. "sweep_enqueue.deferred_promotion")
    * auto_q02              (e.g. "record_build_result.auto_q02")

`never_tested` is a fresh-discovery lineage and is DELIBERATELY EXCLUDED — it is not
recovery debris. Rows already carrying `priority_track: true` or an existing
`recovery_class` marker are skipped.

Provenance / compare-and-swap safety (Codex requirement):
    Each target row id is bound to its PRE-image payload SHA256 and its POST-image
    payload SHA256 in a durable manifest. `--apply` and `--revert` both open the DB
    read-write with BEGIN IMMEDIATE and only mutate a row when its CURRENT payload
    still hashes to the expected pre- (apply) / post- (revert) image — a true
    compare-and-swap. "Remove the flag" is never a blind rollback.

Modes:
    (default)   READ-ONLY dry-run: opens the DB via URI mode=ro + PRAGMA query_only=ON,
                prints the resolved DB path, computes the census + manifest, writes them
                to --out. Never mutates the DB. THIS is the mode used to produce the
                pending-Q02 class census; --apply / --revert run ONLY in the Factory-OFF
                window by the operator.
    --apply     Factory-OFF only: CAS-tag every manifest row still matching its pre-image.
    --revert    Factory-OFF only: CAS-untag every manifest row still matching its post-image.

    python classify_recovery_pending.py --out D:/QM/reports/.../manifest.json      # dry-run
    python classify_recovery_pending.py --manifest <path> --apply                  # OFF window
    python classify_recovery_pending.py --manifest <path> --revert                 # OFF window
"""
from __future__ import annotations

import argparse
import datetime as dt
import hashlib
import json
import sqlite3
from collections import Counter
from pathlib import Path

LIVE_DB = Path(r"D:\QM\strategy_farm\state\farm_state.sqlite")
DEFAULT_BATCH = "ultracode_recovery_20260726"
RECOVERY_PHASES = ("Q02", "P2")

# EXACT recovery lineages, matched on payload["enqueued_by"]. Order = census order.
RECOVERY_LINEAGES: dict[str, tuple[str, ...]] = {
    "stranded_infra_fail": ("stranded_infra_fail",),
    "deferred_promotion": ("deferred_promotion",),
    "auto_q02": ("auto_q02",),
}
EXCLUDED_LINEAGES = ("never_tested",)  # fresh discovery — never recovery


def _sha256_text(text: str) -> str:
    return hashlib.sha256(text.encode("utf-8")).hexdigest()


def _lineage_for(enqueued_by: str) -> str | None:
    eb = (enqueued_by or "").lower()
    if any(tok in eb for tok in EXCLUDED_LINEAGES):
        return None
    for lineage, tokens in RECOVERY_LINEAGES.items():
        if any(tok in eb for tok in tokens):
            return lineage
    return None


def _ro_connect(db: Path) -> sqlite3.Connection:
    uri = f"file:{db.resolve().as_posix()}?mode=ro"
    conn = sqlite3.connect(uri, uri=True, timeout=30)
    conn.row_factory = sqlite3.Row
    conn.execute("PRAGMA query_only=ON")
    return conn


def _rw_connect(db: Path) -> sqlite3.Connection:
    conn = sqlite3.connect(db, timeout=30)
    conn.row_factory = sqlite3.Row
    conn.execute("PRAGMA busy_timeout=30000")
    return conn


def build_manifest(db: Path, batch: str) -> dict:
    """READ-ONLY. Compute the tag manifest + census. Never mutates the DB."""
    now = dt.datetime.now(dt.UTC).replace(microsecond=0).isoformat()
    conn = _ro_connect(db)
    rows = conn.execute(
        "SELECT id, ea_id, symbol, payload_json FROM work_items "
        "WHERE status='pending' AND phase IN ('Q02','P2')"
    ).fetchall()

    census: Counter = Counter()
    skipped: Counter = Counter()
    entries: list[dict] = []
    for r in rows:
        raw = r["payload_json"] or "{}"
        try:
            payload = json.loads(raw)
        except Exception:
            skipped["unparseable_payload"] += 1
            continue
        if not isinstance(payload, dict):
            skipped["non_dict_payload"] += 1
            continue
        if payload.get("recovery_class"):
            skipped["already_recovery_class"] += 1
            continue
        if payload.get("priority_track") is True:
            skipped["priority_track_skipped"] += 1
            continue
        lineage = _lineage_for(str(payload.get("enqueued_by") or ""))
        if lineage is None:
            continue
        pre_sha = _sha256_text(raw)
        post_payload = dict(payload)
        post_payload["recovery_class"] = lineage
        post_payload["recovery_batch"] = batch
        post_payload["recovery_tagged_at_utc"] = now
        post_payload["recovery_pre_image_sha256"] = pre_sha
        post_json = json.dumps(post_payload, sort_keys=True)
        post_sha = _sha256_text(post_json)
        entries.append({
            "id": r["id"],
            "ea_id": r["ea_id"],
            "symbol": r["symbol"],
            "lineage": lineage,
            "enqueued_by": payload.get("enqueued_by"),
            "pre_sha256": pre_sha,
            "post_sha256": post_sha,
            "pre_payload_json": raw,
            "post_payload_json": post_json,
        })
        census[lineage] += 1
    conn.close()

    return {
        "batch": batch,
        "generated_at_utc": now,
        "resolved_db_path": str(db.resolve()),
        "recovery_marker_key": "recovery_class",
        "lineages": list(RECOVERY_LINEAGES.keys()),
        "excluded_lineages": list(EXCLUDED_LINEAGES),
        "total_pending_q02": len(rows),
        "tag_count": len(entries),
        "census_per_lineage": dict(census),
        "skipped": dict(skipped),
        "entries": entries,
    }


def apply_manifest(db: Path, manifest: dict, revert: bool = False) -> dict:
    """Factory-OFF only. CAS-apply (or --revert) the manifest against the live DB."""
    now = dt.datetime.now(dt.UTC).replace(microsecond=0).isoformat()
    entries = manifest.get("entries") or []
    changed = 0
    cas_mismatch = 0
    not_pending = 0
    conn = _rw_connect(db)
    try:
        conn.execute("BEGIN IMMEDIATE")
        for e in entries:
            row = conn.execute(
                "SELECT payload_json, status, phase FROM work_items WHERE id=?",
                (e["id"],),
            ).fetchone()
            if row is None:
                cas_mismatch += 1
                continue
            if row["status"] != "pending" or row["phase"] not in RECOVERY_PHASES:
                not_pending += 1
                continue
            current = row["payload_json"] or "{}"
            current_sha = _sha256_text(current)
            expected = e["post_sha256"] if revert else e["pre_sha256"]
            target = e["pre_payload_json"] if revert else e["post_payload_json"]
            if current_sha != expected:
                cas_mismatch += 1
                continue
            conn.execute(
                "UPDATE work_items SET payload_json=?, updated_at=? "
                "WHERE id=? AND status='pending'",
                (target, now, e["id"]),
            )
            changed += 1
        conn.commit()
    except Exception:
        conn.rollback()
        raise
    finally:
        conn.close()
    return {
        "mode": "revert" if revert else "apply",
        "entries": len(entries),
        "changed": changed,
        "cas_mismatch_skipped": cas_mismatch,
        "not_pending_skipped": not_pending,
    }


def main(argv=None) -> int:
    ap = argparse.ArgumentParser(description=__doc__,
                                 formatter_class=argparse.RawDescriptionHelpFormatter)
    ap.add_argument("--db", type=Path, default=LIVE_DB, help="farm DB (default: live)")
    ap.add_argument("--batch", default=DEFAULT_BATCH, help="batch marker id")
    ap.add_argument("--out", type=Path, help="dry-run: write manifest JSON here")
    g = ap.add_mutually_exclusive_group()
    g.add_argument("--apply", action="store_true", help="Factory-OFF: CAS-tag rows")
    g.add_argument("--revert", action="store_true", help="Factory-OFF: CAS-untag rows")
    ap.add_argument("--manifest", type=Path, help="manifest JSON for --apply/--revert")
    args = ap.parse_args(argv)

    print(f"RESOLVED_DB_PATH={args.db.resolve()}")

    if args.apply or args.revert:
        if not args.manifest or not args.manifest.exists():
            ap.error("--apply/--revert require an existing --manifest")
        manifest = json.loads(args.manifest.read_text(encoding="utf-8"))
        if str(Path(manifest.get("resolved_db_path", "")).resolve()) != str(args.db.resolve()):
            ap.error("manifest resolved_db_path does not match --db (refusing to cross DBs)")
        result = apply_manifest(args.db, manifest, revert=args.revert)
        print(json.dumps(result, indent=2))
        return 0

    # Default: READ-ONLY dry-run.
    manifest = build_manifest(args.db, args.batch)
    print(f"total pending Q02/P2 : {manifest['total_pending_q02']}")
    print(f"would tag (recovery) : {manifest['tag_count']}")
    print(f"census per lineage   : {manifest['census_per_lineage']}")
    print(f"skipped              : {manifest['skipped']}")
    if args.out:
        args.out.parent.mkdir(parents=True, exist_ok=True)
        args.out.write_text(json.dumps(manifest, indent=2), encoding="utf-8")
        print(f"manifest written     : {args.out.resolve()}")
    print("\n(dry-run, read-only) — --apply / --revert run ONLY in the Factory-OFF window")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
