"""MECHANIZE gate — deterministic static validation of a mechanical spec.

No ML hypothesis may enter Q00 while it still depends on a research model
(directive sec 13). MECHANIZE converts the edge into an exact mechanical
specification; this module is the deterministic, no-LLM gate over that spec
markdown (design doc sec 4.3).

Checks (each emits a machine-readable finding):

1. All required sections present (sec 4.1 list + the six charter sections)
   -> ``MECH_SECTIONS_MISSING:<list>``
2. No ML/inference terms in the mechanics sections (the ``## Research provenance``
   narrative is exempt, keyed on the shared heading constant) -> ``MECH_ML_IN_RULES``
3. Finite parameter count; every parameter has a bounded numeric range
   -> ``MECH_PARAM_UNBOUNDED:<name>``
4. Codex-implementability checklist: entry/exit/stop/sizing/filter each resolve to a
   rule with no external model reference -> ``MECH_MODEL_DEPENDENCY``
5. No runtime data feed beyond native MT5 + the live news filter -> ``MECH_RUNTIME_FEED``
6. Numeric provenance (optional, when an artifact research.json is supplied): every
   quantitative claim resolves to a computed-output-file hash -> ``RESEARCH_NUMERIC_UNBACKED``

Result: ``{"verdict": "PASS"|"RETURN_TO_RESEARCH", "findings": [...], ...}``.
"""

from __future__ import annotations

import argparse
import json
import re
import sys
from pathlib import Path
from typing import Any

_SF = Path(__file__).resolve().parents[1]
if str(_SF) not in sys.path:
    sys.path.insert(0, str(_SF))

# Shared heading constant so the ML-scan exemption cannot drift between this gate
# and card_intake_prescreen's own ML text-scan (design doc sec 3.1, sec 7).
RESEARCH_PROVENANCE_HEADING = "research provenance"

# Reuse the prescreen negation detector when importable; else a local fallback so
# "No ML, no neural network" is not read as an affirmative ML rule.
try:  # pragma: no cover - import path exercised indirectly
    import card_intake_prescreen as _prescreen  # type: ignore

    _line_is_negated = _prescreen._line_is_negated  # type: ignore[attr-defined]
except Exception:  # pragma: no cover - fallback
    _NEGATION_RE = re.compile(
        r"\b(?:no|not|never|without|avoid|prohibit|forbid|forbidden|ban|banned|"
        r"exclude|excludes|excluding|free of|absence of)\b",
        re.I,
    )

    def _line_is_negated(line: str, match: "re.Match[str]") -> bool:
        prefix = line[: match.start()]
        prefix = re.split(r"[.;]", prefix)[-1][-180:]
        return bool(_NEGATION_RE.search(prefix))


# ML / inference vocabulary forbidden inside the *mechanics* of the spec. Kept in
# sync with card_intake_prescreen._affirmative_prohibited_mechanics' ML pattern and
# extended with the offline-instrument terms that must not leak into EA rules
# (directive sec 3: "no inference API, no model file, no online learning").
_ML_PATTERN = re.compile(
    r"\b(?:machine learning|deep learning|reinforcement learning|random forest|"
    r"neural network|gradient boost(?:ing)?|xgboost|lightgbm|catboost|lstm|gru|"
    r"transformer|hidden markov|viterbi|k-?means|dbscan|clustering|classifier|"
    r"regressor|regression model|support vector|svm|inference api|model file|"
    r"online learning|retrain(?:ing)?|predict_proba|\.predict\(|black box|"
    r"trained model|autoencoder|embedding model)\b",
    re.I,
)

# External live-feed vocabulary beyond native MT5 + the live news filter.
_RUNTIME_FEED_PATTERN = re.compile(
    r"\b(?:rest api|http[s]?://|web ?scrap|external feed|sentiment api|twitter|"
    r"reddit feed|websocket feed|third-party api|remote lookup|cloud api|"
    r"live database query)\b",
    re.I,
)

# Dangling dependency on the research artefacts (directive sec 13 implementability).
_MODEL_DEP_PATTERN = re.compile(
    r"\b(?:the (?:ml )?model|research model|the dataset|kimi lookup|lookup(?: table)? "
    r"from the (?:model|dataset)|as (?:predicted|scored) by the model|model output|"
    r"feature importance from|cluster assignment from the model)\b",
    re.I,
)

