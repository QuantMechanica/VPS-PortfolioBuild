from __future__ import annotations

import datetime as dt
import hashlib
import json
from pathlib import Path

import pytest

from tools.strategy_farm.portfolio import ftmo_daily_net_export as exporter
from tools.strategy_farm.portfolio import ftmo_timebox_eval as evaluator


ROOT = Path(__file__).resolve().parents[3]


def _sha(path: Path) -> str:
    return hashlib.sha256(path.read_bytes()).hexdigest()


def _trade_row(
    *,
    entry: dt.datetime,
    exit_: dt.datetime,
    volume: float,
    entry_price: float,
    exit_price: float,
    profit: float,
    entry_commission: float,
    exit_commission: float,
    mae: float,
) -> dict[str, object]:
    commission = entry_commission + exit_commission
    net = profit + commission
    return {
        "event": "TRADE_CLOSED",
        "money_basis": "FULL_POSITION_LIFECYCLE_ACTUAL_V1",
        "entry_time": int(entry.timestamp()),
        "time": int(exit_.timestamp()),
        "symbol": "XAUUSD",
        "side": "buy",
        "volume": volume,
        "entry_price": entry_price,
        "exit_price": exit_price,
        "profit": profit,
        "swap": 0.0,
        "entry_commission": entry_commission,
        "exit_commission": exit_commission,
        "commission": commission,
        "fee": 0.0,
        "net": net,
        "mae_acct": mae,
    }


def _report_html(*, server: str, stale_hours: int = 336) -> tuple[str, list[dict[str, object]]]:
    first_entry = dt.datetime(2024, 1, 2, 10, 0, tzinfo=dt.UTC)
    first_exit = dt.datetime(2024, 1, 2, 12, 0, tzinfo=dt.UTC)
    second_entry = dt.datetime(2024, 1, 3, 10, 0, tzinfo=dt.UTC)
    second_exit = dt.datetime(2024, 1, 3, 12, 0, tzinfo=dt.UTC)
    rows = [
        _trade_row(
            entry=first_entry,
            exit_=first_exit,
            volume=1.0,
            entry_price=2000.0,
            exit_price=2001.0,
            profit=100.0,
            entry_commission=-2.8,
            exit_commission=-2.8,
            mae=-50.0,
        ),
        _trade_row(
            entry=second_entry,
            exit_=second_exit,
            volume=0.5,
            entry_price=2000.0,
            exit_price=1998.0,
            profit=-100.0,
            entry_commission=-1.4,
            exit_commission=-1.4,
            mae=-102.8,
        ),
    ]
    net = sum(float(row["net"]) for row in rows)
    balance_1 = 100_000.0
    balance_2 = balance_1 - 2.8
    balance_3 = balance_2 + 100.0 - 2.8
    balance_4 = balance_3 - 1.4
    balance_5 = balance_4 - 100.0 - 1.4
    deals = f"""
<tr><th>Deals</th></tr>
<tr><td>Time</td><td>Deal</td><td>Symbol</td><td>Type</td><td>Direction</td><td>Volume</td><td>Price</td><td>Order</td><td>Commission</td><td>Swap</td><td>Profit</td><td>Balance</td><td>Comment</td></tr>
<tr><td>2024.01.02 10:00:00</td><td>1</td><td>XAUUSD</td><td>buy</td><td>in</td><td>1.00</td><td>2000.00</td><td>1</td><td>-2.80</td><td>0.00</td><td>0.00</td><td>{balance_2:.2f}</td><td>entry</td></tr>
<tr><td>2024.01.02 12:00:00</td><td>2</td><td>XAUUSD</td><td>sell</td><td>out</td><td>1.00</td><td>2001.00</td><td>2</td><td>-2.80</td><td>0.00</td><td>100.00</td><td>{balance_3:.2f}</td><td>exit</td></tr>
<tr><td>2024.01.03 10:00:00</td><td>3</td><td>XAUUSD</td><td>buy</td><td>in</td><td>0.50</td><td>2000.00</td><td>3</td><td>-1.40</td><td>0.00</td><td>0.00</td><td>{balance_4:.2f}</td><td>entry</td></tr>
<tr><td>2024.01.03 12:00:00</td><td>4</td><td>XAUUSD</td><td>sell</td><td>out</td><td>0.50</td><td>1998.00</td><td>4</td><td>-1.40</td><td>0.00</td><td>-100.00</td><td>{balance_5:.2f}</td><td>exit</td></tr>
"""
    html = f"""<!DOCTYPE html><html><body><table>
<tr><td>Strategy Tester Report</td></tr>
<tr><td>{server}</td></tr>
<tr><td>Settings</td></tr>
<tr><td>Expert:</td><td>QM5_10128_bb-breakout</td></tr>
<tr><td>Symbol:</td><td>XAUUSD</td></tr>
<tr><td>Period:</td><td>Daily (2024.01.01 - 2024.01.05)</td></tr>
<tr><td></td><td>RISK_FIXED=1000</td></tr>
<tr><td></td><td>RISK_PERCENT=0</td></tr>
<tr><td></td><td>qm_news_stale_max_hours={stale_hours}</td></tr>
<tr><td>Company:</td><td>FTMO Global Markets Ltd</td></tr>
<tr><td>Currency:</td><td>USD</td></tr>
<tr><td>Initial Deposit:</td><td>100 000.00</td></tr>
<tr><td>Results</td></tr>
<tr><td>History Quality:</td><td>100% real ticks</td></tr>
<tr><td>Total Net Profit:</td><td>{net:.2f}</td></tr>
<tr><td>Gross Profit:</td><td>94.40</td></tr>
<tr><td>Gross Loss:</td><td>-102.80</td></tr>
<tr><td>Profit Factor:</td><td>0.92</td></tr>
<tr><td>Total Trades:</td><td>2</td></tr>
<tr><td>Equity Drawdown Maximal:</td><td>102.80 (0.10%)</td></tr>
{deals}</table></body></html>"""
    return html, rows


