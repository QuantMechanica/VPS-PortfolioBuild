#!/usr/bin/env python3
"""DL-057 R-057-3 dedup-check helper for Research.

Before APPROVING any new Strategy Card for ea_id allocation, Research + QB
must check for duplication against:

1. `framework/registry/ea_id_registry.csv` — same `slug` or `strategy_id`
2. `framework/registry/magic_numbers.csv` — same `(ea_id, symbol_slot)`
3. Existing strategy cards below `strategy-seeds/cards/**/*.md` — same author +
   strategy mechanic + parameter family (fuzzy)

Duplicates do NOT get a new ea_id. They get linked back to the existing EA
as `_v<n>` enhancement per DL-029 / DL-033.

Usage:

  # Check a candidate slug + strategy_id BEFORE allocating ea_id
  python research_dedup_check.py check \\
      --slug williams-monday-oops \\
      --strategy-id SRC03_S02 \\
      --author "Larry Williams" \\
      --mechanic "monday-gap-down-fade"

  # List all known slugs/strategy_ids (audit)
  python research_dedup_check.py list

  # Validate the registries are internally consistent (no duplicate magics,
  # ea_id_registry vs magic_numbers vs filesystem cards alignment)
  python research_dedup_check.py audit

Exit codes:
    0  — clean (no duplicate, ea_id can be allocated)
    2  — duplicate detected (must link as _v<n> per DL-029/033, NOT new ea_id)
    3  — fuzzy match — manual review (Research + QB inspect)
    1  — runner error

Author: Board Advisor 2026-05-01.
Authority: DL-057 R-057-3 + DL-029 + DL-033.

Version 2 is fail-closed: a missing/empty/unreadable source can never produce
``CLEAN``. ``check --output`` records every checked root, row/file count, and
this tool version in JSON evidence.
"""
from __future__ import annotations

import argparse
import csv
import datetime as dt
import json
import re
import sys
from dataclasses import dataclass
from pathlib import Path
from typing import Any

REPO = Path(r"C:\QM\repo")
EA_REG = REPO / "framework" / "registry" / "ea_id_registry.csv"
MAGIC = REPO / "framework" / "registry" / "magic_numbers.csv"
CARDS_DIR = REPO / "strategy-seeds" / "cards"
DEFAULT_WIKI_VAULT = Path(r"G:\My Drive\09 Strategy Wiki")
TOOL_VERSION = "2.0.0"
EVIDENCE_SCHEMA = "qm.research-dedup-check.evidence.v2"


class DedupInputError(RuntimeError):
    """A source-integrity failure that must never degrade to CLEAN."""

    def __init__(
        self,
        code: str,
        label: str,
        checked_root: Path,
        *,
        count: int | None = None,
        detail: str = "",
    ) -> None:
        self.code = code
        self.label = label
        try:
            self.checked_root = checked_root.resolve()
        except OSError:
            self.checked_root = checked_root.absolute()
        self.count = count
        self.detail = detail
        super().__init__(
            f"{code}:{label}:{self.checked_root}" + (f":{detail}" if detail else "")
        )

    def binding(self) -> dict[str, Any]:
        return {
            "label": self.label,
            "checked_root": str(self.checked_root),
            "count": self.count,
            "status": self.code,
            "detail": self.detail or None,
        }


@dataclass
class CardSummary:
    path: Path
    source: str = "card"
    slug: str = ""
    strategy_id: str = ""
    author: str = ""
    mechanic: str = ""
    status: str = ""
    ea_id: str = ""

    def is_dup_of(self, slug: str, strategy_id: str) -> bool:
        return self.slug == slug.lower() or self.strategy_id == strategy_id.upper()


