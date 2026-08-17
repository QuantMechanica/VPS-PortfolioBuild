#!/usr/bin/env python3
"""Deterministically enumerate pattern-family EAs and their target-management shape.

The audit is intentionally lexical and narrow.  It does not declare strategy
quality.  It answers the specific QM5_20177 question: which source-bearing EAs
in a reproducibly selected pattern/harmonic cohort contain the exact combination
of signal-projection state, live-price target checks, and no fill-price anchor?
"""

from __future__ import annotations

import argparse
from collections import Counter
import hashlib
import json
from pathlib import Path
import re
from typing import Any, Iterable


SCHEMA = "qm.pattern-target-management-audit/v1"
DEFAULT_TERMS = (
    "pattern",
    "harmonic",
    "wave",
    "fib",
    "abcd",
    "gartley",
    "butterfly",
    "bat",
    "cypher",
    "drive",
    "crab",
    "shark",
    "5-0",
    "5_0",
    "carney",
    "pesavento",
    "goodman",
    "sperandeo",
    "zigzag",
)
EA_DIR_RE = re.compile(r"^QM5_(\d+)_(.+)$", re.IGNORECASE)
MANAGE_SIGNATURE_RE = re.compile(
    r"\bvoid\s+Strategy_ManageOpenPosition\s*\([^)]*\)\s*\{",
    re.MULTILINE,
)


def sha256_bytes(raw: bytes) -> str:
    return hashlib.sha256(raw).hexdigest()


def sha256_file(path: Path) -> str:
    digest = hashlib.sha256()
    with path.open("rb") as handle:
        while chunk := handle.read(1024 * 1024):
            digest.update(chunk)
    return digest.hexdigest()


def _mask_comments_and_literals(source: str) -> str:
    """Replace comments and quoted literals while preserving offsets/newlines."""
    result = list(source)
    index = 0
    state = "code"
    while index < len(source):
        char = source[index]
        nxt = source[index + 1] if index + 1 < len(source) else ""
        if state == "code":
            if char == "/" and nxt == "/":
                result[index] = result[index + 1] = " "
                index += 2
                state = "line_comment"
                continue
            if char == "/" and nxt == "*":
                result[index] = result[index + 1] = " "
                index += 2
                state = "block_comment"
                continue
            if char == '"':
                result[index] = " "
                index += 1
                state = "string"
                continue
            if char == "'":
                result[index] = " "
                index += 1
                state = "char"
                continue
            index += 1
            continue
        if state == "line_comment":
            if char == "\n":
                state = "code"
            else:
                result[index] = " "
            index += 1
            continue
        if state == "block_comment":
            if char == "*" and nxt == "/":
                result[index] = result[index + 1] = " "
                index += 2
                state = "code"
                continue
            if char != "\n":
                result[index] = " "
            index += 1
            continue
        if state in {"string", "char"}:
            delimiter = '"' if state == "string" else "'"
            if char == "\\" and nxt:
                result[index] = " "
                if nxt != "\n":
                    result[index + 1] = " "
                index += 2
                continue
            if char == delimiter:
                result[index] = " "
                index += 1
                state = "code"
                continue
            if char != "\n":
                result[index] = " "
            index += 1
    return "".join(result)


def _function_bodies(masked_source: str) -> list[str]:
    bodies: list[str] = []
    for match in MANAGE_SIGNATURE_RE.finditer(masked_source):
        opening = masked_source.rfind("{", match.start(), match.end())
        depth = 0
        for index in range(opening, len(masked_source)):
            if masked_source[index] == "{":
                depth += 1
            elif masked_source[index] == "}":
                depth -= 1
                if depth == 0:
                    bodies.append(masked_source[opening + 1 : index])
                    break
        else:
            raise ValueError("unterminated Strategy_ManageOpenPosition body")
    return bodies


def _matched_terms(slug: str, terms: Iterable[str]) -> list[str]:
    lowered = slug.casefold()
    return sorted({term for term in terms if term.casefold() in lowered})


def _classify_sources(sources: list[Path]) -> tuple[str, dict[str, Any]]:
    if not sources:
        return "NO_MQ5_SOURCE", {
            "management_hook_count": 0,
            "position_price_open": False,
            "projection_state_d_and_c": False,
            "live_bid_or_ask": False,
            "strategy_close_call": False,
        }

    masked_sources = [
        _mask_comments_and_literals(path.read_text(encoding="utf-8-sig", errors="replace"))
        for path in sources
    ]
    bodies = [body for source in masked_sources for body in _function_bodies(source)]
    combined_body = "\n".join(bodies)
    combined_source = "\n".join(masked_sources)
    signals = {
        "management_hook_count": len(bodies),
        "position_price_open": "POSITION_PRICE_OPEN" in combined_body,
        "projection_state_d_and_c": (
            "g_position_D" in combined_body and "g_position_C" in combined_body
        ),
        "live_bid_or_ask": (
            "SYMBOL_BID" in combined_body or "SYMBOL_ASK" in combined_body
        ),
        "strategy_close_call": (
            "QM_TM_PartialClose" in combined_body
            or "QM_TM_ClosePosition" in combined_body
        ),
        "projection_state_assigned_outside_manager": (
            "g_position_D" in combined_source and "g_position_C" in combined_source
        ),
    }
    if not bodies:
        return "NO_MANAGEMENT_HOOK", signals
    if not combined_body.strip():
        return "EMPTY_MANAGEMENT_HOOK", signals
    if signals["position_price_open"]:
        return "MANAGEMENT_ANCHORED_TO_FILL", signals
    if (
        signals["projection_state_d_and_c"]
        and signals["live_bid_or_ask"]
        and signals["strategy_close_call"]
        and signals["projection_state_assigned_outside_manager"]
    ):
        return "UNANCHORED_SIGNAL_PROJECTION_TARGETS", signals
    return "OTHER_MANAGEMENT_NO_EXACT_SIGNATURE", signals


