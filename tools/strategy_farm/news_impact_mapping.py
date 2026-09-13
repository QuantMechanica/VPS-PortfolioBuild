#!/usr/bin/env python3
"""Deterministic news-impact taxonomy under ``qm.news_impact_mapping.v1``.

This module implements sections 3, 4 and 7 of
``docs/ops/NEWS_CALENDAR_CONTRACT_V2_2026-08-22.md`` for the **factory
evidence** layer:

* **section 3** - exactly one active source per run.  The authoritative source
  is fixed by ``OWNER-DEC-NEWS-MAPPING`` (2026-08-22, Option 1:
  ``forex_factory_calendar_clean.csv``; ``news_calendar_2015_2025.csv`` is an
  audit trail, never a gating source).  Loading any non-authoritative source
  is refused unless the caller passes an explicit, recorded override.
* **section 4** - the impact mapping is one versioned rules artifact
  (``tools/strategy_farm/config/news_impact_mapping.v1.json``) plus this code,
  fingerprinted by a hash over *both*.  No inline rank dict.
* **section 7** - :func:`run_self_report` returns the consolidated
  ``{schema_version, mapping_version, dst_rule_version, authoritative_source,
  source_path, content_sha256, row_count, max_event_date_utc,
  generated_at_utc}`` object plus per-label counts.

Two deliberate non-goals:

* **Nothing here is wired into the live news path.**  DL-080 and the OWNER
  ruling of 2026-09-06 stand: an ``ENV=live`` EA uses the native MT5 calendar,
  fail-closed.  This module is factory evidence semantics only.
* **Default-OFF for consumers.**  Every function that produces mapped rows or
  a self-report requires an explicit ``opt_in=True`` plus a named ``consumer``.
  Importing the module changes no existing behaviour.

The ``qm.dst_rule.us.v1`` helpers are the Python port of the already-live MQL5
rule in ``framework/include/QM/QM_DSTAware.mqh`` (contract section 2); they are
needed here so a mapped row can carry the broker-time projection the gate
layer reasons about.
"""

from __future__ import annotations

import argparse
import calendar
import csv
import hashlib
import json
import os
import sys
from dataclasses import dataclass, asdict
from datetime import datetime, timedelta, timezone
from pathlib import Path
from typing import Any, Iterable, Iterator, Mapping, Sequence

SCHEMA_VERSION = "qm.news_impact_mapping.v1"
SELFREPORT_SCHEMA_VERSION = "qm.news-calendar-run-selfreport/v1"
DST_RULE_VERSION = "qm.dst_rule.us.v1"

MODULE_PATH = Path(__file__).resolve()
DEFAULT_RULES_PATH = MODULE_PATH.parent / "config" / "news_impact_mapping.v1.json"
DEFAULT_CALENDAR_DIR = Path(r"D:\QM\data\news_calendar")

#: Consumers are opt-in.  Importing this module must not change any behaviour.
DEFAULT_ENABLED = False

#: The single cutover flag.  One flag, one spelling, Default-OFF.
FLAG_ENV = "QM_NEWS_IMPACT_MAPPING_V2"


class MappingError(ValueError):
    """Base class for every fail-closed refusal in this module."""


class OptInRequired(MappingError):
    """A consumer used the mapping without declaring itself."""


class SourceNotAuthoritative(MappingError):
    """Section 3: the run declared a source that is not the canonical one."""


class UnmappedImpactLabel(MappingError):
    """Section 4: an impact string the versioned rules do not describe."""


class DuplicateEventConflict(MappingError):
    """Section 8: the same event identity carries conflicting impact.

    Raised only when the active ``duplicate_policy`` cannot resolve the clash:
    under ``collapse_identical_impact_else_reject`` for *any* disagreement, and
    under ``collapse_identical_impact_else_highest_rank_wins`` only when the
    disagreeing labels share one rank (no fail-safe direction exists).
    """


#: ``duplicate_policy`` values this module implements (contract section 8).
DUPLICATE_POLICY_REJECT = "collapse_identical_impact_else_reject"
DUPLICATE_POLICY_MAX_RANK = "collapse_identical_impact_else_highest_rank_wins"
SUPPORTED_DUPLICATE_POLICIES = frozenset(
    {DUPLICATE_POLICY_REJECT, DUPLICATE_POLICY_MAX_RANK}
)


# --------------------------------------------------------------------------
# qm.dst_rule.us.v1 - Python port of framework/include/QM/QM_DSTAware.mqh
# --------------------------------------------------------------------------


