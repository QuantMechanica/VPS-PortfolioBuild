"""Exact, fail-closed installer for the OWNER's M13 FTMO Free-Trial terminal.

This stages binaries and presets only.  It never starts MT5, edits a chart,
changes AutoTrading, or writes T_Live/T1-T10.
"""
from __future__ import annotations

import argparse
import configparser
import hashlib
import json
import os
from pathlib import Path
import shutil
import sqlite3
import sys

if __package__ in {None, ""}:
    sys.path.insert(0, str(Path(__file__).resolve().parents[3]))
from tools.strategy_farm.ftmo import trial_setpath

TASK_ID = "35eac0e9-8568-4114-b68f-45258ad7189b"
TARGET = Path(r"C:\Users\Administrator\AppData\Roaming\MetaQuotes\Terminal\81A933A9AFC5DE3C23B15CAB19C63850")
PROGRAM = Path(r"C:\Program Files\FTMO Global Markets MT5 Terminal")
DATABASE = Path(r"D:\QM\strategy_farm\state\farm_state.sqlite")
EVIDENCE = Path(r"C:\QM\repo\docs\ops\evidence\2026-09-06_ftmo_demo_install")
SETS = EVIDENCE / "sets"
COLLECTOR_BINARY = EVIDENCE / "compile_probe" / "MQL5" / "QM_FTMO_TrialTelemetry.ex5"
COLLECTOR_PRESET = EVIDENCE / "collector" / "QM_FTMO_TrialTelemetry_1514536732.set"
RECEIPT = EVIDENCE / "install_receipt.json"
EXPECTED_LOGIN = "1514536732"
EXPECTED_SERVER = "FTMO-Demo"
EXPECTED_COLLECTOR_SHA = "411638a1ae177326070c19b28c849fda36594592279303ce7d96f36bfa458258"


class Refusal(RuntimeError):
    pass


def sha(path: Path) -> str:
    return hashlib.sha256(path.read_bytes()).hexdigest()


def require_task() -> None:
    with sqlite3.connect(DATABASE.resolve().as_uri() + "?mode=ro", uri=True) as db:
        row = db.execute(
            "SELECT assigned_agent,state FROM agent_tasks WHERE id=?", (TASK_ID,)
        ).fetchone()
    if row != ("codex", "IN_PROGRESS"):
        raise Refusal(f"live_task_authority_missing:{row}")


def require_target() -> dict:
    target = TARGET.resolve()
    if target != TARGET.absolute() or TARGET.is_symlink() or not target.is_dir():
        raise Refusal("target_missing_or_redirected")
    forbidden = [Path(r"C:\QM\mt5\T_Live")] + [Path(f"D:/QM/mt5/T{i}") for i in range(1, 11)]
    if any(target == path.resolve() for path in forbidden):
        raise Refusal("forbidden_terminal_target")
    origin = (target / "origin.txt").read_text(encoding="utf-16", errors="ignore").strip("\ufeff\0\r\n ")
    if Path(origin).resolve() != PROGRAM.resolve():
        raise Refusal(f"origin_mismatch:{origin}")
    parser = configparser.ConfigParser()
    parser.read(target / "config" / "common.ini", encoding="utf-16")
    if parser.get("Common", "Login", fallback="") != EXPECTED_LOGIN:
        raise Refusal("login_mismatch")
    if parser.get("Common", "Server", fallback="") != EXPECTED_SERVER:
        raise Refusal("server_mismatch")
    if parser.get("Experts", "Enabled", fallback="1") != "0":
        raise Refusal("autotrading_must_be_disabled")
    return {"origin": origin, "login": EXPECTED_LOGIN, "server": EXPECTED_SERVER, "autotrading": False}


def inventory(root: Path) -> list[dict]:
    candidates = list((root / "MQL5" / "Experts" / "QM_FTMO").glob("*.ex5"))
    candidates += list((root / "MQL5" / "Experts").glob("QM_AccountMonitor.*"))
    return [
        {"path": str(path), "sha256": sha(path), "bytes": path.stat().st_size}
        for path in sorted(candidates)
        if path.is_file()
    ]


def atomic_copy(source: Path, destination: Path) -> dict:
    destination.parent.mkdir(parents=True, exist_ok=True)
    tmp = destination.with_name(destination.name + f".m13-{os.getpid()}.tmp")
    if tmp.exists():
        raise Refusal(f"temporary_destination_exists:{tmp}")
    shutil.copy2(source, tmp)
    if sha(tmp) != sha(source):
        tmp.unlink(missing_ok=True)
        raise Refusal(f"copy_hash_mismatch:{destination}")
    os.replace(tmp, destination)
    return {"source": str(source), "destination": str(destination), "sha256": sha(destination)}


