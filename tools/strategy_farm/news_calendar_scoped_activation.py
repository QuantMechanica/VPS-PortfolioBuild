"""OWNER-approved activation boundary for scoped news-calendar consumer B.

This module does not publish or repin a calendar and does not release a hold.
It authenticates the exact E1-D3/D4 candidate, projects each pending Q10_NEWS
row through the already-adopted E1-C exclusion semantics, and produces the
binding marker consumed by the explicit row-by-row release path.
"""
from __future__ import annotations

import csv
import datetime as dt
import hashlib
import json
from dataclasses import dataclass
from pathlib import Path
import re
import sqlite3
from typing import Any, Mapping

try:
    from tools.strategy_farm import news_calendar_scoped_consumer as e1c
except ModuleNotFoundError:
    import news_calendar_scoped_consumer as e1c


CONFIG = Path(__file__).resolve().parent / "config/news_calendar_scoped_consumer_b.v1.json"
SCHEMA = "qm.news-calendar-scoped-consumer-b-activation/v1"
MARKER_SCHEMA = "qm.news-calendar-scoped-counter-marker/v1"
MARKER_KEY = "news_calendar_scoped_consumer_b"
FOOTNOTE = "Kalender scope-begrenzt"
HEX = re.compile(r"^[0-9a-f]{64}$")
TIMEFRAME = re.compile(r"_(M1|M5|M15|M30|H1|H2|H4|H6|H8|H12|D1|W1)(?:_|\.)", re.I)


class ActivationError(ValueError):
    """The B binding or the row proof is unavailable; callers fail closed."""


def _sha(raw: bytes) -> str:
    return hashlib.sha256(raw).hexdigest()


def _canonical(value: Any) -> bytes:
    return (json.dumps(value, sort_keys=True, separators=(",", ":"), allow_nan=False) + "\n").encode()


def _strict_bytes(raw: bytes) -> Any:
    def pairs(items):
        result = {}
        for key, value in items:
            if key in result:
                raise ActivationError(f"duplicate JSON key: {key}")
            result[key] = value
        return result
    try:
        return json.loads(raw.decode("utf-8-sig"), object_pairs_hook=pairs,
                          parse_constant=lambda value: (_ for _ in ()).throw(
                              ActivationError(f"nonfinite JSON: {value}")))
    except (UnicodeError, ValueError, TypeError) as exc:
        if isinstance(exc, ActivationError):
            raise
        raise ActivationError(f"invalid JSON: {exc}") from exc


def _digest(value: Any, label: str) -> str:
    if not isinstance(value, str) or not HEX.fullmatch(value):
        raise ActivationError(f"invalid {label} SHA-256")
    return value


def _read_bound(path_value: Any, digest_value: Any, label: str) -> tuple[Path, bytes]:
    if not isinstance(path_value, (str, Path)) or not str(path_value).strip():
        raise ActivationError(f"missing {label} path")
    path = Path(path_value)
    try:
        raw = path.read_bytes()
    except OSError as exc:
        raise ActivationError(f"{label} unavailable: {exc}") from exc
    expected = _digest(digest_value, label)
    actual = _sha(raw)
    if actual != expected:
        raise ActivationError(f"{label} SHA-256 mismatch: expected={expected} actual={actual}")
    return path, raw


@dataclass(frozen=True)
class Activation:
    config: Mapping[str, Any]
    binding_sha256: str
    declarations: tuple[Mapping[str, Any], ...]
    declarations_by_currency_month: Mapping[tuple[str, str], tuple[Mapping[str, Any], ...]]
    high_classes: Mapping[tuple[str, str], frozenset[str]]


