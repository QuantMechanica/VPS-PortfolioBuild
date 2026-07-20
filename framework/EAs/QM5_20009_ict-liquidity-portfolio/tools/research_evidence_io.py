"""Strict, dependency-free evidence I/O for QM5_20009 Freeze-v5.

This module deliberately has no dependency on a mutable pipeline runner.  It
provides the small set of primitives needed by the DEV adjudicator: strict JSON
loading, canonical artifact bytes, SHA-256 bindings, detached checksum files,
and same-volume exclusive publication.  The authoritative JSON is always
published after its checksum sidecar and is therefore the commit marker.
"""

from __future__ import annotations

import hashlib
import json
import os
import re
import shutil
import tempfile
from dataclasses import dataclass
from pathlib import Path
from typing import Any, Mapping


SHA256_RE = re.compile(r"^[0-9a-f]{64}$")


class EvidenceIOError(RuntimeError):
    """Evidence is malformed, mutable, outside its root, or already published."""


def _reject_duplicate_keys(pairs: list[tuple[str, Any]]) -> dict[str, Any]:
    value: dict[str, Any] = {}
    for key, item in pairs:
        if key in value:
            raise EvidenceIOError(f"duplicate JSON key: {key}")
        value[key] = item
    return value


def _reject_json_constant(value: str) -> None:
    raise EvidenceIOError(f"non-finite JSON number is forbidden: {value}")


def load_json_strict(path: Path | str) -> dict[str, Any]:
    """Load one JSON object, rejecting duplicate keys and NaN/Infinity."""

    source = Path(path)
    try:
        payload = json.loads(
            source.read_text(encoding="utf-8-sig"),
            object_pairs_hook=_reject_duplicate_keys,
            parse_constant=_reject_json_constant,
        )
    except EvidenceIOError:
        raise
    except (OSError, UnicodeError, json.JSONDecodeError) as exc:
        raise EvidenceIOError(f"cannot read strict JSON {source}: {exc}") from exc
    if not isinstance(payload, dict):
        raise EvidenceIOError(f"JSON root must be an object: {source}")
    return payload


def canonical_json_bytes(payload: Mapping[str, Any]) -> bytes:
    """Return the sole on-disk JSON representation for v5 adjudication artifacts."""

    try:
        text = json.dumps(
            payload,
            indent=2,
            sort_keys=True,
            ensure_ascii=True,
            allow_nan=False,
        )
    except (TypeError, ValueError) as exc:
        raise EvidenceIOError(f"payload is not canonical-JSON serializable: {exc}") from exc
    return (text + "\n").encode("ascii")


def canonical_payload_sha256(payload: Any) -> str:
    """Hash a value independent of whitespace, for internal closure identities."""

    try:
        encoded = json.dumps(
            payload,
            sort_keys=True,
            separators=(",", ":"),
            ensure_ascii=True,
            allow_nan=False,
        ).encode("ascii")
    except (TypeError, ValueError) as exc:
        raise EvidenceIOError(f"payload cannot be hashed canonically: {exc}") from exc
    return hashlib.sha256(encoded).hexdigest()


def sha256_bytes(payload: bytes) -> str:
    return hashlib.sha256(payload).hexdigest()


def sha256_file(path: Path | str) -> str:
    source = Path(path)
    digest = hashlib.sha256()
    try:
        with source.open("rb") as handle:
            for chunk in iter(lambda: handle.read(1024 * 1024), b""):
                digest.update(chunk)
    except OSError as exc:
        raise EvidenceIOError(f"cannot hash file {source}: {exc}") from exc
    return digest.hexdigest()


def valid_sha256(value: Any) -> bool:
    return isinstance(value, str) and SHA256_RE.fullmatch(value.lower()) is not None


def require_sha256(value: Any, label: str) -> str:
    if not valid_sha256(value):
        raise EvidenceIOError(f"{label} must be lowercase SHA-256")
    if value != value.lower():
        raise EvidenceIOError(f"{label} must be lowercase SHA-256")
    return value


