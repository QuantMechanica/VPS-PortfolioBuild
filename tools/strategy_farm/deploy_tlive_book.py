#!/usr/bin/env python3
"""Guarded, hash-bound copy ceremony for the T_Live DXZ book.

The legacy deployment boundary was an untracked manual file copy.  This tool
turns that boundary into a reviewable plan and invokes the canonical
``risk_freeze`` guard before the first live write.  Dry-run is the default.

It never starts MT5, edits charts/configuration, or toggles AutoTrading.
"""
from __future__ import annotations

import argparse
import hashlib
import json
import os
import shutil
import sys
from pathlib import Path
from typing import Callable

try:
    from tools.strategy_farm import risk_freeze
except ModuleNotFoundError:  # direct script execution
    sys.path.insert(0, str(Path(__file__).resolve().parents[2]))
    from tools.strategy_farm import risk_freeze


SCHEMA = "qm.tlive_book_copy_plan.v1"
DEFAULT_LIVE_ROOT = Path(r"C:\QM\mt5\T_Live\MT5_Base")
ALLOWED_TARGET_PARENTS = (
    Path("MQL5/Presets"),
    Path("MQL5/Experts/Live EAs"),
)


class CopyPlanError(ValueError):
    """The copy plan is unsafe, incomplete, or does not match its sources."""


def sha256_file(path: Path) -> str:
    digest = hashlib.sha256()
    with path.open("rb") as handle:
        for chunk in iter(lambda: handle.read(1024 * 1024), b""):
            digest.update(chunk)
    return digest.hexdigest()


def _resolved_under(path: Path, root: Path) -> bool:
    try:
        path.resolve().relative_to(root.resolve())
        return True
    except (OSError, ValueError):
        return False


def load_and_validate_plan(plan_path: Path, live_root: Path) -> tuple[dict, list[dict]]:
    try:
        plan = json.loads(plan_path.read_text(encoding="utf-8-sig"))
    except (OSError, UnicodeError, json.JSONDecodeError) as exc:
        raise CopyPlanError(f"plan unreadable: {plan_path}: {exc}") from exc
    if not isinstance(plan, dict) or plan.get("schema") != SCHEMA:
        raise CopyPlanError(f"plan schema must be {SCHEMA}")

    evidence = Path(str(plan.get("owner_approval_evidence") or ""))
    if not evidence.is_file():
        raise CopyPlanError("owner_approval_evidence must name an existing file")
    items = plan.get("items")
    if not isinstance(items, list) or not items:
        raise CopyPlanError("items must be a non-empty array")

    checked: list[dict] = []
    destinations: set[str] = set()
    for index, raw in enumerate(items):
        if not isinstance(raw, dict):
            raise CopyPlanError(f"items[{index}] must be an object")
        source = Path(str(raw.get("source") or ""))
        if not source.is_file():
            raise CopyPlanError(f"items[{index}].source is not a file: {source}")
        relative = Path(str(raw.get("destination_relative") or ""))
        if relative.is_absolute() or ".." in relative.parts:
            raise CopyPlanError(f"items[{index}].destination_relative escapes live root")
        if not any(relative.parent == allowed for allowed in ALLOWED_TARGET_PARENTS):
            raise CopyPlanError(
                f"items[{index}] destination must be directly under MQL5/Presets "
                "or MQL5/Experts/Live EAs"
            )
        suffix = relative.suffix.lower()
        if relative.parent == Path("MQL5/Presets") and suffix != ".set":
            raise CopyPlanError(f"items[{index}] preset target must end in .set")
        if relative.parent == Path("MQL5/Experts/Live EAs") and suffix != ".ex5":
            raise CopyPlanError(f"items[{index}] expert target must end in .ex5")
        destination = live_root / relative
        if not _resolved_under(destination, live_root):
            raise CopyPlanError(f"items[{index}] destination escapes live root")
        destination_key = str(destination.resolve()).casefold()
        if destination_key in destinations:
            raise CopyPlanError(f"duplicate destination: {destination}")
        destinations.add(destination_key)

        expected = str(raw.get("sha256") or "").strip().lower()
        actual = sha256_file(source)
        if expected != actual:
            raise CopyPlanError(
                f"items[{index}] source SHA-256 mismatch: expected {expected}, got {actual}"
            )
        checked.append({
            "source": source,
            "destination": destination,
            "destination_relative": relative.as_posix(),
            "sha256": actual,
        })
    return plan, checked


def execute(
    plan_path: Path,
    *,
    live_root: Path = DEFAULT_LIVE_ROOT,
    backup_dir: Path | None = None,
    apply: bool = False,
    guard: Callable[..., dict] = risk_freeze.assert_live_book_mutation_allowed,
) -> dict:
    """Validate the entire batch, then optionally perform guarded atomic copies."""
    if apply:
        # Deliberately first: ACTIVE/missing/unreadable freeze state refuses
        # before directories, backups, or destination temp files are created.
        guard("copy a staged DXZ book into T_Live")

    plan, items = load_and_validate_plan(Path(plan_path), Path(live_root))
    if apply and backup_dir is None:
        raise CopyPlanError("--apply requires --backup-dir for recoverable replacements")

    replaced: list[dict] = []
    if apply:
        backup_dir = Path(backup_dir)
        if _resolved_under(backup_dir, Path(live_root)):
            raise CopyPlanError("backup_dir must be outside T_Live")
        backup_dir.mkdir(parents=True, exist_ok=False)

        # All validation is complete before the mutation phase.  Existing
        # destinations are captured byte-for-byte before replacement.
        for item in items:
            destination = item["destination"]
            relative = Path(item["destination_relative"])
            if destination.exists():
                backup = backup_dir / relative
                backup.parent.mkdir(parents=True, exist_ok=True)
                shutil.copy2(destination, backup)
            destination.parent.mkdir(parents=True, exist_ok=True)
            temp = destination.with_name(f".{destination.name}.{os.getpid()}.tmp")
            try:
                shutil.copy2(item["source"], temp)
                if sha256_file(temp) != item["sha256"]:
                    raise CopyPlanError(f"temporary copy hash mismatch: {destination}")
                os.replace(temp, destination)
            finally:
                if temp.exists():
                    temp.unlink()
            if sha256_file(destination) != item["sha256"]:
                raise CopyPlanError(f"post-copy hash mismatch: {destination}")
            replaced.append({
                "destination": str(destination),
                "sha256": item["sha256"],
            })

    return {
        "schema": SCHEMA,
        "mode": "APPLY" if apply else "DRY_RUN",
        "plan": str(plan_path),
        "owner_approval_evidence": plan["owner_approval_evidence"],
        "live_root": str(live_root),
        "validated_items": len(items),
        "written_items": len(replaced),
        "items": [
            {
                "source": str(item["source"]),
                "destination": str(item["destination"]),
                "sha256": item["sha256"],
            }
            for item in items
        ],
    }


def main(argv: list[str] | None = None) -> int:
    parser = argparse.ArgumentParser(description=__doc__.split("\n", 1)[0])
    parser.add_argument("--plan", type=Path, required=True)
    parser.add_argument("--live-root", type=Path, default=DEFAULT_LIVE_ROOT)
    parser.add_argument("--backup-dir", type=Path)
    parser.add_argument("--apply", action="store_true", help="perform copies; default is dry-run")
    args = parser.parse_args(argv)
    result = execute(
        args.plan,
        live_root=args.live_root,
        backup_dir=args.backup_dir,
        apply=args.apply,
    )
    print(json.dumps(result, indent=2))
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
