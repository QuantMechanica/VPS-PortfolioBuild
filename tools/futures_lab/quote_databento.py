"""Quote-only Databento metadata client; no market-data download or purchase path.

Interface verified 2026-09-22 against official primary sources:
https://databento.com/docs/api-reference-historical/symbology/symbology-resolve
https://raw.githubusercontent.com/databento/databento-python/main/databento/historical/api/metadata.py
https://raw.githubusercontent.com/databento/databento-python/main/databento/historical/api/symbology.py
https://raw.githubusercontent.com/databento/databento-python/main/databento/common/http.py

Current SDK implementation uses POST form data despite older GET docstrings.
Only main() loads the local DPAPI credential. Import and tests need no credential.
Use --plan data_requests.json --output <new-receipt.json> after account setup.
The disk check reserves the entire configured raw/derived budget; billable DBN
bytes do not establish actual disk/RAM consumption. No quote authorizes download.
"""
from __future__ import annotations

import argparse
import base64
import hashlib
import http.client
import json
import re
import shutil
import ssl
from datetime import date, datetime, time, timedelta, timezone
from decimal import Decimal, InvalidOperation
from pathlib import Path
from urllib.parse import urlencode


HOST = "hist.databento.com"
METHODS = frozenset({"symbology.resolve", "metadata.get_cost",
                     "metadata.get_record_count", "metadata.get_billable_size"})
SCHEMAS = frozenset({"definition", "mbp-1", "status"})
MAX_RESPONSE_BYTES = 1024 * 1024
GIB = 1024 ** 3


class QuoteError(Exception):
    """Only fixed local error codes, never remote bodies, headers or credentials."""


def json_bytes(value) -> bytes:
    return json.dumps(value, sort_keys=True, separators=(",", ":"),
                      ensure_ascii=True, allow_nan=False).encode("utf-8")


def number(value, *, integer=False):
    if type(value) not in (int, float, Decimal):
        raise QuoteError("INVALID_NUMERIC_METADATA")
    try:
        result = Decimal(str(value))
    except (InvalidOperation, ValueError):
        raise QuoteError("INVALID_NUMERIC_METADATA") from None
    if not result.is_finite() or result < 0:
        raise QuoteError("INVALID_NUMERIC_METADATA")
    if integer:
        if type(value) is not int:
            raise QuoteError("NON_INTEGER_METADATA")
        return value
    return result


def timestamp(value) -> datetime:
    if not isinstance(value, str):
        raise QuoteError("INVALID_REQUEST_TIME")
    try:
        parsed = datetime.fromisoformat(value.replace("Z", "+00:00"))
    except ValueError:
        raise QuoteError("INVALID_REQUEST_TIME") from None
    if parsed.tzinfo is None or parsed.utcoffset() is None:
        raise QuoteError("TIMEZONE_REQUIRED")
    return parsed.astimezone(timezone.utc)


def validate_plan(plan: dict) -> dict:
    try:
        if (plan["schema"] != "qm.futures-data-plan/v1"
                or plan["historical_only"] is not True
                or plan["primary_provider"] != "Databento"
                or plan["dataset"] != "GLBX.MDP3" or plan["currency"] != "USD"):
            raise QuoteError("UNSUPPORTED_PLAN")
        req = plan["first_request"]
        budget = plan["budget_proposal_not_an_executed_purchase"]
        symbol = req["symbol"]
        if (not isinstance(symbol, str)
                or re.fullmatch(r"(?:MES|MNQ|ES|NQ)[HMUZ][0-9]{1,2}", symbol) is None
                or req["stype_in"] != "raw_symbol"):
            raise QuoteError("SINGLE_RAW_FUTURES_CONTRACT_REQUIRED")
        schemas = req["schemas"]
        if (not isinstance(schemas, list) or not schemas
                or any(type(s) is not str or s not in SCHEMAS for s in schemas)
                or len(schemas) != len(set(schemas))):
            raise QuoteError("UNSUPPORTED_OR_DUPLICATE_SCHEMA")
        start, end = timestamp(req["start"]), timestamp(req["end"])
        if not timedelta(0) < end - start <= timedelta(days=7):
            raise QuoteError("PILOT_RANGE_MUST_BE_WITHIN_SEVEN_DAYS")
        cost_cap = number(req["max_initial_quote_usd"])
        cash_cap = number(budget["initial_data_out_of_pocket_cap_usd"])
        disk_cap = number(req["max_total_local_raw_and_derived_bytes"], integer=True)
        reserve_gib = number(budget["minimum_factory_free_gib_on_D"], integer=True)
        if cost_cap <= 0 or cash_cap <= 0 or disk_cap <= 0 or reserve_gib < 60:
            raise QuoteError("INVALID_OR_INSUFFICIENT_CAPS")
    except (KeyError, TypeError, AttributeError):
        raise QuoteError("INVALID_PLAN_STRUCTURE") from None
    # Symbology uses inclusive UTC date start and exclusive UTC date end.
    end_date = end.date() + (timedelta(days=1) if end.time() != time(0) else timedelta())
    return {"dataset": "GLBX.MDP3", "symbol": symbol, "stype_in": "raw_symbol",
            "schemas": schemas, "start": start.isoformat(), "end": end.isoformat(),
            "start_date": start.date().isoformat(), "end_date": end_date.isoformat(),
            "quote_cap_usd": str(cost_cap), "cash_cap_usd": str(cash_cap),
            "local_storage_budget_bytes": disk_cap, "factory_reserve_bytes": reserve_gib * GIB}


