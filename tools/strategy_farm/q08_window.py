"""Canonical Q08 baseline-window resolution.

The Q08 runner and every producer of a Q08 work item must bind the same
calendar.  Keeping the resolver here prevents queue payloads from inheriting a
Q02 canary window while the runner executes the Q08 full-history window.
"""
from __future__ import annotations

import csv
import hashlib
import re
from pathlib import Path
from typing import Any


SCHEMA = "qm.q08-phase-window/v1"
DEFAULT_FROM_DATE = "2017.01.01"
LATE_HISTORY_FROM_DATE = "2018.07.02"
TO_DATE = "2025.12.31"
_TIMEFRAME_RE = re.compile(
    r"_(MN1|W1|D1|H12|H8|H6|H4|H3|H2|H1|M30|M20|M15|M12|M10|M6|M5|M4|M3|M2|M1)_",
    re.IGNORECASE,
)


class Q08WindowError(ValueError):
    """The exact Q08 runtime window cannot be proven."""


def _sha256_file(path: Path) -> str:
    digest = hashlib.sha256()
    with path.open("rb") as handle:
        for block in iter(lambda: handle.read(1024 * 1024), b""):
            digest.update(block)
    return digest.hexdigest()


def host_symbol_from_setfile(setfile: Path, fallback: str) -> str:
    """Resolve a basket host symbol; ordinary setfiles retain ``fallback``."""
    try:
        for line in setfile.read_text(encoding="utf-8-sig").splitlines():
            match = re.match(
                r";\s*host_symbol\s*:\s*(\S+)",
                line.strip(),
                flags=re.IGNORECASE,
            )
            if match:
                return match.group(1)
    except (OSError, UnicodeDecodeError) as exc:
        raise Q08WindowError(f"Q08_SETFILE_UNREADABLE:{setfile}") from exc
    return str(fallback or "").strip()


def timeframe_from_setfile(setfile: Path) -> str:
    match = _TIMEFRAME_RE.search(f"_{setfile.stem}_")
    if match is None:
        raise Q08WindowError(f"Q08_TIMEFRAME_UNAVAILABLE:{setfile}")
    return match.group(1).upper()


def resolve_q08_window(
    repo_root: Path,
    setfile_path: str | Path,
    logical_symbol: str,
) -> dict[str, Any]:
    """Return the exact calendar used by the Q08 baseline runner.

    Resolution is deliberately fail closed when no registry row exists.  The
    runner's established contract maps every registry first year from 2018
    onward to the DWX late-history floor (2018-07-02); this function mirrors
    that behavior exactly so the queue seal cannot drift from execution.
    """
    root = Path(repo_root).resolve()
    setfile = Path(setfile_path).resolve()
    if not setfile.is_file():
        raise Q08WindowError(f"Q08_SETFILE_MISSING:{setfile}")
    symbol = host_symbol_from_setfile(setfile, logical_symbol)
    if not symbol:
        raise Q08WindowError("Q08_HOST_SYMBOL_UNAVAILABLE")
    timeframe = timeframe_from_setfile(setfile)
    registry = root / "framework" / "registry" / "dwx_symbol_history_ranges.csv"
    if not registry.is_file():
        raise Q08WindowError(f"Q08_HISTORY_REGISTRY_MISSING:{registry}")

    selected: dict[str, str] | None = None
    try:
        with registry.open("r", encoding="utf-8-sig", newline="") as handle:
            for row in csv.DictReader(handle):
                if (
                    str(row.get("symbol") or "").casefold() == symbol.casefold()
                    and str(row.get("period") or "").casefold()
                    == timeframe.casefold()
                ):
                    selected = dict(row)
                    break
    except (OSError, UnicodeError, csv.Error) as exc:
        raise Q08WindowError(f"Q08_HISTORY_REGISTRY_UNREADABLE:{registry}") from exc
    if selected is None:
        raise Q08WindowError(
            f"Q08_HISTORY_RANGE_UNAVAILABLE:{symbol}:{timeframe}"
        )
    try:
        first_year = int(selected.get("first_year") or 0)
        last_year = int(selected.get("last_year") or 0)
    except (TypeError, ValueError) as exc:
        raise Q08WindowError(
            f"Q08_HISTORY_RANGE_INVALID:{symbol}:{timeframe}"
        ) from exc
    if first_year <= 0 or last_year <= 0:
        raise Q08WindowError(
            f"Q08_HISTORY_RANGE_INVALID:{symbol}:{timeframe}"
        )
    if first_year <= 2017:
        from_date = DEFAULT_FROM_DATE
    elif first_year >= 2018:
        from_date = LATE_HISTORY_FROM_DATE
    return {
        "schema": SCHEMA,
        "from_date": from_date,
        "to_date": TO_DATE,
        "logical_symbol": str(logical_symbol),
        "host_symbol": symbol,
        "timeframe": timeframe,
        "history_first_year": first_year,
        "history_last_year": last_year,
        "history_registry_path": str(registry),
        "history_registry_sha256": _sha256_file(registry),
        "setfile_path": str(setfile),
    }
