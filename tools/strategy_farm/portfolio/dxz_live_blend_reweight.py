"""Deterministic, analysis-only DXZ live/backtest volatility blend.

The live terminal logs do not contain authoritative per-magic realised PnL.  This
tool therefore consumes an *offline, frozen* MT5 deal-history export.  It never
connects to a terminal, changes presets, or applies weights.

Canonical deal CSV fields (MetaTrader5 JSON field aliases are also accepted):

    deal_id,position_id,time_utc,type,entry,magic,symbol,volume,
    profit,swap,commission,fee

``type`` must be BUY/SELL (or MT5 numeric 0/1) and ``entry`` must be IN, OUT,
or OUT_BY (or MT5 numeric 0/1/3).  Opening-deal commission is retained.  A
broker-side closing deal with magic=0 is attributed through the opening
position_id.  Ambiguous or unknown ownership fails closed.

The proposed estimator is a variance blend::

    alpha = min(observed_live_sessions / 42, 1)
    blended_vol = sqrt((1-alpha)*backtest_vol^2 + alpha*live_vol^2)

Live cash PnL is first divided by the RISK_PERCENT in force, placing it on the
same 1%-risk basis as the sealed RISK_FIXED=1000 / 100k backtest streams.  A
leakage-free walk-forward test compares baseline and blended volatility forecast
error before any proposal can become OWNER-review eligible.
"""

from __future__ import annotations

import argparse
import csv
import hashlib
import json
import math
import re
import shutil
import sys
from collections import defaultdict
from dataclasses import dataclass
from datetime import date, datetime, timedelta, timezone
from pathlib import Path
from typing import Any, Iterable, Mapping, Sequence

REPO_ROOT = Path(__file__).resolve().parents[3]
if str(REPO_ROOT) not in sys.path:
    sys.path.insert(0, str(REPO_ROOT))

from tools.strategy_farm.portfolio.commission import CommissionModel
from tools.strategy_farm.portfolio.portfolio_common import load_streams


SCHEMA_VERSION = 1
DEFAULT_TOTAL_RISK = 9.75
DEFAULT_SLEEVE_CAP = 1.0
DEFAULT_BLEND_WINDOW = 42
DEFAULT_MIN_LIVE_DEALS = 2
DEFAULT_MIN_PROPOSAL_SESSIONS = 21
DEFAULT_OOS_TRAIN_DAYS = 252
DEFAULT_OOS_HORIZON_DAYS = 21
DEFAULT_OOS_STEP_DAYS = 63
DEFAULT_OOS_OBSERVATION_DAYS = (10, 21, 42)
MONEY_FIELDS = ("profit", "swap", "commission", "fee")
LIVE_ROOTS = (Path(r"C:\QM\mt5\T_Live"), Path(r"D:\QM\mt5\T_Live"))
# Backwards-compatible name used by older focused tests and evidence readers.
LIVE_ROOT = LIVE_ROOTS[0]
EXPECTED_ACCOUNT_LOGIN = "4000090541"
EXPECTED_SERVER = "Darwinex-Live"
EXPECTED_EXPORT_SCOPE = "ALL_ACCOUNT_DEALS_UNFILTERED"
FINAL24_LIVE_START = date(2026, 7, 20)
FINAL24_MANIFEST_SHA256 = "5ce872cc4ff92fe849edcfbcb9d1fd8e4e75d0b0d9892cdc025f6590f008fb8a"
FINAL24_DECISION_SHA256 = "41d202525796f67429d39f2676392e7139327321e6608debc7f905662619eeee"
FINAL24_BASELINE_FINGERPRINT_SHA256 = "d40b26fe56d4ce1cd6082413a566a4c5b6f3ac2e8f1e3ce8b80ba13d2103e495"
TASK_ID = "f1c19271-dbff-4694-a302-327605a59616"
# raw magic -> (EA id, exact registry symbol, logical host magic).  These are the
# only non-host magics deployed as components of a Final-24 logical sleeve.
EXPLICIT_COMPOSITE_MAGIC_ALIASES = {
    127780001: (12778, "EURJPY.DWX", 127780000),
    131170001: (13117, "AUDJPY.DWX", 131170000),
}
COMMISSION_REGISTRY = (
    REPO_ROOT / "framework" / "registry" / "live_commission.json"
)
COMMISSION_SOURCE = REPO_ROOT / "tools" / "strategy_farm" / "portfolio" / "commission.py"
PORTFOLIO_COMMON_SOURCE = (
    REPO_ROOT / "tools" / "strategy_farm" / "portfolio" / "portfolio_common.py"
)
EPSILON = 1e-12


class InputError(ValueError):
    """Raised when evidence is incomplete or ambiguous."""


@dataclass(frozen=True, order=True)
class Sleeve:
    ea_id: int
    symbol: str
    magic: int
    current_risk_percent: float
    expected_trades: int | None = None

    @property
    def key(self) -> str:
        return f"{self.ea_id}:{self.symbol}"


@dataclass(frozen=True)
class Deal:
    deal_id: int
    position_id: int
    time_utc: datetime
    deal_type: str
    entry: str
    magic: int
    symbol: str
    volume: float
    profit: float
    swap: float
    commission: float
    fee: float

    @property
    def net(self) -> float:
        return self.profit + self.swap + self.commission + self.fee


@dataclass(frozen=True)
class RiskRegime:
    magic: int
    effective_from: date
    effective_to: date | None
    risk_percent: float

    def covers(self, day: date) -> bool:
        return day >= self.effective_from and (
            self.effective_to is None or day <= self.effective_to
        )


@dataclass(frozen=True)
class MagicRoute:
    logical_magic: int
    expected_symbol: str


@dataclass
class PositionState:
    logical_magic: int
    opening_magic: int
    expected_symbol: str
    risk_percent: float
    open_volume: float = 0.0
    lifecycle_net: float = 0.0
    closed: bool = False


def _normalise_symbol(value: Any) -> str:
    text = str(value or "").strip().upper()
    if not text:
        raise InputError("empty symbol")
    return text


def _broker_symbol(value: Any) -> str:
    """Compare live broker symbols with registry `.DWX` names deterministically."""

    text = _normalise_symbol(value)
    return text.removesuffix(".DWX")


def _as_int(value: Any, field: str) -> int:
    if value is None or str(value).strip() == "":
        raise InputError(f"missing {field}")
    try:
        return int(value)
    except (TypeError, ValueError) as exc:
        raise InputError(f"invalid {field}: {value!r}") from exc


def _as_float(value: Any, field: str, *, default: float | None = None) -> float:
    if value is None or str(value).strip() == "":
        if default is not None:
            return default
        raise InputError(f"missing {field}")
    try:
        result = float(str(value).replace(",", "."))
    except (TypeError, ValueError) as exc:
        raise InputError(f"invalid {field}: {value!r}") from exc
    if not math.isfinite(result):
        raise InputError(f"non-finite {field}: {value!r}")
    return result


def _parse_date(value: Any, field: str) -> date:
    text = str(value or "").strip()
    try:
        return date.fromisoformat(text)
    except ValueError as exc:
        raise InputError(f"invalid {field} date: {value!r}") from exc


def _parse_time_utc(value: Any) -> datetime:
    if isinstance(value, (int, float)) or str(value).strip().isdigit():
        try:
            return datetime.fromtimestamp(int(value), tz=timezone.utc)
        except (OverflowError, OSError, ValueError) as exc:
            raise InputError(f"invalid time_utc epoch: {value!r}") from exc
    text = str(value or "").strip()
    if not text:
        raise InputError("missing time_utc")
    text = text.replace("Z", "+00:00")
    for candidate in (text, text.replace(".", "-", 2)):
        try:
            parsed = datetime.fromisoformat(candidate)
            if parsed.tzinfo is None:
                raise InputError(
                    f"time_utc must include a UTC offset (got naive {value!r})"
                )
            return parsed.astimezone(timezone.utc)
        except ValueError:
            continue
    raise InputError(f"invalid time_utc: {value!r}")


def _field(row: Mapping[str, Any], *names: str, default: Any = None) -> Any:
    lowered = {str(key).strip().lower(): value for key, value in row.items()}
    for name in names:
        if name.lower() in lowered:
            return lowered[name.lower()]
    return default


def _normalise_deal_type(value: Any) -> str:
    numeric = {0: "BUY", 1: "SELL"}
    try:
        if str(value).strip().lstrip("-").isdigit():
            code = int(value)
            return numeric.get(code, f"NON_TRADE_{code}")
    except (TypeError, ValueError):
        pass
    text = str(value or "").strip().upper()
    text = text.removeprefix("DEAL_TYPE_")
    if text in {"BUY", "SELL"}:
        return text
    return f"NON_TRADE_{text or 'UNKNOWN'}"


def _normalise_entry(value: Any) -> str:
    numeric = {0: "IN", 1: "OUT", 2: "INOUT", 3: "OUT_BY"}
    if str(value).strip().lstrip("-").isdigit():
        return numeric.get(int(value), f"UNKNOWN_{value}")
    text = str(value or "").strip().upper().replace(" ", "_")
    return text.removeprefix("DEAL_ENTRY_")


def sha256_file(path: Path) -> str:
    digest = hashlib.sha256()
    with path.open("rb") as handle:
        while chunk := handle.read(1024 * 1024):
            digest.update(chunk)
    return digest.hexdigest()


def _canonical_json(path: Path, payload: Any) -> None:
    path.write_text(
        json.dumps(payload, indent=2, sort_keys=True, ensure_ascii=False) + "\n",
        encoding="utf-8",
        newline="\n",
    )


def _write_csv(path: Path, fieldnames: Sequence[str], rows: Iterable[Mapping[str, Any]]) -> None:
    with path.open("w", encoding="utf-8", newline="") as handle:
        writer = csv.DictWriter(handle, fieldnames=list(fieldnames), lineterminator="\n")
        writer.writeheader()
        for row in rows:
            writer.writerow({name: row.get(name, "") for name in fieldnames})


def _path_is_under(path: Path, root: Path) -> bool:
    try:
        path.resolve().relative_to(root.resolve())
        return True
    except (ValueError, FileNotFoundError):
        return False


def validate_output_dir(path: Path) -> None:
    for live_root in LIVE_ROOTS:
        if _path_is_under(path, live_root):
            raise InputError(f"refusing to write under live terminal root: {path}")
    if path.exists() and any(path.iterdir()):
        raise InputError(f"immutable output directory is not empty: {path}")


