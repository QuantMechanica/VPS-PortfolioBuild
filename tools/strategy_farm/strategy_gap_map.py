#!/usr/bin/env python3
"""Build a read-only strategy-development gap map from internal evidence.

The map joins a Q15 Shadow BookLab reference roster, OWNER-approved Strategy
Cards, the active EA registry, and the version-aware pipeline frontier.  It
prioritizes research whitespace and existing-card visibility only; it never
creates/approves a Strategy Card, changes a queue, or alters a book.
"""
from __future__ import annotations

import argparse
import csv
import dataclasses
import datetime as dt
import hashlib
import json
import math
import re
import sys
from collections import Counter, defaultdict
from pathlib import Path
from typing import Any, Iterable, Mapping

import yaml

if __package__ in (None, ""):
    sys.path.insert(0, str(Path(__file__).resolve().parents[2]))

from tools.strategy_farm import gate_manifest, path_to_25  # noqa: E402
from tools.strategy_farm.portfolio import concentration_tail  # noqa: E402


SCHEMA = "qm.strategy-gap-map/v1"
DEFAULT_DB = Path(r"D:\QM\strategy_farm\state\farm_state.sqlite")
DEFAULT_CARDS = Path(r"D:\QM\strategy_farm\artifacts\cards_approved")
DEFAULT_BOOKLAB = Path(
    r"D:\QM\strategy_farm\reports\shadow_research\2026-08-24_q15_shadow_booklab.json"
)
DEFAULT_REGISTRY = Path(__file__).resolve().parents[2] / "framework" / "registry" / "ea_id_registry.csv"

ASSET_UNIVERSE = ("fx", "indices", "metals", "energy")
TIMEFRAME_UNIVERSE = ("M5", "M15", "M30", "H1", "H4", "D1")
ARCHETYPE_UNIVERSE = (
    "relative_value",
    "event_driven",
    "carry",
    "seasonal_calendar",
    "volatility",
    "trend_following",
    "breakout_momentum",
    "mean_reversion_reversal",
    "other",
)
FEASIBLE_ARCHETYPES_BY_ASSET = {
    "fx": frozenset(ARCHETYPE_UNIVERSE),
    "indices": frozenset({
        "relative_value", "event_driven", "seasonal_calendar", "volatility",
        "trend_following", "breakout_momentum", "mean_reversion_reversal", "other",
    }),
    "metals": frozenset({
        "relative_value", "event_driven", "seasonal_calendar", "volatility",
        "trend_following", "breakout_momentum", "mean_reversion_reversal", "other",
    }),
    "energy": frozenset({
        "relative_value", "event_driven", "seasonal_calendar", "volatility",
        "trend_following", "breakout_momentum", "mean_reversion_reversal", "other",
    }),
}
_EA_RE = re.compile(r"QM5_(\d+)", re.IGNORECASE)
_FRONTMATTER_RE = re.compile(r"\A---\s*\r?\n(.*?)\r?\n---\s*(?:\r?\n|\Z)", re.DOTALL)


class GapMapError(ValueError):
    """A required read-only evidence source is invalid or ambiguous."""


@dataclasses.dataclass(frozen=True)
class Card:
    path: str
    sha256: str
    ea_id: str
    ea_id_int: int
    slug: str
    timeframe: str
    symbols: tuple[str, ...]
    assets: tuple[str, ...]
    concepts: tuple[str, ...]
    archetype: str


def _utc_now() -> str:
    return dt.datetime.now(dt.timezone.utc).isoformat()


def _sha256(path: Path) -> str:
    digest = hashlib.sha256()
    with path.open("rb") as handle:
        for chunk in iter(lambda: handle.read(1024 * 1024), b""):
            digest.update(chunk)
    return digest.hexdigest()


def _load_json(path: str | Path) -> tuple[dict[str, Any], dict[str, Any]]:
    resolved = Path(path).resolve()
    payload = json.loads(resolved.read_text(encoding="utf-8-sig"))
    if not isinstance(payload, dict):
        raise GapMapError(f"JSON root is not an object: {resolved}")
    return payload, {
        "path": str(resolved),
        "sha256": _sha256(resolved),
        "size_bytes": resolved.stat().st_size,
    }


