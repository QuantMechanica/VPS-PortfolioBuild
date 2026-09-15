"""Deterministic Strategy Wiki projection (OWNER follow-up directive §2-§8).

Every canonical QuantMechanica strategy must be findable in the Company
Reference Vault, without maintaining a second hand-kept truth. This tool renders
ONE generated node per canonical strategy record — the deterministic projection
of:

    EA registry  +  canonical Strategy Cards  +  gate read-model
      +  research source / lineage  +  book-evolution membership

Repo Card remains authoritative; the Vault node is the human/company knowledge
projection (directive §3). Hand-written nodes under ``09 Strategy Wiki/
strategies/`` are NEVER touched — generated nodes live under
``09 Strategy Wiki/generated/<projection_class>/`` and cross-link to a
hand-written node when ids match.

Subcommands
-----------
* ``build``  — render the generated nodes (idempotent; writes only changed files).
* ``index``  — rebuild the generated ``_INDEX`` (per class + per family), and,
               with ``--init-root-index`` / an existing marker, refresh a
               delimited generated block inside the hand-written top-level
               ``_INDEX.md`` without disturbing the surrounding hand text.
* ``lint``   — the §6 machine check: canonical records vs valid projections →
               missing / stale / duplicate / orphan / invalid_link /
               unresolved_source / unresolved_lineage; writes the
               ``strategy_wiki_sync.json`` health read-model with
               ``STRATEGY_WIKI_SYNC = GREEN|AMBER|RED``; exit non-zero on RED.
* ``status`` — print the last health read-model (no writes).

Determinism (directive §7)
--------------------------
Same canonical inputs → byte-identical nodes. Node bodies carry NO wall-clock;
each node's ``inputs_sha256`` is the digest of THAT node's own resolved inputs,
so an unrelated input change does not rewrite every node (and does not spam the
cloud sync). Wall-clock lives only in the sidecar (``generated/.sync/state.json``)
and the health read-model.
"""
from __future__ import annotations

import argparse
import csv
import datetime as dt
import hashlib
import json
import os
import re
import sys
from dataclasses import dataclass, field
from pathlib import Path
from typing import Any, Iterable

# Dual import: works as ``tools.strategy_farm.strategy_wiki_sync`` (pytest from
# repo root) and as ``strategy_wiki_sync`` (conftest puts tools/strategy_farm on
# sys.path; CLI run from the worktree root).
try:  # pragma: no cover - import shim
    from tools.strategy_farm import vault_paths
except ImportError:  # pragma: no cover - import shim
    import vault_paths  # type: ignore

GENERATOR = "strategy_wiki_sync/v1"
HEALTH_SCHEMA = "qm.strategy-wiki-sync.health/v1"
SIDECAR_SCHEMA = "qm.strategy-wiki-sync.sidecar/v1"
LINEAGE_SCHEMA = "qm.lineage-map/v1"

# Explicit "no value" tokens (directive §4 — never silently ambiguous).
NOT_EVALUATED = "NOT_EVALUATED"
UNKNOWN = "UNKNOWN"
NOT_APPLICABLE = "NOT_APPLICABLE"
EVIDENCE_MISSING = "EVIDENCE_MISSING"

# Projection classes (directive §5). Order = folder order in the index.
CLASS_ACTIVE = "ACTIVE_CANONICAL"
CLASS_DRAFT = "DRAFT"
CLASS_RETIRED = "RETIRED"
CLASS_REJECTED = "REJECTED"
CLASS_DUPLICATE = "DUPLICATE"
CLASS_SUPERSEDED = "SUPERSEDED"
CLASS_HISTORICAL = "HISTORICAL"
PROJECTION_CLASSES = (
    CLASS_ACTIVE,
    CLASS_DRAFT,
    CLASS_RETIRED,
    CLASS_REJECTED,
    CLASS_DUPLICATE,
    CLASS_SUPERSEDED,
    CLASS_HISTORICAL,
)
# The canonical universe for the completeness lint = ACTIVE_CANONICAL only.
# (directive §3/§6: "every canonical Strategy Card must be discoverable"; drafts
# and historical/rejected nodes are findable but are not "missing" when absent.)
CANONICAL_CLASSES = frozenset({CLASS_ACTIVE})

# Terminal reject verdicts (per_ea.final_verdict) that force REJECTED.
_TERMINAL_REJECT = {"REJECT", "REJECTED", "FAIL_TERMINAL", "RETIRE", "RETIRED"}

# Markers delimiting the generated block inside the hand-written root _INDEX.md.
ROOT_INDEX_BEGIN = "<!-- STRATEGY_WIKI_SYNC:BEGIN (generated; do not edit inside) -->"
ROOT_INDEX_END = "<!-- STRATEGY_WIKI_SYNC:END -->"


# ---------------------------------------------------------------------------
# Source configuration (all overridable → testable)
# ---------------------------------------------------------------------------
def _repo_root() -> Path:
    return Path(__file__).resolve().parents[2]


@dataclass(frozen=True)
class Sources:
    repo_root: Path
    vault_override: Path | None
    d_runtime: Path
    pipeline_state: Path
    book_dxz: Path
    book_ftmo: Path
    lineage_map: Path
    health_out: Path

    @property
    def ea_registry(self) -> Path:
        return self.repo_root / "framework" / "registry" / "ea_id_registry.csv"

    @property
    def generated_dir(self) -> Path:
        return vault_paths.strategy_wiki_generated_dir(self.vault_override)

    @property
    def strategies_dir(self) -> Path:
        return vault_paths.strategy_wiki_strategies_dir(self.vault_override)

    @property
    def wiki_root(self) -> Path:
        return vault_paths.strategy_wiki_root(self.vault_override)

    @property
    def sidecar_path(self) -> Path:
        return self.generated_dir / ".sync" / "state.json"

    def card_stores(self) -> list[tuple[str, Path, str]]:
        """(store_name, directory, class_hint), most-authoritative first.

        Repo cards win over D:\\ runtime cards (directive §3 "Repo Card remains
        authoritative"). class_hint feeds the projection-class precedence.
        """
        r, d = self.repo_root, self.d_runtime
        return [
            ("repo_approved", r / "strategy-seeds" / "cards" / "approved", "approved"),
            ("repo_artifacts_approved", r / "artifacts" / "cards_approved", "approved"),
            ("repo_seed", r / "strategy-seeds" / "cards", "seed"),  # top-level only
            ("d_approved", d / "artifacts" / "cards_approved", "approved"),
            ("d_review", d / "artifacts" / "cards_review", "review"),
            ("d_draft", d / "artifacts" / "cards_draft", "draft"),
            ("d_rejected", d / "artifacts" / "cards_rejected", "rejected"),
            ("d_duplicates", d / "artifacts" / "card_duplicates_g0", "duplicate"),
            ("d_blocked", d / "artifacts" / "cards_blocked_r3_data", "blocked"),
            ("d_recovery", d / "artifacts" / "cards_recovery", "recovery"),
        ]