def _nth_weekday_of_month(year: int, month: int, weekday: int, nth: int) -> int:
    """Day-of-month of the ``nth`` ``weekday`` (0=Sunday) in ``year``/``month``."""

    hits = 0
    for day in range(1, calendar.monthrange(year, month)[1] + 1):
        # calendar.weekday: Monday=0..Sunday=6 -> MQL5 convention Sunday=0..Saturday=6
        if (calendar.weekday(year, month, day) + 1) % 7 != weekday:
            continue
        hits += 1
        if hits == nth:
            return day
    raise MappingError(f"no {nth}th weekday {weekday} in {year}-{month:02d}")


def us_dst_start_utc(year: int) -> datetime:
    """07:00 UTC on the 2nd Sunday of March (02:00 local EST, UTC-5)."""

    day = _nth_weekday_of_month(year, 3, 0, 2)
    return datetime(year, 3, day, 7, 0, tzinfo=timezone.utc)


def us_dst_end_utc(year: int) -> datetime:
    """06:00 UTC on the 1st Sunday of November (02:00 local EDT, UTC-4)."""

    day = _nth_weekday_of_month(year, 11, 0, 1)
    return datetime(year, 11, day, 6, 0, tzinfo=timezone.utc)


def is_us_dst_utc(moment: datetime) -> bool:
    """True on ``[start, end)`` of the US DST window containing ``moment``."""

    moment = _as_utc(moment)
    return us_dst_start_utc(moment.year) <= moment < us_dst_end_utc(moment.year)


def broker_offset_hours(moment: datetime) -> int:
    """UTC+3 during US DST, else UTC+2 (Darwinex Zero NY-close convention)."""

    return 3 if is_us_dst_utc(moment) else 2


def utc_to_broker(moment: datetime) -> datetime:
    """Deterministic broker time; never read from a broker clock."""

    moment = _as_utc(moment)
    return moment + timedelta(hours=broker_offset_hours(moment))


def broker_to_utc(broker_moment: datetime) -> datetime:
    """Reverse map; at the November fallback prefer the UTC+2 candidate."""

    naive = broker_moment.replace(tzinfo=None)
    standard = naive - timedelta(hours=2)
    summer = naive - timedelta(hours=3)
    standard_utc = standard.replace(tzinfo=timezone.utc)
    summer_utc = summer.replace(tzinfo=timezone.utc)
    # Documented policy (QM_BrokerToUTC): prefer standard time when both fit.
    if not is_us_dst_utc(standard_utc):
        return standard_utc
    if is_us_dst_utc(summer_utc):
        return summer_utc
    return standard_utc


def _as_utc(moment: datetime) -> datetime:
    if moment.tzinfo is None:
        return moment.replace(tzinfo=timezone.utc)
    return moment.astimezone(timezone.utc)


# --------------------------------------------------------------------------
# Rules, code and version hash (contract section 4)
# --------------------------------------------------------------------------


def canonical_json_bytes(value: Any) -> bytes:
    return (
        json.dumps(value, sort_keys=True, separators=(",", ":"), ensure_ascii=False) + "\n"
    ).encode("utf-8")


def sha256_bytes(data: bytes) -> str:
    return hashlib.sha256(data).hexdigest()


def sha256_file(path: Path) -> str:
    digest = hashlib.sha256()
    with Path(path).open("rb") as handle:
        for chunk in iter(lambda: handle.read(1024 * 1024), b""):
            digest.update(chunk)
    return digest.hexdigest()


_REQUIRED_RULE_KEYS = (
    "schema_version",
    "authoritative_source",
    "source_field",
    "timestamp_field",
    "currency_field",
    "event_field",
    "labels",
    "unmapped_label_policy",
    "duplicate_policy",
    "dst_rule_version",
)


