"""Canonical source-hash binding for evidence, setfiles, and build identity.

Root cause this module exists to eliminate (recurring defect class, first
diagnosed 2026-08-17 "Pin-SHA ueber LF-Blob-Bytes" / "Bindung nutzt
Arbeitskopie-Bytes", re-confirmed by the 2026-08-24 verification sweep with
>=13 drifted reworks):

    Evidence documents, setfile ``build_hash`` fields, and EA ``build_identity``
    records historically declared a SHA-256 for a source file (``.mq5``,
    ``.mqh``, ``.set``) by hashing the *raw working-copy bytes on disk* (see the
    legacy ``_sha256_file()`` in ``farmctl.py``).  On this Windows checkout
    ``core.autocrlf`` / ``.gitattributes`` normalization means the on-disk bytes
    can be CRLF while the committed git blob is LF, so the declared hash binds to
    *nothing durable*: it never matches ``git show <ref>:<path> | sha256sum``.

The canonical basis is the LF-normalized blob **exactly as git stores it** --
i.e. the bytes ``git cat-file blob <ref>:<path>`` returns.  Git applies its own
attribute-driven normalization when materializing blob content, so this is
already the correct per-``.gitattributes`` answer: a normal ``-text`` (binary /
raw) setfile keeps its exact committed bytes, while a normal text file is
LF-normalized -- no manual line-ending stripping is required here.

Prospective use only.  This module is the standard that rework-completion and
build tooling should call instead of ad-hoc ``hashlib.sha256(open(p,'rb').read())``.
It does not retroactively rebind historical drifted reworks (a separate task).

Usable two ways:

* importable -- ``canonical_blob_sha256(path)`` and
  ``validate_declared_hash(path, declared)`` for rework/build tooling; and
* standalone CLI -- ``python canonical_hash.py <path> --declared <sha> [--ref R]``.
"""
from __future__ import annotations

import argparse
import hashlib
import subprocess
import sys
from dataclasses import asdict, dataclass
from pathlib import Path


class CanonicalHashError(RuntimeError):
    """A canonical hash could not be computed (path untracked / git failure)."""


_SHA256_HEX_LEN = 64
_GIT_TIMEOUT_S = 20


def _git_bytes(repo_root: Path, *args: str) -> bytes:
    """Run ``git -C <repo_root> <args>`` and return raw stdout bytes.

    Binary-safe: no text decoding, so blob content is hashed exactly as git
    stores it.  Raises :class:`CanonicalHashError` on any failure.
    """
    try:
        result = subprocess.run(
            ("git", "-C", str(repo_root), *args),
            capture_output=True,
            timeout=_GIT_TIMEOUT_S,
            check=False,
        )
    except (OSError, subprocess.SubprocessError) as exc:
        raise CanonicalHashError(f"git invocation failed: {exc}") from exc
    if result.returncode != 0:
        stderr = result.stderr.decode("utf-8", errors="replace").strip()
        raise CanonicalHashError(
            f"git {' '.join(args)} failed (rc={result.returncode}): {stderr}"
        )
    return result.stdout


def find_repo_root(start: Path | str) -> Path:
    """Return the git top-level directory containing ``start``."""
    start_path = Path(start)
    anchor = start_path if start_path.is_dir() else start_path.parent
    out = _git_bytes(anchor, "rev-parse", "--show-toplevel")
    return Path(out.decode("utf-8").strip())


def _relative_posix(path: Path, repo_root: Path) -> str:
    """Repo-relative POSIX path suitable for a ``git <ref>:<path>`` pathspec."""
    try:
        rel = path.resolve().relative_to(repo_root.resolve())
    except ValueError as exc:
        raise CanonicalHashError(
            f"{path} is not inside repo root {repo_root}"
        ) from exc
    return rel.as_posix()


def _sha256_bytes(data: bytes) -> str:
    digest = hashlib.sha256()
    digest.update(data)
    return digest.hexdigest()


