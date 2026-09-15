"""External-source programme ROI vs internal / rebuild / failure-mining ROI.

Deterministic, read-only generator (schema ``qm.research-roi/v1``) for the OWNER
follow-up directive §20 and master §49. It measures the harvest funnel

    sources considered -> Strategy Cards -> EAs -> Q02 -> Q08 -> Q14
    -> portfolio admission -> economic contribution

broken down by **origin programme** — external harvest vs internal autonomous
research vs commercial/rebuild vs failure mining (plus the residual owner-mission
and unknown buckets) — so research capacity can be allocated on measured ROI, not
on the fact that a programme has historically existed.

The whitespace audit (research_universe_whitespace.md §6) found there is **no
per-EA origin field**, which blocks the §49 split. This module closes that gap by
deriving an origin for every registered EA and writing it to a NEW registry
sidecar ``framework/registry/ea_origin.v1.csv`` — it **never mutates**
``ea_id_registry.csv``. The derivation is a documented precedence over the
Strategy Card front-matter (source citation / source id / ``sources`` wikilink),
the registry slug prefix, and the registry ``owner`` label; every row records the
``basis`` that decided it, so the (acknowledged) weakness of a slug-default guess
is visible, never hidden.

Economic contribution: per-EA live/demo PnL attribution has **no evidence file**
today, so ``economic_contribution.pnl`` is honestly ``EVIDENCE_MISSING``; the
closest available economic-relevance signal — how many EAs of each origin sit in
the live DXZ book / FTMO demo book — is reported as ``book_admission``.

Read-only, stdlib only (``csv`` + ``sqlite3`` via the canonical clean view). No
DB write, no network, no gzip re-walk. Deterministic + idempotent with ``now``
fixed; ``inputs_sha256`` fingerprints real inputs.

CLI::

    python external_roi.py --db <farm_state.sqlite> --out <research_roi.json> \
        --doc <RESEARCH_PROGRAMME_ROI_2026-09.md> --origin-out <ea_origin.v1.csv>
"""

from __future__ import annotations

import argparse
import csv
import datetime as dt
import hashlib
import json
import re
import sqlite3
import sys
from collections import Counter, defaultdict
from pathlib import Path
from typing import Any, Iterable

_SF = Path(__file__).resolve().parents[1]
if str(_SF) not in sys.path:
    sys.path.insert(0, str(_SF))

import work_item_clean_view  # noqa: E402
from research import observe_projector as op  # noqa: E402

ROI_SCHEMA = "qm.research-roi/v1"
ORIGIN_SIDECAR_SCHEMA = "qm.ea-origin/v1"

_REPO_ROOT = _SF.parents[1]
DEFAULT_DB = Path(r"D:\QM\strategy_farm\state\farm_state.sqlite")
DEFAULT_REGISTRY = _REPO_ROOT / "framework" / "registry" / "ea_id_registry.csv"
DEFAULT_ORIGIN_OUT = _REPO_ROOT / "framework" / "registry" / "ea_origin.v1.csv"
DEFAULT_STATE_DIR = Path(r"D:\QM\reports\state")
DEFAULT_OUT = DEFAULT_STATE_DIR / "research_roi.json"
DEFAULT_DOC = _REPO_ROOT / "docs" / "research" / "RESEARCH_PROGRAMME_ROI_2026-09.md"
DEFAULT_BOOK_DXZ = DEFAULT_STATE_DIR / "book_evolution_dxz.json"
DEFAULT_BOOK_FTMO = DEFAULT_STATE_DIR / "book_evolution_ftmo.json"
DEFAULT_CARD_DIRS = (
    Path(r"D:\QM\strategy_farm\artifacts\cards_approved"),
    _REPO_ROOT / "artifacts" / "cards_approved",
    _REPO_ROOT / "strategy-seeds" / "cards",
)
DEFAULT_SEED_SOURCES_DIR = _REPO_ROOT / "strategy-seeds" / "sources"

