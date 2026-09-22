"""Offline stub tests. No credentials, sockets, requests or real metadata API calls."""
import copy
import io
import json
import os
import sys
import tempfile
import types
import unittest
from contextlib import redirect_stdout
from decimal import Decimal
from pathlib import Path
from unittest.mock import patch

from quote_databento import (GIB, HOST, METHODS, MetadataTransport, QuoteError,
                            quote_plan, validate_plan, main)


PLAN = {"schema": "qm.futures-data-plan/v1", "historical_only": True,
        "primary_provider": "Databento", "dataset": "GLBX.MDP3", "currency": "USD",
        "first_request": {"symbol": "MESZ6", "stype_in": "raw_symbol",
                          "start": "2026-09-15T22:00:00Z", "end": "2026-09-16T21:00:00Z",
                          "schemas": ["definition", "mbp-1", "status"],
                          "max_initial_quote_usd": 25,
                          "max_total_local_raw_and_derived_bytes": 2 * GIB},
        "budget_proposal_not_an_executed_purchase": {
            "initial_data_out_of_pocket_cap_usd": 50, "minimum_factory_free_gib_on_D": 60}}


def resolution():
    return {"status": 0, "partial": [], "not_found": [], "symbols": ["MESZ6"],
            "stype_in": "raw_symbol", "stype_out": "instrument_id",
            "start_date": "2026-09-15", "end_date": "2026-09-17", "message": "OK",
            "result": {"MESZ6": [{"d0": "2026-09-15", "d1": "2026-09-17", "s": "12345"}]}}


class StubTransport:
    def __init__(self, overrides=None):
        self.overrides = overrides or {}
        self.calls = []

    def post_json(self, method, params):
        self.calls.append((method, params))
        value = self.overrides.get(method, {"symbology.resolve": resolution(),
                "metadata.get_cost": Decimal("1.25"), "metadata.get_record_count": 100,
                "metadata.get_billable_size": 10000}[method])
        if isinstance(value, Exception):
            raise value
        return value


class FakeResponse:
    status = 200
    content_type = "application/json"
    warning = None
    body = b"1.25"

    def __init__(self):
        self.read_count = 0

    def getheader(self, name, default=None):
        return {"Content-Type": self.content_type, "X-Warning": self.warning}.get(name, default)

    def read(self, size):
        self.read_count += 1
        return self.body[:size]


class FakeConnection:
    def __init__(self, response):
        self.response = response
        self.requests = []
        self.closed = False

    def request(self, method, path, **kwargs):
        self.requests.append((method, path, kwargs))

    def getresponse(self):
        return self.response

    def close(self):
        self.closed = True


