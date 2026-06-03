from __future__ import annotations

import datetime as dt
import json
import re
import sqlite3
from dataclasses import dataclass
from pathlib import Path
from typing import Any, Iterable

try:
    import numpy as np
except ModuleNotFoundError:  # pragma: no cover - depends on local Python env
    np = None  # type: ignore[assignment]

try:
    from .commission import CommissionModel, load_model
except ImportError:  # pragma: no cover - direct script execution
    from commission import CommissionModel, load_model  # type: ignore


DEFAULT_COMMON_DIR = Path(
    r"C:\Users\Administrator\AppData\Roaming\MetaQuotes\Terminal\Common\Files"
)
DEFAULT_CANDIDATES_DB = Path(r"D:\QM\strategy_farm\state\farm_state.sqlite")
DEFAULT_ARTIFACT_DIR = Path(r"D:\QM\strategy_farm\artifacts\portfolio")
Q12_READY_STATES = ("Q12_REVIEW_READY",)


def _coerce_ea_int(ea_id: Any) -> int | None:
    """Portfolio keys are (int ea_id, symbol), but portfolio_candidates.ea_id stores
    the label form 'QM5_10692'. Normalize both to the integer 10692.
    NB: match QM5_(\\d+), not \\d+ — the latter grabs the '5' in the 'QM5' prefix."""
    if isinstance(ea_id, int):
        return ea_id
    s = str(ea_id)
    m = re.search(r"QM5_(\d+)", s)
    if m:
        return int(m.group(1))
    m2 = re.fullmatch(r"\s*(\d+)\s*", s)
    return int(m2.group(1)) if m2 else None


@dataclass(frozen=True)
class Trade:
    ea_id: int
    symbol: str
    time: int
    net: float
    volume: float
    notional: float | None
    commission_cost: float
    net_of_cost: float


def key_label(key: tuple[int, str]) -> str:
    return f"{key[0]}:{key[1]}"


def stream_path_key(path: Path) -> tuple[int, str]:
    stem = path.stem
    ea_token, separator, symbol_token = stem.partition("_")
    if not separator:
        raise ValueError(f"stream filename {path.name!r} does not contain an EA id and symbol")
    return int(ea_token), symbol_token.replace("_", ".")


def read_candidates(
    db_path: Path = DEFAULT_CANDIDATES_DB,
    *,
    ready_states: Iterable[str] = Q12_READY_STATES,
) -> list[tuple[int, str]]:
    if not db_path.exists():
        return []

    states = tuple(ready_states)
    if not states:
        return []

    placeholders = ",".join("?" for _ in states)
    conn: sqlite3.Connection | None = None
    try:
        conn = sqlite3.connect(db_path)
        rows = conn.execute(
            f"""
            SELECT DISTINCT ea_id, symbol
            FROM portfolio_candidates
            WHERE state IN ({placeholders})
            """,
            states,
        ).fetchall()
    except sqlite3.Error:
        return []
    finally:
        if conn is not None:
            conn.close()

    candidates: list[tuple[int, str]] = []
    for ea_id, symbol in rows:
        if symbol is None:
            continue
        symbol_text = str(symbol)
        if not symbol_text:
            continue
        ea_int = _coerce_ea_int(ea_id)
        if ea_int is None:
            continue
        candidates.append((ea_int, symbol_text))
    return sorted(set(candidates))


def load_streams(
    common_dir: Path,
    *,
    candidates: list[tuple[str, str]] | list[tuple[int, str]] | None = None,
    commission_model: CommissionModel | None = None,
) -> dict[tuple[int, str], list[Trade]]:
    model = commission_model if commission_model is not None else load_model()
    model.reset_degraded()

    q08_dir = common_dir / "QM" / "q08_trades"
    if not q08_dir.exists():
        return {}

    candidate_set: set[tuple[int, str]] | None = None
    if candidates is not None:
        candidate_set = {
            (ce, str(symbol))
            for ea_id, symbol in candidates
            if (ce := _coerce_ea_int(ea_id)) is not None
        }

    streams: dict[tuple[int, str], list[Trade]] = {}
    for path in sorted(q08_dir.glob("*.jsonl"), key=lambda item: item.name):
        key = stream_path_key(path)
        if candidate_set is not None and key not in candidate_set:
            continue
        trades = _load_one_stream(path, key[0], key[1], model)
        streams[key] = trades
    return dict(sorted(streams.items(), key=lambda item: item[0]))


def to_daily_pnl(trades: Iterable[Trade]) -> dict[dt.date, float]:
    daily: dict[dt.date, float] = {}
    for trade in trades:
        day = dt.datetime.fromtimestamp(trade.time, tz=dt.UTC).date()
        daily[day] = daily.get(day, 0.0) + trade.net_of_cost
    return dict(sorted(daily.items()))


def align(
    series_by_key: dict[tuple[int, str], dict[dt.date, float]],
) -> tuple[list[tuple[int, str]], list[dt.date], Any]:
    keys = sorted(series_by_key)
    dates = sorted({day for series in series_by_key.values() for day in series})
    if np is None:
        matrix = [[0.0 for _ in keys] for _ in dates]
    else:
        matrix = np.zeros((len(dates), len(keys)), dtype=float)
    date_index = {day: idx for idx, day in enumerate(dates)}
    for col, key in enumerate(keys):
        for day, value in series_by_key[key].items():
            if np is None:
                matrix[date_index[day]][col] = float(value)
            else:
                matrix[date_index[day], col] = float(value)
    return keys, dates, matrix


def _load_one_stream(
    path: Path,
    ea_id: int,
    symbol: str,
    model: CommissionModel,
) -> list[Trade]:
    trades: list[Trade] = []
    with path.open("r", encoding="utf-8") as fh:
        for line_number, line in enumerate(fh, start=1):
            line = line.strip()
            if not line:
                continue
            try:
                row = json.loads(line)
            except json.JSONDecodeError as exc:
                raise ValueError(f"{path}:{line_number} contains invalid JSON: {exc}") from exc
            if row.get("event") != "TRADE_CLOSED":
                continue

            trade_symbol = str(row.get("symbol") or symbol)
            net = float(row["net"])
            volume = float(row["volume"])
            notional = row.get("notional")
            notional_value = None if notional is None else float(notional)
            cost = model.cost_round_trip(trade_symbol, volume, notional_value)
            trades.append(
                Trade(
                    ea_id=ea_id,
                    symbol=trade_symbol,
                    time=int(row["time"]),
                    net=net,
                    volume=volume,
                    notional=notional_value,
                    commission_cost=cost,
                    net_of_cost=net - cost,
                )
            )
    return trades