def default_sources(
    *,
    repo_root: Path | None = None,
    vault_override: Path | None = None,
    d_runtime: Path | None = None,
    pipeline_state: Path | None = None,
    book_dxz: Path | None = None,
    book_ftmo: Path | None = None,
    lineage_map: Path | None = None,
    health_out: Path | None = None,
) -> Sources:
    rr = repo_root or _repo_root()
    d = d_runtime or Path(r"D:\QM\strategy_farm")
    state = Path(r"D:\QM\reports\state")
    return Sources(
        repo_root=rr,
        vault_override=vault_override,
        d_runtime=d,
        pipeline_state=pipeline_state or (state / "pipeline_state.json"),
        book_dxz=book_dxz or (state / "book_evolution_dxz.json"),
        book_ftmo=book_ftmo or (state / "book_evolution_ftmo.json"),
        lineage_map=lineage_map or (state / "lineage_map.json"),
        health_out=health_out or (state / "strategy_wiki_sync.json"),
    )


# ---------------------------------------------------------------------------
# Small parsing helpers
# ---------------------------------------------------------------------------
_FM_RE = re.compile(r"^(?:\s*<!--.*?-->\s*)*---\s*\n(.*?)\n---", re.DOTALL)
_KV_RE = re.compile(r"^([A-Za-z_][A-Za-z0-9_]*)\s*:\s*(.*?)\s*$")
_LIST_ITEM_RE = re.compile(r"^\s*-\s+(.*?)\s*$")
_EA_NUM_RE = re.compile(r"(?:QM5[_-])?0*(\d+)")


def normalize_ea_key(value: Any) -> str | None:
    """Return ``QM5_<int>`` for any EA-id spelling, else None."""
    if value is None:
        return None
    s = str(value).strip()
    if not s or s.upper() in {"TBD", "-", "NONE", "NULL"}:
        return None
    m = re.fullmatch(r"(?:QM5[_-])?(\d+)", s)
    if not m:
        return None
    return f"QM5_{int(m.group(1))}"


def slugify(value: str) -> str:
    s = re.sub(r"[^a-z0-9]+", "-", str(value).lower()).strip("-")
    return s or "unnamed"


def _read_text(path: Path) -> str:
    raw = path.read_bytes()
    enc = "utf-8-sig" if raw.startswith(b"\xef\xbb\xbf") else "utf-8"
    return raw.decode(enc, errors="replace")


def parse_frontmatter(text: str) -> tuple[dict[str, str], dict[str, list[str]]]:
    """Flat scalar keys + simple ``- item`` list keys from YAML frontmatter."""
    scalars: dict[str, str] = {}
    lists: dict[str, list[str]] = {}
    m = _FM_RE.match(text)
    if not m:
        return scalars, lists
    block = m.group(1)
    current_list: str | None = None
    for line in block.split("\n"):
        if not line.strip():
            current_list = None
            continue
        li = _LIST_ITEM_RE.match(line)
        if li and current_list is not None and line[:1] in " \t-":
            lists.setdefault(current_list, []).append(
                li.group(1).strip().strip('"').strip("'")
            )
            continue
        kv = _KV_RE.match(line)
        if kv:
            key, val = kv.group(1), kv.group(2).strip()
            if val == "" or val in {"|", ">"}:
                current_list = key  # a following ``- item`` block or block scalar
                if val == "":
                    lists.setdefault(key, [])
                continue
            current_list = None
            scalars[key] = val.strip('"').strip("'")
    return scalars, lists


# ---------------------------------------------------------------------------
# Card scan
# ---------------------------------------------------------------------------
@dataclass
class Card:
    path: Path
    store: str
    class_hint: str
    rank: int
    scalars: dict[str, str]
    lists: dict[str, list[str]]
    card_hash: str
    ea_key: str | None
    slug: str


def scan_cards(sources: Sources) -> list[Card]:
    cards: list[Card] = []
    for rank, (store, directory, hint) in enumerate(sources.card_stores()):
        if not directory.is_dir():
            continue
        if store == "repo_seed":
            paths = sorted(p for p in directory.glob("*.md") if p.is_file())
        else:
            paths = sorted(p for p in directory.rglob("*.md") if p.is_file())
        for p in paths:
            try:
                text = _read_text(p)
            except OSError:
                continue
            scalars, lists = parse_frontmatter(text)
            ea_key = normalize_ea_key(scalars.get("ea_id"))
            slug = (scalars.get("slug") or "").strip() or p.stem.replace("_card", "")
            cards.append(
                Card(
                    path=p,
                    store=store,
                    class_hint=hint,
                    rank=rank,
                    scalars=scalars,
                    lists=lists,
                    card_hash=vault_paths.card_content_sha256(text),
                    ea_key=ea_key,
                    slug=slug,
                )
            )
    return cards


# ---------------------------------------------------------------------------
# Registry / pipeline / books / lineage
# ---------------------------------------------------------------------------
def load_registry(sources: Sources) -> dict[str, dict[str, str]]:
    out: dict[str, dict[str, str]] = {}
    path = sources.ea_registry
    if not path.is_file():
        return out
    with path.open(encoding="utf-8-sig", newline="") as fh:
        for row in csv.DictReader(fh):
            key = normalize_ea_key(row.get("ea_id"))
            if key:
                out[key] = row
    return out


def load_pipeline(sources: Sources) -> dict[str, dict[str, Any]]:
    out: dict[str, dict[str, Any]] = {}
    path = sources.pipeline_state
    if not path.is_file():
        return out
    try:
        data = json.loads(path.read_text(encoding="utf-8"))
    except (OSError, json.JSONDecodeError):
        return out
    for entry in data.get("per_ea") or []:
        key = normalize_ea_key(entry.get("ea_id"))
        if key:
            out[key] = entry
    return out


def _book_membership(path: Path) -> dict[str, str]:
    """key -> INCUMBENT | CHALLENGER from a book-evolution read-model."""
    out: dict[str, str] = {}
    if not path.is_file():
        return out
    try:
        data = json.loads(path.read_text(encoding="utf-8"))
    except (OSError, json.JSONDecodeError):
        return out
    for sleeve in (data.get("incumbent") or {}).get("sleeves") or []:
        key = normalize_ea_key(sleeve.get("ea_id"))
        if key:
            out[key] = "INCUMBENT"
    for ch in data.get("challengers") or []:
        key = normalize_ea_key(ch.get("ea_id"))
        if key and key not in out:
            out[key] = "CHALLENGER"
    return out