def load_activation(path: Path = CONFIG) -> Activation:
    """Authenticate config, candidate manifest, declarations, and both CSVs."""
    try:
        raw_config = Path(path).read_bytes()
    except OSError as exc:
        raise ActivationError(f"activation config unavailable: {exc}") from exc
    config = _strict_bytes(raw_config)
    if not isinstance(config, dict) or config.get("schema") != SCHEMA:
        raise ActivationError("unknown activation schema")
    if type(config.get("enabled")) is not bool:
        raise ActivationError("activation enabled must be boolean")
    decision = config.get("decision")
    if not isinstance(decision, dict) or not all(
        isinstance(decision.get(key), str) and decision[key].strip()
        for key in ("id", "receipt_id", "evidence")
    ):
        raise ActivationError("OWNER decision binding incomplete")
    candidate = config.get("candidate")
    if not isinstance(candidate, dict):
        raise ActivationError("candidate binding missing")
    manifest_path, manifest_raw = _read_bound(
        candidate.get("manifest_path"), candidate.get("manifest_sha256"), "candidate manifest"
    )
    declarations_path, declarations_raw = _read_bound(
        candidate.get("declarations_path"), candidate.get("declarations_sha256"), "declarations"
    )
    manifest = _strict_bytes(manifest_raw)
    declarations = _strict_bytes(declarations_raw)
    if not isinstance(manifest, dict) or manifest.get("schema") != "qm.news-calendar-repair-e1a/v1":
        raise ActivationError("candidate manifest schema mismatch")
    if manifest.get("publishable") is not False or manifest.get("scoped_review_only") is not True:
        raise ActivationError("B requires the scoped, non-publishable candidate")
    if manifest.get("declared_inadmissible_ranges_sha256") != candidate.get("declarations_sha256"):
        raise ActivationError("candidate/declarations binding mismatch")
    if manifest.get("declared_inadmissible_ranges") != declarations:
        raise ActivationError("candidate declarations differ from external manifest")
    if not isinstance(declarations, list) or not declarations:
        raise ActivationError("empty declarations cannot authorize B")

    file_hashes = candidate.get("calendar_files")
    if not isinstance(file_hashes, dict) or set(file_hashes) != set(e1c.FILES):
        raise ActivationError("exact candidate CSV pair required")
    manifest_files = {
        row.get("name"): row.get("sha256")
        for row in manifest.get("files", []) if isinstance(row, dict)
    }
    high_classes: dict[tuple[str, str], set[str]] = {}
    for name in e1c.FILES:
        expected = _digest(file_hashes[name], name)
        if manifest_files.get(name) != expected:
            raise ActivationError(f"candidate manifest CSV binding mismatch: {name}")
        csv_path, csv_raw = _read_bound(manifest_path.parent / name, expected, name)
        del csv_path
        text = csv_raw.decode("utf-8-sig")
        reader = csv.DictReader(text.splitlines())
        if name == "news_calendar_2015_2025.csv":
            fields = ("datetime", "currency", "event_name", "impact")
            fmt = "%Y-%m-%d %H:%M:%S"
        else:
            fields = ("DateTime_UTC", "Currency", "Event", "Impact")
            fmt = "%Y.%m.%d %H:%M:%S"
        if not reader.fieldnames or not set(fields).issubset(reader.fieldnames):
            raise ActivationError(f"candidate CSV layout mismatch: {name}")
        count = 0
        for row in reader:
            count += 1
            if str(row[fields[3]]).strip().upper() != "HIGH":
                continue
            try:
                moment = dt.datetime.strptime(str(row[fields[0]]), fmt)
            except ValueError as exc:
                raise ActivationError(f"candidate CSV timestamp invalid: {name}") from exc
            currency = str(row[fields[1]]).strip().upper()
            event_class = str(row[fields[2]]).strip()
            if not re.fullmatch(r"[A-Z]{3}", currency) or not event_class:
                raise ActivationError(f"candidate CSV exposure class invalid: {name}")
            high_classes.setdefault((currency, moment.strftime("%Y-%m")), set()).add(event_class)
        if count <= 0:
            raise ActivationError(f"candidate CSV empty: {name}")

    admissibility = config.get("admissibility")
    if not isinstance(admissibility, dict):
        raise ActivationError("admissibility policy missing")
    if admissibility.get("phase") != "Q10_NEWS" or admissibility.get("timeframes") != ["D1"]:
        raise ActivationError("activation must remain Q10_NEWS D1-only")
    if admissibility.get("impact") != "HIGH" or admissibility.get("permitted_currencies") != ["USD"]:
        raise ActivationError("activation must remain HIGH-impact USD-only")
    if admissibility.get("require_sealed_q10_window") is not True:
        raise ActivationError("sealed Q10 window requirement cannot be disabled")
    if admissibility.get("release_mode") != "OWNER_ROW_BY_ROW":
        raise ActivationError("release mode must remain OWNER_ROW_BY_ROW")
    marker = config.get("counter_marker")
    if not isinstance(marker, dict) or marker.get("schema") != MARKER_SCHEMA \
            or marker.get("payload_key") != MARKER_KEY or marker.get("footnote") != FOOTNOTE:
        raise ActivationError("counter marker contract mismatch")
    readjudication = config.get("readjudication")
    if not isinstance(readjudication, dict) or readjudication.get("mode") != "APPEND_ONLY_RERUN" \
            or readjudication.get("overwrite_existing_verdicts") is not False:
        raise ActivationError("append-only re-adjudication contract missing")
    _digest(readjudication.get("full_scope_seal_sha256"), "future full-scope seal")
    binding = {
        "schema": config["schema"], "decision": decision, "candidate": candidate,
        "admissibility": admissibility, "counter_marker": marker,
        "readjudication": readjudication,
    }
    declaration_index: dict[tuple[str, str], list[Mapping[str, Any]]] = {}
    for declaration in declarations:
        currency = str(declaration.get("currency") or "")
        months = declaration.get("months")
        if not currency or not isinstance(months, list) or not months:
            raise ActivationError("declaration currency/months invalid")
        for month in months:
            if not isinstance(month, str) or not re.fullmatch(r"\d{4}-\d{2}", month):
                raise ActivationError("declaration month invalid")
            declaration_index.setdefault((currency, month), []).append(declaration)
    return Activation(config=config, binding_sha256=_sha(_canonical(binding)),
                      declarations=tuple(declarations),
                      declarations_by_currency_month={
                          key: tuple(value) for key, value in declaration_index.items()
                      },
                      high_classes={k: frozenset(v) for k, v in high_classes.items()})


