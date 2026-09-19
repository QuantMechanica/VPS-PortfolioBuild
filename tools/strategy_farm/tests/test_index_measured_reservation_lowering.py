"""Evidence-bound lowering of the single_index_tick flat reservation (2026-09-19).

``_resolve_ram_reservation`` is max(flat, measured, floor); until this change a
per-EA ledger expectation of 11.5 GB (QM5_1230 NDX D1, n=11) could never lower
the 44 GB index flat, so every full-window index row was unwinnable on the
63 GB host.  The new pure helper lowers ONLY single-index rows, ONLY downwards,
ONLY on evidence (per-EA n>=3 same timeframe, else class n>=30), clamped to
[12 GB, flat]; news rows fall back to the backtest key.  Rollback env
QM_INDEX_EA_MEASURED_LOWERS=0.
"""
import json
import sys
from pathlib import Path

sys.path.insert(0, str(Path(__file__).resolve().parents[1]))

import terminal_worker as tw  # noqa: E402


def _reset_cache():
    tw._TESTER_MEMORY_EXPECTATIONS_CACHE.update(
        {"path": None, "mtime": None, "data": {}, "at": -1e9}
    )


def _write(path, keys):
    path.parent.mkdir(parents=True, exist_ok=True)
    path.write_text(
        json.dumps({"schema": "qm.tester_memory_expectations/v2", "keys": keys}),
        encoding="utf-8",
    )


def test_per_ea_evidence_lowers_index_flat():
    data = {"ea:QM5_1230|D1|backtest": {"n": 11, "p95_gb": 11.495, "max_gb": 11.505}}
    got = tw._index_measured_flat_reservation_gb(data, "QM5_1230", "index", "D1", "backtest", 44.0)
    # ceil(max(11.495*1.5+2=19.24, 13.5)) = 20
    assert got == (20.0, tw.RAM_RESERVATION_SOURCE_INDEX_EA_MEASURED)


def test_per_ea_needs_min_samples_then_class_key():
    data = {
        "ea:QM5_1355|H4|backtest": {"n": 1, "p95_gb": 10.5, "max_gb": 10.5},
        "index|H4|backtest": {"n": 54, "p95_gb": 10.637, "max_gb": 17.86},
    }
    got = tw._index_measured_flat_reservation_gb(data, "QM5_1355", "index", "H4", "backtest", 44.0)
    # per-EA n=1 < 3 -> class key: ceil(max(17.96, 19.86)) = 20
    assert got == (20.0, tw.RAM_RESERVATION_SOURCE_INDEX_CLASS_MEASURED)


def test_class_key_needs_30_samples():
    data = {"index|M1|backtest": {"n": 5, "p95_gb": 2.0, "max_gb": 2.1}}
    assert tw._index_measured_flat_reservation_gb(data, None, "index", "M1", "backtest", 44.0) is None


def test_news_falls_back_to_backtest_key_of_same_ea():
    data = {"ea:QM5_9973|D1|backtest": {"n": 6, "p95_gb": 10.3, "max_gb": 10.301}}
    got = tw._index_measured_flat_reservation_gb(data, "QM5_9973", "index", "D1", "news", 44.0)
    assert got == (18.0, tw.RAM_RESERVATION_SOURCE_INDEX_EA_MEASURED)


def test_monster_evidence_never_raises_and_stays_near_flat():
    data = {"ea:QM5_10280|D1|backtest": {"n": 8, "p95_gb": 29.733, "max_gb": 39.516}}
    got = tw._index_measured_flat_reservation_gb(data, "QM5_10280", "index", "D1", "backtest", 44.0)
    # ceil(max(46.6, 41.5)) = 47 -> clamped to flat 44 -> not strictly lower -> None
    assert got is None
    # a 40 GB monster class max lowers only to 42
    data = {"index|D1|backtest": {"n": 204, "p95_gb": 10.334, "max_gb": 39.516}}
    got = tw._index_measured_flat_reservation_gb(data, None, "index", "D1", "backtest", 44.0)
    assert got == (42.0, tw.RAM_RESERVATION_SOURCE_INDEX_CLASS_MEASURED)


def test_minimum_clamp_12gb():
    data = {"ea:QM5_X|H1|backtest": {"n": 9, "p95_gb": 1.0, "max_gb": 1.2}}
    got = tw._index_measured_flat_reservation_gb(data, "QM5_X", "index", "H1", "backtest", 44.0)
    assert got == (tw.INDEX_MEASURED_MIN_GB, tw.RAM_RESERVATION_SOURCE_INDEX_EA_MEASURED)


