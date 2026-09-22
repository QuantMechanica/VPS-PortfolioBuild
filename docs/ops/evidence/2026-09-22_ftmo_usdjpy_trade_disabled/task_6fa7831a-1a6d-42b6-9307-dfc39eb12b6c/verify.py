#!/usr/bin/env python3
"""Deterministically verify the task-scoped FTMO trade-disabled evidence."""

from __future__ import annotations

import argparse
import ast
import hashlib
import json
from pathlib import Path
from typing import Any


HERE = Path(__file__).resolve().parent
REPO = Path(__file__).resolve().parents[5]
TASK_ID = "6fa7831a-1a6d-42b6-9307-dfc39eb12b6c"

BOUND_SOURCES = {
    "docs/ops/evidence/ftmo_fetch_20260918/cand_symbols.html":
        "103d7486d307d28588e4bae7849d062d944834e557fd01b8ddf6ae1cf756d684",
    "docs/ops/evidence/2026-09-06_ftmo_demo_account_terms.md":
        "6d6c7bdd43b690db44d1fac8e64fcb515c2db0d79ae6f12de00e7f5bbcb2e753",
    "docs/ftmo/genesis/SUNDAY_LAUNCH_RUNBOOK_2026-09-27.md":
        "a20b8080a15e6c0801ef49956b33091e870a3ce79258870babfd0eea54ce1295",
    "framework/EAs/QM5_13213_balke-gmt3-range-breakout/SPEC.md":
        "dfe0730c8f3f43844b400a011faa6489479eecb11d133a515c3a548ed3ebc436",
    "framework/EAs/QM5_13213_balke-gmt3-range-breakout/"
    "QM5_13213_balke-gmt3-range-breakout.mq5":
        "ea3920720c4f71ebe2ed4266075e51bc0fad67b261ebf15ef6335a9c68584448",
}


def sha256(path: Path) -> str:
    return hashlib.sha256(path.read_bytes()).hexdigest()


def load_json(path: Path) -> dict[str, Any]:
    value = json.loads(path.read_text(encoding="utf-8"))
    if not isinstance(value, dict):
        raise AssertionError(f"expected object: {path}")
    return value


def call_names(path: Path) -> set[str]:
    tree = ast.parse(path.read_text(encoding="utf-8"), filename=str(path))
    result: set[str] = set()
    for node in ast.walk(tree):
        if not isinstance(node, ast.Call):
            continue
        if isinstance(node.func, ast.Attribute):
            result.add(node.func.attr)
        elif isinstance(node.func, ast.Name):
            result.add(node.func.id)
    return result