def _payload(value: Any) -> dict[str, Any]:
    if isinstance(value, dict):
        return dict(value)
    try:
        parsed = json.loads(value or "{}")
    except (TypeError, ValueError):
        return {}
    return parsed if isinstance(parsed, dict) else {}


def _timeframe(item: Mapping[str, Any], payload: Mapping[str, Any]) -> str | None:
    direct = payload.get("host_timeframe") or payload.get("expected_period")
    if isinstance(direct, str) and direct.strip():
        return direct.strip().upper()
    match = TIMEFRAME.search(str(item.get("setfile_path") or ""))
    return match.group(1).upper() if match else None


def _symbols(item: Mapping[str, Any], payload: Mapping[str, Any]) -> list[str]:
    basket = payload.get("basket_symbols")
    if basket is not None:
        if not isinstance(basket, list) or not basket or not all(isinstance(v, str) and v for v in basket):
            raise ActivationError("unknown basket composition")
        return sorted(set(basket))
    symbol = payload.get("host_symbol") or item.get("symbol")
    if not isinstance(symbol, str) or not symbol.strip():
        raise ActivationError("missing symbol exposure")
    return [symbol.strip()]


def _currencies(symbols: list[str], activation: Activation) -> list[str]:
    overrides = activation.config["admissibility"].get("symbol_currency_overrides")
    if not isinstance(overrides, dict):
        raise ActivationError("symbol currency overrides missing")
    result: set[str] = set()
    for symbol in symbols:
        upper = symbol.upper()
        mapped = overrides.get(upper)
        if mapped is not None:
            if not isinstance(mapped, list) or not mapped or not all(re.fullmatch(r"[A-Z]{3}", str(v)) for v in mapped):
                raise ActivationError(f"invalid symbol currency override: {symbol}")
            result.update(mapped)
            continue
        base = upper.removesuffix(".DWX")
        if re.fullmatch(r"[A-Z]{6}", base):
            result.update((base[:3], base[3:]))
            continue
        raise ActivationError(f"unknown symbol exposure: {symbol}")
    return sorted(result)