def load_rules(rules_path: Path | str | None = None) -> dict[str, Any]:
    """Load and structurally validate the versioned rules artifact."""

    path = Path(rules_path or DEFAULT_RULES_PATH)
    rules = json.loads(path.read_text(encoding="utf-8"))
    if not isinstance(rules, Mapping):
        raise MappingError("rules artifact must be a JSON object")
    for key in _REQUIRED_RULE_KEYS:
        if key not in rules:
            raise MappingError(f"rules artifact is missing required key {key!r}")
    if rules["schema_version"] != SCHEMA_VERSION:
        raise MappingError(
            f"rules schema_version must be {SCHEMA_VERSION!r}, got {rules['schema_version']!r}"
        )
    if rules["dst_rule_version"] != DST_RULE_VERSION:
        raise MappingError(f"rules dst_rule_version must be {DST_RULE_VERSION!r}")
    labels = rules["labels"]
    if not isinstance(labels, Mapping) or not labels:
        raise MappingError("rules.labels must be a non-empty object")
    if rules["duplicate_policy"] not in SUPPORTED_DUPLICATE_POLICIES:
        raise MappingError(
            f"rules duplicate_policy {rules['duplicate_policy']!r} is not one of "
            f"{sorted(SUPPORTED_DUPLICATE_POLICIES)}"
        )
    seen_alias: dict[str, str] = {}
    for label, spec in labels.items():
        if not isinstance(spec, Mapping) or "rank" not in spec or "gating" not in spec:
            raise MappingError(f"rules.labels.{label} needs rank and gating")
        for alias in [label, *spec.get("aliases", [])]:
            key = str(alias).strip().lower()
            if key in seen_alias and seen_alias[key] != label:
                raise MappingError(f"alias {key!r} is claimed by two labels")
            seen_alias[key] = label
    return dict(rules)


def rules_sha256(rules: Mapping[str, Any]) -> str:
    """Hash of the rules content alone (order-independent)."""

    return sha256_bytes(canonical_json_bytes(rules))


def code_sha256() -> str:
    """Hash of this module's own source bytes."""

    return sha256_file(MODULE_PATH)


def mapping_version_hash(rules: Mapping[str, Any] | None = None) -> str:
    """Contract section 4 fingerprint over **rules + code**.

    A silent edit to either side moves this hash, so evidence generated before
    and after the edit is visibly non-comparable (section 9).
    """

    resolved = dict(rules) if rules is not None else load_rules()
    fingerprint = {
        "schema_version": SCHEMA_VERSION,
        "rules_sha256": rules_sha256(resolved),
        "code_sha256": code_sha256(),
    }
    return sha256_bytes(canonical_json_bytes(fingerprint))


def mapping_fingerprint(rules: Mapping[str, Any] | None = None) -> dict[str, str]:
    """The full, quotable fingerprint triple for a run self-report."""

    resolved = dict(rules) if rules is not None else load_rules()
    return {
        "mapping_version": SCHEMA_VERSION,
        "rules_sha256": rules_sha256(resolved),
        "code_sha256": code_sha256(),
        "content_sha256": mapping_version_hash(resolved),
        "dst_rule_version": DST_RULE_VERSION,
    }


# --------------------------------------------------------------------------
# Opt-in gate (Default-OFF)
# --------------------------------------------------------------------------


def v2_enabled(env: Mapping[str, str] | None = None) -> bool:
    """True only for the exact opt-in value ``"1"`` of :data:`FLAG_ENV`.

    Anything else - unset, empty, ``"0"``, ``"true"``, ``"yes"`` - leaves every
    consumer on its pre-V2 code path, whose output must stay byte-identical.
    A typo therefore fails *off*, never half-on.
    """

    source = os.environ if env is None else env
    return str(source.get(FLAG_ENV, "") or "").strip() == "1"


def contract_declaration(
    source_path: Path | str | None = None,
    *,
    consumer: str | None = None,
    opt_in: bool = False,
    rules: Mapping[str, Any] | None = None,
    allow_non_authoritative: bool = False,
    require_source: bool = True,
) -> dict[str, Any]:
    """The contract section 3 + 4 + 7 declaration a consuming run must cite.

    This is the cheap half of :func:`run_self_report`: it names *which* source
    is authoritative and *which* mapping was used, without mapping every row.
    A consumer that gates on impact must be able to state both even when it
    never builds a full mapped view.
    """

    who = _require_opt_in(consumer, opt_in)
    resolved = dict(rules) if rules is not None else load_rules()
    fingerprint = mapping_fingerprint(resolved)
    declaration: dict[str, Any] = {
        "selfreport_schema_version": SELFREPORT_SCHEMA_VERSION,
        "schema_version": resolved.get("contract_schema_version", SCHEMA_VERSION),
        "mapping_version": fingerprint["mapping_version"],
        "mapping_content_sha256": fingerprint["content_sha256"],
        "mapping_rules_sha256": fingerprint["rules_sha256"],
        "mapping_code_sha256": fingerprint["code_sha256"],
        "dst_rule_version": DST_RULE_VERSION,
        "authoritative_source": resolved["authoritative_source"],
        "authoritative_source_decision": resolved.get("owner_decision"),
        "duplicate_policy": resolved["duplicate_policy"],
        "consumer": who,
        "live_path_forbidden": True,
    }
    if require_source:
        path = resolve_source(
            source_path, rules=resolved, allow_non_authoritative=allow_non_authoritative
        )
        declaration["authoritative_source"] = path.name
        declaration["source_path"] = str(path)
        declaration["content_sha256"] = sha256_file(path)
    return declaration


