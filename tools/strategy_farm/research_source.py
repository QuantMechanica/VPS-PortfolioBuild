"""Internal research source tooling (QM-RESEARCH namespace).

Implements slice C4 / R1-internal of the Kimi integration, governed by
``docs/ops/INTERNAL_RESEARCH_SOURCE_CONTRACT.md`` (FINAL v1) and
``decisions/2026-09-15_owner_kimi_integration_ml_research_r1_internal.md``.

A QM-RESEARCH source is a durable, content-addressed internal research artifact
that satisfies R1 for a QuantMechanica-discovered edge.  The integrity model
(contract R-B) is anchored on:

* ``source_hash = sha256(source.md)`` over the full UTF-8 bytes (the card binds
  to this and the ledger records it); ``source.md`` carries no self-hash;
* an in-file fenced ``qm-source-manifest`` block that records the sha256 of
  ``research.json`` / ``lineage.json`` / ``critic_receipt.json`` and of every
  computed-output file cited by a quantitative claim.

Because the manifest hashes the *sibling* files, any edit to any of them forces
``source.md`` to change, which changes ``source_hash`` and breaks the card
binding until a fresh id is minted (contract Section 6.2 immutability).

Subcommands: ``mint``, ``resolve``, ``verify``, ``seal`` (plus ``remint`` for
explicit re-versioning).  Every path is injectable via arguments / environment
so tests never touch ``D:/QM`` (contract Section 12).

CLI examples::

    python tools/strategy_farm/research_source.py mint --author Kimi \
        --model kimi-code/kimi-for-coding --task-id T-123 --title "XAU gap fade"
    python tools/strategy_farm/research_source.py resolve QM-RESEARCH://2026-0042
    python tools/strategy_farm/research_source.py verify --id QM-RESEARCH-2026-0042
    python tools/strategy_farm/research_source.py verify --card D:/.../card.md
"""

from __future__ import annotations

import argparse
import datetime as dt
import hashlib
import json
import os
import re
import sys
from dataclasses import dataclass
from pathlib import Path
from typing import Any, Mapping


# Repo root: tools/strategy_farm/research_source.py -> parents[2] == repo root.
REPO_ROOT = Path(__file__).resolve().parents[2]
DEFAULT_STORE_ROOT = REPO_ROOT / "strategy-seeds" / "sources"
# Authorized-author config (directive §37 / OWNER-DEC-CBE-20260915).
DEFAULT_SOURCE_CONFIG_PATH = Path(__file__).resolve().parent / "config" / "research_source.v1.json"
DEFAULT_LEDGER_PATH = Path(r"D:\QM\reports\state\research_source_ledger.jsonl")
# The research-layer search-history ledger (data-snooping evidence, contract
# Section 4.3).  Deliberately a *different* quantity from the Q08 DSR cohort.
DEFAULT_SEARCH_LEDGER_PATH = Path(r"D:\QM\reports\state\search_history_ledger.jsonl")

ENV_STORE_ROOT = "QM_RESEARCH_STORE_ROOT"
ENV_LEDGER = "QM_RESEARCH_SOURCE_LEDGER"
ENV_SEARCH_LEDGER = "QM_RESEARCH_SEARCH_LEDGER"
ENV_AUTHORIZED_AUTHORS = "QM_RESEARCH_AUTHORIZED_AUTHORS"

# Fallback authorized-author set if the config is missing/unreadable. Matches
# config/research_source.v1.json (directive §37: Kimi, Fable, another authorized
# research agent, or documented multi-agent collaboration).
_FALLBACK_AUTHORIZED_AUTHORS = ("Kimi", "Fable", "Claude", "Codex", "Antigravity")
_FALLBACK_MULTI_AGENT_PREFIX = "multi-agent:"

LEDGER_SCHEMA = "qm.research-source-ledger/v1"
RESEARCH_SCHEMA = "qm.internal-research-source/v1"
LINEAGE_SCHEMA = "qm.research-lineage/v1"
CRITIC_SCHEMA = "qm.agent-chain.receipt.v1"

SOURCE_MD = "source.md"
RESEARCH_JSON = "research.json"
LINEAGE_JSON = "lineage.json"
CRITIC_JSON = "critic_receipt.json"
# The three siblings that must always appear in the manifest block.
CORE_MANIFEST_FILES = (RESEARCH_JSON, LINEAGE_JSON, CRITIC_JSON)

# Authoritative allocation regex (contract Section 2.1).
MINT_RE = re.compile(r"^QM-RESEARCH-(20\d{2})-(\d{4})$")
# Deliberately broader intake trigger (contract Section 2.1 / R-A): a near-miss
# year is still routed to verify and fails closed rather than slipping through.
INTAKE_RE = re.compile(r"^QM-RESEARCH-(\d{4})-(\d{4})$")
# Reference form QM-RESEARCH://<year>-<nnnn> (contract Section 2.2).
REF_RE = re.compile(r"^QM-RESEARCH://(\d{4})-(\d{4})$")

# Ledger statuses (contract Section 6).
ALL_STATUSES = ("draft", "reviewed", "preregistered", "carded", "retired")
# Admissible-at-intake statuses (contract Section 6.1 / R-A).
ADMISSIBLE_STATUSES = frozenset({"reviewed", "preregistered", "carded"})

