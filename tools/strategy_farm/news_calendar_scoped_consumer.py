"""Inert option-B scope contract. No publication, queue, ledger or runtime writes.

Legacy entry points remain unchanged and refuse this schema/prefix. Availability
is an additive non-promoting projection, never a persisted pipeline verdict.
"""
from __future__ import annotations

import csv
from dataclasses import dataclass
from datetime import datetime, timedelta, timezone
import hashlib
import io
import json
import os
import re
from typing import Callable, Mapping
from zoneinfo import ZoneInfo

FLAG = "QM_NEWS_SCOPED_CONSUMER_V1"
SCHEMA = "qm.news-calendar-scoped/v1"
CONSUMER = "qm.news-scope-consumer/v1"
PROOF_SCHEMA = "qm.news-scope-source-proof/v1"
MAPPING_SCHEMA = "qm.news-scope-mapping/v1"
POLICY_SCHEMA = "qm.news-scope-window/v1"
FILES = ("news_calendar_2015_2025.csv", "forex_factory_calendar_clean.csv")
WILDCARDS = frozenset({"ALL", "ALL_HIGH", "ALL_UNRESOLVED", "ALL_RATE_AND_NONRATE"})


class ScopeError(ValueError):
    """Unknown availability; callers must deny scope-dependent authorization."""


def sha(raw: bytes) -> str:
    return hashlib.sha256(raw).hexdigest()


def canonical(value) -> bytes:
    return (json.dumps(value, sort_keys=True, separators=(",", ":"), allow_nan=False) + "\n").encode()


def strict(raw: bytes) -> dict:
    def pairs(items):
        obj = {}
        for key, value in items:
            if key in obj:
                raise ScopeError("duplicate JSON key: " + key)
            obj[key] = value
        return obj
    try:
        value = json.loads(raw.decode("utf-8"), object_pairs_hook=pairs,
                           parse_constant=lambda s: (_ for _ in ()).throw(ScopeError("nonfinite JSON")))
    except (UnicodeError, ValueError, TypeError) as exc:
        raise ScopeError("invalid scope JSON: " + str(exc)) from exc
    if not isinstance(value, dict):
        raise ScopeError("scope JSON must be an object")
    return value


def require(value, message):
    if not value:
        raise ScopeError(message)


def digest(value) -> str:
    require(isinstance(value, str) and re.fullmatch("[0-9a-f]{64}", value), "invalid SHA-256")
    return value


def utc(value: str) -> datetime:
    try:
        result = datetime.fromisoformat(value.replace("Z", "+00:00"))
        require(result.tzinfo is not None and result.utcoffset() == timedelta(0), "explicit UTC required")
        return result.astimezone(timezone.utc)
    except (ValueError, TypeError, AttributeError) as exc:
        raise ScopeError("invalid UTC instant") from exc


def interval(obj) -> tuple[datetime, datetime]:
    require(isinstance(obj, dict), "missing interval")
    a, b = utc(obj.get("from_utc")), utc(obj.get("to_utc"))
    require(a < b, "empty or reversed interval")
    return a, b


def month(value: str) -> tuple[datetime, datetime]:
    require(isinstance(value, str) and re.fullmatch(r"\d{4}-\d{2}", value), "explicit UTC month required")
    try:
        y, m = map(int, value.split("-"))
        a = datetime(y, m, 1, tzinfo=timezone.utc)
        b = datetime(y + (m == 12), 1 if m == 12 else m + 1, 1, tzinfo=timezone.utc)
        return a, b
    except ValueError as exc:
        raise ScopeError("invalid UTC month") from exc


def enabled(env: Mapping[str, str] | None = None) -> bool:
    return (os.environ if env is None else env).get(FLAG) == "1"


@dataclass(frozen=True)
class BoundScope:
    # Only immutable bytes are retained; no caller-owned nested dict can mutate the proof.
    sidecar: bytes
    primary: bytes
    secondary: bytes
    proof: bytes
    tzif: bytes
    bundle_id: str
    bundle_sha256: str


