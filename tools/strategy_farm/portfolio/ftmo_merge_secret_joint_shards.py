"""Merge development-only secret joint-equity shards and select one winner."""

from __future__ import annotations

import argparse
import hashlib
import json
from pathlib import Path
from typing import Any, Mapping, Sequence

try:
    from .ftmo_secret_joint_bar_mae_screen import select_development_winner
except ImportError:  # pragma: no cover - direct script execution
    from ftmo_secret_joint_bar_mae_screen import select_development_winner  # type: ignore


def _sha256(path: Path) -> str:
    digest = hashlib.sha256()
    with path.open("rb") as handle:
        for chunk in iter(lambda: handle.read(1024 * 1024), b""):
            digest.update(chunk)
    return digest.hexdigest()


def merge_shards(shards: Sequence[tuple[Path, Mapping[str, Any]]]) -> dict[str, Any]:
    if not shards:
        raise ValueError("at least one shard is required")
    reference = shards[0][1]
    scenario = reference.get("scenario")
    manifest_hash = reference.get("manifest_sha256")
    control_normal = reference["development"]["control_normal"]
    control_adverse = reference["development"]["control_adverse"]
    rows: list[dict[str, Any]] = []
    representations: list[str] = []
    sources: list[dict[str, Any]] = []
    for path, shard in shards:
        if not shard.get("stopped_after_development"):
            raise ValueError(f"{path}: shard was allowed beyond development")
        if shard.get("validation") is not None or shard.get("confirmation") is not None:
            raise ValueError(f"{path}: validation or confirmation was opened")
        if shard.get("scenario") != scenario or shard.get("manifest_sha256") != manifest_hash:
            raise ValueError(f"{path}: scenario or manifest mismatch")
        if shard["development"]["control_normal"] != control_normal:
            raise ValueError(f"{path}: normal control mismatch")
        if shard["development"]["control_adverse"] != control_adverse:
            raise ValueError(f"{path}: adverse control mismatch")
        names = [str(value) for value in shard.get("representations_screened") or []]
        if len(names) != 1:
            raise ValueError(f"{path}: expected exactly one representation")
        if names[0] in representations:
            raise ValueError(f"{path}: duplicate representation {names[0]}")
        representations.extend(names)
        rows.extend(dict(row) for row in shard["development"]["rows"])
        sources.append({"path": str(path), "sha256": _sha256(path)})

    control_normal_pct = float(control_normal["historical_rolling"]["pass_pct"])
    control_adverse_pct = float(control_adverse["historical_rolling"]["pass_pct"])
    winner = select_development_winner(
        rows,
        control_normal=control_normal_pct,
        control_adverse=control_adverse_pct,
    )
    leaderboard = sorted(
        rows,
        key=lambda row: (
            -float(row["normal_pass_pct"]),
            -(float(row["adverse_pass_pct"]) if row.get("adverse_pass_pct") is not None else -1.0),
            float(row["candidate_weight_pct"]),
            str(row["representation"]),
        ),
    )
    return {
        "schema_version": 1,
        "status": "DEVELOPMENT_SURVIVOR" if winner else "NO_DEVELOPMENT_SURVIVOR",
        "label": "RESEARCH_ONLY_NO_GO",
        "deployment_allowed": False,
        "scenario": scenario,
        "manifest_sha256": manifest_hash,
        "representations": sorted(representations),
        "candidate_count": len(rows),
        "control_normal": control_normal,
        "control_adverse": control_adverse,
        "winner": winner,
        "validation_open_allowed": winner is not None,
        "sealed_holdout_open_allowed": False,
        "leaderboard": leaderboard,
        "source_shards": sources,
    }


def main(argv: Sequence[str] | None = None) -> int:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--shard", type=Path, action="append", required=True)
    parser.add_argument("--out", type=Path, required=True)
    args = parser.parse_args(argv)
    shards = [
        (path, json.loads(path.read_text(encoding="utf-8-sig"))) for path in args.shard
    ]
    artifact = merge_shards(shards)
    args.out.parent.mkdir(parents=True, exist_ok=True)
    args.out.write_text(json.dumps(artifact, indent=2, sort_keys=True) + "\n", encoding="utf-8")
    print(
        f"wrote {args.out} status={artifact['status']} "
        f"candidates={artifact['candidate_count']}"
    )
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