def _normalize_symbol(value: Any) -> str:
    token = str(value or "").strip().upper()
    if token and "." not in token and not token.startswith("QM5_"):
        token += ".DWX"
    return token


def _normalize_timeframe(value: Any) -> str:
    token = str(value or "").strip().upper()
    match = re.search(r"\b(M(?:5|15|30)|H(?:1|4)|D1)\b", token)
    return match.group(1) if match else (token or "UNKNOWN")


def _concept_token(value: Any) -> str:
    token = str(value or "").lower()
    token = token.replace("[[concepts/", "").replace("]]", "")
    return re.sub(r"[^a-z0-9]+", "-", token).strip("-")


def classify_archetype(slug: str, concepts: Iterable[str] = ()) -> str:
    """Transparent keyword classifier used for research routing, never gates."""
    text = " ".join([str(slug).lower(), *(_concept_token(row) for row in concepts)])
    rules = (
        (
            "relative_value",
            (
                "cointeg", "stat-arb", "pairs", "pair-", "spread", "ratio",
                "relative-value", "arbitrage",
            ),
        ),
        ("event_driven", ("fomc", "eia", "news", "event", "earnings", "inventory", "storage")),
        ("carry", ("carry", "swap", "roll-yield", "forward-premium")),
        (
            "seasonal_calendar",
            (
                "season", "calendar", "turn-of", "day-of", "month", "weekday",
                "holiday", "overnight", "gotobi", "nakane", "mon-ls",
            ),
        ),
        ("volatility", ("volatility", "vol-", "straddle", "strangle", "squeeze", "variance")),
        (
            "trend_following",
            (
                "trend", "tsmom", "time-series-momentum", "moving-average",
                "donchian", "turtle", "ichimoku",
            ),
        ),
        (
            "breakout_momentum",
            (
                "breakout", "momentum", "range-break", "channel-break",
                "opening-range", "mom12", "-mom",
            ),
        ),
        (
            "mean_reversion_reversal",
            (
                "mean-reversion", "reversal", "reverse", "fade", "pullback",
                "oversold", "overbought", "revert", "rsi2", "-pb", "overshoot",
            ),
        ),
    )
    for archetype, keywords in rules:
        if any(keyword in text for keyword in keywords):
            return archetype
    return "other"


def _frontmatter(path: Path) -> dict[str, Any]:
    text = path.read_text(encoding="utf-8-sig")
    match = _FRONTMATTER_RE.match(text)
    if match is None:
        raise GapMapError("YAML frontmatter missing")
    block = match.group(1)
    try:
        payload = yaml.safe_load(block)
    except yaml.YAMLError as exc:
        # Historical cards occasionally place an unescaped Windows path in an
        # unrelated double-quoted source_citation.  Recover only the flat fields
        # used by this research inventory; do not claim full YAML validity.
        mark = getattr(exc, "problem_mark", None)
        source_lines = block.splitlines()
        error_line = (
            source_lines[mark.line]
            if mark is not None and 0 <= mark.line < len(source_lines)
            else ""
        )
        if re.match(r"^source_citation\s*:", error_line) is None:
            raise GapMapError(
                "YAML is invalid outside the recoverable source_citation field"
            ) from exc
        payload = {}
        current_list: str | None = None
        supported = {
            "ea_id", "slug", "g0_status", "period", "timeframe",
            "target_symbols", "concepts",
        }
        for raw_line in block.splitlines():
            line = raw_line.rstrip()
            key_match = re.match(r"^([A-Za-z0-9_]+):\s*(.*)$", line)
            if key_match:
                key, raw_value = key_match.groups()
                current_list = None
                if key not in supported:
                    continue
                value = raw_value.strip()
                if not value and key in {"target_symbols", "concepts"}:
                    payload[key] = []
                    current_list = key
                elif value.startswith("[") and value.endswith("]"):
                    payload[key] = [
                        token.strip().strip("'\"")
                        for token in value[1:-1].split(",") if token.strip()
                    ]
                else:
                    payload[key] = value.strip("'\"")
                continue
            list_match = re.match(r"^\s+-\s+(.*)$", line)
            if list_match and current_list:
                payload[current_list].append(list_match.group(1).strip().strip("'\""))
        payload["__gap_parser_mode__"] = "RELEVANT_FLAT_FIELDS_FALLBACK"
    if not isinstance(payload, dict):
        raise GapMapError("YAML frontmatter is not an object")
    payload.setdefault("__gap_parser_mode__", "FULL_YAML")
    return payload


