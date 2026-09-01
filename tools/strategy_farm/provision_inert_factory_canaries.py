#!/usr/bin/env python3
"""Provision T11/T12 without launching MT5 or changing factory activation.

The v1 Variant-A manifest stays immutable and signed for T1-T10.  Its file
inventory and hashes are also the content authority for the inert canaries.
Archive files whose original family inode still exists are hard-linked into a
physical per-terminal Custom tree.  Archives whose family has already been
fully privatized are copied from the verified master, once per terminal.  The
normal copy-on-claim path then privatizes any remaining family links before a
future admitted claim.
"""

from __future__ import annotations

import argparse
import configparser
import datetime as dt
import hashlib
import json
import os
from pathlib import Path, PurePosixPath
import shutil
import subprocess
import sys
from typing import Any


REPO_ROOT = Path(__file__).resolve().parents[2]
if str(Path(__file__).resolve().parent) not in sys.path:
    sys.path.insert(0, str(Path(__file__).resolve().parent))

from custom_history_contract import (  # noqa: E402
    canonical_bytes,
    file_identity,
    load_manifest,
    normalize_relative_path,
    sha256_file,
    write_json_atomic,
)
from custom_history_master import load_master_state, master_file_path  # noqa: E402


SCHEMA = "qm.inert-factory-canary-provision/v1"
CANARIES = ("T11", "T12")
LEGACY_RUNNERS = tuple(f"T{i}" for i in range(1, 11))
INSTALL_FILES = ("terminal64.exe", "metatester64.exe", "MetaEditor64.exe", "portable.txt")
COPY_TREES = ("Config", "MQL5", "Profiles", "Sounds")
EMPTY_TREES = ("logs", "llm-agent", "Tester")


class ProvisionError(RuntimeError):
    pass


def _utc_now() -> str:
    return dt.datetime.now(dt.UTC).isoformat()


def _disabled(path: Path) -> set[str]:
    try:
        return {
            line.strip().upper()
            for line in path.read_text(encoding="utf-8-sig").splitlines()
            if line.strip()
        }
    except (OSError, UnicodeError) as exc:
        raise ProvisionError(f"disabled-terminal policy unreadable: {exc}") from exc


def _target_processes() -> list[dict[str, Any]]:
    if os.name != "nt":
        return []
    command = (
        "Get-CimInstance Win32_Process -Filter \"Name='terminal64.exe' OR Name='python.exe' OR Name='pythonw.exe'\" "
        "| Where-Object { $_.CommandLine -match '(?i)(?:\\\\mt5\\\\T1[12]\\\\|--terminal\\s+T1[12]\\b)' } "
        "| Select-Object ProcessId,Name,ExecutablePath,CommandLine | ConvertTo-Json -Compress"
    )
    result = subprocess.run(
        ["powershell.exe", "-NoProfile", "-NonInteractive", "-Command", command],
        capture_output=True,
        text=True,
        timeout=30,
        check=False,
    )
    if result.returncode != 0:
        raise ProvisionError(f"target-process probe failed: {result.stderr.strip()}")
    raw = result.stdout.strip()
    if not raw:
        return []
    decoded = json.loads(raw)
    return decoded if isinstance(decoded, list) else [decoded]


def _copy_tree(source: Path, target: Path) -> None:
    if not source.is_dir():
        raise ProvisionError(f"reference tree missing: {source}")
    shutil.copytree(source, target, copy_function=shutil.copy2)


def _family_source(mt5_root: Path, relative: str, manifest_file_id: str) -> Path | None:
    parts = PurePosixPath(normalize_relative_path(relative)).parts
    for terminal in LEGACY_RUNNERS:
        candidate = mt5_root / terminal / "Bases" / "Custom" / Path(*parts)
        try:
            if file_identity(candidate)["file_id"] == manifest_file_id:
                return candidate
        except OSError:
            continue
    return None