def _read_csv_strict(path: Path, label: str) -> list[dict[str, str]]:
    try:
        is_file = path.is_file()
    except OSError as exc:
        raise DedupInputError("ROOT_ACCESS_ERROR", label, path, detail=str(exc)) from exc
    if not is_file:
        raise DedupInputError("MISSING_ROOT", label, path)
    try:
        with path.open(encoding="utf-8-sig", newline="") as handle:
            reader = csv.DictReader(handle)
            if not reader.fieldnames:
                raise DedupInputError("EMPTY_SOURCE", label, path, count=0)
            rows = [dict(row) for row in reader]
    except UnicodeError as exc:
        raise DedupInputError("ENCODING_ERROR", label, path, detail=str(exc)) from exc
    except (OSError, csv.Error) as exc:
        raise DedupInputError("READ_ERROR", label, path, detail=str(exc)) from exc
    if not rows:
        raise DedupInputError("EMPTY_SOURCE", label, path, count=0)
    return rows


def read_ea_registry() -> list[dict[str, str]]:
    return _read_csv_strict(EA_REG, "ea_id_registry")


def read_magic_registry() -> list[dict[str, str]]:
    return _read_csv_strict(MAGIC, "magic_registry")


def parse_card_frontmatter(card_path: Path, *, source: str = "card") -> CardSummary:
    """Extract slug / strategy_id / author / mechanic / status / ea_id from card."""
    cs = CardSummary(path=card_path, source=source)
    try:
        is_file = card_path.is_file()
    except OSError as exc:
        raise DedupInputError(
            "ROOT_ACCESS_ERROR", f"{source}_card", card_path, detail=str(exc)
        ) from exc
    if not is_file:
        raise DedupInputError("MISSING_FILE", f"{source}_card", card_path)
    try:
        text = card_path.read_text(encoding="utf-8")
    except UnicodeError as exc:
        raise DedupInputError(
            "ENCODING_ERROR", f"{source}_card", card_path, detail=str(exc)
        ) from exc
    except OSError as exc:
        raise DedupInputError("READ_ERROR", f"{source}_card", card_path, detail=str(exc)) from exc
    # YAML frontmatter
    m = re.match(r"^---\s*\n(.+?)\n---", text, re.DOTALL)
    fm_block = m.group(1) if m else text[:1000]
    # Extract simple key: value pairs (don't bother parsing full YAML)
    for line in fm_block.splitlines():
        if ":" not in line:
            continue
        k, _, v = line.partition(":")
        k = k.strip().lower()
        v = v.strip().strip('"').strip("'")
        if k in ("slug", "name", "strategy_slug"):
            cs.slug = v.lower()
        elif k in ("strategy_id", "src_id", "id"):
            cs.strategy_id = v.upper()
        elif k in ("author", "source_author", "researcher"):
            cs.author = v
        elif k in ("mechanic", "strategy_mechanic", "type", "strategy_type"):
            cs.mechanic = v.lower()
        elif k == "status":
            cs.status = v.upper()
        elif k == "ea_id":
            cs.ea_id = v
    if not cs.slug:
        # Fallback: slug from filename
        cs.slug = card_path.stem.replace("_card", "").lower()
    return cs


def scan_cards() -> list[CardSummary]:
    try:
        is_dir = CARDS_DIR.is_dir()
    except OSError as exc:
        raise DedupInputError(
            "ROOT_ACCESS_ERROR", "strategy_cards", CARDS_DIR, detail=str(exc)
        ) from exc
    if not is_dir:
        raise DedupInputError("MISSING_ROOT", "strategy_cards", CARDS_DIR)
    try:
        paths = sorted(CARDS_DIR.rglob("*.md"))
    except OSError as exc:
        raise DedupInputError(
            "ROOT_ACCESS_ERROR", "strategy_cards", CARDS_DIR, detail=str(exc)
        ) from exc
    if not paths:
        raise DedupInputError("EMPTY_ROOT", "strategy_cards", CARDS_DIR, count=0)
    cards = []
    try:
        for path in paths:
            cards.append(parse_card_frontmatter(path))
    except DedupInputError as exc:
        raise DedupInputError(
            exc.code,
            "strategy_cards",
            CARDS_DIR,
            count=len(paths),
            detail=f"{exc.checked_root}:{exc.detail}",
        ) from exc
    return cards