class QuoteTests(unittest.TestCase):
    def run_quote(self, stub=None, plan=None, free=100 * GIB):
        return quote_plan(plan or copy.deepcopy(PLAN), stub or StubTransport(), free_disk_bytes=free)

    def test_complete_quote_stays_quote_only_and_hash_is_stable(self):
        stub = StubTransport()
        a, b = self.run_quote(stub), self.run_quote()
        self.assertEqual(a["status"], "WITHIN_QUOTE_LIMITS")
        self.assertEqual(a["totals"], {"usage_cost_usd": "3.75", "record_count": 300,
                                      "billable_uncompressed_bytes": 30000})
        self.assertFalse(a["purchase_authorized"])
        self.assertFalse(a["download_performed"])
        self.assertEqual(a["classification"], "QUOTE_ONLY")
        self.assertEqual(a["request_sha256"], b["request_sha256"])
        self.assertEqual(len(stub.calls), 10)
        self.assertTrue(all(method in METHODS for method, _ in stub.calls))
        self.assertEqual(stub.calls[0][1]["end_date"], "2026-09-17")

    def test_unknown_negative_nonfinite_and_nonnumeric_quotes_block(self):
        for value in (None, -1, float("nan"), float("inf"), Decimal("NaN"),
                      "1.25", True, {"cost": 1.25}, [1.25]):
            with self.subTest(value=repr(value)):
                result = self.run_quote(StubTransport({"metadata.get_cost": value}))
                self.assertEqual(result["status"], "BLOCKED")
                self.assertIsNone(result["totals"])

    def test_counts_and_bytes_require_nonnegative_integer_not_bool_or_float(self):
        for method in ("metadata.get_record_count", "metadata.get_billable_size"):
            for value in (-1, None, True, 1.0, "100", float("nan")):
                with self.subTest(method=method, value=repr(value)):
                    result = self.run_quote(StubTransport({method: value}))
                    self.assertEqual(result["status"], "BLOCKED")
                    self.assertIsNone(result["totals"])

    def test_valid_zero_cost_not_rejected_but_empty_data_is_flagged(self):
        self.assertEqual(self.run_quote(StubTransport({"metadata.get_cost": 0}))["status"], "WITHIN_QUOTE_LIMITS")
        result = self.run_quote(StubTransport({"metadata.get_record_count": 0, "metadata.get_billable_size": 0}))
        self.assertIn("NONEMPTY_REQUESTED_SCHEMAS", result["blockers"])

    def test_partial_unresolved_and_malformed_symbols_stop_before_quotes(self):
        mutations = [{"partial": ["MESZ6"]}, {"not_found": ["MESZ6"]}, {"status": 1},
                     {"status": True}, {"result": {}}, {"symbols": ["MESZ6", "MNQZ6"]},
                     {"end_date": "2026-09-16"}]
        for change in mutations:
            with self.subTest(change=change):
                mapping = resolution()
                mapping.update(change)
                stub = StubTransport({"symbology.resolve": mapping})
                result = self.run_quote(stub)
                self.assertEqual(result["status"], "BLOCKED")
                self.assertEqual(len(stub.calls), 1)
                self.assertEqual(result["quotes"], [])

    def test_resolution_date_gaps_or_id_switch_block(self):
        variants = [[{"d0": "2026-09-16", "d1": "2026-09-17", "s": "12345"}],
                    [{"d0": "2026-09-15", "d1": "2026-09-16", "s": "12345"}],
                    [{"d0": "2026-09-15", "d1": "2026-09-16", "s": "12345"},
                     {"d0": "2026-09-16", "d1": "2026-09-17", "s": "67890"}]]
        for rows in variants:
            mapping = resolution()
            mapping["result"]["MESZ6"] = rows
            self.assertEqual(self.run_quote(StubTransport({"symbology.resolve": mapping}))["status"], "BLOCKED")

    def test_contiguous_same_id_and_midnight_exclusive_dates(self):
        mapping = resolution()
        mapping["result"]["MESZ6"] = [{"d0": "2026-09-15", "d1": "2026-09-16", "s": "12345"},
                                      {"d0": "2026-09-16", "d1": "2026-09-17", "s": "12345"}]
        self.assertEqual(self.run_quote(StubTransport({"symbology.resolve": mapping}))["status"], "WITHIN_QUOTE_LIMITS")
        plan = copy.deepcopy(PLAN)
        plan["first_request"]["end"] = "2026-09-17T00:00:00Z"
        self.assertEqual(validate_plan(plan)["end_date"], "2026-09-17")

    def test_request_cash_bytes_and_disk_reserve_caps(self):
        cases = [(StubTransport({"metadata.get_cost": Decimal("9")}), PLAN, 100 * GIB, "WITHIN_REQUEST_COST_CAP"),
                 (StubTransport({"metadata.get_billable_size": GIB}), PLAN, 100 * GIB, "BILLABLE_BYTES_WITHIN_LOCAL_BUDGET"),
                 (StubTransport(), PLAN, 61 * GIB, "FACTORY_RESERVE_AFTER_FULL_LOCAL_BUDGET")]
        low_cash = copy.deepcopy(PLAN)
        low_cash["budget_proposal_not_an_executed_purchase"]["initial_data_out_of_pocket_cap_usd"] = 2
        cases.append((StubTransport(), low_cash, 100 * GIB, "WITHIN_CASH_BUDGET_BEFORE_CREDIT"))
        for stub, plan, free, blocker in cases:
            with self.subTest(blocker=blocker):
                result = self.run_quote(stub, plan, free)
                self.assertIn(blocker, result["blockers"])
                self.assertEqual(result["status"], "BLOCKED")

    def test_invalid_scope_is_rejected_without_any_transport_calls(self):
        for field, value in (("symbol", "ALL_SYMBOLS"), ("symbol", "MESZ6,MNQZ6"),
                             ("stype_in", "parent"), ("schemas", ["mbp-1", "mbp-1"]),
                             ("schemas", ["mbo"]), ("start", "2026-09-15")):
            plan = copy.deepcopy(PLAN)
            plan["first_request"][field] = value
            stub = StubTransport()
            with self.subTest(field=field, value=value), self.assertRaises(QuoteError):
                self.run_quote(stub, plan)
            self.assertEqual(stub.calls, [])

    def test_transport_failures_are_sanitized_and_never_totalled(self):
        marker = "DO_NOT_LEAK_SECRET_OR_SERVER_BODY"
        for failure in (RuntimeError(marker), QuoteError(marker)):
            result = self.run_quote(StubTransport({"metadata.get_record_count": failure}))
            self.assertNotIn(marker, json.dumps(result))
            self.assertIsNone(result["totals"])
            self.assertEqual(result["status"], "BLOCKED")


