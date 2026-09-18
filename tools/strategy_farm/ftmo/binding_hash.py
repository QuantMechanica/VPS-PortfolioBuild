"""Line-ending-invariant SHA-256 for the hash-pinned FTMO text contracts.

A pin computed over raw on-disk bytes is not portable across clones. Git
stores these files with LF, but ``core.autocrlf`` smudges them to CRLF in one
worktree and leaves them LF in another, so the *same committed content*
produces two different digests. That is exactly how the M13 demo binding came
to refuse everywhere at once (router ticket a5cf99d0, 2026-09-18):

  * ``docs/ops/evidence/2026-09-06_ftmo_demo_account_terms.md`` was pinned over
    LF bytes -> ``account_terms_evidence_hash_drift`` in every autocrlf worktree;
  * the two QM5_13206 governor presets were pinned over CRLF bytes -> they only
    verified where autocrlf happened to smudge them, and never on an LF clone;
  * ``FTMO_2S_100K_STANDARD_V2.json`` was pinned over LF bytes ->
    ``rulepack_file_hash_drift`` in any clone predating its ``text eol=lf``
    ``.gitattributes`` entry (the canonical C:/QM/repo clone).

Hashing the LF-normalized bytes makes the pin a property of the *content*, not
of the clone, which is what a rule binding is supposed to assert. The
companion ``.gitattributes`` entries keep the working-tree bytes stable as well,
so the two defenses are independent: a clone that ignores .gitattributes
still verifies, and a tool that forgets to normalize still sees stable bytes.

Sensitivity is unchanged for everything a rule binding cares about: any byte of
rule content that differs -- a digit, a flag, a rule id, an inserted or removed
line -- still changes the digest. Only the CR/LF spelling of a line break is
neutralized.
"""
from __future__ import annotations

import hashlib
from pathlib import Path

# A UTF-16 set file encodes a line break as CR NUL LF NUL; a byte-level CR/LF
# rewrite would corrupt it, so those files are hashed verbatim. MT5 writes both
# encodings, and trial_setpath.decode() already handles the UTF-16 case.
UTF16_BOMS = (b"\xff\xfe", b"\xfe\xff")


def normalize_line_endings(data: bytes) -> bytes:
    """Return ``data`` with CRLF and lone CR line breaks rewritten to LF."""
    if data.startswith(UTF16_BOMS):
        return data
    return data.replace(b"\r\n", b"\n").replace(b"\r", b"\n")


def content_sha256(data: bytes) -> str:
    """SHA-256 of the line-ending-normalized content of ``data``."""
    return hashlib.sha256(normalize_line_endings(data)).hexdigest()


def file_content_sha256(path: Path | str) -> str:
    """SHA-256 of the line-ending-normalized content of the file at ``path``."""
    return content_sha256(Path(path).read_bytes())


def raw_sha256(data: bytes) -> str:
    """SHA-256 of the exact bytes -- forensic provenance, never a pin."""
    return hashlib.sha256(data).hexdigest()
