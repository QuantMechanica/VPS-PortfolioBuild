#!/usr/bin/env python3
"""Shared authentication rules for the QM live-deployment pointer / deploy-stamp.

Single, ASCII, stdlib-only, side-effect-free encoding of the checks that decide
whether a signed deploy pointer authentically binds a given manifest.

WHY THIS MODULE EXISTS
----------------------
Two consumers apply the *same* rules and must never drift:

  * ``morning_brief.py`` -- its Deploy lamp (`_authenticate_deploy`) turns the
    result into a GRUEN/GELB/UNBEKANNT/ROT lamp with German operator notes.
  * ``verify_live_deployment_contract.py`` -- its pointer binding turns the result
    into VERIFIED / UNKNOWN / MISMATCH per identity field.

``verify_live_deployment_contract.py`` imports this module and consumes its
machine-readable reason *codes* + *ranks*. ``morning_brief.py`` was intentionally
**not** refactored to import it: its canonical notes are German (non-ASCII) and
this file is deliberately ASCII-only, so re-expressing those notes here (or moving
them onto changed lines in a live-critical file) was avoided. The two
implementations are instead kept in lockstep by an explicit *parity test*
(``tests/test_verify_pointer_binding.py::test_shared_auth_matches_morning_brief``)
that runs identical inputs through both and asserts the rank <-> lamp-level
correspondence. If morning_brief's rules ever change, that test fails loudly.

RANKS
-----
The four ranks mirror ``morning_brief._LEVEL_RANK`` order EXACTLY, so a rank maps
1:1 onto that lamp's level and ``worst == max(rank)`` matches ``morning_brief._worst``:

    RANK_OK            0   clean                           (GRUEN)
    RANK_DEGRADED      1   a required auth field missing   (GELB)
    RANK_UNCORROBORATED 2  manifest carries no bindable    (UNBEKANNT)
                           account -> cannot corroborate
    RANK_CONFLICT      3   sha / account MISMATCH -- tamper (ROT)
                           or wrong file

An UNCORROBORATED (rank 2) result is deliberately worse than a DEGRADED (rank 1)
one: a missing field can be added, but a manifest whose book has no account digits
cannot have its expected_account confirmed at all -- never green, never a silent
pass. This ordering is the whole point of the shared rank scale.
"""

from __future__ import annotations

import re
from dataclasses import dataclass, field
from typing import Callable, List, Optional, Union

RANK_OK = 0
RANK_DEGRADED = 1
RANK_UNCORROBORATED = 2
RANK_CONFLICT = 3

RANK_NAME = {
    RANK_OK: "OK",
    RANK_DEGRADED: "DEGRADED",
    RANK_UNCORROBORATED: "UNCORROBORATED",
    RANK_CONFLICT: "CONFLICT",
}

# Reason codes that represent a hard MISMATCH (tamper / wrong file), as opposed to
# a merely-missing authentication field. Consumers that distinguish "unsigned"
# (UNKNOWN) from "mismatch" key off these.
CONFLICT_CODES = frozenset({"MANIFEST_SHA_MISMATCH", "ACCOUNT_MISMATCH"})

_ACCOUNT_RE = re.compile(r"(\d{6,})")


@dataclass
class Reason:
    """One failed authentication check. ``detail`` is ASCII English only; each
    consumer renders its own operator-facing wording (morning_brief keeps its
    German notes)."""

    code: str
    rank: int
    detail: str


@dataclass
class DeployAuthResult:
    """Structured outcome of :func:`authenticate_deploy_stamp`.

    ``rank`` is the worst of the base rank (derived from ``src``) and every
    reason's rank -- identical to ``morning_brief._worst`` over the same checks."""

    rank: int
    reasons: List[Reason] = field(default_factory=list)

    @property
    def clean(self) -> bool:
        """True only when every check passed and the source was a runtime stamp."""
        return self.rank == RANK_OK

    @property
    def has_conflict(self) -> bool:
        """True when any check is a hard MISMATCH (tamper / wrong file)."""
        return any(r.rank == RANK_CONFLICT for r in self.reasons)

    def codes(self) -> List[str]:
        return [r.code for r in self.reasons]

    def details(self) -> List[str]:
        return [r.detail for r in self.reasons]


def parse_utc_epoch(s: Optional[str]):
    """Parse an ISO-8601 UTC stamp (trailing Z, offset, or naive) to an aware
    datetime, or ``None``. Mirrors ``morning_brief._parse_utc`` byte-for-byte so
    the epoch check decides identically in both consumers. Imported lazily to keep
    this module import-cheap and stdlib-only."""
    import datetime as _dt

    if not isinstance(s, str) or not s.strip():
        return None
    t = s.strip()
    if t.endswith("Z"):
        t = t[:-1] + "+00:00"
    try:
        d = _dt.datetime.fromisoformat(t)
    except ValueError:
        return None
    if d.tzinfo is None:
        d = d.replace(tzinfo=_dt.timezone.utc)
    return d


def book_account(book: Optional[str]) -> Optional[str]:
    """The bindable account digits embedded in a manifest ``book`` string (>=6
    digits), or ``None``. Same rule morning_brief and the verifier use elsewhere."""
    if not book:
        return None
    m = _ACCOUNT_RE.search(str(book))
    return m.group(1) if m else None