def _list_values(value: Any) -> list[str]:
    if isinstance(value, (list, tuple)):
        return [str(row).strip() for row in value if str(row).strip()]
    if value in (None, ""):
        return []
    return [str(value).strip()]


def load_cards(
    cards_dir: str | Path,
    asset_by_symbol: Mapping[str, str],
) -> tuple[list[Card], dict[str, Any]]:
    root = Path(cards_dir).resolve()
    cards: list[Card] = []
    errors: list[dict[str, str]] = []
    skipped = Counter()
    parser_modes = Counter()
    inventory_rows: list[tuple[str, str]] = []
    for path in sorted(root.glob("*.md"), key=lambda item: item.name.lower()):
        sha = _sha256(path)
        inventory_rows.append((path.name, sha))
        try:
            frontmatter = _frontmatter(path)
        except (OSError, UnicodeError, yaml.YAMLError, GapMapError) as exc:
            skipped["frontmatter_unusable"] += 1
            if len(errors) < 25:
                errors.append({"path": str(path), "reason": f"{type(exc).__name__}: {exc}"})
            continue
        parser_modes[str(frontmatter.pop("__gap_parser_mode__", "UNKNOWN"))] += 1
        if str(frontmatter.get("g0_status") or "").strip().upper() != "APPROVED":
            skipped["not_g0_approved"] += 1
            continue
        ea_id = str(frontmatter.get("ea_id") or "").strip().upper()
        match = _EA_RE.fullmatch(ea_id)
        slug = str(frontmatter.get("slug") or "").strip().lower()
        if match is None or not slug:
            skipped["identity_missing"] += 1
            continue
        symbols = tuple(sorted({
            normalized for value in _list_values(frontmatter.get("target_symbols"))
            if (normalized := _normalize_symbol(value))
        }))
        concepts = tuple(_list_values(frontmatter.get("concepts")))
        assets = tuple(sorted({
            asset_by_symbol.get(symbol, "unknown") for symbol in symbols
        }))
        cards.append(Card(
            path=str(path),
            sha256=sha,
            ea_id=ea_id,
            ea_id_int=int(match.group(1)),
            slug=slug,
            timeframe=_normalize_timeframe(frontmatter.get("period") or frontmatter.get("timeframe")),
            symbols=symbols,
            assets=assets,
            concepts=concepts,
            archetype=classify_archetype(slug, concepts),
        ))
    inventory_sha = hashlib.sha256(
        (json.dumps(inventory_rows, separators=(",", ":")) + "\n").encode("utf-8")
    ).hexdigest()
    return cards, {
        "root": str(root),
        "markdown_files": len(inventory_rows),
        "approved_cards_parsed": len(cards),
        "skipped": dict(sorted(skipped.items())),
        "parser_modes": dict(sorted(parser_modes.items())),
        "sample_errors": errors,
        "inventory_sha256": inventory_sha,
    }


def _registry(path: str | Path) -> tuple[dict[int, str], dict[str, Any]]:
    resolved = Path(path).resolve()
    slugs: dict[int, str] = {}
    active = 0
    with resolved.open("r", encoding="utf-8-sig", newline="") as handle:
        for row in csv.DictReader(handle):
            if str(row.get("status") or "").strip().lower() != "active":
                continue
            try:
                ea_id = int(row["ea_id"])
            except (KeyError, TypeError, ValueError):
                continue
            slug = str(row.get("slug") or "").strip().lower()
            if slug:
                slugs[ea_id] = slug
                active += 1
    return slugs, {
        "path": str(resolved),
        "sha256": _sha256(resolved),
        "active_rows": active,
    }


