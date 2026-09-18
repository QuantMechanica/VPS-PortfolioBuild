"""Card intake prescreen -- G0 economics contract v2.

Lessons from the QM5_41477 H-FXMR Q02 postmortem
(``docs/research/HFXMR_41477_Q02_POSTMORTEM_2026-09-18.md``, section 5): a card
that only *asserts* a trading frequency derived from its own parameter caps,
never checks commission drag against its own minimum stop, never cross-checks
declared controls against each other for reachability, and ships an EA that
can only log what it *did* (never what it rejected and why) turns a Q02 kill
into unrecoverable guesswork instead of a fast, cheap G0 reject.

Relationship to the existing ``card_intake_prescreen.py`` (schema
``qm.card-intake-prescreen/v1``, on ``agents/board-advisor``): that module
screens drafts in ``cards_review``/``cards_draft`` for dedup, DWX symbol/feed
availability, charter-section completeness, and the runtime-ML/tail-risk
boundary. It is deliberately silent on trading economics (frequency, cost,
control reachability) and on build-time logging requirements. This module
covers exactly that gap as an ADDITIVE sibling contract -- it does not import,
patch, or duplicate any check in the v1 module, and does not change what v1
accepts or rejects. When the two branches merge, folding both under one
SCHEMA namespace is a reasonable follow-up, but is out of scope here: this
module is self-contained and independently runnable.

This module is a NEW, additive contract version (:data:`CONTRACT_VERSION`).
It does not replace or mutate the existing (implicitly unversioned / "v1")
G0 checks in ``farmctl.approve_card`` -- those keep gating
``cards_draft/`` -> ``cards_approved/`` exactly as they do today. v2 runs
alongside in shadow mode: it can be invoked standalone (CLI) or from a
script to produce a verdict, but nothing downstream is wired to block on it
until an independent, different-vendor critique has been recorded via
:func:`record_cross_vendor_critique` (see "Activation" below). Until then
every verdict this module produces is advisory/report-only, and existing
card approvals are left untouched: their ``g0_status``/``g0_approval_reasoning``
frontmatter is never rewritten by this module, so they stay bound to the
(legacy, unversioned) contract they were actually evaluated under -- old
verdicts are never mutated to look like they satisfied v2.

Four checks (postmortem section 5, items 1-4):

1. ``pilot_fire_count_evidence`` -- a card that states a trading-frequency
   claim must carry a *measured* fire-count field pointing at durable
   evidence; a claim derived only from the card's own parameter caps is
   rejected. "Caps are upper bounds; only a measurement is an expectation."
2. ``cost_to_target_floor`` -- ``commission_R = round_turn_cost_per_lot /
   (min_stop_units * unit_value_per_lot)`` at the card's own declared
   minimum plausible stop, using the OWNER-ratified worst-case commission
   registry (``framework/registry/live_commission.json`` via
   ``portfolio.commission.CommissionModel`` -- never a hand-rolled or
   invented commission figure). Reject at G0 above ``COST_TO_TARGET_MAX_R``.
3. ``no_op_filter_lint`` -- cross-check declared controls against each
   other for structural reachability (e.g. a per-day trade cap that can
   never bind because the window count already bounds entries lower).
4. ``skip_reason_logging`` -- an EA must emit a reason/session/branch-
   tagged rejection event for every evaluated in-window bar where no entry
   fired, not just for framework-level order-submission rejects. Gates
   before Q02, not at G0 (no EA exists yet at G0 time).

Activation
----------
:func:`contract_is_active` is False until a critique from a vendor/agent
distinct from the implementing author has been appended via
:func:`record_cross_vendor_critique` with ``verdict="ACCEPT"``. The author
of this module is Claude; Claude may not self-activate it -- calling
``record_cross_vendor_critique(critic_agent="claude", ...)`` raises.
"""
from __future__ import annotations

import argparse
import hashlib
import json
import re
import sys
from dataclasses import asdict, dataclass, field
from datetime import datetime, timezone
from pathlib import Path
from typing import Any