def scan_wiki_strategies(vault: Path) -> list[CardSummary]:
    strategies_dir = vault / "strategies"
    try:
        is_dir = strategies_dir.is_dir()
    except OSError as exc:
        raise DedupInputError(
            "ROOT_ACCESS_ERROR", "strategy_wiki", strategies_dir, detail=str(exc)
        ) from exc
    if not is_dir:
        raise DedupInputError("MISSING_ROOT", "strategy_wiki", strategies_dir)
    try:
        paths = sorted(strategies_dir.glob("*.md"))
    except OSError as exc:
        raise DedupInputError(
            "ROOT_ACCESS_ERROR", "strategy_wiki", strategies_dir, detail=str(exc)
        ) from exc
    if not paths:
        raise DedupInputError("EMPTY_ROOT", "strategy_wiki", strategies_dir, count=0)
    strategies: list[CardSummary] = []
    try:
        for path in paths:
            strategies.append(parse_card_frontmatter(path, source="wiki"))
    except DedupInputError as exc:
        raise DedupInputError(
            exc.code,
            "strategy_wiki",
            strategies_dir,
            count=len(paths),
            detail=f"{exc.checked_root}:{exc.detail}",
        ) from exc
    return strategies


def _binding(label: str, path: Path, count: int) -> dict[str, Any]:
    return {
        "label": label,
        "checked_root": str(path.resolve()),
        "count": count,
        "status": "OK",
        "detail": None,
    }


def _write_check_evidence(args: argparse.Namespace, report: dict[str, Any]) -> None:
    output = getattr(args, "output", None)
    if output is None:
        return
    output.parent.mkdir(parents=True, exist_ok=True)
    output.write_text(json.dumps(report, indent=2, sort_keys=True) + "\n", encoding="utf-8")


def _check_report(
    args: argparse.Namespace,
    *,
    verdict: str,
    exit_code: int,
    sources: list[dict[str, Any]],
    matches: list[dict[str, Any]] | None = None,
    error: str | None = None,
) -> dict[str, Any]:
    return {
        "schema": EVIDENCE_SCHEMA,
        "tool_version": TOOL_VERSION,
        "generated_at_utc": dt.datetime.now(dt.UTC).replace(microsecond=0).isoformat(),
        "candidate": {
            "slug": args.slug,
            "strategy_id": args.strategy_id,
            "author": args.author or "",
            "mechanic": args.mechanic or "",
        },
        "verdict": verdict,
        "exit_code": exit_code,
        "sources": sources,
        "matches": matches or [],
        "error": error,
    }


def normalize_slug(slug: str) -> str:
    """Lowercase, strip non-alphanumeric, collapse hyphens/underscores to nothing."""
    return re.sub(r"[^a-z0-9]", "", slug.lower())


def fuzzy_match(a: str, b: str) -> float:
    """Crude fuzzy-match: ratio of normalized-string overlap."""
    na, nb = normalize_slug(a), normalize_slug(b)
    if not na or not nb:
        return 0.0
    if na == nb:
        return 1.0
    if na in nb or nb in na:
        return 0.85
    # token overlap — require ≥4 chars to avoid common-prefix noise like 'src'
    set_a = set(re.findall(r"[a-z]{4,}", a.lower()))
    set_b = set(re.findall(r"[a-z]{4,}", b.lower()))
    if not set_a or not set_b:
        return 0.0
    overlap = len(set_a & set_b)
    return overlap / max(len(set_a), len(set_b))


# -------------------------------------------------------------------------
# Commands
# -------------------------------------------------------------------------