def _pipeline_frontiers(db_path: str | Path) -> tuple[dict[int, dict[str, Any]], dict[str, Any]]:
    manifest = gate_manifest.load_gate_manifest()
    terminal_ordinal = next(
        gate.ordinal for gate in manifest.gates
        if gate.id == manifest.terminal_requalification_gate
    )
    gates = tuple(
        gate.id for gate in manifest.gates if 2 <= gate.ordinal <= terminal_ordinal
    )
    rank = {gate: index for index, gate in enumerate(gates)}
    connection = path_to_25._open_ro(db_path)
    try:
        query_only = int(connection.execute("PRAGMA query_only").fetchone()[0])
        pairs = path_to_25._pair_summaries_fast(connection, gates)
        by_ea: dict[int, dict[str, Any]] = {}
        for row in pairs:
            match = _EA_RE.search(str(row.get("ea_id") or ""))
            if match is None:
                continue
            ea_id = int(match.group(1))
            current = by_ea.setdefault(ea_id, {
                "pair_count": 0,
                "highest_frontier": "",
                "highest_frontier_rank": -1,
                "pairs_at_or_beyond_q07": 0,
                "pairs_at_or_beyond_q10": 0,
                "terminal_pairs": 0,
            })
            current["pair_count"] += 1
            frontier = str(row.get("highest_contiguous_valid_gate") or "")
            frontier_rank = rank.get(frontier, -1)
            if frontier_rank > current["highest_frontier_rank"]:
                current["highest_frontier"] = frontier
                current["highest_frontier_rank"] = frontier_rank
            if frontier_rank >= rank.get("Q07", 10**9):
                current["pairs_at_or_beyond_q07"] += 1
            if frontier_rank >= rank.get("Q10", 10**9):
                current["pairs_at_or_beyond_q10"] += 1
            if frontier == manifest.terminal_requalification_gate:
                current["terminal_pairs"] += 1
        return by_ea, {
            "path": str(Path(db_path).resolve()),
            "sqlite_uri_mode": "ro",
            "query_only": query_only,
            "observer_total_changes": connection.total_changes,
            "pairs_observed": len(pairs),
            "eas_observed": len(by_ea),
            "candidate_gates": list(gates),
            "manifest_sha256": manifest.sha256,
        }
    finally:
        connection.close()


def _book_records(
    booklab: Mapping[str, Any],
    registry_slugs: Mapping[int, str],
) -> list[dict[str, Any]]:
    classifications = (booklab.get("classification") or {}).get("rows") or []
    weights = {
        str(row.get("sleeve")): float(row.get("weight") or 0.0)
        for row in (((booklab.get("research_counterfactuals") or {})
                     .get("train_inverse_volatility") or {})
                    .get("concentration") or {}).get("weights", [])
    }
    records = []
    for row in classifications:
        try:
            ea_id = int(row.get("ea_id_int"))
        except (TypeError, ValueError):
            match = _EA_RE.search(str(row.get("ea_id") or ""))
            if match is None:
                continue
            ea_id = int(match.group(1))
        slug = registry_slugs.get(ea_id, str(row.get("family") or ""))
        records.append({
            "sleeve": str(row.get("sleeve")),
            "ea_id": ea_id,
            "slug": slug,
            "symbol": str(row.get("symbol") or "unknown"),
            "asset_class": str(row.get("asset_class") or "unknown"),
            "timeframe": _normalize_timeframe(row.get("timeframe")),
            "family": str(row.get("family") or f"ea_{ea_id}"),
            "archetype": classify_archetype(slug),
            "shadow_invvol_weight": weights.get(str(row.get("sleeve")), 0.0),
        })
    return records


