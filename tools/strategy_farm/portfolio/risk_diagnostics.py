#!/usr/bin/env python3
"""Advisory portfolio risk diagnostics (OWNER-DEC-CBE-20260915 sections 7/8).

OWNER master directive 2026-09-15 (OWNER-DEC-CBE-20260915, verbatim at
``docs/ops/evidence/2026-09-15_continuous_book_evolution/owner_directive_verbatim.md``
sections 7 and 8) supersedes the old *static* portfolio concentration caps as absolute
Hard Rules:

* maximum N EAs per family,
* maximum M EAs per symbol,
* the fixed pairwise-correlation cutoff,
* the per-dimension percent-of-budget concentration cutoffs.

Those static caps become advisory guardrails / diagnostics: a breach is emitted as a
structured WARNING (cap name, value, threshold, affected sleeves) instead of a book
refusal.  The ONLY surviving hard book-build guards are the portfolio-LEVEL risk
constraints that already existed -- the total book-risk budget and the venue daily-loss /
joint-tail limit -- plus the fail-closed data-validity guard.  This module never invents a
new arbitrary permanent cap (section 8, final paragraph); it only re-partitions the
existing concentration evidence into advisory warnings vs. the surviving hard guards, and
assembles the ``risk_diagnostics`` object that the builders emit so the warnings can never
silently become a no-op risk analysis (section 70).
"""
from __future__ import annotations

from typing import Any, Mapping, Sequence

# Dated OWNER decision that authorises converting the static caps to advisory diagnostics.
SUPERSEDING_DECISION = "OWNER-DEC-CBE-20260915"

RISK_DIAGNOSTICS_SCHEMA = "qm.risk-diagnostics/v1"

# Concentration dimensions whose breach is now advisory (section 8): the per-symbol,
# per-asset-class, per-family and per-session percent-of-budget concentration cutoffs.
ADVISORY_CAP_DIMENSIONS: tuple[str, ...] = ("symbol", "asset_class", "family", "session")

# The surviving hard guards that still fail a book closed:
#   * ``joint_tail``  -- the portfolio-level venue daily-loss / joint-tail limit,
#   * ``data``        -- the fail-closed data-validity guard (missing/invalid evidence).
HARD_GUARD_DIMENSIONS: tuple[str, ...] = ("joint_tail", "data")


def split_rejects(
    rejects: Sequence[Mapping[str, Any]],
) -> tuple[list[dict[str, Any]], list[dict[str, Any]]]:
    """Partition a machine-readable reject list into (advisory, hard) buckets.

    ``advisory`` holds the static concentration-cap breaches (now warnings); ``hard``
    holds the surviving portfolio-level guards (``joint_tail``) and the fail-closed
    data-validity guard (``data``).  Any unknown dimension is treated as HARD so an
    unrecognised guard fails closed rather than being silently downgraded.
    """
    advisory: list[dict[str, Any]] = []
    hard: list[dict[str, Any]] = []
    for reject in rejects or ():
        dim = str(reject.get("dim", ""))
        if dim in ADVISORY_CAP_DIMENSIONS:
            advisory.append(dict(reject))
        else:
            hard.append(dict(reject))
    return advisory, hard


def hard_guard_rejects(concentration: Mapping[str, Any]) -> list[dict[str, Any]]:
    """Return only the surviving hard-guard rejects from a concentration report.

    A book is refused only for a portfolio-level guard (``joint_tail``) or a fail-closed
    data-validity guard (``data``); static concentration-cap breaches are advisory and are
    never returned here.
    """
    _advisory, hard = split_rejects(concentration.get("concentration_reject") or ())
    return hard