def test_detail_resolver_uses_lowered_flat_for_index_rows(tmp_path, monkeypatch):
    path = tmp_path / "expectations.json"
    _write(path, {"ea:QM5_1230|D1|backtest": {"n": 11, "p95_gb": 11.495, "max_gb": 11.505}})
    monkeypatch.setenv("QM_TESTER_MEMORY_EXPECTATIONS", str(path))
    monkeypatch.delenv("QM_TESTER_MEMORY_ADMISSION", raising=False)
    monkeypatch.delenv("QM_INDEX_EA_MEASURED_LOWERS", raising=False)
    _reset_cache()
    item = {"id": "x", "ea_id": "QM5_1230", "symbol": "NDX.DWX", "phase": "Q08", "kind": "backtest"}
    payload = {"timeframe": "D1", "host_symbol": "NDX.DWX"}
    ram_class, gb, source = tw._ram_reservation_detail_for_candidate(item, payload, False)
    assert ram_class == tw.COMMIT_CLASS_SINGLE_INDEX_TICK
    assert gb == 20.0
    assert source == tw.RAM_RESERVATION_SOURCE_INDEX_EA_MEASURED
    # rollback env restores the 44 GB flat
    monkeypatch.setenv("QM_INDEX_EA_MEASURED_LOWERS", "0")
    _reset_cache()
    _, gb_off, source_off = tw._ram_reservation_detail_for_candidate(item, payload, False)
    assert gb_off == 44.0 and source_off in (
        tw.RAM_RESERVATION_SOURCE_FLAT,
        tw.RAM_RESERVATION_SOURCE_INDEX_TABLE,
    )


def test_non_index_rows_unchanged(tmp_path, monkeypatch):
    path = tmp_path / "expectations.json"
    _write(path, {"ea:QM5_10148|D1|backtest": {"n": 9, "p95_gb": 1.0, "max_gb": 1.2}})
    monkeypatch.setenv("QM_TESTER_MEMORY_EXPECTATIONS", str(path))
    _reset_cache()
    item = {"id": "y", "ea_id": "QM5_10148", "symbol": "EURNZD.DWX", "phase": "Q04", "kind": "backtest"}
    payload = {"timeframe": "D1", "host_symbol": "EURNZD.DWX"}
    ram_class, gb, source = tw._ram_reservation_detail_for_candidate(item, payload, False)
    assert ram_class != tw.COMMIT_CLASS_SINGLE_INDEX_TICK
    assert gb >= 8.0
    assert source not in (
        tw.RAM_RESERVATION_SOURCE_INDEX_EA_MEASURED,
        tw.RAM_RESERVATION_SOURCE_INDEX_CLASS_MEASURED,
    )


def test_sp500_class_key_excluded_but_per_ea_allowed():
    data = {
        "index|H1|backtest": {"n": 127, "p95_gb": 10.616, "max_gb": 10.735},
        "ea:QM5_1098|H1|backtest": {"n": 4, "p95_gb": 10.5, "max_gb": 10.6},
    }
    assert tw._index_measured_flat_reservation_gb(data, "QM5_10309", "index", "H1", "backtest", 44.0, host_base="SP500") is None
    assert tw._index_measured_flat_reservation_gb(data, "QM5_10309", "index", "H1", "backtest", 44.0, host_base="NDX") == (
        18.0, tw.RAM_RESERVATION_SOURCE_INDEX_CLASS_MEASURED)
    assert tw._index_measured_flat_reservation_gb(data, "QM5_1098", "index", "H1", "backtest", 44.0, host_base="SP500") == (
        18.0, tw.RAM_RESERVATION_SOURCE_INDEX_EA_MEASURED)


def test_admission_floor_lowered_only_for_measured_index_rows(monkeypatch):
    monkeypatch.delenv("QM_INDEX_EA_MEASURED_LOWERS", raising=False)
    monkeypatch.delenv("QM_INDEX_TICK_RESERVATION_TABLE", raising=False)
    idx = tw.COMMIT_CLASS_SINGLE_INDEX_TICK
    assert tw._index_measured_admission_floor_gb(idx, tw.RAM_RESERVATION_SOURCE_INDEX_EA_MEASURED, 14.0) == 8.0
    assert tw._index_measured_admission_floor_gb(idx, tw.RAM_RESERVATION_SOURCE_INDEX_CLASS_MEASURED, 14.0) == 8.0
    assert tw._index_measured_admission_floor_gb(idx, tw.RAM_RESERVATION_SOURCE_FLAT, 14.0) == 14.0
    assert tw._index_measured_admission_floor_gb(idx, tw.RAM_RESERVATION_SOURCE_INDEX_TABLE, 14.0) == 14.0
    assert tw._index_measured_admission_floor_gb("ordinary", tw.RAM_RESERVATION_SOURCE_INDEX_EA_MEASURED, 14.0) == 14.0
    # a floor already below 8 is never raised
    assert tw._index_measured_admission_floor_gb(idx, tw.RAM_RESERVATION_SOURCE_INDEX_EA_MEASURED, 4.0) == 4.0
    monkeypatch.setenv("QM_INDEX_EA_MEASURED_LOWERS", "0")
    assert tw._index_measured_admission_floor_gb(idx, tw.RAM_RESERVATION_SOURCE_INDEX_EA_MEASURED, 14.0) == 14.0