# research.json required fields (contract Section 4.2 schema table).
RESEARCH_REQUIRED_FIELDS = (
    "schema", "research_id", "author", "model", "created_utc",
    "originating_task_id", "research_question", "source_datasets",
    "computed_outputs", "quantitative_claims", "observations",
    "proposed_mechanism", "candidate_edge", "confidence", "confounders",
    "related_strategies", "research_trial_count", "search_history_ref",
    "critic_receipt", "lineage",
)
# Fields whose empty/zero value is legitimate and must not fail presence.
_RESEARCH_EMPTY_OK = frozenset({
    "source_datasets", "computed_outputs", "quantitative_claims",
    "confounders", "related_strategies", "research_trial_count", "ml_method",
})

# critic_receipt.json required field paths (contract Section 4.5).
CRITIC_REQUIRED_PATHS = (
    "chain_id", "plan.creator.vendor", "plan.creator.model",
    "plan.critic.vendor", "plan.critic.model", "critic_verdict",
    "critic_seat_final", "generated_at_utc",
)

# Diagnostic sub-reason codes (contract Section 9.3).  These are carried as the
# detail of the single prescreen reason ``INTERNAL_SOURCE_UNRESOLVED``.
REASON_NOT_FOUND = "NOT_FOUND"
REASON_HASH_MISMATCH = "HASH_MISMATCH"
REASON_MANIFEST_MISSING = "MANIFEST_MISSING"
REASON_NUMERIC_UNBACKED = "NUMERIC_UNBACKED"
REASON_TRIAL_COUNT_UNDERSTATED = "TRIAL_COUNT_UNDERSTATED"
REASON_CRITIC_KIMI_ON_KIMI = "CRITIC_KIMI_ON_KIMI"
REASON_CRITIC_WROTE = "CRITIC_WROTE"
REASON_LEDGER_STATUS_BAD = "LEDGER_STATUS_BAD"
REASON_MISSING_FIELD = "MISSING_FIELD"
REASON_UNAUTHORIZED_AUTHOR = "UNAUTHORIZED_AUTHOR"

INTAKE_REASON = "INTERNAL_SOURCE_UNRESOLVED"


# --------------------------------------------------------------------------- #
# Small dataclasses
# --------------------------------------------------------------------------- #
@dataclass(frozen=True)
class VerifyResult:
    ok: bool
    reasons: tuple[str, ...] = ()
    resolved_id: str | None = None
    source_hash: str | None = None

    def as_dict(self) -> dict[str, Any]:
        return {
            "ok": self.ok,
            "reasons": list(self.reasons),
            "resolved_id": self.resolved_id,
            "source_hash": self.source_hash,
        }


@dataclass
class Paths:
    store_root: Path
    ledger_path: Path
    search_ledger_path: Path


class ResearchSourceError(RuntimeError):
    """Raised for hard, non-verify failures (mint/seal misuse)."""


# --------------------------------------------------------------------------- #
# Path / id helpers
# --------------------------------------------------------------------------- #
def resolve_paths(
    store_root: Path | str | None = None,
    ledger_path: Path | str | None = None,
    search_ledger_path: Path | str | None = None,
) -> Paths:
    """Resolve the injectable store/ledger paths with env fallbacks."""
    store = Path(store_root or os.environ.get(ENV_STORE_ROOT) or DEFAULT_STORE_ROOT)
    ledger = Path(ledger_path or os.environ.get(ENV_LEDGER) or DEFAULT_LEDGER_PATH)
    search = Path(
        search_ledger_path
        or os.environ.get(ENV_SEARCH_LEDGER)
        or DEFAULT_SEARCH_LEDGER_PATH
    )
    return Paths(store_root=store, ledger_path=ledger, search_ledger_path=search)


def normalise_id(value: str) -> str | None:
    """Return the canonical ``QM-RESEARCH-YYYY-NNNN`` id from any accepted form.

    Accepts a bare id, the ``QM-RESEARCH://<year>-<nnnn>`` reference form, and
    the intake-broad form.  Returns None when nothing matches.
    """
    value = (value or "").strip()
    if not value:
        return None
    ref = REF_RE.match(value)
    if ref:
        return f"QM-RESEARCH-{ref.group(1)}-{ref.group(2)}"
    if INTAKE_RE.match(value):
        return value
    return None


def is_internal_reference(value: str) -> bool:
    """True when *value* names the internal namespace (id or reference form)."""
    return normalise_id(value) is not None


def store_dir(research_id: str, paths: Paths) -> Path:
    return paths.store_root / research_id


def resolve(reference: str, paths: Paths | None = None) -> Path:
    """Resolve an id or ``QM-RESEARCH://`` reference to its store directory.

    Raises ResearchSourceError(NOT_FOUND) when the directory is absent.
    """
    paths = paths or resolve_paths()
    research_id = normalise_id(reference)
    if research_id is None:
        raise ResearchSourceError(f"{REASON_NOT_FOUND}:unparseable_reference:{reference}")
    directory = store_dir(research_id, paths)
    if not directory.is_dir():
        raise ResearchSourceError(f"{REASON_NOT_FOUND}:{research_id}")
    return directory


