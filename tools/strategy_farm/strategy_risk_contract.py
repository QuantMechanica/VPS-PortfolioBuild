"""Deterministic Strategy Risk Contract (v1) helpers — Strategy Eligibility V2.

Style-agnostic strategy admission (OWNER-DEC-D3-20260915, directive 3 sections
14-21; verbatim at
``docs/ops/evidence/2026-09-15_continuous_book_evolution/owner_directive_3_max_factory_utilization_verbatim.md``):
a strategy STYLE is never a rejection reason on its own.  Uncontrolled ruin risk
is.  A *tail-amplifying* mechanism (martingale, grid, negative pyramiding,
recovery, unbounded multi-position) must expose a deterministic, bounded
``strategy_risk_contract.v1`` (schema at
``tools/strategy_farm/config/strategy_risk_contract.v1.json``).

This module is intentionally runtime-disconnected and stdlib-only.  It does not
open the farm database, change a verdict, size a book, or authorize a live
weight.  It provides the single source of truth for:

* the controlled ``mechanism_flags`` vocabulary and which flags are
  tail-amplifying (require a risk contract);
* deterministic detection of affirmative, non-negated tail-amplifying mechanism
  mentions in a card body (a fail-closed safety net so a card cannot smuggle a
  tail-amplifying mechanism in prose without declaring it); and
* structural validation of a risk-contract object plus the ``is_unbounded``
  ruin check (infinite levels or no equity stop).

The Machine Learning boundary (Hard Rule 14) is unchanged and is NOT handled
here — runtime-ML remains a separate, always-on rejection in
``card_intake_prescreen`` (directive section 15).
"""

from __future__ import annotations

import re
from typing import Any, Iterable, Mapping


CONTRACT_SCHEMA = "qm.strategy-risk-contract/v1"
SUPERSEDING_DECISION = "OWNER-DEC-D3-20260915"

# Controlled mechanism_flags vocabulary (lower_snake_case). Positive and negative
# pyramiding are DISTINCT mechanisms and are never collapsed into a generic
# "pyramiding" label (directive section 21).
MECHANISM_FLAGS: frozenset[str] = frozenset(
    {
        # execution / horizon styles (never tail-amplifying by themselves)
        "scalping",
        "hft",
        "trailing_stop",
        "break_even",
        "partial_exit",
        "time_exit",
        "session",
        "pattern_filter",
        "price_action_filter",
        "volatility_filter",
        "regime_filter",
        "portfolio_hedge",
        "hedging",
        "basket",
        "multi_position",
        "positive_pyramiding",
        "anti_martingale",
        # tail-amplifying mechanisms (require a bounded risk contract)
        "martingale",
        "grid",
        "bounded_grid",
        "negative_pyramiding",
        "recovery",
        "bounded_recovery",
        "unbounded_multi_position",
    }
)

# Flags that require a deterministic, bounded risk contract at intake
# (directive section 18). "bounded" grid / recovery still qualify: the contract
# is precisely where "bounded" is substantiated (finite max_levels + a real
# account-loss bound). Positive pyramiding and anti-martingale REDUCE adverse
# exposure and are NOT in this set.
TAIL_AMPLIFYING_FLAGS: frozenset[str] = frozenset(
    {
        "martingale",
        "grid",
        "bounded_grid",
        "negative_pyramiding",
        "recovery",
        "bounded_recovery",
        "unbounded_multi_position",
    }
)

_EXPLICIT_NON_VALUES = {
    "",
    "none",
    "null",
    "n/a",
    "na",
    "not_applicable",
    "not applicable",
    "not_evaluated",
    "not evaluated",
    "unknown",
    "evidence_missing",
    "evidence missing",
}

# Affirmative-mention detection. Each entry maps a canonical flag to an ordered
# list of regexes; the FIRST matching, non-negated occurrence wins for that flag.
# Order matters: more specific phrases (anti-martingale, bounded grid) are tried
# before the generic term so a reverse mechanism is not mislabelled tail-amplifying.
_NEGATION_RE = re.compile(
    r"\b(?:no|not|never|without|forbid(?:s|den)?|prohibit(?:s|ed)?|avoid(?:s|ed)?|"
    r"does\s+not|do\s+not|disallow(?:s|ed)?)\b",
    re.IGNORECASE,
)