def load_manifest(path: Path) -> tuple[dict[str, Any], list[Sleeve]]:
    try:
        payload = json.loads(path.read_text(encoding="utf-8-sig"))
    except (OSError, json.JSONDecodeError) as exc:
        raise InputError(f"manifest unreadable: {path}: {exc}") from exc
    if not isinstance(payload, dict) or not isinstance(payload.get("sleeves"), list):
        raise InputError("manifest must contain a sleeves array")
    declared = _as_int(payload.get("n_sleeves"), "manifest.n_sleeves")
    if declared != 24 or len(payload["sleeves"]) != 24:
        raise InputError(
            f"Final-24 required: declared={declared}, rows={len(payload['sleeves'])}"
        )
    sleeves: list[Sleeve] = []
    seen_magics: set[int] = set()
    seen_keys: set[str] = set()
    for raw in payload["sleeves"]:
        if not isinstance(raw, dict):
            raise InputError("manifest sleeve row is not an object")
        sleeve = Sleeve(
            ea_id=_as_int(raw.get("ea_id"), "ea_id"),
            symbol=_normalise_symbol(raw.get("symbol")),
            magic=_as_int(raw.get("magic_number"), "magic_number"),
            current_risk_percent=_as_float(
                raw.get("risk_percent", raw.get("weight")), "risk_percent"
            ),
            expected_trades=_as_int(raw.get("trades"), "trades"),
        )
        if sleeve.magic in seen_magics:
            raise InputError(f"duplicate manifest magic {sleeve.magic}")
        if sleeve.key in seen_keys:
            raise InputError(f"duplicate manifest sleeve {sleeve.key}")
        if sleeve.current_risk_percent <= 0 or sleeve.current_risk_percent > DEFAULT_SLEEVE_CAP + EPSILON:
            raise InputError(
                f"manifest risk outside (0,{DEFAULT_SLEEVE_CAP}]: {sleeve.key}="
                f"{sleeve.current_risk_percent}"
            )
        if sleeve.expected_trades is None or sleeve.expected_trades <= 0:
            raise InputError(f"manifest trade count must be positive: {sleeve.key}")
        expectation = raw.get("set_file_expectation")
        if not isinstance(expectation, dict):
            raise InputError(f"manifest set-file expectation missing: {sleeve.key}")
        if _as_float(expectation.get("RISK_FIXED"), "RISK_FIXED") != 0.0:
            raise InputError(f"live manifest RISK_FIXED must be zero: {sleeve.key}")
        if abs(
            _as_float(expectation.get("RISK_PERCENT"), "RISK_PERCENT")
            - sleeve.current_risk_percent
        ) > 0.000001:
            raise InputError(f"manifest RISK_PERCENT mismatch: {sleeve.key}")
        if _as_float(expectation.get("PORTFOLIO_WEIGHT"), "PORTFOLIO_WEIGHT") != 1.0:
            raise InputError(f"live manifest PORTFOLIO_WEIGHT must be one: {sleeve.key}")
        backtest_set = Path(str(raw.get("backtest_set", "")))
        try:
            set_values = {}
            for line in backtest_set.read_text(encoding="utf-8-sig").splitlines():
                if "=" not in line or line.lstrip().startswith((";", "#")):
                    continue
                name, value = line.split("=", 1)
                set_values[name.strip().upper()] = value.split("||", 1)[0].strip()
        except OSError as exc:
            raise InputError(f"backtest set unreadable for {sleeve.key}: {backtest_set}: {exc}") from exc
        if _as_float(set_values.get("RISK_FIXED"), "RISK_FIXED") <= 0:
            raise InputError(f"backtest set RISK_FIXED must be positive: {sleeve.key}")
        if _as_float(set_values.get("RISK_PERCENT"), "RISK_PERCENT") != 0.0:
            raise InputError(f"backtest set RISK_PERCENT must be zero: {sleeve.key}")
        seen_magics.add(sleeve.magic)
        seen_keys.add(sleeve.key)
        sleeves.append(sleeve)
    total = _as_float(payload.get("total_risk_pct", DEFAULT_TOTAL_RISK), "total_risk_pct")
    if abs(sum(row.current_risk_percent for row in sleeves) - total) > 0.001:
        raise InputError("manifest sleeve risk does not reconcile to total_risk_pct")
    if payload.get("manual_approval_required") is not True:
        raise InputError("manifest must require manual approval")
    return payload, sorted(sleeves)


def verify_live_decision(path: Path) -> None:
    try:
        text = path.read_text(encoding="utf-8-sig")
    except OSError as exc:
        raise InputError(f"decision record unreadable: {path}: {exc}") from exc
    required = ("OWNER-Freigabe", "SCHLUSSVERIFY", "24/24", "AutoTrading")
    missing = [token for token in required if token not in text]
    if missing:
        raise InputError(f"decision record lacks final-live proof tokens: {missing}")
    actual_sha = sha256_file(path)
    if actual_sha != FINAL24_DECISION_SHA256:
        raise InputError(
            "decision record is not the pinned OWNER Final-24 decision: "
            f"expected {FINAL24_DECISION_SHA256}, got {actual_sha}"
        )


def verify_staging_manifest_link(
    path: Path,
    manifest_path: Path,
    sleeves: Sequence[Sleeve],
) -> None:
    """Bind the supplied DRAFT-named manifest to the OWNER-deployed Final-24."""

    try:
        payload = json.loads(path.read_text(encoding="utf-8-sig"))
    except (OSError, json.JSONDecodeError) as exc:
        raise InputError(f"staging report unreadable: {path}: {exc}") from exc
    expected_sha = str(payload.get("manifest_sha256", "")).strip().lower()
    actual_sha = sha256_file(manifest_path)
    if expected_sha != actual_sha:
        raise InputError(
            f"staging report manifest SHA mismatch: expected {expected_sha}, got {actual_sha}"
        )
    if payload.get("warnings") not in ([], None):
        raise InputError(f"staging report contains warnings: {payload.get('warnings')!r}")
    deployed_rows = len(payload.get("existing", [])) + len(payload.get("new", []))
    if deployed_rows != len(sleeves):
        raise InputError(
            f"staging report sleeve count mismatch: expected {len(sleeves)}, got {deployed_rows}"
        )
    staged_sum = _as_float(payload.get("sum_risk_percent"), "sum_risk_percent")
    manifest_sum = sum(sleeve.current_risk_percent for sleeve in sleeves)
    if abs(staged_sum - manifest_sum) > 0.0001:
        raise InputError(
            f"staging/manifest risk mismatch: staged={staged_sum}, manifest={manifest_sum}"
        )
    news_age = _as_float(payload.get("news_age_hours"), "news_age_hours")
    if news_age > 336.0:
        raise InputError(f"staging news evidence is stale: {news_age}h > 336h")


def load_magic_registry(path: Path, sleeves: Sequence[Sleeve]) -> dict[int, MagicRoute]:
    """Return a strict deal-magic attribution route.

    Every manifest magic must match an active registry EA+symbol exactly.
    Secondary mappings are an explicit Final-24 basket contract; there is no
    unique-EA heuristic that could silently merge a later unrelated symbol.
    """
    try:
        with path.open("r", encoding="utf-8-sig", newline="") as handle:
            rows = list(csv.DictReader(handle))
    except OSError as exc:
        raise InputError(f"magic registry unreadable: {path}: {exc}") from exc
    active: dict[int, tuple[int, str]] = {}
    for row in rows:
        try:
            magic = int(row.get("magic", ""))
            ea_id = int(row.get("ea_id", ""))
        except ValueError:
            continue
        if str(row.get("status", "")).strip().lower() != "active":
            continue
        active[magic] = (ea_id, _normalise_symbol(row.get("symbol")))
    aliases: dict[int, MagicRoute] = {}
    manifest_magics = {sleeve.magic for sleeve in sleeves}
    for sleeve in sleeves:
        registered = active.get(sleeve.magic)
        expected = (sleeve.ea_id, sleeve.symbol)
        if registered != expected:
            raise InputError(
                f"manifest magic {sleeve.magic} registry mismatch: "
                f"expected={expected!r}, registered={registered!r}"
            )
        aliases[sleeve.magic] = MagicRoute(sleeve.magic, sleeve.symbol)
    for alias, (expected_ea, expected_symbol, logical) in EXPLICIT_COMPOSITE_MAGIC_ALIASES.items():
        if logical not in manifest_magics:
            continue
        alias_row = active.get(alias)
        logical_row = active.get(logical)
        if (
            alias_row != (expected_ea, expected_symbol)
            or logical_row is None
            or logical_row[0] != expected_ea
        ):
            raise InputError(f"explicit composite alias is not registry-valid: {alias}->{logical}")
        aliases[alias] = MagicRoute(logical, expected_symbol)
    return aliases


def _read_deal_rows(path: Path) -> list[Mapping[str, Any]]:
    suffix = path.suffix.lower()
    try:
        if suffix == ".csv":
            with path.open("r", encoding="utf-8-sig", newline="") as handle:
                return list(csv.DictReader(handle))
        if suffix == ".jsonl":
            rows = []
            with path.open("r", encoding="utf-8-sig") as handle:
                for line_no, line in enumerate(handle, 1):
                    if not line.strip():
                        continue
                    row = json.loads(line)
                    if not isinstance(row, dict):
                        raise InputError(f"deal JSONL line {line_no} is not an object")
                    rows.append(row)
            return rows
        if suffix == ".json":
            payload = json.loads(path.read_text(encoding="utf-8-sig"))
            if isinstance(payload, dict):
                payload = payload.get("deals")
            if not isinstance(payload, list) or not all(isinstance(row, dict) for row in payload):
                raise InputError("deal JSON must be an array or an object with deals[]")
            return payload
    except (OSError, json.JSONDecodeError) as exc:
        raise InputError(f"deal history unreadable: {path}: {exc}") from exc
    raise InputError("deal history must be .csv, .json, or .jsonl")


def load_deals(path: Path) -> list[Deal]:
    deals: list[Deal] = []
    seen: set[int] = set()
    for index, row in enumerate(_read_deal_rows(path), 1):
        deal_id = _as_int(_field(row, "deal_id", "ticket", "deal"), f"row {index} deal_id")
        if deal_id in seen:
            raise InputError(f"duplicate deal_id {deal_id}")
        seen.add(deal_id)
        deal_type = _normalise_deal_type(_field(row, "type", "deal_type"))
        time_utc = _parse_time_utc(_field(row, "time_utc", "time"))
        money: dict[str, float] = {}
        for name in MONEY_FIELDS:
            raw_value = _field(row, name)
            if raw_value is None or str(raw_value).strip() == "":
                raise InputError(f"deal {deal_id}: missing explicit {name}")
            money[name] = _as_float(raw_value, f"deal {deal_id} {name}")
        # A complete, unfiltered export can contain balance/charge/tax rows.  A
        # non-zero one cannot be assigned to a strategy lifecycle by magic and
        # must never silently disappear from a volatility estimate.
        if deal_type not in {"BUY", "SELL"}:
            if abs(sum(money.values())) > EPSILON:
                raise InputError(
                    f"deal {deal_id}: UNALLOCATED_FINANCIAL_CASHFLOW ({deal_type})"
                )
            continue
        entry = _normalise_entry(_field(row, "entry", "deal_entry"))
        if entry == "INOUT":
            raise InputError(f"deal {deal_id}: INOUT is ambiguous in v1")
        if entry not in {"IN", "OUT", "OUT_BY"}:
            raise InputError(f"deal {deal_id}: unsupported entry {entry!r}")
        position_id = _as_int(
            _field(row, "position_id", "position", "position_ticket"),
            f"deal {deal_id} position_id",
        )
        if position_id <= 0:
            raise InputError(f"deal {deal_id}: position_id must be positive")
        volume = _as_float(_field(row, "volume"), f"deal {deal_id} volume")
        if volume <= 0:
            raise InputError(f"deal {deal_id}: volume must be positive")
        magic = _as_int(_field(row, "magic", "magic_number", default=0), "magic")
        if entry == "IN" and magic == 0:
            raise InputError(f"deal {deal_id}: opening magic cannot be zero")
        deal = Deal(
            deal_id=deal_id,
            position_id=position_id,
            time_utc=time_utc,
            deal_type=deal_type,
            entry=entry,
            magic=magic,
            symbol=_normalise_symbol(_field(row, "symbol")),
            volume=volume,
            profit=money["profit"],
            swap=money["swap"],
            commission=money["commission"],
            fee=money["fee"],
        )
        deals.append(deal)
    return sorted(deals, key=lambda row: (row.time_utc, row.deal_id))


