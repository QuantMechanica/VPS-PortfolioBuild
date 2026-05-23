"""
migrate_t2_t5_junction.py - junction T2-T5/Bases to T1/Bases to free disk.

Implements DL-062-adjacent disk-recovery work per OWNER 2026-05-23.

Safety:
  - Hard-aborts if factory is running (any terminal_worker, terminal64, or
    metatester64 process detected).
  - Dry-run by default - prints plan, no writes.
  - Backup-rename instead of delete: T<n>/Bases moves to
    T<n>/Bases.before_junction.YYYYMMDD before junction creation. OWNER
    deletes the backup manually after testing confirms no regression.
  - Per-terminal application (one of {T2,T3,T4,T5} per invocation) so
    OWNER can test T2 with Factory_ON, then proceed incrementally.
  - File classification: .tkc/.hcc/.dat/.tk1/.h1 = MT5 cache (regenerable
    per terminal), skip-and-discard-on-junction. Other extensions in
    unique-to-T<n> files are merged into T1/Bases BEFORE junction.

Usage:
  python migrate_t2_t5_junction.py --terminal T2 --dry-run
  python migrate_t2_t5_junction.py --terminal T2 --apply

Exit codes:
  0  - success (dry-run completed or apply succeeded)
  1  - factory running, aborted
  2  - precondition failed (T1 is itself a junction, T<n> already junctioned, etc.)
  3  - merge or junction step failed mid-flight (backup preserved, junction NOT created)
"""

from __future__ import annotations

import argparse
import datetime as dt
import os
import shutil
import subprocess
import sys
from pathlib import Path

MT5_ROOT = Path(r"D:\QM\mt5")
# MT5 per-terminal regenerable caches: tick caches, history caches, fxt fixtures,
# and anything under a /cache/ subdir (typically Custom/history/<SYM>/cache/M1.hc).
CACHE_EXTENSIONS = {".tkc", ".hcc", ".hc", ".dat", ".tk1", ".h1", ".ticks", ".cache", ".fxt"}
CREATE_NO_WINDOW = getattr(subprocess, "CREATE_NO_WINDOW", 0)


def list_running_factory_processes() -> dict[str, int]:
    """Return counts of {terminal_worker daemons, terminal64, metatester64}."""
    counts = {"terminal_worker": 0, "terminal64": 0, "metatester64": 0}
    try:
        result = subprocess.run(
            [
                "powershell.exe", "-NoProfile", "-Command",
                "$worker = @(Get-CimInstance Win32_Process -Filter \"Name='pythonw.exe' OR Name='python.exe'\" | "
                "Where-Object {$_.CommandLine -match 'terminal_worker'}).Count; "
                "$t64 = @(Get-Process terminal64 -ErrorAction SilentlyContinue).Count; "
                "$mt = @(Get-Process metatester64 -ErrorAction SilentlyContinue).Count; "
                "Write-Output \"$worker|$t64|$mt\""
            ],
            capture_output=True, text=True, timeout=15,
            creationflags=CREATE_NO_WINDOW,
        )
        if result.returncode == 0 and result.stdout.strip():
            parts = result.stdout.strip().split("|")
            if len(parts) == 3:
                counts["terminal_worker"] = int(parts[0])
                counts["terminal64"] = int(parts[1])
                counts["metatester64"] = int(parts[2])
    except Exception as exc:
        print(f"WARN: could not enumerate factory processes: {exc}", file=sys.stderr)
    return counts


def is_junction(path: Path) -> bool:
    import ctypes
    FILE_ATTRIBUTE_REPARSE_POINT = 0x400
    attrs = ctypes.windll.kernel32.GetFileAttributesW(str(path))
    return attrs != -1 and (attrs & FILE_ATTRIBUTE_REPARSE_POINT) != 0


def index_dir(root: Path) -> dict[str, int]:
    """Return {relative_path: size_bytes} for all files under root."""
    out = {}
    for r, _, files in os.walk(root):
        for f in files:
            full = Path(r) / f
            try:
                rel = full.relative_to(root).as_posix()
                out[rel] = full.stat().st_size
            except Exception:
                pass
    return out


def classify_file(rel_path: str) -> str:
    """Return 'cache' or 'data' based on extension OR path (any /cache/ subdir)."""
    ext = Path(rel_path).suffix.lower()
    if ext in CACHE_EXTENSIONS:
        return "cache"
    if "/cache/" in rel_path.lower():
        return "cache"
    return "data"