def _sealed_window(
    payload: Mapping[str, Any], item: Mapping[str, Any]
) -> tuple[dt.datetime, dt.datetime, str]:
    scoped = payload.get("scoped_q10_window_seal")
    if isinstance(scoped, dict):
        seal_sha = str(scoped.get("seal_sha256") or "")
        material = dict(scoped)
        material.pop("seal_sha256", None)
        if (
            scoped.get("schema") != "qm.scoped-q10-window-seal/v1"
            or scoped.get("scope") != "NEWS_CALENDAR_SCOPED_CONSUMER_B_ONLY"
            or scoped.get("source_phase") != "Q09"
            or scoped.get("source_verdict") != "PASS"
            or scoped.get("terminal_claimable") is not False
            or payload.get("scoped_review_only") is not True
            or payload.get("terminal_claimable") is not False
            or not HEX.fullmatch(seal_sha)
            or _sha(_canonical(material)) != seal_sha
            or str(payload.get("promoted_from_work_item") or "")
            != str(scoped.get("source_work_item_id") or "")
            or str(item.get("ea_id") or "") != str(scoped.get("ea_id") or "")
            or str(item.get("symbol") or "") != str(scoped.get("symbol") or "")
            or str(item.get("setfile_path") or "")
            != str(scoped.get("setfile_path") or "")
        ):
            raise ActivationError("scoped Q10 window seal invalid")
        evidence_path, evidence_raw = _read_bound(
            scoped.get("source_evidence_path"),
            scoped.get("source_evidence_sha256"),
            "scoped Q09 PASS evidence",
        )
        del evidence_path
        evidence = _strict_bytes(evidence_raw)
        if (
            not isinstance(evidence, dict)
            or evidence.get("phase") != "Q09"
            or evidence.get("verdict") != "PASS"
            or str(evidence.get("ea_id") or "")
            != str(scoped.get("ea_id") or "").removeprefix("QM5_")
            or str(evidence.get("symbol") or "") != str(scoped.get("symbol") or "")
        ):
            raise ActivationError("scoped Q09 PASS evidence contradicts seal")
        try:
            start = e1c.utc(scoped.get("window_from_utc"))
            end = e1c.utc(scoped.get("window_to_utc"))
            evidence_start = dt.datetime.strptime(
                str(evidence.get("history_from") or ""), "%Y.%m.%d"
            ).replace(tzinfo=dt.timezone.utc)
            evidence_end = dt.datetime.strptime(
                str(evidence.get("history_to") or ""), "%Y.%m.%d"
            ).replace(tzinfo=dt.timezone.utc) + dt.timedelta(days=1)
        except (e1c.ScopeError, ValueError) as exc:
            raise ActivationError(f"scoped Q10 window seal invalid: {exc}") from exc
        if start != evidence_start or end != evidence_end or start >= end:
            raise ActivationError("scoped Q10 window contradicts Q09 PASS evidence")
        return start, end, str(scoped["source_evidence_sha256"])
    plan_value = payload.get("q09_run_plan_path")
    plan_sha = payload.get("q09_run_plan_file_sha256")
    input_sha = payload.get("q09_input_manifest_sha256")
    if not all(isinstance(v, str) and v for v in (plan_value, plan_sha, input_sha)):
        raise ActivationError("sealed Q10 window unavailable")
    plan_path, plan_raw = _read_bound(plan_value, plan_sha, "sealed Q10 run plan")
    plan = _strict_bytes(plan_raw)
    manifest_value = plan.get("input_manifest_path") if isinstance(plan, dict) else None
    manifest_path, manifest_raw = _read_bound(manifest_value, input_sha, "sealed Q10 input manifest")
    del plan_path, manifest_path
    manifest = _strict_bytes(manifest_raw)
    windows = manifest.get("windows") if isinstance(manifest, dict) else None
    if not isinstance(windows, dict):
        raise ActivationError("sealed Q10 window missing")
    try:
        start = e1c.utc(windows.get("full_from_utc"))
        end_inclusive = e1c.utc(windows.get("full_to_utc"))
    except e1c.ScopeError as exc:
        raise ActivationError(f"sealed Q10 window invalid: {exc}") from exc
    end = end_inclusive + dt.timedelta(seconds=1)
    if start >= end:
        raise ActivationError("sealed Q10 window reversed")
    return start, end, _sha(manifest_raw)


def _months(start: dt.datetime, end: dt.datetime) -> list[str]:
    current = dt.datetime(start.year, start.month, 1, tzinfo=dt.timezone.utc)
    result = []
    while current < end:
        result.append(current.strftime("%Y-%m"))
        current = dt.datetime(current.year + (current.month == 12),
                              1 if current.month == 12 else current.month + 1,
                              1, tzinfo=dt.timezone.utc)
    return result


