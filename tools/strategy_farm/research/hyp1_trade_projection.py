"""Metadata-first projection of immutable JSONL; no post-2024 outcome decoding.

Draft research code. Independent review must approve this byte/metadata access
contract before empirical use. Raw bytes are authenticated, then top-level
event/entry/exit metadata decide whether outcome decoding is permitted.
"""
from __future__ import annotations

from dataclasses import dataclass
from datetime import datetime, timedelta, timezone
from hashlib import sha256
import json
from math import isfinite

from tools.strategy_farm.research.hyp1_causal_tags import OBSERVATION_START, OBSERVATION_END
from tools.strategy_farm.research.hyp1_inputs import verify_bytes

START = datetime.combine(OBSERVATION_START, datetime.min.time())
END = datetime.combine(OBSERVATION_END + timedelta(days=1), datetime.min.time())
METADATA_KEYS = frozenset({'event', 'entry_time', 'time'})


def _string_end(text: str, start: int) -> int:
    if text[start] != '"':
        raise ValueError('expected JSON string')
    cursor = start + 1
    while cursor < len(text):
        if text[cursor] == '\\':
            cursor += 2
        elif text[cursor] == '"':
            return cursor + 1
        else:
            cursor += 1
    raise ValueError('unterminated string')


def _value_end(text: str, start: int) -> int:
    """Locate a value without interpreting its number, string or object."""
    if text[start] == '"':
        return _string_end(text, start)
    if text[start] in '[{':
        stack, cursor = [text[start]], start + 1
        while cursor < len(text) and stack:
            char = text[cursor]
            if char == '"':
                cursor = _string_end(text, cursor)
                continue
            if char in '[{':
                stack.append(char)
            elif char in ']}':
                if stack.pop() != ("[" if char == ']' else "{"):
                    raise ValueError('unbalanced container')
            cursor += 1
        if stack:
            raise ValueError('unterminated container')
        return cursor
    cursor = start
    while cursor < len(text) and text[cursor] not in ',}]':
        cursor += 1
    if cursor == start or not text[start:cursor].strip():
        raise ValueError('missing value')
    return cursor


def metadata_only(line: bytes) -> dict:
    """Decode only top-level metadata; nested lookalike keys cannot select rows.

    All other values are scanned for delimiters but are not deserialized,
    returned or evaluated. Their exact bytes remain part of input identity.
    """
    text = line.decode('utf-8').strip()
    if not text.startswith('{'):
        raise ValueError('JSON object required')
    cursor, seen, result = 1, set(), {}
    while cursor < len(text):
        while cursor < len(text) and text[cursor].isspace():
            cursor += 1
        if cursor < len(text) and text[cursor] == '}':
            if text[cursor + 1:].strip():
                raise ValueError('trailing JSON data')
            return result
        stop = _string_end(text, cursor)
        key = json.loads(text[cursor:stop])
        if key in seen:
            raise ValueError('duplicate top-level key')
        seen.add(key)
        cursor = stop
        while cursor < len(text) and text[cursor].isspace():
            cursor += 1
        if cursor >= len(text) or text[cursor] != ':':
            raise ValueError('missing colon')
        cursor += 1
        while cursor < len(text) and text[cursor].isspace():
            cursor += 1
        stop = _value_end(text, cursor)
        if key in METADATA_KEYS:
            result[key] = json.loads(text[cursor:stop])
        cursor = stop
        while cursor < len(text) and text[cursor].isspace():
            cursor += 1
        if cursor < len(text) and text[cursor] == ',':
            cursor += 1
            if text[cursor:].lstrip().startswith('}'):
                raise ValueError('trailing comma')
        elif cursor >= len(text) or text[cursor] != '}':
            raise ValueError('missing object delimiter')
    raise ValueError('unterminated object')


def _server_stamp(value) -> datetime:
    if not isinstance(value, int) or isinstance(value, bool):
        raise ValueError('integral stored-server timestamp required')
    return datetime.fromtimestamp(value, timezone.utc).replace(tzinfo=None)


@dataclass(frozen=True)
class ProjectedTrade:
    line_number: int
    line_sha256: str
    state: str
    entry_server: datetime | None = None
    exit_server: datetime | None = None
    gross_profit: float | None = None
    reason: str | None = None


def project_stream(data: bytes, expected_sha256: str) -> tuple[ProjectedTrade, ...]:
    """Keep a disposition for every nonempty row; only CLOSED reads outcomes.

    RIGHT_CENSORED exposes the entry and window boundary, not the future exit or
    outcome. A closed-trade stream alone cannot prove all open positions exist
    in the population: report that limitation, never claim an as-of census.
    """
    verify_bytes(data, expected_sha256)
    out = []
    for number, line in enumerate(data.splitlines(), 1):
        if not line.strip():
            continue
        identity = {'line_number': number, 'line_sha256': sha256(line).hexdigest()}
        entry = exit_time = None
        try:
            meta = metadata_only(line)
            if meta.get('event') != 'TRADE_CLOSED':
                state = 'NON_CLOSED_EVENT'  # Retained; event-specific population audit still required.
            else:
                entry, exit_time = _server_stamp(meta.get('entry_time')), _server_stamp(meta.get('time'))
                if exit_time < entry:
                    raise ValueError('exit precedes entry')
                if exit_time < START or entry >= END:
                    state, entry, exit_time = 'OUTSIDE_WINDOW', None, None
                elif exit_time >= END:
                    state, exit_time = 'RIGHT_CENSORED', END
                else:
                    state = 'CLOSED'
            if state != 'CLOSED':
                out.append(ProjectedTrade(**identity, state=state, entry_server=entry, exit_server=exit_time))
                continue
            # The sole whole-row decode is after the temporal eligibility check.
            full = json.loads(line)
            value = full.get('profit')
            if isinstance(value, bool) or not isinstance(value, (int, float)) or not isfinite(value):
                raise ValueError('missing or nonfinite numeric gross profit')
            out.append(ProjectedTrade(**identity, state=state, entry_server=entry,
                                      exit_server=exit_time, gross_profit=float(value)))
        except (ValueError, TypeError, IndexError, OverflowError, OSError, UnicodeError) as exc:
            # Do not include raw line/value/error snippets that could expose held-out outcomes.
            out.append(ProjectedTrade(**identity, state='UNRESOLVED',
                                      reason=type(exc).__name__ + ':metadata_or_eligible_outcome_invalid'))
    return tuple(out)
