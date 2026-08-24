from __future__ import annotations

import csv
import hashlib
import json
from pathlib import Path

import numpy as np
import pytest

from tools.strategy_farm.portfolio import shadow_booklab as lab
from tools.strategy_farm import shadow_null_factory as nf


def _sha(path: Path) -> str:
    return hashlib.sha256(path.read_bytes()).hexdigest()


def _write_package(root: Path) -> Path:
    daily = root / "daily"
    daily.mkdir(parents=True)
    rng = np.random.default_rng(44)
    base = rng.normal(0.2, 3.0, size=180)
    series = {
        "QM5_900001_EURUSD_1": base,
        "QM5_900002_GBPUSD_2": base * 0.85 + rng.normal(0, 0.5, size=180),
        "QM5_900003_XAUUSD_3": rng.normal(0.1, 1.2, size=180),
    }
    output_hashes: dict[str, str] = {}
    lineage_rows = []
    for index, (sleeve, values) in enumerate(series.items(), start=1):
        path = daily / f"{sleeve}_daily_returns.csv"
        with path.open("w", encoding="utf-8", newline="") as handle:
            writer = csv.writer(handle)
            writer.writerow(["date", "daily_return_eur_at_RISK_FIXED_1000"])
            for day, value in enumerate(values):
                writer.writerow([f"2025-{day // 28 + 1:02d}-{day % 28 + 1:02d}", f"{value:.10f}"])
        relative = f"daily/{path.name}"
        output_hashes[relative] = _sha(path)
        ea = sleeve.split("_", 2)[0] + "_" + sleeve.split("_", 2)[1]
        symbol = sleeve.split("_")[2] + ".DWX"
        lineage_rows.append({
            "sleeve": sleeve, "ea_id": ea, "host_symbol": symbol,
            "timeframe": "H1", "magic": str(index), "status": "EXTRACTED",
            "source_phase": "Q10", "work_item_id": f"wi-{index}",
            "work_item_verdict": "PASS", "daily_csv": str(path.resolve()),
            "daily_csv_sha256": _sha(path), "reason": "fixture",
        })
    excluded = "QM5_900004_NDX_4"
    excluded_path = daily / f"{excluded}_daily_returns.csv"
    excluded_path.write_text("date,daily_return_eur_at_RISK_FIXED_1000\n", encoding="utf-8")
    output_hashes[f"daily/{excluded_path.name}"] = _sha(excluded_path)
    lineage_rows.append({
        "sleeve": excluded, "ea_id": "QM5_900004", "host_symbol": "NDX.DWX",
        "timeframe": "H1", "magic": "4", "status": "NOT_EXTRACTABLE",
        "source_phase": "Q10", "work_item_id": "wi-4",
        "work_item_verdict": "FAIL", "daily_csv": str(excluded_path.resolve()),
        "daily_csv_sha256": _sha(excluded_path), "reason": "no PASS evidence",
    })
    lineage = root / "lineage.csv"
    with lineage.open("w", encoding="utf-8", newline="") as handle:
        writer = csv.DictWriter(handle, fieldnames=list(lineage_rows[0]))
        writer.writeheader()
        writer.writerows(lineage_rows)
    summary = root / "summary.csv"
    summary.write_text("sleeve,n_days\n", encoding="utf-8")
    output_hashes["lineage.csv"] = _sha(lineage)
    output_hashes["summary.csv"] = _sha(summary)
    verification = {
        "schema": lab.PACKAGE_SCHEMA,
        "status": "PASS_WITH_EXPECTED_NOT_EXTRACTABLE",
        "checks": {
            "manifest_declared_and_actual_sleeves": 4,
            "extracted_sleeves": 3,
        },
        "output_sha256": output_hashes,
    }
    (root / "verification.json").write_text(json.dumps(verification), encoding="utf-8")
    return root


def _config() -> lab.LabConfig:
    return lab.LabConfig(
        train_fraction=0.6,
        bootstrap_runs=199,
        bootstrap_block_days=10,
        bootstrap_seed=55,
        bootstrap_batch_size=23,
    )


def test_package_keeps_exclusion_visible_and_analysis_is_shadow_only(tmp_path: Path) -> None:
    package = lab.load_package(_write_package(tmp_path / "package"))

    report = lab.analyze_package(package, _config())

    assert report["status"] == "DATA_READY_WITH_GAPS"
    assert report["source"]["declared_sleeves"] == 4
    assert report["source"]["analyzed_sleeves"] == 3
    assert report["source"]["exclusions"][0]["sleeve"] == "QM5_900004_NDX_4"
    assert report["gate_eligible"] is False
    assert report["book_manifest_emitted"] is False
    assert report["deployment_action"] == "NONE"
    assert report["autotrading_action"] == "NONE"
    assert report["holdout_joint_bootstrap"]["sleeves_bootstrapped_independently"] is False


def test_correlated_pair_is_visible_in_stress_diagnostics(tmp_path: Path) -> None:
    report = lab.analyze_package(
        lab.load_package(_write_package(tmp_path / "package")), _config()
    )

    pair = next(
        row for row in report["correlation"]["worst_15_stress_pairs"]
        if {row["left"], row["right"]}
        == {"QM5_900001_EURUSD_1", "QM5_900002_GBPUSD_2"}
    )
    assert pair["correlation"]["all_days"] > 0.9


def test_consumed_daily_hash_mismatch_refuses(tmp_path: Path) -> None:
    root = _write_package(tmp_path / "package")
    target = root / "daily" / "QM5_900001_EURUSD_1_daily_returns.csv"
    target.write_text(target.read_text(encoding="utf-8") + "\n", encoding="utf-8")

    with pytest.raises(lab.ShadowBookLabError, match="SHA-256 mismatch"):
        lab.load_package(root)


def test_null_adapter_keeps_the_package_exclusion_context(tmp_path: Path) -> None:
    panel = nf.panel_from_booklab_package(_write_package(tmp_path / "package"))

    assert panel.returns.shape == (180, 3)
    assert panel.source_context["declared_sleeves"] == 4
    assert panel.source_context["excluded_sleeves"] == 1
    assert "incumbent roster" in panel.source_context["selection_warning"]
