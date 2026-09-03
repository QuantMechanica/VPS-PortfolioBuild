"""Measured-RAM admission override (2026-09-03, CEO).

The pure reservation resolver, the measured-expectation lookup (with/without a
compiled file, min-sample floor, env rollback), and the aggregation.  No gate,
verdict, or threshold-constant change: heavy single-symbol runs reserve their
measured peak; everything else keeps today's flat commit class.
"""
import json
import sys
from pathlib import Path

sys.path.insert(0, str(Path(__file__).resolve().parents[1]))

import terminal_worker  # noqa: E402


def _reset_expectations_cache():
    terminal_worker._TESTER_MEMORY_EXPECTATIONS_CACHE.update(
        {"path": None, "mtime": None, "data": {}, "at": -1e9}
    )


def _write_expectations(path, keys):
    path.parent.mkdir(parents=True, exist_ok=True)
    path.write_text(
        json.dumps({"schema": "qm.tester_memory_expectations/v1", "keys": keys}),
        encoding="utf-8",
    )


# ---- resolver (pure) ----------------------------------------------------

def test_resolver_no_measurement_keeps_flat():
    assert terminal_worker._resolve_ram_reservation_gb(
        "ordinary", 8.0, None, multisymbol=False
    ) == 8.0


def test_resolver_small_run_keeps_flat():
    # measured <= TESTER_MEMORY_HEAVY_GB (10) -> today's rule exactly
    assert terminal_worker._resolve_ram_reservation_gb(
        "ordinary", 8.0, 9.0, multisymbol=False
    ) == 8.0
    assert terminal_worker._resolve_ram_reservation_gb(
        "ordinary", 8.0, 10.0, multisymbol=False
    ) == 8.0


def test_resolver_heavy_run_takes_max_flat_measured():
    # measured > 10 -> reserve the measured peak
    assert terminal_worker._resolve_ram_reservation_gb(
        "ordinary", 8.0, 18.0, multisymbol=False
    ) == 18.0
    # never lowers a class below its flat default
    assert terminal_worker._resolve_ram_reservation_gb(
        terminal_worker.COMMIT_CLASS_SINGLE_INDEX_TICK, 44.0, 12.0, multisymbol=False
    ) == 44.0


def test_resolver_multisymbol_keeps_flat_regardless():
    assert terminal_worker._resolve_ram_reservation_gb(
        "ordinary", 8.0, 30.0, multisymbol=True
    ) == 8.0


def test_resolver_census_class_keeps_flat():
    assert terminal_worker._resolve_ram_reservation_gb(
        terminal_worker.RAM_CLASS_OPT_CENSUS_CELL, 4.0, 30.0, multisymbol=False
    ) == 4.0


# ---- lookup -------------------------------------------------------------

def test_lookup_none_without_file(tmp_path, monkeypatch):
    _reset_expectations_cache()
    monkeypatch.delenv("QM_TESTER_MEMORY_ADMISSION", raising=False)
    monkeypatch.setenv(
        "QM_TESTER_MEMORY_EXPECTATIONS", str(tmp_path / "missing.json")
    )
    assert terminal_worker._measured_ram_expectation_gb(
        "fx_cross", "H4", "backtest"
    ) is None


def test_lookup_returns_max_gb_for_matching_key(tmp_path, monkeypatch):
    _reset_expectations_cache()
    monkeypatch.delenv("QM_TESTER_MEMORY_ADMISSION", raising=False)
    path = tmp_path / "exp.json"
    _write_expectations(path, {"fx_cross|H4|backtest": {"n": 3, "max_gb": 23.0, "p95_gb": 22.0}})
    monkeypatch.setenv("QM_TESTER_MEMORY_EXPECTATIONS", str(path))
    assert terminal_worker._measured_ram_expectation_gb(
        "fx_cross", "H4", "backtest"
    ) == 23.0


def test_lookup_none_for_undersampled_key(tmp_path, monkeypatch):
    _reset_expectations_cache()
    monkeypatch.delenv("QM_TESTER_MEMORY_ADMISSION", raising=False)
    path = tmp_path / "exp.json"
    _write_expectations(path, {"fx_cross|H4|backtest": {"n": 2, "max_gb": 23.0, "p95_gb": 22.0}})
    monkeypatch.setenv("QM_TESTER_MEMORY_EXPECTATIONS", str(path))
    assert terminal_worker._measured_ram_expectation_gb(
        "fx_cross", "H4", "backtest"
    ) is None


def test_lookup_none_when_admission_disabled_even_with_file(tmp_path, monkeypatch):
    _reset_expectations_cache()
    path = tmp_path / "exp.json"
    _write_expectations(path, {"fx_cross|H4|backtest": {"n": 9, "max_gb": 23.0, "p95_gb": 22.0}})
    monkeypatch.setenv("QM_TESTER_MEMORY_EXPECTATIONS", str(path))
    monkeypatch.setenv("QM_TESTER_MEMORY_ADMISSION", "0")
    assert terminal_worker._measured_ram_expectation_gb(
        "fx_cross", "H4", "backtest"
    ) is None


# ---- aggregation --------------------------------------------------------

def test_compile_expectations_pure_aggregation():
    rows = [
        {"lookup_key": "fx_cross|H4|backtest", "peak_subtree_working_set_gb": 10.0},
        {"lookup_key": "fx_cross|H4|backtest", "peak_subtree_working_set_gb": 23.0},
        {"lookup_key": "fx_cross|H4|backtest", "peak_subtree_working_set_gb": 20.0},
        {"lookup_key": "fx_major|D1|smoke", "peak_subtree_working_set_gb": 4.0},
        {"peak_subtree_working_set_gb": 99.0},          # no key -> ignored
        {"lookup_key": "x|y|z", "peak_subtree_working_set_gb": "bad"},  # unparseable -> ignored
    ]
    out = terminal_worker._compile_tester_memory_expectations(rows)
    assert set(out) == {"fx_cross|H4|backtest", "fx_major|D1|smoke"}
    cross = out["fx_cross|H4|backtest"]
    assert cross["n"] == 3
    assert cross["max_gb"] == 23.0
    # p95 of sorted [10,20,23] via linear interpolation = 22.7
    assert cross["p95_gb"] == 22.7
    assert out["fx_major|D1|smoke"] == {"n": 1, "max_gb": 4.0, "p95_gb": 4.0}