def _coverage_state(book_count: int) -> str:
    if book_count == 0:
        return "ABSENT"
    if book_count == 1:
        return "THIN"
    return "PRESENT"


def _gap_score(
    book_count: int,
    book_weight: float,
    approved_supply: int,
    advanced_supply: int,
    near_supply: int,
) -> int:
    score = 40 if book_count == 0 else (20 if book_count == 1 else 0)
    if book_weight < 0.02:
        score += 10
    if approved_supply == 0:
        score += 25
    elif advanced_supply == 0:
        score += 15
    if near_supply == 0:
        score += 10
    return min(100, score)


def _dimension_rows(
    dimension: str,
    values: Iterable[str],
    book: list[dict[str, Any]],
    cards: list[Card],
    frontiers: Mapping[int, Mapping[str, Any]],
) -> list[dict[str, Any]]:
    rows = []
    for value in values:
        book_rows = [row for row in book if row.get(dimension) == value]
        if dimension == "asset_class":
            card_rows = [card for card in cards if value in card.assets]
        else:
            card_rows = [card for card in cards if getattr(card, dimension) == value]
        advanced = [
            card for card in card_rows
            if int((frontiers.get(card.ea_id_int) or {}).get("pairs_at_or_beyond_q07") or 0) > 0
        ]
        near = [
            card for card in card_rows
            if int((frontiers.get(card.ea_id_int) or {}).get("pairs_at_or_beyond_q10") or 0) > 0
        ]
        weight = sum(float(row["shadow_invvol_weight"]) for row in book_rows)
        rows.append({
            "dimension": dimension,
            "key": value,
            "coverage_state": _coverage_state(len(book_rows)),
            "reference_roster_sleeves": len(book_rows),
            "shadow_invvol_weight_share": round(weight, 10),
            "approved_card_supply": len(card_rows),
            "approved_supply_at_or_beyond_q07": len(advanced),
            "approved_supply_at_or_beyond_q10": len(near),
            "gap_priority_score": _gap_score(
                len(book_rows), weight, len(card_rows), len(advanced), len(near)
            ),
        })
    return sorted(rows, key=lambda row: (-row["gap_priority_score"], row["key"]))


def _combo_whitespace(
    book: list[dict[str, Any]],
    cards: list[Card],
    frontiers: Mapping[int, Mapping[str, Any]],
) -> list[dict[str, Any]]:
    rows = []
    for asset in ASSET_UNIVERSE:
        for archetype in ARCHETYPE_UNIVERSE:
            if archetype not in FEASIBLE_ARCHETYPES_BY_ASSET[asset]:
                continue
            book_rows = [
                row for row in book
                if row["asset_class"] == asset and row["archetype"] == archetype
            ]
            card_rows = [
                card for card in cards
                if asset in card.assets and card.archetype == archetype
            ]
            advanced = [
                card for card in card_rows
                if int((frontiers.get(card.ea_id_int) or {}).get("pairs_at_or_beyond_q07") or 0) > 0
            ]
            near = [
                card for card in card_rows
                if int((frontiers.get(card.ea_id_int) or {}).get("pairs_at_or_beyond_q10") or 0) > 0
            ]
            weight = sum(float(row["shadow_invvol_weight"]) for row in book_rows)
            score = _gap_score(
                len(book_rows), weight, len(card_rows), len(advanced), len(near)
            )
            if len(book_rows) == 0:
                if not card_rows:
                    route = "RESEARCH_OWNER_APPROVED_SOURCES"
                elif not advanced:
                    route = "EXISTING_APPROVED_SUPPLY_NOT_YET_ADVANCED"
                else:
                    route = "WATCH_EXISTING_ADVANCED_SUPPLY"
                rows.append({
                    "asset_class": asset,
                    "archetype": archetype,
                    "reference_roster_sleeves": 0,
                    "approved_card_supply": len(card_rows),
                    "advanced_supply_q07_plus": len(advanced),
                    "near_supply_q10_plus": len(near),
                    "gap_priority_score": score,
                    "research_route": route,
                    "sample_approved_cards": [
                        {"ea_id": card.ea_id, "slug": card.slug, "path": card.path}
                        for card in sorted(card_rows, key=lambda item: item.ea_id_int)[:5]
                    ],
                })
    return sorted(
        rows,
        key=lambda row: (
            -row["gap_priority_score"],
            row["approved_card_supply"],
            row["asset_class"],
            row["archetype"],
        ),
    )