REPO_ROOT = Path(__file__).resolve().parents[2]
if str(REPO_ROOT / "tools" / "strategy_farm") not in sys.path:
    sys.path.insert(0, str(REPO_ROOT / "tools" / "strategy_farm"))
if str(REPO_ROOT / "tools" / "strategy_farm" / "portfolio") not in sys.path:
    sys.path.insert(0, str(REPO_ROOT / "tools" / "strategy_farm" / "portfolio"))

from commission import CommissionModel, DEFAULT_REGISTRY_PATH  # noqa: E402

CONTRACT_VERSION = "qm.card-intake-prescreen-g0-economics/v2"
# Cards approved before this contract existed were evaluated under
# farmctl.approve_card's checks only (R1-R4 body/frontmatter consistency,
# _approval_card_contract_issues, _infer_expected_trades_per_year_per_symbol)
# plus the separate cards_review-stage qm.card-intake-prescreen/v1 module.
# Neither has a frequency-measurement, cost-floor, filter-reachability, or
# skip-reason-logging check; this label exists so a verdict's "what did I
# compare against" is always explicit, never implicit-by-absence.
LEGACY_CONTRACT_VERSION = "qm.card-intake-prescreen-g0-economics/v1-legacy-unversioned"

COST_TO_TARGET_MAX_R = 0.03  # postmortem sec 5.2: reject at G0 above ~0.03 R

STRATEGY_ENTRY_REJECTED_EVENT = "STRATEGY_ENTRY_REJECTED"

STATUS_PASS = "PASS"
STATUS_FAIL = "FAIL"
STATUS_PARTIAL = "PARTIAL"
STATUS_MISSING_EVIDENCE = "MISSING_EVIDENCE"
STATUS_NOT_APPLICABLE = "NOT_APPLICABLE"
STATUS_DEFERRED_NO_BUILD_YET = "DEFERRED_NO_BUILD_YET"

# Overall verdict is FAIL if any check FAILed; otherwise MISSING_EVIDENCE if
# any check is missing required evidence (net-new fields nothing has yet);
# otherwise PASS. PARTIAL/NOT_APPLICABLE/DEFERRED never on their own block PASS.
_BLOCKING_FOR_OVERALL_FAIL = {STATUS_FAIL}
_BLOCKING_FOR_OVERALL_MISSING = {STATUS_MISSING_EVIDENCE, STATUS_DEFERRED_NO_BUILD_YET}


def _utcnow_iso() -> str:
    return datetime.now(timezone.utc).strftime("%Y-%m-%dT%H:%M:%SZ")


def _sha256_file(path: Path) -> str:
    h = hashlib.sha256()
    with path.open("rb") as fh:
        for chunk in iter(lambda: fh.read(1 << 20), b""):
            h.update(chunk)
    return h.hexdigest()


@dataclass(frozen=True)
class PrescreenCheckResult:
    check_id: str
    status: str
    detail: str
    data: dict[str, Any] = field(default_factory=dict)


@dataclass(frozen=True)
class PrescreenVerdict:
    contract_version: str
    card_path: str
    card_sha256: str | None
    generated_at: str
    checks: tuple[PrescreenCheckResult, ...]
    overall_status: str

    def to_dict(self) -> dict[str, Any]:
        return asdict(self)


# ---------------------------------------------------------------------------
# Card parsing helpers (frontmatter reuses farmctl's own parser -- do not
# reimplement a second hand-rolled YAML-subset parser for the same files).
# ---------------------------------------------------------------------------


def _load_frontmatter(card_path: Path) -> dict[str, Any]:
    import farmctl  # local import: farmctl.py is a multi-thousand-line module;

    # importing it at module load time would pay that cost even for callers
    # that only need the lint/cost checks and never touch a real card file.
    return farmctl.parse_card_frontmatter(card_path)


