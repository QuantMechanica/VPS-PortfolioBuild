import csv
import json
from pathlib import Path

from tools.strategy_farm.portfolio import live_deal_attribution as subject


FIELDS = ["deal_id", "position_id", "time_utc", "entry", "deal_magic", "logical_magic", "symbol", "profit", "swap", "commission", "fee", "net_actual", "risk_percent_in_force", "net_per_1pct_risk", "magic", "type", "volume", "price", "order", "time_broker", "comment"]


def test_per_magic_metrics_and_manual_separation(tmp_path: Path) -> None:
    source = tmp_path / "deals.csv"
    rows = [
        ["1", "11", "2026-07-24T01:00:00Z", "IN", "10000", "", "EURUSD", "0", "0", "-1", "0", "-1", "", "", "10000", "BUY", "0.5", "1", "1", "", ""],
        ["2", "11", "2026-07-24T02:00:00Z", "OUT", "10000", "", "EURUSD", "11", "0", "-1", "0", "10", "", "", "10000", "SELL", "0.5", "1", "2", "", ""],
        ["3", "12", "2026-07-25T03:00:00Z", "IN", "10000", "", "EURUSD", "0", "0", "-1", "0", "-1", "", "", "10000", "SELL", "0.25", "1", "3", "", ""],
        ["4", "12", "2026-07-25T04:00:00Z", "OUT", "10000", "", "EURUSD", "-4", "0", "-1", "0", "-5", "", "", "10000", "BUY", "0.25", "1", "4", "", ""],
        ["5", "13", "2026-07-25T05:00:00Z", "IN", "0", "", "XAUUSD", "0", "0", "0", "0", "0", "", "", "0", "BUY", "0.1", "1", "5", "", "manual"],
        ["6", "13", "2026-07-25T06:00:00Z", "OUT", "0", "", "XAUUSD", "3", "0", "0", "0", "3", "", "", "0", "SELL", "0.1", "1", "6", "", "manual"],
        ["7", "0", "2026-07-25T07:00:00Z", "IN", "0", "", "", "2", "0", "0", "0", "2", "", "", "0", "DIVIDEND", "0", "0", "0", "", ""],
    ]
    with source.open("w", encoding="utf-8", newline="") as handle:
        writer = csv.writer(handle, lineterminator="\n"); writer.writerow(FIELDS); writer.writerows(rows)
    pointer = tmp_path / "pointer.json"
    pointer.write_text(json.dumps({"binary_setfile_fingerprint": {"per_sleeve": [{"magic_number": 10000, "deployed_preset": "1_EURUSD_H1_QM5_1.set"}, {"magic_number": 20000, "deployed_preset": "2_GBPUSD_H1_QM5_2.set"}]}}), encoding="utf-8")
    report = subject.build(source, pointer, "2026-07-24T00:00:00Z", "2026-09-12T00:00:00Z")
    by_magic = {row["magic"]: row for row in report["per_magic"]}
    assert by_magic[10000]["closes"] == 2
    assert by_magic[10000]["net"] == 3.0
    assert by_magic[10000]["gross_win"] == 9.0
    assert by_magic[10000]["gross_loss"] == -6.0
    assert by_magic[10000]["profit_factor"] == 1.5
    assert by_magic[10000]["lots"] == 0.75
    assert by_magic[10000]["entry_hour_utc"]["1"] == 1
    assert by_magic[20000]["flat"] is True
    assert report["manual_magic_0"]["closes"] == 1
    assert report["non_trade_magic_0_rows_excluded"] == 1
