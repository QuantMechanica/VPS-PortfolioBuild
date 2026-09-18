"""Exact, fail-closed installer for the OWNER's M13 FTMO Free-Trial terminal.

This stages binaries and presets only.  It never starts MT5, edits a chart,
changes AutoTrading, or writes T_Live/T1-T10.

Two input modes:

* ``--package <dir>`` (G1): every per-cycle binding — task/decision authority,
  roster, presets, collector contract, backup and telemetry directories — is
  read from a package directory instead of module constants.  The package holds
  ``roster.json`` (``qm.ftmo-demo-roster/v1``), ``sets/manifest.json`` plus the
  derived presets, and ``authority.json`` naming the decision id and the Fable
  receipt.
* the legacy constants below, kept byte-for-byte so the 2026-09-06 install
  remains reproducible.

The fail-closed target checks (login, server, origin, AutoTrading off, forbidden
terminals), the atomic hash-verified copy, the backup-collision guard and the
receipt shape are identical in both modes.
"""
from __future__ import annotations

import argparse
import configparser
import hashlib
import json
import os
from pathlib import Path
import re
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
LEGACY_CYCLE_ID = "2026-09-06"
LEGACY_TRIAL_ID = "M13_OPTION_B_20260906_1514536732"
LEGACY_BACKUP_DIR = "_pre_m13_20260906"
TRIAL_REPORT_ROOT = Path(r"D:\QM\reports\ftmo_trial")
AUTHORITY_SCHEMA = "qm.ftmo-demo-install-authority/v1"
_CYCLE_ID_RE = re.compile(r"[A-Za-z0-9][A-Za-z0-9_.-]{0,63}")


class Refusal(RuntimeError):
    pass


def sha(path: Path) -> str:
    return hashlib.sha256(path.read_bytes()).hexdigest()


# --------------------------------------------------------------------------- #
# Package (per-cycle bindings) — replaces the hard-bound constants
# --------------------------------------------------------------------------- #
class Package:
    """Everything the installer must be told per cycle. No behaviour lives here."""

    def __init__(self, *, root, sets_dir, roster, task_id, expected_agent, decision_id,
                 receipt_in, receipt_out, cycle_id, trial_id, collector_binary,
                 collector_preset, collector_sha, expected_schema, label):
        self.root = root
        self.sets_dir = sets_dir
        self.roster = roster
        self.task_id = task_id
        self.expected_agent = expected_agent
        self.decision_id = decision_id
        self.receipt_in = receipt_in
        self.receipt_out = receipt_out
        self.cycle_id = cycle_id
        self.trial_id = trial_id
        self.collector_binary = collector_binary
        self.collector_preset = collector_preset
        self.collector_sha = collector_sha
        self.expected_schema = expected_schema
        self.label = label

    @property
    def backup_dir_name(self) -> str:
        return LEGACY_BACKUP_DIR if self.cycle_id == LEGACY_CYCLE_ID else f"_pre_{self.cycle_id}"

    @property
    def collector_output_dir(self) -> str:
        return "QM\\ftmo_trial\\" + self.cycle_id


def legacy_package() -> Package:
    """The 2026-09-06 bindings, unchanged."""
    return Package(
        root=EVIDENCE, sets_dir=SETS, roster=None, task_id=TASK_ID, expected_agent="codex",
        decision_id="LEGACY_2026-09-06_M13_OPTION_B", receipt_in=None, receipt_out=RECEIPT,
        cycle_id=LEGACY_CYCLE_ID, trial_id=LEGACY_TRIAL_ID,
        collector_binary=COLLECTOR_BINARY, collector_preset=COLLECTOR_PRESET,
        collector_sha=EXPECTED_COLLECTOR_SHA,
        expected_schema="qm.ftmo-trial-setpath/v2", label="m13_option_b_20260906",
    )