def verify_deal_export_metadata(
    path: Path,
    deal_path: Path,
    live_start: date,
    as_of: date,
    generated_at: datetime,
) -> dict[str, Any]:
    try:
        payload = json.loads(path.read_text(encoding="utf-8-sig"))
    except (OSError, json.JSONDecodeError) as exc:
        raise InputError(f"deal-export metadata unreadable: {path}: {exc}") from exc
    if not isinstance(payload, dict) or payload.get("schema_version") != 1:
        raise InputError("deal-export metadata schema_version must be 1")
    if str(payload.get("account_login", "")).strip() != EXPECTED_ACCOUNT_LOGIN:
        raise InputError("deal export is not for T_Live account 4000090541")
    if str(payload.get("server", "")).strip() != EXPECTED_SERVER:
        raise InputError("deal export server must be Darwinex-Live")
    if payload.get("complete") is not True:
        raise InputError("deal export must declare complete=true")
    if payload.get("read_only_export") is not True:
        raise InputError("deal export must declare read_only_export=true")
    source_kind = str(payload.get("source_kind", "")).strip()
    if source_kind != "MT5_ACCOUNT_HISTORY_EXPORT":
        raise InputError(f"unsupported deal export source_kind: {source_kind!r}")
    if str(payload.get("scope", "")).strip() != EXPECTED_EXPORT_SCOPE:
        raise InputError(f"deal export scope must be {EXPECTED_EXPORT_SCOPE}")
    if str(payload.get("deal_history_basename", "")).strip() != deal_path.name:
        raise InputError("deal export metadata basename does not match deal history")
    expected_sha = str(payload.get("deal_history_sha256", "")).strip().lower()
    actual_sha = sha256_file(deal_path)
    if expected_sha != actual_sha:
        raise InputError(
            f"deal export SHA mismatch: expected {expected_sha}, got {actual_sha}"
        )
    raw_count = len(_read_deal_rows(deal_path))
    if _as_int(payload.get("source_row_count"), "source_row_count") != raw_count:
        raise InputError(
            "deal export source_row_count mismatch: "
            f"metadata={payload.get('source_row_count')!r}, actual={raw_count}"
        )
    history_from = _parse_time_utc(payload.get("history_from_utc"))
    history_to_exclusive = _parse_time_utc(payload.get("history_to_utc_exclusive"))
    exported_at = _parse_time_utc(payload.get("exported_at_utc"))
    required_from = datetime.combine(live_start, datetime.min.time(), tzinfo=timezone.utc)
    required_to = datetime.combine(
        as_of + timedelta(days=1), datetime.min.time(), tzinfo=timezone.utc
    )
    if history_from != required_from:
        raise InputError("deal export must start exactly at live_start 00:00 UTC")
    if history_to_exclusive != required_to:
        raise InputError("deal export must end exactly after the complete as_of UTC day")
    if history_to_exclusive > exported_at:
        raise InputError("deal export cutoff is after exported_at_utc")
    if exported_at > generated_at:
        raise InputError("deal export was created after generated_at_utc")
    return payload


def load_risk_schedule(
    path: Path | None,
    sleeves: Sequence[Sleeve],
    live_start: date,
    as_of: date | None = None,
) -> dict[int, list[RiskRegime]]:
    regimes: dict[int, list[RiskRegime]] = defaultdict(list)
    if path is None:
        for sleeve in sleeves:
            regimes[sleeve.magic].append(
                RiskRegime(sleeve.magic, live_start, None, sleeve.current_risk_percent)
            )
        return dict(regimes)
    try:
        with path.open("r", encoding="utf-8-sig", newline="") as handle:
            rows = list(csv.DictReader(handle))
    except OSError as exc:
        raise InputError(f"risk schedule unreadable: {path}: {exc}") from exc
    expected = {row.magic for row in sleeves}
    for index, row in enumerate(rows, 1):
        magic = _as_int(row.get("magic"), f"risk row {index} magic")
        if magic not in expected:
            raise InputError(f"risk row {index}: unknown logical magic {magic}")
        start = _parse_date(row.get("effective_from"), "effective_from")
        raw_end = str(row.get("effective_to") or "").strip()
        end = _parse_date(raw_end, "effective_to") if raw_end else None
        risk = _as_float(row.get("risk_percent"), "risk_percent")
        if risk <= 0 or risk > DEFAULT_SLEEVE_CAP + EPSILON:
            raise InputError(f"risk row {index}: risk outside (0,1]: {risk}")
        if end is not None and end < start:
            raise InputError(f"risk row {index}: effective_to before effective_from")
        regimes[magic].append(RiskRegime(magic, start, end, risk))
    for magic in expected:
        rows_for_magic = sorted(regimes.get(magic, []), key=lambda row: row.effective_from)
        if not rows_for_magic:
            raise InputError(f"risk schedule missing magic {magic}")
        for previous, current in zip(rows_for_magic, rows_for_magic[1:]):
            if previous.effective_to is None or current.effective_from <= previous.effective_to:
                raise InputError(f"overlapping risk regimes for magic {magic}")
            if current.effective_from != previous.effective_to + timedelta(days=1):
                raise InputError(f"gapped risk regimes for magic {magic}")
        if as_of is not None:
            if not rows_for_magic[0].covers(live_start):
                raise InputError(f"risk schedule does not cover live_start for magic {magic}")
            if not rows_for_magic[-1].covers(as_of):
                raise InputError(f"risk schedule does not cover as_of for magic {magic}")
        regimes[magic] = rows_for_magic
    # v1 is the first post-deploy evidence cut.  Until a separately signed
    # reweight decision exists, the risk-at-entry schedule is exactly the pinned
    # July-20 manifest—not an operator-selectable normalization input.
    by_magic = {sleeve.magic: sleeve for sleeve in sleeves}
    for magic, rows_for_magic in regimes.items():
        if len(rows_for_magic) != 1:
            raise InputError(f"v1 risk schedule must have one pinned regime for magic {magic}")
        regime = rows_for_magic[0]
        sleeve = by_magic[magic]
        if regime.effective_from != live_start:
            raise InputError(f"v1 risk regime must start on {live_start} for magic {magic}")
        if abs(regime.risk_percent - sleeve.current_risk_percent) > 0.000001:
            raise InputError(f"v1 risk does not match pinned manifest for magic {magic}")
    if abs(
        sum(rows[0].risk_percent for rows in regimes.values()) - DEFAULT_TOTAL_RISK
    ) > 0.000001:
        raise InputError("v1 risk schedule must preserve TOTAL_RISK 9.75")
    return dict(regimes)


def _risk_on(regimes: Mapping[int, Sequence[RiskRegime]], magic: int, day: date) -> float:
    matches = [row for row in regimes.get(magic, ()) if row.covers(day)]
    if len(matches) != 1:
        raise InputError(
            f"risk schedule coverage for magic {magic} on {day}: expected 1, got {len(matches)}"
        )
    return matches[0].risk_percent


def attribute_deals(
    deals: Sequence[Deal],
    aliases: Mapping[int, MagicRoute],
    risk_schedule: Mapping[int, Sequence[RiskRegime]],
    live_start: date,
    as_of: date,
) -> tuple[
    list[dict[str, Any]],
    dict[int, dict[date, float]],
    dict[int, dict[date, float]],
    dict[int, int],
]:
    # A lifecycle is realised only when its position volume returns to zero.
    # This puts live PnL on the same close-day basis as the sealed Q08 streams
    # and counts a partially closed position zero times until it is truly flat.
    positions: dict[int, PositionState] = {}
    rows: list[dict[str, Any]] = []
    daily: dict[int, dict[date, float]] = defaultdict(lambda: defaultdict(float))
    daily_actual: dict[int, dict[date, float]] = defaultdict(lambda: defaultdict(float))
    closed_positions: dict[int, set[int]] = defaultdict(set)
    for deal in deals:
        day = deal.time_utc.date()
        if not (live_start <= day <= as_of):
            raise InputError(
                f"deal {deal.deal_id}: trade timestamp {day} is outside requested window"
            )
        raw_magic = deal.magic
        route = aliases.get(raw_magic)
        if deal.entry == "IN":
            if route is None:
                raise InputError(f"deal {deal.deal_id}: unknown opening magic {raw_magic}")
            if _broker_symbol(deal.symbol) != _broker_symbol(route.expected_symbol):
                raise InputError(
                    f"deal {deal.deal_id}: symbol {deal.symbol} does not match "
                    f"magic {raw_magic} route {route.expected_symbol}"
                )
            entry_risk = _risk_on(risk_schedule, route.logical_magic, day)
            state = positions.get(deal.position_id)
            if state is None:
                state = PositionState(
                    logical_magic=route.logical_magic,
                    opening_magic=raw_magic,
                    expected_symbol=route.expected_symbol,
                    risk_percent=entry_risk,
                )
                positions[deal.position_id] = state
            elif state.closed:
                raise InputError(f"position {deal.position_id}: reused after completed lifecycle")
            elif (
                state.logical_magic != route.logical_magic
                or state.opening_magic != raw_magic
                or _broker_symbol(state.expected_symbol) != _broker_symbol(deal.symbol)
            ):
                raise InputError(f"position {deal.position_id}: mixed magic or symbol on scale-in")
            elif abs(state.risk_percent - entry_risk) > EPSILON:
                raise InputError(
                    f"position {deal.position_id}: multiple entry-risk regimes are ambiguous"
                )
            state.open_volume += deal.volume
        else:
            state = positions.get(deal.position_id)
            if state is None:
                raise InputError(
                    f"deal {deal.deal_id}: closing position {deal.position_id} has no opening deal"
                )
            if state.closed:
                raise InputError(f"position {deal.position_id}: close after completed lifecycle")
            if raw_magic != 0:
                if route is None:
                    raise InputError(f"deal {deal.deal_id}: unknown closing magic {raw_magic}")
                if raw_magic != state.opening_magic:
                    raise InputError(
                        f"deal {deal.deal_id}: closing magic {raw_magic} differs from "
                        f"opening magic {state.opening_magic}"
                    )
            if _broker_symbol(deal.symbol) != _broker_symbol(state.expected_symbol):
                raise InputError(
                    f"deal {deal.deal_id}: closing symbol {deal.symbol} differs from "
                    f"opening route {state.expected_symbol}"
                )
            if deal.volume > state.open_volume + 0.00000001:
                raise InputError(
                    f"position {deal.position_id}: close volume {deal.volume} exceeds "
                    f"open volume {state.open_volume}"
                )
            state.open_volume = max(0.0, state.open_volume - deal.volume)
        logical_magic = state.logical_magic
        risk = state.risk_percent
        state.lifecycle_net += deal.net
        lifecycle_closed = deal.entry != "IN" and state.open_volume <= 0.00000001
        lifecycle_net = ""
        lifecycle_normalised = ""
        if lifecycle_closed:
            state.closed = True
            lifecycle_net = round(state.lifecycle_net, 8)
            lifecycle_normalised = round(state.lifecycle_net / risk, 8)
            daily[logical_magic][day] += state.lifecycle_net / risk
            daily_actual[logical_magic][day] += state.lifecycle_net
            closed_positions[logical_magic].add(deal.position_id)
        if risk <= 0:
            raise InputError(
                f"deal {deal.deal_id}: invalid opening risk for position {deal.position_id}"
            )
        normalised = deal.net / risk
        rows.append(
            {
                "deal_id": deal.deal_id,
                "position_id": deal.position_id,
                "time_utc": deal.time_utc.isoformat().replace("+00:00", "Z"),
                "entry": deal.entry,
                "deal_magic": deal.magic,
                "logical_magic": logical_magic,
                "symbol": deal.symbol,
                "volume": round(deal.volume, 8),
                "profit": round(deal.profit, 8),
                "swap": round(deal.swap, 8),
                "commission": round(deal.commission, 8),
                "fee": round(deal.fee, 8),
                "net_actual": round(deal.net, 8),
                "risk_percent_in_force": round(risk, 8),
                "net_per_1pct_risk": round(normalised, 8),
                "lifecycle_closed": str(lifecycle_closed).lower(),
                "lifecycle_net_actual_if_closed": lifecycle_net,
                "lifecycle_net_per_1pct_risk_if_closed": lifecycle_normalised,
            }
        )
    return (
        rows,
        {magic: dict(values) for magic, values in daily.items()},
        {magic: dict(values) for magic, values in daily_actual.items()},
        {magic: len(position_ids) for magic, position_ids in closed_positions.items()},
    )