def _card_body(card_path: Path) -> str:
    text = card_path.read_text(encoding="utf-8-sig")
    m = re.match(r"^(?:\s*<!--.*?-->\s*)*---\s*\n.*?\n---\s*\n(.*)$", text, re.DOTALL)
    return m.group(1) if m else text


def _list_field(frontmatter_raw_text: str, key: str) -> list[str]:
    """Frontmatter list fields (e.g. ``target_symbols: [A, B]``) are skipped by
    farmctl.parse_card_frontmatter (it only keeps flat scalars), so pull them
    directly off the raw frontmatter block here."""
    m = re.search(rf"^{key}\s*:\s*\[(.*?)\]\s*$", frontmatter_raw_text, re.MULTILINE)
    if not m:
        return []
    return [item.strip().strip('"').strip("'") for item in m.group(1).split(",") if item.strip()]


def _frontmatter_block(card_path: Path) -> str:
    text = card_path.read_text(encoding="utf-8-sig")
    m = re.match(r"^(?:\s*<!--.*?-->\s*)*---\s*\n(.*?)\n---", text, re.DOTALL)
    return m.group(1) if m else ""


_TIMEFRAME_MINUTES = {
    "M1": 1, "M5": 5, "M15": 15, "M30": 30,
    "H1": 60, "H4": 240, "D1": 1440, "W1": 10080, "MN1": 43200,
}


# ---------------------------------------------------------------------------
# Check 1: pilot fire-count evidence
# ---------------------------------------------------------------------------


def check_pilot_fire_count_evidence(card_path: Path) -> PrescreenCheckResult:
    fm = _load_frontmatter(card_path)
    body = _card_body(card_path)

    has_freq_claim = bool(fm.get("expected_trades_per_year_per_symbol")) or bool(
        re.search(r"expected trade frequency|expected_trade_frequency", body, re.IGNORECASE)
    )
    measured = fm.get("measured_fire_count_per_window")

    if not has_freq_claim and measured is None:
        return PrescreenCheckResult(
            "pilot_fire_count_evidence",
            STATUS_NOT_APPLICABLE,
            "card carries no trading-frequency claim to substantiate",
        )

    if measured is None:
        return PrescreenCheckResult(
            "pilot_fire_count_evidence",
            STATUS_MISSING_EVIDENCE,
            "frequency claim present but no measured_fire_count_per_window field: "
            "a card may never state an expected frequency derived from its own "
            "caps (postmortem sec 5.1) -- caps are upper bounds, only a "
            "measurement is an expectation",
        )

    try:
        measured_val = float(measured)
    except (TypeError, ValueError):
        return PrescreenCheckResult(
            "pilot_fire_count_evidence",
            STATUS_FAIL,
            f"measured_fire_count_per_window={measured!r} is not numeric",
        )
    if not (0.0 <= measured_val <= 1.0):
        return PrescreenCheckResult(
            "pilot_fire_count_evidence",
            STATUS_FAIL,
            f"measured_fire_count_per_window={measured_val} out of [0,1] range "
            "(must be entries per evaluated window opportunity)",
        )

    evidence_path_raw = fm.get("measured_fire_count_evidence_path")
    evidence_hash = fm.get("measured_fire_count_evidence_sha256")
    if not evidence_path_raw:
        return PrescreenCheckResult(
            "pilot_fire_count_evidence",
            STATUS_MISSING_EVIDENCE,
            "measured_fire_count_per_window declared without "
            "measured_fire_count_evidence_path (durable artifact required)",
            {"measured_fire_count_per_window": measured_val},
        )

    evidence_path = Path(evidence_path_raw)
    if not evidence_path.is_absolute():
        evidence_path = REPO_ROOT / evidence_path
    if not evidence_path.exists():
        return PrescreenCheckResult(
            "pilot_fire_count_evidence",
            STATUS_FAIL,
            f"measured_fire_count_evidence_path {evidence_path_raw!r} does not exist on disk",
            {"measured_fire_count_per_window": measured_val},
        )

    if not evidence_hash:
        return PrescreenCheckResult(
            "pilot_fire_count_evidence",
            STATUS_FAIL,
            "measured_fire_count_evidence_path present but "
            "measured_fire_count_evidence_sha256 missing (unpinned evidence)",
            {"measured_fire_count_per_window": measured_val},
        )

    actual_hash = _sha256_file(evidence_path)
    if actual_hash != str(evidence_hash).lower():
        return PrescreenCheckResult(
            "pilot_fire_count_evidence",
            STATUS_FAIL,
            f"measured_fire_count_evidence_sha256 mismatch: card says "
            f"{evidence_hash}, file hashes to {actual_hash}",
            {"measured_fire_count_per_window": measured_val},
        )

    return PrescreenCheckResult(
        "pilot_fire_count_evidence",
        STATUS_PASS,
        f"measured fire count {measured_val:.4f}/window bound to hash-pinned "
        f"evidence at {evidence_path_raw}",
        {"measured_fire_count_per_window": measured_val, "evidence_path": evidence_path_raw},
    )


