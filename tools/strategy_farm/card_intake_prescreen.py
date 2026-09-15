"""Deterministic, dry-run-first Strategy Card intake prescreen.

This is a cheap paper gate for drafts before an orchestrator places them in
``cards_review``.  It is deliberately not a G0 verdict and cannot approve a
card.  The default invocation is read-only.  Mutation additionally requires
both ``--apply`` and ``QM_CARD_INTAKE_PRESCREEN=1``.

The checks are intentionally limited to facts available at intake time:

* coarse slug/mechanism overlap with approved and rejected cards;
* target-symbol membership in the governed DWX matrix;
* named external-feed availability under ``D:/QM/data``;
* the six Edge Lab thesis sections; and
* the Edge Lab design box (DD, timeframe, and prohibited mechanics).

Examples::

    python tools/strategy_farm/card_intake_prescreen.py
    python tools/strategy_farm/card_intake_prescreen.py --card D:/.../card.md
    set QM_CARD_INTAKE_PRESCREEN=1
    python tools/strategy_farm/card_intake_prescreen.py --card D:/.../card.md --apply
"""

from __future__ import annotations

import argparse
import csv
import datetime as dt
import hashlib
import json
import os
import re
import shutil
import sys
from dataclasses import asdict, dataclass
from difflib import SequenceMatcher
from functools import lru_cache
from pathlib import Path
from typing import Iterable, Mapping


REPO_ROOT = Path(r"C:\QM\repo")
FARM_ARTIFACTS = Path(r"D:\QM\strategy_farm\artifacts")
DEFAULT_INPUT_ROOT = FARM_ARTIFACTS / "cards_review"
DEFAULT_APPROVED_ROOT = FARM_ARTIFACTS / "cards_approved"
DEFAULT_REJECTED_ROOT = FARM_ARTIFACTS / "cards_rejected"
DEFAULT_SYMBOL_MATRIX = REPO_ROOT / "framework" / "registry" / "dwx_symbol_matrix.csv"
DEFAULT_DATA_ROOT = Path(r"D:\QM\data")
ARM_ENV = "QM_CARD_INTAKE_PRESCREEN"
SCHEMA = "qm.card-intake-prescreen/v1"

_WORD_RE = re.compile(r"[a-z0-9]+")
_SYMBOL_RE = re.compile(r"\b[A-Z][A-Z0-9]{2,15}(?:\.DWX)?\b")
_TIMEFRAME_RE = re.compile(r"\b(M\d+|H\d+|D1|W1|MN1)\b", re.IGNORECASE)
_NEGATION_RE = re.compile(
    r"\b(?:no|not|never|without|forbid(?:s|den)?|prohibit(?:s|ed)?|does\s+not|do\s+not)\b",
    re.IGNORECASE,
)

_SLUG_NOISE = {
    "a", "an", "and", "ea", "edge", "edgelab", "ff", "for", "fx", "lab",
    "mql5", "of", "qm", "rb", "strategy", "system", "the", "trading", "v1",
    "v2", "v3", "variant",
}

_MECHANISM_PHRASES = {
    "1 2 3 reversal", "amd po3", "bollinger band", "cash open",
    "commodity momentum", "currency strength", "double 7", "dual thrust",
    "ema cross", "engulfing", "fair value gap", "fibonacci",
    "fisher transform", "gap fade", "garch", "go long", "ict ote",
    "ict silver bullet", "inside bar", "kalman", "liquidity sweep",
    "london breakout", "mean reversion", "momentum rotation", "nnfx",
    "opening range", "order block", "pairs trade", "psar", "relative momentum",
    "range breakout", "rsi 2", "safe haven", "stat arb", "stochastic pullback",
    "tdi", "turn of month", "turnaround tuesday", "vegas tunnel",
    "volume profile", "vwap", "weekly rebalance", "wolfe wave", "z score",
}

_DISTINCTIVE_MECHANISMS = _MECHANISM_PHRASES - {
    "bollinger band", "cash open", "currency strength", "ema cross",
    "fibonacci", "mean reversion", "momentum rotation", "opening range",
    "pairs trade", "safe haven", "weekly rebalance",
}