def require_exact_keys(
    value: Mapping[str, Any], *, required: set[str], context: str
) -> None:
    actual = set(value)
    missing = sorted(required - actual)
    extra = sorted(actual - required)
    if missing or extra:
        raise EvidenceIOError(
            f"{context} key mismatch: missing={missing} extra={extra}"
        )


def is_within(path: Path | str, root: Path | str, *, allow_root: bool = False) -> bool:
    try:
        resolved = Path(path).resolve(strict=False)
        resolved_root = Path(root).resolve(strict=False)
        relative = resolved.relative_to(resolved_root)
        return allow_root or relative != Path(".")
    except (OSError, ValueError):
        return False


@dataclass(frozen=True)
class FileBinding:
    path: str
    size_bytes: int
    sha256: str

    def as_dict(self) -> dict[str, Any]:
        return {
            "path": self.path,
            "size_bytes": self.size_bytes,
            "sha256": self.sha256,
        }


def file_binding(path: Path | str) -> FileBinding:
    try:
        resolved = Path(path).resolve(strict=True)
        stat = resolved.stat()
    except OSError as exc:
        raise EvidenceIOError(f"required evidence file is missing: {path}: {exc}") from exc
    if not resolved.is_file() or stat.st_size <= 0:
        raise EvidenceIOError(f"evidence binding target is missing/empty: {resolved}")
    return FileBinding(str(resolved), stat.st_size, sha256_file(resolved))


def validate_file_binding(
    raw: Mapping[str, Any],
    *,
    context: str,
    root: Path | None = None,
) -> FileBinding:
    require_exact_keys(
        raw,
        required={"path", "size_bytes", "sha256"},
        context=context,
    )
    path_raw = raw["path"]
    size_raw = raw["size_bytes"]
    if not isinstance(path_raw, str) or not path_raw:
        raise EvidenceIOError(f"{context}.path must be a non-empty string")
    if isinstance(size_raw, bool) or not isinstance(size_raw, int) or size_raw <= 0:
        raise EvidenceIOError(f"{context}.size_bytes must be a positive integer")
    expected_sha = require_sha256(raw["sha256"], f"{context}.sha256")
    binding = file_binding(path_raw)
    if root is not None and not is_within(binding.path, root):
        raise EvidenceIOError(f"{context} escapes required root {root}: {binding.path}")
    if binding.size_bytes != size_raw or binding.sha256 != expected_sha:
        raise EvidenceIOError(
            f"{context} binding drift: size/hash do not match {binding.path}"
        )
    return binding


def detached_bytes(artifact_sha256: str, artifact_name: str) -> bytes:
    digest = require_sha256(artifact_sha256, "detached artifact sha256")
    if not artifact_name or Path(artifact_name).name != artifact_name:
        raise EvidenceIOError(f"detached artifact name is not a basename: {artifact_name!r}")
    return f"{digest}  {artifact_name}\n".encode("ascii")


def verify_detached(
    artifact_path: Path | str,
    sidecar_path: Path | str,
    *,
    allow_bare: bool = False,
) -> FileBinding:
    artifact = Path(artifact_path).resolve(strict=True)
    sidecar = Path(sidecar_path).resolve(strict=True)
    actual = sha256_file(artifact)
    try:
        text = sidecar.read_text(encoding="ascii")
    except (OSError, UnicodeError) as exc:
        raise EvidenceIOError(f"cannot read detached checksum {sidecar}: {exc}") from exc
    accepted = {f"{actual}  {artifact.name}\n"}
    if allow_bare:
        accepted.add(f"{actual}\n")
    if text not in accepted:
        raise EvidenceIOError(f"detached checksum mismatch/format error: {sidecar}")
    return file_binding(sidecar)


@dataclass(frozen=True)
class ArtifactPayload:
    path: Path
    payload: bytes


def _fsync_directory(path: Path) -> None:
    """Best-effort directory flush; Windows does not expose a portable directory fd."""

    if os.name == "nt":
        return
    descriptor = os.open(path, os.O_RDONLY)
    try:
        os.fsync(descriptor)
    finally:
        os.close(descriptor)