def _fixture(
    tmp_path: Path,
    *,
    server: str = "FTMO-Demo (Build 9999)",
    missing_swap: bool = False,
    stale_hours: int = 336,
) -> dict[str, Path | str]:
    report = tmp_path / "report.htm"
    report_html, trade_rows = _report_html(server=server, stale_hours=stale_hours)
    report.write_text(report_html, encoding="utf-16")

    q08 = tmp_path / "q08.jsonl"
    q08.write_text(
        "".join(json.dumps(row, sort_keys=True) + "\n" for row in trade_rows),
        encoding="utf-8",
    )
    equity = tmp_path / "equity.jsonl"
    equity_rows = [
        (20240101, 100_000.0),
        (20240102, 100_094.4),
        (20240103, 99_991.6),
        (20240104, 99_991.6),
    ]
    equity.write_text(
        "".join(
            json.dumps(
                {
                    "event": "EQUITY_SNAPSHOT",
                    "payload": {
                        "scope": "account",
                        "symbol": "XAUUSD",
                        "day_key": day,
                        "equity": value,
                    },
                },
                sort_keys=True,
            )
            + "\n"
            for day, value in equity_rows
        ),
        encoding="utf-8",
    )
    setfile = tmp_path / "candidate.set"
    setfile.write_text(
        f"RISK_FIXED=1000\nRISK_PERCENT=0\nqm_news_stale_max_hours={stale_hours}\n",
        encoding="utf-8",
    )
    cost = tmp_path / "cost.json"
    term = {
        "active": True,
        "code": "XAU/USD",
        "displayCode": "XAU/USD",
        "commission": 0.0014,
        "commissionType": "percent",
        "swapLong": -75.93,
        "swapShort": -23.55,
        "swapType": "points",
        "contractSize": 100,
        "digits": 2,
        "profitCurrency": "USD",
    }
    if missing_swap:
        term.pop("swapShort")
    cost.write_text(json.dumps([term], sort_keys=True), encoding="utf-8")

    summary = tmp_path / "summary.json"
    summary.write_text(
        json.dumps(
            {
                "evidence_schema": "run_smoke/v2",
                "result": "PASS",
                "ea_id": 10128,
                "symbol": "XAUUSD",
                "model": 4,
                "execution_identity": {
                    "stable_during_run": True,
                    "setfile": {"source": {"sha256": _sha(setfile)}},
                },
                "runs": [
                    {
                        "run": "run_01",
                        "status": "OK",
                        "real_ticks_marker": True,
                        "total_trades": 2,
                        "profit_factor": 0.92,
                        "net_profit": -8.4,
                        "drawdown": 102.8,
                        "report_canonical_path": str(report),
                        "report_sha256": _sha(report),
                    }
                ],
            },
            sort_keys=True,
        ),
        encoding="utf-8",
    )
    return {
        "report": report,
        "q08": q08,
        "equity": equity,
        "setfile": setfile,
        "cost": cost,
        "summary": summary,
        "cost_sha": _sha(cost),
        "out": tmp_path / "daily.jsonl",
        "receipt": tmp_path / "receipt.json",
    }