# These are external series, not DWX price symbols.  A feed counts as available
# only when at least one of its governed paths exists under the configured data
# root.  Merely mentioning a technique in a prohibition/negative sentence does
# not create a dependency.
_EXTERNAL_FEEDS: Mapping[str, tuple[re.Pattern[str], tuple[str, ...]]] = {
    "VIX": (re.compile(r"\bVIX\b", re.IGNORECASE), ("vix", "VIX")),
    "COT": (
        re.compile(r"\b(?:CFTC\s+)?COT\b|commitments?\s+of\s+traders", re.IGNORECASE),
        ("cot", "COT", "cftc", "CFTC"),
    ),
    "OPTIONS": (
        re.compile(r"\b(?:option(?:s)?|implied\s+vol(?:atility)?|straddle)\b", re.IGNORECASE),
        ("options", "OPTIONS"),
    ),
    "BOND_YIELDS": (
        re.compile(r"\b(?:bond|treasury|government)\s+yield(?:s)?\b|\byield\s+curve\b", re.IGNORECASE),
        ("bond_yields", "yields", "rates"),
    ),
    "CVD": (
        re.compile(r"\bCVD\b|cumulative\s+volume\s+delta", re.IGNORECASE),
        ("cvd", "CVD"),
    ),
    "MACRO_SURPRISE": (
        re.compile(r"\b(?:economic|macro)\s+surprise(?:\s+index)?\b|\bCitigroup\s+Economic\b", re.IGNORECASE),
        ("macro_surprise", "economic_surprise"),
    ),
    "FUNDAMENTALS": (
        re.compile(r"\b(?:EPS|earnings yield|fundamental data)\b", re.IGNORECASE),
        ("fundamentals", "fundamental"),
    ),
    "SWAP_HISTORY": (
        re.compile(r"\b(?:historical\s+swap|swap\s+history|historical\s+carry)\b", re.IGNORECASE),
        ("swap_history", "swaps"),
    ),
}


@dataclass(frozen=True)
class CardDocument:
    path: Path
    text: str
    frontmatter: dict[str, str]
    headings: tuple[str, ...]
    body: str


@dataclass(frozen=True)
class CardResult:
    path: str
    ea_id: str
    slug: str
    verdict: str
    reasons: tuple[str, ...]
    warnings: tuple[str, ...]
    duplicate_of: str | None
    target_symbols: tuple[str, ...]
    missing_feeds: tuple[str, ...]
    missing_sections: tuple[str, ...]
    expected_dd_pct: float | None
    timeframe: str | None
    action: str


@dataclass(frozen=True)
class ReferenceSignature:
    document: CardDocument
    slug: str
    slug_tokens: frozenset[str]
    mechanism_terms: frozenset[str]


@dataclass(frozen=True)
class ReferenceIndex:
    signatures: tuple[ReferenceSignature, ...]
    by_slug_token: Mapping[str, tuple[int, ...]]
    by_mechanism: Mapping[str, tuple[int, ...]]
    by_prefix: Mapping[str, tuple[int, ...]]


def _sha256(path: Path) -> str:
    digest = hashlib.sha256()
    with path.open("rb") as handle:
        for chunk in iter(lambda: handle.read(1024 * 1024), b""):
            digest.update(chunk)
    return digest.hexdigest()


def _parse_frontmatter(text: str) -> tuple[dict[str, str], str]:
    normalized = text.replace("\r\n", "\n").lstrip("\ufeff")
    if not normalized.startswith("---\n"):
        return {}, normalized
    end = normalized.find("\n---", 4)
    if end < 0:
        return {}, normalized
    raw = normalized[4:end]
    fields: dict[str, str] = {}
    current: str | None = None
    for line in raw.splitlines():
        match = re.match(r"^([A-Za-z0-9_-]+)\s*:\s*(.*?)\s*$", line)
        if match:
            current = match.group(1).lower()
            fields[current] = match.group(2).strip().strip("'\"")
            continue
        item = re.match(r"^\s*-\s*(.*?)\s*$", line)
        if item and current:
            value = item.group(1).strip().strip("'\"")
            fields[current] = ",".join(part for part in (fields[current], value) if part)
    return fields, normalized[end + 4 :].lstrip("\n")