@dataclass
class Lineage:
    present: bool
    nodes: dict[str, dict[str, Any]]
    # key -> list of {"other": key, "relation": str, "direction": "from"|"to"}
    relations: dict[str, list[dict[str, str]]]
    families: dict[str, list[str]]


def load_lineage(sources: Sources) -> Lineage:
    path = sources.lineage_map
    if not path.is_file():
        return Lineage(False, {}, {}, {})
    try:
        data = json.loads(path.read_text(encoding="utf-8"))
    except (OSError, json.JSONDecodeError):
        return Lineage(False, {}, {}, {})
    nodes: dict[str, dict[str, Any]] = {}
    for raw_id, node in (data.get("nodes") or {}).items():
        key = normalize_ea_key(raw_id)
        if key:
            nodes[key] = node if isinstance(node, dict) else {}
    relations: dict[str, list[dict[str, str]]] = {}
    for edge in data.get("edges") or []:
        a = normalize_ea_key(edge.get("from"))
        b = normalize_ea_key(edge.get("to"))
        rel = str(edge.get("relation") or "").strip() or UNKNOWN
        if not a or not b:
            continue
        relations.setdefault(a, []).append({"other": b, "relation": rel, "direction": "from"})
        relations.setdefault(b, []).append({"other": a, "relation": rel, "direction": "to"})
    families: dict[str, list[str]] = {}
    for fam, ids in (data.get("families") or {}).items():
        norm = sorted({k for k in (normalize_ea_key(i) for i in ids or []) if k})
        if norm:
            families[str(fam)] = norm
    return Lineage(True, nodes, relations, families)


# ---------------------------------------------------------------------------
# Record model + projection class
# ---------------------------------------------------------------------------
@dataclass
class Record:
    key: str  # QM5_<n> or slug:<slug>
    ea_key: str | None
    slug: str
    card: Card | None = None
    store_hints: set[str] = field(default_factory=set)
    registry: dict[str, str] | None = None
    pipeline: dict[str, Any] | None = None
    dxz: str = ""
    ftmo: str = ""
    lineage_node: dict[str, Any] | None = None
    lineage_relations: list[dict[str, str]] = field(default_factory=list)


def build_records(
    sources: Sources,
    cards: list[Card],
    registry: dict[str, dict[str, str]],
    pipeline: dict[str, dict[str, Any]],
    dxz: dict[str, str],
    ftmo: dict[str, str],
    lineage: Lineage,
) -> dict[str, Record]:
    records: dict[str, Record] = {}

    def rec_for(ea_key: str | None, slug: str) -> Record:
        key = ea_key if ea_key else f"slug:{slugify(slug)}"
        r = records.get(key)
        if r is None:
            r = Record(key=key, ea_key=ea_key, slug=slug)
            records[key] = r
        return r

    # Cards define most records; authoritative card = lowest rank.
    for card in cards:
        r = rec_for(card.ea_key, card.slug)
        r.store_hints.add(card.class_hint)
        if r.card is None or card.rank < r.card.rank:
            r.card = card
            if not r.slug:
                r.slug = card.slug

    # Registry rows (may add id-only records with no card).
    for key, row in registry.items():
        r = rec_for(key, (row.get("slug") or "").strip())
        r.registry = row

    # Pipeline entries.
    for key, entry in pipeline.items():
        r = rec_for(key, "")
        r.pipeline = entry

    # Book membership + lineage attach to existing/new id records.
    for key, status in dxz.items():
        rec_for(key, "").dxz = status
    for key, status in ftmo.items():
        rec_for(key, "").ftmo = status
    for key, node in lineage.nodes.items():
        rec_for(key, "").lineage_node = node
    for key, rels in lineage.relations.items():
        rec_for(key, "").lineage_relations = rels

    # Fill slug fallbacks.
    for r in records.values():
        if not r.slug:
            if r.registry and r.registry.get("slug"):
                r.slug = r.registry["slug"].strip()
            elif r.card:
                r.slug = r.card.slug
            elif r.ea_key:
                r.slug = ""
    return records


def _card_approved(record: Record) -> bool:
    if "approved" in record.store_hints:
        return True
    if record.card:
        g0 = (record.card.scalars.get("g0_status") or "").upper()
        st = (record.card.scalars.get("status") or "").upper()
        if g0 == "APPROVED" or st == "APPROVED":
            return True
    return False


def _is_superseded(record: Record) -> bool:
    if record.card and record.card.scalars.get("superseded_by"):
        return True
    for rel in record.lineage_relations:
        # This node is the target of a "superseded" edge → it is superseded.
        if rel.get("relation") == "superseded" and rel.get("direction") == "to":
            return True
    return False


def projection_class(record: Record) -> str:
    """Deterministic projection class (directive §5).

    Precedence (first match wins):
      1. REJECTED   — card in a rejected store, OR terminal reject verdict.
      2. DUPLICATE  — card in the duplicates store.
      3. SUPERSEDED — card ``superseded_by`` set, OR a lineage ``superseded``
                      edge names this node as the superseded side.
      4. RETIRED    — EA registry status == retired.
      5. ACTIVE_CANONICAL — an approved card exists (approved store or
                      ``g0_status: APPROVED``) and none of the above.
      6. DRAFT      — draft/review/seed store, or card status DRAFT / g0 PENDING.
      7. HISTORICAL — a record exists (registry / pipeline / lineage) but no
                      canonical card qualifies it as any of the above.
    """
    verdict = ""
    if record.pipeline:
        verdict = str(record.pipeline.get("final_verdict") or "").upper()
    if "rejected" in record.store_hints or verdict in _TERMINAL_REJECT:
        return CLASS_REJECTED
    if "duplicate" in record.store_hints:
        return CLASS_DUPLICATE
    if _is_superseded(record):
        return CLASS_SUPERSEDED
    reg_status = ((record.registry or {}).get("status") or "").strip().lower()
    if reg_status == "retired":
        return CLASS_RETIRED
    if _card_approved(record):
        return CLASS_ACTIVE
    card = record.card
    if card is not None:
        st = (card.scalars.get("status") or "").upper()
        g0 = (card.scalars.get("g0_status") or "").upper()
        if card.class_hint in {"seed", "draft", "review"} or st == "DRAFT" or g0 == "PENDING":
            return CLASS_DRAFT
    return CLASS_HISTORICAL


