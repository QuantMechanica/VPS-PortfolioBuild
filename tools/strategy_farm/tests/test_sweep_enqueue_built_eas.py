from __future__ import annotations

import csv
import json
import os
import sqlite3
import subprocess
import sys
from pathlib import Path

from tools.strategy_farm import farmctl


REPO = Path(__file__).resolve().parents[3]
SWEEP = REPO / "tools" / "strategy_farm" / "sweep_enqueue_built_eas.py"


def test_never_tested_sweep_enqueues_one_logical_basket_item(
    tmp_path: Path,
) -> None:
    farm_root = tmp_path / "farm"
    repo_root = tmp_path / "repo"
    report_root = tmp_path / "reports"
    ea_id = "QM5_9001"
    ea_dir = repo_root / "framework" / "EAs" / f"{ea_id}_fxpair"
    sets_dir = ea_dir / "sets"
    registry = repo_root / "framework" / "registry" / "ea_id_registry.csv"
    sets_dir.mkdir(parents=True)
    registry.parent.mkdir(parents=True)
    report_root.joinpath("state").mkdir(parents=True)

    (ea_dir / f"{ea_dir.name}.ex5").write_text("compiled\n", encoding="utf-8")
    logical_symbol = "QM5_9001_GBPUSD_USDCHF_COINTEGRATION_D1"
    manifest = {
        "logical_symbol": logical_symbol,
        "host_symbol": "GBPUSD.DWX",
        "host_timeframe": "D1",
        "tester_currency": "USD",
        "tester_deposit": 100000,
        "basket_symbols": ["GBPUSD.DWX", "USDCHF.DWX"],
    }
    manifest_path = ea_dir / "basket_manifest.json"
    manifest_path.write_text(json.dumps(manifest), encoding="utf-8")
    logical_setfile = (
        sets_dir / f"{ea_dir.name}_{logical_symbol}_D1_backtest.set"
    )
    logical_setfile.write_text("; logical basket\n", encoding="utf-8")
    physical_setfile = (
        sets_dir / f"{ea_dir.name}_GBPUSD.DWX_D1_backtest.set"
    )
    physical_setfile.write_text("; legacy physical host\n", encoding="utf-8")

    with registry.open("w", encoding="utf-8", newline="") as handle:
        writer = csv.DictWriter(
            handle,
            fieldnames=["ea_id", "slug", "status"],
        )
        writer.writeheader()
        writer.writerow({"ea_id": "9001", "slug": "fxpair", "status": "active"})

    farmctl.init_db(farm_root)
    env = os.environ.copy()
    env.update({
        "QM_STRATEGY_FARM_ROOT": str(farm_root),
        "QM_CANONICAL_REPO_ROOT": str(repo_root),
        "QM_REPORT_ROOT": str(report_root),
    })
    result = subprocess.run(
        [sys.executable, str(SWEEP), "--apply", "--ea", ea_id],
        cwd=REPO,
        env=env,
        capture_output=True,
        text=True,
        timeout=60,
        check=False,
    )

    assert result.returncode == 0, result.stdout + result.stderr
    with sqlite3.connect(farm_root / farmctl.DB_REL) as conn:
        rows = conn.execute(
            """
            SELECT symbol, setfile_path, payload_json
            FROM work_items
            WHERE ea_id=? AND phase='Q02'
            """,
            (ea_id,),
        ).fetchall()

    assert len(rows) == 1
    symbol, setfile_path, raw_payload = rows[0]
    assert symbol == logical_symbol
    assert Path(setfile_path) == logical_setfile.resolve()
    payload = json.loads(raw_payload)
    assert payload["host_symbol"] == "GBPUSD.DWX"
    assert payload["host_timeframe"] == "D1"
    assert payload["logical_symbol"] == logical_symbol
    assert payload["portfolio_scope"] == "basket"
    assert payload["basket_manifest"] == str(manifest_path.resolve())
    assert payload["tester_currency"] == "USD"
    assert payload["priority_track"] is True

    report = json.loads(
        (report_root / "state" / "claude_sweep_enqueue_2026-06-10.json")
        .read_text(encoding="utf-8")
    )
    assert report["part1_never_tested"]["enqueued"] == [{
        "ea_id": ea_id,
        "symbol": logical_symbol,
        "setfile": logical_setfile.name,
        "priority_track": True,
    }]
    assert any(
        row.get("reason") == "basket_manifest_logical_setfile_preferred"
        and row.get("setfile") == physical_setfile.name
        for row in report["part1_never_tested"]["skipped"]
    )


def test_never_tested_sweep_prioritizes_every_first_q02_row(
    tmp_path: Path,
) -> None:
    farm_root = tmp_path / "farm"
    repo_root = tmp_path / "repo"
    report_root = tmp_path / "reports"
    ea_id = "QM5_9002"
    ea_dir = repo_root / "framework" / "EAs" / f"{ea_id}_multisym"
    sets_dir = ea_dir / "sets"
    registry = repo_root / "framework" / "registry" / "ea_id_registry.csv"
    sets_dir.mkdir(parents=True)
    registry.parent.mkdir(parents=True)
    report_root.joinpath("state").mkdir(parents=True)

    (ea_dir / f"{ea_dir.name}.ex5").write_text("compiled\n", encoding="utf-8")
    for symbol in ("EURUSD.DWX", "GBPUSD.DWX"):
        (sets_dir / f"{ea_dir.name}_{symbol}_H1_backtest.set").write_text(
            "; first Q02 cohort\n",
            encoding="utf-8",
        )

    with registry.open("w", encoding="utf-8", newline="") as handle:
        writer = csv.DictWriter(handle, fieldnames=["ea_id", "slug", "status"])
        writer.writeheader()
        writer.writerow({"ea_id": "9002", "slug": "multisym", "status": "active"})

    farmctl.init_db(farm_root)
    env = os.environ.copy()
    env.update({
        "QM_STRATEGY_FARM_ROOT": str(farm_root),
        "QM_CANONICAL_REPO_ROOT": str(repo_root),
        "QM_REPORT_ROOT": str(report_root),
    })
    result = subprocess.run(
        [sys.executable, str(SWEEP), "--apply", "--ea", ea_id],
        cwd=REPO,
        env=env,
        capture_output=True,
        text=True,
        timeout=60,
        check=False,
    )

    assert result.returncode == 0, result.stdout + result.stderr
    with sqlite3.connect(farm_root / farmctl.DB_REL) as conn:
        payloads = [
            json.loads(row[0])
            for row in conn.execute(
                "SELECT payload_json FROM work_items WHERE ea_id=? AND phase='Q02'",
                (ea_id,),
            ).fetchall()
        ]

    assert len(payloads) == 2
    assert all(payload["priority_track"] is True for payload in payloads)
