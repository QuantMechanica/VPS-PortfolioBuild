"""Explicit, hash-bound research inputs; no automatic discovery or outcome reads.

Synthetic-tested draft. Independent code/protocol approval is required before
empirical use. A matching hash proves identity, not economic or data validity.
"""
from __future__ import annotations

from collections import defaultdict
from dataclasses import dataclass
from datetime import date, datetime, timedelta, timezone
from hashlib import sha256
from math import isfinite
from pathlib import Path, PurePosixPath
import re
import struct
import subprocess
from typing import Iterable

from tools.strategy_farm.research.hyp1_causal_tags import DailyClose, WARMUP_START, OBSERVATION_END
from tools.strategy_farm.session_tools import hcc_m1_reader_0921 as hcc


def verify_bytes(data: bytes, expected_sha256: str) -> bytes:
    if not re.fullmatch(r"[0-9a-f]{64}", expected_sha256):
        raise ValueError("an exact lowercase SHA256 is required")
    if sha256(data).hexdigest() != expected_sha256:
        raise ValueError("input byte identity mismatch")
    return data


def read_git_blob(repo: Path, revision: str, relative_path: str, expected_sha256: str) -> bytes:
    """Return immutable raw bytes for identity/projection; never parse outcomes.

    The whole blob may be authenticated, but empirical consumers must project
    the permitted window before interpreting outcome fields. This function
    does not authorize consumption of the returned content.
    """
    rel = PurePosixPath(relative_path)
    if (not re.fullmatch(r"[0-9a-f]{40}", revision) or rel.is_absolute()
            or ".." in rel.parts or "\\" in relative_path or ":" in relative_path):
        raise ValueError("explicit Git revision and repository-relative path required")
    data = subprocess.check_output(["git", "-C", str(repo), "cat-file", "blob", f"{revision}:{rel.as_posix()}"])
    return verify_bytes(data, expected_sha256)


def read_hcc(path: Path, year: int, expected_sha256: str):
    """Read only the one declared annual archive, with no terminal fallback."""
    if year not in range(2018, 2025):
        raise ValueError("HCC year outside frozen 2018-2024 window")
    if path.name != f"{year}.hcc":
        raise ValueError("HCC path/year disagreement")
    data = verify_bytes(path.read_bytes(), expected_sha256)
    return tuple(hcc.iter_m1_bytes(data, label=str(path), allowed_year=year))


def timestamp_fingerprint(timestamps: Iterable[int]) -> str:
    """Hash ordered server-clock seconds; must be compared with external evidence."""
    digest = sha256()
    for value in timestamps:
        digest.update(struct.pack("<q", value))
    return digest.hexdigest()


@dataclass(frozen=True)
class DayCoverage:
    day: date
    status: str  # COMPLETE, CLOSED, UNVERIFIED
    authority_ref: str | None = None
    expected_timestamp_sha256: str | None = None


@dataclass(frozen=True)
class CoverageObservation:
    day: date
    status: str
    observed_minutes: int
    reason: str


def aggregate_daily(records, calendar: Iterable[DayCoverage]):
    """Qualified closes with explicit unknown days, never last-minute availability.

    COMPLETE/CLOSED labels require a separate reviewed coverage authority.
    Copying this archive's timestamp hash into a manifest is not such proof.
    A failed per-day check produces MISSING, retaining the day for reporting.
    Structural ambiguity (duplicates or unlisted days) refuses the input.
    """
    days = tuple(calendar)
    for i, d in enumerate(days):
        if not WARMUP_START <= d.day <= OBSERVATION_END:
            raise ValueError("calendar outside frozen input window")
        if i and d.day != days[i - 1].day + timedelta(days=1):
            raise ValueError("calendar must be contiguous, unique and ordered")
        if d.status not in {"COMPLETE", "CLOSED", "UNVERIFIED"}:
            raise ValueError("unknown coverage status")
        if d.status != "UNVERIFIED" and not d.authority_ref:
            raise ValueError("qualified coverage requires an authority reference")
        if d.status == "COMPLETE" and not re.fullmatch(r"[0-9a-f]{64}", d.expected_timestamp_sha256 or ""):
            raise ValueError("complete coverage requires an expected timestamp fingerprint")
    by_day = defaultdict(list)
    allowed = {d.day for d in days}
    previous = None
    for r in records:
        t = r[0]
        if not isinstance(t, int) or t % 60 or (previous is not None and t <= previous):
            raise ValueError("M1 timestamps must be integral, minute-aligned and strictly ordered")
        day = datetime.fromtimestamp(t, timezone.utc).date()  # Stored server clock, not UTC conversion.
        if day not in allowed:
            raise ValueError("M1 record outside declared calendar")
        previous = t
        by_day[day].append(r)
    closes, observations = [], []
    for d in days:
        bars = by_day[d.day]
        valid_prices = all(all(isfinite(v) and v > 0 for v in r[1:5])
                           and r[3] <= min(r[1], r[4]) <= max(r[1], r[4]) <= r[2]
                           for r in bars)
        if d.status == "UNVERIFIED":
            quality, reason = "MISSING", "COVERAGE_NOT_AUTHENTICATED"
        elif d.status == "CLOSED":
            quality, reason = ("CLOSED", "QUALIFIED_CLOSED") if not bars else ("MISSING", "CLOSED_DAY_HAS_RECORDS")
        elif not bars:
            quality, reason = "MISSING", "EXPECTED_OPEN_DAY_EMPTY"
        elif timestamp_fingerprint(r[0] for r in bars) != d.expected_timestamp_sha256:
            quality, reason = "MISSING", "TIMESTAMP_COVERAGE_MISMATCH"
        elif not valid_prices:
            quality, reason = "MISSING", "INVALID_OHLC"
        else:
            quality, reason = "VALID", "QUALIFIED_COMPLETE"
        closes.append(DailyClose(d.day, bars[-1][4] if quality == "VALID" else None, quality))
        observations.append(CoverageObservation(d.day, quality, len(bars), reason))
    return tuple(closes), tuple(observations)