def load(*, sidecar: bytes, csv_bytes: Mapping[str, bytes], source_proof: bytes,
         timezone_bytes: bytes, expected_sidecar_sha256: str,
         consumer_version: str = CONSUMER) -> BoundScope:
    """Verify a complete immutable in-memory package, including every raw byte.

    The caller's expected sidecar hash must come from the sealed plan, not the
    sidecar itself. No active option-A directory is read or altered here.
    """
    try:
        require(isinstance(sidecar, bytes) and sidecar, "missing sidecar")
        require(sha(sidecar) == digest(expected_sidecar_sha256), "sidecar SHA-256 mismatch")
        s = strict(sidecar)
        require(s.get("schema") == SCHEMA, "unknown scope schema")
        require(consumer_version == CONSUMER and s.get("consumer_version") == consumer_version,
                "incompatible consumer version")
        require(set(csv_bytes) == set(FILES) and set(s.get("csv_sha256", {})) == set(FILES), "exact CSV pair required")
        require(isinstance(source_proof, bytes) and source_proof, "missing source proof")
        require(sha(source_proof) == digest(s.get("source_proof_sha256")), "source proof SHA-256 mismatch")
        proof = strict(source_proof)
        require(proof.get("schema") == PROOF_SCHEMA, "unknown source proof schema")
        require(proof.get("measured_full_scope_pass") is False, "scoped proof cannot claim full-scope PASS")
        envelope = interval(s.get("coverage_envelope"))
        require(proof.get("coverage_envelope") == s.get("coverage_envelope"), "source envelope mismatch")
        mapping = s.get("mapping", {})
        require(mapping.get("schema") == MAPPING_SCHEMA and isinstance(mapping.get("version"), str) and mapping["version"], "mapping version required")
        classes = mapping.get("event_classes")
        require(isinstance(classes, dict) and classes, "empty class mapping")
        for name, impacts in classes.items():
            require(isinstance(name, str) and name and name not in WILDCARDS, "invalid event class")
            require(isinstance(impacts, list) and impacts and all(i in {"HIGH", "MEDIUM", "LOW"} for i in impacts), "unknown class impact")
        symbols = mapping.get("symbols")
        require(isinstance(symbols, dict) and symbols, "empty symbol mapping")
        all_ccy = set()
        for symbol, info in symbols.items():
            require(isinstance(symbol, str) and symbol and isinstance(info, dict), "invalid symbol mapping")
            require(set(info) in ({"currencies"}, {"constituents"}), "ambiguous symbol mapping")
            if "currencies" in info:
                ccy = info["currencies"]
                require(isinstance(ccy, list) and ccy and len(ccy) == len(set(ccy)), "empty currency exposure")
                require(all(isinstance(c, str) and re.fullmatch("[A-Z]{3}", c) for c in ccy), "unknown currency")
                all_ccy.update(ccy)
            else:
                parts = info["constituents"]
                require(isinstance(parts, list) and parts and all(x in symbols for x in parts), "unknown basket composition")
        def visit(symbol, trail=()):
            require(symbol not in trail, "cyclic basket")
            for child in symbols[symbol].get("constituents", []):
                visit(child, (*trail, symbol))
        for symbol in symbols:
            visit(symbol)
        policy = s.get("window_policy", {})
        require(policy.get("schema") == POLICY_SCHEMA, "unknown window policy")
        for name in ("look_back_seconds", "look_ahead_seconds"):
            require(type(policy.get(name)) is int and 0 <= policy[name] <= 366 * 86400, "unsealed window expansion")
        require(type(policy.get("whole_local_days")) is bool, "day policy must be explicit")
        require(isinstance(policy.get("timezone"), str) and policy["timezone"], "timezone required")
        require(timezone_bytes and sha(timezone_bytes) == digest(policy.get("tzif_sha256")), "timezone rule bytes mismatch")
        ZoneInfo.from_file(io.BytesIO(timezone_bytes), key=policy["timezone"])
        coverage = s.get("coverage_assertions")
        require(isinstance(coverage, list) and coverage, "empty coverage never means unrestricted")
        require(proof.get("coverage_assertions") == coverage, "coverage assertions lack bound source proof")
        for row in coverage:
            require(row.get("currency") in all_ccy and row.get("event_class") in classes, "unknown coverage currency/class")
            a, b = interval(row)
            require(envelope[0] <= a < b <= envelope[1], "coverage outside envelope")
            require(isinstance(row.get("evidence_id"), str) and row["evidence_id"], "coverage source evidence missing")
        declarations = s.get("declarations")
        require(isinstance(declarations, list), "declarations must be explicit, never missing")
        require(proof.get("declarations_sha256") == sha(canonical(declarations)), "declarations differ from source proof")
        ids = set()
        for row in declarations:
            require(isinstance(row, dict), "invalid declaration")
            for name in ("id", "gate", "reason", "required_evidence"):
                require(isinstance(row.get(name), str) and row[name] and "\n" not in row[name] and "|" not in row[name], "declaration field missing or unsafe")
            require(row["id"] not in ids, "duplicate declaration ID")
            require(re.fullmatch(r"[A-Za-z0-9_-]+", row["id"]), "declaration ID must be receipt-safe ASCII")
            ids.add(row["id"])
            require(row.get("currency") in all_ccy | {"ALL"}, "unknown declaration currency")
            require(row.get("event_class") in set(classes) | WILDCARDS, "unknown declaration class")
            require(row.get("usage") == "INADMISSIBLE" and row.get("production_use_permitted") is False, "declaration cannot confer permission")
            months = row.get("months")
            require(isinstance(months, list) and months, "empty declaration months")
            for item in months:
                month(item)
        layouts = s.get("csv_columns", {})
        for name in FILES:
            raw = csv_bytes[name]
            require(isinstance(raw, bytes) and raw, "empty calendar input")
            require(sha(raw) == digest(s["csv_sha256"][name]), "CSV SHA-256 mismatch: " + name)
            layout = layouts.get(name, {})
            require(set(layout) == {"time", "currency", "class", "impact"}, "CSV column roles incomplete")
            reader = csv.DictReader(io.StringIO(raw.decode("utf-8-sig")))
            require(reader.fieldnames and len(reader.fieldnames) == len(set(reader.fieldnames)) and set(layout.values()) <= set(reader.fieldnames), "CSV header mismatch")
            n = 0
            for row in reader:
                require(None not in row and all(v is not None for v in row.values()), "malformed CSV row")
                moment = utc(row[layout["time"]])
                require(envelope[0] <= moment < envelope[1], "CSV event outside coverage envelope")
                require(row[layout["currency"]] in all_ccy, "unknown CSV currency")
                cls = row[layout["class"]]
                require(cls in classes and row[layout["impact"]] in classes[cls], "unknown CSV class/impact")
                n += 1
            require(n > 0, "header-only input never means unrestricted")
        material = {"schema": SCHEMA, "sidecar_sha256": sha(sidecar),
                    "csv_sha256": {n: sha(csv_bytes[n]) for n in FILES},
                    "source_proof_sha256": sha(source_proof), "tzif_sha256": sha(timezone_bytes),
                    "consumer_version": consumer_version}
        identity = sha(canonical(material))
        return BoundScope(sidecar, csv_bytes[FILES[0]], csv_bytes[FILES[1]], source_proof,
                          timezone_bytes, "qmscopecal-v1-" + identity, identity)
    except (KeyError, TypeError, UnicodeError, ValueError, AttributeError) as exc:
        if isinstance(exc, ScopeError):
            raise
        raise ScopeError("invalid scope package: " + str(exc)) from exc


