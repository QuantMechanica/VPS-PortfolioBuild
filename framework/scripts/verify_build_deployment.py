#!/usr/bin/env python3
"""verify_build_deployment.py — strict build-artifact gate.

Refuses to confirm a P0 build is complete unless:
 1. EA directory exists under framework/EAs/<dir>/
 2. .ex5 file exists at framework/EAs/<dir>/<file>.ex5, size > 50 KB
 3. .ex5 deployed to installed D:/QM/mt5/T1..T10/MQL5/Experts/QM/<file>.ex5
 4. SHA256 matches across framework + all installed factory terminals
 5. (Optional) at least one .set file exists under framework/EAs/<dir>/sets/

Exit codes:
 0 = all checks passed
 1 = missing directory
 2 = missing build artifact (.ex5)
 3 = deployment incomplete on installed factory terminals
 4 = SHA mismatch
 5 = no setfiles

Usage:
  verify_build_deployment.py --ea-id 1039 --ea-dir-glob "*singh*swap*fly*"
  verify_build_deployment.py --ea-id 1003 --ea-dir-glob "QM5_1003_*"
  verify_build_deployment.py --json --ea-id 1039 --ea-dir-glob "*singh*"
"""
from __future__ import annotations

import argparse
import glob
import hashlib
import json
import os
import sys
from pathlib import Path

REPO_ROOT = Path(__file__).resolve().parents[2]
EA_ROOT = REPO_ROOT / "framework" / "EAs"
MT5_TERMINAL_ROOT = Path("D:/QM/mt5")
TERMINALS = [f"T{i}" for i in range(1, 11)]
MQL5_EXPERTS_REL = Path("MQL5/Experts/QM")
MIN_EX5_BYTES = 50_000


def installed_terminals() -> list[str]:
    terminals = [terminal for terminal in TERMINALS if (MT5_TERMINAL_ROOT / terminal / "terminal64.exe").exists()]
    return terminals or list(TERMINALS)


def sha256_hex(p: Path) -> str:
    h = hashlib.sha256()
    with p.open("rb") as f:
        for chunk in iter(lambda: f.read(65536), b""):
            h.update(chunk)
    return h.hexdigest()


def main() -> int:
    ap = argparse.ArgumentParser(description="Strict build-artifact + deployment verification")
    ap.add_argument("--ea-id", required=True, help="EA numeric id (e.g. 1039)")
    ap.add_argument("--ea-dir-glob", required=True,
                    help="Glob pattern to match the EA dir under framework/EAs/ (e.g. '*singh*')")
    ap.add_argument("--json", action="store_true", help="Emit JSON evidence on stdout")
    a = ap.parse_args()

    result: dict = {
        "ea_id": a.ea_id,
        "ea_dir_glob": a.ea_dir_glob,
        "checks": {},
        "verdict": "PENDING",
        "exit_code": 0,
        "evidence": {},
    }

    # 1. EA directory
    dirs = [Path(p) for p in glob.glob(str(EA_ROOT / a.ea_dir_glob)) if Path(p).is_dir()]
    result["checks"]["ea_dir_exists"] = len(dirs) > 0
    result["evidence"]["ea_dirs"] = [str(d) for d in dirs]
    if not dirs:
        result["verdict"] = "GHOST_BUILD"
        result["exit_code"] = 1
        _emit(result, a.json)
        return 1
    if len(dirs) > 1:
        result["evidence"]["multiple_dirs_warning"] = (
            "More than one dir matches glob. Using first: " + str(dirs[0])
        )
    ea_dir = dirs[0]

    # 2. .ex5 artifact
    ex5_files = list(ea_dir.glob("*.ex5"))
    result["checks"]["ex5_present"] = len(ex5_files) > 0
    result["evidence"]["framework_ex5"] = [str(p) for p in ex5_files]
    if not ex5_files:
        result["verdict"] = "GHOST_BUILD"
        result["exit_code"] = 2
        _emit(result, a.json)
        return 2

    # Pick the .ex5 that matches the dir name; fallback to first
    ea_dir_name = ea_dir.name
    candidate = ea_dir / f"{ea_dir_name}.ex5"
    if not candidate.exists():
        candidate = ex5_files[0]
    src_size = candidate.stat().st_size
    result["evidence"]["selected_ex5"] = str(candidate)
    result["evidence"]["src_size_bytes"] = src_size
    if src_size < MIN_EX5_BYTES:
        result["checks"]["size_ok"] = False
        result["verdict"] = "GHOST_BUILD"
        result["exit_code"] = 2
        _emit(result, a.json)
        return 2
    result["checks"]["size_ok"] = True

    src_sha = sha256_hex(candidate)
    result["evidence"]["src_sha256"] = src_sha
    ex5_filename = candidate.name

    # 3 + 4. Deployment + SHA across installed factory terminals.
    per_terminal: dict[str, dict] = {}
    deploy_missing = []
    sha_mismatch = []
    for t in installed_terminals():
        target = MT5_TERMINAL_ROOT / t / MQL5_EXPERTS_REL / ex5_filename
        info: dict = {"path": str(target), "exists": target.exists()}
        if target.exists():
            info["size"] = target.stat().st_size
            info["sha256"] = sha256_hex(target)
            if info["sha256"] != src_sha:
                sha_mismatch.append(t)
                info["sha_match"] = False
            else:
                info["sha_match"] = True
        else:
            deploy_missing.append(t)
            info["sha_match"] = False
        per_terminal[t] = info

    result["evidence"]["per_terminal"] = per_terminal
    result["checks"]["all_terminals_deployed"] = len(deploy_missing) == 0
    result["checks"]["all_sha_match"] = len(sha_mismatch) == 0
    result["evidence"]["deploy_missing"] = deploy_missing
    result["evidence"]["sha_mismatch"] = sha_mismatch

    if deploy_missing:
        result["verdict"] = "DEPLOY_INCOMPLETE"
        result["exit_code"] = 3
        _emit(result, a.json)
        return 3
    if sha_mismatch:
        result["verdict"] = "SHA_MISMATCH"
        result["exit_code"] = 4
        _emit(result, a.json)
        return 4

    # 5. setfiles
    sets_dir = ea_dir / "sets"
    set_files = list(sets_dir.glob("*.set")) if sets_dir.exists() else []
    result["checks"]["setfiles_present"] = len(set_files) > 0
    result["evidence"]["setfile_count"] = len(set_files)
    if not set_files:
        result["verdict"] = "NO_SETFILES"
        result["exit_code"] = 5
        _emit(result, a.json)
        return 5

    result["verdict"] = "PASS"
    result["exit_code"] = 0
    _emit(result, a.json)
    return 0


def _emit(result: dict, as_json: bool) -> None:
    if as_json:
        print(json.dumps(result, indent=2))
    else:
        print(f"verdict={result['verdict']} exit={result['exit_code']}")
        for k, v in result["checks"].items():
            print(f"  {k}: {v}")
        if result["verdict"] != "PASS":
            print(f"  evidence-snip: {json.dumps(result['evidence'])[:300]}")


if __name__ == "__main__":
    raise SystemExit(main())