def assess_work_item(item: Mapping[str, Any], activation: Activation) -> dict[str, Any]:
    """Return ADMISSIBLE only when every E1-C proof is present and exclusion-free."""
    base = {
        "schema": "qm.news-calendar-scoped-row-assessment/v1",
        "work_item_id": str(item.get("id") or ""),
        "ea_id": str(item.get("ea_id") or ""),
        "symbol": str(item.get("symbol") or ""),
        "binding_sha256": activation.binding_sha256,
    }
    reasons: list[str] = []
    payload = _payload(item.get("payload_json"))
    phase = str(item.get("phase") or "")
    status = str(item.get("status") or "")
    if not activation.config.get("enabled"):
        reasons.append("SCOPED_CONSUMER_INACTIVE")
    if phase != "Q10_NEWS" or status != "pending":
        reasons.append("NOT_PENDING_Q10_NEWS")
    timeframe = _timeframe(item, payload)
    if timeframe not in activation.config["admissibility"]["timeframes"]:
        reasons.append("INTRADAY_OR_UNKNOWN_TIMEFRAME")
    symbols: list[str] = []
    currencies: list[str] = []
    start = end = None
    input_manifest_sha = None
    try:
        symbols = _symbols(item, payload)
        currencies = _currencies(symbols, activation)
    except ActivationError as exc:
        reasons.append(str(exc).upper().replace(" ", "_"))
    permitted = set(activation.config["admissibility"]["permitted_currencies"])
    if currencies and (set(currencies) - permitted or set(currencies) != permitted):
        reasons.append("NON_USD_EXPOSURE")
    try:
        start, end, input_manifest_sha = _sealed_window(payload, item)
    except ActivationError as exc:
        reasons.append(str(exc).upper().replace(" ", "_"))

    matched: list[Mapping[str, Any]] = []
    exposure_classes: set[tuple[str, str, str]] = set()
    if start is not None and end is not None and currencies:
        months = _months(start, end)
        for currency in currencies:
            for month in months:
                for event_class in activation.high_classes.get((currency, month), frozenset()):
                    exposure_classes.add((currency, event_class, month))
        if not exposure_classes:
            reasons.append("NO_BOUND_HIGH_IMPACT_EXPOSURE_CLASSES")
        wildcards = set(activation.config["admissibility"]["declaration_wildcards_for_high"])
        matched_by_id: dict[str, Mapping[str, Any]] = {}
        for currency, event_class, month in exposure_classes:
            candidates = (
                *activation.declarations_by_currency_month.get((currency, month), ()),
                *activation.declarations_by_currency_month.get(("ALL", month), ()),
            )
            for declaration in candidates:
                d_class = declaration.get("event_class")
                if d_class == event_class or d_class in wildcards:
                    matched_by_id[str(declaration.get("id"))] = declaration
        matched = list(matched_by_id.values())
        if matched:
            reasons.append("DECLARED_EXCLUSION_OVERLAP")
    verdict = "ADMISSIBLE" if not reasons else "EXCLUDED"
    exclusion_ids = sorted({str(row.get("id")) for row in matched})
    result = {
        **base, "verdict": verdict, "reasons": sorted(set(reasons)),
        "timeframe": timeframe, "symbols": symbols, "currencies": currencies,
        "window_from_utc": start.isoformat() if start else None,
        "window_to_utc": end.isoformat() if end else None,
        "input_manifest_sha256": input_manifest_sha,
        "exposure_class_count": len(exposure_classes),
        "declared_exclusion_count": len(exclusion_ids),
        "declared_exclusion_ids_sha256": _sha(_canonical(exclusion_ids)),
        "declared_exclusion_ids_sample": exclusion_ids[:12],
    }
    result["assessment_sha256"] = _sha(_canonical(result))
    return result