# ---------------------------------------------------------------------------
# Field resolution (§4)
# ---------------------------------------------------------------------------
def _first(*values: Any) -> str:
    for v in values:
        if v is None:
            continue
        s = str(v).strip()
        if s and s.upper() not in {"TBD", "-", "NONE", "NULL"}:
            return s
    return ""


def _direction_from(card: Card | None) -> str:
    if not card:
        return UNKNOWN
    blob = " ".join(
        [card.scalars.get(k, "") for k in ("direction", "strategy_type_flags")]
        + card.lists.get("strategy_type_flags", [])
    ).lower()
    has_long = "long" in blob
    has_short = "short" in blob
    if has_long and has_short:
        return "LONG_SHORT"
    if has_long:
        return "LONG"
    if has_short:
        return "SHORT"
    return UNKNOWN


def _timeframes(card: Card | None) -> str:
    if not card:
        return UNKNOWN
    tfs: list[str] = []
    for k in ("timeframe", "period", "execution_period"):
        v = card.scalars.get(k)
        if v:
            tfs.append(v)
    tfs += card.lists.get("timeframes", [])
    out = sorted({t.strip() for t in tfs if t.strip()})
    return ", ".join(out) if out else UNKNOWN


def _symbols(card: Card | None) -> str:
    if not card:
        return UNKNOWN
    syms: list[str] = list(card.lists.get("target_symbols", []))
    raw = card.scalars.get("target_symbols", "")
    if raw.startswith("[") and raw.endswith("]"):
        syms += [s.strip() for s in raw[1:-1].split(",") if s.strip()]
    out = sorted({s.strip() for s in syms if s.strip()})
    return ", ".join(out) if out else UNKNOWN


def _resolve_source_hash(record: Record, sources: Sources) -> tuple[str, str]:
    """(source_id, source_hash) — resolve QM-RESEARCH ids via research_source.

    Returns explicit tokens rather than guessing. source_hash is
    EVIDENCE_MISSING when a source_id is declared but cannot be resolved,
    NOT_APPLICABLE when no source is declared.
    """
    card = record.card
    source_id = _first(card.scalars.get("source_id")) if card else ""
    if not source_id:
        return (NOT_APPLICABLE, NOT_APPLICABLE)
    # Only internal QM-RESEARCH ids have a deterministic content hash.
    if source_id.upper().startswith("QM-RESEARCH"):
        try:  # pragma: no cover - optional dependency path
            try:
                from tools.strategy_farm import research_source as rs
            except ImportError:
                import research_source as rs  # type: ignore
            paths = rs.resolve_paths()
            directory = rs.resolve(source_id, paths)
            return (source_id, rs.source_hash(directory))
        except Exception:
            return (source_id, EVIDENCE_MISSING)
    # External source: the durable hash lives in the source node, not here.
    return (source_id, EVIDENCE_MISSING)


def _lineage_relationships(record: Record) -> tuple[str, str]:
    """(duplicate_relationships, parent_lineage) as compact strings."""
    dup_rels = [
        f"{r['relation']}:{r['other']}"
        for r in record.lineage_relations
        if r["relation"]
        in {"exact_clone", "close_implementation_clone", "parameter_variant",
            "same_edge_different_implementation", "materially_different"}
    ]
    parent = ""
    if record.lineage_node:
        cl = record.lineage_node.get("card_lineage") or {}
        parent = _first(cl.get("parent_id"), cl.get("variant_of"), cl.get("rerun_of"))
    child_rels = [
        f"{r['relation']}:{r['other']}"
        for r in record.lineage_relations
        if r["relation"] in {"child_challenger", "superseded"}
    ]
    dup_out = ", ".join(sorted(dup_rels)) if dup_rels else (
        NOT_APPLICABLE if record.lineage_node is not None else EVIDENCE_MISSING
    )
    parent_bits = []
    if parent:
        parent_bits.append(f"parent:{parent}")
    parent_bits += sorted(child_rels)
    parent_out = ", ".join(parent_bits) if parent_bits else (
        NOT_APPLICABLE if record.lineage_node is not None else EVIDENCE_MISSING
    )
    return dup_out, parent_out


def _handwritten_link(record: Record, handwritten: dict[str, Path]) -> str:
    if record.ea_key and record.ea_key in handwritten:
        stem = handwritten[record.ea_key].stem
        return f"[[strategies/{stem}]]"
    return NOT_APPLICABLE