def load_card(path: Path) -> CardDocument:
    text = path.read_text(encoding="utf-8", errors="replace")
    frontmatter, body = _parse_frontmatter(text)
    headings = tuple(
        match.group(1).strip().lower()
        for match in re.finditer(r"(?m)^#{1,4}\s+(.+?)\s*$", body)
    )
    return CardDocument(path=path, text=text, frontmatter=frontmatter, headings=headings, body=body)


def _slug(document: CardDocument) -> str:
    explicit = document.frontmatter.get("slug", "").strip().lower()
    if explicit:
        return explicit
    stem = re.sub(r"^(?:PENDING_[A-F0-9]+|QM5_\d+)_", "", document.path.stem, flags=re.I)
    return stem.lower()


def _ea_id(document: CardDocument) -> str:
    return document.frontmatter.get("ea_id", "").strip() or document.path.stem.split("_", 1)[0]


def _tokens(value: str) -> set[str]:
    return {
        token for token in _WORD_RE.findall(value.lower())
        if len(token) > 1 and token not in _SLUG_NOISE and not token.isdigit()
    }


@lru_cache(maxsize=4096)
def _mechanism_terms_from_text(slug: str, body: str) -> frozenset[str]:
    compact = re.sub(r"[-_/]+", " ", f"{slug}\n{body.lower()}")
    terms = {phrase for phrase in _MECHANISM_PHRASES if phrase in compact}
    # Indicator/numeric combinations give a little more identity without using
    # generic words such as "entry", "risk", or "trend" as duplicate proof.
    for pattern in (
        r"\b(?:ema|sma|rsi|atr|cci|adx|stochastic|bollinger)\s*\(?\s*\d{1,3}\b",
        r"\b\d{1,3}\s*(?:day|bar|period)\s+(?:high|low|return|range)\b",
        r"\b(?:daily|weekly|monthly)\s+(?:rebalance|rotation|breakout)\b",
    ):
        terms.update(match.group(0).strip() for match in re.finditer(pattern, compact))
    return frozenset(terms)


def _mechanism_terms(document: CardDocument) -> frozenset[str]:
    return _mechanism_terms_from_text(_slug(document), document.body)


def _build_reference_index(references: Iterable[CardDocument]) -> ReferenceIndex:
    signatures: list[ReferenceSignature] = []
    token_index: dict[str, list[int]] = {}
    mechanism_index: dict[str, list[int]] = {}
    prefix_index: dict[str, list[int]] = {}
    for document in references:
        slug = _slug(document)
        signature = ReferenceSignature(
            document=document,
            slug=slug,
            slug_tokens=frozenset(_tokens(slug)),
            mechanism_terms=_mechanism_terms(document),
        )
        index = len(signatures)
        signatures.append(signature)
        for token in signature.slug_tokens:
            token_index.setdefault(token, []).append(index)
        for term in signature.mechanism_terms:
            mechanism_index.setdefault(term, []).append(index)
        prefix_index.setdefault(slug[:8], []).append(index)
    return ReferenceIndex(
        signatures=tuple(signatures),
        by_slug_token={key: tuple(value) for key, value in token_index.items()},
        by_mechanism={key: tuple(value) for key, value in mechanism_index.items()},
        by_prefix={key: tuple(value) for key, value in prefix_index.items()},
    )


