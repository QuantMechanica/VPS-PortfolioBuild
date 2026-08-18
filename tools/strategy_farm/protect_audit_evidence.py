#!/usr/bin/env python3
"""Put the evidence the audit actually stands on somewhere a reports-tree deletion cannot reach.

Why
---
43,182 evidence directories under ``D:\\QM\\reports\\work_items`` are gone. The loss is not a
retention policy: every child directory older than 2026-07-07 10:30 is absent, while every other
subtree on D: still holds April and May entries. Two later partial events follow, one of them
documented in MNT_CONVERGENCE_LEDGER as a manual purge during a disk burn.

Whatever did it, the audit's own inputs are currently one such event away from being
unreconstructible - and they are small. The Q08 aggregates for the 91 pool pairs are 1.0 MB
together; all 216 sleeve streams are 13.1 MB. Protecting them costs nothing and removes the entire
class of "the batch gets paid for twice".

What is protected
-----------------
Deliberately narrow: only what a later revision would need to recompute a number it already
published.

  * Q08 aggregate.json for every pool pair that still has one
  * every sleeve stream under q08_trades (the 21 book sleeves plus the rest of the pool)
  * the frozen cohort file and the baseline snapshot manifest

NOT the full report tree. Copying hundreds of gigabytes would be a different project and would fail
for the same reason the tree is unprotectable in the first place.

Integrity
---------
Every file is hashed before it goes in and the manifest carries the hashes, so ``--verify`` can tell
"the archive is intact" apart from "the archive matches what is on disk today". Those are different
questions and both matter: the second one is how a future deletion becomes visible instead of silent.
"""

from __future__ import annotations

import argparse
import datetime as dt
import hashlib
import json
import os
import shutil
import sqlite3
import zipfile
from pathlib import Path
from typing import Any

DB = Path(r"D:\QM\strategy_farm\state\farm_state.sqlite")
REPO = Path(r"C:\QM\repo")
STREAMS = Path(r"D:\QM\reports\portfolio\sleeve_streams\QM\q08_trades")
COHORTS = REPO / "artifacts" / "book_q08_regeneration_cohorts_20260817.json"
BASELINE = REPO / "artifacts" / "audit_baseline_snapshot_20260818.json"
OFFHOST = Path(r"G:\My Drive\QuantMechanica - Company Reference\_audit_baselines")
SCHEMA = "qm.audit-evidence-vault/v1"


def sha256_file(p: Path) -> str:
    d = hashlib.sha256()
    with p.open("rb") as fh:
        for chunk in iter(lambda: fh.read(1 << 20), b""):
            d.update(chunk)
    return d.hexdigest()


def pool_pairs() -> list[dict[str, str]]:
    doc = json.loads(COHORTS.read_text(encoding="utf-8"))
    return [{"ea_id": r["ea_id"], "symbol": str(r["symbol"]).upper(), "cohort": c}
            for c, rows in doc["cohorts"].items() for r in rows]


def collect() -> tuple[list[tuple[Path, str]], dict[str, Any]]:
    """Return [(source path, archive name)] plus a coverage report."""
    items: list[tuple[Path, str]] = []
    report: dict[str, Any] = {"q08_aggregates": 0, "q08_missing": [], "streams": 0, "manifests": 0}
    con = sqlite3.connect(f"file:{DB}?mode=ro", uri=True, timeout=60)
    con.row_factory = sqlite3.Row
    try:
        for p in pool_pairs():
            row = con.execute(
                "SELECT evidence_path FROM ea_metrics WHERE ea_id=? AND phase='Q08' "
                "AND (UPPER(symbol)=? OR UPPER(symbol)=?) "
                "AND source NOT IN ('missing','no_evidence') "
                "ORDER BY extracted_at DESC LIMIT 1",
                (p["ea_id"], p["symbol"], p["symbol"] + ".DWX")).fetchone()
            path = Path(row["evidence_path"]) if row and row["evidence_path"] else None
            if path is None or not path.is_file():
                report["q08_missing"].append(f"{p['ea_id']}|{p['symbol']}")
                continue
            items.append((path, f"q08_aggregates/{p['ea_id']}_{p['symbol']}.json"))
            report["q08_aggregates"] += 1
    finally:
        con.close()
    for s in sorted(STREAMS.glob("*.jsonl")):
        items.append((s, f"sleeve_streams/{s.name}"))
        report["streams"] += 1
    for m in (COHORTS, BASELINE):
        if m.is_file():
            items.append((m, f"manifests/{m.name}"))
            report["manifests"] += 1
    return items, report