class TransportTests(unittest.TestCase):
    def client(self, response):
        connection = FakeConnection(response)
        destinations = []
        def factory(host, **kwargs):
            destinations.append(host)
            return connection
        return MetadataTransport("db-" + "x" * 29, connection_factory=factory), connection, destinations

    def test_fixed_host_post_form_and_basic_auth_never_in_url(self):
        client, connection, destinations = self.client(FakeResponse())
        self.assertEqual(client.post_json("metadata.get_cost", {"symbols": "MESZ6"}), Decimal("1.25"))
        self.assertEqual(destinations, [HOST])
        method, path, params = connection.requests[0]
        self.assertEqual(method, "POST")
        self.assertEqual(path, "/v0/metadata.get_cost")
        self.assertEqual(params["body"], b"symbols=MESZ6")
        self.assertTrue(connection.closed)

    def test_redirect_and_partial_http_never_follow_or_read_body(self):
        for status in (301, 302, 303, 307, 308, 206, 401, 402, 429, 500):
            response = FakeResponse()
            response.status = status
            response.body = b"SECRET_ECHO_FROM_SERVER"
            client, connection, destinations = self.client(response)
            with self.subTest(status=status), self.assertRaises(QuoteError) as caught:
                client.post_json("metadata.get_cost", {})
            self.assertNotIn("SECRET", str(caught.exception))
            self.assertEqual(len(connection.requests), 1)
            self.assertEqual(destinations, [HOST])
            self.assertEqual(response.read_count, 0)
            self.assertTrue(connection.closed)

    def test_disallowed_endpoints_do_not_open_connection(self):
        for endpoint in ("timeseries.get_range", "batch.submit_job", "live", "https://evil.invalid/"):
            client, connection, destinations = self.client(FakeResponse())
            with self.assertRaises(QuoteError):
                client.post_json(endpoint, {})
            self.assertEqual(destinations, [])
            self.assertEqual(connection.requests, [])

    def test_warning_wrong_type_bad_json_never_expose_response(self):
        for changes in ({"warning": "PRIVATE_SERVER_MESSAGE"}, {"content_type": "text/html"},
                        {"body": b"PRIVATE_BAD_JSON"}):
            response = FakeResponse()
            for name, value in changes.items():
                setattr(response, name, value)
            client, _, _ = self.client(response)
            with self.assertRaises(QuoteError) as caught:
                client.post_json("metadata.get_cost", {})
            self.assertNotIn("PRIVATE", str(caught.exception))


@unittest.skipUnless(os.name == "nt" and Path("D:/QM/futures_lab").is_dir(), "CLI uses the existing Windows D: workspace")
class CLITests(unittest.TestCase):
    def test_missing_credential_is_sanitized_before_transport_creation(self):
        secret_marker = "DO_NOT_PRINT_CREDENTIAL_ERROR_DETAILS"
        def missing():
            raise RuntimeError(secret_marker)
        with tempfile.TemporaryDirectory(dir="D:/QM/futures_lab", prefix="quote-test-") as directory:
            root = Path(directory)
            plan = root / "plan.json"
            plan.write_text(json.dumps(PLAN), encoding="utf-8")
            output = root / "quote.json"
            stdout = io.StringIO()
            with patch.dict(sys.modules, {"credential_store": types.SimpleNamespace(load_key=missing)}), \
                    patch("quote_databento.MetadataTransport") as transport, redirect_stdout(stdout):
                status = main(["--plan", str(plan), "--output", str(output)])
            self.assertEqual(status, 2)
            self.assertFalse(output.exists())
            transport.assert_not_called()
            self.assertNotIn(secret_marker, stdout.getvalue())
            self.assertIn("LOCAL_CREDENTIAL_NOT_READY", stdout.getvalue())

    def test_cli_persists_sanitized_quote_and_refuses_overwrite(self):
        fake_key = "db-" + "x" * 29
        with tempfile.TemporaryDirectory(dir="D:/QM/futures_lab", prefix="quote-test-") as directory:
            root = Path(directory)
            plan = root / "plan.json"
            plan.write_text(json.dumps(PLAN), encoding="utf-8")
            output = root / "quote.json"
            stdout = io.StringIO()
            with patch.dict(sys.modules, {"credential_store": types.SimpleNamespace(load_key=lambda: fake_key)}), \
                    patch("quote_databento.MetadataTransport", return_value=StubTransport()) as transport, \
                    patch("quote_databento.shutil.disk_usage", return_value=types.SimpleNamespace(free=100 * GIB)), \
                    redirect_stdout(stdout):
                status = main(["--plan", str(plan), "--output", str(output)])
                again = main(["--plan", str(plan), "--output", str(output)])
            self.assertEqual((status, again), (0, 2))
            transport.assert_called_once_with(fake_key)
            text = output.read_text(encoding="utf-8")
            self.assertNotIn(fake_key, text + stdout.getvalue())
            receipt = json.loads(text)
            self.assertEqual(receipt["classification"], "QUOTE_ONLY")
            self.assertEqual(len(receipt["plan_file_sha256"]), 64)
            self.assertFalse(receipt["purchase_authorized"])


if __name__ == "__main__":
    unittest.main()
