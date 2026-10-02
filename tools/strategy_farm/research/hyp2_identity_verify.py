"""Re-derive the immutable input identities claimed by hyp2_mechanization/input_availability.json.

Read-only. Verifies byte identity only: the sealed 11422 stream's Git blob
hash (reusing ``hyp1_inputs.read_git_blob``/``verify_bytes``, the same
byte-identity primitives the already-reviewed HYP-1 task uses -- no second
hashing engine) and the declared XTIUSD/USDCAD HCC archive existence and file
sizes. It never decodes HCC OHLC bytes, never parses a JSONL record, and never
opens a 2025+ payload. A matching hash/size proves identity, not economic or
data validity -- see REVIEW.md and AUTHOR_DELIVERY.md Section 7 for the
remaining (unresolved) data-quality refusals this script does not and cannot
clear (price completeness, calendar alignment, contract-roll provenance).
"""
from __future__ import annotations

import argparse
import json
from pathlib import Path

from tools.strategy_farm.research.hyp1_inputs import read_git_blob

SEALED_STREAM = {
    "repo": "C:/QM/repo",
    "revision": "dd886aa3896e1e9d9b036bd77a493402da5e8410",
    "relative_path": "docs/research/ftmo_shadow/trackc_xau_cluster_financing_exits_c94e1a7f/streams/d2g6_incumbent/11422_USDCAD_DWX.jsonl",
    "expected_sha256": "2eddc16d02689caf0e4e4fc27f7dd421906d8a7263c4026dc623417811a9fcc9",
}


def verify_sealed_stream() -> dict:
    data = read_git_blob(Path(SEALED_STREAM["repo"]), SEALED_STREAM["revision"],
                          SEALED_STREAM["relative_path"], SEALED_STREAM["expected_sha256"])
    return {"check": "sealed_stream_git_blob_sha256", "path": SEALED_STREAM["relative_path"],
            "revision": SEALED_STREAM["revision"], "bytes": len(data), "match": True,
            "note": "Byte hashing only; no JSONL record parsing or outcome calculation."}


def verify_hcc_archives(manifest_path: Path) -> list[dict]:
    manifest = json.loads(manifest_path.read_text(encoding="utf-8-sig"))
    out = []
    for entry in manifest["archive_metadata"]:
        p = Path(entry["path"])
        exists = p.exists()
        size = p.stat().st_size if exists else None
        out.append({"check": "hcc_archive_existence_and_size", "symbol": entry["symbol"],
                    "year": entry["year"], "path": str(p), "expected_exists": entry["exists"],
                    "expected_bytes": entry["bytes"], "observed_exists": exists,
                    "observed_bytes": size, "match": exists == entry["exists"] and size == entry["bytes"],
                    "note": "Existence/size only; no OHLC bytes decoded."})
    return out


def main() -> int:
    ap = argparse.ArgumentParser(description=__doc__.splitlines()[0])
    ap.add_argument("--manifest", type=Path,
                     default=Path("C:/QM/repo/docs/ops/evidence/2026-09-26_astra_takeover/"
                                   "hyp2_mechanization/input_availability.json"))
    args = ap.parse_args()
    results = [verify_sealed_stream(), *verify_hcc_archives(args.manifest)]
    receipt = {"schema": "qm.hyp2-identity-verify/v1", "price_payload_read": False,
               "new_outcomes_computed": False, "results": results,
               "all_match": all(r["match"] for r in results)}
    print(json.dumps(receipt, indent=2))
    return 0 if receipt["all_match"] else 1


if __name__ == "__main__":
    raise SystemExit(main())
