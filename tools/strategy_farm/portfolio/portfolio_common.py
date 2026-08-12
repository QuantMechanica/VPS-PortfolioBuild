from __future__ import annotations

import datetime as dt
import hashlib
import json
import re
import sqlite3
from dataclasses import dataclass
from pathlib import Path
from typing import Any, Iterable, Sequence

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
    entry_time: int | None = None
    mae_acct: float | None = None


class FrozenStreamValidationError(ValueError):
    """A resize input is not an immutable, SHA-verified stream bundle."""


@dataclass(frozen=True)
class VerifiedStreamInfo:
    key: tuple[int, str]
    path: Path
    sha256: str
    size_bytes: int
    trade_count: int
    first_close_time: int | None
    last_close_time: int | None
    source_starting_capital: float
    source_risk_pct: float


@dataclass(frozen=True)
class FrozenStreamBundle:
    """Verified closed-trade streams plus the explicit scale of their source run.

    ``source_risk_pct`` is expressed in account percentage points (1.0 means one
    percent of the source account), never as a 0.01 fraction.  Requiring that scale
    next to every SHA prevents the historical ``raw dollars * risk_percent`` unit
    ambiguity in portfolio resize scripts.
    """

    manifest_path: Path
    manifest_sha256: str
    frozen_root: Path
    streams: dict[tuple[int, str], list[Trade]]
    info: dict[tuple[int, str], VerifiedStreamInfo]


def key_label(key: tuple[int, str]) -> str:
    return f"{key[0]}:{key[1]}"


def stream_path_key(path: Path) -> tuple[int, str]:
    stem = path.stem
    ea_token, separator, symbol_token = stem.partition("_")
    if not separator:
        raise ValueError(f"stream filename {path.name!r} does not contain an EA id and symbol")
    return int(ea_token), symbol_token.replace("_", ".")


# Basket EAs carry a logical composite work-item symbol (QM5_<id>_..., never a
# real MT5 symbol) but their q08 stream files are keyed by HOST symbol
# (volatile Common\Files) or by the logical name (durable store). Adversarial
# review b4e2a62b (2026-07-06) showed the one-sided candidate fix poisoned the
# BOOK: portfolio_candidates stores the logical symbol, load_streams could
# never match it, and every consumer of the book (admission -> hard error;
# assemble/correlation/manifest/MC -> SILENT drop of the sleeve) broke. The
# resolution therefore lives HERE, at the single choke point every consumer
# uses, and streams are returned under the ORIGINAL candidate key.
BASKET_SYMBOL_RE = re.compile(r"^QM5_\d+_", re.IGNORECASE)
REPO_EAS = Path(r"C:\QM\repo\framework\EAs")
HOST_SYMBOL_HEADER_RE = re.compile(r";\s*host_symbol\s*:\s*(\S+)", re.IGNORECASE)


def resolve_basket_stream_key(candidate: tuple[int, str], common_dir: Path):
    """Return ((ea, stream_key_symbol), note) for logical basket symbols, else (None, None).

    Order: '; host_symbol:' setfile header -> host-keyed stream file; logical-
    named stream file (durable-store layout). When BOTH exist, the NEWER file
    wins (review b4e2a62b: a refresh through the farmctl --log path updates
    only the logical name — a stale host copy must not shadow it). Fallback:
    unique non-logical <ea>_*.jsonl. Commission stays correct regardless of
    key: _load_one_stream prices each trade from the row's own symbol field."""
    ea, sym = candidate
    if not BASKET_SYMBOL_RE.match(str(sym)):
        return None, None
    stream_dir = common_dir / "QM" / "q08_trades"
    logical_name = f"{ea}_{str(sym).replace('.', '_')}.jsonl"
    logical_key = (int(ea), str(sym).replace("_", "."))
    logical_file = stream_dir / logical_name

    host = None
    host_note = None
    for sf in sorted(REPO_EAS.glob(f"QM5_{ea}_*/sets/*.set")):
        try:
            for line in sf.read_text(encoding="utf-8-sig").splitlines():
                m = HOST_SYMBOL_HEADER_RE.match(line.strip())
                if m:
                    host = m.group(1)
                    host_note = f"host_symbol_from_setfile:{sf.name}"
                    break
        except (OSError, UnicodeDecodeError):
            continue
        if host is not None:
            break

    if host is not None:
        host_file = stream_dir / f"{ea}_{host.replace('.', '_')}.jsonl"
        host_exists = host_file.exists()
        logical_exists = logical_file.exists()
        if host_exists and logical_exists:
            try:
                if logical_file.stat().st_mtime > host_file.stat().st_mtime:
                    return logical_key, f"logical_stream_newer:{logical_name}"
            except OSError:
                pass
            return (int(ea), host), host_note
        if host_exists:
            return (int(ea), host), host_note
        if logical_exists:
            return logical_key, f"logical_stream_fallback:{logical_name}"
        # Neither file present yet (e.g. volatile dir pre-run): keep the host
        # key so a later-appearing stream still matches.
        return (int(ea), host), host_note

    if logical_file.exists():
        return logical_key, f"logical_stream_fallback:{logical_name}"
    others = [p for p in stream_dir.glob(f"{ea}_*.jsonl") if p.name != logical_name]
    if len(others) == 1:
        sym_part = others[0].stem.split("_", 1)[1]
        resolved = re.sub(r"_([A-Z0-9]+)$", r".\1", sym_part)
        return (int(ea), resolved), f"unique_stream_fallback:{others[0].name}"
    return None, f"basket_stream_ambiguous:{len(others)}_candidates"