def plan_migration(terminal: str) -> dict:
    """Compute the diff between T<n>/Bases and T1/Bases and the merge plan."""
    t1_bases = MT5_ROOT / "T1" / "Bases"
    tn_bases = MT5_ROOT / terminal / "Bases"

    if not t1_bases.exists():
        raise RuntimeError(f"T1/Bases missing: {t1_bases}")
    if not tn_bases.exists():
        raise RuntimeError(f"{terminal}/Bases missing: {tn_bases}")
    if is_junction(t1_bases):
        raise RuntimeError("T1/Bases is itself a junction - aborting (T1 must be source)")
    if is_junction(tn_bases):
        raise RuntimeError(f"{terminal}/Bases is already a junction - nothing to do")

    print(f"  indexing T1/Bases...")
    t1_idx = index_dir(t1_bases)
    print(f"    {len(t1_idx)} files, {sum(t1_idx.values()) / 1e9:.2f} GB")

    print(f"  indexing {terminal}/Bases...")
    tn_idx = index_dir(tn_bases)
    print(f"    {len(tn_idx)} files, {sum(tn_idx.values()) / 1e9:.2f} GB")

    unique_to_tn = set(tn_idx) - set(t1_idx)
    shared = set(t1_idx) & set(tn_idx)
    size_mismatch = {k for k in shared if t1_idx[k] != tn_idx[k]}

    plan = {
        "terminal": terminal,
        "t1_bases": str(t1_bases),
        "tn_bases": str(tn_bases),
        "t1_file_count": len(t1_idx),
        "t1_size_gb": sum(t1_idx.values()) / 1e9,
        "tn_file_count": len(tn_idx),
        "tn_size_gb": sum(tn_idx.values()) / 1e9,
        "unique_data": [],
        "unique_cache_skipped": [],
        "mismatch_data": [],
        "mismatch_cache_skipped": [],
        "identical": len(shared) - len(size_mismatch),
    }

    for rel in unique_to_tn:
        size = tn_idx[rel]
        if classify_file(rel) == "cache":
            plan["unique_cache_skipped"].append({"rel": rel, "size": size})
        else:
            plan["unique_data"].append({"rel": rel, "size": size})

    for rel in size_mismatch:
        size = tn_idx[rel]
        if classify_file(rel) == "cache":
            plan["mismatch_cache_skipped"].append({"rel": rel, "size_t1": t1_idx[rel], "size_tn": size})
        else:
            plan["mismatch_data"].append({"rel": rel, "size_t1": t1_idx[rel], "size_tn": size})

    plan["unique_data_size"] = sum(f["size"] for f in plan["unique_data"])
    plan["unique_cache_size"] = sum(f["size"] for f in plan["unique_cache_skipped"])
    plan["mismatch_data_count"] = len(plan["mismatch_data"])
    plan["mismatch_cache_count"] = len(plan["mismatch_cache_skipped"])
    plan["estimated_savings_gb"] = (plan["tn_size_gb"] - plan["unique_data_size"] / 1e9)
    return plan


def print_plan(plan: dict) -> None:
    tn = plan["terminal"]
    print(f"\n=== Migration plan for {tn} ===")
    print(f"  T1/Bases:     {plan['t1_size_gb']:.2f} GB ({plan['t1_file_count']} files)")
    print(f"  {tn}/Bases:   {plan['tn_size_gb']:.2f} GB ({plan['tn_file_count']} files)")
    print(f"  Identical:    {plan['identical']} files")
    print()
    print(f"  Unique-to-{tn} files:")
    print(f"    DATA (will be merged to T1/Bases):  {len(plan['unique_data'])} files, {plan['unique_data_size'] / 1e6:.1f} MB")
    print(f"    CACHE (regenerable, will be discarded): {len(plan['unique_cache_skipped'])} files, {plan['unique_cache_size'] / 1e6:.1f} MB")
    print()
    print(f"  Size-mismatched files (same path, different size):")
    print(f"    DATA (CONFLICT - needs OWNER decision): {plan['mismatch_data_count']} files")
    print(f"    CACHE (per-terminal regen, will be discarded): {plan['mismatch_cache_count']} files")
    print()
    if plan["mismatch_data"]:
        print(f"  WARNING: {plan['mismatch_data_count']} non-cache files differ between T1 and {tn}.")
        print(f"  These are NOT auto-mergeable. Showing first 10:")
        for f in sorted(plan["mismatch_data"], key=lambda x: -max(x["size_t1"], x["size_tn"]))[:10]:
            print(f"    {f['rel']}: T1={f['size_t1']} {tn}={f['size_tn']}")
        print(f"  Re-run with --force-keep-t1 to accept T1 versions and continue.")
    print()
    print(f"  Estimated savings if migration applied: {plan['estimated_savings_gb']:.2f} GB")
    print()