ORIGIN_VALUES = (
    "external_source",
    "internal_discovery",
    "commercial_rebuild",
    "failure_mining",
    "owner_mission",
    "unknown",
)

# The four programmes the directive §20/§49 compares head-to-head.
ROI_PROGRAMMES = ("external_source", "internal_discovery", "commercial_rebuild", "failure_mining")

# --- origin markers (documented, deterministic; lower-cased substring match) ---
_INTERNAL_MARKERS = (
    "qm-research", "qm_research", "internal-discovery", "internal_discovery",
    "edgelab", "edge-lab", "edge_lab", "autonomous", "cross-asset-discovery",
    "cross_asset_discovery", "kimi", "fable-discovery", "fable_discovery",
)
_REBUILD_MARKERS = (
    "rebuild", "faithful", "commercial-ea", "commercial_ea", "reverse-eng",
    "reverse_eng", "reverse-engineer", "licensed-ea", "mql5 market", "mql5-market",
    "paid ea", "paid-ea", "decompil",
)
_FAILURE_MARKERS = (
    "failure-mine", "failure_mine", "failmine", "fail-mining", "observe-mine",
    "negative-knowledge", "negative_knowledge",
)
_EXTERNAL_URL_MARKERS = (
    "http://", "https://", "forexfactory", "mql5", "ssrn", "youtube", "youtu.be",
    "reddit", "tradingview", "github", "arxiv", "elitetrader", "elite-trader",
    ".pdf", "book", "paper", "blog", "thread", "channel", "seekingalpha",
    "alpha-architect", "quantpedia",
)
_INTERNAL_SLUG_PREFIXES = ("edgelab-", "edge-lab-", "edge_lab-", "claude_cross_asset", "autonomous-")
_REBUILD_SLUG_MARKERS = ("rebuild", "faithful", "commercial-", "reverse-eng")
_FAILURE_SLUG_MARKERS = ("failure-mine", "failmine", "fm-obs")


def _utc_now_iso() -> str:
    return dt.datetime.now(dt.timezone.utc).replace(microsecond=0).isoformat()


def _read_json(path: Path) -> Any:
    try:
        return json.loads(Path(path).read_text(encoding="utf-8"))
    except (OSError, ValueError):
        return None


def _has(text: str, markers: Iterable[str]) -> bool:
    return any(m in text for m in markers)


# --- Strategy Card front-matter parse (light, no yaml dep) --------------------

def _parse_card_origin_text(card_path: Path) -> str:
    """Return a lowercased concatenation of the card's origin-bearing fields.

    Reads only the YAML front-matter block (between the first two ``---`` lines)
    plus the ``## Source`` section lines, which is where ``source_id``,
    ``source_citation`` and the ``sources`` wikilinks live. Cheap, single read.
    """
    try:
        raw = card_path.read_text(encoding="utf-8", errors="replace")
    except OSError:
        return ""
    lines = raw.splitlines()
    collected: list[str] = []
    in_front = False
    front_done = False
    for i, line in enumerate(lines):
        stripped = line.strip()
        if i == 0 and stripped == "---":
            in_front = True
            continue
        if in_front and stripped == "---":
            in_front = False
            front_done = True
            continue
        if in_front:
            low = stripped.lower()
            if low.startswith(("source_id:", "source_citation:", "source_type:",
                                "sources:", "source:", "type:", "origin:", "author:")) \
                    or "[[sources/" in low or "qm-research" in low:
                collected.append(stripped)
        elif front_done:
            # Grab a few Source-section lines (citation/URLs often only here).
            low = stripped.lower()
            if low.startswith(("- source:", "- citation:", "- author", "source:", "citation:")) \
                    or "[[sources/" in low or "http" in low or "qm-research" in low:
                collected.append(stripped)
            if len(collected) > 40:  # bounded read; origin is decided by the top fields
                break
    return " ".join(collected).lower()


