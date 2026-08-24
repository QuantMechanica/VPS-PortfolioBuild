"""Tests for canonical_hash (router task 8628cddd).

Covers the helper (``canonical_blob_sha256`` / ``working_copy_sha256``) and the
validator (``validate_declared_hash``) against the exact defect class they
exist to catch: a source hash declared from transient working-copy CRLF bytes
that does not bind to the LF-normalized committed git blob.

Fully hermetic -- every test builds a throwaway git repo in ``tmp_path`` and
never touches the live farm state DB or the real checkout.
"""
import hashlib
import subprocess
import sys
from pathlib import Path

import pytest

sys.path.insert(0, str(Path(__file__).resolve().parents[1]))

import canonical_hash as ch  # noqa: E402


def _git(repo: Path, *args: str) -> str:
    result = subprocess.run(
        ("git", "-C", str(repo), *args),
        capture_output=True,
        text=True,
        encoding="utf-8",
        check=True,
    )
    return result.stdout.strip()


def _sha256(raw: bytes) -> str:
    return hashlib.sha256(raw).hexdigest()


def _init_repo(tmp_path: Path, *, autocrlf: str) -> Path:
    repo = tmp_path / "repo"
    repo.mkdir()
    _git(repo, "init", "-q")
    _git(repo, "config", "user.email", "canon-tests@example.invalid")
    _git(repo, "config", "user.name", "Canon Tests")
    _git(repo, "config", "core.autocrlf", autocrlf)
    return repo


def _commit_crlf_drift_file(tmp_path: Path) -> tuple[Path, Path, bytes, bytes]:
    """Commit a text file so the blob is LF but the working copy is CRLF.

    Returns (repo, file_path, lf_bytes, crlf_bytes).  This reproduces the real
    farm condition: ``.gitattributes`` marks ``.set`` as text, so git stores LF
    while ``core.autocrlf=true`` smudges the checkout to CRLF.
    """
    repo = _init_repo(tmp_path, autocrlf="true")
    (repo / ".gitattributes").write_text("*.set text\n", encoding="ascii")
    _git(repo, "add", ".gitattributes")
    _git(repo, "commit", "-q", "-m", "attrs")

    rel = "framework/EAs/demo/sets/demo_EURUSD.set"
    lf_bytes = b"; build_hash: deadbeef\nqm_ea_id=39001\nRISK_FIXED=1000\n"
    target = repo / rel
    target.parent.mkdir(parents=True, exist_ok=True)
    target.write_bytes(lf_bytes)  # commit LF content
    _git(repo, "add", rel)
    _git(repo, "commit", "-q", "-m", "add setfile")

    # Re-materialize the working copy through git so autocrlf smudges to CRLF,
    # exactly as a fresh Windows checkout would.
    target.unlink()
    _git(repo, "checkout", "--", rel)
    crlf_bytes = target.read_bytes()
    return repo, target, lf_bytes, crlf_bytes


# --------------------------------------------------------------------------
# Helper: canonical vs working-copy hashing
# --------------------------------------------------------------------------

def test_working_copy_and_canonical_diverge_under_crlf(tmp_path):
    repo, target, lf_bytes, crlf_bytes = _commit_crlf_drift_file(tmp_path)
    # Precondition: the checkout really is CRLF while the blob is LF.
    assert b"\r\n" in crlf_bytes
    assert b"\r\n" not in lf_bytes
    assert crlf_bytes != lf_bytes

    canonical = ch.canonical_blob_sha256(target, repo_root=repo)
    working = ch.working_copy_sha256(target)

    assert canonical == _sha256(lf_bytes)  # binds to the committed blob
    assert working == _sha256(crlf_bytes)  # legacy _sha256_file basis
    assert canonical != working  # the drift the module exists to catch


def test_canonical_blob_bytes_match_git_show(tmp_path):
    repo, target, lf_bytes, _ = _commit_crlf_drift_file(tmp_path)
    rel = target.resolve().relative_to(repo.resolve()).as_posix()
    via_show = subprocess.run(
        ("git", "-C", str(repo), "show", f"HEAD:{rel}"),
        capture_output=True,
        check=True,
    ).stdout
    assert ch.canonical_blob_bytes(target, repo_root=repo) == via_show
    assert via_show == lf_bytes


def test_raw_minus_text_file_has_no_drift(tmp_path):
    """A ``-text`` (raw) setfile keeps exact committed bytes -> no drift."""
    repo = _init_repo(tmp_path, autocrlf="true")
    (repo / ".gitattributes").write_text("*.set -text\n", encoding="ascii")
    _git(repo, "add", ".gitattributes")
    _git(repo, "commit", "-q", "-m", "attrs")

    rel = "sets/raw.set"
    raw_bytes = b"; raw contract\r\nqm=1\r\n"  # CRLF preserved as-is
    target = repo / rel
    target.parent.mkdir(parents=True, exist_ok=True)
    target.write_bytes(raw_bytes)
    _git(repo, "add", rel)
    _git(repo, "commit", "-q", "-m", "raw setfile")
    target.unlink()
    _git(repo, "checkout", "--", rel)

    canonical = ch.canonical_blob_sha256(target, repo_root=repo)
    working = ch.working_copy_sha256(target)
    assert canonical == working == _sha256(raw_bytes)


