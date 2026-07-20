#!/usr/bin/env python3
"""Build the exact, immutable input snapshot released for QM5_10729 full-DEV."""

from __future__ import annotations

import argparse
import hashlib
import json
import os
import shutil
import stat
import subprocess
import tempfile
from datetime import datetime, timezone
from pathlib import Path, PurePosixPath
from typing import Any, Mapping


TOOL_PATH = Path(__file__).resolve()
EA_ROOT = TOOL_PATH.parents[2]
REPO_ROOT = EA_ROOT.parents[2]
EVIDENCE_ROOT = EA_ROOT / "docs" / "candidate-analysis"
CONTRACT_PATH = EVIDENCE_ROOT / "tv_smc_mss_fvg_m15_two_symbol_full_dev_contract.json"
REVIEW_PATH = EVIDENCE_ROOT / "tv_smc_mss_fvg_outcome_blind_review_receipt.json"
EXPECTED_CONTRACT_SHA256 = "0b221d1c79dce4a4fef0aa635de957296511e1fc945523e8a4da556c13311d25"
EXPECTED_REVIEW_SHA256 = "2d009fa440a125514d3d6109ae00d91be295c1b052d53e9e47b5ee9121358d99"
ANALYSIS_ID = "QM5_10729_TV_SMC_MSS_FVG_M15_TWO_SYMBOL_FULL_DEV_001"
CONTRACT_COMMIT = "3886f15e756b622f0b9cc9f9e1890bce173d653d"
REVIEW_COMMIT = "fc9b5428c6258b885f6f1c8f3a930529ed0dc8e6"
NEWS_FILTER_CONTRACT_PATH = "framework/Include/QM/QM_NewsFilter.mqh"
NEWS_FILTER_COMMIT = "5b21b9b1d4851538ddf0f62ddaa2a70db82990c3"
NEWS_FILTER_BLOB = "5b398bb428c3fe14200a779a4b393884aae0dae6"
DEFAULT_SNAPSHOT_ROOT = Path(
    r"D:\QM\audit_snapshots\QM5_10729_TV_SMC_MSS_FVG_M15_TWO_SYMBOL_FULL_DEV_001"
    r"\release_0b221d1c_2d009fa4"
)


class SnapshotError(RuntimeError):
    """The exact snapshot cannot be built without changing the release."""


def sha256_bytes(data: bytes) -> str:
    return hashlib.sha256(data).hexdigest()


def sha256_file(path: Path) -> str:
    digest = hashlib.sha256()
    with path.open("rb") as handle:
        for chunk in iter(lambda: handle.read(1024 * 1024), b""):
            digest.update(chunk)
    return digest.hexdigest()


def canonical_json(payload: Mapping[str, Any]) -> bytes:
    return (
        json.dumps(payload, sort_keys=True, ensure_ascii=False, separators=(",", ":"))
        + "\n"
    ).encode("utf-8")


def resolve_source(raw: str) -> Path:
    candidate = Path(raw)
    return candidate if candidate.is_absolute() else REPO_ROOT / PurePosixPath(raw)


def mtime_100ns(path: Path) -> str:
    nanoseconds = path.stat().st_mtime_ns
    seconds, remainder = divmod(nanoseconds, 1_000_000_000)
    current = datetime.fromtimestamp(seconds, timezone.utc)
    return f"{current:%Y-%m-%dT%H:%M:%S}.{remainder // 100:07d}Z"


def git_bytes(object_spec: str) -> bytes:
    completed = subprocess.run(
        ["git", "cat-file", "blob", object_spec],
        cwd=REPO_ROOT,
        check=False,
        stdout=subprocess.PIPE,
        stderr=subprocess.PIPE,
    )
    if completed.returncode:
        raise SnapshotError(
            f"cannot read Git object {object_spec}: "
            f"{completed.stderr.decode('utf-8', errors='replace').strip()}"
        )
    return completed.stdout


def git_blob_at(commit: str, path: str) -> str:
    completed = subprocess.run(
        ["git", "rev-parse", f"{commit}:{path}"],
        cwd=REPO_ROOT,
        check=False,
        stdout=subprocess.PIPE,
        stderr=subprocess.PIPE,
        text=True,
        encoding="utf-8",
    )
    if completed.returncode:
        raise SnapshotError(f"cannot resolve {commit}:{path}")
    return completed.stdout.strip()


def write_exact(path: Path, data: bytes) -> None:
    path.parent.mkdir(parents=True, exist_ok=True)
    with path.open("xb") as handle:
        handle.write(data)
        handle.flush()
        os.fsync(handle.fileno())