# ---------------------------------------------------------------------------
# Check 2: cost-to-target ratio floor
# ---------------------------------------------------------------------------


def check_cost_to_target_floor(
    card_path: Path, commission_model: CommissionModel | None = None
) -> PrescreenCheckResult:
    fm = _load_frontmatter(card_path)
    fm_block = _frontmatter_block(card_path)
    symbols = _list_field(fm_block, "target_symbols")

    min_stop_units_raw = fm.get("cost_floor_min_stop_units")
    unit_value_raw = fm.get("cost_floor_unit_value_per_lot")

    if not symbols:
        return PrescreenCheckResult(
            "cost_to_target_floor",
            STATUS_NOT_APPLICABLE,
            "card declares no target_symbols to cost",
        )

    if min_stop_units_raw is None or unit_value_raw is None:
        return PrescreenCheckResult(
            "cost_to_target_floor",
            STATUS_MISSING_EVIDENCE,
            "card lacks cost_floor_min_stop_units / cost_floor_unit_value_per_lot "
            "(mandatory field, postmortem sec 5.2): "
            "commission_R = round_turn_cost_per_lot / (min_stop_units * unit_value_per_lot) "
            f"must be computed and bounded below {COST_TO_TARGET_MAX_R} at the card's own "
            "minimum plausible stop before build",
        )

    try:
        min_stop_units = float(min_stop_units_raw)
        unit_value_per_lot = float(unit_value_raw)
    except (TypeError, ValueError):
        return PrescreenCheckResult(
            "cost_to_target_floor",
            STATUS_FAIL,
            f"cost_floor fields not numeric: min_stop_units={min_stop_units_raw!r}, "
            f"unit_value_per_lot={unit_value_raw!r}",
        )
    if min_stop_units <= 0 or unit_value_per_lot <= 0:
        return PrescreenCheckResult(
            "cost_to_target_floor",
            STATUS_FAIL,
            f"cost_floor fields must be positive: min_stop_units={min_stop_units}, "
            f"unit_value_per_lot={unit_value_per_lot}",
        )

    model = commission_model or CommissionModel(DEFAULT_REGISTRY_PATH)
    per_symbol: dict[str, float] = {}
    worst_symbol = None
    worst_r = -1.0
    for symbol in symbols:
        # Notional/equity is unknown at G0 (no live account context); use the
        # model's flat-per-lot floor deliberately -- it is the worst-case
        # figure the registry itself defines for a fixed 1.0-lot round turn,
        # not a fallback approximation.
        cost_per_lot = model.cost_round_trip(symbol, volume=1.0, notional_acct=None)
        commission_r = cost_per_lot / (min_stop_units * unit_value_per_lot)
        per_symbol[symbol] = commission_r
        if commission_r > worst_r:
            worst_r = commission_r
            worst_symbol = symbol

    if worst_r > COST_TO_TARGET_MAX_R:
        return PrescreenCheckResult(
            "cost_to_target_floor",
            STATUS_FAIL,
            f"commission_R={worst_r:.4f} for {worst_symbol} at min_stop_units="
            f"{min_stop_units} exceeds floor {COST_TO_TARGET_MAX_R} "
            "(postmortem QM5_41477 reference case: 0.583/11.1=0.0525R was 55% of the realised loss)",
            {"per_symbol_commission_r": per_symbol, "worst_symbol": worst_symbol},
        )

    return PrescreenCheckResult(
        "cost_to_target_floor",
        STATUS_PASS,
        f"worst-case commission_R={worst_r:.4f} ({worst_symbol}) within floor {COST_TO_TARGET_MAX_R}",
        {"per_symbol_commission_r": per_symbol, "worst_symbol": worst_symbol},
    )