def cap_warnings(concentration: Mapping[str, Any]) -> list[dict[str, Any]]:
    """Return the structured advisory cap warnings for a concentration report.

    Prefers the explicit ``cap_warnings`` list emitted by ``concentration_tail.evaluate``;
    falls back to re-deriving them from any advisory dimension breaches still carried in
    ``concentration_reject`` (robust against older report payloads).
    """
    explicit = concentration.get("cap_warnings")
    if isinstance(explicit, list):
        return [dict(row) for row in explicit]
    advisory, _hard = split_rejects(concentration.get("concentration_reject") or ())
    warnings: list[dict[str, Any]] = []
    for reject in advisory:
        warnings.append({
            "cap": reject.get("dim"),
            "key": reject.get("key"),
            "value": reject.get("value"),
            "threshold": reject.get("cap"),
            "unit": reject.get("unit", "planned_stop_risk_pct"),
            "severity": "WARN",
            "affected_sleeves": reject.get("affected_sleeves", []),
            "superseded_hard_cap": SUPERSEDING_DECISION,
        })
    return warnings


def build(
    concentration: Mapping[str, Any],
    *,
    dependence_panel: Sequence[Mapping[str, Any]] | None = None,
    correlation_warnings: Sequence[Mapping[str, Any]] | None = None,
) -> dict[str, Any]:
    """Assemble the ``risk_diagnostics`` object a builder embeds in its manifest.

    The object always carries the advisory ``cap_warnings`` and a ``hard_guards`` summary
    so a consumer can render both.  ``dependence_panel`` (pairwise / downside correlation /
    trade-overlap entries) and ``correlation_warnings`` (pairwise-correlation cutoff
    warnings) are included when the caller computed them.
    """
    tail = concentration.get("tail") or {}
    hard = hard_guard_rejects(concentration)
    warnings = cap_warnings(concentration)
    return {
        "schema": RISK_DIAGNOSTICS_SCHEMA,
        "supersedes_static_caps": (
            f"{SUPERSEDING_DECISION} sections 7/8: family/symbol/correlation and "
            "per-dimension concentration caps are advisory; portfolio-level risk is the "
            "only hard guard."
        ),
        "cap_warnings": warnings,
        "correlation_warnings": [dict(row) for row in (correlation_warnings or ())],
        "dependence_panel": [dict(row) for row in (dependence_panel or ())],
        "hard_guards": {
            "policy_status": concentration.get("policy_status"),
            "joint_tail": {
                "status": tail.get("status"),
                "worst_joint_day_loss_pct": tail.get("worst_joint_day_loss_pct"),
                "cap_loss_pct": tail.get("cap_loss_pct"),
            },
            "hard_guard_rejects": hard,
            "passed": not hard,
        },
    }


def markdown(diagnostics: Mapping[str, Any]) -> str:
    """Render the advisory diagnostics so warnings are never a silent no-op (section 70)."""
    lines = ["## Portfolio risk diagnostics (advisory caps + hard guards)", ""]
    hard = diagnostics.get("hard_guards") or {}
    lines.append(
        f"- Hard guards passed: `{str(bool(hard.get('passed'))).lower()}`; "
        f"joint-tail: `{(hard.get('joint_tail') or {}).get('status')}`; "
        f"policy: `{hard.get('policy_status')}`."
    )
    warnings = diagnostics.get("cap_warnings") or []
    if warnings:
        lines.append(f"- Advisory cap warnings (`{len(warnings)}`, no longer a hard cap):")
        for warning in warnings:
            lines.append(
                f"  - `{warning.get('cap')}` `{warning.get('key')}`: "
                f"`{warning.get('value')}` vs threshold `{warning.get('threshold')}` "
                f"(`{warning.get('unit')}`); sleeves: {warning.get('affected_sleeves')}"
            )
    else:
        lines.append("- Advisory cap warnings: none.")
    corr_warnings = diagnostics.get("correlation_warnings") or []
    if corr_warnings:
        lines.append(f"- Pairwise-correlation warnings (`{len(corr_warnings)}`):")
        for warning in corr_warnings:
            lines.append(
                f"  - `{warning.get('a')}` vs `{warning.get('b')}`: "
                f"|r|=`{warning.get('correlation')}` >= advisory reference "
                f"`{warning.get('threshold')}` (admitted-with-WARN)."
            )
    panel = diagnostics.get("dependence_panel") or []
    if panel:
        lines.append(f"- Dependence panel entries: `{len(panel)}`.")
    return "\n".join(lines)