def apply_migration(plan: dict, force_keep_t1: bool = False) -> None:
    """Execute: merge unique data, backup-rename T<n>/Bases, create junction."""
    tn = plan["terminal"]
    t1_bases = Path(plan["t1_bases"])
    tn_bases = Path(plan["tn_bases"])

    if plan["mismatch_data"] and not force_keep_t1:
        raise RuntimeError(
            f"{plan['mismatch_data_count']} non-cache files differ between T1 and {tn}; "
            "re-run with --force-keep-t1 to accept T1 versions and continue."
        )

    if plan["unique_data"]:
        print(f"  merging {len(plan['unique_data'])} unique data files into T1/Bases...")
        for f in plan["unique_data"]:
            src = tn_bases / f["rel"]
            dst = t1_bases / f["rel"]
            dst.parent.mkdir(parents=True, exist_ok=True)
            shutil.copy2(src, dst)
        print(f"    merged ({plan['unique_data_size'] / 1e6:.1f} MB into T1/Bases)")
    else:
        print(f"  no unique data files to merge")

    today = dt.datetime.now().strftime("%Y%m%d")
    backup = tn_bases.parent / f"Bases.before_junction.{today}"
    if backup.exists():
        raise RuntimeError(f"backup target {backup} already exists - aborting (manual cleanup needed)")

    print(f"  renaming {tn_bases} -> {backup}")
    tn_bases.rename(backup)

    print(f"  creating junction {tn_bases} -> {t1_bases}")
    try:
        result = subprocess.run(
            ["cmd.exe", "/c", "mklink", "/J", str(tn_bases), str(t1_bases)],
            capture_output=True, text=True, timeout=30, creationflags=CREATE_NO_WINDOW,
        )
        if result.returncode != 0:
            print(f"  mklink FAILED: {result.stderr}", file=sys.stderr)
            print(f"  restoring backup...")
            backup.rename(tn_bases)
            raise RuntimeError("junction creation failed; backup restored")
        print(f"    {result.stdout.strip()}")
    except Exception as exc:
        if backup.exists() and not tn_bases.exists():
            backup.rename(tn_bases)
            print(f"  restored backup after failure: {exc}", file=sys.stderr)
        raise

    print(f"  verifying junction works...")
    if not is_junction(tn_bases):
        raise RuntimeError(f"{tn_bases} is not a junction after mklink - aborting")
    # symbols.custom.dat lives at Bases/ top-level (not under Bases/Custom/)
    test_path = tn_bases / "symbols.custom.dat"
    if not test_path.exists():
        print(f"  WARNING: T1/Bases/symbols.custom.dat missing - junction works but T1 may be incomplete")
    else:
        print(f"    junction verified - T1/Bases/symbols.custom.dat reachable via {tn} ({test_path.stat().st_size} bytes)")
    print(f"  backup kept at: {backup}")
    print(f"  OWNER: test factory with Factory_ON; if {tn} backtests work for ~1h, delete backup manually:")
    print(f"    rmdir /s /q {backup}")


def main() -> int:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--terminal", required=True, choices=["T2", "T3", "T4", "T5"])
    parser.add_argument("--dry-run", action="store_true", default=True)
    parser.add_argument("--apply", action="store_true")
    parser.add_argument("--force-keep-t1", action="store_true",
                        help="On size-mismatch for non-cache files, prefer T1 version (discards T<n> diff)")
    args = parser.parse_args()

    if args.apply:
        args.dry_run = False

    print(f"=== T2-T5 Bases junction migration ===")
    print(f"  terminal: {args.terminal}")
    print(f"  mode:     {'APPLY' if not args.dry_run else 'DRY-RUN'}")
    print(f"  force-keep-t1: {args.force_keep_t1}")
    print()

    print(f"step 1: factory-off precheck")
    procs = list_running_factory_processes()
    print(f"  {procs}")
    if any(v > 0 for v in procs.values()):
        print(f"  FAIL: factory is running, aborting. Run Factory_OFF.ps1 first.", file=sys.stderr)
        return 1

    print(f"\nstep 2: plan migration")
    try:
        plan = plan_migration(args.terminal)
    except RuntimeError as exc:
        print(f"  FAIL: {exc}", file=sys.stderr)
        return 2

    print_plan(plan)

    if args.dry_run:
        print(f"DRY-RUN COMPLETE. Re-run with --apply to execute.")
        return 0

    print(f"\nstep 3: apply migration")
    try:
        apply_migration(plan, force_keep_t1=args.force_keep_t1)
    except RuntimeError as exc:
        print(f"  FAIL: {exc}", file=sys.stderr)
        return 3

    print(f"\nSUCCESS: {args.terminal}/Bases now junctioned to T1/Bases")
    print(f"  estimated freed: {plan['estimated_savings_gb']:.2f} GB")
    return 0


if __name__ == "__main__":
    sys.exit(main())