def _duplicate_match(candidate: CardDocument, references: ReferenceIndex) -> tuple[str | None, float]:
    slug = _slug(candidate)
    slug_tokens = _tokens(slug)
    mechanism = _mechanism_terms(candidate)
    candidate_ea = _ea_id(candidate).upper()
    parent = candidate.frontmatter.get("parent_ea_id", "").strip().upper()
    declared_variant = bool(parent) and any(
        phrase in candidate.body.lower()
        for phrase in ("sole carrier change", "variant", "delta", "differs from", "distinct from")
    )
    best_path: str | None = None
    best_score = 0.0
    candidate_indexes: set[int] = set(references.by_prefix.get(slug[:8], ()))
    for token in slug_tokens:
        candidate_indexes.update(references.by_slug_token.get(token, ()))
    for term in mechanism:
        candidate_indexes.update(references.by_mechanism.get(term, ()))
    for index in candidate_indexes:
        signature = references.signatures[index]
        reference = signature.document
        # Callers normalize candidate paths and reference roots are absolute;
        # avoid filesystem-resolving every archive path for every comparison.
        if reference.path == candidate.path:
            continue
        reference_ea = _ea_id(reference).upper()
        if candidate_ea and reference_ea == candidate_ea:
            continue
        if declared_variant and reference_ea == parent:
            continue
        other_slug = signature.slug
        other_tokens = signature.slug_tokens
        other_mechanism = signature.mechanism_terms
        shared_slug = slug_tokens & other_tokens
        shared_mechanism = mechanism & other_mechanism
        union = slug_tokens | other_tokens
        jaccard = len(shared_slug) / len(union) if union else 0.0
        sequence = SequenceMatcher(None, slug, other_slug).ratio()
        mechanism_overlap = (
            len(shared_mechanism) / min(len(mechanism), len(other_mechanism))
            if mechanism and other_mechanism else 0.0
        )
        lexical_score = max(sequence if sequence >= 0.84 else 0.0, jaccard)
        strong_mechanism = (
            bool(shared_mechanism & _DISTINCTIVE_MECHANISMS)
            or (len(shared_mechanism) >= 3 and mechanism_overlap >= 0.8)
        )
        if lexical_score < 0.9 and not strong_mechanism:
            continue
        score = max(lexical_score, mechanism_overlap if strong_mechanism else 0.0)
        if score > best_score:
            best_score = score
            best_path = str(reference.path)
    return (best_path, round(best_score, 4)) if best_path else (None, 0.0)


def load_symbol_matrix(path: Path) -> set[str]:
    with path.open("r", encoding="utf-8-sig", newline="") as handle:
        return {
            str(row.get("symbol") or "").strip().upper()
            for row in csv.DictReader(handle)
            if str(row.get("symbol") or "").strip()
        }


def _split_scalar_list(value: str) -> list[str]:
    return [part.strip().strip("'\"") for part in re.split(r"[,\[\]]+", value) if part.strip()]


def target_symbols(document: CardDocument) -> tuple[str, ...]:
    values: list[str] = []
    for key in ("target_symbols", "symbols", "market_universe"):
        if document.frontmatter.get(key):
            values.extend(_split_scalar_list(document.frontmatter[key]))
            break
    if not values and document.frontmatter.get("symbol"):
        values.append(document.frontmatter["symbol"])
    symbols = []
    for value in values:
        match = _SYMBOL_RE.fullmatch(value.upper())
        if match:
            symbols.append(match.group(0))
    return tuple(sorted(set(symbols)))


def _line_is_negated(line: str, match: re.Match[str]) -> bool:
    prefix = line[: match.start()]
    prefix = re.split(r"[.;]", prefix)[-1][-180:]
    return bool(_NEGATION_RE.search(prefix))


def missing_external_feeds(document: CardDocument, data_root: Path) -> tuple[str, ...]:
    missing: list[str] = []
    for name, (pattern, relative_paths) in _EXTERNAL_FEEDS.items():
        required = False
        for line in document.text.splitlines():
            match = pattern.search(line)
            if match and not _line_is_negated(line, match):
                required = True
                break
        if required and not any((data_root / rel).exists() for rel in relative_paths):
            missing.append(name)
    return tuple(sorted(missing))


def _heading_has(document: CardDocument, *needles: str) -> bool:
    return any(any(needle in heading for needle in needles) for heading in document.headings)


