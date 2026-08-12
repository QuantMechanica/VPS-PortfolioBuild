import json
import re

import pytest

from tools.strategy_farm.compare_joint_replay import classify, load_closed, main
from tools.strategy_farm.compare_joint_replay import (
    FULL_LIFECYCLE_MONEY_BASIS,
    GOVERNED_MONEY_TOLERANCE,
    GOVERNED_PRICE_TOLERANCE,
    GOVERNED_VOLUME_TOLERANCE,
    JOINT_PRODUCER_VERSION,
    validate_full_lifecycle_rows,
)


EXPECTED_RUN_ID = "FTMO_BOOK3_20260729_V2_J0"
RUN_ID_ARGS = ["--expected-joint-run-id", EXPECTED_RUN_ID]


def trade(entry, close, volume=1.0, net=10.0):
    return {
        "entry_time": entry,
        "time": close,
        "side": "BUY",
        "entry_price": 100.125,
        "exit_price": 101.375,
        "volume": volume,
        "profit": net + 2.0,
        "swap": 0.0,
        "fee": 0.0,
        "entry_commission": -1.0,
        "exit_commission": -1.0,
        "commission": -2.0,
        "net": net,
    }


def standalone_trade(*, magic=1, net=10.0, overrides=None):
    row = {
        "event": "TRADE_CLOSED",
        "money_basis": FULL_LIFECYCLE_MONEY_BASIS,
        "magic": magic,
        "symbol": "USDJPY.DWX",
        "side": "BUY",
        "entry_price": 100.125,
        "exit_price": 101.375,
        "entry_time": 100,
        "time": 200,
        "profit": net + 2.0,
        "swap": 0.0,
        "fee": 0.0,
        "entry_commission": -1.0,
        "exit_commission": -1.0,
        "commission": -2.0,
        "net": net,
        "mae_acct": -5.0,
        "volume": 0.1,
        "notional": 10_000.0,
    }
    if overrides:
        row.update(overrides)
    return row


def joint_trade(*, magic=201810000, net=10.0, overrides=None):
    row = {
        "event": "TRADE_CLOSED",
        "schema_version": 2,
        "run_id": EXPECTED_RUN_ID,
        "producer_version": JOINT_PRODUCER_VERSION,
        "position_fully_closed": True,
        "position_id": 123_456,
        "entry_deal_ids": [7001],
        "exit_deal_ids": [7002],
        "magic": magic,
        "symbol": "USDJPY.DWX",
        "side": "BUY",
        "entry_price": 100.125,
        "exit_price": 101.375,
        "entry_time": 100,
        "time": 200,
        "profit": net + 2.0,
        "swap": 0.0,
        "entry_commission": -1.0,
        "exit_commission": -1.0,
        "commission": -2.0,
        "fee": 0.0,
        "net": net,
        "balance_events": [
            {"deal_id": 7001, "time": 100, "component": "COMMISSION", "amount": -1.0},
            {"deal_id": 7002, "time": 200, "component": "PROFIT", "amount": net + 2.0},
            {"deal_id": 7002, "time": 200, "component": "SWAP", "amount": 0.0},
            {"deal_id": 7002, "time": 200, "component": "COMMISSION", "amount": -1.0},
            {"deal_id": 7002, "time": 200, "component": "FEE", "amount": 0.0},
        ],
        "mae_acct": -5.0,
        "volume": 0.1,
        "notional": 10_000.0,
    }
    if overrides:
        row.update(overrides)
    return row


def write_stream(path, row):
    path.write_text(json.dumps(row) + "\n", encoding="utf-8")


def captured_json(capsys):
    output = capsys.readouterr().out
    return json.JSONDecoder().raw_decode(output)[0]