# --------------------------------------------------------------------------- #
# Hashing (contract Section 7)
# --------------------------------------------------------------------------- #
def sha256_bytes(data: bytes) -> str:
    return hashlib.sha256(data).hexdigest()


def sha256_file(path: Path) -> str:
    digest = hashlib.sha256()
    with path.open("rb") as handle:
        for chunk in iter(lambda: handle.read(1024 * 1024), b""):
            digest.update(chunk)
    return digest.hexdigest()


def source_hash(directory: Path) -> str:
    """``sha256(source.md)`` over the full file bytes (contract R-B)."""
    return sha256_file(directory / SOURCE_MD)


# --------------------------------------------------------------------------- #
# Manifest block (contract Section 4.1 / R-B)
# --------------------------------------------------------------------------- #
_MANIFEST_FENCE_RE = re.compile(
    r"```qm-source-manifest[ \t]*\n(?P<body>.*?)\n```",
    re.DOTALL,
)
_MANIFEST_LINE_RE = re.compile(r"^\s*(?P<file>[^#\s][^:]*?):\s*(?P<sha>[0-9a-f]{64})\s*$")


def parse_manifest(source_md_text: str) -> dict[str, str]:
    """Parse the fenced ``qm-source-manifest`` block -> {relpath: sha256}."""
    match = _MANIFEST_FENCE_RE.search(source_md_text)
    if not match:
        return {}
    entries: dict[str, str] = {}
    for line in match.group("body").splitlines():
        stripped = line.strip()
        if not stripped or stripped.startswith("#"):
            continue
        line_match = _MANIFEST_LINE_RE.match(line)
        if line_match:
            entries[line_match.group("file").strip()] = line_match.group("sha")
    return entries


def _computed_output_files(research: Mapping[str, Any]) -> list[str]:
    files: list[str] = []
    for item in research.get("computed_outputs") or []:
        if isinstance(item, Mapping) and item.get("file"):
            files.append(str(item["file"]))
    # Also fold in dataset paths, which the contract says must appear in the
    # manifest too (research.json.source_datasets[].sha256).
    for item in research.get("source_datasets") or []:
        if isinstance(item, Mapping) and item.get("path"):
            files.append(str(item["path"]))
    # De-duplicate while keeping deterministic order.
    seen: set[str] = set()
    ordered: list[str] = []
    for rel in files:
        if rel not in seen:
            seen.add(rel)
            ordered.append(rel)
    return ordered


def build_manifest_block(directory: Path) -> str:
    """Recompute the manifest block body over the sibling + cited files.

    Raises ResearchSourceError when a listed companion file is missing so an
    inconsistent artifact can never be sealed.
    """
    research = _read_json(directory / RESEARCH_JSON)
    entries: list[tuple[str, str]] = []
    for rel in CORE_MANIFEST_FILES:
        target = directory / rel
        if not target.is_file():
            raise ResearchSourceError(f"{REASON_MANIFEST_MISSING}:{rel}")
        entries.append((rel, sha256_file(target)))
    for rel in _computed_output_files(research):
        target = directory / rel
        if not target.is_file():
            raise ResearchSourceError(f"{REASON_MANIFEST_MISSING}:{rel}")
        entries.append((rel, sha256_file(target)))
    width = max((len(rel) + 1) for rel, _ in entries)
    lines = ["# Auto-generated by research_source.seal; do not hand-edit."]
    for rel, sha in entries:
        lines.append(f"{(rel + ':').ljust(width)} {sha}")
    return "\n".join(lines)


def _write_manifest_into_source(directory: Path, block_body: str) -> None:
    path = directory / SOURCE_MD
    text = path.read_text(encoding="utf-8")
    fence = f"```qm-source-manifest\n{block_body}\n```"
    if _MANIFEST_FENCE_RE.search(text):
        text = _MANIFEST_FENCE_RE.sub(lambda _m: fence, text, count=1)
    else:
        if not text.endswith("\n"):
            text += "\n"
        text += "\n## Source manifest\n\n" + fence + "\n"
    path.write_text(text, encoding="utf-8", newline="\n")


# --------------------------------------------------------------------------- #
# JSON helpers
# --------------------------------------------------------------------------- #
def _read_json(path: Path) -> dict[str, Any]:
    try:
        return json.loads(path.read_text(encoding="utf-8"))
    except (OSError, ValueError) as exc:
        raise ResearchSourceError(f"unreadable_json:{path}:{exc}") from exc


def _write_json(path: Path, payload: Mapping[str, Any]) -> None:
    path.write_text(
        json.dumps(payload, indent=2, ensure_ascii=False, sort_keys=True) + "\n",
        encoding="utf-8",
        newline="\n",
    )


def _dig(mapping: Mapping[str, Any], dotted: str) -> Any:
    node: Any = mapping
    for part in dotted.split("."):
        if not isinstance(node, Mapping) or part not in node:
            return None
        node = node[part]
    return node


# --------------------------------------------------------------------------- #
# Ledger (append-only, contract Section 6)
# --------------------------------------------------------------------------- #
def read_ledger(ledger_path: Path) -> list[dict[str, Any]]:
    if not ledger_path.is_file():
        return []
    rows: list[dict[str, Any]] = []
    for line in ledger_path.read_text(encoding="utf-8").splitlines():
        line = line.strip()
        if not line:
            continue
        try:
            rows.append(json.loads(line))
        except ValueError:
            continue
    return rows