def _stream_name(sleeve: Sleeve) -> str:
    symbol = re.sub(r"[^A-Z0-9]+", "_", sleeve.symbol.upper()).strip("_")
    return f"{sleeve.ea_id}_{symbol}.jsonl"


def load_backtest_bundle(
    bundle: Path,
    sleeves: Sequence[Sleeve],
) -> tuple[dict[int, dict[date, float]], list[dict[str, Any]]]:
    base = bundle / "QM" / "q08_trades"
    candidates = [(sleeve.ea_id, sleeve.symbol) for sleeve in sleeves]
    paths = {sleeve.key: base / _stream_name(sleeve) for sleeve in sleeves}
    for key, path in paths.items():
        if not path.is_file():
            raise InputError(f"missing sealed backtest stream for {key}: {path}")
    hashes_before = {key: sha256_file(path) for key, path in paths.items()}

    # This must match the Final-24 construction path.  Reading raw q08 `net`
    # would mix gross backtest PnL with live cash PnL after commission.
    model = CommissionModel(COMMISSION_REGISTRY)
    streams = load_streams(bundle, candidates=candidates, commission_model=model)
    expected_keys = set(candidates)
    if set(streams) != expected_keys:
        raise InputError(
            "sealed backtest stream keys mismatch: "
            f"missing={sorted(expected_keys - set(streams))}, "
            f"extra={sorted(set(streams) - expected_keys)}"
        )
    if model.degraded:
        raise InputError(
            "commission model degraded because notional is missing for "
            f"{sorted(model.degraded_symbols)}"
        )
    if model.unknown_symbols:
        raise InputError(f"unknown commission symbols: {sorted(model.unknown_symbols)}")

    daily: dict[int, dict[date, float]] = {}
    inputs: list[dict[str, Any]] = [
        {
            "kind": "commission_registry",
            "path": str(COMMISSION_REGISTRY),
            "sha256": sha256_file(COMMISSION_REGISTRY),
            "rows": "",
        }
    ]
    for sleeve in sleeves:
        path = paths[sleeve.key]
        trades = streams[(sleeve.ea_id, sleeve.symbol)]
        if len(trades) != sleeve.expected_trades:
            raise InputError(
                f"sealed trade-count mismatch for {sleeve.key}: "
                f"expected {sleeve.expected_trades}, got {len(trades)}"
            )
        hash_after = sha256_file(path)
        if hash_after != hashes_before[sleeve.key]:
            raise InputError(f"sealed stream changed while reading: {path}")
        by_day: dict[date, float] = defaultdict(float)
        for trade in trades:
            day = datetime.fromtimestamp(trade.time, tz=timezone.utc).date()
            by_day[day] += float(trade.net_of_cost)
        if not trades:
            raise InputError(f"empty backtest stream: {path}")
        daily[sleeve.magic] = dict(by_day)
        inputs.append(
            {
                "kind": "backtest_stream",
                "logical_magic": sleeve.magic,
                "path": str(path),
                "sha256": hash_after,
                "rows": len(trades),
            }
        )
    return daily, inputs


def verify_pinned_backtest_inputs(
    path: Path,
    current_inputs: Sequence[Mapping[str, Any]],
) -> None:
    try:
        with path.open("r", encoding="utf-8-sig", newline="") as handle:
            rows = list(csv.DictReader(handle))
    except OSError as exc:
        raise InputError(f"pinned baseline input manifest unreadable: {path}: {exc}") from exc

    def key(row: Mapping[str, Any]) -> tuple[str, str]:
        return (str(row.get("kind", "")), str(row.get("logical_magic", "")))

    relevant = {"commission_registry", "backtest_stream"}
    pinned = {key(row): str(row.get("sha256", "")).strip().lower() for row in rows if row.get("kind") in relevant}
    current = {key(row): str(row.get("sha256", "")).strip().lower() for row in current_inputs if row.get("kind") in relevant}
    if pinned != current:
        missing = sorted(set(current) - set(pinned))
        extra = sorted(set(pinned) - set(current))
        changed = sorted(item for item in set(current) & set(pinned) if current[item] != pinned[item])
        raise InputError(
            "pinned baseline mismatch: "
            f"missing={missing!r}, extra={extra!r}, changed={changed!r}"
        )


def baseline_input_fingerprint(current_inputs: Sequence[Mapping[str, Any]]) -> str:
    rows = [
        {
            "kind": str(row.get("kind", "")),
            "logical_magic": str(row.get("logical_magic", "")),
            "sha256": str(row.get("sha256", "")).strip().lower(),
            "rows": str(row.get("rows", "")),
        }
        for row in current_inputs
        if row.get("kind") in {"commission_registry", "backtest_stream"}
    ]
    rows.sort(key=lambda row: (row["kind"], row["logical_magic"]))
    encoded = json.dumps(rows, sort_keys=True, separators=(",", ":")).encode("utf-8")
    return hashlib.sha256(encoded).hexdigest()


def business_days(start: date, end: date) -> list[date]:
    if end < start:
        return []
    rows: list[date] = []
    current = start
    while current <= end:
        if current.weekday() < 5:
            rows.append(current)
        current += timedelta(days=1)
    return rows


def _business_calendar_for_daily(
    daily: Mapping[int, Mapping[date, float]],
) -> list[date]:
    observed = [day for rows in daily.values() for day in rows]
    if not observed:
        return []
    return business_days(min(observed), max(observed))


def population_std(values: Sequence[float]) -> float:
    if not values:
        return 0.0
    mean = sum(values) / len(values)
    return math.sqrt(sum((value - mean) ** 2 for value in values) / len(values))


def _vols_on_calendar(
    daily: Mapping[int, Mapping[date, float]],
    magics: Sequence[int],
    dates: Sequence[date],
) -> dict[int, float]:
    return {
        magic: population_std([float(daily.get(magic, {}).get(day, 0.0)) for day in dates])
        for magic in magics
    }


def blend_volatility(backtest_vol: float, live_vol: float, alpha: float) -> float:
    if backtest_vol <= 0 or not math.isfinite(backtest_vol):
        raise InputError(f"invalid backtest volatility {backtest_vol}")
    if live_vol < 0 or not math.isfinite(live_vol):
        raise InputError(f"invalid live volatility {live_vol}")
    if alpha < 0 or alpha > 1:
        raise InputError(f"alpha outside [0,1]: {alpha}")
    return math.sqrt((1.0 - alpha) * backtest_vol**2 + alpha * live_vol**2)


def capped_inverse_vol(
    vols: Mapping[int, float],
    total_risk: float,
    cap: float,
) -> dict[int, float]:
    if total_risk <= 0 or cap <= 0:
        raise InputError("total_risk and cap must be positive")
    keys = sorted(vols)
    if len(keys) * cap + EPSILON < total_risk:
        raise InputError("allocation infeasible under sleeve cap")
    scores: dict[int, float] = {}
    for magic in keys:
        vol = float(vols[magic])
        if vol <= 0 or not math.isfinite(vol):
            raise InputError(f"invalid allocation volatility for {magic}: {vol}")
        scores[magic] = 1.0 / vol
    remaining = set(keys)
    weights = {magic: 0.0 for magic in keys}
    risk_left = total_risk
    while remaining:
        score_total = sum(scores[magic] for magic in remaining)
        if score_total <= 0:
            raise InputError("non-positive inverse-vol score total")
        provisional = {
            magic: risk_left * scores[magic] / score_total for magic in remaining
        }
        over = [magic for magic in sorted(remaining) if provisional[magic] > cap + EPSILON]
        if not over:
            for magic, value in provisional.items():
                weights[magic] = value
            break
        for magic in over:
            weights[magic] = cap
            risk_left -= cap
            remaining.remove(magic)
        if risk_left < -EPSILON:
            raise InputError("cap allocation over-consumed total risk")
    return _round_weights_exact(weights, total_risk, cap)


def _round_weights_exact(
    weights: Mapping[int, float], total_risk: float, cap: float, decimals: int = 6
) -> dict[int, float]:
    unit = 10 ** (-decimals)
    target_units = round(total_risk / unit)
    exact_units = {magic: value / unit for magic, value in weights.items()}
    units = {magic: int(math.floor(value + EPSILON)) for magic, value in exact_units.items()}
    cap_units = round(cap / unit)
    missing = target_units - sum(units.values())
    if missing > 0:
        order = sorted(
            units,
            key=lambda magic: (-(exact_units[magic] - units[magic]), magic),
        )
        while missing:
            progressed = False
            for magic in order:
                if units[magic] < cap_units:
                    units[magic] += 1
                    missing -= 1
                    progressed = True
                    if missing == 0:
                        break
            if not progressed:
                raise InputError("cannot reconcile rounded allocation under cap")
    elif missing < 0:
        order = sorted(
            units,
            key=lambda magic: (exact_units[magic] - units[magic], magic),
        )
        while missing:
            progressed = False
            for magic in order:
                if units[magic] > 0:
                    units[magic] -= 1
                    missing += 1
                    progressed = True
                    if missing == 0:
                        break
            if not progressed:
                raise InputError("cannot reconcile rounded allocation")
    rounded = {magic: round(value * unit, decimals) for magic, value in units.items()}
    if round(sum(rounded.values()), decimals) != round(total_risk, decimals):
        raise InputError("rounded allocation does not preserve total risk")
    if max(rounded.values(), default=0.0) > cap + unit / 2:
        raise InputError("rounded allocation breaches sleeve cap")
    return rounded


