"""Content-addressed, immutable execution-bundle v1 contract.

This module is deliberately not wired to the factory, database, MT5, or any
pipeline runner.  It only builds, validates, loads, verifies, and create-new
writes deterministic evidence bundles.

Paths in a bundle are logical paths below an explicit artifact root.  Every
such path is paired with a SHA-256 digest; the include-root path is paired with
a digest of the complete, recursively sorted file manifest.  The bundle ID is
the SHA-256 of canonical JSON for the complete payload except ``bundle_id``.
"""

from __future__ import annotations

import hashlib
import json
import os
import re
from pathlib import Path, PurePosixPath
from typing import Any, Mapping, Sequence


SCHEMA_VERSION = "qm.execution-bundle/v1"
SHA256_RE = re.compile(r"^[0-9a-f]{64}$")
GIT_OBJECT_RE = re.compile(r"^(?:[0-9a-f]{40}|[0-9a-f]{64})$")


class ExecutionBundleError(ValueError):
    """The supplied bundle or builder input violates the v1 contract."""


def _reject_duplicate_keys(pairs: list[tuple[str, Any]]) -> dict[str, Any]:
    result: dict[str, Any] = {}
    for key, value in pairs:
        if key in result:
            raise ExecutionBundleError(f"duplicate JSON key rejected: {key}")
        result[key] = value
    return result


def _reject_float(_value: str) -> Any:
    raise ExecutionBundleError("JSON floating-point values are forbidden")


def _reject_constant(value: str) -> Any:
    raise ExecutionBundleError(f"non-finite JSON value is forbidden: {value}")


def _assert_no_floats(value: Any, context: str = "payload") -> None:
    if isinstance(value, float):
        raise ExecutionBundleError(f"floating-point value forbidden at {context}")
    if isinstance(value, Mapping):
        for key, child in value.items():
            if not isinstance(key, str):
                raise ExecutionBundleError(f"non-string object key at {context}")
            _assert_no_floats(child, f"{context}.{key}")
    elif isinstance(value, (list, tuple)):
        for index, child in enumerate(value):
            _assert_no_floats(child, f"{context}[{index}]")


def canonical_json_bytes(value: Any) -> bytes:
    """Return the single canonical byte representation used by v1 hashes."""

    _assert_no_floats(value)
    try:
        text = json.dumps(
            value,
            ensure_ascii=False,
            sort_keys=True,
            separators=(",", ":"),
            allow_nan=False,
        )
    except (TypeError, ValueError) as exc:
        raise ExecutionBundleError(f"payload is not canonical-JSON compatible: {exc}") from exc
    return text.encode("utf-8")


def canonical_sha256(value: Any) -> str:
    return hashlib.sha256(canonical_json_bytes(value)).hexdigest()


def sha256_file(path: Path) -> str:
    digest = hashlib.sha256()
    with Path(path).open("rb") as handle:
        for block in iter(lambda: handle.read(1024 * 1024), b""):
            digest.update(block)
    return digest.hexdigest()


def _require_exact_object(value: Any, keys: set[str], context: str) -> dict[str, Any]:
    if type(value) is not dict:
        raise ExecutionBundleError(f"{context} must be an object")
    actual = set(value)
    if actual != keys:
        missing = sorted(keys - actual)
        extra = sorted(actual - keys)
        raise ExecutionBundleError(
            f"{context} key set mismatch (missing={missing}, extra={extra})"
        )
    return value


def _require_nonempty_string(value: Any, context: str) -> str:
    if not isinstance(value, str) or not value or value.strip() != value:
        raise ExecutionBundleError(f"{context} must be a non-empty, trimmed string")
    return value


def _validate_sha256(value: Any, context: str) -> str:
    if not isinstance(value, str) or SHA256_RE.fullmatch(value) is None:
        raise ExecutionBundleError(f"{context} must be a lowercase SHA-256 hex digest")
    return value


def _validate_git_object(value: Any, context: str) -> str:
    if not isinstance(value, str) or GIT_OBJECT_RE.fullmatch(value) is None:
        raise ExecutionBundleError(
            f"{context} must be a lowercase 40- or 64-character Git object ID"
        )
    return value