def append_ledger(ledger_path: Path, row: Mapping[str, Any]) -> None:
    """Append exactly one JSON object line.  Never rewrites existing lines."""
    ledger_path.parent.mkdir(parents=True, exist_ok=True)
    with ledger_path.open("a", encoding="utf-8", newline="\n") as handle:
        handle.write(json.dumps(row, ensure_ascii=False, sort_keys=True) + "\n")


def latest_ledger_row(ledger_path: Path, research_id: str) -> dict[str, Any] | None:
    match: dict[str, Any] | None = None
    for row in read_ledger(ledger_path):
        if str(row.get("id")) == research_id:
            match = row
    return match


def _next_counter(ledger_path: Path, store_root: Path, year: str) -> int:
    """Next free monotonic counter for *year* (ledger + on-disk union)."""
    used: set[int] = set()
    for row in read_ledger(ledger_path):
        found = MINT_RE.match(str(row.get("id") or ""))
        if found and found.group(1) == year:
            used.add(int(found.group(2)))
    if store_root.is_dir():
        for child in store_root.iterdir():
            found = MINT_RE.match(child.name)
            if found and found.group(1) == year:
                used.add(int(found.group(2)))
    counter = 1
    while counter in used:
        counter += 1
    return counter


# --------------------------------------------------------------------------- #
# Skeleton writers
# --------------------------------------------------------------------------- #
def _utc_now_iso() -> str:
    return dt.datetime.now(dt.timezone.utc).replace(microsecond=0).isoformat()


def _utc_date() -> str:
    return dt.datetime.now(dt.timezone.utc).date().isoformat()


def _research_skeleton(
    research_id: str, author: str, model: str, task_id: str, created_utc: str
) -> dict[str, Any]:
    return {
        "schema": RESEARCH_SCHEMA,
        "research_id": research_id,
        "author": author,
        "model": model,
        "created_utc": created_utc,
        "originating_task_id": task_id,
        "research_question": "",
        "source_datasets": [],
        "computed_outputs": [],
        "quantitative_claims": [],
        "ml_method": None,
        "observations": "",
        "proposed_mechanism": "",
        "candidate_edge": "",
        "confidence": "",
        "confounders": [],
        "related_strategies": [],
        "research_trial_count": 0,
        "search_history_ref": "",
        "critic_receipt": CRITIC_JSON,
        "lineage": LINEAGE_JSON,
    }


def _lineage_skeleton(research_id: str, parent_version_id: str | None, version: int) -> dict[str, Any]:
    return {
        "schema": LINEAGE_SCHEMA,
        "research_id": research_id,
        "version": version,
        "parent_version_id": parent_version_id,
        "discovery_sample": {"period": "", "instruments": [], "dataset_ids": []},
        "validation_sample": {"period": "", "instruments": [], "dataset_ids": []},
        "preregistration": None,
        "mechanization": {"spec_section": "", "codex_implementable": False},
    }


def _critic_skeleton() -> dict[str, Any]:
    # Skeleton is intentionally NON-passing: a draft has no real critic yet, so
    # verify (which requires a non-kimi read-only critic) fails closed until a
    # genuine cross-vendor receipt is attached.
    return {
        "schema": CRITIC_SCHEMA,
        "chain_id": "",
        "plan": {
            "creator": {"vendor": "", "model": ""},
            "critic": {"vendor": "", "model": ""},
        },
        "stages": [],
        "critic_verdict": "",
        "finding_counts": {},
        "scope_drift": False,
        "repo_write": False,
        "critic_fallback_used": False,
        "critic_seat_final": "",
        "receipt_path": "",
        "generated_at_utc": "",
    }


def _source_md_skeleton(
    research_id: str, title: str, author: str, model: str, created: str, task_id: str
) -> str:
    year_nnnn = research_id.replace("QM-RESEARCH-", "")
    return (
        "---\n"
        f"source_id: {research_id}\n"
        f"title: {title}\n"
        "source_type: internal_research\n"
        f"source_author: {author}\n"
        f"source_model: {model}\n"
        f"created: {created}\n"
        f"originating_task_id: {task_id}\n"
        "status: draft\n"
        "parent_source_ids: []\n"
        f"source_artifact: QM-RESEARCH://{year_nnnn}\n"
        "---\n"
        "\n"
        f"# {title}\n"
        "\n"
        "## Research provenance\n"
        "Describe here how the edge was discovered, including any ML/statistical\n"
        "research instruments used.  This section is exempt from the card ML-term\n"
        "scan (contract Section 9.4).  Cite only figures backed by the manifest.\n"
        "\n"
        "## Structural cause\n"
        "State the mechanical thesis.  No ML terms belong in this section.\n"
        "\n"
        "## Source manifest\n"
        "\n"
        "```qm-source-manifest\n"
        "# placeholder; rewritten by research_source.seal\n"
        "```\n"
    )