def test_mismatch_categories_are_exhaustive():
    gated = [trade(1, 2), trade(3, 4), trade(5, 6), trade(7, 8)]
    joint = [trade(1, 2), trade(3, 40), trade(50, 60), trade(70, 80)]
    assert classify(joint, gated, .005, .005) == {
        "exact": 1,
        "same_entry_same_volume_shifted_exit": 1,
        "different_entry": 2,
        "extra": 0,
        "missing": 0,
    }


def test_extra_and_missing():
    assert classify([trade(1, 2)], [], .005, .005)["extra"] == 1
    assert classify([], [trade(1, 2)], .005, .005)["missing"] == 1


def test_load_closed_filters_one_sleeve_by_magic_and_symbol(tmp_path):
    stream = tmp_path / "joint.jsonl"
    stream.write_text(
        "\n".join(
            [
                json.dumps({
                    "event": "TRADE_CLOSED",
                    "magic": 201810000,
                    "symbol": "USDJPY.DWX",
                    "entry_time": 1,
                    "time": 2,
                }),
                json.dumps({
                    "event": "TRADE_CLOSED",
                    "magic": 201810001,
                    "symbol": "XAUUSD.DWX",
                    "entry_time": 3,
                    "time": 4,
                }),
                json.dumps({
                    "event": "TRADE_CLOSED",
                    "magic": 201810002,
                    "symbol": "XTIUSD.DWX",
                    "entry_time": 5,
                    "time": 6,
                }),
            ]
        )
        + "\n",
        encoding="utf-8",
    )

    assert [row["magic"] for row in load_closed(stream, magic=201810001)] == [
        201810001
    ]
    assert [row["magic"] for row in load_closed(stream, symbol="xtiusd.dwx")] == [
        201810002
    ]
    assert load_closed(stream, magic=201810001, symbol="USDJPY.DWX") == []


def test_v2_fixtures_carry_marker_schema_producer_run_and_lineage():
    standalone = standalone_trade()
    joint = joint_trade()

    assert standalone["money_basis"] == FULL_LIFECYCLE_MONEY_BASIS
    assert joint["schema_version"] == 2
    assert joint["producer_version"] == JOINT_PRODUCER_VERSION
    assert joint["run_id"] == EXPECTED_RUN_ID
    assert joint["position_id"] > 0
    assert joint["entry_deal_ids"] and joint["exit_deal_ids"]
    assert joint["balance_events"]
    assert validate_full_lifecycle_rows(
        [standalone], role="standalone", money_tol=0.005
    )[0]["money_basis"] == FULL_LIFECYCLE_MONEY_BASIS
    assert validate_full_lifecycle_rows(
        [joint], role="joint", money_tol=0.005, expected_run_id=EXPECTED_RUN_ID
    )[0]["schema_version"] == 2


def test_main_rejects_empty_filtered_operands(tmp_path, capsys):
    stream = tmp_path / "one.jsonl"
    write_stream(stream, standalone_trade())

    exit_code = main(
        [
            "--joint",
            str(stream),
            "--joint-magic",
            "999",
            "--gated",
            str(stream),
            "--gated-magic",
            "999",
            *RUN_ID_ARGS,
        ]
    )

    result = captured_json(capsys)
    assert exit_code == 2
    assert result["valid"] is False
    assert result["reason"] == "empty_filtered_operand"
    assert result["joint_trades"] == 0
    assert result["gated_trades"] == 0
    assert result["match_rate"] is None

    exit_code = main(
        [
            "--joint",
            str(stream),
            "--joint-magic",
            "999",
            "--gated",
            str(stream),
            "--gated-magic",
            "1",
            *RUN_ID_ARGS,
        ]
    )
    one_empty = captured_json(capsys)
    assert exit_code == 2
    assert one_empty["joint_trades"] == 0
    assert one_empty["gated_trades"] == 1
    assert one_empty["match_rate"] is None