def _card_visibility(
    cards: list[Card],
    frontiers: Mapping[int, Mapping[str, Any]],
    asset_gap: Mapping[str, int],
    archetype_gap: Mapping[str, int],
    timeframe_gap: Mapping[str, int],
) -> list[dict[str, Any]]:
    rows = []
    for card in cards:
        frontier = dict(frontiers.get(card.ea_id_int) or {})
        component_scores = [archetype_gap.get(card.archetype, 0), timeframe_gap.get(card.timeframe, 0)]
        component_scores.extend(asset_gap.get(asset, 0) for asset in card.assets)
        gap_score = max(component_scores or [0])
        raw_frontier_rank = frontier.get("highest_frontier_rank")
        frontier_rank = -1 if raw_frontier_rank is None else int(raw_frontier_rank)
        rows.append({
            "ea_id": card.ea_id,
            "slug": card.slug,
            "path": card.path,
            "archetype": card.archetype,
            "assets": list(card.assets),
            "timeframe": card.timeframe,
            "highest_contiguous_frontier": frontier.get("highest_frontier") or "UNBUILT_OR_UNOBSERVED",
            "pipeline_pairs": int(frontier.get("pair_count") or 0),
            "pairs_at_or_beyond_q07": int(frontier.get("pairs_at_or_beyond_q07") or 0),
            "pairs_at_or_beyond_q10": int(frontier.get("pairs_at_or_beyond_q10") or 0),
            "terminal_pairs": int(frontier.get("terminal_pairs") or 0),
            "gap_relevance_score": gap_score,
            "visibility_score": gap_score + max(0, frontier_rank) * 2,
            "action_authority": "VISIBILITY_ONLY_NO_QUEUE_CHANGE",
        })
    return sorted(
        rows,
        key=lambda row: (-row["visibility_score"], -row["gap_relevance_score"], row["ea_id"]),
    )[:30]


