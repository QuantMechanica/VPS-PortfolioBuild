"""Per-EA tester-memory expectations (2026-09-05).

A per-EA key ``ea:ea_id|timeframe|run_kind`` is compiled alongside the
asset-class key and, with only n>=1, takes precedence over the class value
whenever its recorded max exceeds it — so a known memory-balloon EA
(QM5_10395/EURJPY, 27 GB) reserves its true peak on the next admission instead
of the 8 GB class average. The class key keeps its conservative min-sample
floor. Ledger stays append-only; expectations schema bumps to v2.
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
        json.dumps({"schema": "qm.tester_memory_expectations/v2", "keys": keys}),
        encoding="utf-8",
    )


# ---- key builders -------------------------------------------------------

def test_ea_lookup_key_namespaced():
    assert (
        terminal_worker._tester_memory_ea_lookup_key("QM5_10395", "H1", "backtest")
        == "ea:QM5_10395|H1|backtest"
    )


def test_ea_key_from_row_requires_all_fields():
    full = {"ea_id": "QM5_10395", "timeframe": "H1", "run_kind": "backtest",
            "peak_subtree_working_set_gb": 27.0}
    assert terminal_worker._tester_memory_ea_key_from_row(full) == "ea:QM5_10395|H1|backtest"
    # a class-only aggregation row carries no EA identity -> no per-EA key
    assert terminal_worker._tester_memory_ea_key_from_row(
        {"lookup_key": "fx_cross|H1|backtest", "peak_subtree_working_set_gb": 4.0}
    ) is None
    for missing in ({"ea_id": "", "timeframe": "H1", "run_kind": "backtest"},
                    {"ea_id": "QM5_1", "timeframe": "", "run_kind": "backtest"},
                    {"ea_id": "QM5_1", "timeframe": "H1", "run_kind": ""}):
        assert terminal_worker._tester_memory_ea_key_from_row(missing) is None


# ---- aggregation emits both families ------------------------------------

def test_compile_emits_class_and_per_ea_keys():
    rows = [
        {"lookup_key": "fx_cross|H1|backtest", "ea_id": "QM5_10395",
         "timeframe": "H1", "run_kind": "backtest",
         "peak_subtree_working_set_gb": 4.0},
        {"lookup_key": "fx_cross|H1|backtest", "ea_id": "QM5_10395",
         "timeframe": "H1", "run_kind": "backtest",
         "peak_subtree_working_set_gb": 27.0},
    ]
    out = terminal_worker._compile_tester_memory_expectations(rows)
    assert out["fx_cross|H1|backtest"] == {"n": 2, "max_gb": 27.0, "p95_gb": 25.85}
    assert out["ea:QM5_10395|H1|backtest"]["n"] == 2
    assert out["ea:QM5_10395|H1|backtest"]["max_gb"] == 27.0


def test_compile_backward_compatible_with_class_only_rows():
    # The v1 pure-aggregation shape (no EA identity) must be byte-for-byte the
    # same set of keys as before.
    rows = [
        {"lookup_key": "fx_cross|H4|backtest", "peak_subtree_working_set_gb": 10.0},
        {"lookup_key": "fx_major|D1|smoke", "peak_subtree_working_set_gb": 4.0},
        {"peak_subtree_working_set_gb": 99.0},           # no key -> ignored
        {"lookup_key": "x|y|z", "peak_subtree_working_set_gb": "bad"},  # unparseable
    ]
    out = terminal_worker._compile_tester_memory_expectations(rows)
    assert set(out) == {"fx_cross|H4|backtest", "fx_major|D1|smoke"}


# ---- precedence ---------------------------------------------------------

def test_per_ea_wins_when_it_exceeds_class(tmp_path, monkeypatch):
    _reset_expectations_cache()
    monkeypatch.delenv("QM_TESTER_MEMORY_ADMISSION", raising=False)
    path = tmp_path / "exp.json"
    _write_expectations(path, {
        "fx_cross|H1|backtest": {"n": 33, "max_gb": 4.4, "p95_gb": 4.3},
        "ea:QM5_10395|H1|backtest": {"n": 1, "max_gb": 27.0, "p95_gb": 27.0},
    })
    monkeypatch.setenv("QM_TESTER_MEMORY_EXPECTATIONS", str(path))
    # per-EA (n=1) overrides the well-sampled class value
    assert terminal_worker._measured_ram_expectation_gb(
        "fx_cross", "H1", "backtest", ea_id="QM5_10395"
    ) == 27.0
    # a DIFFERENT EA on the same class stays on the class value
    assert terminal_worker._measured_ram_expectation_gb(
        "fx_cross", "H1", "backtest", ea_id="QM5_99999"
    ) == 4.4
    # no ea_id -> class value
    assert terminal_worker._measured_ram_expectation_gb(
        "fx_cross", "H1", "backtest"
    ) == 4.4


def test_per_ea_ignored_when_not_exceeding_class(tmp_path, monkeypatch):
    _reset_expectations_cache()
    monkeypatch.delenv("QM_TESTER_MEMORY_ADMISSION", raising=False)
    path = tmp_path / "exp.json"
    _write_expectations(path, {
        "fx_cross|H1|backtest": {"n": 5, "max_gb": 18.0, "p95_gb": 17.0},
        "ea:QM5_10395|H1|backtest": {"n": 2, "max_gb": 12.0, "p95_gb": 12.0},
    })
    monkeypatch.setenv("QM_TESTER_MEMORY_EXPECTATIONS", str(path))
    assert terminal_worker._measured_ram_expectation_gb(
        "fx_cross", "H1", "backtest", ea_id="QM5_10395"
    ) == 18.0


def test_per_ea_used_when_class_absent(tmp_path, monkeypatch):
    _reset_expectations_cache()
    monkeypatch.delenv("QM_TESTER_MEMORY_ADMISSION", raising=False)
    path = tmp_path / "exp.json"
    _write_expectations(path, {
        "ea:QM5_10395|H1|backtest": {"n": 1, "max_gb": 27.0, "p95_gb": 27.0},
    })
    monkeypatch.setenv("QM_TESTER_MEMORY_EXPECTATIONS", str(path))
    assert terminal_worker._measured_ram_expectation_gb(
        "fx_cross", "H1", "backtest", ea_id="QM5_10395"
    ) == 27.0


def test_per_ea_disabled_by_env(tmp_path, monkeypatch):
    _reset_expectations_cache()
    path = tmp_path / "exp.json"
    _write_expectations(path, {
        "ea:QM5_10395|H1|backtest": {"n": 9, "max_gb": 27.0, "p95_gb": 27.0},
    })
    monkeypatch.setenv("QM_TESTER_MEMORY_EXPECTATIONS", str(path))
    monkeypatch.setenv("QM_TESTER_MEMORY_ADMISSION", "0")
    assert terminal_worker._measured_ram_expectation_gb(
        "fx_cross", "H1", "backtest", ea_id="QM5_10395"
    ) is None


def test_resolver_applies_per_ea_peak_over_flat(tmp_path, monkeypatch):
    # End-to-end via the reservation resolver: the incident shape (ordinary
    # 8 GB class, a 27 GB per-EA peak) reserves 27 GB next time.
    _reset_expectations_cache()
    monkeypatch.delenv("QM_TESTER_MEMORY_ADMISSION", raising=False)
    path = tmp_path / "exp.json"
    _write_expectations(path, {
        "ea:QM5_10395|H4|backtest": {"n": 1, "max_gb": 27.0, "p95_gb": 27.0},
    })
    monkeypatch.setenv("QM_TESTER_MEMORY_EXPECTATIONS", str(path))
    item = {"ea_id": "QM5_10395", "symbol": "EURJPY.DWX", "phase": "Q05"}
    payload = {"host_timeframe": "H4"}
    ram_class, reservation = terminal_worker._ram_reservation_for_candidate(
        item, payload, False
    )
    assert ram_class == terminal_worker.MULTISYMBOL_COMMIT_CLASS_ORDINARY
    assert reservation == 27.0