def resolve_fields(
    record: Record,
    sources: Sources,
    handwritten: dict[str, Path],
) -> dict[str, Any]:
    card = record.card
    reg = record.registry or {}
    pe = record.pipeline or {}
    pclass = projection_class(record)

    source_id, source_hash = _resolve_source_hash(record, sources)
    dup_rel, parent_lineage = _lineage_relationships(record)

    # lifecycle status: registry status wins, else card status, else class.
    lifecycle = _first(reg.get("status"), (card.scalars.get("status") if card else ""),
                       (card.scalars.get("g0_status") if card else "")) or pclass

    name = _first(
        card.scalars.get("name") if card else "",
        record.slug.replace("-", " ").title() if record.slug else "",
    ) or UNKNOWN

    if card:
        repo_rel = _repo_relpath(card.path, sources)
        card_hash = card.card_hash
    else:
        repo_rel = EVIDENCE_MISSING
        card_hash = EVIDENCE_MISSING

    highest_gate = _first(pe.get("latest_pass_phase")) or (
        NOT_EVALUATED if not pe else UNKNOWN
    )
    pipe_status = _first(pe.get("status")) or (NOT_EVALUATED if not pe else UNKNOWN)
    final_verdict = _first(pe.get("final_verdict")) or (
        NOT_APPLICABLE if not pe else UNKNOWN
    )
    blockers = pe.get("phase_blockers") or []
    if blockers:
        current_blocker = "; ".join(
            f"{b.get('phase')}:{b.get('verdict')}" for b in blockers
            if isinstance(b, dict)
        ) or UNKNOWN
    else:
        current_blocker = NOT_APPLICABLE if pe else NOT_EVALUATED

    last_run = _first(pe.get("last_run_utc"))
    evidence_freshness = last_run or (EVIDENCE_MISSING if not pe else UNKNOWN)

    dxz_status = record.dxz or (NOT_APPLICABLE if _book_loaded(sources.book_dxz)
                                else EVIDENCE_MISSING)
    ftmo_status = record.ftmo or (NOT_APPLICABLE if _book_loaded(sources.book_ftmo)
                                  else EVIDENCE_MISSING)
    if record.dxz == "INCUMBENT" or record.ftmo == "INCUMBENT":
        live_demo = "LIVE_OR_DEMO_MEMBER"
    elif record.dxz or record.ftmo:
        live_demo = "CHALLENGER"
    else:
        live_demo = NOT_APPLICABLE

    family = _first(
        card.scalars.get("strategy_family") if card else "",
        (record.lineage_node or {}).get("family") if record.lineage_node else "",
        card.scalars.get("strategy_type_flags") if card else "",
    ) or (", ".join(card.lists.get("concepts", [])) if card and card.lists.get("concepts")
          else UNKNOWN)

    fields: dict[str, Any] = {
        "ea_id": record.ea_key or NOT_APPLICABLE,
        "slug": record.slug or UNKNOWN,
        "name": name,
        "projection_class": pclass,
        "lifecycle_status": lifecycle,
        "source_type": _first(card.scalars.get("source_type") if card else "") or (
            UNKNOWN if card else EVIDENCE_MISSING),
        "source_id": source_id,
        "source_hash": source_hash,
        "author": _first(
            card.scalars.get("source_authors") if card else "",
            card.scalars.get("author") if card else "",
            reg.get("owner"),
        ) or UNKNOWN,
        "strategy_family": family,
        "key_mechanism": _first(
            card.scalars.get("strategy_mechanic") if card else "",
            card.scalars.get("key_mechanism") if card else "",
        ) or UNKNOWN,
        "timeframes": _timeframes(card),
        "intended_symbols": _symbols(card),
        "direction": _direction_from(card),
        "parameter_family": _first(
            card.scalars.get("parameter_family") if card else "") or (
            UNKNOWN if card else EVIDENCE_MISSING),
        "canonical_repo_path": repo_rel,
        "card_hash": card_hash,
        "build_identity": _first(
            card.scalars.get("build_hash") if card else "") or NOT_EVALUATED,
        "highest_contiguous_gate": highest_gate,
        "pipeline_status": pipe_status,
        "terminal_verdict": final_verdict,
        "current_blocker": current_blocker,
        "duplicate_relationships": dup_rel,
        "parent_lineage": parent_lineage,
        "dxz_status": dxz_status,
        "ftmo_status": ftmo_status,
        "live_demo_status": live_demo,
        "evidence_freshness": evidence_freshness,
        "handwritten_node": _handwritten_link(record, handwritten),
    }
    # Per-node input digest (directive §7 idempotency): only THIS node's inputs.
    fields["inputs_sha256"] = _node_inputs_sha256(record, fields)
    fields["last_sync_inputs_sha256"] = fields["inputs_sha256"]
    return fields


def _book_loaded(path: Path) -> bool:
    return path.is_file()


def _repo_relpath(path: Path, sources: Sources) -> str:
    try:
        return path.resolve().relative_to(sources.repo_root.resolve()).as_posix()
    except ValueError:
        # D:\ runtime card — record its absolute-ish location, not repo-relative.
        return path.as_posix()


def _node_inputs_sha256(record: Record, fields: dict[str, Any]) -> str:
    payload = {
        "card_hash": fields["card_hash"],
        "registry": record.registry,
        "pipeline": record.pipeline,
        "dxz": record.dxz,
        "ftmo": record.ftmo,
        "lineage_node": record.lineage_node,
        "lineage_relations": sorted(
            (r["relation"], r["other"], r["direction"]) for r in record.lineage_relations
        ),
        "source_hash": fields["source_hash"],
    }
    blob = json.dumps(payload, sort_keys=True, ensure_ascii=False, default=str)
    return hashlib.sha256(blob.encode("utf-8")).hexdigest()


# ---------------------------------------------------------------------------
# Node rendering
# ---------------------------------------------------------------------------
_FRONTMATTER_ORDER = [
    "generated", "generator", "projection_class",
    "ea_id", "slug", "name", "lifecycle_status",
    "source_type", "source_id", "source_hash", "author",
    "strategy_family", "key_mechanism", "timeframes", "intended_symbols",
    "direction", "parameter_family",
    "canonical_repo_path", "card_hash", "build_identity",
    "highest_contiguous_gate", "pipeline_status", "terminal_verdict",
    "current_blocker", "duplicate_relationships", "parent_lineage",
    "dxz_status", "ftmo_status", "live_demo_status",
    "evidence_freshness", "handwritten_node",
    "inputs_sha256", "last_sync_inputs_sha256",
]


def _yaml_scalar(value: Any) -> str:
    s = "" if value is None else str(value)
    if s == "":
        return '""'
    if re.search(r'[:#\[\]{}",\'`]|\[\[', s) or s != s.strip():
        return '"' + s.replace("\\", "\\\\").replace('"', '\\"') + '"'
    return s


def render_node(fields: dict[str, Any]) -> str:
    lines = ["---"]
    fm = dict(fields)
    fm["generated"] = "true"
    fm["generator"] = GENERATOR
    for key in _FRONTMATTER_ORDER:
        if key in fm:
            lines.append(f"{key}: {_yaml_scalar(fm[key])}")
    lines.append("---")
    body = [
        "",
        f"# {fields['name']}",
        "",
        "> Generated node — do not edit. Managed by "
        "`tools/strategy_farm/strategy_wiki_sync.py`. The authoritative Strategy "
        "Card is at `" + str(fields["canonical_repo_path"]) + "`.",
        "",
        f"**Projection class:** `{fields['projection_class']}` · "
        f"**Lifecycle:** `{fields['lifecycle_status']}`",
        "",
        "## Mechanical summary",
        "",
        f"- **Family:** {fields['strategy_family']}",
        f"- **Key mechanism:** {fields['key_mechanism']}",
        f"- **Direction:** {fields['direction']}",
        f"- **Timeframe(s):** {fields['timeframes']}",
        f"- **Intended / tested symbols:** {fields['intended_symbols']}",
        f"- **Parameter family:** {fields['parameter_family']}",
        "",
        "## Provenance",
        "",
        f"- **Source type:** {fields['source_type']}",
        f"- **Source / research id:** {fields['source_id']}",
        f"- **Source hash:** {fields['source_hash']}",
        f"- **Author:** {fields['author']}",
        f"- **Canonical repo path:** `{fields['canonical_repo_path']}`",
        f"- **Card hash:** `{fields['card_hash']}`",
        "",
        "## Pipeline & books",
        "",
        f"- **Highest contiguous valid gate:** {fields['highest_contiguous_gate']}",
        f"- **Pipeline status:** {fields['pipeline_status']}",
        f"- **Terminal verdict:** {fields['terminal_verdict']}",
        f"- **Current blocker:** {fields['current_blocker']}",
        f"- **Evidence freshness (last run UTC):** {fields['evidence_freshness']}",
        f"- **DXZ status:** {fields['dxz_status']}",
        f"- **FTMO status:** {fields['ftmo_status']}",
        f"- **Live / demo status:** {fields['live_demo_status']}",
        "",
        "## Relationships",
        "",
        f"- **Duplicate / clone / variant:** {fields['duplicate_relationships']}",
        f"- **Parent / child lineage:** {fields['parent_lineage']}",
        f"- **Hand-written node:** {fields['handwritten_node']}",
        "",
    ]
    return "\n".join(lines) + "\n" + "\n".join(body)