def build_gap_map(
    *,
    booklab_path: str | Path = DEFAULT_BOOKLAB,
    db_path: str | Path = DEFAULT_DB,
    cards_dir: str | Path = DEFAULT_CARDS,
    registry_path: str | Path = DEFAULT_REGISTRY,
) -> dict[str, Any]:
    booklab, booklab_binding = _load_json(booklab_path)
    if booklab.get("schema") != "qm.q15-shadow-booklab/v1":
        raise GapMapError("input is not a Q15 Shadow BookLab report")
    registry_slugs, registry_binding = _registry(registry_path)
    asset_by_symbol, symbol_binding = concentration_tail.load_asset_classes()
    cards, card_inventory = load_cards(cards_dir, asset_by_symbol)
    frontiers, db_evidence = _pipeline_frontiers(db_path)
    book = _book_records(booklab, registry_slugs)
    if not book:
        raise GapMapError("BookLab report contains no reference sleeves")

    asset_rows = _dimension_rows(
        "asset_class", ASSET_UNIVERSE, book, cards, frontiers
    )
    archetype_rows = _dimension_rows(
        "archetype", ARCHETYPE_UNIVERSE, book, cards, frontiers
    )
    timeframe_rows = _dimension_rows(
        "timeframe", TIMEFRAME_UNIVERSE, book, cards, frontiers
    )
    gap_maps = {
        "asset_class": {row["key"]: row["gap_priority_score"] for row in asset_rows},
        "archetype": {row["key"]: row["gap_priority_score"] for row in archetype_rows},
        "timeframe": {row["key"]: row["gap_priority_score"] for row in timeframe_rows},
    }
    whitespace = _combo_whitespace(book, cards, frontiers)
    actionable_whitespace = [
        row for row in whitespace if row["approved_card_supply"] > 0
    ]
    actionable_whitespace.sort(key=lambda row: (
        -int(row["near_supply_q10_plus"] > 0),
        -int(row["advanced_supply_q07_plus"] > 0),
        -row["gap_priority_score"],
        -row["approved_card_supply"],
        row["asset_class"], row["archetype"],
    ))
    new_source_whitespace = [
        row for row in whitespace if row["approved_card_supply"] == 0
    ]
    focus = (
        "ADVANCE_AND_DIAGNOSE_EXISTING_APPROVED_SUPPLY"
        if not new_source_whitespace
        else "OWNER_REVIEW_NEW_SOURCE_WHITESPACE"
    )
    return {
        "schema": SCHEMA,
        "generated_at_utc": _utc_now(),
        "mode": "READ_ONLY_RESEARCH_PRIORITIZATION",
        "status": "READY",
        "strategy_cards_created_by_run": 0,
        "strategy_cards_approved_by_run": 0,
        "queue_rows_changed": 0,
        "book_or_live_action": "NONE",
        "authority": {
            "new_source_intake": "OWNER_APPROVAL_REQUIRED",
            "strategy_card_g0": "OWNER_APPROVAL_REQUIRED",
            "queue_priority": "UNCHANGED",
        },
        "sources": {
            "booklab": booklab_binding,
            "reference_roster_sleeves": len(book),
            "cards": card_inventory,
            "registry": registry_binding,
            "symbol_matrix": symbol_binding,
            "pipeline": db_evidence,
        },
        "method": {
            "book_basis": "23-sleeve SHA-bound BookLab reference roster, not a new book",
            "style_classifier": "ordered transparent keyword rules over card concepts/slug",
            "advanced_supply": "at least one pair highest-contiguous-valid >= Q07",
            "near_supply": "at least one pair highest-contiguous-valid >= Q10",
            "gap_score": (
                "shadow heuristic: absent=40, thin=20, weight<2%=10, no approved supply=25 "
                "or no advanced supply=15, no near supply=10; cap 100"
            ),
            "score_is_gate_or_queue_priority": False,
        },
        "reference_roster": book,
        "dimension_gaps": {
            "asset_class": asset_rows,
            "archetype": archetype_rows,
            "timeframe": timeframe_rows,
        },
        "top_whitespace": actionable_whitespace[:20],
        "new_source_whitespace": new_source_whitespace[:20],
        "diagnosis": {
            "feasible_absent_roster_cells": len(whitespace),
            "cells_with_existing_approved_supply": len(actionable_whitespace),
            "cells_without_approved_supply": len(new_source_whitespace),
            "cells_with_q10_plus_supply": sum(
                row["near_supply_q10_plus"] > 0 for row in whitespace
            ),
            "recommended_focus": focus,
            "recommendation_is_queue_or_card_action": False,
        },
        "existing_card_visibility": _card_visibility(
            cards,
            frontiers,
            gap_maps["asset_class"],
            gap_maps["archetype"],
            gap_maps["timeframe"],
        ),
        "concentration_context": {
            "inverse_vol_group_exposure": (
                (((booklab.get("research_counterfactuals") or {})
                  .get("train_inverse_volatility") or {})
                 .get("group_exposure") or {})
            ),
            "worst_15_stress_pairs": (
                ((booklab.get("correlation") or {}).get("worst_15_stress_pairs") or [])
            ),
        },
        "limitations": [
            "Reference-roster coverage is not a target allocation and does not define binding caps.",
            "Keyword archetypes are research labels; Strategy Card mechanics remain authoritative.",
            "Approved-card counts do not prove build capacity or economic merit.",
            "No external source was searched and no new source/card was authorized by this run.",
        ],
    }