# Required sections: canonical name -> heading keyword synonyms (substring match,
# lowercased). Directive sec 13 / design doc sec 4.1 mechanical fields ...
_REQUIRED_MECHANICAL = {
    "long_entry": ("long entry", "entry (long", "buy entry", "long signal"),
    "short_entry": ("short entry", "sell entry", "short signal"),
    "no_trade": ("no-trade", "no trade", "do not trade", "flat condition"),
    "exit": ("exit",),
    "stop_loss": ("stop loss", "stop-loss", "stoploss"),
    "take_profit": ("take profit", "take-profit", "profit target"),
    "position_sizing": ("position sizing", "sizing", "risk sizing", "lot sizing"),
    "session_rules": ("session",),
    "filters": ("filter",),
    "parameter_ranges": ("parameter range", "parameters", "parameter table"),
    "indicators_data": ("indicator", "required data", "data inputs"),
    "timeframe": ("timeframe",),
    "symbols": ("symbol",),
    "expected_frequency": ("expected frequency", "trade frequency", "expected trade"),
    "invalidation": ("invalidation",),
}
# ... plus the six card charter sections (design doc sec 4.1, mapped 1:1).
_REQUIRED_CHARTER = {
    "STRUCTURAL_CAUSE": ("structural cause",),
    "PRICE_SIGNATURE": ("price signature",),
    "PERSISTENCE": ("persistence",),
    "FALSIFICATION": ("falsification", "kill criteria", "falsifier"),
    "Q08_Q11_RISK": ("q08", "q11", "crisis", "news risk"),
    "FTMO_FIT": ("ftmo",),
}

# Codex-implementability: each of these mechanical primitives must have a section.
_IMPLEMENTABILITY_PRIMITIVES = ("long_entry", "exit", "stop_loss", "position_sizing", "filters")

_HEADING_RE = re.compile(r"^\s{0,3}(#{1,6})\s+(.*?)\s*#*\s*$")
_PARAM_RANGE_RE = re.compile(
    r"(-?\d+(?:\.\d+)?)\s*(?:\.\.|-|–|to|,)\s*(-?\d+(?:\.\d+)?)"
)
_UNBOUNDED_RE = re.compile(
    r"\b(?:unbounded|unlimited|open-?ended|no limit|any value|arbitrary|free)\b", re.I
)


def _split_sections(text: str) -> list[tuple[str, str]]:
    """Return [(heading_lower, body_text), ...]; a preamble uses heading ''."""

    sections: list[tuple[str, list[str]]] = [("", [])]
    for line in text.splitlines():
        match = _HEADING_RE.match(line)
        if match:
            sections.append((match.group(2).strip().lower(), []))
        else:
            sections[-1][1].append(line)
    return [(h, "\n".join(body)) for h, body in sections]


def _headings(sections: list[tuple[str, str]]) -> list[str]:
    return [h for h, _ in sections if h]


def _section_present(headings: list[str], synonyms: tuple[str, ...]) -> bool:
    return any(any(syn in h for syn in synonyms) for h in headings)


def _mechanics_text(sections: list[tuple[str, str]]) -> str:
    """All section bodies EXCEPT the exempt Research provenance narrative."""

    parts: list[str] = []
    for heading, body in sections:
        if RESEARCH_PROVENANCE_HEADING in heading:
            continue
        parts.append(body)
    return "\n".join(parts)


def _find_section_body(sections: list[tuple[str, str]], synonyms: tuple[str, ...]) -> str | None:
    for heading, body in sections:
        if any(syn in heading for syn in synonyms):
            return body
    return None


def _scan_affirmative(pattern: re.Pattern[str], text: str) -> list[str]:
    """Return affirmative (non-negated) matches of ``pattern`` in ``text``."""

    hits: list[str] = []
    # Join hard-wrapped continuation lines so a negation clause is not split.
    scan_text = re.sub(r"(?<!\n)\n(?=[a-z])", " ", text)
    for line in scan_text.splitlines():
        for match in pattern.finditer(line):
            if not _line_is_negated(line, match):
                hits.append(match.group(0).strip())
    return hits


def _check_parameters(sections: list[tuple[str, str]]) -> tuple[list[str], int]:
    """Return (unbounded_param_names, bounded_param_count)."""

    body = _find_section_body(sections, _REQUIRED_MECHANICAL["parameter_ranges"])
    if body is None:
        return [], 0
    unbounded: list[str] = []
    bounded = 0
    for raw in body.splitlines():
        line = raw.strip().lstrip("-*").strip()
        if not line or line.startswith("|---") or set(line) <= {"|", "-", " ", ":"}:
            continue
        # A parameter line names something before a ':' or a table '|' cell.
        if ":" in line:
            name = line.split(":", 1)[0].strip()
        elif "|" in line:
            cells = [c.strip() for c in line.strip("|").split("|")]
            name = cells[0] if cells else line
            # skip a markdown table header row
            if name.lower() in {"parameter", "name", "param"}:
                continue
        else:
            continue
        if not name or name.lower() in {"parameter", "name", "param"}:
            continue
        if _UNBOUNDED_RE.search(line):
            unbounded.append(name)
        elif _PARAM_RANGE_RE.search(line):
            bounded += 1
        else:
            unbounded.append(name)
    return unbounded, bounded


