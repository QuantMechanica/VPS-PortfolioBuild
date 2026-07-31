#!/usr/bin/env python3
"""Build and self-verify canonical Factory runtime-activation artifacts.

The builder is fail-closed.  It requires a clean repository, a still-live
preparation authorization, the exact committed preparation/source cohort, and
an exact schema-v2 OFF record.  Candidate artifacts are passed through the
runtime validator before they replace the canonical outputs.
"""

from __future__ import annotations

import argparse
import datetime as dt
import hashlib
import json
import os
import re
import secrets
import subprocess
import sys
import tempfile
from pathlib import Path
from typing import Any

import factory_runtime_activation as fra


DEFAULT_REPO_ROOT = Path(r"C:\QM\repo")
DEFAULT_FLAG = Path(r"D:\QM\strategy_farm\state\FACTORY_OFF.flag")
TEMPLATE_RELATIVE_PATH = Path(
    "tools/strategy_farm/factory_runtime_activation.v1.template.json"
)

EXIT_PRECONDITION = 3
EXIT_SELF_VERIFICATION = 4
EXIT_PUBLICATION = 5
EXIT_INTERNAL = 10

DECISION_ID_RE = re.compile(r"[A-Za-z0-9][A-Za-z0-9_.:-]{0,199}")


class DecisionBuildError(RuntimeError):
    """A classified, operator-facing fail-closed builder error."""

    def __init__(self, message: str, *, exit_code: int, category: str) -> None:
        super().__init__(message)
        self.exit_code = exit_code
        self.category = category


def _sha256(raw: bytes) -> str:
    return hashlib.sha256(raw).hexdigest()


def _git_blob(raw: bytes) -> str:
    return hashlib.sha1(
        f"blob {len(raw)}\0".encode("ascii") + raw,
        usedforsecurity=False,
    ).hexdigest()


def _git(repo_root: Path, *args: str) -> str:
    try:
        result = subprocess.run(
            ("git", "-C", str(repo_root), *args),
            capture_output=True,
            text=True,
            encoding="utf-8",
            errors="strict",
            timeout=20,
            check=False,
        )
    except (OSError, subprocess.SubprocessError, UnicodeError) as exc:
        raise DecisionBuildError(
            f"Git precondition probe failed: {exc}",
            exit_code=EXIT_PRECONDITION,
            category="PRECONDITION",
        ) from exc
    if result.returncode != 0:
        raise DecisionBuildError(
            f"Git precondition probe failed ({' '.join(args)}): "
            f"{result.stderr.strip()}",
            exit_code=EXIT_PRECONDITION,
            category="PRECONDITION",
        )
    return result.stdout.strip()


def _git_bytes(repo_root: Path, *args: str) -> bytes:
    try:
        result = subprocess.run(
            ("git", "-C", str(repo_root), *args),
            capture_output=True,
            timeout=20,
            check=False,
        )
    except (OSError, subprocess.SubprocessError) as exc:
        raise DecisionBuildError(
            f"Git blob read failed: {exc}",
            exit_code=EXIT_PRECONDITION,
            category="PRECONDITION",
        ) from exc
    if result.returncode != 0:
        stderr = result.stderr.decode("utf-8", errors="replace").strip()
        raise DecisionBuildError(
            f"Git blob read failed ({' '.join(args)}): {stderr}",
            exit_code=EXIT_PRECONDITION,
            category="PRECONDITION",
        )
    return result.stdout


def _read_bytes(path: Path, *, label: str) -> bytes:
    try:
        return path.read_bytes()
    except OSError as exc:
        raise DecisionBuildError(
            f"{label} cannot be read: {path}: {exc}",
            exit_code=EXIT_PRECONDITION,
            category="PRECONDITION",
        ) from exc


def _load_json(path: Path, *, label: str) -> tuple[bytes, dict[str, Any]]:
    raw = _read_bytes(path, label=label)
    try:
        payload = fra._load_json(raw, label=label)
    except fra.RuntimeActivationError as exc:
        raise DecisionBuildError(
            str(exc),
            exit_code=EXIT_PRECONDITION,
            category="PRECONDITION",
        ) from exc
    return raw, payload


def _require(condition: bool, message: str) -> None:
    if not condition:
        raise DecisionBuildError(
            message,
            exit_code=EXIT_PRECONDITION,
            category="PRECONDITION",
        )


def _normalize_now(now_utc: dt.datetime | None) -> dt.datetime:
    now = now_utc or dt.datetime.now(dt.UTC)
    _require(now.tzinfo is not None, "builder now_utc must be timezone-aware")
    return now.astimezone(dt.UTC).replace(microsecond=0)