def copy_current_exact(source: Path, destination: Path, expected_sha: str) -> int:
    if not source.is_file():
        raise SnapshotError(f"source is missing: {source}")
    before = source.stat()
    destination.parent.mkdir(parents=True, exist_ok=True)
    digest = hashlib.sha256()
    with source.open("rb") as reader, destination.open("xb") as writer:
        for chunk in iter(lambda: reader.read(1024 * 1024), b""):
            digest.update(chunk)
            writer.write(chunk)
        writer.flush()
        os.fsync(writer.fileno())
    after = source.stat()
    if (before.st_size, before.st_mtime_ns) != (after.st_size, after.st_mtime_ns):
        raise SnapshotError(f"source changed during copy: {source}")
    observed = digest.hexdigest()
    if observed != expected_sha:
        raise SnapshotError(f"source hash drift: {source}: {observed} != {expected_sha}")
    if destination.stat().st_size != before.st_size or sha256_file(destination) != expected_sha:
        raise SnapshotError(f"snapshot rehash failed: {destination}")
    return before.st_size


def binding_snapshot_name(index: int, raw_path: str) -> str:
    name = Path(raw_path).name
    return f"bindings/{index:02d}_{name}"


def control_entry(
    source: Path,
    destination: Path,
    relative: str,
    expected_sha: str,
    commit: str,
    git_path: str,
) -> dict[str, Any]:
    size = copy_current_exact(source, destination, expected_sha)
    blob = git_blob_at(commit, git_path)
    raw_git = git_bytes(blob)
    if sha256_bytes(raw_git) != expected_sha:
        raise SnapshotError(f"control Git blob is not byte-exact: {git_path}")
    return {
        "snapshot_relpath": relative,
        "sha256": expected_sha,
        "bytes": size,
        "provenance": "CURRENT_EXACT",
        "source_path": str(source.resolve()),
        "git_commit": commit,
        "git_path": git_path,
        "git_blob_sha1": blob,
    }


