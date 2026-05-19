"""Tests for framework/scripts/p4_fold_generator.py."""

from __future__ import annotations

import csv
import importlib.util
import subprocess
import sys
import tempfile
from datetime import date
from pathlib import Path

import pytest


SCRIPT = Path(__file__).resolve().parents[3] / "framework" / "scripts" / "p4_fold_generator.py"


def _load_module():
    spec = importlib.util.spec_from_file_location("p4_fold_generator", SCRIPT)
    module = importlib.util.module_from_spec(spec)
    spec.loader.exec_module(module)
    return module


def test_six_anchored_folds_produced():
    mod = _load_module()
    folds = mod.generate_folds(
        ea_id="QM5_1056", train_from_year=2017,
        oos_from_year=2023, oos_to_year=2025,
        fold_months=6, embargo_days=7, min_folds=6,
    )
    assert len(folds) == 6
    assert [f["fold_id"] for f in folds] == ["F1", "F2", "F3", "F4", "F5", "F6"]


def test_anchored_train_start():
    mod = _load_module()
    folds = mod.generate_folds(
        ea_id="QM5_1056", train_from_year=2017,
        oos_from_year=2023, oos_to_year=2025,
        fold_months=6, embargo_days=7, min_folds=6,
    )
    for f in folds:
        assert f["dev_start"] == "2017-01-01"


def test_embargo_respected():
    mod = _load_module()
    folds = mod.generate_folds(
        ea_id="QM5_1056", train_from_year=2017,
        oos_from_year=2023, oos_to_year=2025,
        fold_months=6, embargo_days=7, min_folds=6,
    )
    for f in folds:
        dev_end = date.fromisoformat(f["dev_end"])
        oos_start = date.fromisoformat(f["oos_start"])
        assert (oos_start - dev_end).days >= 7


def test_csv_columns_exact(tmp_path):
    out_prefix = tmp_path / "pipeline"
    proc = subprocess.run(
        [sys.executable, str(SCRIPT), "--ea", "QM5_TEST",
         "--out-prefix", str(out_prefix),
         "--train-from-year", "2017",
         "--oos-from-year", "2023", "--oos-to-year", "2025",
         "--fold-months", "6", "--embargo-days", "7", "--min-folds", "6"],
        capture_output=True, text=True, check=True,
    )
    csv_path = Path(proc.stdout.strip())
    assert csv_path.exists()
    with csv_path.open() as f:
        rows = list(csv.DictReader(f))
    assert len(rows) == 6
    assert list(rows[0].keys()) == [
        "ea_id", "fold_id", "regime", "dev_start", "dev_end", "oos_start", "oos_end"
    ]
    assert rows[0]["ea_id"] == "QM5_TEST"
    assert rows[0]["regime"] == "UNCLASSIFIED"


def test_raises_when_min_folds_unreachable():
    mod = _load_module()
    with pytest.raises(ValueError, match="only .* folds produced"):
        mod.generate_folds(
            ea_id="QM5_1056", train_from_year=2017,
            oos_from_year=2025, oos_to_year=2025,
            fold_months=12, embargo_days=7, min_folds=6,
        )