def build(out_zip: Path, out_manifest: Path, *, offhost: bool = True) -> dict[str, Any]:
    items, report = collect()
    entries = []
    out_zip.parent.mkdir(parents=True, exist_ok=True)
    with zipfile.ZipFile(out_zip, "w", zipfile.ZIP_DEFLATED, compresslevel=9) as zf:
        for src, name in items:
            digest = sha256_file(src)
            zf.write(src, name)
            entries.append({"archive_name": name, "source": str(src),
                            "sha256": digest, "bytes": src.stat().st_size})
    entries.sort(key=lambda e: e["archive_name"])
    content_hash = hashlib.sha256(
        "".join(f"{e['archive_name']}:{e['sha256']}" for e in entries).encode()).hexdigest()
    manifest = {
        "schema_version": SCHEMA,
        "built_at_utc": dt.datetime.now(dt.UTC).replace(microsecond=0).isoformat(),
        "baseline_snapshot": "3472a5d2e1b5",
        "archive": str(out_zip),
        "archive_sha256": sha256_file(out_zip),
        "archive_bytes": out_zip.stat().st_size,
        "content_hash": content_hash,
        "file_count": len(entries),
        "coverage": report,
        "files": entries,
    }
    out_manifest.write_text(json.dumps(manifest, indent=1, sort_keys=True) + "\n", encoding="utf-8")
    if offhost:
        try:
            OFFHOST.mkdir(parents=True, exist_ok=True)
            shutil.copy2(out_zip, OFFHOST / out_zip.name)
            shutil.copy2(out_manifest, OFFHOST / out_manifest.name)
            manifest["offhost"] = str(OFFHOST / out_zip.name)
        except Exception as exc:
            manifest["offhost_error"] = str(exc)
    return manifest


def verify(manifest_path: Path, zip_path: Path | None = None) -> dict[str, Any]:
    """Two independent questions, answered separately.

    ``archive_intact`` - does the zip still hash to what the manifest recorded?
    ``disk_matches``  - does each source file on disk still hash to what went in? A file that has
    vanished or changed since is reported by name, which is exactly the signal that was missing
    when 43,182 directories disappeared unnoticed.
    """
    m = json.loads(manifest_path.read_text(encoding="utf-8"))
    zp = zip_path or Path(m["archive"])
    out: dict[str, Any] = {"manifest": str(manifest_path), "archive": str(zp)}
    out["archive_present"] = zp.is_file()
    out["archive_intact"] = bool(zp.is_file() and sha256_file(zp) == m["archive_sha256"])
    gone, changed, ok = [], [], 0
    for e in m["files"]:
        src = Path(e["source"])
        if not src.is_file():
            gone.append(e["archive_name"])
            continue
        if sha256_file(src) != e["sha256"]:
            changed.append(e["archive_name"])
        else:
            ok += 1
    out.update({"disk_unchanged": ok, "disk_gone": gone, "disk_changed": changed,
                "disk_matches": not gone and not changed, "file_count": len(m["files"])})
    return out


def main() -> int:
    ap = argparse.ArgumentParser(description=__doc__)
    ap.add_argument("--build", action="store_true")
    ap.add_argument("--verify", type=Path)
    ap.add_argument("--zip", type=Path,
                    default=REPO / "artifacts" / "audit_evidence_vault_20260818.zip")
    ap.add_argument("--manifest", type=Path,
                    default=REPO / "artifacts" / "audit_evidence_vault_20260818.json")
    ap.add_argument("--no-offhost", action="store_true")
    args = ap.parse_args()
    if args.verify:
        print(json.dumps(verify(args.verify, args.zip if args.zip.is_file() else None), indent=1))
        return 0
    if args.build:
        m = build(args.zip, args.manifest, offhost=not args.no_offhost)
        print(json.dumps({k: v for k, v in m.items() if k != "files"}, indent=1))
        return 0
    items, report = collect()
    print(json.dumps({"would_archive": len(items), "coverage": report}, indent=1))
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