def missing_charter_sections(document: CardDocument) -> tuple[str, ...]:
    lower = re.sub(r"\s+", " ", document.body.lower())
    missing: list[str] = []
    structural = _heading_has(document, "structural cause", "hypothesis", "thesis", "edge hypothesis")
    structural = structural and bool(
        re.search(
            r"\b(?:because|due to|flow|inventory|auction|rebalance|liquidity|risk premium|behavio|forced|institutional|microstructure|carry)\w*\b",
            lower,
        )
    )
    if not structural:
        missing.append("STRUCTURAL_CAUSE")

    price_signature = _heading_has(
        document, "price signature", "entry", "rules", "mechanic", "signal", "source-defined rules"
    ) and bool(re.search(r"\b(?:enter|buy|sell|break|cross|close|return|rank|gap|price)\w*\b", lower))
    if not price_signature:
        missing.append("PRICE_SIGNATURE")

    persistence = _heading_has(document, "persistence", "why this variant", "thesis", "hypothesis")
    persistence = persistence and bool(
        re.search(
            r"\b(?:persist|capacity|arbitrage|institutional|forced|inventory|rebalance|liquidity|crowd|slow|constraint|risk premium|flow)\w*\b",
            lower,
        )
    )
    if not persistence:
        missing.append("PERSISTENCE")

    if not _heading_has(document, "falsification", "falsifier", "kill criteria", "requalification"):
        missing.append("FALSIFICATION")
    if not _heading_has(document, "q08", "q11", "crisis", "news risk"):
        missing.append("Q08_Q11_RISK")

    ftmo_heading = _heading_has(document, "ftmo", "risk and ftmo", "risk")
    ftmo_terms = all(
        re.search(pattern, lower)
        for pattern in (
            r"(?:5\s*%|five\s+percent).{0,35}(?:daily|day)|(?:daily|day).{0,35}(?:5\s*%|five\s+percent)",
            r"(?:10\s*%|ten\s+percent).{0,35}(?:total|drawdown)|(?:total|drawdown).{0,35}(?:10\s*%|ten\s+percent)",
            r"news.{0,30}blackout|blackout.{0,30}news",
            r"\b(?:m5|m15|h1|h4|d1|swing|scalp)\b",
        )
    )
    if not ftmo_heading or not ftmo_terms:
        missing.append("FTMO_FIT")
    return tuple(missing)


def _expected_dd(document: CardDocument) -> float | None:
    raw = document.frontmatter.get("expected_dd_pct", "").strip()
    if not raw:
        return None
    try:
        return float(raw.rstrip("%"))
    except ValueError:
        return None


def _timeframe(document: CardDocument) -> str | None:
    raw = document.frontmatter.get("timeframe", "").strip().upper()
    if raw:
        match = _TIMEFRAME_RE.search(raw)
        return match.group(1).upper() if match else raw
    for line in document.body.splitlines():
        if "timeframe" not in line.lower() and "signal" not in line.lower():
            continue
        match = _TIMEFRAME_RE.search(line)
        if match:
            return match.group(1).upper()
    return None


def _timeframe_allowed(value: str | None) -> bool:
    if not value:
        return False
    if value == "D1":
        return True
    match = re.fullmatch(r"([MH])(\d+)", value)
    if not match:
        return False
    amount = int(match.group(2))
    return 5 <= amount <= 15 if match.group(1) == "M" else 1 <= amount <= 24