def test_main_accepts_v2_singletons_without_magic_filters(tmp_path, capsys):
    standalone = tmp_path / "standalone.jsonl"
    joint = tmp_path / "joint.jsonl"
    write_stream(standalone, standalone_trade())
    write_stream(joint, joint_trade())

    exit_code = main(["--joint", str(joint), "--gated", str(standalone), *RUN_ID_ARGS])

    result = captured_json(capsys)
    assert exit_code == 0
    assert result["valid"] is True
    assert result["match_rate"] == 1.0
    assert result["money_basis"] == FULL_LIFECYCLE_MONEY_BASIS
    assert result["filters"]["expected_joint_run_id"] == EXPECTED_RUN_ID
    assert result["filters"]["joint_magic"] is None
    assert result["filters"]["gated_magic"] is None
    assert result["filters"]["money_tolerance"] == GOVERNED_MONEY_TOLERANCE
    assert result["filters"]["volume_tolerance"] == GOVERNED_VOLUME_TOLERANCE
    assert result["filters"]["price_tolerance"] == GOVERNED_PRICE_TOLERANCE


def test_main_rejects_missing_standalone_money_marker(tmp_path, capsys):
    standalone = tmp_path / "standalone.jsonl"
    joint = tmp_path / "joint.jsonl"
    row = standalone_trade()
    row.pop("money_basis")
    write_stream(standalone, row)
    write_stream(joint, joint_trade())

    exit_code = main(["--joint", str(joint), "--gated", str(standalone), *RUN_ID_ARGS])

    result = captured_json(capsys)
    assert exit_code == 2
    assert result["valid"] is False
    assert result["reason"] == "full_lifecycle_money_contract_invalid"
    assert "standalone trade 1 money_basis mismatch" in result["detail"]
    assert result["money_basis"] == FULL_LIFECYCLE_MONEY_BASIS


@pytest.mark.parametrize("role", ["standalone", "joint"])
def test_main_rejects_missing_fee(tmp_path, capsys, role):
    standalone = tmp_path / "standalone.jsonl"
    joint = tmp_path / "joint.jsonl"
    standalone_row = standalone_trade()
    joint_row = joint_trade()
    (standalone_row if role == "standalone" else joint_row).pop("fee")
    write_stream(standalone, standalone_row)
    write_stream(joint, joint_row)

    exit_code = main(["--joint", str(joint), "--gated", str(standalone), *RUN_ID_ARGS])

    result = captured_json(capsys)
    assert exit_code == 2
    assert result["reason"] == "full_lifecycle_money_contract_invalid"
    assert f"{role} trade 1 fee is missing" in result["detail"]


@pytest.mark.parametrize(
    ("overrides", "message"),
    [
        ({"commission": -3.0}, "commission components do not reconcile"),
        ({"net": 9.0}, "full-lifecycle net does not reconcile"),
    ],
)
def test_main_rejects_inconsistent_money_components(
    tmp_path, capsys, overrides, message
):
    standalone = tmp_path / "standalone.jsonl"
    joint = tmp_path / "joint.jsonl"
    write_stream(standalone, standalone_trade(overrides=overrides))
    write_stream(joint, joint_trade())

    exit_code = main(["--joint", str(joint), "--gated", str(standalone), *RUN_ID_ARGS])

    result = captured_json(capsys)
    assert exit_code == 2
    assert result["reason"] == "full_lifecycle_money_contract_invalid"
    assert message in result["detail"]


def test_main_rejects_consistent_but_different_money_components(tmp_path, capsys):
    standalone = tmp_path / "standalone.jsonl"
    joint = tmp_path / "joint.jsonl"
    write_stream(standalone, standalone_trade())
    write_stream(
        joint,
        joint_trade(
            overrides={
                "entry_commission": -1.006,
                "exit_commission": -0.994,
                "balance_events": [
                    {"deal_id": 7001, "time": 100, "component": "COMMISSION", "amount": -1.006},
                    {"deal_id": 7002, "time": 200, "component": "PROFIT", "amount": 12.0},
                    {"deal_id": 7002, "time": 200, "component": "SWAP", "amount": 0.0},
                    {"deal_id": 7002, "time": 200, "component": "COMMISSION", "amount": -0.994},
                    {"deal_id": 7002, "time": 200, "component": "FEE", "amount": 0.0},
                ],
            }
        ),
    )

    exit_code = main(["--joint", str(joint), "--gated", str(standalone), *RUN_ID_ARGS])

    result = captured_json(capsys)
    assert exit_code == 2
    assert result["money_basis"] == FULL_LIFECYCLE_MONEY_BASIS
    assert result["match_rate"] == 0.0


