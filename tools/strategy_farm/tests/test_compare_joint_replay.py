import json

import pytest

from tools.strategy_farm.compare_joint_replay import classify, load_closed, main


def trade(entry, close, volume=1.0, net=10.0):
    return {"entry_time": entry, "time": close, "volume": volume, "net": net}


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


def test_main_rejects_empty_filtered_operands(tmp_path, capsys):
    stream = tmp_path / "one.jsonl"
    stream.write_text(
        json.dumps({
            "event": "TRADE_CLOSED",
            "magic": 1,
            "symbol": "USDJPY.DWX",
            "entry_time": 1,
            "time": 2,
            "net": 1.0,
            "volume": 0.1,
        })
        + "\n",
        encoding="utf-8",
    )

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
        ]
    )

    result = json.loads(capsys.readouterr().out)
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
        ]
    )
    one_empty = json.loads(capsys.readouterr().out)
    assert exit_code == 2
    assert one_empty["joint_trades"] == 0
    assert one_empty["gated_trades"] == 1
    assert one_empty["match_rate"] is None


def test_main_remains_backwards_compatible_without_magic_filters(tmp_path, capsys):
    stream = tmp_path / "singleton.jsonl"
    stream.write_text(
        json.dumps({
            "event": "TRADE_CLOSED",
            "magic": 1,
            "symbol": "USDJPY.DWX",
            "entry_time": 1,
            "time": 2,
            "net": 1.0,
            "volume": 0.1,
        })
        + "\n",
        encoding="utf-8",
    )

    exit_code = main(["--joint", str(stream), "--gated", str(stream)])

    result = json.loads(capsys.readouterr().out)
    assert exit_code == 0
    assert result["valid"] is True
    assert result["match_rate"] == 1.0
    assert result["filters"]["joint_magic"] is None
    assert result["filters"]["gated_magic"] is None


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
        main(["--joint", str(stream), "--gated", str(stream), *args])

    assert exc.value.code == 2