def node_filename(record: Record) -> str:
    if record.ea_key and record.slug:
        return f"{record.ea_key}_{slugify(record.slug)}.md"
    if record.ea_key:
        return f"{record.ea_key}.md"
    return f"{slugify(record.slug)}.md"


# ---------------------------------------------------------------------------
# Build
# ---------------------------------------------------------------------------
def _hand_written_index(sources: Sources) -> dict[str, Path]:
    out: dict[str, Path] = {}
    d = sources.strategies_dir
    if not d.is_dir():
        return out
    for p in sorted(d.glob("*.md")):
        m = _EA_NUM_RE.match(p.stem)
        if m and p.stem.upper().startswith("QM5"):
            out[f"QM5_{int(m.group(1))}"] = p
    return out


def _write_if_changed(path: Path, content: str) -> bool:
    """Write only when bytes differ. Returns True if written."""
    data = content.encode("utf-8")
    if path.is_file():
        try:
            if path.read_bytes() == data:
                return False
        except OSError:
            pass
    path.parent.mkdir(parents=True, exist_ok=True)
    path.write_text(content, encoding="utf-8", newline="\n")
    return True


@dataclass
class BuildResult:
    records: dict[str, Record]
    fields_by_key: dict[str, dict[str, Any]]
    path_by_key: dict[str, Path]
    class_counts: dict[str, int]
    written: int
    skipped: int
    pruned: int = 0
    only: str | None = None


def _prune_stale_generated(sources: Sources, expected: set[Path]) -> int:
    """Delete generator-owned nodes no longer at an expected path.

    Only files carrying our ``generator`` frontmatter marker are removed (a node
    whose record changed projection class, so its old-class file lingers). This
    never touches hand-written pages — those live in ``strategies/``, not in the
    generated tree, and never carry the marker.
    """
    base = sources.generated_dir
    if not base.is_dir():
        return 0
    pruned = 0
    for pclass in PROJECTION_CLASSES:
        d = base / pclass
        if not d.is_dir():
            continue
        for p in list(d.glob("*.md")):
            if p.resolve() in expected:
                continue
            scalars, _ = parse_frontmatter(_read_text(p))
            if scalars.get("generator") == GENERATOR:
                try:
                    p.unlink()
                    pruned += 1
                except OSError:
                    pass
    return pruned


def build(
    sources: Sources,
    *,
    only: str | None = None,
    now: dt.datetime | None = None,
    write_sidecar: bool = True,
) -> BuildResult:
    now = now or dt.datetime.now(dt.UTC)
    cards = scan_cards(sources)
    registry = load_registry(sources)
    pipeline = load_pipeline(sources)
    dxz = _book_membership(sources.book_dxz)
    ftmo = _book_membership(sources.book_ftmo)
    lineage = load_lineage(sources)
    handwritten = _hand_written_index(sources)

    records = build_records(sources, cards, registry, pipeline, dxz, ftmo, lineage)
    only_key = normalize_ea_key(only) if only else None

    fields_by_key: dict[str, dict[str, Any]] = {}
    path_by_key: dict[str, Path] = {}
    class_counts: dict[str, int] = {c: 0 for c in PROJECTION_CLASSES}
    written = skipped = 0

    for key in sorted(records):
        record = records[key]
        if only_key and record.ea_key != only_key:
            continue
        fields = resolve_fields(record, sources, handwritten)
        pclass = fields["projection_class"]
        class_counts[pclass] = class_counts.get(pclass, 0) + 1
        target = sources.generated_dir / pclass / node_filename(record)
        fields_by_key[key] = fields
        path_by_key[key] = target
        if _write_if_changed(target, render_node(fields)):
            written += 1
        else:
            skipped += 1

    # Full builds prune generator-owned nodes whose record changed class (their
    # old-class file would otherwise read as a duplicate/orphan). Never on a
    # single-id build (it does not see the whole record set).
    pruned = 0
    if only_key is None:
        pruned = _prune_stale_generated(
            sources, {p.resolve() for p in path_by_key.values()}
        )

    if write_sidecar and only_key is None:
        sidecar = {
            "schema": SIDECAR_SCHEMA,
            "generator": GENERATOR,
            "generated_at_utc": now.replace(microsecond=0).isoformat(),
            "record_count": len(records),
            "projected_count": len(fields_by_key),
            "class_counts": class_counts,
            "written": written,
            "skipped": skipped,
            "pruned": pruned,
        }
        _write_if_changed_json(sources.sidecar_path, sidecar)

    return BuildResult(records, fields_by_key, path_by_key, class_counts,
                       written, skipped, pruned, only)


def _write_if_changed_json(path: Path, payload: dict[str, Any]) -> bool:
    return _write_if_changed(path, json.dumps(payload, indent=2, sort_keys=True) + "\n")


# ---------------------------------------------------------------------------
# Index
# ---------------------------------------------------------------------------
def _scan_generated_nodes(sources: Sources) -> list[dict[str, str]]:
    """Read generated nodes back → list of frontmatter dicts (for index/lint)."""
    out: list[dict[str, str]] = []
    base = sources.generated_dir
    if not base.is_dir():
        return out
    for pclass in PROJECTION_CLASSES:
        d = base / pclass
        if not d.is_dir():
            continue
        for p in sorted(d.glob("*.md")):
            scalars, lists = parse_frontmatter(_read_text(p))
            scalars["_path"] = str(p)
            scalars["_class"] = pclass
            out.append(scalars)
    return out