@pytest.mark.parametrize(
    "args",
    [
        ["--joint-magic", "not-an-int"],
        ["--joint-magic", "0"],
        ["--joint-magic", "-1"],
        ["--joint-magic"],
        ["--gated-magic", "not-an-int"],
        ["--gated-magic"],
    ],
)
def test_main_rejects_invalid_or_missing_magic_values(tmp_path, args):
    stream = tmp_path / "singleton.jsonl"
    stream.write_text("{}\n", encoding="utf-8")

    with pytest.raises(SystemExit) as exc:
        main(["--joint", str(stream), "--gated", str(stream), *RUN_ID_ARGS, *args])

    assert exc.value.code == 2


@pytest.mark.parametrize(
    ("flag", "value"),
    [
        ("--money-tol", "nan"),
        ("--money-tol", "inf"),
        ("--money-tol", "-0.001"),
        ("--money-tol", "0.006"),
        ("--vol-tol", "nan"),
        ("--vol-tol", "inf"),
        ("--vol-tol", "-0.001"),
        ("--vol-tol", "0.006"),
    ],
)
def test_main_rejects_non_finite_negative_or_relaxed_tolerances(
    tmp_path, flag, value
):
    stream = tmp_path / "singleton.jsonl"
    stream.write_text("{}\n", encoding="utf-8")

    with pytest.raises(SystemExit) as exc:
        main(
            [
                "--joint",
                str(stream),
                "--gated",
                str(stream),
                *RUN_ID_ARGS,
                flag,
                value,
            ]
        )

    assert exc.value.code == 2


def test_main_accepts_stricter_zero_tolerances(tmp_path, capsys):
    standalone = tmp_path / "standalone.jsonl"
    joint = tmp_path / "joint.jsonl"
    write_stream(standalone, standalone_trade())
    write_stream(joint, joint_trade())

    exit_code = main(
        [
            "--joint",
            str(joint),
            "--gated",
            str(standalone),
            *RUN_ID_ARGS,
            "--money-tol",
            "0",
            "--vol-tol",
            "0",
        ]
    )

    assert exit_code == 0
    assert captured_json(capsys)["match_rate"] == 1.0


@pytest.mark.parametrize(
    ("overrides", "message"),
    [
        ({"run_id": "FTMO_BOOK3_20260729_V2_J1"}, "run_id mismatch"),
        ({"position_id": 0}, "position_id must be a positive integer"),
        ({"position_id": True}, "position_id must be a positive integer"),
        ({"entry_deal_ids": "7001"}, "entry_deal_ids must be a non-empty array"),
        ({"entry_deal_ids": [0]}, "entry_deal_ids[0] must be a positive integer"),
        ({"entry_deal_ids": [7001, 7001]}, "contains duplicate deal IDs"),
        ({"exit_deal_ids": [7001]}, "entry/exit deal IDs overlap"),
        ({"balance_events": "event"}, "balance_events must be a non-empty array"),
        (
            {"balance_events": [{"deal_id": 9999, "time": 100, "component": "COMMISSION", "amount": -1.0}]},
            "outside declared lineage",
        ),
        (
            {"balance_events": [{"deal_id": 7001, "time": 100, "component": "COMMISSION", "amount": -1.0, "extra": True}]},
            "fields mismatch",
        ),
        (
            {
                "balance_events": [
                    {
                        "deal_id": 7001,
                        "time": 100,
                        "component": "COMMISSION",
                        "amount": "-1.0",
                    }
                ]
            },
            "amount must be a JSON number",
        ),
        (
            {
                "balance_events": [
                    {"deal_id": 7001, "time": 100, "component": "COMMISSION", "amount": -0.99},
                    {"deal_id": 7002, "time": 200, "component": "PROFIT", "amount": 12.0},
                    {"deal_id": 7002, "time": 200, "component": "SWAP", "amount": 0.0},
                    {"deal_id": 7002, "time": 200, "component": "COMMISSION", "amount": -1.0},
                    {"deal_id": 7002, "time": 200, "component": "FEE", "amount": 0.0},
                ]
            },
            "does not reconcile",
        ),
    ],
)
def test_joint_v2_requires_expected_run_and_typed_positive_lineage(
    overrides, message
):
    with pytest.raises(ValueError, match=re.escape(message)):
        validate_full_lifecycle_rows(
            [joint_trade(overrides=overrides)],
            role="joint",
            money_tol=GOVERNED_MONEY_TOLERANCE,
            expected_run_id=EXPECTED_RUN_ID,
        )