def _export(case: dict[str, Path | str]) -> dict[str, object]:
    return exporter.export_ftmo_daily_stream(
        sleeve_id="10128:XAUUSD",
        symbol="XAUUSD",
        native_symbol="XAUUSD",
        ftmo_code="XAU/USD",
        summary_path=Path(case["summary"]),
        report_path=Path(case["report"]),
        q08_trades_path=Path(case["q08"]),
        equity_log_path=Path(case["equity"]),
        cost_snapshot_path=Path(case["cost"]),
        setfile_path=Path(case["setfile"]),
        output_path=Path(case["out"]),
        receipt_path=Path(case["receipt"]),
        expected_cost_sha256=str(case["cost_sha"]),
    )


def test_pinned_snapshot_digest_matches_repository_artifact() -> None:
    snapshot = ROOT / "artifacts" / "ftmo_symbol_snapshot_2026-07-11.json"
    assert _sha(snapshot) == exporter.PINNED_COST_SNAPSHOT_SHA256


def test_exports_exact_evaluator_schema_and_audit_receipt(tmp_path: Path) -> None:
    case = _fixture(tmp_path)
    receipt = _export(case)

    rows = [json.loads(line) for line in Path(case["out"]).read_text().splitlines()]
    assert len(rows) == 5
    assert rows[0]["date"] == "2024-01-01"
    assert rows[-1]["date"] == "2024-01-05"
    assert rows[1]["trade_count"] == 1
    assert rows[1]["intraday_low_return"] == pytest.approx(-0.000528)
    assert rows[2]["trade_count"] == 1
    assert rows[-1]["net_return"] == 0.0
    assert all(row["venue"] == "FTMO" for row in rows)
    assert all(row["cost_snapshot_sha256"] == case["cost_sha"] for row in rows)
    assert receipt["status"] == "PASS"
    assert receipt["attestation"]["report_server"].startswith("FTMO-Demo")
    assert receipt["construction"]["final_close_source"] == (
        "MT5_REPORT_FINAL_BALANCE_FLAT_RECONCILED"
    )
    assert Path(case["receipt"]).is_file()

    entry = {
        "sleeve_id": "10128:XAUUSD",
        "symbol": "XAUUSD",
    }
    points = evaluator.load_daily_stream(entry, Path(case["out"]), str(case["cost_sha"]))
    assert len(points) == 5
    assert points[1].trade_count == 1


def test_refuses_darwinex_report_without_writing_output(tmp_path: Path) -> None:
    case = _fixture(tmp_path, server="Darwinex-Live (Build 9999)")
    with pytest.raises(exporter.FtmoDailyExportError, match="not a native FTMO-Demo"):
        _export(case)
    assert not Path(case["out"]).exists()
    assert not Path(case["receipt"]).exists()


def test_refuses_missing_swap_term(tmp_path: Path) -> None:
    case = _fixture(tmp_path, missing_swap=True)
    with pytest.raises(exporter.FtmoDailyExportError, match="inactive or incomplete"):
        _export(case)
    assert not Path(case["out"]).exists()


def test_refuses_news_staleness_weakening(tmp_path: Path) -> None:
    case = _fixture(tmp_path, stale_hours=337)
    with pytest.raises(exporter.FtmoDailyExportError, match="exceeds 336"):
        _export(case)
    assert not Path(case["out"]).exists()


def test_refuses_legacy_q08_money_basis(tmp_path: Path) -> None:
    case = _fixture(tmp_path)
    rows = [json.loads(line) for line in Path(case["q08"]).read_text().splitlines()]
    for row in rows:
        row.pop("money_basis")
    Path(case["q08"]).write_text(
        "".join(json.dumps(row, sort_keys=True) + "\n" for row in rows),
        encoding="utf-8",
    )
    with pytest.raises(exporter.FtmoDailyExportError, match="FULL_POSITION_LIFECYCLE"):
        _export(case)
    assert not Path(case["out"]).exists()