def validate_sources() -> tuple[dict, list[tuple[Path, Path]]]:
    manifest = json.loads((SETS / "manifest.json").read_text(encoding="utf-8"))
    if manifest.get("schema") != "qm.ftmo-trial-setpath/v2" or manifest.get("account_variant") != "STANDARD_2STEP_100K_FREE_TRIAL":
        raise Refusal("wrong_set_manifest")
    if manifest.get("risk_percent") != 0.3125 or len(manifest.get("candidates", [])) != 8:
        raise Refusal("wrong_risk_or_candidate_count")
    planned: list[tuple[Path, Path]] = []
    expert_dir = TARGET / "MQL5" / "Experts" / "QM_FTMO"
    preset_dir = TARGET / "MQL5" / "Profiles" / "Presets" / "QM_FTMO_M13"
    for row in manifest["candidates"]:
        preset = SETS / row["output_path"]
        if sha(preset) != row["output_sha256"]:
            raise Refusal(f"preset_hash_mismatch:{preset.name}")
        values = trial_setpath.values(trial_setpath.decode(preset.read_bytes()))
        required = {
            "RISK_FIXED": "0", "RISK_PERCENT": "0.3125",
            "qm_news_temporal": "3", "qm_news_compliance": "2",
            "qm_news_stale_max_hours": "336",
            "qm_friday_close_enabled": "true", "qm_friday_close_hour_broker": "21",
        }
        if any(values.get(key) != value for key, value in required.items()):
            raise Refusal(f"preset_contract_mismatch:{preset.name}")
        ea_dir = Path(row["source_path"]).parents[1]
        binaries = list(ea_dir.glob(f"QM5_{row['ea_id']}_*.ex5"))
        if len(binaries) != 1 or sha(binaries[0]) != row["ex5_sha256"]:
            raise Refusal(f"sealed_binary_mismatch:{row['ea_id']}")
        planned.append((binaries[0], expert_dir / binaries[0].name))
        planned.append((preset, preset_dir / preset.name))
    if sha(COLLECTOR_BINARY) != EXPECTED_COLLECTOR_SHA:
        raise Refusal("collector_binary_hash_mismatch")
    collector_values = trial_setpath.values(COLLECTOR_PRESET.read_text(encoding="utf-8"))
    if collector_values != {
        "InpTimerSeconds": "1",
        "InpOutputDir": r"QM\ftmo_trial\2026-09-06",
        "InpExpectedLogin": EXPECTED_LOGIN,
        "InpExpectedServer": EXPECTED_SERVER,
        "InpTrialId": "M13_OPTION_B_20260906_1514536732",
    }:
        raise Refusal("collector_preset_contract_mismatch")
    planned += [
        (COLLECTOR_BINARY, expert_dir / COLLECTOR_BINARY.name),
        (COLLECTOR_PRESET, preset_dir / COLLECTOR_PRESET.name),
    ]
    return manifest, planned


def install() -> dict:
    require_task()
    identity = require_target()
    manifest, planned = validate_sources()
    before = inventory(TARGET)
    backup_dir = TARGET / "MQL5" / "Experts" / "QM_FTMO" / "_pre_m13_20260906"
    backups = []
    installed = []
    for source, destination in planned:
        if destination.exists() and sha(destination) != sha(source):
            backup = backup_dir / destination.name
            if backup.exists() and sha(backup) != sha(destination):
                raise Refusal(f"backup_collision:{backup}")
            if not backup.exists():
                backups.append(atomic_copy(destination, backup))
        installed.append(atomic_copy(source, destination))
    (TARGET / "MQL5" / "Files" / "QM" / "ftmo_trial" / "2026-09-06").mkdir(parents=True, exist_ok=True)
    Path(r"D:\QM\reports\ftmo_trial\2026-09-06").mkdir(parents=True, exist_ok=True)
    final_identity = require_target()
    receipt = {
        "schema": "qm.ftmo-demo-install/v1",
        "task_id": TASK_ID,
        "status": "INSTALLED_UNATTACHED_PARKED",
        "target": str(TARGET),
        "identity": final_identity,
        "autotrading_changed": False,
        "charts_changed": False,
        "tlive_written": False,
        "sets_manifest_sha256": sha(SETS / "manifest.json"),
        "sets_manifest_schema": manifest["schema"],
        "inventory_before": before,
        "backups": backups,
        "installed": installed,
        "inventory_after": inventory(TARGET),
        "legacy_account_monitor_decision": "KEEP_DORMANT_DISTINCT_OUTPUT_PATH_NO_HANDLE_CONFLICT",
        "legacy_attach_map_decision": "KEEP_BUT_OBSOLETE_DO_NOT_USE_FOR_M13",
    }
    RECEIPT.write_text(json.dumps(receipt, indent=2) + "\n", encoding="utf-8")
    return receipt


def main() -> int:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--execute", action="store_true", required=True)
    parser.parse_args()
    print(json.dumps(install(), indent=2))
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
