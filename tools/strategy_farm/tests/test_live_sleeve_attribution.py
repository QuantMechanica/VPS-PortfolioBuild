"""Tests for the live per-sleeve PnL attribution generator (qm.live-sleeve-attribution/v1)."""
import csv
import json
from pathlib import Path

from tools.strategy_farm import live_sleeve_attribution as subject


FIELDS = [
    "deal_id", "position_id", "time_utc", "entry", "deal_magic", "logical_magic",
    "symbol", "profit", "swap", "commission", "fee", "net_actual",
    "risk_percent_in_force", "net_per_1pct_risk", "magic", "type", "volume",
    "price", "order", "time_broker", "comment",
]


def _row(deal_id, pid, time_utc, entry, magic, symbol, profit, swap, comm, fee, net, typ, vol):
    return [
        str(deal_id), str(pid), time_utc, entry, str(magic), "", symbol,
        str(profit), str(swap), str(comm), str(fee), str(net), "", "",
        str(magic), typ, str(vol), "1", str(deal_id), "", "",
    ]


def _write_deals(path: Path, rows) -> None:
    with path.open("w", encoding="utf-8", newline="") as handle:
        writer = csv.writer(handle, lineterminator="\n")
        writer.writerow(FIELDS)
        writer.writerows(rows)


def _write_pointer(path: Path, sleeves) -> None:
    path.write_text(json.dumps({
        "binary_setfile_fingerprint": {
            "per_sleeve": [
                {"magic_number": m, "deployed_preset": preset} for m, preset in sleeves
            ]
        }
    }), encoding="utf-8")


def _fixture(tmp_path: Path):
    deals = tmp_path / "live_deals_normalized.csv"
    # magic 100000000 -> ea 10000 slot 0 EURUSD; magic 200000001 -> ea 20000 slot 1 GBPUSD
    rows = [
        _row(1, 0, "2026-04-24T00:00:00Z", "IN", 0, "", 100000, 0, 0, 0, 100000, "BALANCE", 0),
        # position 11 (EURUSD ea10000): +10 net
        _row(2, 11, "2026-07-24T01:00:00Z", "IN", 100000000, "EURUSD", 0, 0, -1, 0, -1, "BUY", 0.5),
        _row(3, 11, "2026-07-24T02:00:00Z", "OUT", 100000000, "EURUSD", 12, -1, -1, 0, 10, "SELL", 0.5),
        # position 12 (EURUSD ea10000): -5 net, later day
        _row(4, 12, "2026-07-25T03:00:00Z", "IN", 100000000, "EURUSD", 0, 0, -1, 0, -1, "SELL", 0.25),
        _row(5, 12, "2026-07-25T04:00:00Z", "OUT", 100000000, "EURUSD", -3, 0, -1, 0, -4, "BUY", 0.25),
        # position 21 (GBPUSD ea20000): +3 net
        _row(6, 21, "2026-07-24T05:00:00Z", "IN", 200000001, "GBPUSD", 0, 0, 0, 0, 0, "BUY", 0.1),
        _row(7, 21, "2026-07-24T06:00:00Z", "OUT", 200000001, "GBPUSD", 3, 0, 0, 0, 3, "SELL", 0.1),
        # manual magic 0 trade (separate)
        _row(8, 31, "2026-07-26T07:00:00Z", "IN", 0, "XAUUSD", 0, 0, 0, 0, 0, "BUY", 0.1),
        _row(9, 31, "2026-07-26T08:00:00Z", "OUT", 0, "XAUUSD", 2, 0, 0, 0, 2, "SELL", 0.1),
    ]
    _write_deals(deals, rows)
    pointer = tmp_path / "pointer.json"
    _write_pointer(pointer, [
        (100000000, "1_EURUSD_H1_QM5_10000_alpha.set"),
        (200000001, "2_GBPUSD_H4_QM5_20000_beta.set"),
        (300000000, "3_XAUUSD_D1_QM5_30000_gamma.set"),  # dark: no deals
    ])
    snapshot = tmp_path / "account_snapshot.json"
    snapshot.write_text(json.dumps({
        "equity": 100005.0, "balance": 100009.0, "floating_pnl": -4.0,
        "open_positions": 1, "time_utc": "2026-07-26T09:00:00Z",
    }), encoding="utf-8")
    return deals, pointer, snapshot


def test_schema_and_book_totals(tmp_path):
    deals, pointer, snapshot = _fixture(tmp_path)
    m = subject.build(deals_csv=deals, account_snapshot=snapshot, pointer=pointer,
                      generated_at_utc="2026-09-15T00:00:00Z")
    assert m["schema"] == "qm.live-sleeve-attribution/v1"
    assert m["status"] == "PRESENT"
    bt = m["book_totals"]
    assert bt["book_base_equity"] == 100000.0
    # net_actual is summed over EVERY lifecycle deal (IN rows carry commission too):
    # EURUSD pos11 (-1+10)=9, pos12 (-1-4)=-5 -> 4; GBPUSD +3; manual magic0 +2 -> 9 total
    assert bt["realized_pnl"] == 9.0
    assert bt["trade_count"] == 4
    assert bt["account_floating_pnl"] == -4.0


