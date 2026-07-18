from __future__ import annotations

import json
import sqlite3
from pathlib import Path

from tools.strategy_farm import audit_q08_book_setfiles as audit


def _insert(con: sqlite3.Connection, row_id: str, setfile: Path, status: str) -> None:
    con.execute(
        """
        INSERT INTO work_items(
            id, phase, ea_id, symbol, setfile_path, status, verdict,
            created_at, updated_at
        ) VALUES (?, 'Q08', 'QM5_10440', 'NDX.DWX', ?, ?, NULL, ?, ?)
        """,
        (row_id, str(setfile), status, "2026-07-18T00:00:00Z", "2026-07-18T00:00:00Z"),
    )


def test_audit_distinguishes_exact_alias_and_variant(tmp_path: Path) -> None:
    canonical = tmp_path / "repo" / "EA" / "sets" / "QM5_10440_NDX.DWX_H1_backtest.set"
    canonical.parent.mkdir(parents=True)
    canonical.write_text("RISK_FIXED=1000\nRISK_PERCENT=0\n", encoding="utf-8")
    alias = tmp_path / "worktrees" / "agent" / "sets" / canonical.name
    alias.parent.mkdir(parents=True)
    alias.write_bytes(canonical.read_bytes())
    variant = canonical.with_name("QM5_10440_NDX.DWX_H1_backtest_grid_034.set")
    variant.write_text("RISK_FIXED=1000\nRISK_PERCENT=0\nstrategy_x=34\n", encoding="utf-8")

    manifest = tmp_path / "manifest.json"
    manifest.write_text(json.dumps({
        "sleeves": [{
            "ea_id": 10440,
            "symbol": "NDX.DWX",
            "backtest_set": str(canonical),
        }],
    }), encoding="utf-8")
    db = tmp_path / "farm.sqlite"
    with sqlite3.connect(db) as con:
        con.execute(
            """
            CREATE TABLE work_items(
                id TEXT, phase TEXT, ea_id TEXT, symbol TEXT, setfile_path TEXT,
                status TEXT, verdict TEXT, created_at TEXT, updated_at TEXT
            )
            """
        )
        _insert(con, "exact", canonical, "done")
        _insert(con, "alias", alias, "pending")
        _insert(con, "variant", variant, "pending")
        con.commit()

    result = audit.audit(db, manifest)

    assert result["manifest_sleeves"] == 1
    assert result["covered_sleeves"] == 1
    assert result["classification_counts"] == {
        "CONTENT_ALIAS": 1,
        "EXACT": 1,
        "VARIANT_MISMATCH": 1,
    }
    assert result["open_mismatch_count"] == 1
    assert result["open_mismatches"][0]["id"] == "variant"
    assert "VARIANT_MISMATCH" in audit.render_csv(result)


def test_manifest_rejects_duplicate_book_key(tmp_path: Path) -> None:
    manifest = tmp_path / "manifest.json"
    sleeve = {"ea_id": 11165, "symbol": "AUDCAD.DWX", "backtest_set": "a.set"}
    manifest.write_text(json.dumps({"sleeves": [sleeve, sleeve]}), encoding="utf-8")

    try:
        audit.load_manifest(manifest)
    except ValueError as exc:
        assert "duplicate manifest sleeve" in str(exc)
    else:
        raise AssertionError("duplicate manifest sleeve was accepted")
