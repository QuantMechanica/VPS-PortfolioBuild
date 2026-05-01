#!/usr/bin/env python3
"""Build canonical .DWX symbol matrix from a DWX import hourly log.

Purpose: sanitize hand-maintained symbol lists by deriving the 36-symbol
matrix directly from canonical import-log evidence.
"""
from __future__ import annotations

import argparse
import json
import re
from pathlib import Path

SKIP_PATTERN = re.compile(r"\bskip\s+[^:]+:\s+already in MT5 as\s+([A-Za-z0-9_.-]+\.DWX)\b")


def parse_symbols(log_text: str) -> list[str]:
    ordered: list[str] = []
    seen: set[str] = set()
    for line in log_text.splitlines():
        m = SKIP_PATTERN.search(line)
        if not m:
            continue
        symbol = m.group(1).strip()
        if symbol in seen:
            continue
        seen.add(symbol)
        ordered.append(symbol)
    return ordered


def load_candidate_symbols(path: Path) -> list[str]:
    raw = path.read_text(encoding="utf-8", errors="replace").splitlines()
    out: list[str] = []
    for line in raw:
        s = line.strip()
        if not s or s.startswith("#"):
            continue
        out.append(s)
    return out


def main() -> int:
    ap = argparse.ArgumentParser()
    ap.add_argument("--log", required=True, help="Path to hourly_YYYY-MM-DD.log")
    ap.add_argument("--candidate", help="Optional candidate symbol list to audit")
    ap.add_argument("--out-list", required=True, help="Output text file with canonical symbols")
    ap.add_argument("--out-json", required=True, help="Output JSON summary")
    ap.add_argument("--expected-count", type=int, default=36)
    args = ap.parse_args()

    log_path = Path(args.log)
    log_text = log_path.read_text(encoding="utf-8", errors="replace")
    canonical = parse_symbols(log_text)

    candidate: list[str] = []
    unexpected: list[str] = []
    missing: list[str] = []
    if args.candidate:
        candidate = load_candidate_symbols(Path(args.candidate))
        cset = set(candidate)
        sset = set(canonical)
        unexpected = sorted(cset - sset)
        missing = sorted(sset - cset)

    out_list = Path(args.out_list)
    out_list.parent.mkdir(parents=True, exist_ok=True)
    out_list.write_text("\n".join(canonical) + "\n", encoding="utf-8")

    summary = {
        "source_log": str(log_path),
        "canonical_count": len(canonical),
        "expected_count": args.expected_count,
        "count_match": len(canonical) == args.expected_count,
        "canonical_symbols": canonical,
        "candidate_path": args.candidate,
        "candidate_count": len(candidate),
        "unexpected_in_candidate": unexpected,
        "missing_from_candidate": missing,
    }

    out_json = Path(args.out_json)
    out_json.parent.mkdir(parents=True, exist_ok=True)
    out_json.write_text(json.dumps(summary, indent=2), encoding="utf-8")

    print(f"canonical_count={len(canonical)} expected={args.expected_count}")
    if args.candidate:
        print(f"candidate_count={len(candidate)} unexpected={len(unexpected)} missing={len(missing)}")
        if unexpected:
            print("unexpected_symbols=" + ",".join(unexpected))
        if missing:
            print("missing_symbols=" + ",".join(missing))
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