def test_per_sleeve_mapping_and_costs(tmp_path):
    deals, pointer, snapshot = _fixture(tmp_path)
    m = subject.build(deals_csv=deals, account_snapshot=snapshot, pointer=pointer,
                      generated_at_utc="2026-09-15T00:00:00Z")
    by_magic = {s["magic"]: s for s in m["sleeves"]}
    eur = by_magic[100000000]
    assert eur["ea_id"] == 10000
    assert eur["slot"] == 0
    assert eur["symbol"] == "EURUSD"
    assert eur["timeframe"] == "H1"
    assert eur["in_current_roster"] is True
    assert eur["trade_count"] == 2
    assert eur["realized_pnl"] == 4.0            # pos11 (-1+10)=9, pos12 (-1-4)=-5 -> 4
    assert eur["gross"] == 9.0                   # +12 -3
    assert eur["swap"] == -1.0
    assert eur["commission"] == -4.0             # -1-1-1-1
    assert eur["realized_dd"] == 5.0             # cum peak 9 then 4 -> dd 5
    assert eur["floating_pnl"] == "EVIDENCE_MISSING"
    assert eur["contribution_to_book_return"] == round(4.0 / 100000.0, 8)


def test_dark_sleeve_and_manual_separation(tmp_path):
    deals, pointer, snapshot = _fixture(tmp_path)
    m = subject.build(deals_csv=deals, account_snapshot=snapshot, pointer=pointer,
                      generated_at_utc="2026-09-15T00:00:00Z")
    # 300000000 has no deals -> dark
    assert 300000000 in m["health"]["dark_sleeves"]
    assert m["health"]["unmapped_magics"] == []
    assert m["health"]["roster_size"] == 3
    assert m["health"]["mapped_sleeves"] == 3
    assert m["manual_magic_0"]["trade_count"] == 1
    assert m["manual_magic_0"]["realized_pnl"] == 2.0


def test_correlation_missing_below_20_days(tmp_path):
    deals, pointer, snapshot = _fixture(tmp_path)
    m = subject.build(deals_csv=deals, account_snapshot=snapshot, pointer=pointer,
                      generated_at_utc="2026-09-15T00:00:00Z")
    # fixture window spans 2026-07-24..07-26 -> 3 days < 20
    assert m["correlation_matrix"]["status"] == "EVIDENCE_MISSING"
    assert m["correlation_matrix"]["n_days"] == 3


def test_correlation_present_with_span(tmp_path):
    deals = tmp_path / "live_deals_normalized.csv"
    rows = [_row(1, 0, "2026-04-24T00:00:00Z", "IN", 0, "", 100000, 0, 0, 0, 100000, "BALANCE", 0)]
    # two sleeves trading across a >20 day span, varying daily
    did = 2
    for day in range(1, 25):
        d = f"2026-08-{day:02d}"
        rows.append(_row(did, 1000 + day, f"{d}T01:00:00Z", "IN", 100000000, "EURUSD", 0, 0, 0, 0, 0, "BUY", 0.1)); did += 1
        rows.append(_row(did, 1000 + day, f"{d}T02:00:00Z", "OUT", 100000000, "EURUSD", day, 0, 0, 0, day, "SELL", 0.1)); did += 1
        rows.append(_row(did, 2000 + day, f"{d}T03:00:00Z", "IN", 200000001, "GBPUSD", 0, 0, 0, 0, 0, "BUY", 0.1)); did += 1
        rows.append(_row(did, 2000 + day, f"{d}T04:00:00Z", "OUT", 200000001, "GBPUSD", -day, 0, 0, 0, -day, "SELL", 0.1)); did += 1
    _write_deals(deals, rows)
    pointer = tmp_path / "pointer.json"
    _write_pointer(pointer, [
        (100000000, "1_EURUSD_H1_QM5_10000_alpha.set"),
        (200000001, "2_GBPUSD_H4_QM5_20000_beta.set"),
    ])
    snapshot = tmp_path / "account_snapshot.json"
    snapshot.write_text(json.dumps({"equity": 1.0}), encoding="utf-8")
    m = subject.build(deals_csv=deals, account_snapshot=snapshot, pointer=pointer,
                      generated_at_utc="2026-09-15T00:00:00Z")
    cm = m["correlation_matrix"]
    assert cm["status"] == "PRESENT"
    assert cm["n_days"] >= 20
    assert cm["sleeves_scored"] == 2
    # perfectly anti-correlated daily series
    assert cm["pairs"][0]["correlation"] == -1.0


def test_evidence_missing_when_source_absent(tmp_path):
    m = subject.build(deals_csv=tmp_path / "nope.csv", account_snapshot=tmp_path / "no.json",
                      pointer=tmp_path / "no_ptr.json", generated_at_utc="2026-09-15T00:00:00Z")
    assert m["status"] == "EVIDENCE_MISSING"
    assert m["health"]["source_present"] is False
    assert m["authorization"]["t_live_write"] is False


def test_deterministic_idempotent(tmp_path):
    deals, pointer, snapshot = _fixture(tmp_path)
    a = subject.build(deals_csv=deals, account_snapshot=snapshot, pointer=pointer,
                      generated_at_utc="2026-09-15T00:00:00Z")
    b = subject.build(deals_csv=deals, account_snapshot=snapshot, pointer=pointer,
                      generated_at_utc="2026-09-15T00:00:00Z")
    assert json.dumps(a, sort_keys=True) == json.dumps(b, sort_keys=True)
