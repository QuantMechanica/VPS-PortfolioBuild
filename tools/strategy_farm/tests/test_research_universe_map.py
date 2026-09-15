"""Tests: strategy universe economic map (§19) — cells, ranking, idempotency."""

from __future__ import annotations

import json
import sqlite3
import sys
from pathlib import Path

SF = Path(__file__).resolve().parents[1]
if str(SF) not in sys.path:
    sys.path.insert(0, str(SF))

import datetime as dt  # noqa: E402

from research import universe_map as um  # noqa: E402

_FIXED_NOW = dt.datetime(2026, 9, 15, 12, 0, 0, tzinfo=dt.timezone.utc)


def _build_db(path: Path) -> Path:
    conn = sqlite3.connect(path)
    try:
        conn.execute(
            "CREATE TABLE work_items (id TEXT PRIMARY KEY, kind TEXT, phase TEXT, "
            "ea_id TEXT, symbol TEXT, setfile_path TEXT, status TEXT, verdict TEXT, "
            "payload_json TEXT, created_at TEXT, updated_at TEXT, data_window_start TEXT, "
            "data_window_end TEXT, evidence_path TEXT)"
        )
        conn.execute(
            "CREATE TABLE ea_metrics (work_item_id TEXT PRIMARY KEY, ea_id TEXT, phase TEXT, "
            "symbol TEXT, verdict TEXT, status TEXT, net_profit REAL, profit_factor REAL, "
            "trades INTEGER, drawdown_money REAL, drawdown_pct REAL, sharpe REAL, detail_json TEXT)"
        )
        win = ("2015.01.01", "2019.12.31")  # ~5 years

        def sf(ea, slug, sym, tf):
            return f"framework/EAs/{ea}_{slug}/sets/{ea}_{slug}_{sym}_{tf}_q05_stress_medium.set"

        # (id, phase, ea, slug, sym, tf, verdict)
        rows = [
            # 1001: EURUSD H1 trend, reaches Q14 (qualified), active frequency
            ("a1", "Q02", "QM5_1001", "ema-trend-cross", "EURUSD.DWX", "H1", "PASS"),
            ("a2", "Q08", "QM5_1001", "ema-trend-cross", "EURUSD.DWX", "H1", "PASS"),
            ("a3", "Q14", "QM5_1001", "ema-trend-cross", "EURUSD.DWX", "H1", "MULTI_SEED_PASS"),
            # 1002: XAUUSD D1 breakout, reaches Q04 only, gold
            ("b1", "Q02", "QM5_1002", "donchian-breakout", "XAUUSD.DWX", "D1", "PASS"),
            ("b2", "Q04", "QM5_1002", "donchian-breakout", "XAUUSD.DWX", "D1", "FAIL"),
            # 1003: GBPUSD M5 mean-reversion scalp, asian session, reaches Q02
            ("c1", "Q02", "QM5_1003", "asian-rsi-fade-mr", "GBPUSD.DWX", "M5", "PASS"),
            # 1004: SP500 M15 breakout, london session, reaches Q08
            ("d1", "Q02", "QM5_1004", "london-donchian-break", "SP500.DWX", "M15", "PASS"),
            ("d2", "Q08", "QM5_1004", "london-donchian-break", "SP500.DWX", "M15", "PASS"),
        ]
        for wid, phase, ea, slug, sym, tf, verdict in rows:
            conn.execute(
                "INSERT INTO work_items (id, kind, phase, ea_id, symbol, setfile_path, status, "
                "verdict, payload_json, created_at, updated_at, data_window_start, data_window_end, "
                "evidence_path) VALUES (?,?,?,?,?,?,?,?,?,?,?,?,?,?)",
                (wid, "backtest", phase, ea, sym, sf(ea, slug, sym, tf), "done", verdict, "{}",
                 "2026-01-01T00:00:00+00:00", "2026-01-01T00:00:00+00:00", win[0], win[1], ""),
            )
        # Q02 trades -> frequency class. 1001: 750 over 5y = 150/y active; 1003: 2000 = scalp_hf.
        metrics = [
            ("a1", "QM5_1001", "EURUSD.DWX", 750),
            ("b1", "QM5_1002", "XAUUSD.DWX", 40),   # 8/y sparse
            ("c1", "QM5_1003", "GBPUSD.DWX", 2000),  # 400/y scalp_hf
            ("d1", "QM5_1004", "SP500.DWX", 600),    # 120/y active
        ]
        for wid, ea, sym, trades in metrics:
            conn.execute(
                "INSERT INTO ea_metrics (work_item_id, ea_id, phase, symbol, verdict, status, "
                "net_profit, profit_factor, trades, drawdown_money, drawdown_pct, sharpe, detail_json) "
                "VALUES (?,?,?,?,?,?,?,?,?,?,?,?,?)",
                (wid, ea, "Q02", sym, "PASS", "done", 1000.0, 1.3, trades, 100.0, 3.0, 0.5, "{}"),
            )
        conn.commit()
    finally:
        conn.close()
    return path


def _build_registry(path: Path) -> Path:
    path.write_text(
        "ea_id,slug,strategy_id,status,owner,created_at,retired_at,retired_reason,retired_evidence\n"
        "1001,ema-trend-cross,u1,active,Development,2026-01-01,,,\n"
        "1002,donchian-breakout,u2,active,Development,2026-01-01,,,\n"
        "1003,asian-rsi-fade-mr,u3,active,Research,2026-01-01,,,\n"
        "1004,london-donchian-break,u4,active,Research,2026-01-01,,,\n",
        encoding="utf-8",
    )
    return path