def derive_origin(
    slug: str,
    owner: str,
    card_text: str,
) -> tuple[str, str]:
    """Deterministic origin_programme + basis for one EA (documented precedence).

    Precedence (first hit wins):
      1. Card front-matter markers: internal -> rebuild -> failure -> external URL.
      2. Slug markers: internal -> rebuild -> failure.
      3. Registry owner label: OWNER mission -> owner_mission.
      4. Slug default: any non-empty slug -> external_source (harvested idea).
      5. unknown.
    """
    slug_l = str(slug or "").strip().lower()
    owner_l = str(owner or "").strip().lower()
    card = str(card_text or "")

    if card:
        if _has(card, _INTERNAL_MARKERS):
            return "internal_discovery", "card:internal_marker"
        if _has(card, _REBUILD_MARKERS):
            return "commercial_rebuild", "card:rebuild_marker"
        if _has(card, _FAILURE_MARKERS):
            return "failure_mining", "card:failure_marker"
        if _has(card, _EXTERNAL_URL_MARKERS):
            return "external_source", "card:external_source"

    if slug_l:
        if slug_l.startswith(_INTERNAL_SLUG_PREFIXES) or _has(slug_l, ("cross-asset-discovery", "cross_asset_discovery")):
            return "internal_discovery", "slug:internal_prefix"
        if _has(slug_l, _REBUILD_SLUG_MARKERS):
            return "commercial_rebuild", "slug:rebuild_marker"
        if _has(slug_l, _FAILURE_SLUG_MARKERS):
            return "failure_mining", "slug:failure_marker"

    if "owner" in owner_l and "mission" in owner_l:
        return "owner_mission", "owner:mission_label"

    if slug_l:
        return "external_source", "slug:default_external"

    return "unknown", "no_signal"


# --- card index ---------------------------------------------------------------

_CARD_EA_RE = re.compile(r"^(QM5_\d+)_", re.IGNORECASE)


def index_cards(card_dirs: Iterable[Path]) -> dict[str, Path]:
    """Map ea_key (``QM5_<num>``) -> a Strategy Card path (first store wins)."""
    index: dict[str, Path] = {}
    for base in card_dirs:
        base = Path(base)
        if not base.is_dir():
            continue
        try:
            entries = sorted(base.iterdir(), key=lambda p: p.name)
        except OSError:
            continue
        for entry in entries:
            if not entry.name.lower().endswith(".md"):
                continue
            m = _CARD_EA_RE.match(entry.name)
            if not m:
                continue
            ea_key = op._registry_ea_key(m.group(1))
            index.setdefault(ea_key, entry)  # first store (approved) wins
    return index


def build_origin_table(
    registry_path: Path,
    card_dirs: Iterable[Path] = DEFAULT_CARD_DIRS,
) -> list[dict[str, str]]:
    """Derive the per-EA origin sidecar rows (deterministic, registry-ordered)."""
    cards = index_cards(card_dirs)
    rows: list[dict[str, str]] = []
    seen: set[str] = set()  # one sidecar row per EA (the registry has duplicate ea_id rows)
    with Path(registry_path).open("r", encoding="utf-8", newline="") as handle:
        for reg in csv.DictReader(handle):
            ea_key = op._registry_ea_key(reg.get("ea_id"))
            if not ea_key or ea_key in seen:
                continue
            seen.add(ea_key)
            slug = str(reg.get("slug") or "").strip()
            owner = str(reg.get("owner") or "").strip()
            card_path = cards.get(ea_key)
            card_text = _parse_card_origin_text(card_path) if card_path else ""
            origin, basis = derive_origin(slug, owner, card_text)
            rows.append(
                {
                    "ea_id": ea_key,
                    "slug": slug,
                    "origin_programme": origin,
                    "basis": basis,
                    "has_card": "1" if card_path else "0",
                }
            )
    rows.sort(key=lambda r: r["ea_id"])
    return rows


def write_origin_sidecar(rows: list[dict[str, str]], out_path: Path) -> Path:
    out_path = Path(out_path)
    out_path.parent.mkdir(parents=True, exist_ok=True)
    header = ["ea_id", "slug", "origin_programme", "basis", "has_card"]
    with out_path.open("w", encoding="utf-8", newline="") as handle:
        writer = csv.DictWriter(handle, fieldnames=header, lineterminator="\n")
        writer.writeheader()
        for row in rows:
            writer.writerow(row)
    return out_path