def _currencies(s: dict, requested: list[str]) -> list[str]:
    require(isinstance(requested, list) and requested, "empty requested exposure")
    symbols = s["mapping"]["symbols"]
    def visit(symbol, seen=()):
        require(symbol in symbols and symbol not in seen, "unknown symbol/basket composition")
        entry = symbols[symbol]
        if "currencies" in entry:
            return set(entry["currencies"])
        return set().union(*(visit(child, (*seen, symbol)) for child in entry["constituents"]))
    return sorted(set().union(*(visit(symbol) for symbol in requested)))


def expanded_window(bound: BoundScope, request: dict) -> tuple[datetime, datetime]:
    a, b = interval(request)
    policy = strict(bound.sidecar)["window_policy"]
    a -= timedelta(seconds=policy["look_back_seconds"])
    b += timedelta(seconds=policy["look_ahead_seconds"])
    if policy["whole_local_days"]:
        tz = ZoneInfo.from_file(io.BytesIO(bound.tzif), key=policy["timezone"])
        first = a.astimezone(tz).date()
        final = (b - timedelta(microseconds=1)).astimezone(tz).date() + timedelta(days=1)
        a = datetime.combine(first, datetime.min.time(), tz).astimezone(timezone.utc)
        b = datetime.combine(final, datetime.min.time(), tz).astimezone(timezone.utc)
    return a, b