# --------------------------------------------------------------------------- #
# mint / seal / remint
# --------------------------------------------------------------------------- #
def mint(
    *,
    author: str,
    model: str,
    task_id: str,
    title: str = "Untitled internal research",
    research_id: str | None = None,
    year: str | None = None,
    parent_version_id: str | None = None,
    version: int = 1,
    store_root: Path | str | None = None,
    ledger_path: Path | str | None = None,
) -> dict[str, Any]:
    """Allocate a new QM-RESEARCH id and scaffold its durable store directory.

    Writes ``research.json`` / ``lineage.json`` / ``critic_receipt.json`` stubs
    and a ``source.md`` skeleton with a self-consistent manifest block, then
    appends a ``draft`` ledger row.  Refuses if the id already exists.
    """
    if not author or not model or not task_id:
        raise ResearchSourceError("mint_requires:author,model,task_id")
    paths = resolve_paths(store_root, ledger_path)
    year = year or dt.datetime.now(dt.timezone.utc).strftime("%Y")
    if research_id is None:
        counter = _next_counter(paths.ledger_path, paths.store_root, year)
        research_id = f"QM-RESEARCH-{year}-{counter:04d}"
    if MINT_RE.match(research_id) is None:
        raise ResearchSourceError(f"bad_mint_id:{research_id}")

    directory = store_dir(research_id, paths)
    if directory.exists() or latest_ledger_row(paths.ledger_path, research_id) is not None:
        raise ResearchSourceError(f"id_exists:{research_id}")

    directory.mkdir(parents=True, exist_ok=False)
    created = _utc_date()
    created_utc = _utc_now_iso()
    _write_json(directory / RESEARCH_JSON, _research_skeleton(research_id, author, model, task_id, created_utc))
    _write_json(directory / LINEAGE_JSON, _lineage_skeleton(research_id, parent_version_id, version))
    _write_json(directory / CRITIC_JSON, _critic_skeleton())
    (directory / SOURCE_MD).write_text(
        _source_md_skeleton(research_id, title, author, model, created, task_id),
        encoding="utf-8",
        newline="\n",
    )
    # Make the skeleton manifest self-consistent immediately.
    _write_manifest_into_source(directory, build_manifest_block(directory))
    digest = source_hash(directory)

    append_ledger(
        paths.ledger_path,
        {
            "schema": LEDGER_SCHEMA,
            "id": research_id,
            "created": created_utc,
            "author": author,
            "model": model,
            "task_id": task_id,
            "sha256": digest,
            "status": "draft",
            "version": version,
            "parent_version_id": parent_version_id,
            "event": "mint",
        },
    )
    return {"id": research_id, "path": str(directory), "sha256": digest, "status": "draft"}


def seal(
    research_id: str,
    *,
    status: str = "reviewed",
    event: str = "status_change",
    store_root: Path | str | None = None,
    ledger_path: Path | str | None = None,
) -> dict[str, Any]:
    """Recompute the manifest + ``sha256(source.md)`` and append a ledger row.

    Any content edit changes ``sha256(source.md)`` and breaks the card binding;
    re-sealing re-anchors the ledger for the *same* version.  A genuine change
    of the frozen hypothesis must instead go through :func:`remint` (contract
    Section 6.2).
    """
    if status not in ALL_STATUSES:
        raise ResearchSourceError(f"bad_status:{status}")
    paths = resolve_paths(store_root, ledger_path)
    directory = store_dir(research_id, paths)
    if not directory.is_dir():
        raise ResearchSourceError(f"{REASON_NOT_FOUND}:{research_id}")

    _write_manifest_into_source(directory, build_manifest_block(directory))
    digest = source_hash(directory)
    research = _read_json(directory / RESEARCH_JSON)
    lineage = _read_json(directory / LINEAGE_JSON)

    append_ledger(
        paths.ledger_path,
        {
            "schema": LEDGER_SCHEMA,
            "id": research_id,
            "created": _utc_now_iso(),
            "author": str(research.get("author") or ""),
            "model": str(research.get("model") or ""),
            "task_id": str(research.get("originating_task_id") or ""),
            "sha256": digest,
            "status": status,
            "version": int(lineage.get("version") or 1),
            "parent_version_id": lineage.get("parent_version_id"),
            "event": event,
        },
    )
    return {"id": research_id, "path": str(directory), "sha256": digest, "status": status}


def remint(
    parent_id: str,
    *,
    author: str | None = None,
    model: str | None = None,
    task_id: str | None = None,
    store_root: Path | str | None = None,
    ledger_path: Path | str | None = None,
) -> dict[str, Any]:
    """Allocate a fresh id that supersedes *parent_id* with a parent link.

    Copies the parent's companion files, bumps ``lineage.version`` and links
    ``parent_version_id`` (contract Section 6.2 immutability).
    """
    paths = resolve_paths(store_root, ledger_path)
    parent_dir = store_dir(parent_id, paths)
    if not parent_dir.is_dir():
        raise ResearchSourceError(f"{REASON_NOT_FOUND}:{parent_id}")
    parent_research = _read_json(parent_dir / RESEARCH_JSON)
    parent_lineage = _read_json(parent_dir / LINEAGE_JSON)
    match = MINT_RE.match(parent_id)
    if not match:
        raise ResearchSourceError(f"bad_parent_id:{parent_id}")
    year = match.group(1)
    result = mint(
        author=author or str(parent_research.get("author") or "Kimi"),
        model=model or str(parent_research.get("model") or "UNKNOWN"),
        task_id=task_id or str(parent_research.get("originating_task_id") or ""),
        title=f"Re-mint of {parent_id}",
        year=year,
        parent_version_id=parent_id,
        version=int(parent_lineage.get("version") or 1) + 1,
        store_root=paths.store_root,
        ledger_path=paths.ledger_path,
    )
    return result