def _validate_logical_path(value: Any, context: str) -> str:
    if not isinstance(value, str) or not value or value.strip() != value:
        raise ExecutionBundleError(f"{context} must be a non-empty, trimmed path")
    if "\\" in value or "\x00" in value or value.startswith("/") or value.endswith("/"):
        raise ExecutionBundleError(f"{context} must be a normalized relative POSIX path")
    if re.match(r"^[A-Za-z]:", value) or "//" in value:
        raise ExecutionBundleError(f"{context} must be a normalized relative POSIX path")
    logical = PurePosixPath(value)
    if any(part in {"", ".", ".."} for part in logical.parts):
        raise ExecutionBundleError(f"{context} contains a forbidden path segment")
    if logical.is_absolute() or logical.as_posix() != value:
        raise ExecutionBundleError(f"{context} must be a normalized relative POSIX path")
    return value


def _validate_artifact(value: Any, context: str) -> dict[str, Any]:
    artifact = _require_exact_object(value, {"path", "sha256"}, context)
    _validate_logical_path(artifact["path"], f"{context}.path")
    _validate_sha256(artifact["sha256"], f"{context}.sha256")
    return artifact


def _validate_versioned_artifact(value: Any, context: str) -> dict[str, Any]:
    artifact = _require_exact_object(value, {"version", "path", "sha256"}, context)
    _require_nonempty_string(artifact["version"], f"{context}.version")
    _validate_logical_path(artifact["path"], f"{context}.path")
    _validate_sha256(artifact["sha256"], f"{context}.sha256")
    return artifact


def _validate_tool_build(value: Any, context: str) -> dict[str, Any]:
    tool = _require_exact_object(value, {"build", "version", "binary"}, context)
    if type(tool["build"]) is not int or tool["build"] <= 0:
        raise ExecutionBundleError(f"{context}.build must be a positive integer")
    _require_nonempty_string(tool["version"], f"{context}.version")
    _validate_artifact(tool["binary"], f"{context}.binary")
    return tool


def _effective_inputs(parameters: Mapping[str, str]) -> dict[str, Any]:
    if not isinstance(parameters, Mapping) or not parameters:
        raise ExecutionBundleError("effective_tester_inputs must be a non-empty mapping")
    rows: list[dict[str, str]] = []
    for name, value in parameters.items():
        _require_nonempty_string(name, "effective_tester_inputs name")
        if not isinstance(value, str):
            raise ExecutionBundleError(
                f"effective_tester_inputs[{name!r}] must be an exact string value"
            )
        rows.append({"name": name, "value": value})
    rows.sort(key=lambda row: row["name"])
    return {"parameters": rows, "sha256": canonical_sha256(rows)}


def _validate_effective_inputs(value: Any) -> dict[str, Any]:
    inputs = _require_exact_object(value, {"parameters", "sha256"}, "tester.effective_inputs")
    parameters = inputs["parameters"]
    if type(parameters) is not list or not parameters:
        raise ExecutionBundleError("tester.effective_inputs.parameters must be a non-empty array")
    names: list[str] = []
    for index, raw in enumerate(parameters):
        row = _require_exact_object(
            raw, {"name", "value"}, f"tester.effective_inputs.parameters[{index}]"
        )
        name = _require_nonempty_string(
            row["name"], f"tester.effective_inputs.parameters[{index}].name"
        )
        if not isinstance(row["value"], str):
            raise ExecutionBundleError(
                f"tester.effective_inputs.parameters[{index}].value must be a string"
            )
        names.append(name)
    if names != sorted(names) or len(names) != len(set(names)):
        raise ExecutionBundleError(
            "tester.effective_inputs.parameters must be uniquely sorted by name"
        )
    declared = _validate_sha256(inputs["sha256"], "tester.effective_inputs.sha256")
    actual = canonical_sha256(parameters)
    if declared != actual:
        raise ExecutionBundleError("tester.effective_inputs.sha256 mismatch")
    return inputs