def publish_exclusive_bundle(
    artifacts: list[ArtifactPayload],
    *,
    fail_after: int | None = None,
) -> list[FileBinding]:
    """Publish staged bytes with exclusive hard links, in the supplied order.

    All targets must share one existing-or-creatable root volume.  Each payload is
    fully written and fsynced in a private staging directory first.  ``os.link``
    is then an atomic create-new operation: it cannot overwrite an existing
    authoritative artifact.  Callers order checksum files before their JSON
    commit markers and place the phase verdict last.
    """

    if not artifacts:
        raise EvidenceIOError("exclusive bundle is empty")
    if fail_after is not None and (
        isinstance(fail_after, bool)
        or not isinstance(fail_after, int)
        or not 1 <= fail_after <= len(artifacts)
    ):
        raise EvidenceIOError(
            "fail_after must identify a one-based artifact in the bundle"
        )
    for index, item in enumerate(artifacts):
        if not isinstance(item.payload, bytes) or not item.payload:
            raise EvidenceIOError(
                f"exclusive bundle artifact {index} must contain non-empty bytes"
            )
    targets = [item.path.resolve(strict=False) for item in artifacts]
    if len({os.path.normcase(str(path)) for path in targets}) != len(targets):
        raise EvidenceIOError("exclusive bundle contains duplicate target paths")
    existing = [str(path) for path in targets if path.exists()]
    if existing:
        raise EvidenceIOError(f"immutable output already exists: {existing}")

    try:
        common = Path(os.path.commonpath([str(path.parent) for path in targets]))
    except ValueError as exc:
        raise EvidenceIOError(
            "exclusive bundle targets must be on one filesystem volume"
        ) from exc
    common.mkdir(parents=True, exist_ok=True)
    stage = Path(tempfile.mkdtemp(prefix=".qm5_20009_publish_", dir=common))
    staged: list[tuple[Path, Path]] = []
    published: list[Path] = []
    try:
        for index, item in enumerate(artifacts):
            target = targets[index]
            target.parent.mkdir(parents=True, exist_ok=True)
            staged_path = stage / f"{index:04d}.artifact"
            descriptor = os.open(
                staged_path,
                os.O_WRONLY | os.O_CREAT | os.O_EXCL,
                0o600,
            )
            try:
                with os.fdopen(descriptor, "wb", closefd=True) as handle:
                    handle.write(item.payload)
                    handle.flush()
                    os.fsync(handle.fileno())
            except Exception:
                try:
                    os.close(descriptor)
                except OSError:
                    pass
                raise
            staged.append((staged_path, target))

        expected_published: list[tuple[Path, int, str]] = []
        for index, (source, target) in enumerate(staged, start=1):
            # Recheck every earlier commit marker immediately before advancing.
            # This catches concurrent mutation before the final verdict can be
            # made authoritative.
            for prior, expected_size, expected_sha in expected_published:
                observed = file_binding(prior)
                if (
                    observed.size_bytes != expected_size
                    or observed.sha256 != expected_sha
                ):
                    raise EvidenceIOError(
                        f"published artifact changed during bundle commit: {prior}"
                    )
            try:
                os.link(source, target)
            except FileExistsError as exc:
                raise EvidenceIOError(f"immutable output appeared concurrently: {target}") from exc
            except OSError as exc:
                raise EvidenceIOError(f"exclusive publish failed for {target}: {exc}") from exc
            published.append(target)
            payload = artifacts[index - 1].payload
            expected_published.append(
                (target, len(payload), sha256_bytes(payload))
            )
            _fsync_directory(target.parent)
            if fail_after is not None and index == fail_after:
                raise EvidenceIOError(f"injected publication failure after artifact {index}")

        bindings = [file_binding(path) for path in published]
        for binding, (_, expected_size, expected_sha) in zip(
            bindings, expected_published, strict=True
        ):
            if (
                binding.size_bytes != expected_size
                or binding.sha256 != expected_sha
            ):
                raise EvidenceIOError(
                    f"published artifact does not match staged bytes: {binding.path}"
                )
        return bindings
    finally:
        shutil.rmtree(stage, ignore_errors=True)