def load_package(package_dir: Path) -> Package:
    root = Path(package_dir).resolve()
    if not root.is_dir():
        raise Refusal(f"package_dir_missing:{package_dir}")
    authority_path = root / "authority.json"
    if not authority_path.is_file():
        raise Refusal("package_authority_missing")
    authority = json.loads(authority_path.read_text(encoding="utf-8"))
    if authority.get("schema") != AUTHORITY_SCHEMA:
        raise Refusal("package_authority_schema_invalid")
    decision_id = authority.get("decision_id")
    if not isinstance(decision_id, str) or not decision_id.strip():
        raise Refusal("package_authority_decision_id_missing")
    receipt_in = Path(authority["receipt_path"]) if authority.get("receipt_path") else None
    if receipt_in is None or not receipt_in.is_file():
        raise Refusal(f"package_authority_receipt_missing:{receipt_in}")
    cycle_id = authority.get("cycle_id")
    if not isinstance(cycle_id, str) or not _CYCLE_ID_RE.fullmatch(cycle_id):
        raise Refusal(f"package_cycle_id_invalid:{cycle_id}")
    collector = authority.get("collector") or {}
    for key in ("binary_path", "preset_path", "binary_sha256", "trial_id"):
        if not isinstance(collector.get(key), str) or not collector[key].strip():
            raise Refusal(f"package_collector_binding_incomplete:{key}")
    roster_path = root / "roster.json"
    if not roster_path.is_file():
        raise Refusal("package_roster_missing")
    sets_dir = root / "sets"
    if not (sets_dir / "manifest.json").is_file():
        raise Refusal("package_sets_manifest_missing")
    task_id = authority.get("task_id")
    expected_agent = authority.get("assigned_agent")
    if task_id is not None:
        if not isinstance(task_id, str) or not task_id.strip():
            raise Refusal("package_task_id_invalid")
        if not isinstance(expected_agent, str) or not expected_agent.strip():
            raise Refusal("package_assigned_agent_missing")
    return Package(
        root=root, sets_dir=sets_dir, roster=trial_setpath.load_roster(roster_path),
        task_id=task_id, expected_agent=expected_agent, decision_id=decision_id, receipt_in=receipt_in,
        receipt_out=root / "install_receipt.json", cycle_id=cycle_id,
        trial_id=collector["trial_id"],
        collector_binary=_package_file(root, collector["binary_path"]),
        collector_preset=_package_file(root, collector["preset_path"]),
        collector_sha=collector["binary_sha256"],
        expected_schema=authority.get("sets_manifest_schema", "qm.ftmo-trial-setpath/v2"),
        label=authority.get("label", cycle_id),
    )


def _package_file(root: Path, relative: str) -> Path:
    if os.path.isabs(relative) or ".." in Path(relative).parts:
        raise Refusal(f"package_path_escape:{relative}")
    target = (root / relative).resolve()
    try:
        target.relative_to(root)
    except ValueError as exc:
        raise Refusal(f"package_path_escape:{relative}") from exc
    if not target.is_file():
        raise Refusal(f"package_file_missing:{relative}")
    return target


# --------------------------------------------------------------------------- #
# Fail-closed target and source checks (unchanged semantics)
# --------------------------------------------------------------------------- #
def require_task(package: Package) -> dict:
    """Live authority. A package may carry an agent task, a decision receipt, or both."""
    if package.task_id is None:
        return {"mode": "OWNER_DECISION_RECEIPT", "decision_id": package.decision_id,
                "receipt_path": str(package.receipt_in), "receipt_sha256": sha(package.receipt_in)}
    with sqlite3.connect(DATABASE.resolve().as_uri() + "?mode=ro", uri=True) as db:
        row = db.execute(
            "SELECT assigned_agent,state FROM agent_tasks WHERE id=?", (package.task_id,)
        ).fetchone()
    if row != (package.expected_agent, "IN_PROGRESS"):
        raise Refusal(f"live_task_authority_missing:{row}")
    return {"mode": "AGENT_TASK", "task_id": package.task_id, "assigned_agent": row[0],
            "state": row[1], "decision_id": package.decision_id,
            "receipt_path": str(package.receipt_in) if package.receipt_in else None}


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