def _rework_blocked_eas(conn: sqlite3.Connection) -> set[int]:
    """EAs whose MOST RECENT build task is codex_review_rework-flagged.

    A rework-flagged build failed code review (wrong indicator vs card, new-bar
    ordering bug, ...) and must not enter a book until a fresh, clean cascade
    rebuilds it. farmctl guards this in the BUILD path, but the admission path
    had none — a flagged EA could still reach a book through its
    Q12_REVIEW_READY row (QM5_1556, 2026-07-08). read_candidates is the shared
    choke point every book-builder (manifest / admission / prop-optimizer) reads
    through, so the exclusion lives here. A later clean rebuild (newer build task
    without the flag) un-blocks the EA automatically."""
    try:
        rows = conn.execute(
            "SELECT payload_json, updated_at FROM tasks WHERE kind LIKE '%build%'"
        ).fetchall()
    except sqlite3.Error:
        return set()
    latest_ts: dict[int, str] = {}
    latest_flag: dict[int, bool] = {}
    for payload_json, updated_at in rows:
        if not payload_json:
            continue
        try:
            payload = json.loads(payload_json)
        except (ValueError, TypeError):
            continue
        ea = _coerce_ea_int(payload.get("ea_id"))
        if ea is None:
            continue
        ts = str(updated_at or "")
        if ea not in latest_ts or ts >= latest_ts[ea]:
            latest_ts[ea] = ts
            latest_flag[ea] = bool(payload.get("codex_review_rework"))
    return {ea for ea, flagged in latest_flag.items() if flagged}


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
        rework_blocked = _rework_blocked_eas(conn)
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
        if ea_int in rework_blocked:
            # Build failed code review — excluded from every book until a fresh
            # clean cascade rebuilds it. See _rework_blocked_eas.
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
    alias: dict[tuple[int, str], tuple[int, str]] = {}
    if candidates is not None:
        candidate_set = {
            (ce, str(symbol))
            for ea_id, symbol in candidates
            if (ce := _coerce_ea_int(ea_id)) is not None
        }
        # Review b4e2a62b: map basket candidates' logical keys to the file key
        # their stream actually lives under, and hand the trades back under the
        # ORIGINAL candidate key so every consumer stays keyed by candidate
        # identity. A file key that is itself a candidate is owned by that
        # candidate and never aliased away.
        for cand in candidate_set:
            resolved, _note = resolve_basket_stream_key(cand, common_dir)
            if resolved is not None and resolved != cand and resolved not in candidate_set:
                alias[resolved] = cand

    streams: dict[tuple[int, str], list[Trade]] = {}
    for path in sorted(q08_dir.glob("*.jsonl"), key=lambda item: item.name):
        key = stream_path_key(path)
        mapped = alias.get(key, key)
        if candidate_set is not None and mapped not in candidate_set:
            continue
        trades = _load_one_stream(path, mapped[0], mapped[1], model)
        streams[mapped] = trades
    return dict(sorted(streams.items(), key=lambda item: item[0]))