# --- gate reach per EA (read-only) -------------------------------------------

_GATE_ORDER = (
    "Q00", "Q01", "Q02", "Q03", "Q04", "Q05", "Q06", "Q07", "Q08", "Q09",
    "Q09_NEWS", "Q09_PORTFOLIO", "Q10_NEWS", "Q10", "Q11", "Q12", "Q13", "Q14",
    "Q15", "Q16", "Q17",
)
_GATE_ORDINAL = {name: i for i, name in enumerate(_GATE_ORDER)}


def _ea_max_reached(db_path: Path) -> dict[str, int]:
    """Per EA: the max gate ordinal reached on any symbol (read-only clean view)."""
    connection = work_item_clean_view.open_clean_view_connection(Path(db_path))
    try:
        connection.row_factory = sqlite3.Row
        reached: dict[str, int] = {}
        for row in connection.execute(
            "SELECT ea_id, phase FROM work_items_clean"
        ):
            ea = str(row["ea_id"] or "").strip()
            if not ea:
                continue
            ordv = _GATE_ORDINAL.get(str(row["phase"] or "").strip(), -1)
            if ordv > reached.get(ea, -2):
                reached[ea] = ordv
        return reached
    finally:
        connection.close()


def load_incumbent_ea_keys(book_path: Path) -> set[str]:
    data = _read_json(book_path)
    out: set[str] = set()
    if isinstance(data, dict):
        for sleeve in (data.get("incumbent") or {}).get("sleeves") or []:
            if isinstance(sleeve, dict):
                ea = op._registry_ea_key(sleeve.get("ea_id"))
                if ea:
                    out.add(ea)
    return out


def _count_sources(seed_sources_dir: Path) -> dict[str, int]:
    """External-harvest source counts: tracked seed-source folders, split internal/external."""
    base = Path(seed_sources_dir)
    external = 0
    internal = 0
    if base.is_dir():
        try:
            for entry in base.iterdir():
                if not entry.is_dir():
                    continue
                if entry.name.upper().startswith("QM-RESEARCH"):
                    internal += 1
                else:
                    external += 1
        except OSError:
            pass
    return {"external_seed_dirs": external, "internal_research_artifacts": internal}


def _sha256_bytes(*chunks: bytes) -> str:
    digest = hashlib.sha256()
    for chunk in chunks:
        digest.update(chunk)
    return digest.hexdigest()


def _file_fingerprint(path: Path) -> str:
    try:
        return hashlib.sha256(Path(path).read_bytes()).hexdigest()
    except OSError:
        return "ABSENT"