_ANTI_MARTINGALE_RE = re.compile(r"\b(?:anti[-\s]?martingale|reverse[-\s]?martingale)\b", re.I)
_MARTINGALE_RE = re.compile(r"\bmartingale\b", re.I)
_BOUNDED_GRID_RE = re.compile(r"\bbounded[-\s]?grid(?:ding)?\b", re.I)
_GRID_RE = re.compile(r"\bgrid(?:ding)?\b", re.I)
_NEGATIVE_PYRAMID_RE = re.compile(
    r"\b(?:negative[-\s]?pyramid\w*|averag(?:e|es|ing)\s+(?:down|into\s+(?:a\s+)?los\w*)|"
    r"add(?:s|ing)?\s+to\s+(?:a\s+)?los\w+|scal(?:e|es|ing)\s+into\s+(?:a\s+)?los\w+)\b",
    re.I,
)
_POSITIVE_PYRAMID_RE = re.compile(
    r"\b(?:positive[-\s]?pyramid\w*|pyramid\w*\s+into\s+winners?|"
    r"add(?:s|ing)?\s+to\s+winners?|scal(?:e|es|ing)\s+into\s+winners?)\b",
    re.I,
)
_BOUNDED_RECOVERY_RE = re.compile(r"\bbounded[-\s]?recovery\b", re.I)
_RECOVERY_RE = re.compile(
    r"\b(?:recovery\s+(?:mode|multiplier|lot|sequence|grid|martingale|zone|basket)|"
    r"loss\s+recovery|martingale\s+recovery)\b",
    re.I,
)
_UNBOUNDED_MULTI_RE = re.compile(
    r"\b(?:unbounded\s+(?:multi[-\s]?position|positions)|unlimited\s+(?:open\s+)?positions|"
    r"no\s+(?:cap|limit)\s+on\s+(?:open\s+)?positions|unbounded\s+basket)\b",
    re.I,
)

# (flag, regex, exclude_regex_or_None). exclude means: skip this generic pattern
# when the more-specific exclude pattern matches the same line.
_FLAG_PATTERNS: tuple[tuple[str, re.Pattern[str], re.Pattern[str] | None], ...] = (
    ("anti_martingale", _ANTI_MARTINGALE_RE, None),
    ("martingale", _MARTINGALE_RE, _ANTI_MARTINGALE_RE),
    ("bounded_grid", _BOUNDED_GRID_RE, None),
    ("grid", _GRID_RE, _BOUNDED_GRID_RE),
    ("negative_pyramiding", _NEGATIVE_PYRAMID_RE, None),
    ("positive_pyramiding", _POSITIVE_PYRAMID_RE, None),
    ("bounded_recovery", _BOUNDED_RECOVERY_RE, None),
    ("recovery", _RECOVERY_RE, _BOUNDED_RECOVERY_RE),
    ("unbounded_multi_position", _UNBOUNDED_MULTI_RE, None),
)


def _line_is_negated(line: str, match: re.Match[str]) -> bool:
    prefix = line[: match.start()]
    prefix = re.split(r"[.;]", prefix)[-1][-180:]
    return bool(_NEGATION_RE.search(prefix))


def normalize_flags(values: Iterable[str]) -> tuple[list[str], list[str]]:
    """Return ``(valid_sorted_unique, unknown_sorted_unique)`` flag tokens."""
    valid: set[str] = set()
    unknown: set[str] = set()
    for raw in values:
        token = str(raw).strip().lower().replace("-", "_").replace(" ", "_")
        if not token:
            continue
        if token in MECHANISM_FLAGS:
            valid.add(token)
        else:
            unknown.add(token)
    return sorted(valid), sorted(unknown)


def detect_flags_in_text(text: str) -> list[str]:
    """Detect affirmative, non-negated mechanism flags mentioned in prose.

    A fail-closed safety net for intake: a card that affirmatively describes a
    tail-amplifying mechanism in its rules is treated as declaring it, so the
    risk-contract requirement cannot be evaded by omitting the frontmatter flag.
    Negated mentions ("no martingale") never count. Generic, direction-less
    "pyramiding" is deliberately NOT matched (section 21: the two directions are
    distinct and must be declared explicitly).
    """
    if not text:
        return []
    # Join markdown continuation lines wrapped after a comma so
    # "No HFT, grid,\nmartingale ..." stays one negative clause.
    joined = re.sub(r"(?<!\n)\n(?=[a-z])", " ", text)
    found: set[str] = set()
    for flag, pattern, exclude in _FLAG_PATTERNS:
        for line in joined.splitlines():
            if exclude is not None and exclude.search(line):
                # The more-specific variant owns this line; skip the generic term
                # here (the specific flag is matched by its own pattern).
                match = pattern.search(line)
                if match and exclude.search(line[max(0, match.start() - 24): match.end() + 24]):
                    continue
            match = pattern.search(line)
            if match and not _line_is_negated(line, match):
                found.add(flag)
                break
    return sorted(found)


def tail_amplifying_flags(flags: Iterable[str]) -> list[str]:
    """Subset of ``flags`` that require a bounded risk contract."""
    return sorted({f for f in flags if f in TAIL_AMPLIFYING_FLAGS})


def _is_non_value(value: Any) -> bool:
    return isinstance(value, str) and value.strip().lower() in _EXPLICIT_NON_VALUES