def load_frozen_stream_bundle(
    manifest_path: Path,
    *,
    expected_keys: Sequence[tuple[int, str]] | None = None,
    commission_model: CommissionModel | None = None,
) -> FrozenStreamBundle:
    """Load only SHA-pinned streams from a declared frozen root.

    This is the mandatory input path for portfolio resizing.  It deliberately does
    not discover files in MT5 ``Common\\Files``: those files are mutable exports and
    produced non-reproducible 23-sleeve recomputes in July 2026.  The caller supplies
    a JSON manifest with this minimal schema::

        {
          "schema_version": 1,
          "frozen": true,
          "frozen_root": "frozen_streams",
          "risk_scale": {
            "unit": "account_percent",
            "source_starting_capital": 100000,
            "source_risk_pct": 1.0
          },
          "streams": [
            {"ea_id": 100, "symbol": "EURUSD.DWX",
             "path": "100_EURUSD_DWX.jsonl", "sha256": "..."}
          ]
        }

    Paths must resolve below ``frozen_root`` and may not resolve into the mutable
    MT5 Common directory.  A bundle is rejected on any missing/extra key, duplicate,
    hash mismatch, invalid risk scale, or optional trade-count mismatch.
    """

    manifest = Path(manifest_path).resolve(strict=True)
    try:
        payload = json.loads(manifest.read_text(encoding="utf-8"))
    except (OSError, json.JSONDecodeError) as exc:
        raise FrozenStreamValidationError(f"invalid frozen stream manifest {manifest}: {exc}") from exc

    if payload.get("schema_version") != 1:
        raise FrozenStreamValidationError("frozen stream manifest schema_version must be 1")
    if payload.get("frozen") is not True:
        raise FrozenStreamValidationError("frozen stream manifest must contain frozen=true")

    root_token = payload.get("frozen_root")
    if not isinstance(root_token, str) or not root_token.strip():
        raise FrozenStreamValidationError("frozen_root is required")
    root_candidate = Path(root_token)
    if not root_candidate.is_absolute():
        root_candidate = manifest.parent / root_candidate
    try:
        frozen_root = root_candidate.resolve(strict=True)
    except OSError as exc:
        raise FrozenStreamValidationError(f"frozen_root does not exist: {root_candidate}") from exc
    if not frozen_root.is_dir():
        raise FrozenStreamValidationError(f"frozen_root is not a directory: {frozen_root}")
    if _is_mutable_mt5_common_path(frozen_root):
        raise FrozenStreamValidationError("frozen_root may not be MT5 Common\\Files")

    risk_scale = payload.get("risk_scale")
    if not isinstance(risk_scale, dict):
        raise FrozenStreamValidationError("risk_scale object is required")
    if risk_scale.get("unit") != "account_percent":
        raise FrozenStreamValidationError("risk_scale.unit must be 'account_percent'")
    default_capital = _positive_float(
        risk_scale.get("source_starting_capital"), "risk_scale.source_starting_capital"
    )
    default_risk_pct = _positive_float(
        risk_scale.get("source_risk_pct"), "risk_scale.source_risk_pct"
    )

    rows = payload.get("streams")
    if not isinstance(rows, list) or not rows:
        raise FrozenStreamValidationError("streams must be a non-empty list")

    model = commission_model if commission_model is not None else load_model()
    model.reset_degraded()
    streams: dict[tuple[int, str], list[Trade]] = {}
    info: dict[tuple[int, str], VerifiedStreamInfo] = {}
    seen_paths: set[Path] = set()
    for index, row in enumerate(rows):
        where = f"streams[{index}]"
        if not isinstance(row, dict):
            raise FrozenStreamValidationError(f"{where} must be an object")
        try:
            key = (int(row["ea_id"]), str(row["symbol"]))
        except (KeyError, TypeError, ValueError) as exc:
            raise FrozenStreamValidationError(f"{where} has invalid ea_id/symbol") from exc
        if not key[1]:
            raise FrozenStreamValidationError(f"{where}.symbol may not be empty")
        if key in streams:
            raise FrozenStreamValidationError(f"duplicate stream key {key_label(key)}")

        path_token = row.get("path")
        if not isinstance(path_token, str) or not path_token.strip():
            raise FrozenStreamValidationError(f"{where}.path is required")
        candidate = Path(path_token)
        if not candidate.is_absolute():
            candidate = frozen_root / candidate
        try:
            path = candidate.resolve(strict=True)
        except OSError as exc:
            raise FrozenStreamValidationError(f"{where}.path does not exist: {candidate}") from exc
        try:
            path.relative_to(frozen_root)
        except ValueError as exc:
            raise FrozenStreamValidationError(
                f"{where}.path escapes frozen_root: {path}"
            ) from exc
        if not path.is_file():
            raise FrozenStreamValidationError(f"{where}.path is not a file: {path}")
        if _is_mutable_mt5_common_path(path):
            raise FrozenStreamValidationError(f"{where}.path resolves into MT5 Common\\Files")
        if path in seen_paths:
            raise FrozenStreamValidationError(f"stream file reused by multiple sleeves: {path}")
        seen_paths.add(path)

        expected_sha = str(row.get("sha256", "")).strip().lower()
        if not re.fullmatch(r"[0-9a-f]{64}", expected_sha):
            raise FrozenStreamValidationError(f"{where}.sha256 must be 64 lowercase/uppercase hex chars")
        actual_sha = _sha256_file(path)
        if actual_sha != expected_sha:
            raise FrozenStreamValidationError(
                f"SHA256 mismatch for {key_label(key)}: expected {expected_sha}, got {actual_sha}"
            )

        source_capital = _positive_float(
            row.get("source_starting_capital", default_capital),
            f"{where}.source_starting_capital",
        )
        source_risk_pct = _positive_float(
            row.get("source_risk_pct", default_risk_pct), f"{where}.source_risk_pct"
        )
        loaded = _load_one_stream(path, key[0], key[1], model)
        declared_count = row.get("trade_count")
        if declared_count is not None:
            try:
                count = int(declared_count)
            except (TypeError, ValueError) as exc:
                raise FrozenStreamValidationError(f"{where}.trade_count must be an integer") from exc
            if count != len(loaded):
                raise FrozenStreamValidationError(
                    f"trade_count mismatch for {key_label(key)}: expected {count}, got {len(loaded)}"
                )
        close_times = [trade.time for trade in loaded]
        streams[key] = loaded
        info[key] = VerifiedStreamInfo(
            key=key,
            path=path,
            sha256=actual_sha,
            size_bytes=path.stat().st_size,
            trade_count=len(loaded),
            first_close_time=min(close_times) if close_times else None,
            last_close_time=max(close_times) if close_times else None,
            source_starting_capital=source_capital,
            source_risk_pct=source_risk_pct,
        )

    if expected_keys is not None:
        expected = {(int(ea_id), str(symbol)) for ea_id, symbol in expected_keys}
        actual = set(streams)
        missing = sorted(expected - actual)
        extra = sorted(actual - expected)
        if missing or extra:
            raise FrozenStreamValidationError(
                f"frozen bundle key mismatch: missing={missing!r}, extra={extra!r}"
            )

    return FrozenStreamBundle(
        manifest_path=manifest,
        manifest_sha256=_sha256_file(manifest),
        frozen_root=frozen_root,
        streams=dict(sorted(streams.items())),
        info=dict(sorted(info.items())),
    )