def build_snapshot(final_root: Path) -> dict[str, Any]:
    if final_root.exists():
        raise SnapshotError(f"snapshot destination already exists: {final_root}")
    if sha256_file(CONTRACT_PATH) != EXPECTED_CONTRACT_SHA256:
        raise SnapshotError("contract hash drift")
    if sha256_file(REVIEW_PATH) != EXPECTED_REVIEW_SHA256:
        raise SnapshotError("review receipt hash drift")
    contract = json.loads(CONTRACT_PATH.read_text(encoding="utf-8"))
    review = json.loads(REVIEW_PATH.read_text(encoding="utf-8"))
    if contract.get("analysis_id") != ANALYSIS_ID:
        raise SnapshotError("analysis_id drift")
    if review.get("review_status") != "PASS":
        raise SnapshotError("review status is not PASS")
    if review.get("reviewed_contract_sha256") != EXPECTED_CONTRACT_SHA256:
        raise SnapshotError("review does not bind this contract")

    final_root.parent.mkdir(parents=True, exist_ok=True)
    temporary = Path(tempfile.mkdtemp(prefix=f".{final_root.name}.", dir=final_root.parent))
    try:
        contract_rel = "control/contract.json"
        review_rel = "control/review_receipt.json"
        contract_entry = control_entry(
            CONTRACT_PATH,
            temporary / contract_rel,
            contract_rel,
            EXPECTED_CONTRACT_SHA256,
            CONTRACT_COMMIT,
            "framework/EAs/QM5_10729_tv-smc-mss-fvg/docs/candidate-analysis/"
            "tv_smc_mss_fvg_m15_two_symbol_full_dev_contract.json",
        )
        review_entry = control_entry(
            REVIEW_PATH,
            temporary / review_rel,
            review_rel,
            EXPECTED_REVIEW_SHA256,
            REVIEW_COMMIT,
            "framework/EAs/QM5_10729_tv-smc-mss-fvg/docs/candidate-analysis/"
            "tv_smc_mss_fvg_outcome_blind_review_receipt.json",
        )

        bindings: list[dict[str, Any]] = []
        for index, (raw_path, expected_sha) in enumerate(
            contract["source_bindings"].items(), start=1
        ):
            relative = binding_snapshot_name(index, raw_path)
            destination = temporary / PurePosixPath(relative)
            if raw_path == NEWS_FILTER_CONTRACT_PATH:
                observed_blob = git_blob_at(NEWS_FILTER_COMMIT, raw_path)
                if observed_blob != NEWS_FILTER_BLOB:
                    raise SnapshotError("released NewsFilter Git blob drift")
                raw_git = git_bytes(NEWS_FILTER_BLOB)
                normalized_lf = raw_git.replace(b"\r\n", b"\n").replace(b"\r", b"\n")
                materialized = normalized_lf.replace(b"\n", b"\r\n")
                if sha256_bytes(materialized) != expected_sha:
                    raise SnapshotError("NewsFilter CRLF materialization hash mismatch")
                write_exact(destination, materialized)
                entry = {
                    "contract_path": raw_path,
                    "snapshot_relpath": relative,
                    "sha256": expected_sha,
                    "bytes": len(materialized),
                    "provenance": "GIT_BLOB_EXACT",
                    "git_commit": NEWS_FILTER_COMMIT,
                    "git_path": raw_path,
                    "git_blob_sha1": NEWS_FILTER_BLOB,
                    "git_blob_sha256": sha256_bytes(raw_git),
                    "materialization": "NORMALIZE_LF_THEN_LF_TO_CRLF",
                }
            else:
                source = resolve_source(raw_path)
                size = copy_current_exact(source, destination, expected_sha)
                entry = {
                    "contract_path": raw_path,
                    "snapshot_relpath": relative,
                    "sha256": expected_sha,
                    "bytes": size,
                    "provenance": "CURRENT_EXACT",
                    "source_path": str(source.resolve()),
                    "source_sha256_at_copy": expected_sha,
                }
            bindings.append(entry)

        market_files: list[dict[str, Any]] = []
        for symbol in sorted(contract["data_contract"]["files"]):
            spec = contract["data_contract"]["files"][symbol]
            source = Path(spec["path"])
            if source.stat().st_size != spec["file_length_bytes_at_freeze"]:
                raise SnapshotError(f"market length drift: {symbol}")
            if mtime_100ns(source) != spec["file_last_write_utc_at_freeze"]:
                raise SnapshotError(f"market last-write drift: {symbol}")
            relative = f"market/{source.name}"
            destination = temporary / PurePosixPath(relative)
            source_sha = sha256_file(source)
            size = copy_current_exact(source, destination, source_sha)
            if source.stat().st_size != spec["file_length_bytes_at_freeze"]:
                raise SnapshotError(f"market changed after copy: {symbol}")
            if mtime_100ns(source) != spec["file_last_write_utc_at_freeze"]:
                raise SnapshotError(f"market timestamp changed after copy: {symbol}")
            market_files.append(
                {
                    "symbol": symbol,
                    "contract_path": spec["path"],
                    "snapshot_relpath": relative,
                    "sha256": source_sha,
                    "bytes": size,
                    "provenance": "CURRENT_FENCE_EXACT",
                    "source_path": str(source.resolve()),
                    "source_length_bytes_at_copy": size,
                    "source_last_write_utc_at_copy": mtime_100ns(source),
                }
            )

        manifest = {
            "schema_version": 1,
            "analysis_id": ANALYSIS_ID,
            "snapshot_id": "release_0b221d1c_2d009fa4_mixed_exact_v1",
            "runtime_policy": "ALL_CONTROL_BINDING_NEWS_AND_MARKET_INPUTS_FROM_THIS_READ_ONLY_SNAPSHOT_ONLY",
            "contract": contract_entry,
            "review_receipt": review_entry,
            "source_bindings": bindings,
            "market_files": market_files,
        }
        manifest_bytes = canonical_json(manifest)
        write_exact(temporary / "manifest.json", manifest_bytes)

        for path in temporary.rglob("*"):
            if path.is_file():
                os.chmod(path, stat.S_IREAD)
        for entry in bindings:
            target = temporary / PurePosixPath(entry["snapshot_relpath"])
            if sha256_file(target) != entry["sha256"]:
                raise SnapshotError(f"post-freeze binding rehash failed: {target}")
        for entry in market_files:
            target = temporary / PurePosixPath(entry["snapshot_relpath"])
            if sha256_file(target) != entry["sha256"]:
                raise SnapshotError(f"post-freeze market rehash failed: {target}")
        if sha256_file(temporary / contract_rel) != EXPECTED_CONTRACT_SHA256:
            raise SnapshotError("post-freeze contract rehash failed")
        if sha256_file(temporary / review_rel) != EXPECTED_REVIEW_SHA256:
            raise SnapshotError("post-freeze review rehash failed")
        manifest_sha = sha256_file(temporary / "manifest.json")
        temporary.rename(final_root)
        return {
            "status": "PASS",
            "snapshot_root": str(final_root.resolve()),
            "manifest": str((final_root / "manifest.json").resolve()),
            "manifest_sha256": manifest_sha,
            "source_bindings": len(bindings),
            "current_exact": sum(
                entry["provenance"] == "CURRENT_EXACT" for entry in bindings
            ),
            "git_blob_exact": sum(
                entry["provenance"] == "GIT_BLOB_EXACT" for entry in bindings
            ),
            "market_files": len(market_files),
        }
    except Exception:
        shutil.rmtree(temporary, ignore_errors=True)
        raise


def build_parser() -> argparse.ArgumentParser:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--snapshot-root", type=Path, default=DEFAULT_SNAPSHOT_ROOT)
    return parser


def main() -> int:
    args = build_parser().parse_args()
    try:
        print(json.dumps(build_snapshot(args.snapshot_root), sort_keys=True))
        return 0
    except (SnapshotError, OSError, ValueError, KeyError, json.JSONDecodeError) as exc:
        print(
            json.dumps(
                {
                    "status": "REJECT",
                    "error_type": type(exc).__name__,
                    "error": str(exc),
                },
                sort_keys=True,
            )
        )
        return 2


if __name__ == "__main__":
    raise SystemExit(main())