def cmd_check(args: argparse.Namespace) -> int:
    slug = args.slug
    strategy_id = args.strategy_id
    author = args.author or ""
    mechanic = args.mechanic or ""

    print(f"## Dedup check — slug={slug!r}, strategy_id={strategy_id!r}")
    print(f"Tool version: {TOOL_VERSION}")
    print()

    # Load and authenticate every declared source before considering a CLEAN or
    # early duplicate verdict. A missing/empty/unreadable later source may hold
    # the decisive duplicate and therefore cannot be silently treated as zero.
    sources: list[dict[str, Any]] = []
    source_errors: list[DedupInputError] = []
    ea_rows: list[dict[str, str]] = []
    cards: list[CardSummary] = []
    wiki_cards: list[CardSummary] = []
    try:
        ea_rows = read_ea_registry()
        sources.append(_binding("ea_id_registry", EA_REG, len(ea_rows)))
    except DedupInputError as exc:
        sources.append(exc.binding())
        source_errors.append(exc)
    try:
        cards = scan_cards()
        sources.append(_binding("strategy_cards", CARDS_DIR, len(cards)))
    except DedupInputError as exc:
        sources.append(exc.binding())
        source_errors.append(exc)
    try:
        wiki_cards = scan_wiki_strategies(args.vault)
        sources.append(
            _binding("strategy_wiki", args.vault / "strategies", len(wiki_cards))
        )
    except DedupInputError as exc:
        sources.append(exc.binding())
        source_errors.append(exc)

    for binding in sources:
        print(
            "CHECKED SOURCE: "
            f"{binding['label']} root={binding['checked_root']} count={binding['count']} "
            f"status={binding['status']}"
        )
    for exc in source_errors:
        print(f"SOURCE ERROR: {exc}")
    print()

    # 1. ea_id_registry exact match
    print(f"### ea_id_registry.csv — {len(ea_rows)} rows")
    exact_ea_dup = []
    for row in ea_rows:
        if row.get("slug", "").lower() == slug.lower():
            exact_ea_dup.append(("slug", row))
        if row.get("strategy_id", "").upper() == strategy_id.upper():
            exact_ea_dup.append(("strategy_id", row))
    if exact_ea_dup:
        print(f"  EXACT DUPLICATE in ea_id_registry:")
        for field_name, row in exact_ea_dup:
            print(f"    {field_name}: ea_id={row['ea_id']}, slug={row['slug']}, strategy_id={row['strategy_id']}, owner={row.get('owner','-')}")
        print()
        print("VERDICT: DUPLICATE — link as _v<n> enhancement per DL-029/033, NOT new ea_id")
        _write_check_evidence(
            args,
            _check_report(
                args,
                verdict="DUPLICATE",
                exit_code=2,
                sources=sources,
                matches=[
                    {
                        "match_type": field_name,
                        "source": "ea_id_registry",
                        "ea_id": row.get("ea_id"),
                        "slug": row.get("slug"),
                        "strategy_id": row.get("strategy_id"),
                    }
                    for field_name, row in exact_ea_dup
                ],
                error=" | ".join(str(exc) for exc in source_errors) or None,
            ),
        )
        return 2
    print("  (no exact duplicates)")

    # 2. existing cards
    all_candidates = cards + wiki_cards
    print()
    print(f"### strategy-seeds/cards/ — {len(cards)} cards scanned")
    print(f"### 09 Strategy Wiki/strategies/ — {len(wiki_cards)} nodes scanned")
    fuzzy_hits = []
    for card in all_candidates:
        if card.is_dup_of(slug, strategy_id):
            print(f"  EXACT DUPLICATE: [{card.source}] {card.path} ({card.slug} / {card.strategy_id})")
            print()
            print("VERDICT: DUPLICATE — link as _v<n> enhancement per DL-029/033, NOT new ea_id")
            _write_check_evidence(
                args,
                _check_report(
                    args,
                    verdict="DUPLICATE",
                    exit_code=2,
                    sources=sources,
                    matches=[
                        {
                            "match_type": "exact_card",
                            "source": card.source,
                            "path": str(card.path.resolve()),
                            "slug": card.slug,
                            "strategy_id": card.strategy_id,
                            "ea_id": card.ea_id or None,
                        }
                    ],
                    error=" | ".join(str(exc) for exc in source_errors) or None,
                ),
            )
            return 2
        slug_score = fuzzy_match(slug, card.slug)
        sid_score = fuzzy_match(strategy_id, card.strategy_id)
        author_match = author and card.author and (author.lower() in card.author.lower() or card.author.lower() in author.lower())
        mechanic_score = fuzzy_match(mechanic, card.mechanic) if mechanic else 0.0
        # Composite score
        composite = max(slug_score, sid_score, mechanic_score)
        if composite >= 0.7 or (author_match and mechanic_score >= 0.5):
            fuzzy_hits.append((composite, card, slug_score, sid_score, mechanic_score, author_match))
    if fuzzy_hits:
        fuzzy_hits.sort(key=lambda x: -x[0])
        print(f"  FUZZY MATCHES ({len(fuzzy_hits)}) — manual review needed:")
        for score, card, ss, sis, ms, am in fuzzy_hits[:5]:
            print(f"    score={score:.2f}: {card.path.name}")
            print(f"      slug_match={ss:.2f}  sid_match={sis:.2f}  mech_match={ms:.2f}  author_match={am}")
            print(f"      existing slug='{card.slug}', sid='{card.strategy_id}', author='{card.author}', mech='{card.mechanic}'")
        print()
        print("VERDICT: FUZZY MATCH — Research + QB inspect; if same mechanic/parameters, link as _v<n>")
        _write_check_evidence(
            args,
            _check_report(
                args,
                verdict="FUZZY_MATCH",
                exit_code=3,
                sources=sources,
                matches=[
                    {
                        "match_type": "fuzzy",
                        "score": score,
                        "source": card.source,
                        "path": str(card.path.resolve()),
                        "slug": card.slug,
                        "strategy_id": card.strategy_id,
                    }
                    for score, card, _ss, _sis, _ms, _am in fuzzy_hits[:5]
                ],
                error=" | ".join(str(exc) for exc in source_errors) or None,
            ),
        )
        return 3
    print("  (no fuzzy matches above threshold)")

    if source_errors:
        report = _check_report(
            args,
            verdict="INPUT_ERROR_FAIL_CLOSED",
            exit_code=1,
            sources=sources,
            error=" | ".join(str(exc) for exc in source_errors),
        )
        _write_check_evidence(args, report)
        print()
        print("VERDICT: INPUT_ERROR_FAIL_CLOSED — allocation is NOT authorized")
        return 1

    print()
    print("VERDICT: CLEAN — no duplicate detected; ea_id allocation OK.")
    _write_check_evidence(
        args,
        _check_report(
            args,
            verdict="CLEAN",
            exit_code=0,
            sources=sources,
        ),
    )
    return 0