def _validate_include_tree(value: Any) -> dict[str, Any]:
    tree = _require_exact_object(
        value, {"root_path", "tree_sha256", "files"}, "source.include_tree"
    )
    _validate_logical_path(tree["root_path"], "source.include_tree.root_path")
    files = tree["files"]
    if type(files) is not list:
        raise ExecutionBundleError("source.include_tree.files must be an array")
    paths: list[str] = []
    for index, raw in enumerate(files):
        artifact = _validate_artifact(raw, f"source.include_tree.files[{index}]")
        paths.append(artifact["path"])
    if paths != sorted(paths) or len(paths) != len(set(paths)):
        raise ExecutionBundleError("source.include_tree.files must be uniquely sorted by path")
    root_prefix = tree["root_path"] + "/"
    if any(not path.startswith(root_prefix) for path in paths):
        raise ExecutionBundleError("include-tree file is outside source.include_tree.root_path")
    declared = _validate_sha256(tree["tree_sha256"], "source.include_tree.tree_sha256")
    actual = canonical_sha256(files)
    if declared != actual:
        raise ExecutionBundleError("source.include_tree.tree_sha256 mismatch")
    return tree


def _unsigned_payload(bundle: Mapping[str, Any]) -> dict[str, Any]:
    return {key: value for key, value in bundle.items() if key != "bundle_id"}


def validate_execution_bundle(bundle: Any) -> dict[str, Any]:
    """Validate every v1 structural and self-hash invariant, fail-closed."""

    _assert_no_floats(bundle)
    root = _require_exact_object(
        bundle,
        {
            "schema_version",
            "git",
            "strategy_card",
            "source",
            "tester",
            "rulepack",
            "bundle_id",
        },
        "execution bundle",
    )
    if root["schema_version"] != SCHEMA_VERSION:
        raise ExecutionBundleError(f"unsupported schema_version: {root['schema_version']!r}")

    git = _require_exact_object(root["git"], {"commit_sha", "tree_sha"}, "git")
    _validate_git_object(git["commit_sha"], "git.commit_sha")
    _validate_git_object(git["tree_sha"], "git.tree_sha")
    _validate_artifact(root["strategy_card"], "strategy_card")

    source = _require_exact_object(root["source"], {"mq5", "include_tree", "ex5"}, "source")
    _validate_artifact(source["mq5"], "source.mq5")
    _validate_include_tree(source["include_tree"])
    _validate_artifact(source["ex5"], "source.ex5")

    tester = _require_exact_object(
        root["tester"],
        {
            "setfile",
            "effective_inputs",
            "compiler",
            "terminal",
            "symbol_spec_snapshot",
            "history_snapshot",
            "cost_model",
            "calendar_bundle",
        },
        "tester",
    )
    _validate_artifact(tester["setfile"], "tester.setfile")
    _validate_effective_inputs(tester["effective_inputs"])
    _validate_tool_build(tester["compiler"], "tester.compiler")
    _validate_tool_build(tester["terminal"], "tester.terminal")
    for key in (
        "symbol_spec_snapshot",
        "history_snapshot",
        "cost_model",
        "calendar_bundle",
    ):
        _validate_artifact(tester[key], f"tester.{key}")
    _validate_versioned_artifact(root["rulepack"], "rulepack")

    declared_id = _validate_sha256(root["bundle_id"], "bundle_id")
    actual_id = canonical_sha256(_unsigned_payload(root))
    if declared_id != actual_id:
        raise ExecutionBundleError("bundle_id mismatch")
    return root


def _strict_json_load(raw: bytes) -> Any:
    try:
        text = raw.decode("utf-8")
        return json.loads(
            text,
            object_pairs_hook=_reject_duplicate_keys,
            parse_float=_reject_float,
            parse_constant=_reject_constant,
        )
    except ExecutionBundleError:
        raise
    except (UnicodeError, json.JSONDecodeError) as exc:
        raise ExecutionBundleError(f"invalid execution-bundle JSON: {exc}") from exc