def _require_opt_in(consumer: str | None, opt_in: bool) -> str:
    if DEFAULT_ENABLED:  # pragma: no cover - the artifact ships Default-OFF
        return consumer or "default_enabled"
    if not opt_in:
        raise OptInRequired(
            "qm.news_impact_mapping.v1 is Default-OFF; pass opt_in=True and a consumer name"
        )
    if not isinstance(consumer, str) or not consumer.strip():
        raise OptInRequired("an opting-in consumer must name itself")
    return consumer.strip()


# --------------------------------------------------------------------------
# Mapping
# --------------------------------------------------------------------------


@dataclass(frozen=True)
class ImpactClass:
    label: str
    rank: int
    gating: bool


@dataclass(frozen=True)
class MappedEvent:
    timestamp_utc: str
    currency: str
    event: str
    impact_label: str
    impact_rank: int
    gating: bool
    source_impact_raw: str
    broker_time: str
    broker_offset_hours: int
    occurrences: int = 1
    #: True when this row survived an identity conflict under the max-rank rule.
    impact_conflict_resolved: bool = False
    #: The labels this row out-ranked, sorted, so the escalation stays visible.
    superseded_impact_labels: tuple[str, ...] = ()

    def as_dict(self) -> dict[str, Any]:
        return asdict(self)


def classify(impact_raw: Any, rules: Mapping[str, Any] | None = None) -> ImpactClass:
    """Map one raw impact string to the versioned taxonomy.  Fail-closed."""

    resolved = dict(rules) if rules is not None else load_rules()
    key = str(impact_raw or "").strip().lower()
    for label, spec in resolved["labels"].items():
        aliases = {label.lower(), *(str(a).strip().lower() for a in spec.get("aliases", []))}
        if key in aliases:
            return ImpactClass(label=label, rank=int(spec["rank"]), gating=bool(spec["gating"]))
    if resolved.get("unmapped_label_policy") != "fail_closed":  # pragma: no cover
        raise MappingError("only the fail_closed unmapped_label_policy is implemented")
    raise UnmappedImpactLabel(f"impact {impact_raw!r} is not described by {SCHEMA_VERSION}")


def resolve_source(
    source_path: Path | str | None = None,
    *,
    rules: Mapping[str, Any] | None = None,
    allow_non_authoritative: bool = False,
) -> Path:
    """Section 3: resolve **exactly one** authoritative source for this run."""

    resolved = dict(rules) if rules is not None else load_rules()
    authoritative = resolved["authoritative_source"]
    path = Path(source_path) if source_path else DEFAULT_CALENDAR_DIR / authoritative
    if path.name != authoritative and not allow_non_authoritative:
        raise SourceNotAuthoritative(
            f"{path.name!r} is not the authoritative source {authoritative!r} "
            "(OWNER-DEC-NEWS-MAPPING 2026-08-22, Option 1)"
        )
    if not path.is_file():
        raise MappingError(f"calendar source not found: {path}")
    return path


def _parse_timestamp(raw: Any, formats: Sequence[str]) -> datetime:
    text = str(raw or "").strip()
    if not text:
        raise MappingError("empty timestamp")
    for fmt in formats:
        try:
            return datetime.strptime(text, fmt).replace(tzinfo=timezone.utc)
        except ValueError:
            continue
    raise MappingError(f"timestamp {text!r} matches none of {list(formats)}")


def _iso(moment: datetime) -> str:
    return moment.astimezone(timezone.utc).strftime("%Y-%m-%dT%H:%M:%SZ")