def _verify_preparation_window(
    preparation: dict[str, Any],
    *,
    now_utc: dt.datetime,
) -> None:
    restore_intent = preparation.get("restore_intent")
    _require(
        isinstance(restore_intent, dict)
        and restore_intent.get("manifest_creation_authorized_after_prerequisites")
        is True,
        "preparation decision does not authorize runtime-manifest creation",
    )
    try:
        authorized_at = fra._parse_utc(
            preparation.get("authorized_at_utc"),
            label="preparation authorized_at_utc",
        )
        expires_at = fra._parse_utc(
            preparation.get("authorization_expires_at_utc"),
            label="preparation authorization_expires_at_utc",
        )
    except fra.RuntimeActivationError as exc:
        raise DecisionBuildError(
            str(exc),
            exit_code=EXIT_PRECONDITION,
            category="PRECONDITION",
        ) from exc
    _require(
        authorized_at <= now_utc < expires_at,
        "preparation authorization window is not active; refusing to mint "
        "new runtime authority",
    )


def _source_bindings(repo_root: Path, *, head: str) -> dict[str, dict[str, str]]:
    bindings: dict[str, dict[str, str]] = {}
    for label, relative_path in fra.SOURCE_BINDING_PATHS.items():
        path = repo_root / relative_path
        raw = _read_bytes(path, label=f"source binding {label}")
        committed_blob = _git(
            repo_root,
            "rev-parse",
            f"{head}:{relative_path.as_posix()}",
        )
        blob = _git_blob(raw)
        if committed_blob != blob:
            # core.autocrlf=true can smudge checkout bytes to CRLF while Git
            # reports a clean tree.  Runtime validation binds raw bytes, so
            # preserve the established binary-safe normalization to HEAD blobs.
            blob_bytes = _git_bytes(
                repo_root,
                "cat-file",
                "blob",
                f"{head}:{relative_path.as_posix()}",
            )
            _require(
                _git_blob(blob_bytes) == committed_blob,
                f"{relative_path.as_posix()}: git cat-file blob mismatch",
            )
            try:
                path.write_bytes(blob_bytes)
            except OSError as exc:
                raise DecisionBuildError(
                    f"cannot normalize {relative_path.as_posix()} to committed "
                    f"blob bytes: {exc}",
                    exit_code=EXIT_PRECONDITION,
                    category="PRECONDITION",
                ) from exc
            raw = _read_bytes(path, label=f"normalized source binding {label}")
            blob = _git_blob(raw)
        _require(
            committed_blob == blob,
            f"{relative_path.as_posix()}: worktree bytes do not equal HEAD blob",
        )
        bindings[label] = {
            "relative_path": relative_path.as_posix(),
            "sha256": _sha256(raw),
            "git_commit": head,
            "git_blob": blob,
        }
    return bindings


def _restore_artifact(path: Path, prior: bytes | None, *, scratch: Path) -> None:
    if prior is None:
        path.unlink(missing_ok=True)
        return
    rollback_path = scratch / f"rollback-{path.name}"
    rollback_path.write_bytes(prior)
    os.replace(rollback_path, path)


def _publish_and_verify(
    *,
    repo_root: Path,
    flag_path: Path,
    now_utc: dt.datetime,
    candidate_decision: Path,
    candidate_digest: Path,
    scratch: Path,
) -> dict[str, Any]:
    decision_path = repo_root / fra.DECISION_RELATIVE_PATH
    digest_path = repo_root / fra.DIGEST_RELATIVE_PATH
    decision_path.parent.mkdir(parents=True, exist_ok=True)
    prior_decision = decision_path.read_bytes() if decision_path.exists() else None
    prior_digest = digest_path.read_bytes() if digest_path.exists() else None
    try:
        os.replace(candidate_decision, decision_path)
        os.replace(candidate_digest, digest_path)
        return fra.validate_runtime_activation_candidate(
            repo_root=repo_root,
            decision_path=decision_path,
            digest_path=digest_path,
            factory_off_flag=flag_path,
            now_utc=now_utc,
        )
    except (OSError, fra.RuntimeActivationError) as exc:
        rollback_errors: list[str] = []
        for path, prior in (
            (decision_path, prior_decision),
            (digest_path, prior_digest),
        ):
            try:
                _restore_artifact(path, prior, scratch=scratch)
            except OSError as rollback_exc:
                rollback_errors.append(f"{path}: {rollback_exc}")
        suffix = (
            f"; rollback errors: {'; '.join(rollback_errors)}"
            if rollback_errors
            else ""
        )
        raise DecisionBuildError(
            f"artifact publication/self-verification failed: {exc}{suffix}",
            exit_code=EXIT_PUBLICATION,
            category="PUBLICATION",
        ) from exc