# --------------------------------------------------------------------------- #
# verify (contract Section 9.1)
# --------------------------------------------------------------------------- #
def _is_kimi(value: Any) -> bool:
    return "kimi" in str(value or "").strip().lower()


def load_authorized_authors(
    config_path: Path | str | None = None,
) -> tuple[frozenset[str], str]:
    """Return the authorized-author set (lower-cased) and the multi-agent prefix.

    Directive §37 (OWNER-DEC-CBE-20260915): an internal research artifact may be
    authored by Kimi, Fable, another authorized research agent, or a documented
    multi-agent collaboration.  The set lives in
    ``config/research_source.v1.json`` (OWNER-tunable) with an env override
    ``QM_RESEARCH_AUTHORIZED_AUTHORS`` (comma-separated).  A missing/unreadable
    config falls back to the committed default set — never to "anything goes".
    """
    override = os.environ.get(ENV_AUTHORIZED_AUTHORS)
    if override is not None and override.strip():
        authors = tuple(a.strip() for a in override.split(",") if a.strip())
        prefix = _FALLBACK_MULTI_AGENT_PREFIX
    else:
        config: Mapping[str, Any] = {}
        path = Path(config_path) if config_path else DEFAULT_SOURCE_CONFIG_PATH
        try:
            config = json.loads(path.read_text(encoding="utf-8"))
        except (OSError, ValueError):
            config = {}
        raw_authors = config.get("authorized_authors")
        authors = (
            tuple(str(a) for a in raw_authors)
            if isinstance(raw_authors, (list, tuple)) and raw_authors
            else _FALLBACK_AUTHORIZED_AUTHORS
        )
        prefix = str(config.get("multi_agent_prefix") or _FALLBACK_MULTI_AGENT_PREFIX)
    return frozenset(a.strip().lower() for a in authors if a.strip()), prefix.strip().lower()


def is_authorized_author(
    value: Any,
    *,
    config_path: Path | str | None = None,
    authors: frozenset[str] | None = None,
    multi_agent_prefix: str | None = None,
) -> bool:
    """True when *value* names an authorized internal research author.

    Accepts an exact (case-insensitive) member of the authorized set, or a
    documented multi-agent collaboration (``multi-agent:<list>``).  Empty/None
    is never authorized (fail closed).
    """
    if authors is None or multi_agent_prefix is None:
        loaded_authors, loaded_prefix = load_authorized_authors(config_path)
        authors = authors if authors is not None else loaded_authors
        multi_agent_prefix = (
            multi_agent_prefix if multi_agent_prefix is not None else loaded_prefix
        )
    text = str(value or "").strip().lower()
    if not text:
        return False
    if multi_agent_prefix and text.startswith(multi_agent_prefix):
        # A documented multi-agent collaboration must name at least one agent.
        return bool(text[len(multi_agent_prefix):].strip())
    return text in authors