def build_audit(repo_root: Path, *, terms: Iterable[str] = DEFAULT_TERMS) -> dict[str, Any]:
    repo_root = repo_root.resolve()
    eas_root = repo_root / "framework" / "EAs"
    if not eas_root.is_dir():
        raise FileNotFoundError(f"EA directory not found: {eas_root}")

    terms_tuple = tuple(dict.fromkeys(term.casefold() for term in terms))
    all_ea_dirs = sorted(
        path for path in eas_root.iterdir() if path.is_dir() and EA_DIR_RE.match(path.name)
    )
    rows: list[dict[str, Any]] = []
    fingerprint_rows: list[str] = []
    for ea_dir in all_ea_dirs:
        match = EA_DIR_RE.match(ea_dir.name)
        assert match is not None
        slug = match.group(2)
        matches = _matched_terms(slug, terms_tuple)
        if not matches:
            continue
        sources = sorted(ea_dir.glob("*.mq5"), key=lambda path: path.name.casefold())
        disposition, signals = _classify_sources(sources)
        source_rows = []
        for source in sources:
            relative = source.relative_to(repo_root).as_posix()
            source_sha = sha256_file(source)
            source_rows.append({"path": relative, "sha256": source_sha})
            fingerprint_rows.append(f"{relative}\0{source_sha}\n")
        rows.append(
            {
                "ea": ea_dir.name,
                "ea_id": f"QM5_{match.group(1)}",
                "slug": slug,
                "matched_terms": matches,
                "disposition": disposition,
                "signals": signals,
                "sources": source_rows,
            }
        )

    dispositions = Counter(row["disposition"] for row in rows)
    return {
        "schema": SCHEMA,
        "selection": {
            "root": "framework/EAs",
            "directory_rule": "QM5_<numeric-id>_<slug>",
            "matching_field": "slug_only",
            "match_rule": "case-insensitive substring of any declared term",
            "terms": list(terms_tuple),
        },
        "method": {
            "source_scope": "top-level *.mq5 in each selected EA directory",
            "lexical_mask": "comments and string/character literals removed before analysis",
            "exact_defect_rule": (
                "Strategy_ManageOpenPosition references g_position_D and g_position_C, "
                "reads live bid/ask, invokes a strategy close helper, and does not "
                "reference POSITION_PRICE_OPEN"
            ),
            "claim_boundary": (
                "dispositions describe source shape for this exact defect only; "
                "they are not pipeline or strategy verdicts"
            ),
        },
        "counts": {
            "ea_directories_scanned": len(all_ea_dirs),
            "cohort_directories": len(rows),
            "source_bearing_cohort_directories": sum(bool(row["sources"]) for row in rows),
            "source_files_examined": sum(len(row["sources"]) for row in rows),
            "dispositions": dict(sorted(dispositions.items())),
        },
        "selected_source_fingerprint_sha256": sha256_bytes(
            "".join(sorted(fingerprint_rows)).encode("utf-8")
        ),
        "eas": rows,
    }


def render_audit(audit: dict[str, Any]) -> bytes:
    return (json.dumps(audit, indent=2, sort_keys=True) + "\n").encode("utf-8")


def _default_repo_root() -> Path:
    return Path(__file__).resolve().parents[2]


def main() -> int:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--repo-root", type=Path, default=_default_repo_root())
    parser.add_argument("--output", type=Path)
    parser.add_argument(
        "--check",
        action="store_true",
        help="fail unless --output already equals a fresh deterministic render",
    )
    args = parser.parse_args()
    if args.check and args.output is None:
        parser.error("--check requires --output")

    rendered = render_audit(build_audit(args.repo_root))
    if args.output is None:
        print(rendered.decode("utf-8"), end="")
        return 0

    output = args.output.resolve()
    if args.check:
        if not output.is_file() or output.read_bytes() != rendered:
            print(f"STALE: {output}")
            return 1
        print(f"PASS: {output} ({sha256_bytes(rendered)})")
        return 0

    output.parent.mkdir(parents=True, exist_ok=True)
    output.write_bytes(rendered)
    print(f"WROTE: {output} ({sha256_bytes(rendered)})")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