def availability(bound: BoundScope, request: dict) -> dict:
    """Conservative scope only: AVAILABLE never implies healthy news, PASS or credit."""
    try:
        s = strict(bound.sidecar)
        require(request.get("consumer_version") == CONSUMER, "request consumer mismatch")
        require(request.get("bundle_sha256") == bound.bundle_sha256, "request bundle mismatch")
        require(request.get("window_policy_sha256") == sha(canonical(s["window_policy"])), "unsealed request policy")
        ccy = _currencies(s, request.get("symbols"))
        classes = s["mapping"]["event_classes"]
        # All mapped event classes remain relevant; no unproved impact exemption.
        a, b = expanded_window(bound, request)
        env = interval(s["coverage_envelope"])
        reasons = set()
        if not (env[0] <= a < b <= env[1]):
            reasons.add("OUTSIDE_COVERAGE_ENVELOPE")
        matched = []
        for row in s["declarations"]:
            if row["currency"] in [*ccy, "ALL"] and any(a < month(m)[1] and b > month(m)[0] for m in row["months"]):
                matched.append(row)
                reasons.add(row["reason"])
        missing = []
        for currency in ccy:
            for cls in classes:
                spans = sorted(interval(r) for r in s["coverage_assertions"] if r["currency"] == currency and r["event_class"] == cls)
                cursor = a
                for lo, hi in spans:
                    if hi <= cursor:
                        continue
                    if lo > cursor:
                        break
                    cursor = max(cursor, hi)
                    if cursor >= b:
                        break
                if cursor < b:
                    missing.append(currency + "/" + cls)
        if missing:
            reasons.add("INCOMPLETE_SCOPE_COVERAGE")
        return {"availability": "UNCONFIRMED" if reasons else "AVAILABLE", "currencies": ccy,
                "expanded_from_utc": a.isoformat(), "expanded_to_utc": b.isoformat(),
                "declaration_ids": sorted({r["id"] for r in matched}),
                "declaration_gates": sorted({r["gate"] for r in matched}),
                "reasons": sorted(reasons), "missing_coverage": missing,
                "bundle_sha256": bound.bundle_sha256, "request_sha256": sha(canonical(request)),
                "new_release_credit": False}
    except (ScopeError, TypeError, KeyError, OverflowError) as exc:
        return {"availability": "UNCONFIRMED", "declaration_ids": [], "declaration_gates": [],
                "reasons": ["SCOPE_PROOF_ERROR: " + str(exc)], "new_release_credit": False}


def bind_run_plan(bound: BoundScope, request: dict, *, implementation_sha256: str,
                  legacy_input_bytes: bytes) -> dict:
    """Append-only proposal identity. No current plan or effective set is edited."""
    assessment = availability(bound, request)
    material = {"schema": "qm.news-scoped-run-plan/v1", "consumer_version": CONSUMER,
                "implementation_sha256": digest(implementation_sha256),
                "bundle_id": bound.bundle_id, "bundle_sha256": bound.bundle_sha256,
                "sidecar_sha256": sha(bound.sidecar), "request": request,
                "legacy_input_sha256": sha(legacy_input_bytes), "scope": assessment}
    material["run_plan_sha256"] = sha(canonical(material))
    material["effective_input_sha256"] = sha(canonical({"run_plan_sha256": material["run_plan_sha256"],
                                                       "legacy_input_sha256": sha(legacy_input_bytes)}))
    return material


def project(consumer: str, legacy_result: dict, assessment: dict, *, env=None) -> dict:
    """Flag off returns the original object without copying or inspecting it."""
    if not enabled(env):
        return legacy_result
    require(consumer in {"ENTRY", "BOUNDARY", "POSITIONS", "Q09", "Q10", "ADMISSION"}, "unknown consumer")
    require(isinstance(assessment, dict) and assessment.get("availability") in {"AVAILABLE", "UNCONFIRMED"}, "missing scope assessment")
    if assessment["availability"] == "AVAILABLE":
        return legacy_result
    result = dict(legacy_result)
    result["scope_projection"] = assessment
    result["new_release_credit"] = False
    if consumer == "ENTRY":
        result.update(entry_authorized=False, status="BLACKOUT_UNKNOWN", declaration_ids=assessment.get("declaration_ids", []))
    elif consumer == "BOUNDARY":
        result.update(status="DATA_ERROR", event_time=None, safe_close_time=None)
    elif consumer == "POSITIONS":
        result.update(compliance_certified=False, preserve_emergency_protections=True,
                      preserve_risk_reduction=True, scope_forced_close_time=None)
    elif consumer in {"Q09", "Q10"}:
        result.update(availability="UNCONFIRMED", status="UNCONFIRMED", selection_credit=False,
                      config_locked=False, fallback_off_credit=False)
    else:
        result.update(availability="UNCONFIRMED", admission_credit=False)
    return result