def _positive_float(value: Any, label: str) -> float:
    try:
        number = float(value)
    except (TypeError, ValueError) as exc:
        raise FrozenStreamValidationError(f"{label} must be a positive number") from exc
    if not (number > 0.0) or number == float("inf"):
        raise FrozenStreamValidationError(f"{label} must be a finite positive number")
    return number


def _sha256_file(path: Path) -> str:
    digest = hashlib.sha256()
    with path.open("rb") as fh:
        for chunk in iter(lambda: fh.read(1024 * 1024), b""):
            digest.update(chunk)
    return digest.hexdigest()


def _is_mutable_mt5_common_path(path: Path) -> bool:
    """Recognize the volatile MT5 export tree without depending on one username."""

    normalized = "/".join(part.lower() for part in path.resolve(strict=False).parts)
    return "/metaquotes/terminal/common/files" in normalized


def to_daily_pnl(trades: Iterable[Trade]) -> dict[dt.date, float]:
    daily: dict[dt.date, float] = {}
    for trade in trades:
        day = dt.datetime.fromtimestamp(trade.time, tz=dt.UTC).date()
        daily[day] = daily.get(day, 0.0) + trade.net_of_cost
    return dict(sorted(daily.items()))


def to_monthly_pnl(trades: Iterable[Trade]) -> dict[str, float]:
    """Calendar-month buckets ('YYYY-MM' -> summed net_of_cost). Used as the
    diversification-correlation basis for structural low-frequency sleeves whose
    daily series almost never overlap (a few trades per year => ~0 co-active days),
    where daily-PnL correlation is statistically empty."""
    monthly: dict[str, float] = {}
    for trade in trades:
        stamp = dt.datetime.fromtimestamp(trade.time, tz=dt.UTC)
        monthly[f"{stamp.year:04d}-{stamp.month:02d}"] = (
            monthly.get(f"{stamp.year:04d}-{stamp.month:02d}", 0.0) + trade.net_of_cost
        )
    return dict(sorted(monthly.items()))


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
            entry_time = row.get("entry_time")
            entry_time_value = None if entry_time is None else int(entry_time)
            mae_acct = row.get("mae_acct")
            mae_acct_value = None if mae_acct is None else float(mae_acct)
            cost = model.cost_round_trip(trade_symbol, volume, notional_value)
            trades.append(
                Trade(
                    ea_id=ea_id,
                    symbol=trade_symbol,
                    time=int(row["time"]),
                    entry_time=entry_time_value,
                    mae_acct=mae_acct_value,
                    net=net,
                    volume=volume,
                    notional=notional_value,
                    commission_cost=cost,
                    net_of_cost=net - cost,
                )
            )
    return trades