def test_canonical_blob_sha256_untracked_path_raises(tmp_path):
    repo = _init_repo(tmp_path, autocrlf="false")
    (repo / "seed.txt").write_text("x\n", encoding="ascii")
    _git(repo, "add", "seed.txt")
    _git(repo, "commit", "-q", "-m", "seed")
    ghost = repo / "not_committed.set"
    ghost.write_bytes(b"x\n")
    with pytest.raises(ch.CanonicalHashError):
        ch.canonical_blob_sha256(ghost, repo_root=repo)


def test_specific_ref_reads_historical_blob(tmp_path):
    repo = _init_repo(tmp_path, autocrlf="false")
    rel = "a.set"
    (repo / rel).write_bytes(b"v1\n")
    _git(repo, "add", rel)
    _git(repo, "commit", "-q", "-m", "v1")
    first = _git(repo, "rev-parse", "HEAD")
    (repo / rel).write_bytes(b"v2\n")
    _git(repo, "add", rel)
    _git(repo, "commit", "-q", "-m", "v2")

    assert ch.canonical_blob_sha256(
        repo / rel, ref=first, repo_root=repo
    ) == _sha256(b"v1\n")
    assert ch.canonical_blob_sha256(
        repo / rel, ref="HEAD", repo_root=repo
    ) == _sha256(b"v2\n")


# --------------------------------------------------------------------------
# Validator
# --------------------------------------------------------------------------

def test_validator_passes_on_canonical_hash(tmp_path):
    repo, target, lf_bytes, _ = _commit_crlf_drift_file(tmp_path)
    declared = _sha256(lf_bytes)
    result = ch.validate_declared_hash(target, declared, repo_root=repo)
    assert result.status == "PASS"
    assert result.ok is True
    assert result.canonical_sha256 == declared


def test_validator_fails_on_working_copy_drift(tmp_path):
    """The core proof: a hash declared from CRLF working-copy bytes FAILs,
    even though the old naive _sha256_file() would re-derive the same value."""
    repo, target, _lf, crlf_bytes = _commit_crlf_drift_file(tmp_path)
    declared = _sha256(crlf_bytes)  # what legacy _sha256_file() recorded

    # Old naive re-verification would "look fine" (declared == on-disk hash):
    assert ch.working_copy_sha256(target) == declared

    # New validator catches the drift:
    result = ch.validate_declared_hash(target, declared, repo_root=repo)
    assert result.status == "FAIL"
    assert result.ok is False
    assert result.working_copy_drift is True
    assert "working-copy" in result.reason.lower()
    assert result.declared_sha256 != result.canonical_sha256


def test_validator_fails_on_unrelated_hash(tmp_path):
    repo, target, _lf, _crlf = _commit_crlf_drift_file(tmp_path)
    bogus = "0" * 64
    result = ch.validate_declared_hash(target, bogus, repo_root=repo)
    assert result.status == "FAIL"
    assert result.working_copy_drift is True  # on-disk still CRLF-drifted
    assert "canonical committed blob" in result.reason


def test_validator_errors_on_malformed_declared_hash(tmp_path):
    repo, target, _lf, _crlf = _commit_crlf_drift_file(tmp_path)
    result = ch.validate_declared_hash(target, "not-a-hash", repo_root=repo)
    assert result.status == "ERROR"
    assert result.ok is False


def test_validator_fails_closed_on_untracked_path(tmp_path):
    repo = _init_repo(tmp_path, autocrlf="false")
    (repo / "seed.txt").write_text("x\n", encoding="ascii")
    _git(repo, "add", "seed.txt")
    _git(repo, "commit", "-q", "-m", "seed")
    ghost = repo / "ghost.set"
    ghost.write_bytes(b"x\n")
    result = ch.validate_declared_hash(ghost, _sha256(b"x\n"), repo_root=repo)
    assert result.status == "FAIL"
    assert "canonical blob unavailable" in result.reason


def test_validator_normalizes_declared_case_and_whitespace(tmp_path):
    repo, target, lf_bytes, _ = _commit_crlf_drift_file(tmp_path)
    declared = "  " + _sha256(lf_bytes).upper() + "\n"
    result = ch.validate_declared_hash(target, declared, repo_root=repo)
    assert result.status == "PASS"


# --------------------------------------------------------------------------
# CLI
# --------------------------------------------------------------------------

def test_cli_validate_fail_returns_1(tmp_path, capsys):
    repo, target, _lf, crlf_bytes = _commit_crlf_drift_file(tmp_path)
    rc = ch.main(
        [str(target), "--declared", _sha256(crlf_bytes), "--repo-root", str(repo)]
    )
    assert rc == 1
    assert "FAIL" in capsys.readouterr().out


def test_cli_validate_pass_returns_0(tmp_path, capsys):
    repo, target, lf_bytes, _ = _commit_crlf_drift_file(tmp_path)
    rc = ch.main(
        [str(target), "--declared", _sha256(lf_bytes), "--repo-root", str(repo)]
    )
    assert rc == 0
    assert "PASS" in capsys.readouterr().out


def test_cli_compute_only_reports_drift(tmp_path, capsys):
    repo, target, lf_bytes, _ = _commit_crlf_drift_file(tmp_path)
    rc = ch.main([str(target), "--repo-root", str(repo)])
    out = capsys.readouterr().out
    assert rc == 0
    assert _sha256(lf_bytes) in out
    assert "DRIFT" in out