def _affirmative_prohibited_mechanics(document: CardDocument) -> tuple[str, ...]:
    findings: set[str] = set()
    r4 = document.frontmatter.get("r4_ml_forbidden", "").strip().lower()
    ml_required = document.frontmatter.get("ml_required", "").strip().lower()
    if r4 in {"false", "fail", "no"} or ml_required in {"true", "yes", "1"}:
        findings.add("ML")
    patterns = {
        "ML": re.compile(
            r"\b(?:machine learning|random forest|neural network|xgboost|lstm|hidden markov|viterbi)\b",
            re.I,
        ),
        "HFT": re.compile(r"\b(?:hft|sub[- ]?second|\d+[- ]second tick|tick scalping|latency arbitrage)\b", re.I),
        "GRID": re.compile(r"\bgrid(?:ding)?\b", re.I),
        "MARTINGALE": re.compile(r"\bmartingale\b", re.I),
        "AVERAGING_INTO_LOSERS": re.compile(r"\b(?:averag(?:e|ing) (?:down|into (?:a )?los)|add(?:ing)? to losers)\b", re.I),
    }
    # Markdown prose is commonly hard-wrapped after a comma. Join lowercase
    # continuation lines so "No HFT, ML, grid,\nmartingale ..." remains one
    # negative clause rather than turning the second physical line affirmative.
    scan_text = re.sub(r"(?<!\n)\n(?=[a-z])", " ", document.text)
    for line in scan_text.splitlines():
        for name, pattern in patterns.items():
            match = pattern.search(line)
            if match and not _line_is_negated(line, match):
                findings.add(name)
    return tuple(sorted(findings))


def evaluate_card(
    document: CardDocument,
    *,
    symbols: set[str],
    data_root: Path,
    references: ReferenceIndex,
) -> CardResult:
    reasons: list[str] = []
    warnings: list[str] = []
    duplicate_of, duplicate_score = _duplicate_match(document, references)
    if duplicate_of:
        duplicate_finding = (
            f"NEAR_DUPLICATE:{Path(duplicate_of).name}:score={duplicate_score:.4f}"
        )
        differentiation = any(
            phrase in document.body.lower()
            for phrase in (
                "dedup", "duplicate fingerprint", "different from", "differs from", "distinct from",
                "evidence-based delta", "sole carrier change",
            )
        )
        (warnings if differentiation else reasons).append(duplicate_finding)

    targets = target_symbols(document)
    if not targets:
        reasons.append("TARGET_SYMBOLS_MISSING")
    else:
        invalid = sorted(set(targets) - symbols)
        if invalid:
            reasons.append("TARGET_SYMBOL_NOT_IN_DWX_MATRIX:" + ",".join(invalid))

    feeds = missing_external_feeds(document, data_root)
    if feeds:
        reasons.append("EXTERNAL_DATA_FEED_MISSING:" + ",".join(feeds))

    sections = missing_charter_sections(document)
    if sections:
        reasons.append("CHARTER_SECTIONS_MISSING:" + ",".join(sections))

    dd = _expected_dd(document)
    if dd is None:
        reasons.append("EXPECTED_DD_PCT_MISSING")
    elif dd <= 0 or dd > 10:
        reasons.append(f"EXPECTED_DD_PCT_OUTSIDE_BOX:{dd:g}")

    timeframe = _timeframe(document)
    if not _timeframe_allowed(timeframe):
        reasons.append(f"TIMEFRAME_OUTSIDE_BOX:{timeframe or 'MISSING'}")

    prohibited = _affirmative_prohibited_mechanics(document)
    if prohibited:
        reasons.append("PROHIBITED_MECHANICS:" + ",".join(prohibited))

    return CardResult(
        path=str(document.path),
        ea_id=_ea_id(document),
        slug=_slug(document),
        verdict="REJECT" if reasons else "KEEP",
        reasons=tuple(reasons),
        warnings=tuple(warnings),
        duplicate_of=duplicate_of,
        target_symbols=targets,
        missing_feeds=feeds,
        missing_sections=sections,
        expected_dd_pct=dd,
        timeframe=timeframe,
        action="DRY_RUN",
    )


def _load_reference_cards(roots: Iterable[Path]) -> list[CardDocument]:
    cards: list[CardDocument] = []
    for root in roots:
        if not root.is_dir():
            continue
        for path in sorted(root.glob("*.md")):
            try:
                cards.append(load_card(path))
            except OSError:
                continue
    return cards