def main() -> int:
    parser = argparse.ArgumentParser()
    parser.add_argument("--output", type=Path)
    args = parser.parse_args()

    capture = load_json(HERE / "capture.json")
    source_route = load_json(HERE / "source_intake_router.json")
    snapshot = capture["terminal_snapshot"]
    account = snapshot["account"]
    terminal = snapshot["terminal"]
    symbols = snapshot["symbols"]
    history = snapshot["account_close_history"]
    logs = capture["logs"]
    pulse = capture["pulse"]
    readme = (HERE / "README.md").read_text(encoding="utf-8")

    checks: list[dict[str, Any]] = []

    def check(name: str, condition: bool, detail: Any) -> None:
        checks.append({"name": name, "pass": bool(condition), "detail": detail})

    check("task_binding", capture["task_id"] == TASK_ID, capture["task_id"])
    check(
        "collector_authorization_all_false",
        capture["authorization"] and not any(capture["authorization"].values()),
        capture["authorization"],
    )
    check(
        "terminal_connected_and_trade_capable",
        terminal["connected"] is True
        and terminal["terminal_trade_allowed"] is True
        and terminal["tradeapi_disabled"] is False,
        terminal,
    )
    check(
        "account_level_trade_disabled",
        account["account_trade_allowed"] is False
        and account["account_trade_expert"] is True,
        {
            "account_trade_allowed": account["account_trade_allowed"],
            "account_trade_expert": account["account_trade_expert"],
        },
    )

    expected_mapping = {
        "USDJPY": "USDJPY",
        "XAUUSD": "XAUUSD",
        "USDCAD": "USDCAD",
        "XTIUSD": "USOIL.cash",
        "GBPUSD": "GBPUSD",
        "EURUSD": "EURUSD",
    }
    actual_mapping = {item["logical_symbol"]: item["broker_symbol"] for item in symbols}
    check("all_requested_symbols_present", actual_mapping == expected_mapping, actual_mapping)
    modes = {
        item["logical_symbol"]: {
            "mode": item["symbol_trade_mode_label"],
            "start": item["symbol_start_time"],
            "expiration": item["symbol_expiration_time"],
        }
        for item in symbols
    }
    check(
        "all_symbols_full_with_zero_lifecycle_bounds",
        len(modes) == 6
        and all(
            item["mode"] == "SYMBOL_TRADE_MODE_FULL"
            and item["start"] == 0
            and item["expiration"] == 0
            for item in modes.values()
        ),
        modes,
    )

    prior = "\n".join(item["text"] for item in logs["ea_13213_prior_day_same_anchor_success"])
    incident = "\n".join(item["text"] for item in logs["ea_13213_incident"])
    check(
        "same_anchor_prior_success",
        prior.count('"event":"ENTRY_ACCEPTED"') == 2
        and prior.count('"retcode":10009') == 2
        and '"ts_broker":"2026-09-21T06:00:00"' in prior,
        "two USDJPY entries accepted at 06:00 broker on the preceding day",
    )
    check(
        "incident_two_10017_rejects",
        incident.count('"event":"BROKER_TRADE_DISABLED"') == 2
        and incident.count('"retcode":10017') == 2
        and '"ts_broker":"2026-09-22T06:00:00"' in incident,
        "two USDJPY entries rejected at 06:00 broker",
    )

    canceled_xau = {
        item["ticket"]: item["time_done"]["inferred_utc"]
        for item in history["orders"]
        if item["symbol"] == "XAUUSD" and item["state_label"] == "ORDER_STATE_CANCELED"
    }
    forced_orders = [item for item in history["orders"] if item["comment"] == "CLOSED_BY_FTMO"]
    forced_deals = [item for item in history["deals"] if item["comment"] == "CLOSED_BY_FTMO"]
    check(
        "xau_cross_symbol_cancellations",
        canceled_xau == {
            546985040: "2026-09-21T23:02:05Z",
            546985290: "2026-09-21T23:02:05Z",
        },
        canceled_xau,
    )
    check(
        "ftmo_forced_usdcad_close",
        len(forced_orders) == 1
        and len(forced_deals) == 1
        and forced_orders[0]["ticket"] == 547007430
        and forced_deals[0]["ticket"] == 524247545
        and forced_orders[0]["magic"] == 0
        and forced_deals[0]["magic"] == 0
        and forced_deals[0]["time"]["inferred_utc"] == "2026-09-21T23:02:06Z",
        {"orders": forced_orders, "deals": forced_deals},
    )

    clock = logs["clock_binding"]
    check(
        "clock_binding_utc_plus_3",
        clock["broker_utc_offset_seconds"] == 10800
        and clock["ea_ts_utc"].startswith("2026-09-22T03:00:00")
        and clock["ea_ts_broker"] == "2026-09-22T06:00:00",
        clock,
    )
    check(
        "pulse_alarm_matches_incident",
        pulse["verdict"] == "ALARM"
        and pulse["terminal_up"] is True
        and pulse["open_positions"] == 0
        and pulse["pending_orders"] == 0
        and any("BROKER_TRADE_DISABLED" in item for item in pulse["alarms"]),
        pulse,
    )
    check(
        "source_router_policy_enforced",
        source_route["status"] == "PERMISSION_REQUIRED"
        and source_route["adapter_state"] == "ROUTER_ONLY"
        and source_route["lead_status"] == "DEFERRED:SOURCE_POLICY",
        source_route,
    )

    calls = call_names(HERE / "collect_read_only.py")
    prohibited_calls = sorted({"order_send", "order_check", "symbol_select"} & calls)
    expected_read_calls = {
        "initialize",
        "terminal_info",
        "account_info",
        "symbol_info",
        "positions_get",
        "orders_get",
        "history_orders_get",
        "history_deals_get",
        "shutdown",
    }
    check(
        "collector_call_surface_read_only",
        not prohibited_calls and expected_read_calls <= calls,
        {"prohibited_calls": prohibited_calls, "mt5_read_calls": sorted(expected_read_calls & calls)},
    )
    check(
        "already_running_process_guard_observed",
        snapshot["process"]["already_running_before_initialize"] is True
        and snapshot["process"]["same_pid_after_capture"] is True,
        snapshot["process"],
    )

    bound_hashes = {relative: sha256(REPO / relative) for relative in BOUND_SOURCES}
    check("bound_source_hashes", bound_hashes == BOUND_SOURCES, bound_hashes)
    check(
        "report_declares_classification_and_no_card_change",
        "**`ACCOUNT_WIDE` — decisive.**" in readme
        and "does **not** authorize an EA/card change" in readme
        and "fresh-account path" in readme,
        "README contains verdict, scope boundary, and Sunday consequence",
    )

    passed = all(item["pass"] for item in checks)
    result = {
        "schema": "qm.ftmo-trade-disabled-verification/v1",
        "task_id": TASK_ID,
        "verdict": "PASS" if passed else "FAIL",
        "classification": "ACCOUNT_WIDE" if passed else "UNVERIFIED",
        "checks_passed": sum(1 for item in checks if item["pass"]),
        "checks_total": len(checks),
        "artifact_sha256": {
            "README.md": sha256(HERE / "README.md"),
            "capture.json": sha256(HERE / "capture.json"),
            "collect_read_only.py": sha256(HERE / "collect_read_only.py"),
            "source_intake_router.json": sha256(HERE / "source_intake_router.json"),
            "verify.py": sha256(HERE / "verify.py"),
        },
        "checks": checks,
    }

    rendered = json.dumps(result, indent=2, sort_keys=True) + "\n"
    if args.output:
        args.output.write_text(rendered, encoding="utf-8", newline="\n")
    print(rendered, end="")
    return 0 if passed else 1


if __name__ == "__main__":
    raise SystemExit(main())