# ---------------------------------------------------------------------------
# Check 3: no-op filter lint
# ---------------------------------------------------------------------------


def _parameter_ranges(body: str) -> dict[str, tuple[float, float]]:
    section = re.search(
        r"##\s*Parameter ranges\s*\n(.*?)(?=\n##\s|\Z)", body, re.DOTALL | re.IGNORECASE
    )
    if not section:
        return {}
    ranges: dict[str, tuple[float, float]] = {}
    for line in section.group(1).splitlines():
        m = re.match(
            r"\s*-\s*([A-Za-z_][A-Za-z0-9_]*)\s*:\s*(-?[\d.]+)\s*\.\.\s*(-?[\d.]+)", line
        )
        if m:
            key, lo, hi = m.group(1), float(m.group(2)), float(m.group(3))
            ranges[key] = (min(lo, hi), max(lo, hi))
    return ranges


def _lint_trade_cap_vs_window_count(body: str, ranges: dict[str, tuple[float, float]]):
    """Rule A: a per-day trade cap that the window structure already makes
    unreachable across its ENTIRE declared range is a silent no-op -- exactly
    the QM5_41477 defect (max_trades_per_day 2..6 behind "one entry per
    session window" x 2 windows/day, never reachable)."""
    if "max_trades_per_day" not in ranges:
        return None
    one_per_window = bool(
        re.search(r"one entry per symbol per session window", body, re.IGNORECASE)
    )
    if not one_per_window:
        return None
    window_prefixes = sorted(set(re.findall(r"(\w+)_start_hour_utc", body)))
    if not window_prefixes:
        return None
    window_count = len(window_prefixes)
    cap_lo, _cap_hi = ranges["max_trades_per_day"]
    if cap_lo >= window_count:
        return {
            "rule": "trade_cap_vs_window_count",
            "status": STATUS_FAIL,
            "detail": (
                f"max_trades_per_day min={cap_lo:g} >= structural window ceiling "
                f"{window_count} ({', '.join(window_prefixes)} x one entry/window): "
                "the cap is a no-op across its whole preregistered range"
            ),
        }
    return {
        "rule": "trade_cap_vs_window_count",
        "status": STATUS_PASS,
        "detail": f"max_trades_per_day min={cap_lo:g} < window ceiling {window_count}: reachable",
    }


def _lint_time_stop_vs_flat_minute(
    body: str, ranges: dict[str, tuple[float, float]], timeframe_minutes: int | None
):
    """Rule B: a time-stop whose MINIMUM configured duration can never fit
    before the mandatory session-flat minute in ANY configuration is
    structurally unreachable, not merely statistically dominated."""
    if "time_stop_bars" not in ranges or timeframe_minutes is None:
        return None
    time_stop_lo, _ = ranges["time_stop_bars"]
    min_runway_required = time_stop_lo * timeframe_minutes

    findings = []
    for prefix in sorted(set(re.findall(r"(\w+)_flat_min_utc", body))):
        start_key = f"{prefix}_start_hour_utc"
        flat_key = f"{prefix}_flat_min_utc"
        if start_key not in ranges or flat_key not in ranges:
            continue
        start_lo, _start_hi = ranges[start_key]
        _flat_lo, flat_hi = ranges[flat_key]
        max_possible_runway = flat_hi - (start_lo * 60.0)
        if max_possible_runway <= 0:
            continue
        if min_runway_required > max_possible_runway:
            findings.append(
                f"{prefix}: min time-stop runway {min_runway_required:g}min > "
                f"max possible window runway {max_possible_runway:g}min"
            )

    if not findings:
        return None
    return {
        "rule": "time_stop_vs_flat_minute",
        "status": STATUS_FAIL,
        "detail": "time_stop_bars structurally unreachable before session-flat: "
        + "; ".join(findings),
    }