class MetadataTransport:
    """Direct TLS to one fixed host; no proxies, redirects, retries or URL inputs."""

    def __init__(self, key: str, *, connection_factory=None):
        if (not isinstance(key, str) or re.fullmatch(r"db-[A-Za-z0-9_-]{29}", key) is None):
            raise QuoteError("CREDENTIAL_INVALID")
        self._authorization = "Basic " + base64.b64encode((key + ":").encode("ascii")).decode("ascii")
        self._connection_factory = connection_factory or http.client.HTTPSConnection

    def post_json(self, method: str, params: dict):
        if method not in METHODS:
            raise QuoteError("ENDPOINT_NOT_ALLOWED")
        connection = None
        try:
            connection = self._connection_factory(HOST, timeout=20,
                                                  context=ssl.create_default_context())
            connection.request("POST", "/v0/" + method,
                               body=urlencode(params).encode("ascii"),
                               headers={"Authorization": self._authorization,
                                        "Content-Type": "application/x-www-form-urlencoded",
                                        "Accept": "application/json",
                                        "User-Agent": "QM-Metadata-Quote-Only/1"})
            response = connection.getresponse()
            # http.client never follows redirects. Do not read error bodies.
            if response.status != 200:
                if 300 <= response.status < 400:
                    raise QuoteError("REDIRECT_REFUSED")
                if response.status == 206:
                    raise QuoteError("PARTIAL_HTTP_RESPONSE")
                raise QuoteError("HTTP_STATUS_" + str(response.status))
            if response.getheader("X-Warning"):
                raise QuoteError("REMOTE_WARNING_REQUIRES_REVIEW")
            content_type = response.getheader("Content-Type", "").split(";", 1)[0].strip().lower()
            if content_type != "application/json":
                raise QuoteError("NON_JSON_RESPONSE")
            body = response.read(MAX_RESPONSE_BYTES + 1)
            if len(body) > MAX_RESPONSE_BYTES:
                raise QuoteError("RESPONSE_TOO_LARGE")
            return json.loads(body, parse_float=Decimal)
        except QuoteError:
            raise
        except Exception:
            raise QuoteError("TRANSPORT_OR_JSON_FAILURE") from None
        finally:
            if connection is not None:
                try:
                    connection.close()
                except Exception:
                    pass


