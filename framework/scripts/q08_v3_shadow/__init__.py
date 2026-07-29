"""Additive Q08 v3 shadow contracts.

This package is deliberately isolated from ``q08_davey``.  Importing it does
not read or mutate pipeline state, dispatch work, or change Q08 v2 verdicts.
"""

from .aggregate import aggregate_shadow
from .contracts import (
    AggregateDecision,
    EvidenceVerdict,
    FailureEffect,
    RequirementLevel,
    ShadowRoute,
    SubtestResult,
    SubtestStatus,
)
from .evidence_series import (
    BlockBootstrapResult,
    CalendarBasis,
    DailyObservation,
    EvidenceSeriesError,
    ReferenceCapital,
    ReturnPanel,
    SleeveInput,
    ValueKind,
    annualized_sharpe,
    build_return_panel,
    calendar_axis,
    moving_block_bootstrap,
)
from .policy import (
    DEFAULT_POLICY_PATH,
    ArchetypePolicy,
    PolicyManifest,
    PolicyValidationError,
    load_policy,
    parse_policy,
)

__all__ = [
    "AggregateDecision",
    "ArchetypePolicy",
    "BlockBootstrapResult",
    "CalendarBasis",
    "DEFAULT_POLICY_PATH",
    "DailyObservation",
    "EvidenceVerdict",
    "EvidenceSeriesError",
    "FailureEffect",
    "PolicyManifest",
    "PolicyValidationError",
    "RequirementLevel",
    "ReferenceCapital",
    "ReturnPanel",
    "ShadowRoute",
    "SubtestResult",
    "SubtestStatus",
    "SleeveInput",
    "ValueKind",
    "aggregate_shadow",
    "annualized_sharpe",
    "build_return_panel",
    "calendar_axis",
    "load_policy",
    "moving_block_bootstrap",
    "parse_policy",
]