def _numeric_claims_backed(artifact_research_json: Path | None) -> tuple[bool, str]:
    """Optional sec 2.4 / R-C provenance check when a research.json is supplied.

    Returns (ok, detail). We do not parse prose numbers here; instead we confirm
    the artifact declares at least one computed-output file with a sha256 whenever
    it declares any quantitative ``observations``/``candidate_edge`` metric block.
    """

    if artifact_research_json is None:
        return True, "skipped (no research.json supplied)"
    try:
        data = json.loads(Path(artifact_research_json).read_text(encoding="utf-8"))
    except (OSError, ValueError) as exc:
        return False, f"research.json unreadable: {exc}"
    computed = data.get("computed_outputs") or data.get("computed_output_hashes") or []
    has_metrics = bool(
        data.get("observations")
        or data.get("candidate_edge")
        or data.get("quantitative_claims")
    )
    if has_metrics and not computed:
        return False, "quantitative claims present but no computed-output-file hash"
    return True, "backed" if computed else "no quantitative claims"


def check_spec(
    spec_path: Path | str,
    *,
    artifact_research_json: Path | str | None = None,
) -> dict[str, Any]:
    """Run every deterministic MECHANIZE check over a spec markdown file."""

    spec_path = Path(spec_path)
    text = spec_path.read_text(encoding="utf-8")
    sections = _split_sections(text)
    headings = _headings(sections)

    findings: list[str] = []

    # 1. required sections
    missing = [
        name
        for name, syns in {**_REQUIRED_MECHANICAL, **_REQUIRED_CHARTER}.items()
        if not _section_present(headings, syns)
    ]
    if missing:
        findings.append("MECH_SECTIONS_MISSING:" + ",".join(sorted(missing)))

    mechanics = _mechanics_text(sections)

    # 2. ML terms in mechanics
    ml_hits = _scan_affirmative(_ML_PATTERN, mechanics)
    if ml_hits:
        findings.append("MECH_ML_IN_RULES:" + ",".join(sorted(set(ml_hits))))

    # 3. finite / bounded parameters
    unbounded, bounded_count = _check_parameters(sections)
    for name in unbounded:
        findings.append(f"MECH_PARAM_UNBOUNDED:{name}")

    # 4. Codex-implementability: primitives present + no dangling model reference
    missing_primitives = [
        p for p in _IMPLEMENTABILITY_PRIMITIVES if not _section_present(headings, _REQUIRED_MECHANICAL[p])
    ]
    model_dep_hits = _scan_affirmative(_MODEL_DEP_PATTERN, mechanics)
    if missing_primitives or model_dep_hits:
        detail = ",".join(sorted(set(missing_primitives) | set(model_dep_hits)))
        findings.append(f"MECH_MODEL_DEPENDENCY:{detail}")

    # 5. no external runtime feed
    feed_hits = _scan_affirmative(_RUNTIME_FEED_PATTERN, mechanics)
    if feed_hits:
        findings.append("MECH_RUNTIME_FEED:" + ",".join(sorted(set(feed_hits))))

    # 6. numeric provenance (optional)
    backed, provenance_detail = _numeric_claims_backed(
        Path(artifact_research_json) if artifact_research_json is not None else None
    )
    if not backed:
        findings.append("RESEARCH_NUMERIC_UNBACKED:" + provenance_detail)

    verdict = "PASS" if not findings else "RETURN_TO_RESEARCH"
    return {
        "schema": "qm.research-mechanization-check/v1",
        "verdict": verdict,
        "spec_path": str(spec_path),
        "findings": findings,
        "bounded_parameter_count": bounded_count,
        "sections_found": headings,
        "numeric_provenance": provenance_detail,
        "codex_implementable": not missing_primitives and not model_dep_hits,
    }


def main(argv: list[str] | None = None) -> int:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("spec", type=Path)
    parser.add_argument("--research-json", type=Path, default=None)
    args = parser.parse_args(argv)
    result = check_spec(args.spec, artifact_research_json=args.research_json)
    print(json.dumps(result, indent=2, sort_keys=True))
    return 0 if result["verdict"] == "PASS" else 6


if __name__ == "__main__":
    raise SystemExit(main())