def _portfolio_values(
    daily: Mapping[int, Mapping[date, float]],
    weights: Mapping[int, float],
    dates: Sequence[date],
) -> list[float]:
    return [
        sum(float(daily.get(magic, {}).get(day, 0.0)) * weight for magic, weight in weights.items())
        for day in dates
    ]


def _portfolio_risk_metrics(values: Sequence[float], starting_capital: float) -> dict[str, float]:
    if not values:
        return {
            "annualised_return_pct": 0.0,
            "annualised_vol_pct": 0.0,
            "monthly_var95_proxy_pct": 0.0,
            "darwin_return_proxy_pct": 0.0,
            "max_drawdown_pct": 0.0,
            "worst_day_pct": 0.0,
        }
    annualised_return = sum(values) / len(values) * 252.0 / starting_capital * 100.0
    vol = population_std(values) / starting_capital * 100.0 * math.sqrt(252)
    ordered = sorted(values)
    q05 = ordered[min(len(ordered) - 1, int(0.05 * len(ordered)))]
    monthly_var = max(0.0, -q05 / starting_capital * 100.0 * math.sqrt(21.0))
    darwin_leverage = min(6.5 / monthly_var, 9.75) if monthly_var > 0 else 0.0
    cumulative = 0.0
    peak = 0.0
    max_drawdown = 0.0
    for value in values:
        cumulative += value
        peak = max(peak, cumulative)
        max_drawdown = max(max_drawdown, peak - cumulative)
    return {
        "annualised_return_pct": round(annualised_return, 8),
        "annualised_vol_pct": round(vol, 8),
        "monthly_var95_proxy_pct": round(monthly_var, 8),
        "darwin_return_proxy_pct": round(annualised_return * darwin_leverage, 8),
        "max_drawdown_pct": round(max_drawdown / starting_capital * 100.0, 8),
        "worst_day_pct": round(min(values) / starting_capital * 100.0, 8),
    }


def _book_evidence_metrics(
    values: Sequence[float], starting_capital: float
) -> dict[str, Any]:
    risk = _portfolio_risk_metrics(values, starting_capital)
    return {
        **risk,
        "sessions": len(values),
        "total_net": round(sum(values), 8),
        "positive_sessions": sum(value > EPSILON for value in values),
        "negative_sessions": sum(value < -EPSILON for value in values),
        "flat_sessions": sum(abs(value) <= EPSILON for value in values),
    }


def walk_forward_validate(
    daily: Mapping[int, Mapping[date, float]],
    *,
    total_risk: float,
    cap: float,
    blend_window: int,
    min_live_deals: int,
    train_days: int = DEFAULT_OOS_TRAIN_DAYS,
    horizon_days: int = DEFAULT_OOS_HORIZON_DAYS,
    step_days: int = DEFAULT_OOS_STEP_DAYS,
    observation_days: Sequence[int] = DEFAULT_OOS_OBSERVATION_DAYS,
    starting_capital: float = 100_000.0,
) -> tuple[dict[str, Any], list[dict[str, Any]]]:
    magics = sorted(daily)
    dates = _business_calendar_for_daily(daily)
    max_obs = max(observation_days)
    if len(dates) < train_days + max_obs + horizon_days:
        raise InputError(
            f"insufficient backtest calendar for OOS: {len(dates)} days; need "
            f"{train_days + max_obs + horizon_days}"
        )
    errors_baseline: list[float] = []
    errors_blended: list[float] = []
    folds: list[dict[str, Any]] = []
    fold_wins = 0
    fold_losses = 0
    for origin in range(train_days, len(dates) - max_obs - horizon_days + 1, step_days):
        train_dates = dates[:origin]
        backtest_vols = _vols_on_calendar(daily, magics, train_dates)
        if any(value <= 0 for value in backtest_vols.values()):
            continue
        baseline_weights = capped_inverse_vol(backtest_vols, total_risk, cap)
        for observed in observation_days:
            pseudo_dates = dates[origin : origin + observed]
            oos_dates = dates[origin + observed : origin + observed + horizon_days]
            if len(oos_dates) < horizon_days:
                continue
            pseudo_vols = _vols_on_calendar(daily, magics, pseudo_dates)
            blended_vols: dict[int, float] = {}
            active_alphas: list[float] = []
            fold_base_errors: list[float] = []
            fold_blend_errors: list[float] = []
            realised_vols = _vols_on_calendar(daily, magics, oos_dates)
            for magic in magics:
                nonzero_days = sum(
                    abs(float(daily[magic].get(day, 0.0))) > EPSILON for day in pseudo_dates
                )
                live_vol = pseudo_vols[magic]
                alpha = min(observed / blend_window, 1.0)
                if nonzero_days < min_live_deals or live_vol <= 0:
                    alpha = 0.0
                blended = blend_volatility(backtest_vols[magic], live_vol, alpha)
                blended_vols[magic] = blended
                active_alphas.append(alpha)
                realised = realised_vols[magic]
                if realised > 0:
                    base_error = math.log(backtest_vols[magic] / realised) ** 2
                    blend_error = math.log(blended / realised) ** 2
                    errors_baseline.append(base_error)
                    errors_blended.append(blend_error)
                    fold_base_errors.append(base_error)
                    fold_blend_errors.append(blend_error)
            if not fold_base_errors:
                continue
            blend_weights = capped_inverse_vol(blended_vols, total_risk, cap)
            base_metric = sum(fold_base_errors) / len(fold_base_errors)
            blend_metric = sum(fold_blend_errors) / len(fold_blend_errors)
            if blend_metric < base_metric - EPSILON:
                fold_wins += 1
            elif blend_metric > base_metric + EPSILON:
                fold_losses += 1
            base_portfolio = _portfolio_risk_metrics(
                _portfolio_values(daily, baseline_weights, oos_dates), starting_capital
            )
            blend_portfolio = _portfolio_risk_metrics(
                _portfolio_values(daily, blend_weights, oos_dates), starting_capital
            )
            folds.append(
                {
                    "train_end": train_dates[-1].isoformat(),
                    "pseudo_live_start": pseudo_dates[0].isoformat(),
                    "pseudo_live_end": pseudo_dates[-1].isoformat(),
                    "oos_start": oos_dates[0].isoformat(),
                    "oos_end": oos_dates[-1].isoformat(),
                    "observed_days": observed,
                    "mean_active_alpha": round(sum(active_alphas) / len(active_alphas), 8),
                    "pairs_scored": len(fold_base_errors),
                    "baseline_log_mse": round(base_metric, 10),
                    "blended_log_mse": round(blend_metric, 10),
                    "winner": (
                        "BLEND" if blend_metric < base_metric - EPSILON else
                        "BASELINE" if blend_metric > base_metric + EPSILON else "TIE"
                    ),
                    "baseline_oos_ann_vol_pct": base_portfolio["annualised_vol_pct"],
                    "blended_oos_ann_vol_pct": blend_portfolio["annualised_vol_pct"],
                    "baseline_oos_darwin_proxy_pct": base_portfolio["darwin_return_proxy_pct"],
                    "blended_oos_darwin_proxy_pct": blend_portfolio["darwin_return_proxy_pct"],
                    "baseline_oos_maxdd_pct": base_portfolio["max_drawdown_pct"],
                    "blended_oos_maxdd_pct": blend_portfolio["max_drawdown_pct"],
                    "baseline_oos_worst_day_pct": base_portfolio["worst_day_pct"],
                    "blended_oos_worst_day_pct": blend_portfolio["worst_day_pct"],
                }
            )
    if not errors_baseline or len(folds) < 6:
        raise InputError(f"insufficient valid OOS folds: {len(folds)}")
    baseline_rmse = math.sqrt(sum(errors_baseline) / len(errors_baseline))
    blended_rmse = math.sqrt(sum(errors_blended) / len(errors_blended))
    decisive = fold_wins + fold_losses
    win_rate = fold_wins / decisive if decisive else 0.0
    forecast_pass = blended_rmse <= baseline_rmse + EPSILON and win_rate >= 0.5

    # The July-11 precedent used two chronological directions and a held-out
    # Darwin objective.  Preserve that spirit without feeding returns into the
    # weight estimator: held-out returns only decide whether the rule is safe to
    # present.  The VaR-based Darwin figure is explicitly a proxy, not a pipeline
    # or live-performance verdict.
    chronological = sorted(folds, key=lambda row: (row["oos_start"], row["observed_days"]))
    cut = len(chronological) // 2
    segments = [chronological[:cut], chronological[cut:]]
    segment_rows: list[dict[str, Any]] = []
    segment_passes: list[bool] = []
    for index, segment in enumerate(segments, 1):
        if not segment:
            segment_passes.append(False)
            continue
        pairs = sum(int(row["pairs_scored"]) for row in segment)
        base_mse = sum(float(row["baseline_log_mse"]) * int(row["pairs_scored"]) for row in segment) / pairs
        blend_mse = sum(float(row["blended_log_mse"]) * int(row["pairs_scored"]) for row in segment) / pairs
        base_darwin = sum(float(row["baseline_oos_darwin_proxy_pct"]) for row in segment) / len(segment)
        blend_darwin = sum(float(row["blended_oos_darwin_proxy_pct"]) for row in segment) / len(segment)
        passed_segment = blend_mse <= base_mse + EPSILON and blend_darwin >= base_darwin - EPSILON
        segment_passes.append(passed_segment)
        segment_rows.append(
            {
                "segment": index,
                "folds": len(segment),
                "baseline_log_rmse": round(math.sqrt(base_mse), 10),
                "blended_log_rmse": round(math.sqrt(blend_mse), 10),
                "baseline_mean_darwin_proxy_pct": round(base_darwin, 8),
                "blended_mean_darwin_proxy_pct": round(blend_darwin, 8),
                "pass": passed_segment,
            }
        )
    mean_base_vol = sum(float(row["baseline_oos_ann_vol_pct"]) for row in folds) / len(folds)
    mean_blend_vol = sum(float(row["blended_oos_ann_vol_pct"]) for row in folds) / len(folds)
    mean_base_dd = sum(float(row["baseline_oos_maxdd_pct"]) for row in folds) / len(folds)
    mean_blend_dd = sum(float(row["blended_oos_maxdd_pct"]) for row in folds) / len(folds)
    max_blend_dd = max(float(row["blended_oos_maxdd_pct"]) for row in folds)
    worst_blend_day = min(float(row["blended_oos_worst_day_pct"]) for row in folds)
    book_risk_pass = (
        mean_blend_vol <= mean_base_vol + EPSILON
        and mean_blend_dd <= mean_base_dd + EPSILON
        and max_blend_dd <= 10.0 + EPSILON
        and worst_blend_day >= -5.0 - EPSILON
    )
    passed = forecast_pass and all(segment_passes) and book_risk_pass
    validation = {
        "schema_version": 1,
        "method": "leakage_free_expanding_backtest_plus_pseudo_live_variance_blend",
        "forecast_loss": "RMSE of log(predicted sleeve daily vol / next-window realised vol)",
        "pass_rule": (
            "forecast RMSE/win-rate pass AND both chronological segments have "
            "no-worse RMSE plus no-worse held-out Darwin proxy AND held-out book "
            "mean vol/maxDD are no worse with <=5% worst day and <=10% maxDD"
        ),
        "train_days_minimum": train_days,
        "observation_days": list(observation_days),
        "blend_window_days": blend_window,
        "oos_horizon_days": horizon_days,
        "step_days": step_days,
        "fold_count": len(folds),
        "pairs_scored": len(errors_baseline),
        "baseline_log_rmse": round(baseline_rmse, 10),
        "blended_log_rmse": round(blended_rmse, 10),
        "relative_rmse": round(blended_rmse / baseline_rmse, 10) if baseline_rmse else None,
        "blend_fold_wins": fold_wins,
        "baseline_fold_wins": fold_losses,
        "ties": len(folds) - decisive,
        "decisive_fold_win_rate": round(win_rate, 10),
        "forecast_pass": forecast_pass,
        "chronological_segments": segment_rows,
        "book_risk": {
            "baseline_mean_ann_vol_pct": round(mean_base_vol, 8),
            "blended_mean_ann_vol_pct": round(mean_blend_vol, 8),
            "baseline_mean_maxdd_pct": round(mean_base_dd, 8),
            "blended_mean_maxdd_pct": round(mean_blend_dd, 8),
            "blended_max_fold_maxdd_pct": round(max_blend_dd, 8),
            "blended_worst_fold_day_pct": round(worst_blend_day, 8),
            "ftmo_daily_dd_limit_pct": 5.0,
            "ftmo_total_dd_limit_pct": 10.0,
            "pass": book_risk_pass,
        },
        "verdict": "PASS" if passed else "FAIL",
    }
    return validation, folds