def build_roi(
    db_path: Path | str = DEFAULT_DB,
    *,
    registry_path: Path | str = DEFAULT_REGISTRY,
    card_dirs: Iterable[Path] = DEFAULT_CARD_DIRS,
    seed_sources_dir: Path | str = DEFAULT_SEED_SOURCES_DIR,
    book_dxz_path: Path | str = DEFAULT_BOOK_DXZ,
    book_ftmo_path: Path | str = DEFAULT_BOOK_FTMO,
    origin_rows: list[dict[str, str]] | None = None,
    now: dt.datetime | None = None,
) -> dict[str, Any]:
    """Assemble the ``qm.research-roi/v1`` read-model dict deterministically."""

    db_path = Path(db_path)
    if origin_rows is None:
        origin_rows = build_origin_table(Path(registry_path), card_dirs)
    origin_by_ea = {r["ea_id"]: r["origin_programme"] for r in origin_rows}
    has_card_by_ea = {r["ea_id"]: r["has_card"] == "1" for r in origin_rows}

    reached = _ea_max_reached(db_path)
    dxz_inc = load_incumbent_ea_keys(Path(book_dxz_path))
    ftmo_inc = load_incumbent_ea_keys(Path(book_ftmo_path))

    # Per-origin funnel counts (distinct EAs).
    def _new_funnel() -> dict[str, int]:
        return {
            "registry_eas": 0,
            "with_card": 0,
            "reached_q02": 0,
            "reached_q08": 0,
            "reached_q14": 0,
            "in_dxz_book": 0,
            "in_ftmo_book": 0,
        }

    funnel: dict[str, dict[str, int]] = {o: _new_funnel() for o in ORIGIN_VALUES}

    q02 = _GATE_ORDINAL["Q02"]
    q08 = _GATE_ORDINAL["Q08"]
    q14 = _GATE_ORDINAL["Q14"]
    for ea, origin in origin_by_ea.items():
        f = funnel[origin]
        f["registry_eas"] += 1
        if has_card_by_ea.get(ea):
            f["with_card"] += 1
        r = reached.get(ea, -2)
        if r >= q02:
            f["reached_q02"] += 1
        if r >= q08:
            f["reached_q08"] += 1
        if r >= q14:
            f["reached_q14"] += 1
        if ea in dxz_inc:
            f["in_dxz_book"] += 1
        if ea in ftmo_inc:
            f["in_ftmo_book"] += 1

    # EAs that reached a gate but have NO origin row (in DB, not in registry) —
    # surface honestly rather than silently dropping.
    in_db_not_registry = sum(1 for ea in reached if ea not in origin_by_ea)

    sources = _count_sources(Path(seed_sources_dir))

    # Programme ROI rows (the four the directive compares + residuals).
    programmes: list[dict[str, Any]] = []
    for origin in ORIGIN_VALUES:
        f = funnel[origin]
        admitted = f["in_dxz_book"] + f["in_ftmo_book"]
        eas = f["registry_eas"]
        programmes.append(
            {
                "origin_programme": origin,
                "is_directive_roi_programme": origin in ROI_PROGRAMMES,
                "funnel": f,
                "book_admission": {
                    "dxz": f["in_dxz_book"],
                    "ftmo": f["in_ftmo_book"],
                    "total": admitted,
                },
                # Yield = book-admitted EAs / EAs that reached Q02 (economic funnel end).
                "yield_admit_per_q02_pct": (
                    round(100.0 * admitted / f["reached_q02"], 3) if f["reached_q02"] else None
                ),
                "economic_contribution": {
                    "pnl": "EVIDENCE_MISSING",
                    "note": (
                        "No per-EA live/demo PnL attribution file exists yet; "
                        "book_admission is the closest available economic-relevance signal."
                    ),
                },
            }
        )

    inputs_sha = _sha256_bytes(
        str(db_path.stat().st_size if db_path.exists() else 0).encode(),
        _file_fingerprint(Path(registry_path)).encode(),
        _file_fingerprint(Path(book_dxz_path)).encode(),
        _file_fingerprint(Path(book_ftmo_path)).encode(),
        json.dumps(sources, sort_keys=True).encode(),
    )

    return {
        "schema": ROI_SCHEMA,
        "generated_at_utc": (now.isoformat() if now else _utc_now_iso()),
        "inputs_sha256": inputs_sha,
        "definitions": {
            "unit": "distinct EA (ea_id), across all its symbols",
            "reached_qNN": "the EA has a work_item row at gate NN or deeper on any symbol (reached, not a pass claim)",
            "book_admission": "EA present in the live DXZ incumbent book / FTMO demo incumbent book",
            "origin_programme": "derived per-EA in framework/registry/ea_origin.v1.csv (read-only sidecar); see basis column",
            "economic_contribution_pnl": "EVIDENCE_MISSING — no per-EA PnL attribution artifact exists yet",
        },
        "origin_derivation": {
            "sidecar": str(DEFAULT_ORIGIN_OUT),
            "precedence": "card markers (internal>rebuild>failure>external-url) > slug markers > owner mission > slug-default external > unknown",
            "origin_values": list(ORIGIN_VALUES),
            "basis_distribution": dict(
                sorted(Counter(r["basis"] for r in origin_rows).items(), key=lambda kv: (-kv[1], kv[0]))
            ),
            "origin_distribution": dict(
                sorted(Counter(r["origin_programme"] for r in origin_rows).items(), key=lambda kv: (-kv[1], kv[0]))
            ),
        },
        "sources_considered": {
            **sources,
            "note": (
                "The tracked seed-source folders + internal QM-RESEARCH artifacts. "
                "The directive's 'tens of thousands of sources' is not present in "
                "current metadata (see research_universe_whitespace.md §6); this is "
                "the measurable source universe."
            ),
        },
        "totals": {
            "registry_eas": sum(f["registry_eas"] for f in funnel.values()),
            "eas_in_db_not_in_registry": in_db_not_registry,
            "dxz_book_eas": len(dxz_inc),
            "ftmo_book_eas": len(ftmo_inc),
        },
        "programmes": programmes,
    }


