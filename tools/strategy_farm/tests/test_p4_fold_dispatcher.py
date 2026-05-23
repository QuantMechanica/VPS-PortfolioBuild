"""Tests for framework/scripts/p4_fold_dispatcher.py."""

from __future__ import annotations

import csv
import importlib.util
import json
from pathlib import Path


SCRIPT = Path(__file__).resolve().parents[3] / "framework" / "scripts" / "p4_fold_dispatcher.py"


def _load_module():
    spec = importlib.util.spec_from_file_location("p4_fold_dispatcher", SCRIPT)
    module = importlib.util.module_from_spec(spec)
    spec.loader.exec_module(module)
    return module


def _write_folds_csv(path: Path, ea_id: str = "QM5_TEST") -> None:
    path.parent.mkdir(parents=True, exist_ok=True)
    with path.open("w", encoding="utf-8", newline="") as f:
        writer = csv.DictWriter(f, fieldnames=[
            "ea_id", "fold_id", "regime", "dev_start", "dev_end", "oos_start", "oos_end",
        ])
        writer.writeheader()
        for i in range(1, 4):
            writer.writerow({
                "ea_id": ea_id, "fold_id": f"F{i}", "regime": "UNCLASSIFIED",
                "dev_start": "2017-01-01", "dev_end": f"2022-12-{20 + i:02d}",
                "oos_start": f"2023-0{i}-01", "oos_end": f"2023-0{i}-28",
            })


def test_dispatch_invokes_spawn_per_fold(tmp_path):
    mod = _load_module()
    folds_csv = tmp_path / "walk_forward_folds.csv"
    _write_folds_csv(folds_csv)
    spawned = []

    def fake_spawn(**kwargs):
        spawned.append(kwargs["fold"]["fold_id"])
        return {
            "fold_id": kwargs["fold"]["fold_id"],
            "oos_start": kwargs["fold"]["oos_start"],
            "oos_end": kwargs["fold"]["oos_end"],
            "regime": "UNCLASSIFIED",
            "summary_path": str(tmp_path / f"summary_{kwargs['fold']['fold_id']}.json"),
            "exit_code": "0", "log_path": "",
        }

    manifest = mod.dispatch_folds(
        ea_id="QM5_TEST", symbol="EURUSD.DWX", period="H1",
        setfile=tmp_path / "x.set", folds_csv=folds_csv,
        out_prefix=tmp_path / "out", terminal="T1",
        timeout_seconds=60, spawn_fn=fake_spawn,
    )
    assert spawned == ["F1", "F2", "F3"]
    assert manifest["fold_count"] == 3


def test_manifest_written(tmp_path):
    mod = _load_module()
    folds_csv = tmp_path / "walk_forward_folds.csv"
    _write_folds_csv(folds_csv)

    def fake_spawn(**kwargs):
        return {
            "fold_id": kwargs["fold"]["fold_id"],
            "oos_start": kwargs["fold"]["oos_start"],
            "oos_end": kwargs["fold"]["oos_end"],
            "regime": "UNCLASSIFIED",
            "summary_path": "/tmp/x.json", "exit_code": "0", "log_path": "",
        }

    mod.dispatch_folds(
        ea_id="QM5_TEST", symbol="EURUSD.DWX", period="H1",
        setfile=tmp_path / "x.set", folds_csv=folds_csv,
        out_prefix=tmp_path / "out", terminal="T1",
        timeout_seconds=60, spawn_fn=fake_spawn,
    )
    manifest_path = tmp_path / "out" / "QM5_TEST" / "P4" / "fold_dispatch_manifest.json"
    assert manifest_path.exists()
    manifest = json.loads(manifest_path.read_text(encoding="utf-8"))
    assert manifest["ea_id"] == "QM5_TEST"
    assert manifest["fold_count"] == 3
    assert len(manifest["fold_results"]) == 3


def test_fold_results_carry_window_metadata(tmp_path):
    mod = _load_module()
    folds_csv = tmp_path / "walk_forward_folds.csv"
    _write_folds_csv(folds_csv)

    def fake_spawn(**kwargs):
        return {
            "fold_id": kwargs["fold"]["fold_id"],
            "oos_start": kwargs["fold"]["oos_start"],
            "oos_end": kwargs["fold"]["oos_end"],
            "regime": "UNCLASSIFIED",
            "summary_path": "/tmp/x.json", "exit_code": "0", "log_path": "",
        }

    manifest = mod.dispatch_folds(
        ea_id="QM5_TEST", symbol="EURUSD.DWX", period="H1",
        setfile=tmp_path / "x.set", folds_csv=folds_csv,
        out_prefix=tmp_path / "out", terminal="T1",
        timeout_seconds=60, spawn_fn=fake_spawn,
    )
    for fr in manifest["fold_results"]:
        assert fr["oos_start"]
        assert fr["oos_end"]
        assert fr["regime"] == "UNCLASSIFIED"