def marker_for(item: Mapping[str, Any], activation: Activation, *, adjudicated_at: str) -> dict[str, Any]:
    assessment = assess_work_item(item, activation)
    if assessment["verdict"] != "ADMISSIBLE":
        raise ActivationError("row is not B-admissible: " + ",".join(assessment["reasons"]))
    config = activation.config
    return {
        "schema": MARKER_SCHEMA,
        "decision_id": config["decision"]["id"],
        "decision_receipt_id": config["decision"]["receipt_id"],
        "binding_sha256": activation.binding_sha256,
        "candidate_manifest_sha256": config["candidate"]["manifest_sha256"],
        "declarations_sha256": config["candidate"]["declarations_sha256"],
        "assessment_sha256": assessment["assessment_sha256"],
        "adjudicated_at": adjudicated_at,
        "footnote": FOOTNOTE,
        "readjudication_ticket_id": config["readjudication"]["ticket_id"],
        "readjudication_trigger": config["readjudication"]["trigger"],
        "append_only_readjudication": True,
    }


def marker_valid(item: Mapping[str, Any], activation: Activation) -> bool:
    payload = _payload(item.get("payload_json"))
    marker = payload.get(MARKER_KEY)
    if not isinstance(marker, dict) or marker.get("schema") != MARKER_SCHEMA:
        return False
    config = activation.config
    expected = {
        "decision_id": config["decision"]["id"],
        "decision_receipt_id": config["decision"]["receipt_id"],
        "binding_sha256": activation.binding_sha256,
        "candidate_manifest_sha256": config["candidate"]["manifest_sha256"],
        "declarations_sha256": config["candidate"]["declarations_sha256"],
        "footnote": FOOTNOTE,
        "readjudication_ticket_id": config["readjudication"]["ticket_id"],
        "append_only_readjudication": True,
    }
    if any(marker.get(key) != value for key, value in expected.items()):
        return False
    assessment = assess_work_item(item, activation)
    return assessment["verdict"] == "ADMISSIBLE" \
        and marker.get("assessment_sha256") == assessment["assessment_sha256"]


def marker_from_payload(payload_value: Any) -> dict[str, Any] | None:
    """Presentation-only marker parser; it never grants claimability."""
    marker = _payload(payload_value).get(MARKER_KEY)
    if not isinstance(marker, dict) or marker.get("schema") != MARKER_SCHEMA \
            or marker.get("footnote") != FOOTNOTE or not HEX.fullmatch(
                str(marker.get("binding_sha256") or "")):
        return None
    return marker


def dry_run(connection: sqlite3.Connection, activation: Activation) -> dict[str, Any]:
    connection.row_factory = sqlite3.Row
    rows = connection.execute(
        "SELECT id,ea_id,symbol,phase,status,setfile_path,payload_json,created_at "
        "FROM work_items WHERE phase='Q10_NEWS' AND status='pending' "
        "AND NOT EXISTS (SELECT 1 FROM work_item_supersedes s "
        "WHERE s.work_item_id=work_items.id) ORDER BY created_at,id"
    ).fetchall()
    assessments = [assess_work_item(dict(row), activation) for row in rows]
    counts: dict[str, int] = {}
    for row in assessments:
        counts[row["verdict"]] = counts.get(row["verdict"], 0) + 1
    priority_id = "a909ee18-9f16-4706-967e-daa080b6f720"
    return {
        "schema": "qm.news-calendar-scoped-consumer-b-dry-run/v1",
        "binding_sha256": activation.binding_sha256,
        "candidate_manifest_sha256": activation.config["candidate"]["manifest_sha256"],
        "declarations_sha256": activation.config["candidate"]["declarations_sha256"],
        "pending_q10_news_count": len(assessments),
        "priority_row": priority_id,
        "priority_row_included": any(row["work_item_id"] == priority_id for row in assessments),
        "counts": counts,
        "rows": assessments,
    }


def main() -> int:
    import argparse
    parser = argparse.ArgumentParser()
    parser.add_argument("--config", type=Path, default=CONFIG)
    parser.add_argument("--db", type=Path, default=Path("D:/QM/strategy_farm/state/farm_state.sqlite"))
    parser.add_argument("--output", type=Path)
    args = parser.parse_args()
    activation = load_activation(args.config)
    uri = args.db.resolve().as_uri() + "?mode=ro"
    with sqlite3.connect(uri, uri=True) as connection:
        document = json.dumps(dry_run(connection, activation), indent=2, sort_keys=True) + "\n"
    if args.output:
        args.output.parent.mkdir(parents=True, exist_ok=True)
        args.output.write_text(document, encoding="utf-8", newline="\n")
        print(args.output)
    else:
        print(document, end="")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