def canonical_blob_bytes(
    path: Path | str,
    *,
    ref: str = "HEAD",
    repo_root: Path | str | None = None,
) -> bytes:
    """Return the committed blob bytes of ``path`` at ``ref``.

    This is ``git cat-file blob <ref>:<relative_path>`` -- the canonical,
    ``.gitattributes``-normalized content git actually stores, NOT the
    working-copy bytes on disk.  Raises :class:`CanonicalHashError` if the path
    is not tracked at ``ref``.
    """
    path = Path(path)
    root = Path(repo_root) if repo_root is not None else find_repo_root(path)
    rel = _relative_posix(path, root)
    return _git_bytes(root, "cat-file", "blob", f"{ref}:{rel}")


def canonical_blob_sha256(
    path: Path | str,
    *,
    ref: str = "HEAD",
    repo_root: Path | str | None = None,
) -> str:
    """SHA-256 of the canonical committed blob of ``path`` at ``ref``.

    Use this everywhere a source-file hash is recorded (evidence docs, setfile
    ``build_hash``, ``build_identity``) so the declared hash binds to the
    durable committed blob instead of transient working-copy line-ending bytes.
    """
    return _sha256_bytes(canonical_blob_bytes(path, ref=ref, repo_root=repo_root))


def working_copy_sha256(path: Path | str) -> str:
    """SHA-256 of the raw on-disk bytes -- the legacy ``_sha256_file`` basis.

    Exposed for diagnostics / drift detection ONLY.  This is exactly the value
    that silently drifts under CRLF normalization; never record it as the
    canonical source hash.
    """
    digest = hashlib.sha256()
    with Path(path).open("rb") as handle:
        for chunk in iter(lambda: handle.read(1024 * 1024), b""):
            digest.update(chunk)
    return digest.hexdigest()


def _normalize_declared(declared: str) -> str:
    value = (declared or "").strip().lower()
    if len(value) != _SHA256_HEX_LEN or any(
        ch not in "0123456789abcdef" for ch in value
    ):
        raise CanonicalHashError(
            f"declared value is not a 64-hex-char sha256: {declared!r}"
        )
    return value


@dataclass(frozen=True)
class HashBinding:
    """Result of validating a declared source hash against the canonical blob."""

    relative_path: str
    ref: str
    declared_sha256: str
    canonical_sha256: str
    working_copy_sha256: str | None
    status: str  # "PASS" | "FAIL" | "ERROR"
    reason: str

    @property
    def ok(self) -> bool:
        return self.status == "PASS"

    @property
    def working_copy_drift(self) -> bool:
        """True when on-disk bytes differ from the canonical committed blob.

        This is the fingerprint of the bug class: if a declared hash equals the
        working-copy hash but not the canonical hash, it was computed from
        transient CRLF bytes and binds to nothing durable.
        """
        return (
            self.working_copy_sha256 is not None
            and self.working_copy_sha256 != self.canonical_sha256
        )

    def to_dict(self) -> dict[str, object]:
        d = asdict(self)
        d["ok"] = self.ok
        d["working_copy_drift"] = self.working_copy_drift
        return d