def validate_resolution(response, req: dict) -> dict:
    try:
        if (type(response) is not dict or type(response["status"]) is not int
                or response["status"] != 0 or response["partial"] != []
                or response["not_found"] != [] or response["symbols"] != [req["symbol"]]
                or response["stype_in"] != "raw_symbol"
                or response["stype_out"] != "instrument_id"
                or response["start_date"] != req["start_date"]
                or response["end_date"] != req["end_date"]
                or set(response["result"]) != {req["symbol"]}):
            raise QuoteError("SYMBOL_NOT_FULLY_RESOLVED")
        rows = response["result"][req["symbol"]]
        if not isinstance(rows, list) or not rows:
            raise QuoteError("SYMBOL_NOT_FULLY_RESOLVED")
        intervals = []
        ids = set()
        for row in rows:
            instrument_id = row["s"]
            if not isinstance(instrument_id, str) or re.fullmatch(r"[0-9]{1,10}", instrument_id) is None:
                raise QuoteError("INVALID_INSTRUMENT_ID")
            if not 0 < int(instrument_id) <= 4294967295:
                raise QuoteError("INVALID_INSTRUMENT_ID")
            d0, d1 = date.fromisoformat(row["d0"]), date.fromisoformat(row["d1"])
            if d0 >= d1:
                raise QuoteError("INVALID_MAPPING_INTERVAL")
            ids.add(instrument_id)
            intervals.append((d0, d1))
        if len(ids) != 1:
            raise QuoteError("INSTRUMENT_ID_CHANGES_IN_REQUEST")
        cursor, last = date.fromisoformat(req["start_date"]), date.fromisoformat(req["end_date"])
        for first, end in sorted(intervals):
            if first > cursor:
                raise QuoteError("SYMBOL_MAPPING_GAP")
            cursor = max(cursor, end)
        if cursor < last:
            raise QuoteError("SYMBOL_MAPPING_GAP")
        return {"status": "FULL_DATE_COVERAGE_ONE_ID", "instrument_id": next(iter(ids)),
                "start_date": req["start_date"], "end_date": req["end_date"],
                "instrument_definition_verified": False}
    except (KeyError, TypeError, ValueError, AttributeError):
        raise QuoteError("INVALID_SYMBOLOGY_RESPONSE") from None


def _call(transport, method, params):
    try:
        return transport.post_json(method, params)
    except QuoteError as exc:
        # All production QuoteError strings are local constants. Do not accept
        # arbitrary transport messages from future adapters or injected clients.
        safe = {"ENDPOINT_NOT_ALLOWED", "REDIRECT_REFUSED", "PARTIAL_HTTP_RESPONSE",
                "HTTP_REQUEST_REJECTED", "REMOTE_WARNING_REQUIRES_REVIEW", "NON_JSON_RESPONSE",
                "RESPONSE_TOO_LARGE", "TRANSPORT_OR_JSON_FAILURE"}
        code = str(exc)
        if code not in safe and re.fullmatch(r"HTTP_STATUS_[1-5][0-9]{2}", code) is None:
            code = "TRANSPORT_FAILURE"
        raise QuoteError(code) from None
    except Exception:
        raise QuoteError("TRANSPORT_FAILURE") from None