def load_execution_bundle(path: Path, *, artifact_root: Path | None = None) -> dict[str, Any]:
    """Load strict JSON, validate self-hashes, and optionally verify bound files."""

    bundle = validate_execution_bundle(_strict_json_load(Path(path).read_bytes()))
    if artifact_root is not None:
        verify_referenced_artifacts(bundle, artifact_root)
    return bundle


def _root_directory(path: Path) -> Path:
    candidate = Path(path)
    if candidate.is_symlink() or not candidate.is_dir():
        raise ExecutionBundleError(f"artifact_root must be a non-symlink directory: {candidate}")
    return candidate.resolve(strict=True)


def _bound_file(root: Path, logical_path: str) -> Path:
    _validate_logical_path(logical_path, "artifact path")
    current = root
    for part in PurePosixPath(logical_path).parts:
        current = current / part
        if current.is_symlink():
            raise ExecutionBundleError(f"symlink artifact path rejected: {logical_path}")
    try:
        resolved = current.resolve(strict=True)
    except FileNotFoundError as exc:
        raise ExecutionBundleError(f"bound artifact does not exist: {logical_path}") from exc
    if not resolved.is_relative_to(root) or not resolved.is_file():
        raise ExecutionBundleError(f"bound artifact is not a regular file: {logical_path}")
    return resolved


def _logical_path(root: Path, path: Path, context: str) -> str:
    candidate = Path(path)
    if not candidate.is_absolute():
        candidate = root / candidate
    try:
        resolved = candidate.resolve(strict=True)
    except FileNotFoundError as exc:
        raise ExecutionBundleError(f"{context} does not exist: {candidate}") from exc
    if not resolved.is_relative_to(root):
        raise ExecutionBundleError(f"{context} is outside artifact_root: {candidate}")
    relative = resolved.relative_to(root).as_posix()
    _bound_file(root, relative)
    return _validate_logical_path(relative, context)


def _artifact_from_path(root: Path, path: Path, context: str) -> dict[str, str]:
    logical = _logical_path(root, path, context)
    return {"path": logical, "sha256": sha256_file(_bound_file(root, logical))}


def _include_manifest(root: Path, include_root: Path) -> dict[str, Any]:
    candidate = Path(include_root)
    if not candidate.is_absolute():
        candidate = root / candidate
    try:
        resolved = candidate.resolve(strict=True)
    except FileNotFoundError as exc:
        raise ExecutionBundleError(f"include_root does not exist: {candidate}") from exc
    if not resolved.is_relative_to(root) or not resolved.is_dir() or candidate.is_symlink():
        raise ExecutionBundleError("include_root must be a non-symlink directory below artifact_root")
    root_path = _validate_logical_path(resolved.relative_to(root).as_posix(), "include_root")

    files: list[dict[str, str]] = []

    def visit(directory: Path) -> None:
        for child in sorted(directory.iterdir(), key=lambda item: item.name):
            if child.is_symlink():
                raise ExecutionBundleError(f"symlink in include tree rejected: {child}")
            if child.is_dir():
                visit(child)
            elif child.is_file():
                files.append(_artifact_from_path(root, child, "include-tree file"))
            else:
                raise ExecutionBundleError(f"non-regular include-tree entry rejected: {child}")

    visit(resolved)
    files.sort(key=lambda row: row["path"])
    return {
        "root_path": root_path,
        "tree_sha256": canonical_sha256(files),
        "files": files,
    }