def verify(
    *,
    research_id: str | None = None,
    card_frontmatter: Mapping[str, Any] | None = None,
    hypothesis_family: str | None = None,
    store_root: Path | str | None = None,
    ledger_path: Path | str | None = None,
    search_ledger_path: Path | str | None = None,
    source_config_path: Path | str | None = None,
) -> VerifyResult:
    """Deterministic, fail-closed verify for an internal research source.

    Provide either *research_id* or *card_frontmatter* (from which the id,
    ``source_hash`` and ``research_trial_count`` are read).  Returns a
    VerifyResult; ``ok`` is False with one or more sub-reason codes on any miss.
    """
    paths = resolve_paths(store_root, ledger_path, search_ledger_path)
    reasons: list[str] = []

    fm = dict(card_frontmatter or {})
    if research_id is None:
        candidate = str(fm.get("source_id") or "")
        research_id = normalise_id(candidate) or normalise_id(
            str(fm.get("source_artifact") or fm.get("source_uri") or "")
        )
    else:
        research_id = normalise_id(research_id) or research_id

    if not research_id:
        return VerifyResult(ok=False, reasons=(REASON_NOT_FOUND,))

    directory = store_dir(research_id, paths)
    if not directory.is_dir() or not (directory / SOURCE_MD).is_file():
        return VerifyResult(ok=False, reasons=(REASON_NOT_FOUND,), resolved_id=research_id)

    digest = source_hash(directory)
    source_text = (directory / SOURCE_MD).read_text(encoding="utf-8")

    # Card <-> source binding (contract Section 7).
    card_hash = str(fm.get("source_hash") or "").strip().lower()
    if card_hash and card_hash != digest:
        reasons.append(REASON_HASH_MISMATCH)

    # Manifest recompute (contract Section 4.1 / R-B).
    manifest = parse_manifest(source_text)
    for rel in CORE_MANIFEST_FILES:
        if rel not in manifest:
            reasons.append(f"{REASON_MANIFEST_MISSING}:{rel}")
            continue
        target = directory / rel
        if not target.is_file():
            reasons.append(f"{REASON_MANIFEST_MISSING}:{rel}")
        elif sha256_file(target) != manifest[rel]:
            reasons.append(f"{REASON_HASH_MISMATCH}:{rel}")

    # Load companion JSON (best effort; hard-missing already flagged above).
    research: dict[str, Any] = {}
    critic: dict[str, Any] = {}
    try:
        research = _read_json(directory / RESEARCH_JSON)
    except ResearchSourceError:
        reasons.append(f"{REASON_MANIFEST_MISSING}:{RESEARCH_JSON}")
    try:
        critic = _read_json(directory / CRITIC_JSON)
    except ResearchSourceError:
        reasons.append(f"{REASON_MANIFEST_MISSING}:{CRITIC_JSON}")

    # Required research.json fields (contract Section 4.2).
    for field_name in RESEARCH_REQUIRED_FIELDS:
        if field_name not in research:
            reasons.append(f"{REASON_MISSING_FIELD}:{field_name}")
        elif field_name not in _RESEARCH_EMPTY_OK and research.get(field_name) in ("", None):
            reasons.append(f"{REASON_MISSING_FIELD}:{field_name}")

    # Authorized author (directive §37 / OWNER-DEC-CBE-20260915). The durable
    # artifact's author must be an authorized internal research agent (Kimi,
    # Fable, Claude, Codex, Antigravity) or a documented multi-agent
    # collaboration. A present-but-unauthorized author fails closed; an empty
    # author is already flagged above as MISSING_FIELD:author. This generalizes
    # the previously Kimi-centric expectation while keeping every other
    # provenance requirement identical.
    author_value = research.get("author")
    if author_value not in ("", None) and not is_authorized_author(
        author_value, config_path=source_config_path
    ):
        reasons.append(f"{REASON_UNAUTHORIZED_AUTHOR}:{author_value}")

    # Numeric provenance (contract Section 4.4 / R-C): every quantitative claim
    # must cite a computed_outputs[].claim_ref whose file hash is in the
    # manifest and matches.
    claim_refs: dict[str, str] = {}
    for item in research.get("computed_outputs") or []:
        if not isinstance(item, Mapping):
            continue
        ref = str(item.get("claim_ref") or "")
        rel = str(item.get("file") or "")
        if not ref or not rel:
            reasons.append(REASON_NUMERIC_UNBACKED)
            continue
        if rel not in manifest:
            reasons.append(f"{REASON_NUMERIC_UNBACKED}:{rel}")
            continue
        target = directory / rel
        if not target.is_file() or sha256_file(target) != manifest[rel]:
            reasons.append(f"{REASON_NUMERIC_UNBACKED}:{rel}")
            continue
        claim_refs[ref] = rel
    for item in research.get("quantitative_claims") or []:
        if not isinstance(item, Mapping):
            reasons.append(REASON_NUMERIC_UNBACKED)
            continue
        ref = str(item.get("computed_output_ref") or "")
        if not ref or ref not in claim_refs:
            reasons.append(REASON_NUMERIC_UNBACKED)

    # Ledger status + edit-after-seal detection (contract Section 6).
    row = latest_ledger_row(paths.ledger_path, research_id)
    if row is None:
        reasons.append(f"{REASON_LEDGER_STATUS_BAD}:MISSING")
        status: str | None = None
    else:
        status = str(row.get("status") or "")
        if status not in ADMISSIBLE_STATUSES:
            reasons.append(f"{REASON_LEDGER_STATUS_BAD}:{status or 'EMPTY'}")
        ledger_sha = str(row.get("sha256") or "").strip().lower()
        if ledger_sha and ledger_sha != digest:
            # source.md was edited after the last seal (contract Section 6.2).
            reasons.append(f"{REASON_HASH_MISMATCH}:ledger")

    # Cross-vendor read-only critic (contract Section 4.5 / R-D).  Required for
    # any admissible status (all of which are >= reviewed).
    require_critic = status in ADMISSIBLE_STATUSES if status else True
    if require_critic:
        for path in CRITIC_REQUIRED_PATHS:
            if _dig(critic, path) in (None, ""):
                reasons.append(f"{REASON_MISSING_FIELD}:critic.{path}")
        if bool(critic.get("repo_write")) is True:
            reasons.append(REASON_CRITIC_WROTE)
        creator_vendor = _dig(critic, "plan.creator.vendor")
        critic_vendor = _dig(critic, "plan.critic.vendor")
        critic_final = critic.get("critic_seat_final")
        if _is_kimi(creator_vendor) and (
            _is_kimi(critic_vendor) or _is_kimi(critic_final)
        ):
            reasons.append(REASON_CRITIC_KIMI_ON_KIMI)

    # Trial-count understatement (contract Section 4.3 / R-C).
    family = hypothesis_family or str(
        research.get("search_history_ref") or ""
    ) or research_id
    declared = fm.get("research_trial_count")
    if declared is None:
        declared = research.get("research_trial_count")
    ledger_count = _search_ledger_count(paths.search_ledger_path, family)
    if ledger_count > 0:
        try:
            declared_int = int(str(declared))
        except (TypeError, ValueError):
            declared_int = -1
        if declared_int < ledger_count:
            reasons.append(
                f"{REASON_TRIAL_COUNT_UNDERSTATED}:declared={declared}:ledger={ledger_count}"
            )

    return VerifyResult(
        ok=not reasons,
        reasons=tuple(reasons),
        resolved_id=research_id,
        source_hash=digest,
    )