def check_no_op_filter_lint(card_path: Path) -> PrescreenCheckResult:
    fm = _load_frontmatter(card_path)
    body = _card_body(card_path)
    ranges = _parameter_ranges(body)
    if not ranges:
        return PrescreenCheckResult(
            "no_op_filter_lint",
            STATUS_NOT_APPLICABLE,
            "no '## Parameter ranges' section to cross-check",
        )

    timeframe = fm.get("timeframe") or fm.get("period")
    timeframe_minutes = _TIMEFRAME_MINUTES.get(str(timeframe).upper()) if timeframe else None

    findings = []
    for rule_fn in (
        lambda: _lint_trade_cap_vs_window_count(body, ranges),
        lambda: _lint_time_stop_vs_flat_minute(body, ranges, timeframe_minutes),
    ):
        result = rule_fn()
        if result is not None:
            findings.append(result)

    if not findings:
        return PrescreenCheckResult(
            "no_op_filter_lint",
            STATUS_NOT_APPLICABLE,
            "no lint rule matched this card's declared controls (rule set is "
            "extensible, not exhaustive -- absence of a finding is not proof "
            "of consistency)",
        )

    failing = [f for f in findings if f["status"] == STATUS_FAIL]
    if failing:
        return PrescreenCheckResult(
            "no_op_filter_lint",
            STATUS_FAIL,
            "; ".join(f["detail"] for f in failing),
            {"findings": findings},
        )
    return PrescreenCheckResult(
        "no_op_filter_lint",
        STATUS_PASS,
        "; ".join(f["detail"] for f in findings),
        {"findings": findings},
    )


# ---------------------------------------------------------------------------
# Check 4: skip-reason logging requirement
# ---------------------------------------------------------------------------


def _ea_source_dir(card_path: Path, root: Path) -> Path | None:
    fm = _load_frontmatter(card_path)
    ea_id = fm.get("ea_id")
    slug = fm.get("slug")
    if not ea_id or not slug:
        return None
    candidate = root / "framework" / "EAs" / f"{ea_id}_{slug}"
    return candidate if candidate.is_dir() else None


def check_skip_reason_logging(card_path: Path, root: Path = REPO_ROOT) -> PrescreenCheckResult:
    ea_dir = _ea_source_dir(card_path, root)
    if ea_dir is None:
        return PrescreenCheckResult(
            "skip_reason_logging",
            STATUS_DEFERRED_NO_BUILD_YET,
            "no built EA source directory yet -- this check is mandatory "
            "before Q02, not at G0 card intake (postmortem sec 5.4)",
        )

    sources = list(ea_dir.glob("*.mqh")) + list(ea_dir.glob("*.mq5"))
    if not sources:
        return PrescreenCheckResult(
            "skip_reason_logging",
            STATUS_DEFERRED_NO_BUILD_YET,
            f"EA directory {ea_dir} has no .mqh/.mq5 sources yet",
        )

    for src in sources:
        text = src.read_text(encoding="utf-8", errors="replace")
        if STRATEGY_ENTRY_REJECTED_EVENT in text:
            return PrescreenCheckResult(
                "skip_reason_logging",
                STATUS_PASS,
                f"{STRATEGY_ENTRY_REJECTED_EVENT} emitted from {src.name}",
                {"source": str(src.relative_to(root))},
            )

    return PrescreenCheckResult(
        "skip_reason_logging",
        STATUS_FAIL,
        f"no {STRATEGY_ENTRY_REJECTED_EVENT}{{reason,session,branch}} event found in "
        f"{ea_dir.name} -- the EA can only log what it did, never what it rejected "
        "and why (postmortem sec 5.4: this is what made the QM5_41477 density "
        "shortfall unrecoverable guesswork). Framework-level QM_ENTRY_REJECTED_* "
        "events (QM_Entry.mqh) cover order-submission rejects only, not "
        "application-level 'no signal fired' evaluation -- a distinct event is required.",
        {"source_dir": str(ea_dir.relative_to(root))},
    )