def build_runtime_activation_decision(
    *,
    repo_root: Path,
    flag_path: Path,
    decision_id: str,
    now_utc: dt.datetime | None = None,
) -> dict[str, Any]:
    repo_root = Path(repo_root).resolve()
    flag_path = Path(flag_path).resolve()
    now = _normalize_now(now_utc)
    _require(
        DECISION_ID_RE.fullmatch(decision_id) is not None,
        "decision-id must be 1-200 characters using letters, digits, '.', '_', "
        "':' or '-'",
    )
    top_level = Path(_git(repo_root, "rev-parse", "--show-toplevel")).resolve()
    _require(top_level == repo_root, f"repo-root is not the Git top level: {repo_root}")
    dirty = _git(repo_root, "status", "--porcelain", "--untracked-files=all")
    _require(dirty == "", f"repository is dirty before binding: {dirty!r}")

    try:
        fra._verify_committed_file(
            repo_root,
            fra.PREPARATION_DECISION_RELATIVE_PATH,
            expected_sha256=fra.PREPARATION_DECISION_SHA256,
            expected_commit=fra.PREPARATION_DECISION_COMMIT,
            expected_blob=fra.PREPARATION_DECISION_BLOB,
        )
    except fra.RuntimeActivationError as exc:
        raise DecisionBuildError(
            f"preparation provenance failed: {exc}",
            exit_code=EXIT_PRECONDITION,
            category="PRECONDITION",
        ) from exc
    _, preparation = _load_json(
        repo_root / fra.PREPARATION_DECISION_RELATIVE_PATH,
        label="preparation decision",
    )
    _verify_preparation_window(preparation, now_utc=now)

    _, template = _load_json(
        repo_root / TEMPLATE_RELATIVE_PATH,
        label="runtime activation template",
    )
    restore_intent = preparation.get("restore_intent")
    task_map = (
        restore_intent.get("task_enabled_before")
        if isinstance(restore_intent, dict)
        else None
    )
    _require(
        isinstance(task_map, dict)
        and len(task_map) == 21
        and all(
            isinstance(task_name, str) and isinstance(enabled, bool)
            for task_name, enabled in task_map.items()
        ),
        "preparation decision lacks the exact 21-task boolean map",
    )
    task_map_sha256 = _sha256(
        json.dumps(task_map, sort_keys=True, separators=(",", ":")).encode("utf-8")
    )
    template_restore = template.get("restore_intent")
    _require(
        isinstance(template_restore, dict)
        and template_restore.get("task_enabled_before_sha256")
        == task_map_sha256,
        f"task-map SHA-256 does not match the template pin: {task_map_sha256}",
    )

    flag_raw = _read_bytes(flag_path, label="FACTORY_OFF record")
    try:
        flag = fra._load_json(
            flag_raw.removeprefix(b"\xef\xbb\xbf"),
            label="FACTORY_OFF record",
        )
    except fra.RuntimeActivationError as exc:
        raise DecisionBuildError(
            str(exc),
            exit_code=EXIT_PRECONDITION,
            category="PRECONDITION",
        ) from exc
    _require(
        flag.get("schema_version") == 2 and flag.get("state") == "OFF",
        "FACTORY_OFF record is not exact schema-v2 OFF state",
    )
    _require(
        flag.get("task_enabled_before") == task_map,
        "FACTORY_OFF task map does not equal the approved preparation map",
    )
    flag_sha256 = _sha256(flag_raw)

    head = _git(repo_root, "rev-parse", "HEAD")
    source_bindings = _source_bindings(repo_root, head=head)
    # A raw LF rewrite under core.autocrlf=true can leave Git's cached
    # worktree-size metadata reporting " M" even though the clean-filtered
    # content is byte-identical to the index.  Content diffs are authoritative
    # here; the initial porcelain check already rejected staged/untracked work.
    dirty_after_normalization = _git(repo_root, "diff", "--name-only")
    staged_after_normalization = _git(
        repo_root,
        "diff",
        "--cached",
        "--name-only",
    )
    untracked_after_normalization = _git(
        repo_root,
        "ls-files",
        "--others",
        "--exclude-standard",
    )
    _require(
        dirty_after_normalization == ""
        and staged_after_normalization == ""
        and untracked_after_normalization == "",
        "repository content changed while normalizing source-binding bytes: "
        f"worktree={dirty_after_normalization!r} "
        f"index={staged_after_normalization!r} "
        f"untracked={untracked_after_normalization!r}",
    )

    payload = template
    payload["decision_id"] = decision_id
    payload["activation_nonce"] = secrets.token_hex(16)
    payload["authorized_at_utc"] = now.strftime("%Y-%m-%dT%H:%M:%SZ")
    payload["expires_at_utc"] = (now + dt.timedelta(hours=24)).strftime(
        "%Y-%m-%dT%H:%M:%SZ"
    )
    payload["restore_intent"]["factory_off_flag_sha256"] = flag_sha256
    payload["restore_intent"]["task_enabled_before_sha256"] = task_map_sha256
    payload["source_bindings"] = source_bindings

    decision_bytes = (json.dumps(payload, indent=2) + "\n").encode("utf-8")
    decision_sha256 = _sha256(decision_bytes)
    digest_bytes = (
        f"{decision_sha256}  {fra.DECISION_RELATIVE_PATH.name}\n"
    ).encode("ascii")

    git_dir = Path(_git(repo_root, "rev-parse", "--absolute-git-dir")).resolve()
    try:
        with tempfile.TemporaryDirectory(
            prefix="factory-runtime-activation-",
            dir=git_dir,
        ) as temporary_directory:
            scratch = Path(temporary_directory)
            candidate_decision = scratch / fra.DECISION_RELATIVE_PATH.name
            candidate_digest = scratch / fra.DIGEST_RELATIVE_PATH.name
            candidate_decision.write_bytes(decision_bytes)
            candidate_digest.write_bytes(digest_bytes)
            try:
                candidate_result = fra.validate_runtime_activation_candidate(
                    repo_root=repo_root,
                    decision_path=candidate_decision,
                    digest_path=candidate_digest,
                    factory_off_flag=flag_path,
                    now_utc=now,
                )
            except fra.RuntimeActivationError as exc:
                raise DecisionBuildError(
                    f"candidate self-verification failed: {exc}",
                    exit_code=EXIT_SELF_VERIFICATION,
                    category="SELF_VERIFICATION",
                ) from exc
            published_result = _publish_and_verify(
                repo_root=repo_root,
                flag_path=flag_path,
                now_utc=now,
                candidate_decision=candidate_decision,
                candidate_digest=candidate_digest,
                scratch=scratch,
            )
    except DecisionBuildError:
        raise
    except OSError as exc:
        raise DecisionBuildError(
            f"candidate staging failed: {exc}",
            exit_code=EXIT_PUBLICATION,
            category="PUBLICATION",
        ) from exc

    return {
        "built": True,
        "decision_id": decision_id,
        "decision_sha256": decision_sha256,
        "flag_sha256": flag_sha256,
        "task_map_sha256": task_map_sha256,
        "authorized_at_utc": payload["authorized_at_utc"],
        "expires_at_utc": payload["expires_at_utc"],
        "source_binding_head": head,
        "candidate_validated": candidate_result["candidate_validated"],
        "published_validated": published_result["candidate_validated"],
    }


