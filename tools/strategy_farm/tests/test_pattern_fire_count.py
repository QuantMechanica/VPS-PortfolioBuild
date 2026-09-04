"""Independent, hand-built MQL oracle + counter boundary/ingestion tests."""
import csv
import hashlib
import json
import re
import sqlite3
from collections import defaultdict
from datetime import datetime, timezone
from pathlib import Path

import pytest

from tools.strategy_farm.research import pattern_fire_count as p
from tools.strategy_farm.research import verify_pattern_fire_count as verify

ROOT = Path(__file__).resolve().parents[3]
BUNDLE = ROOT / "framework/tests/fixtures/pattern_permission/_bundle"
GROUPS = defaultdict(list)
for row in csv.DictReader((BUNDLE / "pattern_fixtures.csv").open(encoding="utf-8")):
    GROUPS[row["fixture_id"]].append(row)
ORACLE = {r["fixture_id"]: r for r in csv.DictReader(
    (BUNDLE / "pattern_fixture_results.csv").open(encoding="utf-8"))}


def test_source_contract_and_positive_negative_coverage():
    source = (ROOT / "framework/include/QM/QM_PatternPermission.mqh").read_text(encoding="utf-8")
    assert hashlib.sha256(source.encode()).hexdigest() == p.MQL_SOURCE_SHA256_LF
    enum = source.split("enum QM_PatternId", 1)[1].split("};", 1)[0]
    ids = {int(n) for n in re.findall(r"=\s*(\d+)", enum)} - {0}
    assert ids == set(p.IDS) and len(ids) == 77 and len(p.ARMS) == 154
    for pid in p.IDS:
        cases = {rows[0]["case"] for rows in GROUPS.values() if int(rows[0]["predicate_id"]) == pid}
        assert {"positive", "negative"} <= cases
    assert set(ORACLE) == set(GROUPS)


@pytest.mark.parametrize("fixture_id", sorted(GROUPS))
def test_hand_constructed_mql_fixtures(fixture_id):
    rows = sorted(GROUPS[fixture_id], key=lambda r: int(r["bar_index"]))
    bars = [p.Bar(int(r["time_epoch"]), *(float(r[k]) for k in ("open", "high", "low", "close")),
                  int(r["tick_volume"])) for r in rows]
    oracle = ORACLE[fixture_id]
    assert oracle["verdict"] == "PASS"
    assert p.required_bars(int(rows[0]["predicate_id"])) == int(oracle["bars_required"])
    assert p.evaluate(int(rows[0]["predicate_id"]), bars) == bool(int(oracle["actual"])) == bool(int(rows[0]["expected"]))


def report_html(deal_direction="in", with_order=True):
    def row(*values): return "<tr>" + "".join(f"<td>{v}</td>" for v in values) + "</tr>"
    return ("<html><table>" + row("<b>Orders</b>")
            + (row("2020.01.02 00:04:00", "12", "EURUSD.DWX", "buy stop", "1 / 1", "1", "0", "0", "2020.01.03 12:00:00", "filled", "entry") if with_order else "")
            + row("2020.01.03 13:00:00", "13", "EURUSD.DWX", "sell", "1 / 1", "1", "0", "0", "2020.01.03 13:00:00", "filled", "exit")
            + row("Deals")
            + row("2020.01.01 00:00:00", "1", "", "balance", "", "", "", "0", "0", "0", "100 000.00")
            + row("2020.01.03 12:00:00", "2", "EURUSD.DWX", "buy", deal_direction, ".5", "1", "12", "0", "0", "0")
            + row("2020.01.03 12:00:01", "3", "EURUSD.DWX", "buy", deal_direction, ".5", "1", "12", "0", "0", "0")
            + row("2020.01.03 13:00:00", "4", "EURUSD.DWX", "sell", "out", "1", "1", "13", "0", "0", "0")
            + "</table></html>")


@pytest.mark.parametrize("encoding", ["utf-16", "utf-8-sig"])
def test_parser_pending_creation_partial_fills_and_exit_orders(tmp_path, encoding):
    path = tmp_path / "report.htm"
    path.write_text(report_html(), encoding=encoding)
    entries, candidates = p.parse_report(path)
    assert len(entries) == len(candidates) == 1
    assert entries[0].decision_time == p.civil_epoch("2020.01.02 00:04:00")
    assert entries[0].time == p.civil_epoch("2020.01.03 12:00:00")
    assert entries[0].direction == "BUY"


@pytest.mark.parametrize("html", [report_html("in/out"), report_html(with_order=False), "<html>no deals</html>"])
def test_parser_fails_on_ambiguous_or_missing_input(tmp_path, html):
    path = tmp_path / "report.htm"; path.write_text(html)
    with pytest.raises(ValueError): p.parse_report(path)


@pytest.mark.parametrize("stamp, expected", [
    ("2020-01-02T21:59:59+00:00", "2020.01.02 23:59:59"),
    ("2020-01-02T22:00:00+00:00", "2020.01.03 00:00:00"),
    ("2020-07-02T20:59:59+00:00", "2020.07.02 23:59:59"),
    ("2020-07-02T21:00:00+00:00", "2020.07.03 00:00:00"),
    ("2020-03-09T21:00:00+00:00", "2020.03.10 00:00:00"),
    ("2020-11-02T22:00:00+00:00", "2020.11.03 00:00:00"),
])
def test_new_york_close_and_us_dst(stamp, expected):
    assert p.broker_epoch(datetime.fromisoformat(stamp)) == p.civil_epoch(expected)