# ---------------------------------------------------------------------------
# Verdict assembly
# ---------------------------------------------------------------------------

ALL_CHECKS = (
    check_pilot_fire_count_evidence,
    check_cost_to_target_floor,
    check_no_op_filter_lint,
    check_skip_reason_logging,
)


def _overall_status(checks: tuple[PrescreenCheckResult, ...]) -> str:
    statuses = {c.status for c in checks}
    if statuses & _BLOCKING_FOR_OVERALL_FAIL:
        return STATUS_FAIL
    if statuses & _BLOCKING_FOR_OVERALL_MISSING:
        return STATUS_MISSING_EVIDENCE
    return STATUS_PASS


def evaluate_card(card_path: Path, root: Path = REPO_ROOT) -> PrescreenVerdict:
    """Run the full contract against one card. Read-only: never mutates the
    card file or any state DB. Callers that want a durable record must
    append the resulting verdict to their own evidence ledger (see
    ``append_verdict_to_ledger``) -- this function never does so implicitly,
    so repeated dry runs never silently accumulate duplicate "official" rows."""
    checks = (
        check_pilot_fire_count_evidence(card_path),
        check_cost_to_target_floor(card_path),
        check_no_op_filter_lint(card_path),
        check_skip_reason_logging(card_path, root),
    )
    fm = _load_frontmatter(card_path)
    try:
        rel_path = str(card_path.resolve().relative_to(root.resolve()))
    except ValueError:
        rel_path = str(card_path)
    return PrescreenVerdict(
        contract_version=CONTRACT_VERSION,
        card_path=rel_path,
        card_sha256=fm.get("card_sha256"),
        generated_at=_utcnow_iso(),
        checks=checks,
        overall_status=_overall_status(checks),
    )


def append_verdict_to_ledger(verdict: PrescreenVerdict, ledger_path: Path) -> None:
    """Append-only JSONL write. Never opens the ledger in a mode that could
    truncate or rewrite a prior line -- old verdicts (under this version or
    any earlier one) stay exactly as they were recorded, forever bound to
    the contract_version stamped on them at the time."""
    ledger_path.parent.mkdir(parents=True, exist_ok=True)
    with ledger_path.open("a", encoding="utf-8") as fh:
        fh.write(json.dumps(verdict.to_dict(), sort_keys=True) + "\n")


# ---------------------------------------------------------------------------
# Activation: independent cross-vendor critique gate
# ---------------------------------------------------------------------------

ACTIVATION_LEDGER_SCHEMA = "qm.card-intake-prescreen-g0-economics-activation/v1"
DEFAULT_ACTIVATION_LEDGER = (
    REPO_ROOT / "docs" / "ops" / "evidence" / "2026-09-18_card_intake_prescreen_v2"
    / "activation_ledger.jsonl"
)
IMPLEMENTING_AUTHOR_AGENT = "claude"