def cmd_list(args: argparse.Namespace) -> int:
    ea_rows = read_ea_registry()
    cards = scan_cards()
    wiki_cards = scan_wiki_strategies(args.vault)
    print(f"## Known slugs / strategy_ids ({len(ea_rows)} EAs, {len(cards)} cards, {len(wiki_cards)} wiki)")
    print()
    print("### From ea_id_registry.csv:")
    for row in ea_rows:
        print(f"  ea_id={row['ea_id']:5} slug={row['slug']:35} strategy_id={row['strategy_id']:12} owner={row.get('owner','-')}")
    print()
    print("### From strategy-seeds/cards/:")
    for card in cards:
        print(f"  {card.path.name:50} slug={card.slug:35} sid={card.strategy_id:12} status={card.status:10} ea_id={card.ea_id or '-'}")
    print()
    print("### From 09 Strategy Wiki/strategies/:")
    for card in wiki_cards:
        print(f"  {card.path.name:50} slug={card.slug:35} sid={card.strategy_id:12} status={card.status:10} ea_id={card.ea_id or '-'}")
    return 0


def cmd_audit(args: argparse.Namespace) -> int:
    """Cross-check ea_id_registry vs magic_numbers vs filesystem cards."""
    ea_rows = read_ea_registry()
    magic_rows = read_magic_registry()
    cards = scan_cards() + scan_wiki_strategies(args.vault)

    issues = []

    # Magic-number uniqueness
    seen_magics = {}
    for row in magic_rows:
        m = row.get("magic", "")
        if m in seen_magics:
            issues.append(f"DUPLICATE MAGIC {m}: {row} vs {seen_magics[m]}")
        seen_magics[m] = row

    # Each ea_id in ea_id_registry should have rows in magic_numbers
    for ea in ea_rows:
        ea_id = ea["ea_id"]
        magic_count = sum(1 for r in magic_rows if r.get("ea_id") == ea_id)
        if magic_count == 0:
            issues.append(f"ea_id {ea_id} ({ea['slug']}) has NO magic_numbers rows")
        elif magic_count != 36:
            issues.append(f"ea_id {ea_id} ({ea['slug']}) has {magic_count} magic_numbers rows (expected 36)")

    # Each card with ea_id should match ea_id_registry
    ea_ids = {row["ea_id"] for row in ea_rows}
    for card in cards:
        if card.ea_id and card.ea_id not in ("TBD", "-", ""):
            if card.ea_id not in ea_ids:
                issues.append(f"card {card.path.name} references ea_id={card.ea_id} not in ea_id_registry")

    # Each card slug should appear in ea_id_registry IF status=APPROVED
    for card in cards:
        if card.status == "APPROVED" and card.slug:
            slug_in_reg = any(row.get("slug", "").lower() == card.slug for row in ea_rows)
            if not slug_in_reg:
                issues.append(f"APPROVED card {card.path.name} (slug={card.slug}) has no row in ea_id_registry")

    print(f"## Audit summary: {len(issues)} issue(s)")
    for issue in issues:
        print(f"  - {issue}")
    return 0 if not issues else 2