def _annotate_and_reject(result: CardResult, rejected_root: Path) -> CardResult:
    source = Path(result.path)
    if source.parent.name not in {"cards_draft", "cards_review"}:
        raise ValueError(f"apply refused outside cards_draft/cards_review: {source}")
    rejected_root.mkdir(parents=True, exist_ok=True)
    destination = rejected_root / source.name
    text = source.read_text(encoding="utf-8", errors="strict")
    reason = " | ".join(result.reasons).replace('"', "'")
    annotation = (
        f"prescreen_schema: {SCHEMA}\n"
        "prescreen_status: REJECTED\n"
        f'prescreen_reason: "{reason}"\n'
    )
    if text.startswith("---\n"):
        text = "---\n" + annotation + text[4:]
    else:
        text = f"---\n{annotation}---\n\n{text}"
    if destination.exists():
        if destination.read_text(encoding="utf-8", errors="strict") != text:
            raise FileExistsError(f"rejected destination exists with different bytes: {destination}")
        source.unlink()
        action = f"REUSED_REJECTED:{destination}"
    else:
        staging = source.with_name(source.name + ".prescreen.tmp")
        staging.write_text(text, encoding="utf-8", newline="\n")
        shutil.move(str(staging), str(destination))
        source.unlink()
        action = f"MOVED_TO_REJECTED:{destination}"
    return CardResult(**{**asdict(result), "action": action})


def _resolve_cards(card_args: list[Path], input_root: Path) -> list[Path]:
    if card_args:
        return sorted({path.resolve() for path in card_args})
    if not input_root.is_dir():
        return []
    return sorted(path.resolve() for path in input_root.glob("*.md") if path.is_file())


def run_prescreen(
    card_paths: Iterable[Path],
    *,
    symbol_matrix: Path,
    data_root: Path,
    approved_root: Path,
    rejected_root: Path,
    apply: bool = False,
) -> dict:
    symbols = load_symbol_matrix(symbol_matrix)
    references = _build_reference_index(_load_reference_cards((approved_root, rejected_root)))
    results: list[CardResult] = []
    for path in card_paths:
        document = load_card(path)
        result = evaluate_card(
            document, symbols=symbols, data_root=data_root, references=references
        )
        if apply and result.verdict == "REJECT":
            result = _annotate_and_reject(result, rejected_root)
        results.append(result)
    return {
        "schema": SCHEMA,
        "mode": "APPLY" if apply else "DRY_RUN",
        "armed": os.environ.get(ARM_ENV, "").strip() == "1",
        "summary": {
            "cards": len(results),
            "keep": sum(result.verdict == "KEEP" for result in results),
            "reject": sum(result.verdict == "REJECT" for result in results),
            "mutated": sum(result.action != "DRY_RUN" for result in results),
        },
        "results": [asdict(result) for result in results],
    }


def _triage_class(row: Mapping[str, object]) -> str | None:
    reason = str(row.get("reason") or "").lower()
    if row.get("duplicate_of") or "duplicate" in reason or "overlaps existing" in reason:
        return "DUPLICATE"
    if any(token in reason for token in ("hft", "sub-second", "tick execution", "random forest", "machine learning", "hidden markov", "viterbi", " ml ")):
        return "HFT_OR_ML"
    if any(token in reason for token in ("no data feed", "feed exists", "unavailable", "unsourceable", "options", "yield", "cot", "vix", "cvd", "economic surprise", "fundamental data", "historical swap")):
        return "FEED"
    if any(token in reason for token in ("not in dwx", "no dwx", "no symbol", "outside universe", "symbols")):
        return "SYMBOL"
    return None


def _class_detected(expected_class: str, result: CardResult) -> bool:
    prefixes = {
        "DUPLICATE": ("NEAR_DUPLICATE:",),
        "SYMBOL": ("TARGET_SYMBOLS_MISSING", "TARGET_SYMBOL_NOT_IN_DWX_MATRIX:"),
        "FEED": ("EXTERNAL_DATA_FEED_MISSING:",),
        "HFT_OR_ML": ("PROHIBITED_MECHANICS:", "TIMEFRAME_OUTSIDE_BOX:M1"),
    }[expected_class]
    findings = (*result.reasons, *result.warnings)
    return any(finding.startswith(prefixes) for finding in findings)