def experiment(bound: BoundScope, cells: list[dict], *, expected_cells: list[dict], env=None,
               legacy_result: dict) -> dict:
    """The predeclared attempted denominator includes missing and zero-trade cells."""
    if not enabled(env):
        return legacy_result
    require(expected_cells and len({r["id"] for r in expected_cells}) == len(expected_cells), "sealed attempted-cell roster required")
    require(len({r["id"] for r in cells}) == len(cells), "duplicate observed cell")
    expected = {r["id"]: r for r in expected_cells}
    require(all(r["id"] in expected for r in cells), "unplanned cell")
    observed = {r["id"]: r for r in cells}
    # A caller cannot shrink one arm's requested window or remove it from the roster.
    base_windows = {(r["request"]["from_utc"], r["request"]["to_utc"]) for r in expected_cells}
    require(len(base_windows) == 1, "mixed control/policy requested windows")
    outcomes = []
    for key, plan in expected.items():
        actual = observed.get(key)
        scope = availability(bound, plan["request"])
        missing = actual is None or actual.get("result") is None
        mismatch = actual is not None and actual.get("request") != plan["request"]
        unavailable = scope["availability"] != "AVAILABLE" or missing or mismatch
        outcomes.append({"id": key, "availability": "UNCONFIRMED" if unavailable else "AVAILABLE",
                         "missing": missing, "request_mismatch": mismatch, "scope": scope,
                         "trades": actual.get("trades") if actual else None})
    unknown = sum(r["availability"] == "UNCONFIRMED" for r in outcomes)
    return {"availability": "UNCONFIRMED" if unknown else "AVAILABLE", "attempted_cells": len(expected),
            "missing_cells": sum(r["missing"] for r in outcomes), "unconfirmed_cells": unknown,
            "cells": outcomes, "selection_credit": False, "new_release_credit": False,
            "legacy_result": legacy_result}


def consume(*, legacy: Callable[[], dict], scoped: Callable[[], dict], env=None) -> dict:
    """Explicit future adapter; no production caller is installed by this change."""
    return scoped() if enabled(env) else legacy()


def ea_receipt(bound: BoundScope, plan: dict) -> bytes:
    """Small ASCII proof for the new EA include, pinned by effective-input hash.

    The EA also hashes all five source files. A whole-window UNCONFIRMED receipt
    denies every new entry in that experiment; it never exempts favorable days.
    """
    request = plan["request"]
    expected = availability(bound, request)
    require(plan.get("scope") == expected and plan.get("bundle_sha256") == bound.bundle_sha256, "EA receipt plan mismatch")
    material = {k: v for k, v in plan.items() if k not in {"run_plan_sha256", "effective_input_sha256"}}
    require(plan.get("run_plan_sha256") == sha(canonical(material)), "EA receipt plan hash mismatch")
    require(plan.get("effective_input_sha256") == sha(canonical({"run_plan_sha256": plan["run_plan_sha256"], "legacy_input_sha256": plan["legacy_input_sha256"]})), "EA effective identity mismatch")
    a, b = interval(request)
    require(a.microsecond == 0 and b.microsecond == 0, "EA receipt requires whole UTC seconds")
    symbols = request.get("symbols", [])
    require(symbols and all(re.fullmatch(r"[A-Za-z0-9_.-]+", sym) for sym in symbols), "EA symbol encoding invalid")
    rows = ["QM_SCOPE_V1", bound.bundle_id, plan["effective_input_sha256"],
            sha(bound.sidecar), sha(bound.primary), sha(bound.secondary), sha(bound.proof), sha(bound.tzif),
            str(int(a.timestamp())), str(int(b.timestamp())), expected["availability"],
            ",".join(sorted(symbols)), ",".join(expected.get("declaration_ids", [])) or "-",
            plan["implementation_sha256"]]
    return ("\n".join(rows) + "\n").encode("ascii")
