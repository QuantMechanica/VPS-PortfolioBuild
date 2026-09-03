from __future__ import annotations

import json
from pathlib import Path

from tools.strategy_farm.portfolio import stage_tlive_presets_risk as stage_risk


def _preset(dirpath: Path, name: str, risk: str) -> None:
    dirpath.mkdir(parents=True, exist_ok=True)
    (dirpath / name).write_text(
        f"RISK_PERCENT={risk}\nRISK_FIXED=0\n",
        encoding="utf-8",
    )


def test_dry_run_json_report_parent_dir_is_created(tmp_path: Path) -> None:
    # D5 regression: a dry-run that writes --json to a not-yet-existing directory
    # must create the parent and write the report, not crash with FileNotFoundError
    # after already printing the success report.
    presets = tmp_path / "presets"
    _preset(presets, "01_EURUSD_H1_QM5_100_fixture.set", "0.5")
    manifest = tmp_path / "manifest.json"
    manifest.write_text(
        json.dumps({"sleeves": [{"ea_id": 100, "symbol": "EURUSD.DWX", "risk_percent": 0.4}]}),
        encoding="utf-8",
    )
    json_out = tmp_path / "does" / "not" / "exist" / "report.json"
    assert not json_out.parent.exists()

    rc = stage_risk.main([
        "--presets", str(presets),
        "--manifest", str(manifest),
        "--out-dir", str(tmp_path / "staging"),
        "--json", str(json_out),
    ])

    assert rc == 0
    assert json_out.is_file()
    payload = json.loads(json_out.read_text(encoding="utf-8"))
    assert payload["mode"] == "DRY-RUN"
    assert payload["problems"] == []
    assert len(payload["staged"]) == 1
    assert payload["staged"][0]["new_risk"] == "0.4"
    # dry-run writes no staged presets
    assert not (tmp_path / "staging").exists()