def _search_ledger_count(search_ledger_path: Path, family: str) -> int:
    """Count research-layer searches recorded for *family* (contract 4.3)."""
    if not family or not search_ledger_path.is_file():
        return 0
    total = 0
    for row in read_ledger(search_ledger_path):
        fam = str(row.get("hypothesis_family") or row.get("family") or "")
        if fam != family:
            continue
        if "search_count" in row:
            try:
                total = max(total, int(row["search_count"]))
            except (TypeError, ValueError):
                continue
        else:
            total += 1
    return total


# --------------------------------------------------------------------------- #
# CLI
# --------------------------------------------------------------------------- #
def _add_path_args(parser: argparse.ArgumentParser) -> None:
    parser.add_argument("--store-root", type=Path, default=None)
    parser.add_argument("--ledger", type=Path, default=None)
    parser.add_argument("--search-ledger", type=Path, default=None)


def build_parser() -> argparse.ArgumentParser:
    parser = argparse.ArgumentParser(description=__doc__)
    sub = parser.add_subparsers(dest="command", required=True)

    p_mint = sub.add_parser("mint", help="allocate a new QM-RESEARCH id + scaffold")
    p_mint.add_argument("--author", required=True)
    p_mint.add_argument("--model", required=True)
    p_mint.add_argument("--task-id", required=True)
    p_mint.add_argument("--title", default="Untitled internal research")
    p_mint.add_argument("--id", dest="research_id", default=None)
    p_mint.add_argument("--year", default=None)
    _add_path_args(p_mint)

    p_resolve = sub.add_parser("resolve", help="id or QM-RESEARCH://id -> store path")
    p_resolve.add_argument("reference")
    _add_path_args(p_resolve)

    p_verify = sub.add_parser("verify", help="verify an internal source (fail-closed)")
    p_verify.add_argument("--id", dest="research_id", default=None)
    p_verify.add_argument("--card", type=Path, default=None)
    p_verify.add_argument("--source-config", type=Path, default=None)
    _add_path_args(p_verify)

    p_seal = sub.add_parser("seal", help="recompute manifest+sha, append ledger row")
    p_seal.add_argument("research_id")
    p_seal.add_argument("--status", default="reviewed", choices=list(ALL_STATUSES))
    _add_path_args(p_seal)

    p_remint = sub.add_parser("remint", help="new version id superseding a parent")
    p_remint.add_argument("parent_id")
    _add_path_args(p_remint)
    return parser


def _card_frontmatter_from_file(path: Path) -> dict[str, Any]:
    text = path.read_text(encoding="utf-8-sig", errors="replace")
    match = re.match(r"^(?:\s*<!--.*?-->\s*)*---\s*\n(.*?)\n---", text, re.DOTALL)
    if not match:
        return {}
    result: dict[str, Any] = {}
    for line in match.group(1).splitlines():
        line_match = re.match(r"^([A-Za-z_][A-Za-z0-9_]*)\s*:\s*(.+?)\s*$", line)
        if line_match:
            value = line_match.group(2).strip().strip('"').strip("'")
            if value and not value.startswith("-") and value not in {"|", ">"}:
                result[line_match.group(1)] = value
    return result


def main(argv: list[str] | None = None) -> int:
    args = build_parser().parse_args(argv)
    try:
        if args.command == "mint":
            result = mint(
                author=args.author,
                model=args.model,
                task_id=args.task_id,
                title=args.title,
                research_id=args.research_id,
                year=args.year,
                store_root=args.store_root,
                ledger_path=args.ledger,
            )
            print(json.dumps(result, sort_keys=True))
            return 0
        if args.command == "resolve":
            directory = resolve(
                args.reference,
                resolve_paths(args.store_root, args.ledger, args.search_ledger),
            )
            print(str(directory))
            return 0
        if args.command == "verify":
            fm = _card_frontmatter_from_file(args.card) if args.card else None
            result = verify(
                research_id=args.research_id,
                card_frontmatter=fm,
                store_root=args.store_root,
                ledger_path=args.ledger,
                search_ledger_path=args.search_ledger,
                source_config_path=args.source_config,
            )
            print(json.dumps(result.as_dict(), sort_keys=True))
            return 0 if result.ok else 1
        if args.command == "seal":
            result = seal(
                args.research_id,
                status=args.status,
                store_root=args.store_root,
                ledger_path=args.ledger,
            )
            print(json.dumps(result, sort_keys=True))
            return 0
        if args.command == "remint":
            result = remint(
                args.parent_id,
                store_root=args.store_root,
                ledger_path=args.ledger,
            )
            print(json.dumps(result, sort_keys=True))
            return 0
    except ResearchSourceError as exc:
        print(json.dumps({"ok": False, "error": str(exc)}, sort_keys=True))
        return 2
    return 2


if __name__ == "__main__":
    sys.exit(main())
