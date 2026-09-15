"""Shared Company-Reference-Vault paths and card-content hashing.

Single source of truth for the Obsidian vault root and the Strategy Wiki
sub-tree, so every tool that touches the vault (``strategy_wiki_sync.py``,
``framework/scripts/research_dedup_check.py``, ``check_repo_vault_refs.py``, …)
resolves the SAME path instead of re-hard-coding it. This module exists because
``research_dedup_check.py`` shipped with a wrong wiki root
(``G:\\My Drive\\09 Strategy Wiki`` — missing the
``QuantMechanica - Company Reference`` segment), which fail-closed the vault-side
dedup on every run (drift D1, audit 2026-09-15).

The vault root may be overridden with the ``QM_VAULT_ROOT`` environment variable
(used by tests and by any relocated checkout). Nothing here performs I/O at
import time.
"""
from __future__ import annotations

import hashlib
import os
import re
from pathlib import Path

# Canonical production vault root (cloud-synced Obsidian vault). Override with
# QM_VAULT_ROOT for tests / relocated installs.
DEFAULT_VAULT_ROOT = Path(r"G:\My Drive\QuantMechanica - Company Reference")

ENV_VAULT_ROOT = "QM_VAULT_ROOT"

# Sub-tree names (kept as constants so callers never spell them literally).
STRATEGY_WIKI_DIRNAME = "09 Strategy Wiki"
# Hand-written strategy nodes (NEVER overwritten by a generator).
STRATEGY_WIKI_STRATEGIES_DIRNAME = "strategies"
# Machine-generated strategy projections live here, one class-folder each.
STRATEGY_WIKI_GENERATED_DIRNAME = "generated"

# Frontmatter marker that unmistakably flags a machine-generated node.
GENERATED_MARKER_KEY = "generated"
GENERATED_PRODUCER = "strategy_wiki_sync/v1"

# The card_sha256 / card_hash frontmatter keys are self-excluding from the card
# content hash, so persisting the value back into the card is stable.
_SELF_HASH_KEYS = ("card_sha256", "card_hash")
_SELF_HASH_RE = re.compile(
    r"^\s*(?:" + "|".join(_SELF_HASH_KEYS) + r")\s*:", re.IGNORECASE
)


def vault_root(override: str | os.PathLike[str] | None = None) -> Path:
    """Return the vault root, honouring an explicit override then QM_VAULT_ROOT."""
    if override is not None:
        return Path(override)
    env = os.environ.get(ENV_VAULT_ROOT)
    if env:
        return Path(env)
    return DEFAULT_VAULT_ROOT


def strategy_wiki_root(override: str | os.PathLike[str] | None = None) -> Path:
    """Return ``<vault>/09 Strategy Wiki``."""
    return vault_root(override) / STRATEGY_WIKI_DIRNAME


def strategy_wiki_strategies_dir(
    override: str | os.PathLike[str] | None = None,
) -> Path:
    """Hand-written strategy nodes directory (read-only for generators)."""
    return strategy_wiki_root(override) / STRATEGY_WIKI_STRATEGIES_DIRNAME


def strategy_wiki_generated_dir(
    override: str | os.PathLike[str] | None = None,
) -> Path:
    """Machine-generated strategy projection root."""
    return strategy_wiki_root(override) / STRATEGY_WIKI_GENERATED_DIRNAME


def card_content_sha256(text: str) -> str:
    """Deterministic content hash of a markdown Strategy Card.

    Line endings are normalised to LF and any existing ``card_sha256`` /
    ``card_hash`` frontmatter line is dropped before hashing, so the value is
    stable across checkout line-ending policy AND stable when persisted back
    into the card's own frontmatter (self-excluding, mirroring
    ``strategy_card_v3.canonical_card_hash``). Same card content → same hash.
    """
    norm = text.replace("\r\n", "\n").replace("\r", "\n")
    lines = [ln for ln in norm.split("\n") if not _SELF_HASH_RE.match(ln)]
    return hashlib.sha256("\n".join(lines).encode("utf-8")).hexdigest()


def card_file_content_sha256(path: str | os.PathLike[str]) -> str:
    """``card_content_sha256`` of a card file on disk (utf-8/utf-8-sig)."""
    raw = Path(path).read_bytes()
    encoding = "utf-8-sig" if raw.startswith(b"\xef\xbb\xbf") else "utf-8"
    return card_content_sha256(raw.decode(encoding, errors="replace"))