def summary_for_research_state(model: dict[str, Any]) -> dict[str, Any]:
    """Compact ROI slice for the research_state read-model."""
    prog = {
        p["origin_programme"]: {
            "registry_eas": p["funnel"]["registry_eas"],
            "reached_q02": p["funnel"]["reached_q02"],
            "reached_q08": p["funnel"]["reached_q08"],
            "reached_q14": p["funnel"]["reached_q14"],
            "book_admission_total": p["book_admission"]["total"],
            "yield_admit_per_q02_pct": p["yield_admit_per_q02_pct"],
        }
        for p in model["programmes"]
        if p["is_directive_roi_programme"] or p["funnel"]["registry_eas"] > 0
    }
    return {
        "schema": model["schema"],
        "generated_at_utc": model["generated_at_utc"],
        "inputs_sha256": model["inputs_sha256"],
        "origin_distribution": model["origin_derivation"]["origin_distribution"],
        "sources_considered": model["sources_considered"],
        "economic_contribution_pnl": "EVIDENCE_MISSING",
        "programmes": prog,
    }


def render_doc(model: dict[str, Any]) -> str:
    lines: list[str] = []
    lines.append("# External Source Programme ROI — 2026-09")
    lines.append("")
    lines.append(
        "Generated by `tools/strategy_farm/research/external_roi.py` "
        f"(schema `{model['schema']}`). Read-only measure of the research harvest "
        "funnel by **origin programme**, to allocate research capacity on ROI "
        "(directive §20 / §49). Unit: distinct EA. `reached_qNN` is a *reached* "
        "descriptor, not a pass claim."
    )
    lines.append("")
    lines.append(f"- `inputs_sha256`: `{model['inputs_sha256']}`")
    lines.append(f"- Registry EAs: **{model['totals']['registry_eas']}** "
                 f"(+{model['totals']['eas_in_db_not_in_registry']} in DB but not in registry)")
    lines.append(f"- DXZ book EAs: **{model['totals']['dxz_book_eas']}** · "
                 f"FTMO book EAs: **{model['totals']['ftmo_book_eas']}**")
    lines.append("")
    lines.append("## Origin derivation (new sidecar `framework/registry/ea_origin.v1.csv`)")
    lines.append("")
    lines.append(f"Precedence: {model['origin_derivation']['precedence']}.")
    lines.append("")
    lines.append(f"- Origin distribution: {json.dumps(model['origin_derivation']['origin_distribution'], sort_keys=True)}")
    lines.append(f"- Basis distribution: {json.dumps(model['origin_derivation']['basis_distribution'], sort_keys=True)}")
    lines.append("")
    lines.append("## Sources considered")
    lines.append("")
    lines.append(f"- {json.dumps(model['sources_considered'], sort_keys=True)}")
    lines.append("")
    lines.append("## Funnel by origin programme")
    lines.append("")
    lines.append("| origin | EAs | with_card | Q02 | Q08 | Q14 | DXZ book | FTMO book | admit/Q02 % |")
    lines.append("|---|---:|---:|---:|---:|---:|---:|---:|---:|")
    for p in model["programmes"]:
        f = p["funnel"]
        y = p["yield_admit_per_q02_pct"]
        lines.append(
            f"| {p['origin_programme']} | {f['registry_eas']} | {f['with_card']} | "
            f"{f['reached_q02']} | {f['reached_q08']} | {f['reached_q14']} | "
            f"{f['in_dxz_book']} | {f['in_ftmo_book']} | {y if y is not None else 'n/a'} |"
        )
    lines.append("")
    lines.append("## Economic contribution")
    lines.append("")
    lines.append("Per-EA live/demo PnL attribution is **EVIDENCE_MISSING** — no attribution "
                 "artifact exists yet. `book_admission` (EAs in the live DXZ / FTMO demo book) "
                 "is reported as the closest available economic-relevance signal. Building a "
                 "per-EA PnL attribution feed is the next step to make §49 a true money-ROI.")
    lines.append("")
    lines.append("## Allocation reading")
    lines.append("")
    lines.append("- The four directive ROI programmes are external_source, internal_discovery, "
                 "commercial_rebuild, failure_mining; owner_mission and unknown are residual "
                 "origin buckets.")
    lines.append("- Compare `admit/Q02 %` and absolute `DXZ/FTMO book` columns across programmes "
                 "to see which origin actually reaches books, not merely which produced the most cards.")
    lines.append("- This read-model is regenerated by the 15-min read-model task; do not hand-edit.")
    lines.append("")
    return "\n".join(lines)