def test_joint_validator_accepts_ordered_partial_exit_lineage():
    events = [
        {"deal_id": 7001, "time": 100, "component": "COMMISSION", "amount": -1.0},
        {"deal_id": 7002, "time": 150, "component": "PROFIT", "amount": 5.0},
        {"deal_id": 7002, "time": 150, "component": "SWAP", "amount": 0.0},
        {"deal_id": 7002, "time": 150, "component": "COMMISSION", "amount": -0.4},
        {"deal_id": 7002, "time": 150, "component": "FEE", "amount": 0.0},
        {"deal_id": 7003, "time": 200, "component": "PROFIT", "amount": 7.0},
        {"deal_id": 7003, "time": 200, "component": "SWAP", "amount": 0.0},
        {"deal_id": 7003, "time": 200, "component": "COMMISSION", "amount": -0.6},
        {"deal_id": 7003, "time": 200, "component": "FEE", "amount": 0.0},
    ]

    validated = validate_full_lifecycle_rows(
        [joint_trade(overrides={"exit_deal_ids": [7002, 7003], "balance_events": events})],
        role="joint",
        money_tol=GOVERNED_MONEY_TOLERANCE,
        expected_run_id=EXPECTED_RUN_ID,
    )

    assert validated[0]["exit_deal_ids"] == [7002, 7003]


@pytest.mark.parametrize("tolerance", [float("nan"), float("inf"), -0.001, 0.006])
def test_direct_validator_rejects_ungoverned_money_tolerance(tolerance):
    with pytest.raises(ValueError):
        validate_full_lifecycle_rows(
            [joint_trade()],
            role="joint",
            money_tol=tolerance,
            expected_run_id=EXPECTED_RUN_ID,
        )


def test_governed_tolerance_constants_remain_frozen():
    assert GOVERNED_MONEY_TOLERANCE == 0.005
    assert GOVERNED_VOLUME_TOLERANCE == 0.005
    assert GOVERNED_PRICE_TOLERANCE == 0.0


@pytest.mark.parametrize(
    "overrides",
    [
        {"side": "SELL"},
        {"entry_price": 100.1250000001},
        {"exit_price": 101.3750000001},
    ],
)
def test_main_fails_on_side_or_price_drift(tmp_path, capsys, overrides):
    standalone = tmp_path / "standalone.jsonl"
    joint = tmp_path / "joint.jsonl"
    write_stream(standalone, standalone_trade())
    write_stream(joint, joint_trade(overrides=overrides))

    exit_code = main(["--joint", str(joint), "--gated", str(standalone), *RUN_ID_ARGS])

    result = captured_json(capsys)
    assert exit_code == 2
    assert result["match_rate"] == 0.0
    assert result["filters"]["price_tolerance"] == 0.0