def map_rows(
    rows: Iterable[Mapping[str, Any]],
    *,
    consumer: str | None = None,
    opt_in: bool = False,
    rules: Mapping[str, Any] | None = None,
) -> list[MappedEvent]:
    """Map raw calendar rows to the taxonomy, deterministically.

    Output order is the deterministic sort
    ``(timestamp_utc, currency, event)`` - never input order - so two runs over
    the same bytes produce byte-identical evidence.  Duplicate identities are
    handled per ``rules.duplicate_policy``: identities whose mapped label agrees
    collapse into one row with ``occurrences > 1`` (visible, recorded); a
    disagreement is settled by the recorded ``duplicate_conflict_rule``
    (contract section 8, which explicitly permits visible deduplication under a
    recorded rule):

    * ``collapse_identical_impact_else_reject`` - any disagreement raises
      :class:`DuplicateEventConflict`.  This was the only behaviour before
      2026-09-13 and stays selectable through an explicit rules artifact.
    * ``collapse_identical_impact_else_highest_rank_wins`` - the shipped rule
      since 2026-09-13: the **higher impact rank wins**.  A news filter is a
      safety device, so the fail-safe direction on an identity conflict is the
      more restrictive classification.  The out-ranked label is kept on the row
      in ``superseded_impact_labels`` and counted in the self-report, so the
      escalation is visible, never silent.  Two *different* labels of equal rank
      still raise - there is no fail-safe direction to pick.
    """

    _require_opt_in(consumer, opt_in)
    resolved = dict(rules) if rules is not None else load_rules()
    policy = resolved["duplicate_policy"]
    if policy not in SUPPORTED_DUPLICATE_POLICIES:
        raise MappingError(f"unsupported duplicate_policy {policy!r}")
    formats = resolved.get("timestamp_formats") or ["%Y-%m-%dT%H:%M:%S"]
    ts_field = resolved["timestamp_field"]
    ccy_field = resolved["currency_field"]
    ev_field = resolved["event_field"]

    collapsed: dict[tuple[str, str, str], MappedEvent] = {}
    for index, row in enumerate(rows):
        try:
            moment = _parse_timestamp(row.get(ts_field), formats)
        except MappingError as exc:
            raise MappingError(f"row {index}: {exc}") from exc
        impact_raw = str(row.get(resolved["source_field"]) or "").strip()
        klass = classify(impact_raw, resolved)
        currency = str(row.get(ccy_field) or "").strip()
        event = str(row.get(ev_field) or "").strip()
        key = (_iso(moment), currency, event)
        broker = utc_to_broker(moment)
        mapped = MappedEvent(
            timestamp_utc=key[0],
            currency=currency,
            event=event,
            impact_label=klass.label,
            impact_rank=klass.rank,
            gating=klass.gating,
            source_impact_raw=impact_raw,
            broker_time=broker.strftime("%Y-%m-%dT%H:%M:%S"),
            broker_offset_hours=broker_offset_hours(moment),
        )
        previous = collapsed.get(key)
        if previous is None:
            collapsed[key] = mapped
            continue
        if previous.impact_label == mapped.impact_label:
            collapsed[key] = MappedEvent(
                **{**previous.as_dict(), "occurrences": previous.occurrences + 1}
            )
            continue
        if (
            policy != DUPLICATE_POLICY_MAX_RANK
            or previous.impact_rank == mapped.impact_rank
        ):
            raise DuplicateEventConflict(
                f"duplicate identity {key} carries conflicting impact "
                f"{previous.impact_label!r} vs {mapped.impact_label!r}"
            )
        winner, loser = (
            (mapped, previous)
            if mapped.impact_rank > previous.impact_rank
            else (previous, mapped)
        )
        collapsed[key] = MappedEvent(
            **{
                **winner.as_dict(),
                "occurrences": previous.occurrences + 1,
                "impact_conflict_resolved": True,
                "superseded_impact_labels": tuple(
                    sorted(
                        {
                            *previous.superseded_impact_labels,
                            *mapped.superseded_impact_labels,
                            loser.impact_label,
                        }
                    )
                ),
            }
        )
    return [collapsed[key] for key in sorted(collapsed)]


def read_calendar(path: Path | str) -> Iterator[dict[str, str]]:
    """Read the calendar CSV.  Look-ahead columns stay out of the mapping."""

    with Path(path).open("r", encoding="utf-8-sig", newline="") as handle:
        yield from csv.DictReader(handle)


def schedule_view(events: Sequence[MappedEvent]) -> list[dict[str, Any]]:
    """Section 5 projection: no ``actual``/``forecast``/``previous``, ever."""

    return [
        {
            "timestamp_utc": event.timestamp_utc,
            "currency": event.currency,
            "impact": event.impact_label,
            "impact_rank": event.impact_rank,
            "event_id": sha256_bytes(
                canonical_json_bytes([event.timestamp_utc, event.currency, event.event])
            )[:16],
        }
        for event in events
    ]


# --------------------------------------------------------------------------
# Run self-report (contract section 7)
# --------------------------------------------------------------------------