def write_outputs(
    model: dict[str, Any],
    origin_rows: list[dict[str, str]],
    out_json: Path | str = DEFAULT_OUT,
    out_doc: Path | str = DEFAULT_DOC,
    origin_out: Path | str = DEFAULT_ORIGIN_OUT,
) -> dict[str, Any]:
    origin_path = write_origin_sidecar(origin_rows, Path(origin_out))
    out_json = Path(out_json)
    out_doc = Path(out_doc)
    out_json.parent.mkdir(parents=True, exist_ok=True)
    out_json.write_text(
        json.dumps(model, indent=2, sort_keys=True) + "\n", encoding="utf-8", newline="\n"
    )
    out_doc.parent.mkdir(parents=True, exist_ok=True)
    out_doc.write_text(render_doc(model) + "\n", encoding="utf-8", newline="\n")
    return {"json": str(out_json), "doc": str(out_doc), "origin_sidecar": str(origin_path)}


def main(argv: list[str] | None = None) -> int:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--db", type=Path, default=DEFAULT_DB)
    parser.add_argument("--registry", type=Path, default=DEFAULT_REGISTRY)
    parser.add_argument("--seed-sources-dir", type=Path, default=DEFAULT_SEED_SOURCES_DIR)
    parser.add_argument("--book-dxz", type=Path, default=DEFAULT_BOOK_DXZ)
    parser.add_argument("--book-ftmo", type=Path, default=DEFAULT_BOOK_FTMO)
    parser.add_argument("--out", type=Path, default=DEFAULT_OUT)
    parser.add_argument("--doc", type=Path, default=DEFAULT_DOC)
    parser.add_argument("--origin-out", type=Path, default=DEFAULT_ORIGIN_OUT)
    args = parser.parse_args(argv)

    origin_rows = build_origin_table(args.registry, DEFAULT_CARD_DIRS)
    model = build_roi(
        args.db,
        registry_path=args.registry,
        seed_sources_dir=args.seed_sources_dir,
        book_dxz_path=args.book_dxz,
        book_ftmo_path=args.book_ftmo,
        origin_rows=origin_rows,
    )
    written = write_outputs(model, origin_rows, args.out, args.doc, args.origin_out)
    print(json.dumps({
        "out_json": written["json"],
        "out_doc": written["doc"],
        "origin_sidecar": written["origin_sidecar"],
        "origin_distribution": model["origin_derivation"]["origin_distribution"],
        "registry_eas": model["totals"]["registry_eas"],
    }, indent=2, sort_keys=True))
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