def main(argv: list[str] | None = None) -> int:
    p = argparse.ArgumentParser(prog="research_dedup_check")
    sub = p.add_subparsers(dest="cmd", required=True)

    check = sub.add_parser("check", help="Check a candidate slug + strategy_id for duplicates")
    check.add_argument("--slug", required=True, help="candidate slug, e.g. williams-monday-oops")
    check.add_argument("--strategy-id", required=True, help="candidate strategy_id, e.g. SRC03_S02")
    check.add_argument("--author", help="card author (for fuzzy matching)")
    check.add_argument("--mechanic", help="strategy mechanic short tag (for fuzzy matching)")
    check.add_argument("--vault", type=Path, default=DEFAULT_WIKI_VAULT, help=f"Wiki vault root (default: {DEFAULT_WIKI_VAULT})")
    check.add_argument("--output", type=Path, help="write versioned JSON evidence")
    check.set_defaults(func=cmd_check)

    listp = sub.add_parser("list", help="List all known slugs/strategy_ids from registries + cards")
    listp.add_argument("--vault", type=Path, default=DEFAULT_WIKI_VAULT, help=f"Wiki vault root (default: {DEFAULT_WIKI_VAULT})")
    listp.set_defaults(func=cmd_list)

    audit = sub.add_parser("audit", help="Cross-check ea_id_registry vs magic_numbers vs cards")
    audit.add_argument("--vault", type=Path, default=DEFAULT_WIKI_VAULT, help=f"Wiki vault root (default: {DEFAULT_WIKI_VAULT})")
    audit.set_defaults(func=cmd_audit)

    args = p.parse_args(argv)
    try:
        return args.func(args)
    except DedupInputError as exc:
        print(f"SOURCE ERROR: {exc}")
        print("VERDICT: INPUT_ERROR_FAIL_CLOSED — operation is NOT authorized")
        return 1


if __name__ == "__main__":
    raise SystemExit(main())