def build_live_diagnostics(
    sleeves: Sequence[Sleeve],
    backtest_daily: Mapping[int, Mapping[date, float]],
    live_daily: Mapping[int, Mapping[date, float]],
    closed_position_counts: Mapping[int, int],
    live_dates: Sequence[date],
    *,
    blend_window: int,
    min_live_deals: int,
    total_risk: float,
    cap: float,
) -> tuple[list[dict[str, Any]], dict[int, float]]:
    magics = [row.magic for row in sleeves]
    backtest_dates = _business_calendar_for_daily(backtest_daily)
    backtest_vols = _vols_on_calendar(backtest_daily, magics, backtest_dates)
    live_vol_dates = list(live_dates[-blend_window:])
    live_vols = (
        _vols_on_calendar(live_daily, magics, live_vol_dates)
        if live_vol_dates
        else {m: 0.0 for m in magics}
    )
    blended_vols: dict[int, float] = {}
    rows: list[dict[str, Any]] = []
    by_magic = {row.magic: row for row in sleeves}
    for magic in magics:
        completed_positions = int(closed_position_counts.get(magic, 0))
        live_vol = live_vols[magic]
        alpha = min(len(live_dates) / blend_window, 1.0)
        hold_reason = ""
        if len(live_dates) < 2:
            alpha = 0.0
            hold_reason = "INSUFFICIENT_LIVE_SESSIONS"
        elif completed_positions < min_live_deals:
            alpha = 0.0
            hold_reason = "INSUFFICIENT_LIVE_DEALS"
        elif live_vol <= 0:
            alpha = 0.0
            hold_reason = "ZERO_LIVE_VOL"
        blended = blend_volatility(backtest_vols[magic], live_vol, alpha)
        blended_vols[magic] = blended
        sleeve = by_magic[magic]
        rows.append(
            {
                "ea_id": sleeve.ea_id,
                "symbol": sleeve.symbol,
                "logical_magic": magic,
                "current_risk_percent": round(sleeve.current_risk_percent, 6),
                "backtest_daily_vol_1pct": round(backtest_vols[magic], 8),
                "live_daily_vol_1pct": round(live_vol, 8),
                "observed_live_sessions": len(live_dates),
                "live_vol_window_sessions": len(live_vol_dates),
                "live_closed_position_count": completed_positions,
                "alpha": round(alpha, 8),
                "blended_daily_vol_1pct": round(blended, 8),
                "hold_reason": hold_reason,
            }
        )
    proposed = capped_inverse_vol(blended_vols, total_risk, cap)
    for row in rows:
        row["shadow_weight_percent_not_for_use"] = proposed[int(row["logical_magic"])]
        row["shadow_delta_vs_current"] = round(
            row["shadow_weight_percent_not_for_use"] - row["current_risk_percent"], 6
        )
    return rows, proposed


def proposal_gate(
    *,
    deal_evidence_present: bool,
    observed_sessions: int,
    eligible_sleeves: int,
    total_sleeves: int,
    oos_verdict: str,
    minimum_sessions: int = DEFAULT_MIN_PROPOSAL_SESSIONS,
) -> tuple[bool, list[str]]:
    """Return the fail-closed OWNER-review gate and deterministic reasons."""

    if total_sleeves <= 0 or not 0 <= eligible_sleeves <= total_sleeves:
        raise InputError("invalid live sleeve coverage counts")
    reasons: list[str] = []
    if not deal_evidence_present:
        reasons.append("LIVE_DEAL_EXPORT_REQUIRED")
    if observed_sessions < minimum_sessions:
        reasons.append(
            f"LIVE_WINDOW_IMMATURE_{observed_sessions}_OF_{minimum_sessions}_MINIMUM_SESSIONS"
        )
    if eligible_sleeves <= 0:
        reasons.append("NO_SLEEVE_HAS_MINIMUM_LIVE_EVIDENCE")
    if oos_verdict != "PASS":
        reasons.append("BLEND_RULE_OOS_FAILED")
    return not reasons, reasons


def diagnostics_for_artifact(
    rows: Sequence[Mapping[str, Any]], *, proposal_eligible: bool
) -> list[dict[str, Any]]:
    """Return diagnostics safe to persist at the current review gate."""

    output = [dict(row) for row in rows]
    if not proposal_eligible:
        for row in output:
            row["shadow_weight_percent_not_for_use"] = ""
            row["shadow_delta_vs_current"] = ""
    return output


def _live_daily_rows(
    sleeves: Sequence[Sleeve],
    live_daily: Mapping[int, Mapping[date, float]],
    live_daily_actual: Mapping[int, Mapping[date, float]],
    live_dates: Sequence[date],
) -> list[dict[str, Any]]:
    rows: list[dict[str, Any]] = []
    for day in live_dates:
        for sleeve in sorted(sleeves, key=lambda row: row.magic):
            normalised = float(live_daily.get(sleeve.magic, {}).get(day, 0.0))
            actual = float(live_daily_actual.get(sleeve.magic, {}).get(day, 0.0))
            rows.append(
                {
                    "date_utc": day.isoformat(),
                    "ea_id": sleeve.ea_id,
                    "symbol": sleeve.symbol,
                    "logical_magic": sleeve.magic,
                    "net_actual": round(actual, 8),
                    "net_per_1pct_risk": round(normalised, 8),
                    "normalization_basis": "deal_entry_risk",
                    "zero_fill": str(abs(normalised) <= EPSILON).lower(),
                }
            )
    return rows


def _total_risk_review_markdown(
    *,
    generated_at_utc: str,
    live_start: date,
    as_of: date,
    live_sessions: int,
    deal_count: int,
    current_total: float,
    min_proposal_sessions: int,
    blend_window: int,
    oos_verdict: str,
    status: str,
    live_book_metrics: Mapping[str, Any],
    backtest_book_metrics: Mapping[str, Any],
) -> str:
    if status == "OWNER_REVIEW_ELIGIBLE":
        decision_fields = f"""## OWNER decision fields (choose exactly one)

- [ ] Keep TOTAL_RISK unchanged at `{current_total:.6f}` and defer reweighting.
- [ ] Reject live-blend reweighting for this month.
- [ ] Request separate modelling; no weight or risk change is authorized here.
- [ ] Accept the unapproved weight proposal for preparation of a **separate signed deploy decision**.

OWNER identity: `________`  Decision UTC: `________`  Package verify SHA256: `________`
"""
    else:
        decision_fields = """## HOLD acknowledgement

This package is not eligible for approval and contains no proposed weights.
Record only acknowledgement, rejection, or a request for additional evidence;
no approval or deploy field is intentionally rendered.
"""
    return f"""# DXZ TOTAL_RISK review template

Generated: `{generated_at_utc}`

Evidence window: `{live_start}` through `{as_of}`
Status: **{status}**

This is an OWNER decision template. It cannot apply weights, edit presets, change
live settings, or authorize a risk increase.

## Evidence maturity

- Completed live sessions: **{live_sessions}**
- Minimum for a monthly proposal: **{min_proposal_sessions}**
- Full live-volatility saturation: **{blend_window}**
- Attributed closed positions: **{deal_count}**
- Blend-rule OOS verdict: **{oos_verdict}**
- Current TOTAL_RISK: **{current_total:.6f}**
- Hard per-sleeve cap in every scenario: **1.000000**

## Book evidence (no forecast input)

| metric | live realised deals | sealed backtest at current weights |
|---|---:|---:|
| annualised daily vol | {live_book_metrics['annualised_vol_pct']:.6f}% | {backtest_book_metrics['annualised_vol_pct']:.6f}% |
| max drawdown | {live_book_metrics['max_drawdown_pct']:.6f}% | {backtest_book_metrics['max_drawdown_pct']:.6f}% |
| worst day | {live_book_metrics['worst_day_pct']:.6f}% | {backtest_book_metrics['worst_day_pct']:.6f}% |
| total net | {live_book_metrics['total_net']:.2f} | {backtest_book_metrics['total_net']:.2f} |

Live closed-deal drawdown is not account-equity drawdown and cannot by itself
support a TOTAL_RISK increase.

{decision_fields}

No candidate above the current total is generated automatically. A later review
must attach book-level realised volatility/drawdown, scenario evidence, and a
written OWNER decision. Until then, deployment action is `NONE`.
"""


