"""SQLite helpers for comparing mixed ISO-8601 timestamp text safely.

The farm historically wrote both ``YYYY-MM-DDTHH:MM:SS`` and
``YYYY-MM-DD HH:MM:SS`` values.  Raw lexical comparison is therefore unsafe.
Keep normalization in one expression so operational queries cannot drift.
"""

from __future__ import annotations

import re
import datetime as dt


_SQL_IDENTIFIER = re.compile(r"^[A-Za-z_][A-Za-z0-9_]*(?:\.[A-Za-z_][A-Za-z0-9_]*)?$")


def normalized_timestamp_sql(column: str = "updated_at") -> str:
    """Return a safe SQLite datetime expression for a trusted column name."""

    if not _SQL_IDENTIFIER.fullmatch(column):
        raise ValueError(f"unsafe SQLite timestamp column: {column!r}")
    return f"datetime(replace(substr({column},1,19),char(84),char(32)))"


def parse_timestamp(value: object) -> dt.datetime | None:
    """Parse the farm's supported timestamp shapes to a UTC-aware value."""

    text = str(value or "").strip()
    if not text:
        return None
    try:
        parsed = dt.datetime.fromisoformat(text.replace("Z", "+00:00"))
    except ValueError:
        return None
    if parsed.tzinfo is None:
        parsed = parsed.replace(tzinfo=dt.timezone.utc)
    return parsed.astimezone(dt.timezone.utc)