def render_markdown(report: Mapping[str, Any]) -> str:
    lines = [
        "# Strategy Gap Map — Shadow Research",
        "",
        f"Reference roster: {report['sources']['reference_roster_sleeves']} sleeves · "
        f"approved cards parsed: {report['sources']['cards']['approved_cards_parsed']} · "
        f"pipeline EAs observed: {report['sources']['pipeline']['eas_observed']}.",
        "",
        f"Diagnosis: **{report['diagnosis']['recommended_focus']}** "
        f"({report['diagnosis']['cells_with_existing_approved_supply']} absent-roster "
        "cells already have approved supply; "
        f"{report['diagnosis']['cells_without_approved_supply']} do not).",
        "",
        "## Highest-dimensional gaps",
        "",
        "| Dimension | Key | Score | Roster | Approved | Q07+ | Q10+ |",
        "|---|---|---:|---:|---:|---:|---:|",
    ]
    dimension_rows = [
        row
        for rows in report["dimension_gaps"].values()
        for row in rows
    ]
    for row in sorted(
        dimension_rows, key=lambda item: (-item["gap_priority_score"], item["dimension"], item["key"])
    )[:15]:
        lines.append(
            f"| {row['dimension']} | {row['key']} | {row['gap_priority_score']} | "
            f"{row['reference_roster_sleeves']} | {row['approved_card_supply']} | "
            f"{row['approved_supply_at_or_beyond_q07']} | {row['approved_supply_at_or_beyond_q10']} |"
        )
    lines.extend([
        "",
        "## Top whitespace",
        "",
        "| Asset | Archetype | Score | Approved | Q07+ | Route |",
        "|---|---|---:|---:|---:|---|",
    ])
    for row in report["top_whitespace"][:12]:
        lines.append(
            f"| {row['asset_class']} | {row['archetype']} | {row['gap_priority_score']} | "
            f"{row['approved_card_supply']} | {row['advanced_supply_q07_plus']} | "
            f"{row['research_route']} |"
        )
    lines.extend([
        "",
        "## Feasible new-source whitespace",
        "",
        "| Asset | Archetype | Score | Route |",
        "|---|---|---:|---|",
    ])
    for row in report["new_source_whitespace"][:10]:
        lines.append(
            f"| {row['asset_class']} | {row['archetype']} | "
            f"{row['gap_priority_score']} | {row['research_route']} |"
        )
    lines.extend([
        "",
        "This report created no Strategy Card, approval, queue mutation, book, or live action.",
        "",
    ])
    return "\n".join(lines)


def main(argv: list[str] | None = None) -> int:
    parser = argparse.ArgumentParser(description=__doc__.split("\n", 1)[0])
    parser.add_argument("--booklab", type=Path, default=DEFAULT_BOOKLAB)
    parser.add_argument("--db", type=Path, default=DEFAULT_DB)
    parser.add_argument("--cards", type=Path, default=DEFAULT_CARDS)
    parser.add_argument("--registry", type=Path, default=DEFAULT_REGISTRY)
    parser.add_argument("--output", type=Path)
    parser.add_argument("--markdown", type=Path)
    args = parser.parse_args(argv)
    try:
        report = build_gap_map(
            booklab_path=args.booklab,
            db_path=args.db,
            cards_dir=args.cards,
            registry_path=args.registry,
        )
    except (OSError, ValueError, yaml.YAMLError, json.JSONDecodeError) as exc:
        print(f"STRATEGY_GAP_MAP_REFUSED: {type(exc).__name__}: {exc}", file=sys.stderr)
        return 2
    encoded = json.dumps(report, indent=2, sort_keys=True) + "\n"
    if args.output:
        args.output.parent.mkdir(parents=True, exist_ok=True)
        args.output.write_text(encoded, encoding="utf-8")
    if args.markdown:
        args.markdown.parent.mkdir(parents=True, exist_ok=True)
        args.markdown.write_text(render_markdown(report), encoding="utf-8")
    print(encoded, end="")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())


__all__ = [
    "Card", "GapMapError", "build_gap_map", "classify_archetype",
    "load_cards", "render_markdown",
]