def render_index(sources: Sources) -> str:
    nodes = _scan_generated_nodes(sources)
    by_class: dict[str, list[dict[str, str]]] = {c: [] for c in PROJECTION_CLASSES}
    by_family: dict[str, list[str]] = {}
    for n in nodes:
        by_class.setdefault(n["_class"], []).append(n)
        fam = n.get("strategy_family") or UNKNOWN
        by_family.setdefault(fam, []).append(n.get("ea_id") or n.get("slug") or "?")

    lines = [
        "# Strategy Wiki — Generated Index",
        "",
        "> Fully generated by `tools/strategy_farm/strategy_wiki_sync.py index`. "
        "Do not edit. Hand-written nodes live in `../strategies/` and are never "
        "overwritten.",
        "",
        "## Counts by projection class",
        "",
        "| Class | Nodes |",
        "|---|---:|",
    ]
    for c in PROJECTION_CLASSES:
        lines.append(f"| {c} | {len(by_class.get(c, []))} |")
    lines.append(f"| **Total** | **{len(nodes)}** |")

    for c in PROJECTION_CLASSES:
        rows = sorted(by_class.get(c, []), key=lambda n: n.get("ea_id") or n.get("slug") or "")
        if not rows:
            continue
        lines += ["", f"## {c} ({len(rows)})", "",
                  "| EA ID | Slug | Family | Gate | Pipeline | DXZ | FTMO |",
                  "|---|---|---|---|---|---|---|"]
        for n in rows:
            rel = Path(n["_path"]).name
            link = f"[[generated/{c}/{Path(rel).stem}]]"
            lines.append(
                f"| {n.get('ea_id','?')} | {link} | {n.get('strategy_family','?')} | "
                f"{n.get('highest_contiguous_gate','?')} | {n.get('pipeline_status','?')} | "
                f"{n.get('dxz_status','?')} | {n.get('ftmo_status','?')} |"
            )

    lines += ["", "## By strategy family", "", "| Family | Count |", "|---|---:|"]
    for fam in sorted(by_family):
        lines.append(f"| {fam} | {len(by_family[fam])} |")
    lines.append("")
    return "\n".join(lines) + "\n"


def _update_root_index(sources: Sources, block: str, *, init: bool) -> str:
    """Refresh the delimited generated block inside the hand-written root _INDEX.

    Everything outside the markers (the hand-written preamble) is preserved
    verbatim. Returns a status string. Never overwrites a hand page wholesale.
    """
    root_index = sources.wiki_root / "_INDEX.md"
    marked = f"{ROOT_INDEX_BEGIN}\n{block}\n{ROOT_INDEX_END}\n"
    if not root_index.is_file():
        if init:
            _write_if_changed(root_index, marked)
            return "created"
        return "absent_no_init"
    text = _read_text(root_index)
    if ROOT_INDEX_BEGIN in text and ROOT_INDEX_END in text:
        pre = text.split(ROOT_INDEX_BEGIN, 1)[0]
        post = text.split(ROOT_INDEX_END, 1)[1]
        new = pre + marked + post.lstrip("\n")
        return "updated" if _write_if_changed(root_index, new) else "unchanged"
    if init:
        sep = "" if text.endswith("\n") else "\n"
        new = text + sep + "\n" + marked
        _write_if_changed(root_index, new)
        return "appended"
    return "no_marker_no_init"


def build_index(sources: Sources, *, init_root_index: bool = False) -> dict[str, Any]:
    block_lines = [
        "## Generated Strategy Projections",
        "",
        "See `generated/_INDEX.md` for the full generated index (per class + per "
        "family). Node counts:",
        "",
    ]
    nodes = _scan_generated_nodes(sources)
    counts: dict[str, int] = {c: 0 for c in PROJECTION_CLASSES}
    for n in nodes:
        counts[n["_class"]] = counts.get(n["_class"], 0) + 1
    for c in PROJECTION_CLASSES:
        block_lines.append(f"- **{c}:** {counts.get(c, 0)}")
    block_lines.append(f"- **Total generated nodes:** {len(nodes)}")
    block = "\n".join(block_lines)

    gen_index_path = sources.generated_dir / "_INDEX.md"
    gen_written = _write_if_changed(gen_index_path, render_index(sources))
    root_status = _update_root_index(sources, block, init=init_root_index)
    return {
        "generated_index": str(gen_index_path),
        "generated_index_written": gen_written,
        "node_count": len(nodes),
        "class_counts": counts,
        "root_index_status": root_status,
    }