def run(args: argparse.Namespace) -> dict[str, Any]:
    manifest_path = Path(args.manifest)
    decision_path = Path(args.decision_record)
    staging_report_path = Path(args.staging_report)
    bundle = Path(args.backtest_bundle)
    registry_path = Path(args.magic_registry)
    output_dir = Path(args.output_dir)
    validate_output_dir(output_dir)
    if str(args.task_id).strip() != TASK_ID:
        raise InputError(f"task id must be the routed task {TASK_ID}")
    generator_commit = str(args.generator_commit).strip().lower()
    if not re.fullmatch(r"[0-9a-f]{40}", generator_commit):
        raise InputError("generator_commit must be a full 40-character Git SHA")
    live_start = _parse_date(args.live_start, "live_start")
    as_of = _parse_date(args.as_of, "as_of")
    if live_start != FINAL24_LIVE_START:
        raise InputError(f"Final-24 v1 live_start is pinned to {FINAL24_LIVE_START}")
    if args.blend_window != DEFAULT_BLEND_WINDOW:
        raise InputError("blend window is ratified at 42 sessions and is not tunable")
    if args.min_live_deals != DEFAULT_MIN_LIVE_DEALS:
        raise InputError("minimum closed-position count is predeclared at 2")
    if abs(args.sleeve_cap - DEFAULT_SLEEVE_CAP) > EPSILON:
        raise InputError("sleeve cap is ratified at exactly 1.0")
    generated_at = str(args.generated_at_utc).strip()
    parsed_generated = _parse_time_utc(generated_at)
    generated_at = parsed_generated.isoformat().replace("+00:00", "Z")
    if live_start > as_of and not args.template_only:
        raise InputError("live_start cannot be after as_of")
    if as_of > parsed_generated.date():
        raise InputError("as_of cannot be after generated_at_utc")

    manifest_sha = sha256_file(manifest_path)
    if manifest_sha != FINAL24_MANIFEST_SHA256:
        raise InputError(
            "manifest is not the pinned deployed Final-24 baseline: "
            f"expected {FINAL24_MANIFEST_SHA256}, got {manifest_sha}"
        )
    manifest, sleeves = load_manifest(manifest_path)
    verify_live_decision(decision_path)
    verify_staging_manifest_link(staging_report_path, manifest_path, sleeves)
    declared_bundle = manifest.get("stream_basis", {}).get("bundle")
    if not declared_bundle or Path(str(declared_bundle)).resolve() != bundle.resolve():
        raise InputError(
            f"backtest bundle does not match manifest stream_basis.bundle: {declared_bundle!r}"
        )
    aliases = load_magic_registry(registry_path, sleeves)
    backtest_daily, stream_inputs = load_backtest_bundle(bundle, sleeves)
    baseline_fingerprint = baseline_input_fingerprint(stream_inputs)
    if baseline_fingerprint != FINAL24_BASELINE_FINGERPRINT_SHA256:
        raise InputError(
            "sealed Final-24 baseline fingerprint mismatch: "
            f"expected {FINAL24_BASELINE_FINGERPRINT_SHA256}, got {baseline_fingerprint}"
        )
    pinned_inputs_path = (
        Path(args.pinned_baseline_inputs) if args.pinned_baseline_inputs else None
    )
    total_risk = _as_float(
        manifest.get("total_risk_pct", DEFAULT_TOTAL_RISK), "total_risk_pct"
    )
    if abs(total_risk - DEFAULT_TOTAL_RISK) > 0.000001:
        raise InputError("Final-24 TOTAL_RISK must remain 9.75 in this workflow")
    cap = float(args.sleeve_cap)
    oos_validation, oos_folds = walk_forward_validate(
        backtest_daily,
        total_risk=total_risk,
        cap=cap,
        blend_window=args.blend_window,
        min_live_deals=args.min_live_deals,
    )

    deal_path = Path(args.deal_history) if args.deal_history else None
    deal_metadata_path = Path(args.deal_metadata) if args.deal_metadata else None
    if not args.template_only and deal_path is None:
        raise InputError("--deal-history is required unless --template-only is used")
    if args.template_only and deal_path is not None:
        raise InputError("--template-only cannot be combined with --deal-history")
    if deal_path is not None and deal_metadata_path is None:
        raise InputError("--deal-metadata is required with --deal-history")
    if deal_path is not None and pinned_inputs_path is None:
        raise InputError("--pinned-baseline-inputs is required with --deal-history")
    if args.template_only and deal_metadata_path is not None:
        raise InputError("--template-only cannot be combined with --deal-metadata")
    risk_path = Path(args.risk_schedule) if args.risk_schedule else None
    if deal_path is not None and risk_path is None:
        raise InputError("--risk-schedule is required with --deal-history")
    risk_schedule = load_risk_schedule(
        risk_path,
        sleeves,
        live_start,
        as_of if deal_path is not None else None,
    )
    if pinned_inputs_path is not None:
        verify_pinned_backtest_inputs(pinned_inputs_path, stream_inputs)
    normalised_deals: list[dict[str, Any]] = []
    live_daily: dict[int, dict[date, float]] = {}
    live_daily_actual: dict[int, dict[date, float]] = {}
    closed_position_counts: dict[int, int] = {}
    deal_source_rows = 0
    deal_metadata: dict[str, Any] | None = None
    if deal_path is not None:
        assert deal_metadata_path is not None
        deal_metadata = verify_deal_export_metadata(
            deal_metadata_path,
            deal_path,
            live_start,
            as_of,
            parsed_generated,
        )
        deal_source_rows = len(_read_deal_rows(deal_path))
        deals = load_deals(deal_path)
        normalised_deals, live_daily, live_daily_actual, closed_position_counts = attribute_deals(
            deals, aliases, risk_schedule, live_start, as_of
        )
    live_dates = business_days(live_start, as_of)
    diagnostics, analysis_weights = build_live_diagnostics(
        sleeves,
        backtest_daily,
        live_daily,
        closed_position_counts,
        live_dates,
        blend_window=args.blend_window,
        min_live_deals=args.min_live_deals,
        total_risk=total_risk,
        cap=cap,
    )
    attributed_closed_positions = sum(closed_position_counts.values())
    starting_capital = _as_float(
        manifest.get("starting_capital", 100_000.0), "starting_capital"
    )
    live_book_values = [
        sum(float(live_daily_actual.get(sleeve.magic, {}).get(day, 0.0)) for sleeve in sleeves)
        for day in live_dates
    ]
    backtest_dates = _business_calendar_for_daily(backtest_daily)
    current_weights = {row.magic: row.current_risk_percent for row in sleeves}
    backtest_book_values = _portfolio_values(backtest_daily, current_weights, backtest_dates)
    live_book_metrics = _book_evidence_metrics(live_book_values, starting_capital)
    backtest_book_metrics = _book_evidence_metrics(backtest_book_values, starting_capital)
    live_eligible_sleeves = sum(not row["hold_reason"] for row in diagnostics)
    eligible, hold_reasons = proposal_gate(
        deal_evidence_present=deal_path is not None,
        observed_sessions=len(live_dates),
        eligible_sleeves=live_eligible_sleeves,
        total_sleeves=len(sleeves),
        oos_verdict=oos_validation["verdict"],
    )
    status = "OWNER_REVIEW_ELIGIBLE" if eligible else "HOLD"
    artifact_diagnostics = diagnostics_for_artifact(
        diagnostics, proposal_eligible=eligible
    )

    input_rows = [
        {"kind": "manifest", "path": str(manifest_path), "sha256": sha256_file(manifest_path), "rows": 24},
        {"kind": "decision_record", "path": str(decision_path), "sha256": sha256_file(decision_path), "rows": ""},
        {"kind": "staging_report", "path": str(staging_report_path), "sha256": sha256_file(staging_report_path), "rows": ""},
        {"kind": "magic_registry", "path": str(registry_path), "sha256": sha256_file(registry_path), "rows": ""},
        {"kind": "tool_source", "path": str(Path(__file__).resolve()), "sha256": sha256_file(Path(__file__).resolve()), "rows": ""},
        {"kind": "python_dependency", "path": str(COMMISSION_SOURCE), "sha256": sha256_file(COMMISSION_SOURCE), "rows": ""},
        {"kind": "python_dependency", "path": str(PORTFOLIO_COMMON_SOURCE), "sha256": sha256_file(PORTFOLIO_COMMON_SOURCE), "rows": ""},
        *stream_inputs,
    ]
    if deal_path is not None:
        input_rows.append(
            {"kind": "live_deal_export", "path": str(deal_path), "sha256": sha256_file(deal_path), "rows": deal_source_rows}
        )
        assert deal_metadata_path is not None
        input_rows.append(
            {"kind": "live_deal_export_metadata", "path": str(deal_metadata_path), "sha256": sha256_file(deal_metadata_path), "rows": ""}
        )
    if risk_path is not None:
        input_rows.append(
            {"kind": "risk_schedule", "path": str(risk_path), "sha256": sha256_file(risk_path), "rows": ""}
        )
    if pinned_inputs_path is not None:
        input_rows.append(
            {"kind": "pinned_baseline_inputs", "path": str(pinned_inputs_path), "sha256": sha256_file(pinned_inputs_path), "rows": ""}
        )

    owner_template = {
        "schema_version": SCHEMA_VERSION,
        "task_id": TASK_ID,
        "generator_commit": generator_commit,
        "status": status,
        "approval_status": "UNAPPROVED",
        "not_for_deploy": True,
        "analysis_only": True,
        "auto_apply": False,
        "deployment_action": "NONE",
        "autotrading_action": "NONE",
        "manual_owner_approval_required": True,
        "generated_at_utc": generated_at,
        "book": "DXZ_FINAL_24",
        "composition_change_allowed": False,
        "return_forecasts_used": False,
        "live_start": live_start.isoformat(),
        "as_of": as_of.isoformat(),
        "session_calendar": "UTC weekdays; complete UTC days only",
        "live_pnl_basis": "completed position lifecycle net booked on final close day",
        "backtest_pnl_basis": "Q08 close rows adjusted by canonical commission model",
        "pinned_baseline_fingerprint_sha256": baseline_fingerprint,
        "observed_live_sessions": len(live_dates),
        "minimum_proposal_sessions": DEFAULT_MIN_PROPOSAL_SESSIONS,
        "blend_window_sessions": args.blend_window,
        "attributed_closed_positions": attributed_closed_positions,
        "live_eligible_sleeves": live_eligible_sleeves,
        "live_fallback_to_backtest_sleeves": len(sleeves) - live_eligible_sleeves,
        "deal_export_metadata": deal_metadata,
        "live_book_realised_deal_metrics": live_book_metrics,
        "sealed_backtest_current_weight_metrics": backtest_book_metrics,
        "total_risk_percent": total_risk,
        "sleeve_cap_percent": cap,
        "oos_validation_verdict": oos_validation["verdict"],
        "hold_reasons": hold_reasons,
        "proposed_weights": (
            [
                {
                    "ea_id": row.ea_id,
                    "symbol": row.symbol,
                    "magic": row.magic,
                    "risk_percent": analysis_weights[row.magic],
                }
                for row in sleeves
            ]
            if eligible
            else []
        ),
        "analysis_weights_withheld": not eligible,
        "invocation_config": {
            "blend_window_sessions": args.blend_window,
            "minimum_proposal_sessions": DEFAULT_MIN_PROPOSAL_SESSIONS,
            "minimum_closed_positions_per_sleeve": args.min_live_deals,
            "total_risk_percent": total_risk,
            "sleeve_cap_percent": cap,
            "template_only": bool(args.template_only),
        },
        "input_sha256": input_rows,
    }

    output_dir.mkdir(parents=True, exist_ok=True)
    snapshot_names: list[str] = []
    frozen_dir = output_dir / "frozen_inputs"
    frozen_stream_dir = frozen_dir / "q08_trades"
    frozen_stream_dir.mkdir(parents=True, exist_ok=True)
    frozen_sources = (
        (manifest_path, frozen_dir / "manifest_source.json"),
        (decision_path, frozen_dir / "owner_decision.md"),
        (staging_report_path, frozen_dir / "staging_report.json"),
        (registry_path, frozen_dir / "magic_numbers.csv"),
        (COMMISSION_REGISTRY, frozen_dir / "live_commission.json"),
        (Path(__file__).resolve(), frozen_dir / "dxz_live_blend_reweight.py"),
        (COMMISSION_SOURCE, frozen_dir / "commission.py"),
        (PORTFOLIO_COMMON_SOURCE, frozen_dir / "portfolio_common.py"),
    )
    for source, target in frozen_sources:
        shutil.copyfile(source, target)
        if sha256_file(source) != sha256_file(target):
            raise InputError(f"frozen input copy hash mismatch: {source}")
        snapshot_names.append(target.relative_to(output_dir).as_posix())
    for stream_row in stream_inputs:
        if stream_row.get("kind") != "backtest_stream":
            continue
        source = Path(str(stream_row["path"]))
        target = frozen_stream_dir / source.name
        shutil.copyfile(source, target)
        if str(stream_row["sha256"]) != sha256_file(target):
            raise InputError(f"frozen stream copy hash mismatch: {source}")
        snapshot_names.append(target.relative_to(output_dir).as_posix())
    if deal_path is not None:
        snapshot_name = f"live_deal_export_snapshot{deal_path.suffix.lower()}"
        shutil.copyfile(deal_path, output_dir / snapshot_name)
        snapshot_names.append(snapshot_name)
        assert deal_metadata_path is not None
        snapshot_name = "live_deal_export_metadata_snapshot.json"
        shutil.copyfile(deal_metadata_path, output_dir / snapshot_name)
        snapshot_names.append(snapshot_name)
    if risk_path is not None:
        snapshot_name = "risk_schedule_snapshot.csv"
        shutil.copyfile(risk_path, output_dir / snapshot_name)
        snapshot_names.append(snapshot_name)
    if pinned_inputs_path is not None:
        snapshot_name = "pinned_baseline_inputs_snapshot.csv"
        shutil.copyfile(pinned_inputs_path, output_dir / snapshot_name)
        snapshot_names.append(snapshot_name)
    _canonical_json(output_dir / "manifest_snapshot.json", manifest)
    _canonical_json(
        output_dir / "invocation_config.json",
        {
            "schema_version": 1,
            "task_id": TASK_ID,
            "generator_commit": generator_commit,
            "generated_at_utc": generated_at,
            "manifest": str(manifest_path),
            "decision_record": str(decision_path),
            "staging_report": str(staging_report_path),
            "backtest_bundle": str(bundle),
            "magic_registry": str(registry_path),
            "live_start": live_start.isoformat(),
            "as_of": as_of.isoformat(),
            "template_only": bool(args.template_only),
            "blend_window": args.blend_window,
            "minimum_proposal_sessions": DEFAULT_MIN_PROPOSAL_SESSIONS,
            "minimum_live_closed_positions": args.min_live_deals,
            "sleeve_cap": cap,
            "total_risk": total_risk,
            "pinned_baseline_fingerprint_sha256": baseline_fingerprint,
        },
    )
    _canonical_json(
        output_dir / "deal_export_contract.json",
        {
            "schema_version": 1,
            "accepted_formats": ["csv", "json", "jsonl"],
            "required_trade_fields": [
                "deal_id", "position_id", "time_utc", "type", "entry", "magic",
                "symbol", "volume", "profit", "swap", "commission", "fee",
            ],
            "optional_trade_fields": [],
            "time_contract": "UTC timestamp with explicit offset, or Unix epoch seconds",
            "type_contract": (
                "BUY/SELL or MT5 numeric 0/1; any non-trade row with non-zero "
                "profit/swap/commission/fee is refused as unallocated cashflow"
            ),
            "entry_contract": "IN/OUT/OUT_BY or MT5 numeric 0/1/3; INOUT is refused",
            "ownership_contract": (
                "export must include every opening deal needed to resolve position_id; "
                "magic=0 broker closes inherit opening magic"
            ),
            "net_contract": "profit + swap + commission + fee, aggregated once per position lifecycle",
            "normalization_contract": (
                "book complete lifecycle net on final close UTC day and divide by "
                "RISK_PERCENT at first entry"
            ),
            "metadata_sidecar_required": True,
            "metadata_required_fields": [
                "schema_version", "account_login", "server", "source_kind",
                "complete", "read_only_export", "scope", "history_from_utc",
                "history_to_utc_exclusive", "exported_at_utc",
                "deal_history_basename", "deal_history_sha256", "source_row_count",
            ],
            "account_login_required": EXPECTED_ACCOUNT_LOGIN,
            "server_required": EXPECTED_SERVER,
            "scope_required": EXPECTED_EXPORT_SCOPE,
            "risk_schedule_required": True,
            "terminal_api_used_by_this_tool": False,
        },
    )
    _write_csv(
        output_dir / "input_sha256.csv",
        ("kind", "logical_magic", "path", "sha256", "rows"),
        input_rows,
    )
    _write_csv(
        output_dir / "live_deals_normalized.csv",
        (
            "deal_id", "position_id", "time_utc", "entry", "deal_magic", "logical_magic",
            "symbol", "volume", "profit", "swap", "commission", "fee", "net_actual",
            "risk_percent_in_force", "net_per_1pct_risk", "lifecycle_closed",
            "lifecycle_net_actual_if_closed", "lifecycle_net_per_1pct_risk_if_closed",
        ),
        normalised_deals,
    )
    daily_rows = _live_daily_rows(sleeves, live_daily, live_daily_actual, live_dates)
    _write_csv(
        output_dir / "live_daily_pnl.csv",
        (
            "date_utc", "ea_id", "symbol", "logical_magic", "net_actual",
            "net_per_1pct_risk", "normalization_basis", "zero_fill",
        ),
        daily_rows,
    )
    _write_csv(
        output_dir / "sleeve_diagnostics.csv",
        (
            "ea_id", "symbol", "logical_magic", "current_risk_percent",
            "backtest_daily_vol_1pct", "live_daily_vol_1pct", "observed_live_sessions",
            "live_vol_window_sessions", "live_closed_position_count", "alpha",
            "blended_daily_vol_1pct",
            "shadow_weight_percent_not_for_use", "shadow_delta_vs_current", "hold_reason",
        ),
        artifact_diagnostics,
    )
    fold_fields = tuple(oos_folds[0])
    _write_csv(output_dir / "oos_folds.csv", fold_fields, oos_folds)
    _canonical_json(output_dir / "oos_validation.json", oos_validation)
    _canonical_json(output_dir / "owner_review_template.json", owner_template)
    (output_dir / "total_risk_review_template.md").write_text(
        _total_risk_review_markdown(
            generated_at_utc=generated_at,
            live_start=live_start,
            as_of=as_of,
            live_sessions=len(live_dates),
            deal_count=attributed_closed_positions,
            current_total=total_risk,
            min_proposal_sessions=DEFAULT_MIN_PROPOSAL_SESSIONS,
            blend_window=args.blend_window,
            oos_verdict=oos_validation["verdict"],
            status=status,
            live_book_metrics=live_book_metrics,
            backtest_book_metrics=backtest_book_metrics,
        ),
        encoding="utf-8",
        newline="\n",
    )
    artifact_names = (
        "manifest_snapshot.json", "invocation_config.json", "deal_export_contract.json",
        "input_sha256.csv",
        "live_deals_normalized.csv",
        "live_daily_pnl.csv", "sleeve_diagnostics.csv", "oos_folds.csv",
        "oos_validation.json", "owner_review_template.json", "total_risk_review_template.md",
        *snapshot_names,
    )
    verify = {
        "schema_version": 1,
        "task_id": TASK_ID,
        "generator_commit": generator_commit,
        "status": status,
        "generated_at_utc": generated_at,
        "invariants": {
            "final_24_sleeves": len(sleeves) == 24,
            "composition_unchanged": manifest_sha == FINAL24_MANIFEST_SHA256,
            "owner_decision_pinned": sha256_file(decision_path) == FINAL24_DECISION_SHA256,
            "sealed_baseline_pinned": baseline_fingerprint == FINAL24_BASELINE_FINGERPRINT_SHA256,
            "live_evidence_present_for_at_least_one_sleeve": live_eligible_sleeves > 0,
            "total_risk_exact_6dp": round(sum(analysis_weights.values()), 6) == round(total_risk, 6),
            "sleeve_cap_respected": max(analysis_weights.values()) <= cap + 0.0000005,
            "oos_validation_pass": oos_validation["verdict"] == "PASS",
            "candidate_weights_withheld_on_hold": eligible or all(
                row["shadow_weight_percent_not_for_use"] == ""
                and row["shadow_delta_vs_current"] == ""
                for row in artifact_diagnostics
            ),
            "owner_review_only": True,
            "auto_apply": False,
            "deployment_action": "NONE",
            "writes_outside_live_roots": not any(
                _path_is_under(output_dir, root) for root in LIVE_ROOTS
            ),
        },
        "artifacts": [
            {"path": name, "sha256": sha256_file(output_dir / name)} for name in artifact_names
        ],
    }
    _canonical_json(output_dir / "verify.json", verify)
    return {
        "status": status,
        "hold_reasons": hold_reasons,
        "output_dir": str(output_dir),
        "oos_verdict": oos_validation["verdict"],
        "observed_live_sessions": len(live_dates),
        "attributed_closed_positions": attributed_closed_positions,
        "verify": verify,
    }


