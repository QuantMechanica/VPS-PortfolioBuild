"""Synthetic fixtures for the pre-Q00 research package tests (slice C5).

Builds a small ``farm_state``-shaped sqlite DB whose table/column names mirror the
real ones the audit lists (``work_items``, ``ea_metrics``, ``work_item_holds``,
``sources``), plus a matching ``ea_id_registry.csv``. Deliberately NOT collected by
pytest (leading underscore, no ``test_`` prefix).
"""

from __future__ import annotations

import json
import sqlite3
from pathlib import Path


def build_registry_csv(path: Path) -> Path:
    path.write_text(
        "ea_id,slug,strategy_id,status,owner,created_at,retired_at,retired_reason,retired_evidence\n"
        "1001,ema-trend-cross,uuid-1001,active,Development,2026-01-01,,,\n"
        "1002,rsi-mr-fade,uuid-1002,active,Development,2026-01-01,,,\n"
        "1003,donchian-breakout,uuid-1003,active,Development,2026-01-01,,,\n"
        "1004,ema-trend-brk,uuid-1004,active,Development,2026-01-01,,,\n",
        encoding="utf-8",
    )
    return path


def build_fixture_db(path: Path) -> Path:
    """Create a synthetic farm_state.sqlite with taxonomy-diverse rows."""

    connection = sqlite3.connect(path)
    try:
        connection.execute(
            """
            CREATE TABLE work_items (
                id TEXT PRIMARY KEY,
                kind TEXT, phase TEXT, ea_id TEXT, symbol TEXT,
                setfile_path TEXT,
                status TEXT, verdict TEXT, payload_json TEXT,
                created_at TEXT, updated_at TEXT,
                data_window_start TEXT, data_window_end TEXT,
                evidence_path TEXT
            )
            """
        )
        connection.execute(
            """
            CREATE TABLE ea_metrics (
                work_item_id TEXT PRIMARY KEY, ea_id TEXT, phase TEXT, symbol TEXT,
                verdict TEXT, status TEXT, net_profit REAL, profit_factor REAL,
                trades INTEGER, drawdown_money REAL, drawdown_pct REAL, sharpe REAL,
                detail_json TEXT
            )
            """
        )
        connection.execute(
            """
            CREATE TABLE work_item_holds (
                work_item_id TEXT, hold_code TEXT, reason TEXT, active INTEGER
            )
            """
        )
        connection.execute(
            """
            CREATE TABLE sources (
                id TEXT PRIMARY KEY, priority INTEGER, lane TEXT, source_type TEXT,
                uri TEXT, title TEXT, status TEXT
            )
            """
        )

        infra_payload = json.dumps({"verdict_reason": "run_smoke_fail:ACTIVE_TIMEOUT"})
        win = ("2015.01.01", "2019.12.31")

        def _setfile(ea: str, sym: str, tf: str) -> str:
            slug = ea.split("_", 1)[-1]
            return (
                f"framework/EAs/{ea}_{slug}/sets/"
                f"{ea}_{slug}_{sym}_{tf}_q05_stress_medium.set"
            )

        work_items = [
            # id, phase, ea, symbol, tf, status, verdict, payload, window, created
            ("w1", "Q02", "QM5_1001", "EURUSD.DWX", "H1", "done", "PASS", "{}", win, "2026-01-01T00:00:00+00:00"),
            ("w2", "Q02", "QM5_1001", "EURUSD.DWX", "H1", "done", "FAIL", "{}", win, "2026-01-02T00:00:00+00:00"),
            ("w3", "Q02", "QM5_1002", "XAUUSD.DWX", "M15", "failed", "INFRA_FAIL", infra_payload, win, "2026-01-03T00:00:00+00:00"),
            ("w4", "Q02", "QM5_1002", "XAUUSD.DWX", "M15", "done", "ZERO_TRADES", "{}", win, "2026-01-04T00:00:00+00:00"),
            ("w5", "OPT_CENSUS", "QM5_1003", "GBPUSD.DWX", "D1", "done", "MEASURED", "{}", win, "2026-01-05T00:00:00+00:00"),
            ("w6", "Q02", "QM5_1001", "EURUSD.DWX", "H1", "done", "FAIL", "{}", win, "2026-01-06T00:00:00+00:00"),
        ]
        for wid, phase, ea, sym, tf, status, verdict, payload, window, created in work_items:
            connection.execute(
                "INSERT INTO work_items (id, kind, phase, ea_id, symbol, setfile_path, status, verdict, "
                "payload_json, created_at, updated_at, data_window_start, data_window_end, evidence_path) "
                "VALUES (?,?,?,?,?,?,?,?,?,?,?,?,?,?)",
                (
                    wid, "backtest", phase, ea, sym, _setfile(ea, sym, tf), status, verdict, payload,
                    created, created, window[0], window[1],
                    f"D:/QM/reports/work_items/{wid}/summary.json.gz",
                ),
            )

        # ea_metrics: healthy risk metrics chosen to exercise the projector.
        metrics = [
            # wid, ea, sym, verdict, net, pf, trades, dd_money, dd_pct, sharpe
            ("w1", "QM5_1001", "EURUSD.DWX", "PASS", 5000.0, 1.30, 100, 1200.0, 5.0, 0.50),
            ("w2", "QM5_1001", "EURUSD.DWX", "FAIL", -200.0, 1.20, 50, 1500.0, 6.0, 0.40),
            ("w4", "QM5_1002", "XAUUSD.DWX", "ZERO_TRADES", 300.0, 1.10, 3, 800.0, 4.0, 0.30),
            ("w6", "QM5_1001", "EURUSD.DWX", "FAIL", 900.0, 1.40, 8, 600.0, 3.0, 0.60),
        ]
        for wid, ea, sym, verdict, net, pf, trades, ddm, ddp, sharpe in metrics:
            connection.execute(
                "INSERT INTO ea_metrics (work_item_id, ea_id, phase, symbol, verdict, status, "
                "net_profit, profit_factor, trades, drawdown_money, drawdown_pct, sharpe, detail_json) "
                "VALUES (?,?,?,?,?,?,?,?,?,?,?,?,?)",
                (wid, ea, "Q02", sym, verdict, "done", net, pf, trades, ddm, ddp, sharpe, "{}"),
            )

        # An OPT_CENSUS metrics row carrying a parameter-sweep ``runs`` list, so the
        # projector can derive parameter_sensitivity (measurement taxonomy; never an
        # economic-answer input for the section-19 projector).
        census_detail = json.dumps(
            {
                "n_runs": 3,
                "runs": [
                    {"net_profit": 5000.0, "profit_factor": 1.30, "trades": 120},
                    {"net_profit": 1200.0, "profit_factor": 1.05, "trades": 80},
                    {"net_profit": -400.0, "profit_factor": 0.95, "trades": 60},
                ],
            }
        )
        connection.execute(
            "INSERT INTO ea_metrics (work_item_id, ea_id, phase, symbol, verdict, status, "
            "net_profit, profit_factor, trades, drawdown_money, drawdown_pct, sharpe, detail_json) "
            "VALUES (?,?,?,?,?,?,?,?,?,?,?,?,?)",
            ("w5", "QM5_1003", "OPT_CENSUS", "GBPUSD.DWX", "MEASURED", "done",
             5000.0, 1.30, 120, 1000.0, 4.0, 0.5, census_detail),
        )

        connection.execute(
            "INSERT INTO work_item_holds (work_item_id, hold_code, reason, active) VALUES (?,?,?,?)",
            ("w3", "PRESCREEN_SKIPPED", "cold cache", 1),
        )
        connection.execute(
            "INSERT INTO sources (id, priority, lane, source_type, uri, title, status) "
            "VALUES (?,?,?,?,?,?,?)",
            ("SRC-1", 50, "gemini", "internal_research", "QM-RESEARCH://2026-0001", "seed", "pending"),
        )
        connection.commit()
    finally:
        connection.close()
    return path
