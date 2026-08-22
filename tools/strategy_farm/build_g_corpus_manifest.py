"""Content-addressed manifest for the G: VPS-Portfolio-Build corpus (SP-D1).

Catalogues an existing archive. It never ingests a source, reserves an EA id,
creates a card, or enqueues anything -- the hard constraints of router task
`0fb2edcb-7411-4323-9422-e4fb0fd9adc2`. The farm database is opened read-only
(`mode=ro`) so binding cannot mutate the ledger.

Must run in the interactive session that owns the DriveFS mount; `G:` is not
visible to the headless scheduler context (see
docs/ops/evidence/2026-08-22_sp_d1_corpus_manifest_access_gate.md).
"""
from __future__ import annotations

import argparse
import hashlib
import json
import re
import sqlite3
import unicodedata
from pathlib import Path

DB_RO = "file:D:/QM/strategy_farm/state/farm_state.sqlite?mode=ro"
DEFAULT_ROOT = Path("G:/My Drive/QuantMechanica - VPS Portfolio Build")
MEDIA = {".pdf": "application/pdf", ".mq5": "text/x-mql5"}

# Trust levels are a property of the artifact class, not of its content:
# a raw MQ5 pulled from the web is never trusted, per OWNER-DEC-MQ5-PROMOTION-BAN.
TRUST = {".pdf": "ARCHIVED_REFERENCE", ".mq5": "RAW_UNTRUSTED"}


def sha256_of(path: Path) -> tuple[str, int]:
    h = hashlib.sha256()
    size = 0
    with path.open("rb") as fh:
        for chunk in iter(lambda: fh.read(1 << 20), b""):
            h.update(chunk)
            size += len(chunk)
    return h.hexdigest(), size


def norm(text: str) -> str:
    """Fold to a comparable token stream for fuzzy title binding."""
    text = unicodedata.normalize("NFKD", text).encode("ascii", "ignore").decode()
    return re.sub(r"[^a-z0-9]+", " ", text.lower()).strip()


def load_ledger() -> list[dict]:
    conn = sqlite3.connect(DB_RO, uri=True)
    conn.row_factory = sqlite3.Row
    rows = [dict(r) for r in conn.execute("SELECT * FROM sources")]
    conn.close()
    return rows


def bind(path: Path, ledger: list[dict]) -> tuple[dict | None, str]:
    """Bind a file to an existing ledger row.

    Returns (row, binding_kind). A weak match is reported unbound rather than
    guessed -- a wrong binding would create false provenance, which is worse
    than a declared gap.

    Two binding kinds exist because the ledger has two granularities:
      FILE       -- a row naming this exact file (the quarantined MQ5 rows do)
      COLLECTION -- a row covering the archive as a whole, with no per-document
                    granularity. Recorded as such, never dressed up as a
                    per-file binding.
    """
    name = path.name.lower()
    for row in ledger:
        uri = (row.get("uri") or "").replace("\\", "/").lower()
        if uri.endswith("/" + name) or Path(uri).name == name:
            return row, "FILE"

    target = set(norm(path.stem).split())
    if target:
        best, best_score = None, 0.0
        for row in ledger:
            for field in (row.get("title") or "", Path(row.get("uri") or "").stem):
                tokens = set(norm(field).split())
                if not tokens:
                    continue
                overlap = len(target & tokens) / max(len(target | tokens), 1)
                if overlap > best_score:
                    best, best_score = row, overlap
        if best_score >= 0.6:
            return best, "FILE"

    for row in ledger:
        if row.get("source_type") != "local_archive":
            continue
        uri = (row.get("uri") or "").replace("\\", "/")
        if "*" in uri:
            continue
        if str(path).replace("\\", "/").lower().startswith(uri.lower()):
            return row, "COLLECTION"
    return None, "NONE"


def main() -> int:
    ap = argparse.ArgumentParser(description=__doc__)
    ap.add_argument("--root", type=Path, default=DEFAULT_ROOT)
    ap.add_argument("--out", type=Path, required=True)
    ap.add_argument("--retrieved-at-utc", required=True,
                    help="ISO-8601 UTC; caller-supplied so the tool needs no clock")
    args = ap.parse_args()

    root = args.root
    if not root.is_dir():
        print(json.dumps({"ok": False, "reason": f"root_not_readable:{root}"}))
        return 2

    ledger = load_ledger()
    files = sorted(
        p for p in root.rglob("*")
        if p.is_file() and p.suffix.lower() in MEDIA
    )

    entries, file_unbound = [], []
    for path in files:
        ext = path.suffix.lower()
        digest, size = sha256_of(path)
        rel = path.relative_to(root).as_posix()
        row, kind = bind(path, ledger)
        if kind != "FILE":
            file_unbound.append(rel)
        entries.append({
            "source_id": row["id"] if row else None,
            "relative_path": rel,
            "sha256": digest,
            "size_bytes": size,
            "media_type": MEDIA[ext],
            "source_url": (row or {}).get("uri"),
            "final_url": None,
            "retrieved_at_utc": args.retrieved_at_utc,
            "license_or_usage_basis": "ARCHIVED_RESEARCH_REFERENCE_INTERNAL_ONLY",
            "trust_level": TRUST[ext],
            "harvest_status": (row or {}).get("status") or "ARCHIVED_NOT_IN_LEDGER",
            "ledger_binding": kind,
            "candidate_ids": [],
            "card_ids": [],
            "retention_class": "REPRODUCIBILITY_EVIDENCE_DO_NOT_PURGE",
            "confidentiality": "INTERNAL",
        })

    pdfs = [e for e in entries if e["media_type"] == "application/pdf"]
    mq5s = [e for e in entries if e["media_type"] == "text/x-mql5"]
    coverage = {
        "files_total": len(entries),
        "pdf_total": len(pdfs),
        "mq5_total": len(mq5s),
        "pdf_bound_file_level": sum(1 for e in pdfs if e["ledger_binding"] == "FILE"),
        "pdf_bound_collection_level": sum(1 for e in pdfs if e["ledger_binding"] == "COLLECTION"),
        "pdf_unbound": sum(1 for e in pdfs if e["ledger_binding"] == "NONE"),
        "mq5_bound_file_level": sum(1 for e in mq5s if e["ledger_binding"] == "FILE"),
        "raw_untrusted_mq5": sum(1 for e in mq5s if e["trust_level"] == "RAW_UNTRUSTED"),
        "sha256_missing": sum(1 for e in entries if not e["sha256"]),
    }
    manifest = {
        "schema": "qm.g_corpus_manifest/v1",
        "task_id": "0fb2edcb-7411-4323-9422-e4fb0fd9adc2",
        "root": str(root),
        "retrieved_at_utc": args.retrieved_at_utc,
        "retention_policy": "OWNER-DEC-G-RETENTION 2026-08-22: manifest-first, no deletion before this manifest and a dependency dry-run exist",
        "coverage": coverage,
        "pdf_without_file_level_binding": file_unbound,
        "entries": entries,
    }
    args.out.parent.mkdir(parents=True, exist_ok=True)
    args.out.write_text(json.dumps(manifest, indent=1, ensure_ascii=False), encoding="utf-8")
    manifest_sha, _ = sha256_of(args.out)
    print(json.dumps({"ok": True, "out": str(args.out),
                      "manifest_sha256": manifest_sha, "coverage": coverage}, indent=1))
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