def run_self_report(
    source_path: Path | str | None = None,
    *,
    consumer: str | None = None,
    opt_in: bool = False,
    rules: Mapping[str, Any] | None = None,
    allow_non_authoritative: bool = False,
    generated_at_utc: str | None = None,
) -> dict[str, Any]:
    """Emit the one consolidated self-report a consuming run must cite."""

    who = _require_opt_in(consumer, opt_in)
    resolved = dict(rules) if rules is not None else load_rules()
    path = resolve_source(
        source_path, rules=resolved, allow_non_authoritative=allow_non_authoritative
    )
    events = map_rows(read_calendar(path), consumer=who, opt_in=True, rules=resolved)

    counts: dict[str, int] = {label: 0 for label in sorted(resolved["labels"])}
    gating_rows = 0
    duplicate_groups = 0
    collapsed_rows = 0
    conflicts_resolved = 0
    resolved_conflicts: list[dict[str, Any]] = []
    for event in events:
        counts[event.impact_label] = counts.get(event.impact_label, 0) + event.occurrences
        if event.gating:
            gating_rows += event.occurrences
        if event.occurrences > 1:
            duplicate_groups += 1
            collapsed_rows += event.occurrences - 1
        if event.impact_conflict_resolved:
            conflicts_resolved += 1
            resolved_conflicts.append({
                "timestamp_utc": event.timestamp_utc,
                "currency": event.currency,
                "event": event.event,
                "resolved_to": event.impact_label,
                "superseded_impact_labels": list(event.superseded_impact_labels),
            })

    fingerprint = mapping_fingerprint(resolved)
    report = {
        "selfreport_schema_version": SELFREPORT_SCHEMA_VERSION,
        "schema_version": resolved.get("contract_schema_version", SCHEMA_VERSION),
        "mapping_version": fingerprint["mapping_version"],
        "mapping_content_sha256": fingerprint["content_sha256"],
        "mapping_rules_sha256": fingerprint["rules_sha256"],
        "mapping_code_sha256": fingerprint["code_sha256"],
        "dst_rule_version": DST_RULE_VERSION,
        "authoritative_source": path.name,
        "authoritative_source_decision": resolved.get("owner_decision"),
        "source_path": str(path),
        "content_sha256": sha256_file(path),
        "row_count": sum(event.occurrences for event in events),
        "distinct_event_count": len(events),
        "duplicate_groups": duplicate_groups,
        "duplicate_collapsed_rows": collapsed_rows,
        "duplicate_policy": resolved["duplicate_policy"],
        "duplicate_conflict_rule_id": (
            (resolved.get("duplicate_conflict_rule") or {}).get("rule_id")
        ),
        "duplicate_conflicts_resolved": conflicts_resolved,
        "duplicate_conflicts": resolved_conflicts,
        "impact_counts": counts,
        "gating_row_count": gating_rows,
        "max_event_date_utc": events[-1].timestamp_utc if events else None,
        "min_event_date_utc": events[0].timestamp_utc if events else None,
        "consumer": who,
        "live_path_forbidden": True,
        "generated_at_utc": generated_at_utc
        or datetime.now(timezone.utc).strftime("%Y-%m-%dT%H:%M:%SZ"),
    }
    report["selfreport_sha256"] = sha256_bytes(
        canonical_json_bytes({k: v for k, v in report.items() if k != "generated_at_utc"})
    )
    return report


# --------------------------------------------------------------------------
# CLI
# --------------------------------------------------------------------------


def build_parser() -> argparse.ArgumentParser:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--source", type=Path, default=None)
    parser.add_argument("--rules", type=Path, default=None)
    parser.add_argument("--consumer", required=True, help="name of the opting-in consumer")
    parser.add_argument("--opt-in", action="store_true", required=True)
    parser.add_argument("--fingerprint-only", action="store_true")
    parser.add_argument("--output", type=Path, default=None)
    return parser


def main(argv: Sequence[str] | None = None) -> int:
    args = build_parser().parse_args(argv)
    rules = load_rules(args.rules)
    if args.fingerprint_only:
        payload: dict[str, Any] = mapping_fingerprint(rules)
    else:
        payload = run_self_report(
            args.source, consumer=args.consumer, opt_in=args.opt_in, rules=rules
        )
    text = json.dumps(payload, indent=1, sort_keys=True)
    if args.output:
        args.output.parent.mkdir(parents=True, exist_ok=True)
        args.output.write_text(text + "\n", encoding="utf-8")
    print(text)
    return 0


if __name__ == "__main__":  # pragma: no cover
    sys.exit(main())