def build_execution_bundle(
    *,
    artifact_root: Path,
    git_commit_sha: str,
    git_tree_sha: str,
    strategy_card_path: Path,
    mq5_path: Path,
    include_root: Path,
    ex5_path: Path,
    setfile_path: Path,
    effective_tester_inputs: Mapping[str, str],
    compiler_build: int,
    compiler_version: str,
    compiler_binary_path: Path,
    terminal_build: int,
    terminal_version: str,
    terminal_binary_path: Path,
    symbol_spec_snapshot_path: Path,
    history_snapshot_path: Path,
    cost_model_path: Path,
    calendar_bundle_path: Path,
    rulepack_version: str,
    rulepack_path: Path,
) -> dict[str, Any]:
    """Build a deterministic bundle from bytes below ``artifact_root``."""

    root = _root_directory(artifact_root)
    payload: dict[str, Any] = {
        "schema_version": SCHEMA_VERSION,
        "git": {"commit_sha": git_commit_sha, "tree_sha": git_tree_sha},
        "strategy_card": _artifact_from_path(root, strategy_card_path, "strategy_card_path"),
        "source": {
            "mq5": _artifact_from_path(root, mq5_path, "mq5_path"),
            "include_tree": _include_manifest(root, include_root),
            "ex5": _artifact_from_path(root, ex5_path, "ex5_path"),
        },
        "tester": {
            "setfile": _artifact_from_path(root, setfile_path, "setfile_path"),
            "effective_inputs": _effective_inputs(effective_tester_inputs),
            "compiler": {
                "build": compiler_build,
                "version": compiler_version,
                "binary": _artifact_from_path(
                    root, compiler_binary_path, "compiler_binary_path"
                ),
            },
            "terminal": {
                "build": terminal_build,
                "version": terminal_version,
                "binary": _artifact_from_path(
                    root, terminal_binary_path, "terminal_binary_path"
                ),
            },
            "symbol_spec_snapshot": _artifact_from_path(
                root, symbol_spec_snapshot_path, "symbol_spec_snapshot_path"
            ),
            "history_snapshot": _artifact_from_path(
                root, history_snapshot_path, "history_snapshot_path"
            ),
            "cost_model": _artifact_from_path(root, cost_model_path, "cost_model_path"),
            "calendar_bundle": _artifact_from_path(
                root, calendar_bundle_path, "calendar_bundle_path"
            ),
        },
        "rulepack": {
            "version": rulepack_version,
            **_artifact_from_path(root, rulepack_path, "rulepack_path"),
        },
    }
    payload["bundle_id"] = canonical_sha256(payload)
    validate_execution_bundle(payload)
    verify_referenced_artifacts(payload, root)
    return payload


def _all_artifacts(bundle: Mapping[str, Any]) -> Sequence[Mapping[str, str]]:
    source = bundle["source"]
    tester = bundle["tester"]
    rows: list[Mapping[str, str]] = [
        bundle["strategy_card"],
        source["mq5"],
        *source["include_tree"]["files"],
        source["ex5"],
        tester["setfile"],
        tester["compiler"]["binary"],
        tester["terminal"]["binary"],
        tester["symbol_spec_snapshot"],
        tester["history_snapshot"],
        tester["cost_model"],
        tester["calendar_bundle"],
        bundle["rulepack"],
    ]
    return rows


def verify_referenced_artifacts(bundle: Any, artifact_root: Path) -> None:
    """Verify bytes and exact recursive include-tree membership against a root."""

    root_bundle = validate_execution_bundle(bundle)
    root = _root_directory(artifact_root)
    for artifact in _all_artifacts(root_bundle):
        path = artifact["path"]
        actual = sha256_file(_bound_file(root, path))
        if actual != artifact["sha256"]:
            raise ExecutionBundleError(f"artifact SHA-256 mismatch: {path}")

    declared_tree = root_bundle["source"]["include_tree"]
    actual_tree = _include_manifest(root, root / declared_tree["root_path"])
    if actual_tree != declared_tree:
        raise ExecutionBundleError("include-tree membership or content drift")


def write_execution_bundle_create_new(bundle: Any, path: Path) -> Path:
    """Create an immutable bundle file; an existing destination is never replaced."""

    validated = validate_execution_bundle(bundle)
    output = Path(path)
    data = canonical_json_bytes(validated) + b"\n"
    flags = os.O_WRONLY | os.O_CREAT | os.O_EXCL | getattr(os, "O_BINARY", 0)
    descriptor = os.open(str(output), flags, 0o444)
    try:
        with os.fdopen(descriptor, "wb", closefd=True) as handle:
            descriptor = -1
            handle.write(data)
            handle.flush()
            os.fsync(handle.fileno())
    finally:
        if descriptor >= 0:
            os.close(descriptor)
    return output