def _copy_custom(
    *,
    manifest: dict[str, Any],
    mt5_root: Path,
    farm_root: Path,
    reference_custom: Path,
    target_custom: Path,
) -> dict[str, Any]:
    target_custom.mkdir(parents=True, exist_ok=False)
    rows = {str(row["relative_path"]).casefold(): row for row in manifest["files"]}
    family_sources: dict[str, Path | None] = {}
    actions = {"archive_family_hardlink": 0, "archive_private_master_copy": 0, "mutable_private_copy": 0}
    bytes_by_action = {key: 0 for key in actions}
    master = load_master_state(farm_root, manifest=manifest)["master_root"]

    for relative, row in rows.items():
        canonical_relative = str(row["relative_path"])
        destination = target_custom.joinpath(*PurePosixPath(canonical_relative).parts)
        destination.parent.mkdir(parents=True, exist_ok=True)
        source = _family_source(mt5_root, canonical_relative, str(row["file_id"]))
        family_sources[relative] = source
        if source is not None:
            os.link(source, destination)
            action = "archive_family_hardlink"
        else:
            authoritative = master_file_path(master, canonical_relative)
            if not authoritative.is_file():
                raise ProvisionError(f"verified-master archive missing: {authoritative}")
            shutil.copyfile(authoritative, destination)
            action = "archive_private_master_copy"
        actions[action] += 1
        bytes_by_action[action] += int(row["size"])

    for source in sorted(reference_custom.rglob("*"), key=lambda item: str(item).casefold()):
        if not source.is_file():
            continue
        relative = normalize_relative_path(source.relative_to(reference_custom).as_posix())
        if relative.casefold() in rows:
            continue
        destination = target_custom.joinpath(*PurePosixPath(relative).parts)
        destination.parent.mkdir(parents=True, exist_ok=True)
        shutil.copy2(source, destination)
        actions["mutable_private_copy"] += 1
        bytes_by_action["mutable_private_copy"] += source.stat().st_size

    hash_cache: dict[str, str] = {}
    findings: list[dict[str, str]] = []
    for relative, row in rows.items():
        destination = target_custom.joinpath(*PurePosixPath(str(row["relative_path"])).parts)
        try:
            identity = file_identity(destination)
            if int(identity["size"]) != int(row["size"]):
                findings.append({"relative_path": str(row["relative_path"]), "reason": "size_mismatch"})
                continue
            digest = hash_cache.setdefault(identity["file_id"], sha256_file(destination))
            if digest != str(row["sha256"]).casefold():
                findings.append({"relative_path": str(row["relative_path"]), "reason": "sha256_mismatch"})
            family_source = family_sources[relative]
            if family_source is not None and identity["file_id"] != str(row["file_id"]):
                findings.append({"relative_path": str(row["relative_path"]), "reason": "family_id_mismatch"})
            if family_source is None and int(identity["link_count"]) != 1:
                findings.append({"relative_path": str(row["relative_path"]), "reason": "private_link_count_not_one"})
        except OSError as exc:
            findings.append({"relative_path": str(row["relative_path"]), "reason": f"unreadable:{exc}"})
    if findings:
        raise ProvisionError(f"Custom manifest verification failed: {findings[:10]}")
    return {
        "manifest_file_count": len(rows),
        "manifest_total_bytes": sum(int(row["size"]) for row in rows.values()),
        "actions": actions,
        "bytes_by_action": bytes_by_action,
        "distinct_inodes_hashed": len(hash_cache),
        "verification": "PASS_FULL_SHA256",
    }