def build_parser() -> argparse.ArgumentParser:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--repo-root", type=Path, default=DEFAULT_REPO_ROOT)
    parser.add_argument("--flag", type=Path, default=DEFAULT_FLAG)
    parser.add_argument("--decision-id", required=True)
    return parser


def main(argv: list[str] | None = None) -> int:
    args = build_parser().parse_args(argv)
    try:
        result = build_runtime_activation_decision(
            repo_root=args.repo_root,
            flag_path=args.flag,
            decision_id=args.decision_id,
        )
    except DecisionBuildError as exc:
        print(
            json.dumps(
                {
                    "built": False,
                    "category": exc.category,
                    "error": str(exc),
                    "exit_code": exc.exit_code,
                },
                sort_keys=True,
                separators=(",", ":"),
            ),
            file=sys.stderr,
        )
        return exc.exit_code
    except Exception as exc:  # pragma: no cover - last-resort classified failure
        print(
            json.dumps(
                {
                    "built": False,
                    "category": "INTERNAL",
                    "error": str(exc),
                    "exit_code": EXIT_INTERNAL,
                },
                sort_keys=True,
                separators=(",", ":"),
            ),
            file=sys.stderr,
        )
        return EXIT_INTERNAL
    print(json.dumps(result, sort_keys=True, separators=(",", ":")))
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