def parse_args(argv: Sequence[str] | None = None) -> argparse.Namespace:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--task-id", required=True)
    parser.add_argument("--generator-commit", required=True)
    parser.add_argument("--manifest", required=True)
    parser.add_argument("--decision-record", required=True)
    parser.add_argument("--staging-report", required=True)
    parser.add_argument("--backtest-bundle", required=True)
    parser.add_argument("--magic-registry", required=True)
    parser.add_argument("--deal-history")
    parser.add_argument("--deal-metadata")
    parser.add_argument("--pinned-baseline-inputs")
    parser.add_argument("--risk-schedule")
    parser.add_argument("--live-start", required=True)
    parser.add_argument("--as-of", required=True)
    parser.add_argument("--generated-at-utc", required=True)
    parser.add_argument("--output-dir", required=True)
    parser.add_argument("--template-only", action="store_true")
    parser.add_argument("--blend-window", type=int, default=DEFAULT_BLEND_WINDOW)
    parser.add_argument(
        "--min-live-closed-positions",
        dest="min_live_deals",
        type=int,
        default=DEFAULT_MIN_LIVE_DEALS,
    )
    parser.add_argument("--sleeve-cap", type=float, default=DEFAULT_SLEEVE_CAP)
    return parser.parse_args(argv)


def main(argv: Sequence[str] | None = None) -> int:
    args = parse_args(argv)
    try:
        result = run(args)
    except (InputError, OSError) as exc:
        print(f"dxz live-blend refused: {exc}")
        return 2
    print(json.dumps(result, indent=2, sort_keys=True))
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