def _tester_defaults_evidence(terminal_root: Path, tester_defaults: Path) -> dict[str, Any]:
    defaults = json.loads(tester_defaults.read_text(encoding="utf-8"))
    terminal_ini = configparser.ConfigParser(strict=False)
    terminal_ini.read(terminal_root / "Config" / "terminal.ini", encoding="utf-16")
    tester = terminal_ini["Tester"]
    observed = {
        "deposit": float(tester["Deposit"]),
        "currency": tester["Currency"],
        "leverage": int(tester["Leverage"]),
        "ticks_mode": int(tester["TicksMode"]),
    }
    expected = {
        "deposit": float(defaults["initial_deposit"]),
        "currency": str(defaults["deposit_currency"]),
        "leverage": int(defaults["leverage"]),
        "ticks_mode": int(defaults["p2_real_tick_policy"]["model"]),
        "risk_fixed": float(defaults["fixed_risk"]["amount"]),
    }
    if any(observed[key] != expected[key] for key in observed):
        raise ProvisionError(f"reference tester defaults mismatch: observed={observed} expected={expected}")
    common = configparser.ConfigParser(strict=False)
    common.read(terminal_root / "Config" / "common.ini", encoding="utf-8-sig")
    account = {"login": common["Common"]["Login"], "server": common["Common"]["Server"]}
    if account != {"login": "4000090541", "server": "Darwinex-Live"}:
        raise ProvisionError(f"unexpected reference account binding: {account}")
    return {
        "registry_path": str(tester_defaults),
        "registry_sha256": sha256_file(tester_defaults),
        "observed_terminal_config": observed,
        "expected": expected,
        "account": account,
        "status": "PASS",
    }


def provision(args: argparse.Namespace) -> list[dict[str, Any]]:
    disabled = _disabled(args.disabled_terminals)
    if not set(CANARIES).issubset(disabled):
        raise ProvisionError("T11 and T12 must both be disabled before provisioning")
    containment = json.loads(args.containment.read_text(encoding="utf-8-sig"))
    if containment.get("enabled") is not False:
        raise ProvisionError("containment mode must remain enabled:false")
    active = _target_processes()
    if active:
        raise ProvisionError(f"T11/T12 process already exists: {active}")
    manifest = load_manifest(args.manifest, require_owner_approval=True)
    reference = args.mt5_root / args.reference_terminal
    reference_custom = reference / "Bases" / "Custom"
    if not reference_custom.is_dir():
        raise ProvisionError(f"reference Custom tree missing: {reference_custom}")
    for terminal in CANARIES:
        if (args.mt5_root / terminal).exists() or (args.mt5_root / f"{terminal}.__provisioning__").exists():
            raise ProvisionError(f"target or staging directory already exists: {terminal}")
    args.evidence_dir.mkdir(parents=True, exist_ok=True)

    receipts: list[dict[str, Any]] = []
    for terminal in CANARIES:
        staging = args.mt5_root / f"{terminal}.__provisioning__"
        target = args.mt5_root / terminal
        staging.mkdir(parents=False, exist_ok=False)
        for name in INSTALL_FILES:
            source = reference / name
            if not source.is_file():
                raise ProvisionError(f"reference install file missing: {source}")
            shutil.copy2(source, staging / name)
        for name in COPY_TREES:
            _copy_tree(reference / name, staging / name)
        for name in EMPTY_TREES:
            (staging / name).mkdir()
        # A portable installation does not require a warm broker cache.  The
        # reference's non-Custom Bases tree is 64+ GiB of mutable/downloadable
        # cache and must not be cloned or hard-linked across profiles.  Start
        # with an empty physical Bases root; MT5 may populate it only after the
        # separate activation.  The governed .DWX Custom content is installed
        # and fully verified below.
        (staging / "Bases").mkdir()
        base_files, base_bytes = 0, 0
        custom = _copy_custom(
            manifest=manifest,
            mt5_root=args.mt5_root,
            farm_root=args.farm_root,
            reference_custom=reference_custom,
            target_custom=staging / "Bases" / "Custom",
        )
        defaults = _tester_defaults_evidence(staging, args.tester_defaults)
        if (staging / "Bases" / "Custom").is_symlink():
            raise ProvisionError("Custom root must be physical")
        staging.rename(target)
        receipt: dict[str, Any] = {
            "schema_version": SCHEMA,
            "status": "PASS_INERT_PROVISIONED",
            "recorded_at_utc": _utc_now(),
            "authority_task_id": args.authority_task_id,
            "terminal": terminal,
            "terminal_root": str(target),
            "reference_terminal": args.reference_terminal,
            "disabled_policy_path": str(args.disabled_terminals),
            "disabled_policy_sha256": sha256_file(args.disabled_terminals),
            "disabled_verified": terminal in disabled,
            "target_processes_before": active,
            "portable_mode": (target / "portable.txt").is_file(),
            "top_level_directories": sorted(path.name for path in target.iterdir() if path.is_dir()),
            "install_files": {name: sha256_file(target / name) for name in INSTALL_FILES},
            "bases_non_custom": {
                "file_count": base_files,
                "total_bytes": base_bytes,
                "policy": "COLD_EMPTY_MUTABLE_CACHE; populated only after separate activation",
            },
            "custom_history": {
                **custom,
                "manifest_path": str(args.manifest),
                "manifest_file_sha256": sha256_file(args.manifest),
                "manifest_content_sha256": manifest["manifest_sha256"],
                "signed_runner_set_preserved": manifest["runner_terminals"],
                "admission_state": "FAIL_CLOSED_NOT_IN_ACTIVE_T1_T10_ACTIVATION",
                "copy_on_claim_ready": True,
            },
            "tester_defaults": defaults,
            "containment": {
                "path": str(args.containment),
                "enabled": containment["enabled"],
                "mode_sha256": containment["mode_sha256"],
            },
            "activation_performed": False,
            "terminal_started": False,
            "t_live_touched": False,
            "rollback": [
                f"remove {target} only while {terminal} is disabled and has no process",
                f"remove {terminal} from the fleet code and keep/remove its disabled-list row under OWNER direction",
            ],
        }
        receipt["receipt_sha256"] = hashlib.sha256(canonical_bytes(receipt)).hexdigest()
        destination = args.evidence_dir / f"2026-09-01_{args.authority_task_id[:8]}_{terminal.lower()}_inert_provision.json"
        write_json_atomic(destination, receipt)
        receipt["evidence_path"] = str(destination)
        receipt["evidence_file_sha256"] = sha256_file(destination)
        receipts.append(receipt)
    if _target_processes():
        raise ProvisionError("T11/T12 process appeared during provisioning")
    return receipts