def _positive_number(value: Any) -> bool:
    """True when value is a strictly-positive number (int/float or decimal string)."""
    if isinstance(value, bool) or value is None:
        return False
    if isinstance(value, (int, float)):
        return value > 0
    if isinstance(value, str):
        try:
            return float(value.strip()) > 0
        except ValueError:
            return False
    return False


def _numberish(value: Any) -> bool:
    if isinstance(value, bool):
        return False
    if isinstance(value, (int, float)):
        return True
    if isinstance(value, str):
        s = value.strip()
        if _is_non_value(value):
            return True  # explicit NOT_EVALUATED / UNKNOWN sentinel is allowed
        try:
            float(s)
            return True
        except ValueError:
            return False
    return False


def validate_contract(contract: Any) -> list[str]:
    """Return a sorted list of structural error strings; empty means valid.

    Deterministic, stdlib-only re-implementation of the shape expressed in
    ``config/strategy_risk_contract.v1.json``. A present-but-invalid contract is
    treated by callers exactly like a missing contract (fail closed).
    """
    errors: list[str] = []
    if not isinstance(contract, Mapping):
        return ["contract_not_object"]

    if contract.get("schema") != CONTRACT_SCHEMA:
        errors.append("schema_mismatch")

    if not isinstance(contract.get("tail_amplifying"), bool):
        errors.append("tail_amplifying_not_bool")

    max_levels = contract.get("max_levels")
    if isinstance(max_levels, bool) or not isinstance(max_levels, int):
        errors.append("max_levels_not_integer")
    elif max_levels < 0:
        errors.append("max_levels_negative")

    sizing = contract.get("sizing_progression")
    if not isinstance(sizing, Mapping) or sizing.get("type") not in {
        "flat",
        "linear",
        "geometric",
        "custom",
    }:
        errors.append("sizing_progression_invalid")

    mop = contract.get("max_open_positions")
    if isinstance(mop, bool) or not isinstance(mop, int) or mop < 1:
        errors.append("max_open_positions_invalid")

    if not _numberish(contract.get("max_basket_exposure")):
        errors.append("max_basket_exposure_invalid")
    if not _numberish(contract.get("max_gross_notional")):
        errors.append("max_gross_notional_invalid")

    for pct_key in ("max_margin_pct", "max_basket_loss_pct"):
        val = contract.get(pct_key)
        if _is_non_value(val):
            continue
        if isinstance(val, bool) or not isinstance(val, (int, float)) or not (0 < val <= 100):
            errors.append(f"{pct_key}_out_of_range")

    ee = contract.get("emergency_exit")
    if not isinstance(ee, Mapping):
        errors.append("emergency_exit_missing")
    else:
        if ee.get("type") not in {
            "equity_stop",
            "basket_sl",
            "account_equity_stop",
            "time_stop",
            "none",
        }:
            errors.append("emergency_exit_type_invalid")
        if not isinstance(ee.get("rule"), str) or not ee.get("rule", "").strip():
            errors.append("emergency_exit_rule_missing")

    for str_key in ("gap_sensitivity", "spread_slippage_sensitivity"):
        val = contract.get(str_key)
        if not isinstance(val, str) or not val.strip():
            errors.append(f"{str_key}_missing")

    whs = contract.get("worst_historical_sequence")
    if not isinstance(whs, Mapping) or not {
        "max_adverse_levels",
        "max_drawdown_pct",
        "evidence",
    } <= set(whs):
        errors.append("worst_historical_sequence_invalid")

    stress = contract.get("stress_sequence")
    if not isinstance(stress, Mapping) or not {"scenario", "result_pct", "evidence"} <= set(
        stress
    ):
        errors.append("stress_sequence_invalid")

    return sorted(errors)


def is_unbounded(contract: Mapping[str, Any]) -> bool:
    """True when a (structurally valid) contract declares uncontrolled ruin risk.

    Two independent ruin conditions (directive section 18):

    * infinite levels — ``levels_unbounded is True`` or ``max_levels <= 0``; and
    * no equity stop — ``emergency_exit.type`` is ``none`` (or missing) AND
      there is no positive account-loss bound (neither
      ``emergency_exit.equity_stop_pct`` nor ``max_basket_loss_pct`` is positive).
    """
    if not isinstance(contract, Mapping):
        return True

    max_levels = contract.get("max_levels")
    levels_unbounded = contract.get("levels_unbounded") is True
    if levels_unbounded:
        return True
    if not isinstance(max_levels, int) or isinstance(max_levels, bool) or max_levels <= 0:
        return True

    ee = contract.get("emergency_exit")
    ee_type = ee.get("type") if isinstance(ee, Mapping) else None
    ee_stop_pct = ee.get("equity_stop_pct") if isinstance(ee, Mapping) else None
    basket_loss_bound = contract.get("max_basket_loss_pct")
    has_loss_bound = _positive_number(ee_stop_pct) or _positive_number(basket_loss_bound)
    if ee_type in (None, "none") or not has_loss_bound:
        return True

    return False