def _build_books(tmp_path: Path):
    dxz = tmp_path / "book_dxz.json"
    ftmo = tmp_path / "book_ftmo.json"
    dxz.write_text(json.dumps({
        "incumbent": {"sleeves": [{"ea_id": 1001, "symbol": "EURUSD.DWX"}]}
    }), encoding="utf-8")
    ftmo.write_text(json.dumps({
        "incumbent": {"sleeves": [{"ea_id": 1004, "symbol": "SP500.DWX"}]}
    }), encoding="utf-8")
    return dxz, ftmo


def _build_candidate_universe(path: Path) -> Path:
    path.write_text(
        "ea_id,symbol,status,highest_contiguous_valid_gate\n"
        "QM5_1001,EURUSD.DWX,QUALIFIED,Q14\n",
        encoding="utf-8",
    )
    return path


def _inputs(tmp_path):
    db = _build_db(tmp_path / "farm_state.sqlite")
    reg = _build_registry(tmp_path / "reg.csv")
    dxz, ftmo = _build_books(tmp_path)
    cand = _build_candidate_universe(tmp_path / "cand.csv")
    return db, reg, dxz, ftmo, cand


def _model(tmp_path):
    db, reg, dxz, ftmo, cand = _inputs(tmp_path)
    return um.build_universe_map(
        db, registry_path=reg, book_dxz_path=dxz, book_ftmo_path=ftmo,
        candidate_universe_csv=cand, now=_FIXED_NOW,
    )


def test_schema_and_totals(tmp_path):
    m = _model(tmp_path)
    assert m["schema"] == "qm.strategy-universe-map/v1"
    assert m["totals"]["pairs"] == 4  # 1001,1002,1003,1004 each one symbol
    assert m["totals"]["qualified"] == 1
    assert m["totals"]["dxz_incumbent"] == 1
    assert m["totals"]["ftmo_incumbent"] == 1


def test_style_and_classifiers(tmp_path):
    m = _model(tmp_path)
    style = m["marginals"]["style"]
    assert style.get("trend") == 1          # ema-trend-cross
    assert style.get("breakout") == 2       # donchian-breakout + london-donchian-break
    assert style.get("mean-reversion") == 1  # asian-rsi-fade-mr
    # holding: H1 intraday, D1 position, M5 scalp, M15 intraday
    assert m["marginals"]["holding_class"].get("intraday") == 2
    assert m["marginals"]["holding_class"].get("scalp") == 1
    assert m["marginals"]["holding_class"].get("position") == 1


def test_directive_answers(tmp_path):
    m = _model(tmp_path)
    da = m["directive_answers"]
    assert da["total_pairs"] == 4
    assert da["breakout_derivative_share"]["count"] == 2
    assert da["mean_reversion"]["count"] == 1
    assert da["gold_share"]["count"] == 1  # XAUUSD
    # short-duration FX: 1001 (H1 fx_major) + 1003 (M5 fx_major) = 2
    assert da["short_duration_fx_systems"]["count"] == 2
    # session-tagged: asian (1003) + london (1004) = 2
    assert da["session_diversification"]["count"] == 2


def test_frequency_class(tmp_path):
    m = _model(tmp_path)
    freq = m["marginals"]["frequency_class"]
    assert freq.get("scalp_hf") == 1   # 1003 400/y
    assert freq.get("active") == 2     # 1001 150/y, 1004 120/y
    assert freq.get("sparse") == 1     # 1002 8/y


def test_whitespace_ranking_prefers_ftmo_fit(tmp_path):
    m = _model(tmp_path)
    ws = m["whitespace_ranked"]
    assert ws, "expected ranked white-space cells"
    # Highest-value white space must be an intraday/scalp, session-defined, index/fx cell.
    top = ws[0]
    assert top["holding_class"] in {"scalp", "intraday"}
    assert top["session"] in {"open", "london", "ny", "asian"}
    assert top["symbol_class"] in {"index", "fx_major", "fx_jpy", "metal"}
    # A position/overnight cell must rank strictly below the top.
    assert top["expected_value"] > ws[-1]["expected_value"]
    # No ranked cell may contain a qualified pair (definition of white space).
    assert all(c["n_qualified"] == 0 for c in ws)


def test_idempotent_byte_identical(tmp_path):
    db, reg, dxz, ftmo, cand = _inputs(tmp_path)
    kw = dict(registry_path=reg, book_dxz_path=dxz, book_ftmo_path=ftmo,
              candidate_universe_csv=cand, now=_FIXED_NOW)
    m1 = um.build_universe_map(db, **kw)
    m2 = um.build_universe_map(db, **kw)
    assert json.dumps(m1, sort_keys=True) == json.dumps(m2, sort_keys=True)
    assert m1["inputs_sha256"] == m2["inputs_sha256"]


def test_render_doc_contains_numbers(tmp_path):
    m = _model(tmp_path)
    doc = um.render_doc(m)
    assert "Strategy Universe Economic Map" in doc
    assert "breakout" in doc.lower()
    assert m["inputs_sha256"] in doc


def test_summary_for_research_state(tmp_path):
    m = _model(tmp_path)
    s = um.summary_for_research_state(m)
    assert s["totals"]["pairs"] == 4
    assert "top_whitespace" in s
    assert len(s["top_whitespace"]) <= 5