def triage_recall(
    triage_path: Path,
    *,
    symbol_matrix: Path,
    data_root: Path,
    approved_root: Path,
    rejected_root: Path,
) -> dict:
    payload = json.loads(triage_path.read_text(encoding="utf-8"))
    rows = [
        row for row in payload.get("cards", [])
        if row.get("verdict") == "REJECT" and _triage_class(row)
    ]
    references = _build_reference_index(_load_reference_cards((approved_root, rejected_root)))
    symbols = load_symbol_matrix(symbol_matrix)
    details: list[dict] = []
    caught = 0
    for row in rows:
        original = Path(str(row.get("file") or ""))
        candidates = [original, rejected_root / original.name, approved_root / original.name]
        located = next((path for path in candidates if path.is_file()), None)
        if located is None:
            details.append({"file": original.name, "class": _triage_class(row), "status": "MISSING"})
            continue
        result = evaluate_card(load_card(located), symbols=symbols, data_root=data_root, references=references)
        expected_class = str(_triage_class(row))
        detected = _class_detected(expected_class, result)
        caught += int(detected)
        details.append(
            {
                "file": original.name,
                "class": expected_class,
                "status": "CAUGHT" if detected else "MISSED",
                "reasons": list(result.reasons),
            }
        )
    located_count = sum(detail["status"] != "MISSING" for detail in details)
    return {
        "triage_path": str(triage_path),
        "target_rows": len(rows),
        "located_rows": located_count,
        "caught_rows": caught,
        "recall_pct": round(100.0 * caught / located_count, 2) if located_count else None,
        "details": details,
    }


def build_parser() -> argparse.ArgumentParser:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--card", action="append", type=Path, default=[])
    parser.add_argument("--input-root", type=Path, default=DEFAULT_INPUT_ROOT)
    parser.add_argument("--approved-root", type=Path, default=DEFAULT_APPROVED_ROOT)
    parser.add_argument("--rejected-root", type=Path, default=DEFAULT_REJECTED_ROOT)
    parser.add_argument("--symbol-matrix", type=Path, default=DEFAULT_SYMBOL_MATRIX)
    parser.add_argument("--data-root", type=Path, default=DEFAULT_DATA_ROOT)
    parser.add_argument("--triage-evidence", type=Path)
    parser.add_argument("--report", type=Path, help="Optional JSON report; stdout is always emitted")
    parser.add_argument(
        "--apply",
        action="store_true",
        help=f"Move rejected drafts after annotation; also requires {ARM_ENV}=1",
    )
    return parser


def main(argv: list[str] | None = None) -> int:
    args = build_parser().parse_args(argv)
    armed = os.environ.get(ARM_ENV, "").strip() == "1"
    if args.apply and not armed:
        print(
            json.dumps(
                {
                    "schema": SCHEMA,
                    "ok": False,
                    "reason": f"apply_refused:{ARM_ENV}_not_1",
                },
                sort_keys=True,
            )
        )
        return 2
    paths = _resolve_cards(args.card, args.input_root)
    result = run_prescreen(
        paths,
        symbol_matrix=args.symbol_matrix,
        data_root=args.data_root,
        approved_root=args.approved_root,
        rejected_root=args.rejected_root,
        apply=args.apply,
    )
    result["generated_at"] = dt.datetime.now(dt.timezone.utc).isoformat()
    result["input_root"] = str(args.input_root)
    result["symbol_matrix_sha256"] = _sha256(args.symbol_matrix)
    if args.triage_evidence:
        result["triage_recall"] = triage_recall(
            args.triage_evidence,
            symbol_matrix=args.symbol_matrix,
            data_root=args.data_root,
            approved_root=args.approved_root,
            rejected_root=args.rejected_root,
        )
    rendered = json.dumps(result, ensure_ascii=False, indent=2, sort_keys=True) + "\n"
    if args.report:
        args.report.parent.mkdir(parents=True, exist_ok=True)
        args.report.write_text(rendered, encoding="utf-8", newline="\n")
    print(rendered, end="")
    return 0


if __name__ == "__main__":
    sys.exit(main())