def quote_plan(plan: dict, transport, *, free_disk_bytes: int) -> dict:
    req = validate_plan(plan)
    free = number(free_disk_bytes, integer=True)
    receipt = {"schema": "qm.databento-quote/v1", "classification": "QUOTE_ONLY",
               "status": "BLOCKED", "purchase_authorized": False, "download_performed": False,
               "recorded_at_utc": datetime.now(timezone.utc).isoformat(),
               "request_sha256": hashlib.sha256(json_bytes(req)).hexdigest(),
               "request": req, "resolution": None, "quotes": [], "totals": None,
               "checks": {}, "blockers": [], "network_requests_attempted": 0,
               "account_credit_applied_usd": None,
               "limitations": ["Symbology is not instrument-definition verification.",
                               "Quotes do not establish market-data completeness or entitlements to execution.",
                               "Billable DBN bytes are not actual decoded/derived disk or RAM size.",
                               "Credit, tax and cash charge are not inferred from quoted usage cost.",
                               "No result of this tool authorizes purchase or download."]}

    def call(method, params):
        receipt["network_requests_attempted"] += 1
        return _call(transport, method, params)

    try:
        response = call("symbology.resolve", {"dataset": req["dataset"], "symbols": req["symbol"],
                        "stype_in": "raw_symbol", "stype_out": "instrument_id",
                        "start_date": req["start_date"], "end_date": req["end_date"]})
        receipt["resolution"] = validate_resolution(response, req)
        for schema in req["schemas"]:
            params = {"dataset": req["dataset"], "symbols": req["symbol"], "schema": schema,
                      "stype_in": "raw_symbol", "start": req["start"], "end": req["end"]}
            # Retain only a fully validated triple; incomplete quotes never sum.
            cost = number(call("metadata.get_cost", {**params, "stype_out": "instrument_id"}))
            records = number(call("metadata.get_record_count", params), integer=True)
            size = number(call("metadata.get_billable_size", {**params, "stype_out": "instrument_id"}), integer=True)
            if (records == 0) != (size == 0):
                raise QuoteError("INCONSISTENT_RECORD_AND_BYTE_COUNTS")
            receipt["quotes"].append({"schema": schema, "usage_cost_usd": str(cost),
                                      "record_count": records, "billable_uncompressed_bytes": size})
        total_cost = sum((Decimal(q["usage_cost_usd"]) for q in receipt["quotes"]), Decimal(0))
        total_bytes = sum(q["billable_uncompressed_bytes"] for q in receipt["quotes"])
        receipt["totals"] = {"usage_cost_usd": str(total_cost),
                             "record_count": sum(q["record_count"] for q in receipt["quotes"]),
                             "billable_uncompressed_bytes": total_bytes}
        checks = {"within_request_cost_cap": total_cost <= Decimal(req["quote_cap_usd"]),
                  "within_cash_budget_before_credit": total_cost <= Decimal(req["cash_cap_usd"]),
                  "billable_bytes_within_local_budget": total_bytes <= req["local_storage_budget_bytes"],
                  "factory_reserve_after_full_local_budget": free - req["local_storage_budget_bytes"] >= req["factory_reserve_bytes"],
                  "nonempty_requested_schemas": all(q["record_count"] > 0 for q in receipt["quotes"])}
        receipt["checks"] = checks
        receipt["disk"] = {"observed_free_bytes": free,
                           "reserved_local_raw_and_derived_budget_bytes": req["local_storage_budget_bytes"],
                           "required_remaining_factory_bytes": req["factory_reserve_bytes"],
                           "actual_local_size_verified": False}
        receipt["blockers"] = [name.upper() for name, passed in checks.items() if not passed]
        receipt["status"] = "WITHIN_QUOTE_LIMITS" if all(checks.values()) else "BLOCKED"
    except QuoteError as exc:
        receipt["blockers"].append(str(exc))
    return receipt


def main(argv=None) -> int:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--plan", type=Path, default=Path(__file__).with_name("data_requests.json"))
    parser.add_argument("--output", type=Path, required=True, help="New sanitized QUOTE_ONLY JSON receipt; never overwrite")
    parser.add_argument("--data-root", type=Path, default=Path("D:/QM/futures_lab"), help="Existing D: directory for the Factory disk check")
    args = parser.parse_args(argv)
    try:
        if args.output.exists() or args.output.resolve() == args.plan.resolve():
            raise QuoteError("OUTPUT_MUST_BE_NEW")
        raw = args.plan.read_bytes()
        plan = json.loads(raw)
        validate_plan(plan)  # Fail invalid scope before loading a credential.
        if not args.data_root.is_dir() or args.data_root.resolve().drive.upper() != "D:":
            raise QuoteError("EXISTING_D_DRIVE_DATA_ROOT_REQUIRED")
        free = shutil.disk_usage(args.data_root).free
        try:
            from credential_store import load_key
            key = load_key()
        except Exception:
            raise QuoteError("LOCAL_CREDENTIAL_NOT_READY") from None
        transport = MetadataTransport(key)
        del key
        receipt = quote_plan(plan, transport, free_disk_bytes=free)
        receipt["plan_file_sha256"] = hashlib.sha256(raw).hexdigest()
        args.output.parent.mkdir(parents=True, exist_ok=True)
        with args.output.open("x", encoding="utf-8") as handle:
            json.dump(receipt, handle, ensure_ascii=True, allow_nan=False, indent=2)
            handle.write("\n")
        print("QUOTE_ONLY " + receipt["status"])
        return 0 if receipt["status"] == "WITHIN_QUOTE_LIMITS" else 2
    except QuoteError as exc:
        print("QUOTE_ONLY BLOCKED " + str(exc))
        return 2
    except Exception:
        print("QUOTE_ONLY BLOCKED LOCAL_INPUT_OR_OUTPUT_ERROR")
        return 2


if __name__ == "__main__":
    raise SystemExit(main())