def validate_sources(package: Package, target: Path | None = None) -> tuple[dict, list[tuple[Path, Path]]]:
    # Resolved at CALL time, never bound as a default: a default argument would
    # capture the real terminal path even when TARGET is redirected, so the
    # planned destinations could point somewhere the caller never selected.
    target = TARGET if target is None else target
    manifest = json.loads((package.sets_dir / "manifest.json").read_text(encoding="utf-8"))
    if manifest.get("schema") != package.expected_schema or manifest.get("account_variant") != "STANDARD_2STEP_100K_FREE_TRIAL":
        raise Refusal("wrong_set_manifest")
    rows = manifest.get("candidates", [])
    expected_risk = _expected_risk(package, manifest)
    if package.roster is None:
        # Legacy: the 2026-09-06 constants, verbatim.
        if manifest.get("risk_percent") != 0.3125 or len(rows) != 8:
            raise Refusal("wrong_risk_or_candidate_count")
    else:
        roster_rows = package.roster["candidates"]
        if len(rows) != len(roster_rows):
            raise Refusal(f"roster_manifest_candidate_count_mismatch:{len(rows)}!={len(roster_rows)}")
        by_magic = {row["magic"]: row for row in roster_rows}
        for row in rows:
            magic = int(row["ea_id"]) * 10000 + int(row.get("qm_magic_slot_offset") or row.get("slot") or 0)
            expected_row = by_magic.get(magic)
            if expected_row is None:
                raise Refusal(f"manifest_candidate_not_in_roster:{magic}")
            venue = row.get("native_symbol") or row.get("venue_symbol")
            if venue != expected_row["ftmo_symbol"] or row.get("timeframe") != expected_row["timeframe"]:
                raise Refusal(f"roster_manifest_binding_mismatch:{magic}")
    planned: list[tuple[Path, Path]] = []
    expert_dir = target / "MQL5" / "Experts" / "QM_FTMO"
    preset_dir = target / "MQL5" / "Profiles" / "Presets" / "QM_FTMO_M13"
    for row in rows:
        preset = package.sets_dir / row["output_path"]
        if sha(preset) != row["output_sha256"]:
            raise Refusal(f"preset_hash_mismatch:{preset.name}")
        values = trial_setpath.values(trial_setpath.decode(preset.read_bytes()))
        required = {
            "RISK_FIXED": "0", "RISK_PERCENT": expected_risk(row),
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
    if sha(package.collector_binary) != package.collector_sha:
        raise Refusal("collector_binary_hash_mismatch")
    collector_values = trial_setpath.values(package.collector_preset.read_text(encoding="utf-8"))
    if collector_values != {
        "InpTimerSeconds": "1",
        "InpOutputDir": package.collector_output_dir,
        "InpExpectedLogin": EXPECTED_LOGIN,
        "InpExpectedServer": EXPECTED_SERVER,
        "InpTrialId": package.trial_id,
    }:
        raise Refusal("collector_preset_contract_mismatch")
    planned += [
        (package.collector_binary, expert_dir / package.collector_binary.name),
        (package.collector_preset, preset_dir / package.collector_preset.name),
    ]
    return manifest, planned


def _expected_risk(package: Package, manifest: dict):
    """RISK_PERCENT expected per candidate: the roster row's, else the manifest's."""
    if package.roster is None:
        return lambda _row: "0.3125"
    by_magic = {row["magic"]: row for row in package.roster["candidates"]}

    def lookup(row: dict) -> str:
        magic = int(row["ea_id"]) * 10000 + int(row.get("qm_magic_slot_offset") or row.get("slot") or 0)
        return format(float(by_magic[magic]["risk_percent"]), ".10g")

    return lookup


# --------------------------------------------------------------------------- #
# Plan / install
# --------------------------------------------------------------------------- #
def plan(package: Package) -> dict:
    """The exact copy plan with sha256s. Touches nothing."""
    identity = require_target()
    manifest, planned = validate_sources(package)
    backup_dir = TARGET / "MQL5" / "Experts" / "QM_FTMO" / package.backup_dir_name
    copies = []
    for source, destination in planned:
        source_sha = sha(source)
        existing = sha(destination) if destination.is_file() else None
        copies.append({
            "source": str(source), "source_sha256": source_sha,
            "destination": str(destination),
            "destination_sha256_before": existing,
            "action": "SKIP_IDENTICAL" if existing == source_sha else ("REPLACE" if existing else "CREATE"),
            "backup_to": str(backup_dir / destination.name) if existing and existing != source_sha else None,
        })
    return {
        "schema": "qm.ftmo-demo-install-plan/v1",
        "mode": "DRY_RUN",
        "package": str(package.root),
        "label": package.label,
        "cycle_id": package.cycle_id,
        "decision_id": package.decision_id,
        "task_id": package.task_id,
        "target": str(TARGET),
        "identity": identity,
        "autotrading_changed": False, "charts_changed": False, "tlive_written": False,
        "sets_manifest_sha256": sha(package.sets_dir / "manifest.json"),
        "sets_manifest_schema": manifest["schema"],
        "backup_dir": str(backup_dir),
        "telemetry_dirs": [
            str(TARGET / "MQL5" / "Files" / "QM" / "ftmo_trial" / package.cycle_id),
            str(TRIAL_REPORT_ROOT / package.cycle_id),
        ],
        "copies": copies,
        "copy_count": len(copies),
    }


def install(package: Package | None = None) -> dict:
    package = package or legacy_package()
    authority = require_task(package)
    identity = require_target()
    manifest, planned = validate_sources(package)
    if package.receipt_out.exists() and package.roster is not None:
        raise Refusal(f"receipt_exists_refusing_overwrite:{package.receipt_out}")
    before = inventory(TARGET)
    backup_dir = TARGET / "MQL5" / "Experts" / "QM_FTMO" / package.backup_dir_name
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
    (TARGET / "MQL5" / "Files" / "QM" / "ftmo_trial" / package.cycle_id).mkdir(parents=True, exist_ok=True)
    (TRIAL_REPORT_ROOT / package.cycle_id).mkdir(parents=True, exist_ok=True)
    final_identity = require_target()
    receipt = {
        "schema": "qm.ftmo-demo-install/v1",
        "task_id": package.task_id,
        "authority": authority,
        "decision_id": package.decision_id,
        "cycle_id": package.cycle_id,
        "package": str(package.root),
        "status": "INSTALLED_UNATTACHED_PARKED",
        "target": str(TARGET),
        "identity": final_identity,
        "autotrading_changed": False,
        "charts_changed": False,
        "tlive_written": False,
        "sets_manifest_sha256": sha(package.sets_dir / "manifest.json"),
        "sets_manifest_schema": manifest["schema"],
        "inventory_before": before,
        "backups": backups,
        "installed": installed,
        "inventory_after": inventory(TARGET),
        "legacy_account_monitor_decision": "KEEP_DORMANT_DISTINCT_OUTPUT_PATH_NO_HANDLE_CONFLICT",
        "legacy_attach_map_decision": "KEEP_BUT_OBSOLETE_DO_NOT_USE_FOR_M13",
    }
    package.receipt_out.write_text(json.dumps(receipt, indent=2) + "\n", encoding="utf-8")
    return receipt


def main(argv: list[str] | None = None) -> int:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--package", help="package dir with roster.json, sets/, authority.json")
    group = parser.add_mutually_exclusive_group(required=True)
    group.add_argument("--execute", action="store_true")
    group.add_argument("--dry-run", action="store_true", help="print the exact copy plan with sha256s; touches nothing")
    args = parser.parse_args(argv)
    package = load_package(Path(args.package)) if args.package else legacy_package()
    print(json.dumps(plan(package) if args.dry_run else install(package), indent=2))
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