def validate_declared_hash(
    path: Path | str,
    declared_sha256: str,
    *,
    ref: str = "HEAD",
    repo_root: Path | str | None = None,
    include_working_copy: bool = True,
) -> HashBinding:
    """Validate that ``declared_sha256`` binds to the canonical committed blob.

    Fail-closed: any inability to compute the canonical hash (untracked path,
    git failure) is a FAIL, never a silent pass.  Returns a :class:`HashBinding`
    describing PASS / FAIL and, when available, whether the on-disk working copy
    has drifted from the committed blob (the CRLF fingerprint).
    """
    path = Path(path)
    root = Path(repo_root) if repo_root is not None else None
    try:
        declared = _normalize_declared(declared_sha256)
    except CanonicalHashError as exc:
        return HashBinding(
            relative_path=str(path),
            ref=ref,
            declared_sha256=str(declared_sha256),
            canonical_sha256="",
            working_copy_sha256=None,
            status="ERROR",
            reason=str(exc),
        )

    try:
        if root is None:
            root = find_repo_root(path)
        rel = _relative_posix(path, root)
        canonical = _sha256_bytes(
            canonical_blob_bytes(path, ref=ref, repo_root=root)
        )
    except CanonicalHashError as exc:
        return HashBinding(
            relative_path=str(path),
            ref=ref,
            declared_sha256=declared,
            canonical_sha256="",
            working_copy_sha256=None,
            status="FAIL",
            reason=f"canonical blob unavailable at {ref}: {exc}",
        )

    wc: str | None = None
    if include_working_copy and path.is_file():
        try:
            wc = working_copy_sha256(path)
        except OSError:
            wc = None

    if declared == canonical:
        reason = "declared hash binds to the canonical committed blob"
        status = "PASS"
    else:
        status = "FAIL"
        if wc is not None and declared == wc and wc != canonical:
            reason = (
                "declared hash equals transient working-copy bytes, not the "
                "committed blob -- classic CRLF/working-copy drift; rebind via "
                "canonical_blob_sha256()"
            )
        else:
            reason = (
                "declared hash does not match the canonical committed blob "
                f"({canonical})"
            )

    return HashBinding(
        relative_path=rel,
        ref=ref,
        declared_sha256=declared,
        canonical_sha256=canonical,
        working_copy_sha256=wc,
        status=status,
        reason=reason,
    )


def _build_parser() -> argparse.ArgumentParser:
    parser = argparse.ArgumentParser(
        prog="canonical_hash.py",
        description=(
            "Compute or validate the canonical committed-blob SHA-256 of a "
            "source file (git cat-file blob <ref>:<path>), not working-copy "
            "bytes.  Exit 0 = PASS/OK, 1 = FAIL, 2 = usage/error."
        ),
    )
    parser.add_argument("path", help="path to the tracked source file")
    parser.add_argument(
        "--ref",
        default="HEAD",
        help="git ref/commit to read the blob from (default: HEAD)",
    )
    parser.add_argument(
        "--declared",
        default=None,
        help="declared sha256 to validate against the canonical blob",
    )
    parser.add_argument(
        "--repo-root",
        default=None,
        help="repo root (default: auto-detect via git rev-parse)",
    )
    parser.add_argument(
        "--json",
        action="store_true",
        help="emit machine-readable JSON",
    )
    return parser


def main(argv: list[str] | None = None) -> int:
    import json

    args = _build_parser().parse_args(argv)
    path = Path(args.path)

    if args.declared is None:
        # Compute-only mode: print the canonical hash and flag on-disk drift.
        try:
            canonical = canonical_blob_sha256(
                path, ref=args.ref, repo_root=args.repo_root
            )
        except CanonicalHashError as exc:
            print(f"ERROR: {exc}", file=sys.stderr)
            return 2
        wc = working_copy_sha256(path) if path.is_file() else None
        drift = wc is not None and wc != canonical
        if args.json:
            print(
                json.dumps(
                    {
                        "path": str(path),
                        "ref": args.ref,
                        "canonical_sha256": canonical,
                        "working_copy_sha256": wc,
                        "working_copy_drift": drift,
                    },
                    indent=2,
                )
            )
        else:
            print(f"canonical_sha256 {canonical}  {path} @ {args.ref}")
            if wc is not None:
                marker = "  <-- WORKING-COPY DRIFT" if drift else ""
                print(f"working_copy_sha256 {wc}{marker}")
        return 0

    binding = validate_declared_hash(
        path,
        args.declared,
        ref=args.ref,
        repo_root=args.repo_root,
    )
    if args.json:
        print(json.dumps(binding.to_dict(), indent=2))
    else:
        print(f"{binding.status}: {binding.relative_path} @ {binding.ref}")
        print(f"  declared  {binding.declared_sha256}")
        print(f"  canonical {binding.canonical_sha256}")
        if binding.working_copy_sha256 is not None:
            print(f"  workcopy  {binding.working_copy_sha256}")
        print(f"  {binding.reason}")
    if binding.status == "PASS":
        return 0
    if binding.status == "ERROR":
        return 2
    return 1


if __name__ == "__main__":  # pragma: no cover
    raise SystemExit(main())