def authenticate_deploy_stamp(
    stamp: Optional[dict],
    src: str = "runtime_stamp",
    *,
    manifest_sha_actual: Union[str, None, Callable[[], Optional[str]]],
    manifest_status: Optional[str],
    manifest_book: Optional[str],
) -> DeployAuthResult:
    """Apply the deploy-stamp authentication rules to ``stamp``.

    This is the single source of truth for what makes a signed deploy pointer an
    *authentic* binding of a manifest. It performs NO I/O of its own: the caller
    supplies the recomputed manifest hash, status and book so the function stays
    pure and testable.

    Parameters
    ----------
    stamp : dict | None
        The deploy-pointer / stamp object (``signed``, ``approved_by``,
        ``manifest_sha256``, ``deployment_epoch_utc`` / ``deployment_epoch``,
        ``expected_account``, ``expected_phase``).
    src : str
        Provenance of the stamp: ``"runtime_stamp"`` (a real signed pointer),
        ``"override"`` (an ad-hoc/test manifest override with no stamp), or
        ``"repo_default"`` (the unauthenticated repo fallback). Matches
        ``morning_brief._resolve_deploy_stamp``'s vocabulary. ``repo_default``
        short-circuits to DEGRADED with a single reason, exactly as the lamp does.
    manifest_sha_actual : str | None | callable
        The recomputed lowercase-hex sha256 of the manifest FILE the stamp claims
        to bind, or ``None`` if unhashable. May be a zero-arg callable, evaluated
        lazily and ONLY when the stamp carries a claimed sha (so a stamp without a
        sha never triggers a file hash) -- matching morning_brief's laziness.
    manifest_status : str | None
        The manifest's own ``status`` (must be ``LIVE``).
    manifest_book : str | None
        The manifest's ``book`` (must embed a bindable account).

    Returns
    -------
    DeployAuthResult
        ``clean`` iff authentic. ``has_conflict`` iff a hard MISMATCH fired.
    """
    reasons: List[Reason] = []

    if src == "repo_default":
        return DeployAuthResult(
            RANK_DEGRADED,
            [Reason("REPO_DEFAULT_ONLY", RANK_DEGRADED,
                    "stamp is only the repo default, not a signed runtime pointer")],
        )

    if src == "override":
        base = RANK_DEGRADED
        reasons.append(Reason("OVERRIDE_NO_STAMP", RANK_DEGRADED,
                              "manifest override carries no signed deploy stamp"))
    else:
        base = RANK_OK

    stamp = stamp or {}

    # (a) signed flag must be explicitly True.
    if stamp.get("signed") is not True:
        reasons.append(Reason("SIGNED_NOT_TRUE", RANK_DEGRADED, "signed is not true"))

    # (b) a non-empty approver.
    if not str(stamp.get("approved_by") or "").strip():
        reasons.append(Reason("APPROVED_BY_MISSING", RANK_DEGRADED, "approved_by missing"))

    # (c) manifest sha present AND matching the recomputed file hash.
    claimed = str(stamp.get("manifest_sha256") or "").strip().lower()
    if not claimed:
        reasons.append(Reason("MANIFEST_SHA_MISSING", RANK_DEGRADED, "manifest_sha256 missing"))
    else:
        actual = manifest_sha_actual() if callable(manifest_sha_actual) else manifest_sha_actual
        actual = (actual or "").lower()
        if not actual:
            reasons.append(Reason("MANIFEST_NOT_HASHABLE", RANK_DEGRADED,
                                  "manifest file not hashable"))
        elif actual != claimed:
            reasons.append(Reason("MANIFEST_SHA_MISMATCH", RANK_CONFLICT,
                                  "manifest_sha256 mismatch (tamper / wrong manifest)"))

    # (d) a parseable deployment epoch.
    if parse_utc_epoch(stamp.get("deployment_epoch_utc") or stamp.get("deployment_epoch")) is None:
        reasons.append(Reason("EPOCH_MISSING", RANK_DEGRADED,
                              "deployment_epoch missing or unparseable"))

    # (e) a bindable account from the manifest book, plus a matching expected_account.
    exp_acct = str(stamp.get("expected_account") or "").strip()
    book = str(manifest_book or "")
    man_acct = book_account(book)
    if man_acct is None:
        reasons.append(Reason("ACCOUNT_UNBINDABLE", RANK_UNCORROBORATED,
                              "manifest book %r has no bindable account; expected_account "
                              "cannot be corroborated" % (book or "?")))
    if not exp_acct:
        reasons.append(Reason("EXPECTED_ACCOUNT_MISSING", RANK_DEGRADED,
                              "expected_account missing"))
    elif man_acct is not None and exp_acct != man_acct:
        reasons.append(Reason("ACCOUNT_MISMATCH", RANK_CONFLICT,
                              "expected_account != manifest account (%s != %s)"
                              % (exp_acct, man_acct)))

    # (f) a non-empty expected phase.
    if not str(stamp.get("expected_phase") or "").strip():
        reasons.append(Reason("PHASE_MISSING", RANK_DEGRADED, "expected_phase missing"))

    # (g) the manifest's own status must be LIVE.
    if str(manifest_status or "").upper() != "LIVE":
        reasons.append(Reason("STATUS_NOT_LIVE", RANK_DEGRADED,
                              "manifest status=%s (not LIVE)" % (manifest_status or "?")))

    rank = base
    for r in reasons:
        if r.rank > rank:
            rank = r.rank
    return DeployAuthResult(rank, reasons)