def record_cross_vendor_critique(
    critic_agent: str,
    verdict: str,
    notes: str,
    ledger_path: Path = DEFAULT_ACTIVATION_LEDGER,
    author_agent: str = IMPLEMENTING_AUTHOR_AGENT,
) -> dict[str, Any]:
    """Append an independent critique record for CONTRACT_VERSION.

    Raises ValueError if critic_agent == author_agent: this contract was
    authored by ``author_agent`` and must not be self-activated. verdict must
    be "ACCEPT" or "REJECT" (case-insensitive); anything else raises.
    """
    if critic_agent.strip().lower() == author_agent.strip().lower():
        raise ValueError(
            f"cross-vendor critique requires critic_agent != author_agent "
            f"(author={author_agent!r}); a same-vendor 'critique' cannot activate "
            "this contract (postmortem sec 5 + the QM5_41477 card's own "
            "Pipeline history entry: same-vendor approval without independent "
            "critique is exactly the gap this contract exists to close)"
        )
    verdict_norm = verdict.strip().upper()
    if verdict_norm not in {"ACCEPT", "REJECT"}:
        raise ValueError(f"verdict must be ACCEPT or REJECT, got {verdict!r}")

    record = {
        "schema": ACTIVATION_LEDGER_SCHEMA,
        "contract_version": CONTRACT_VERSION,
        "author_agent": author_agent,
        "critic_agent": critic_agent,
        "verdict": verdict_norm,
        "notes": notes,
        "recorded_at": _utcnow_iso(),
    }
    ledger_path.parent.mkdir(parents=True, exist_ok=True)
    with ledger_path.open("a", encoding="utf-8") as fh:
        fh.write(json.dumps(record, sort_keys=True) + "\n")
    return record


def contract_is_active(ledger_path: Path = DEFAULT_ACTIVATION_LEDGER) -> bool:
    """True only if the ledger contains at least one ACCEPT critique record
    for CONTRACT_VERSION from a critic distinct from IMPLEMENTING_AUTHOR_AGENT."""
    if not ledger_path.exists():
        return False
    for line in ledger_path.read_text(encoding="utf-8").splitlines():
        line = line.strip()
        if not line:
            continue
        record = json.loads(line)
        if (
            record.get("contract_version") == CONTRACT_VERSION
            and record.get("verdict") == "ACCEPT"
            and record.get("critic_agent", "").strip().lower() != IMPLEMENTING_AUTHOR_AGENT
        ):
            return True
    return False


# ---------------------------------------------------------------------------
# CLI
# ---------------------------------------------------------------------------


def _cli_evaluate(args: argparse.Namespace) -> int:
    card_path = Path(args.card).resolve()
    verdict = evaluate_card(card_path, root=REPO_ROOT)
    payload = verdict.to_dict()
    payload["contract_active"] = contract_is_active()
    print(json.dumps(payload, indent=2, sort_keys=True))
    return 0 if verdict.overall_status != STATUS_FAIL else 1


def _cli_scan(args: argparse.Namespace) -> int:
    cards_dir = Path(args.cards_dir).resolve()
    out_path = Path(args.output).resolve() if args.output else None
    verdicts = [evaluate_card(card_path, root=REPO_ROOT) for card_path in sorted(cards_dir.glob("*.md"))]
    if out_path:
        out_path.parent.mkdir(parents=True, exist_ok=True)
        with out_path.open("w", encoding="utf-8") as fh:
            for v in verdicts:
                fh.write(json.dumps(v.to_dict(), sort_keys=True) + "\n")
    summary: dict[str, int] = {}
    for v in verdicts:
        summary[v.overall_status] = summary.get(v.overall_status, 0) + 1
    print(json.dumps({"scanned": len(verdicts), "by_overall_status": summary}, indent=2))
    return 0


def main(argv: list[str] | None = None) -> int:
    parser = argparse.ArgumentParser(description="Card intake prescreen -- G0 economics contract v2")
    sub = parser.add_subparsers(dest="cmd", required=True)

    p_eval = sub.add_parser("evaluate", help="Evaluate one card")
    p_eval.add_argument("--card", required=True)
    p_eval.set_defaults(func=_cli_evaluate)

    p_scan = sub.add_parser("scan", help="Evaluate every card in a directory (report-only)")
    p_scan.add_argument("--cards-dir", required=True)
    p_scan.add_argument("--output", default=None, help="Optional JSONL output path")
    p_scan.set_defaults(func=_cli_scan)

    args = parser.parse_args(argv)
    return args.func(args)


if __name__ == "__main__":
    raise SystemExit(main())