def build_parser() -> argparse.ArgumentParser:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--execute", action="store_true", help="required; there is no implicit mutation")
    parser.add_argument("--authority-task-id", required=True)
    parser.add_argument("--mt5-root", type=Path, default=Path(r"D:\QM\mt5"))
    parser.add_argument("--farm-root", type=Path, default=Path(r"D:\QM\strategy_farm"))
    parser.add_argument("--reference-terminal", default="T10")
    parser.add_argument(
        "--manifest",
        type=Path,
        default=Path(r"D:\QM\strategy_farm\artifacts\ops\custom_history_custom_history_variant_a_20260809\archive_manifest_owner_approved.json"),
    )
    parser.add_argument(
        "--disabled-terminals",
        type=Path,
        default=Path(r"D:\QM\strategy_farm\state\disabled_terminals.txt"),
    )
    parser.add_argument(
        "--containment",
        type=Path,
        default=Path(r"D:\QM\strategy_farm\state\custom_history_containment_mode.json"),
    )
    parser.add_argument(
        "--tester-defaults",
        type=Path,
        default=REPO_ROOT / "framework" / "registry" / "tester_defaults.json",
    )
    parser.add_argument(
        "--evidence-dir",
        type=Path,
        default=REPO_ROOT / "docs" / "ops" / "evidence",
    )
    return parser


def main() -> int:
    args = build_parser().parse_args()
    if not args.execute:
        print(json.dumps({"status": "DRY_RUN_REFUSED", "reason": "pass --execute after review"}, sort_keys=True))
        return 2
    try:
        receipts = provision(args)
    except Exception as exc:
        print(json.dumps({"status": "FAIL_CLOSED", "error": f"{type(exc).__name__}: {exc}"}, sort_keys=True))
        return 1
    print(json.dumps({"status": "PASS", "receipts": receipts}, indent=2, sort_keys=True))
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