# ---------------------------------------------------------------------------
# Lint
# ---------------------------------------------------------------------------
def lint(
    sources: Sources,
    *,
    now: dt.datetime | None = None,
    write_health: bool = True,
) -> dict[str, Any]:
    now = now or dt.datetime.now(dt.UTC)
    # Recompute the canonical record set from live inputs.
    cards = scan_cards(sources)
    registry = load_registry(sources)
    pipeline = load_pipeline(sources)
    dxz = _book_membership(sources.book_dxz)
    ftmo = _book_membership(sources.book_ftmo)
    lineage = load_lineage(sources)
    handwritten = _hand_written_index(sources)
    records = build_records(sources, cards, registry, pipeline, dxz, ftmo, lineage)

    expected_fields: dict[str, dict[str, Any]] = {}
    expected_path: dict[str, Path] = {}
    class_counts: dict[str, int] = {c: 0 for c in PROJECTION_CLASSES}
    for key in sorted(records):
        fields = resolve_fields(records[key], sources, handwritten)
        expected_fields[key] = fields
        expected_path[key] = (
            sources.generated_dir / fields["projection_class"] / node_filename(records[key])
        )
        class_counts[fields["projection_class"]] += 1

    # Index existing generated nodes by their absolute path + by ea_id.
    existing_nodes = _scan_generated_nodes(sources)
    existing_by_path = {Path(n["_path"]).resolve(): n for n in existing_nodes}
    # Duplicate = two generated nodes projecting the same record. Real EA ids
    # collide only when a record's node lingers in an old class folder; id-less
    # nodes are keyed by slug (their ea_id is the NOT_APPLICABLE sentinel, which
    # must NOT be treated as a shared id).
    seen_ids: dict[str, int] = {}
    for n in existing_nodes:
        eid = str(n.get("ea_id") or "")
        key = eid if eid.startswith("QM5_") else f"slug:{n.get('slug') or ''}"
        seen_ids[key] = seen_ids.get(key, 0) + 1

    missing: list[str] = []
    stale: list[str] = []
    invalid_link: list[str] = []
    unresolved_source: list[str] = []
    unresolved_lineage: list[str] = []

    hand_stems = {p.stem for p in sources.strategies_dir.glob("*.md")} \
        if sources.strategies_dir.is_dir() else set()

    for key, fields in expected_fields.items():
        pclass = fields["projection_class"]
        node = existing_by_path.get(expected_path[key].resolve())
        if node is None:
            # Only ACTIVE_CANONICAL missing counts as a completeness gap; other
            # classes are findable-when-present, not required.
            if pclass in CANONICAL_CLASSES:
                missing.append(key)
            continue
        if node.get("inputs_sha256") != fields["inputs_sha256"]:
            stale.append(key)
        # invalid_link: handwritten cross-link points at a non-existent node.
        hw = fields["handwritten_node"]
        if hw.startswith("[[strategies/") and hw.endswith("]]"):
            stem = hw[len("[[strategies/"):-2]
            if stem not in hand_stems:
                invalid_link.append(key)
        if fields["source_hash"] == EVIDENCE_MISSING and fields["source_id"] not in (
            NOT_APPLICABLE, EVIDENCE_MISSING, ""
        ) and fields["source_id"].upper().startswith("QM-RESEARCH"):
            unresolved_source.append(key)
        if fields["parent_lineage"] not in (NOT_APPLICABLE, EVIDENCE_MISSING):
            for token in fields["parent_lineage"].split(","):
                token = token.strip()
                if ":" in token:
                    ref = token.split(":", 1)[1].strip()
                    if normalize_ea_key(ref) and normalize_ea_key(ref) not in records:
                        unresolved_lineage.append(key)
                        break

    duplicate = sorted(k for k, c in seen_ids.items() if c > 1)
    orphan_ids = sorted(
        set(existing_by_path)
        - {expected_path[k].resolve() for k in expected_fields}
    )
    orphan = [p.name for p in orphan_ids]

    categories = {
        "missing": sorted(missing),
        "stale": sorted(stale),
        "duplicate": duplicate,
        "orphan": orphan,
        "invalid_link": sorted(invalid_link),
        "unresolved_source": sorted(unresolved_source),
        "unresolved_lineage": sorted(unresolved_lineage),
    }
    counts = {k: len(v) for k, v in categories.items()}

    red = counts["missing"] or counts["duplicate"] or counts["orphan"] \
        or counts["invalid_link"]
    amber = counts["stale"] or counts["unresolved_source"] or counts["unresolved_lineage"]
    state = "RED" if red else ("AMBER" if amber else "GREEN")

    canonical_records = sum(
        1 for f in expected_fields.values() if f["projection_class"] in CANONICAL_CLASSES
    )
    valid_projections = canonical_records - counts["missing"]

    health = {
        "schema": HEALTH_SCHEMA,
        "generated_at_utc": now.replace(microsecond=0).isoformat(),
        "STRATEGY_WIKI_SYNC": state,
        "record_count": len(records),
        "canonical_records": canonical_records,
        "valid_projections": valid_projections,
        "projected_nodes": len(existing_nodes),
        "class_counts": class_counts,
        "counts": counts,
        # Bounded sample lists (first 50) so the read-model stays small.
        "samples": {k: v[:50] for k, v in categories.items()},
    }
    if write_health:
        _write_if_changed_json(sources.health_out, health)
    return health


# ---------------------------------------------------------------------------
# Public single-node hook (best-effort post-approve)
# ---------------------------------------------------------------------------
def build_single(ea_id: str, *, sources: Sources | None = None) -> Path | None:
    """Best-effort projection of one EA's generated node (post-approve hook).

    Returns the node path, or None if the id resolves to no record. Never
    raises for the caller — used from farmctl.approve_card in a try/except.
    """
    sources = sources or default_sources()
    result = build(sources, only=ea_id, write_sidecar=False)
    key = normalize_ea_key(ea_id)
    return result.path_by_key.get(key) if key else None


# ---------------------------------------------------------------------------
# CLI
# ---------------------------------------------------------------------------
def _add_source_args(p: argparse.ArgumentParser) -> None:
    p.add_argument("--repo-root", type=Path, default=None)
    p.add_argument("--vault-root", type=Path, default=None,
                   help="override vault root (else QM_VAULT_ROOT or the default)")
    p.add_argument("--d-runtime", type=Path, default=None)
    p.add_argument("--pipeline-state", type=Path, default=None)
    p.add_argument("--book-dxz", type=Path, default=None)
    p.add_argument("--book-ftmo", type=Path, default=None)
    p.add_argument("--lineage-map", type=Path, default=None)
    p.add_argument("--health-out", type=Path, default=None)


def _sources_from_args(args: argparse.Namespace) -> Sources:
    return default_sources(
        repo_root=args.repo_root,
        vault_override=args.vault_root,
        d_runtime=args.d_runtime,
        pipeline_state=args.pipeline_state,
        book_dxz=args.book_dxz,
        book_ftmo=args.book_ftmo,
        lineage_map=args.lineage_map,
        health_out=args.health_out,
    )


def main(argv: list[str] | None = None) -> int:
    p = argparse.ArgumentParser(prog="strategy_wiki_sync")
    sub = p.add_subparsers(dest="cmd", required=True)

    b = sub.add_parser("build", help="render generated strategy nodes")
    _add_source_args(b)
    b.add_argument("--only", default=None, help="restrict to one EA id")

    idx = sub.add_parser("index", help="rebuild the generated index")
    _add_source_args(idx)
    idx.add_argument("--init-root-index", action="store_true",
                     help="seed/refresh the generated block in the root _INDEX.md")

    ln = sub.add_parser("lint", help="completeness + staleness check")
    _add_source_args(ln)

    st = sub.add_parser("status", help="print the last health read-model")
    _add_source_args(st)

    args = p.parse_args(argv)
    sources = _sources_from_args(args)

    if args.cmd == "build":
        r = build(sources, only=args.only)
        print(json.dumps({
            "records": len(r.records),
            "projected": len(r.fields_by_key),
            "written": r.written,
            "skipped": r.skipped,
            "pruned": r.pruned,
            "class_counts": r.class_counts,
            "only": r.only,
        }, indent=2))
        return 0

    if args.cmd == "index":
        r = build_index(sources, init_root_index=args.init_root_index)
        print(json.dumps(r, indent=2))
        return 0

    if args.cmd == "lint":
        h = lint(sources)
        print(json.dumps(h, indent=2))
        return 2 if h["STRATEGY_WIKI_SYNC"] == "RED" else 0

    if args.cmd == "status":
        if sources.health_out.is_file():
            print(sources.health_out.read_text(encoding="utf-8"))
            return 0
        print(json.dumps({"STRATEGY_WIKI_SYNC": EVIDENCE_MISSING,
                          "reason": "health read-model absent"}, indent=2))
        return 0

    return 1


if __name__ == "__main__":
    raise SystemExit(main())
