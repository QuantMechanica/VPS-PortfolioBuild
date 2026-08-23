"""English-heading contract for newly ingested Markdown Strategy Cards.

Historical cards are evidence and are intentionally not rewritten.  The
dashboard may translate the known legacy headings at render time, while intake
uses the same map to reject new non-English headings before they enter review.
"""

from __future__ import annotations

import html
import re
from pathlib import Path
from typing import Any


HEADING_DE_EN = {
    "quelle": "Source",
    "mechanik": "Mechanics",
    "pipeline-verlauf": "Pipeline history",
    "verwandte strategien": "Related strategies",
    "r1-r4 bewertung": "R1-R4 assessment",
    "r1–r4 bewertung": "R1-R4 assessment",
    "kriterium": "Criterion",
    "begruendung": "Rationale",
    "begründung": "Rationale",
    "status": "Status",
    "handelslogik": "Trading logic",
    "annahmen": "Assumptions",
    "einstieg": "Entry",
    "ausstieg": "Exit",
    "risiko": "Risk",
    "kosten": "Costs",
    "zusaetzliche filter": "Additional filters",
    "zusätzliche filter": "Additional filters",
    "weitere filter": "Additional filters",
    "filter": "Filters",
    "positionsgroesse": "Position sizing",
    "positionsgröße": "Position sizing",
    "positionsgrösse": "Position sizing",
    "stopp": "Stop loss",
    "handelszeiten": "Trading hours",
    "zeitfenster": "Time window",
    "signal": "Signal",
    "beschreibung": "Description",
    "umsetzung": "Implementation",
    "hinweise": "Notes",
    "lehren": "Lessons learned",
}

# These exact words are valid English headings too and therefore cannot be an
# intake language signal on their own.
_AMBIGUOUS_EXACT_KEYS = frozenset({"filter", "signal", "status"})

# Conservative single-token German signals.  Generic cross-language words are
# omitted so an unusual but valid English heading is left untouched.
_STRONG_GERMAN_TOKENS = frozenset(
    {
        "annahmen",
        "ausstieg",
        "begruendung",
        "begründung",
        "beschreibung",
        "bewertung",
        "einstieg",
        "ergebnis",
        "ergebnisse",
        "handelslogik",
        "handelszeiten",
        "hinweise",
        "kosten",
        "lehren",
        "mechanik",
        "pipeline-verlauf",
        "positionsgroesse",
        "positionsgrösse",
        "positionsgröße",
        "quelle",
        "risiko",
        "schritte",
        "stopp",
        "strategie",
        "strategien",
        "umsetzung",
        "verlauf",
        "verwandte",
        "zeitfenster",
        "zusaetzliche",
        "zusätzliche",
    }
)
_GERMAN_GRAMMAR_TOKENS = frozenset(
    {
        "als",
        "das",
        "dem",
        "den",
        "der",
        "des",
        "die",
        "eine",
        "einer",
        "fuer",
        "für",
        "ist",
        "mit",
        "oder",
        "und",
        "von",
        "was",
        "welche",
        "wie",
        "zum",
        "zur",
    }
)

_ATX_HEADING_RE = re.compile(r"^\s{0,3}#{1,6}[ \t]+(.+?)[ \t]*#*[ \t]*$")
_FENCE_RE = re.compile(r"^\s{0,3}(`{3,}|~{3,})")
_LINK_RE = re.compile(r"\[([^\]]+)\]\([^)]*\)")
_TOKEN_RE = re.compile(r"[a-zà-öø-ÿ]+(?:-[a-zà-öø-ÿ]+)*", re.IGNORECASE)
_SECTION_PREFIX_RE = re.compile(r"^\d+(?:\.\d+)*[.)]?\s+")


def _heading_text(raw: str) -> str:
    value = html.unescape(raw).strip()
    value = _LINK_RE.sub(r"\1", value)
    value = re.sub(r"[`*_~]", "", value)
    value = re.sub(r"<[^>]+>", "", value)
    value = _SECTION_PREFIX_RE.sub("", value)
    return re.sub(r"\s+", " ", value).strip(" \t:;–—")


def _heading_key(text: str) -> str:
    return re.sub(r"\s+", " ", text.strip().casefold())


def normalise_heading(text: str) -> str:
    """Translate one exact known German heading for render-time display."""

    return HEADING_DE_EN.get(_heading_key(text), text)


def check_markdown_heading_language(markdown: str) -> dict[str, Any]:
    """Find mapped or conservatively inferred German ATX section headings."""

    findings: list[dict[str, Any]] = []
    in_fence = False
    for line_number, line in enumerate(markdown.splitlines(), start=1):
        if _FENCE_RE.match(line):
            in_fence = not in_fence
            continue
        if in_fence:
            continue
        match = _ATX_HEADING_RE.match(line)
        if match is None:
            continue

        heading = _heading_text(match.group(1))
        key = _heading_key(heading)
        translation = HEADING_DE_EN.get(key)
        mapped_non_english = (
            translation is not None
            and key not in _AMBIGUOUS_EXACT_KEYS
            and translation.casefold() != key
        )

        tokens = set(_TOKEN_RE.findall(key))
        probable_unmapped = (
            not mapped_non_english
            and key not in _AMBIGUOUS_EXACT_KEYS
            and (
                any(character in key for character in "äöüß")
                or bool(tokens & _STRONG_GERMAN_TOKENS)
                or len(tokens & _GERMAN_GRAMMAR_TOKENS) >= 2
            )
        )
        if not mapped_non_english and not probable_unmapped:
            continue

        classification = (
            "mapped_non_english_heading"
            if mapped_non_english
            else "unmapped_probable_german_heading"
        )
        findings.append(
            {
                "line": line_number,
                "heading": heading,
                "classification": classification,
                "suggested_english": translation,
                "normalization_map_update_required": translation is None,
            }
        )

    return {
        "ok": not findings,
        "findings": findings,
        "unmapped_headings": [
            finding["heading"]
            for finding in findings
            if finding["normalization_map_update_required"]
        ],
    }


def check_card_heading_language(path: Path | str) -> dict[str, Any]:
    """Read one Markdown card and apply the new-card heading contract."""

    card_path = Path(path)
    try:
        text = card_path.read_text(encoding="utf-8-sig")
    except (OSError, UnicodeError) as exc:
        return {
            "ok": False,
            "findings": [],
            "unmapped_headings": [],
            "error": f"card_heading_language_unreadable:{card_path}:{exc}",
        }
    return check_markdown_heading_language(text)
