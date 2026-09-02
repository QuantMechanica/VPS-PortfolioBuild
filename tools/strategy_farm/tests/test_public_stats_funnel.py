import importlib.util
import sqlite3
from pathlib import Path

REPO = Path(__file__).resolve().parents[3]


def _load_module():
    path = REPO / "tools" / "strategy_farm" / "public_stats_funnel.py"
    spec = importlib.util.spec_from_file_location("public_stats_funnel_test", path)
    assert spec and spec.loader
    module = importlib.util.module_from_spec(spec)
    spec.loader.exec_module(module)
    return module


def _make_db(path: Path, *, with_sources: bool = True) -> None:
    conn = sqlite3.connect(path)
    conn.execute(
        "CREATE TABLE work_items ("
        "id TEXT PRIMARY KEY, phase TEXT, ea_id TEXT, symbol TEXT, "
        "status TEXT, verdict TEXT)"
    )
    rows = [
        # Q02: two distinct (ea,symbol) PASS pairs; one duplicate; one non-PASS.
        ("a1", "Q02", "E1", "EURUSD", "done", "PASS"),
        ("a2", "Q02", "E1", "EURUSD", "done", "PASS"),   # dup pair -> not counted twice
        ("a3", "Q02", "E1", "GBPUSD", "done", "PASS"),
        ("a4", "Q02", "E2", "EURUSD", "done", "FAIL"),   # not PASS
        ("a5", "Q02", "E2", "EURUSD", "failed", "PASS"),  # not done
        # Q04: one PASS pair.
        ("b1", "Q04", "E1", "EURUSD", "done", "PASS"),
        # Q08: one PASS pair.
        ("c1", "Q08", "E1", "EURUSD", "done", "PASS"),
        # Q10_NEWS: two CONFIG_LOCKED pairs; one wrong verdict.
        ("d1", "Q10_NEWS", "E1", "EURUSD", "done", "CONFIG_LOCKED"),
        ("d2", "Q10_NEWS", "E1", "GBPUSD", "done", "CONFIG_LOCKED"),
        ("d3", "Q10_NEWS", "E1", "USDJPY", "done", "REVIEW_REQUIRED"),
        # symbols: distinct non-empty across done rows. Empty symbol excluded.
        ("e1", "Q02", "E9", "XAUUSD", "done", "FAIL"),
        ("e2", "Q02", "E9", "", "done", "SUPERSEDED"),   # empty symbol excluded
        ("e3", "Q02", "E9", None, "pending", None),      # null / not done
    ]
    conn.executemany(
        "INSERT INTO work_items(id, phase, ea_id, symbol, status, verdict) "
        "VALUES(?,?,?,?,?,?)",
        rows,
    )
    if with_sources:
        conn.execute("CREATE TABLE sources(id TEXT PRIMARY KEY)")
        conn.executemany(
            "INSERT INTO sources VALUES(?)", [("s1",), ("s2",), ("s3",)]
        )
    conn.commit()
    conn.close()


def test_funnel_counts_distinct_pairs(tmp_path: Path) -> None:
    module = _load_module()
    db = tmp_path / "farm.sqlite"
    _make_db(db)
    conn = module.open_ro(db)
    try:
        funnel = module.compute_funnel(conn)
    finally:
        conn.close()

    assert funnel["q02_baseline_pass"] == 2   # (E1,EURUSD),(E1,GBPUSD)
    assert funnel["q04_walkforward_pass"] == 1
    assert funnel["q08_davey_stats_pass"] == 1
    assert funnel["portfolio_candidates"] == 2  # (E1,EURUSD),(E1,GBPUSD) CONFIG_LOCKED
    # distinct non-empty symbols over done rows: EURUSD, GBPUSD, USDJPY, XAUUSD
    assert funnel["symbols"] == 4
    assert funnel["research_sources"] == 3


def test_funnel_omits_research_sources_when_table_absent(tmp_path: Path) -> None:
    module = _load_module()
    db = tmp_path / "farm.sqlite"
    _make_db(db, with_sources=False)
    conn = module.open_ro(db)
    try:
        funnel = module.compute_funnel(conn)
    finally:
        conn.close()
    assert "research_sources" not in funnel


def test_open_ro_is_read_only(tmp_path: Path) -> None:
    import pytest

    module = _load_module()
    db = tmp_path / "farm.sqlite"
    _make_db(db)
    before = db.read_bytes()
    conn = module.open_ro(db)
    try:
        with pytest.raises(sqlite3.OperationalError):
            conn.execute("INSERT INTO work_items(id) VALUES('x')")
            conn.commit()
    finally:
        conn.close()
    assert db.read_bytes() == before