def test_tick_builder_bid_ohlc_count_boundary_and_manifest(tmp_path):
    archive = tmp_path / "ticks"; archive.mkdir()
    src = archive / "202001.csv"
    values = [("2020-01-02T21:59:59+00:00", 1.0), ("2020-01-02T22:00:00+00:00", 2.0),
              ("2020-01-02T22:01:00+00:00", 3.0), ("2020-01-02T22:02:00+00:00", 1.5)]
    with src.open("w", newline="") as f:
        w = csv.writer(f); w.writerow(["time_msc", "bid"])
        w.writerows((int(datetime.fromisoformat(t).timestamp()) * 1000, v) for t, v in values)
    out = tmp_path / "D1.csv"
    manifest = p.build_tick_cache(archive, out, "utc")
    bars = p.read_bars(out)
    assert len(bars) == 2
    assert (bars[1].open, bars[1].high, bars[1].low, bars[1].close, bars[1].tick_volume) == (2, 3, 1.5, 1.5, 3)
    assert manifest["cache_sha256"] == p.sha256(out)
    assert manifest["tester_spot_check_verified"] is False


def test_tkc_only_archive_fails_without_creating_a_cache(tmp_path):
    (tmp_path / "202001.tkc").write_bytes(b"not a transparent tick source")
    out = tmp_path / "D1.csv"
    with pytest.raises(ValueError, match="unsupported"): p.build_tick_cache(tmp_path, out, "utc")
    assert not out.exists()


def test_missing_volume_is_not_silent_zero(tmp_path):
    path = tmp_path / "bars.csv"
    path.write_text("time,open,high,low,close\n1577836800,1,2,0,1\n")
    with pytest.raises(ValueError, match="tick volume"): p.read_bars(path)


def test_closed_bar_weekend_direction_and_short_history():
    first = p.civil_epoch("2019.01.01 00:00:00")
    times = [first + i * 86400 for i in range(220)
             if datetime.fromtimestamp(first + i * 86400, timezone.utc).weekday() < 5]
    bars = [p.Bar(t, 10, 12, 8, 10, 100) for t in times]
    monday = next(i for i in range(110, len(bars)) if datetime.fromtimestamp(bars[i].time, timezone.utc).weekday() == 0)
    entry = p.Entry(bars[monday].time + 500, "BUY", "1", bars[monday].time + 1, "EURUSD.DWX")
    counts, alignment = p.count_entries([entry], bars)
    assert counts["buy_003"] == 1 and counts["sell_003"] == 0
    assert alignment[0]["reference_bar_time"] == bars[monday - 1].time == bars[monday].time - 3 * 86400
    with pytest.raises(ValueError, match="history"): p.count_entries([entry], bars[monday - 50:])
    with pytest.raises(ValueError, match="unsupported"): p.evaluate(61, bars)
    with pytest.raises(ValueError, match="short history"): p.evaluate(3, bars[:2])


@pytest.mark.parametrize("prediction,profit,trades,outcome", [
    (0, "1.00", 1, "true_never_fires"), (0, "1.01", 1, "false_never_fires"),
    (1, "1.00", 1, "false_fires"), (1, "1.00", 2, "true_fires"),
])
def test_confusion_matrix_uses_both_exact_metrics(prediction, profit, trades, outcome):
    assert verify.classify(prediction, {"net_profit": "1", "trades": 1},
                           {"net_profit": profit, "trades": trades}) == outcome


def test_pruned_done_row_is_not_a_measured_zero_effect(tmp_path):
    path = tmp_path / "receipt.json"
    path.write_text(json.dumps({"schema": "qm.dl089-skipped-as-excluded/v1", "disposition": "skipped_as_excluded"}))
    conn = sqlite3.connect(":memory:"); conn.row_factory = sqlite3.Row
    conn.execute("CREATE TABLE work_items(id,status,evidence_path,payload_json)")
    conn.execute("INSERT INTO work_items VALUES(?,?,?,?)", ("x", "done", str(path), "{}"))
    result, reason = verify.load_cell(conn, {"work_item_id": "x"})
    assert result is None and reason == "pruned_receipt_not_a_measured_cell"
    conn.close()


def test_report_summary_count_rejects_silent_parser_loss(tmp_path):
    path = tmp_path / "report.htm"
    path.write_text(report_html().replace("<table>", "<table><tr><td>Total Trades:</td><td>2</td></tr>"))
    with pytest.raises(ValueError, match="total trades"): p.parse_report(path)


@pytest.mark.parametrize("bad", [float("nan"), float("inf")])
def test_nonfinite_bars_are_not_never_fires(bad):
    with pytest.raises(ValueError, match="invalid bar"):
        p.evaluate(99, [p.Bar(1577836800, bad, 2, 0, 1, 1)])


def test_program_report_to_json_csv_and_source_pin(tmp_path):
    bars = tmp_path / "bars.csv"
    start = p.civil_epoch("2019.01.01 00:00:00")
    with bars.open("w", newline="") as f:
        w = csv.writer(f); w.writerow(["time", "open", "high", "low", "close", "tick_volume"])
        w.writerows((start + i * 86400, 1, 2, 0, 1, 100) for i in range(380))
    report = tmp_path / "report.htm"; report.write_text(report_html())
    result = p.count_program("unit_program", "EURUSD.DWX", {2020: report}, bars)
    assert result["total"]["buy_003"] == 1 and result["total"]["sell_003"] == 0
    assert result["safe_to_skip"] is False
    assert result["predicate_source_sha256_lf"] == p.MQL_SOURCE_SHA256_LF
    out = tmp_path / "result.json"; p.write_result(result, out)
    assert json.loads(out.read_text())["years_observed"] == [2020]
    assert len(out.with_suffix(".csv").read_text().splitlines()) == 155
