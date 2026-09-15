"""Freeze the section 7 recomposition inputs into a self-contained snapshot (section 70).

The weekend recomposition analysis must be reproducible from the frozen inputs alone
(directive section 70).  ``freeze`` collects, at the Friday-cut instant:

* the eligible qualified pool (from the live qualified source: ``book_build_guard`` /
  ``rebaseline_census``; NOT the empty ``candidate_qualifications`` table), with a durable
  ``candidate_universe.csv`` fallback,
* the incumbent roster(s) (DXZ: current live 24-sleeve book AND the planned v2 28-sleeve
  profile, two labelled incumbents; FTMO: the current 8-sleeve demo roster),
* the per-pair sealed Q14 best-settings trade/equity streams (copied byte-for-byte),
* live/demo evidence pointers,
* venue constraints (the concentration/tail policy) and the FTMO probability contract,

and writes a snapshot directory with a manifest that pins the sha256 of every input.  The
snapshot is the ONLY input to ``evaluate`` -- no live source is read again at evaluation
time, so two evaluations of the same snapshot are byte-identical.

Read-only against the farm DB (mode=ro).  Writes only under the caller's ``out`` dir.
"""
from __future__ import annotations

import datetime as dt
import hashlib
import json
import shutil
import subprocess
from pathlib import Path
from typing import Any, Iterable, Mapping, Sequence

Key = tuple[int, str]

SCHEMA = "qm.recompose-frozen-inputs/v1"

# frozen_snapshot.py lives at tools/strategy_farm/portfolio/recompose/; the repo root is
# four parents up (recompose -> portfolio -> strategy_farm -> tools -> repo).
REPO_ROOT = Path(__file__).resolve().parents[4]
DEFAULT_DB_PATH = Path(r"D:\QM\strategy_farm\state\farm_state.sqlite")
PORTFOLIO_REPORTS = Path(r"D:\QM\reports\portfolio")

# Sealed-stream search order (current v2 sealed bundle first, then the durable store,
# then the historical July bundle).  A stream is copied only when its file is found; a
# missing stream is recorded, never fabricated.
DEFAULT_STREAM_SOURCE_ROOTS: tuple[Path, ...] = (
    PORTFOLIO_REPORTS / "dxz_v2_20260913" / "streams_v2b",
    PORTFOLIO_REPORTS / "dxz_v2_20260913" / "streams",
    PORTFOLIO_REPORTS / "sleeve_streams",
    PORTFOLIO_REPORTS / "dxz_final_20260719",
)

DXZ_LIVE_24_MANIFEST = PORTFOLIO_REPORTS / "portfolio_manifest_live_24sleeve_20260724.json"
DXZ_V2_28_MANIFEST = (
    PORTFOLIO_REPORTS / "dxz_v2_20260913" / "build_28_r11" / "analytic_preview_manifest_28_r11.json"
)
CONCENTRATION_POLICY = REPO_ROOT / "tools" / "strategy_farm" / "config" / "concentration_tail_limits.v1.json"
FTMO_CONTRACT = REPO_ROOT / "tools" / "strategy_farm" / "config" / "ftmo_probability_contract.v1.json"
CANDIDATE_UNIVERSE_CSV = (
    REPO_ROOT
    / "docs" / "ops" / "evidence" / "2026-09-15_continuous_book_evolution"
    / "audit" / "candidate_universe.csv"
)

# FTMO demo roster (8 trading sleeves), audit ftmo_demo_state.md finding 1.2, 2026-09-15.
# Keys use the sealed .DWX stream symbol (USOIL.cash -> XTIUSD.DWX) for backtest evidence.
FTMO_DEMO_8_ROSTER: tuple[dict[str, Any], ...] = (
    {"ea_id": 10706, "symbol": "GBPUSD.DWX", "magic": 107060001, "risk_pct": 0.3125, "ftmo_symbol": "GBPUSD"},
    {"ea_id": 11421, "symbol": "EURUSD.DWX", "magic": 114210000, "risk_pct": 0.3125, "ftmo_symbol": "EURUSD"},
    {"ea_id": 11422, "symbol": "USDCAD.DWX", "magic": 114220004, "risk_pct": 0.3125, "ftmo_symbol": "USDCAD"},
    {"ea_id": 11910, "symbol": "NZDUSD.DWX", "magic": 119100006, "risk_pct": 0.3125, "ftmo_symbol": "NZDUSD"},
    {"ea_id": 13054, "symbol": "XTIUSD.DWX", "magic": 130540000, "risk_pct": 0.3125, "ftmo_symbol": "USOIL.cash"},
    {"ea_id": 20048, "symbol": "XTIUSD.DWX", "magic": 200480000, "risk_pct": 0.3125, "ftmo_symbol": "USOIL.cash"},
    {"ea_id": 1537, "symbol": "XAGUSD.DWX", "magic": 15370001, "risk_pct": 0.3125, "ftmo_symbol": "XAGUSD"},
    {"ea_id": 21505, "symbol": "XAGUSD.DWX", "magic": 215050000, "risk_pct": 0.3125, "ftmo_symbol": "XAGUSD"},
)


class SnapshotError(RuntimeError):
    """Fail-closed freeze error."""


def _sha256_file(path: Path) -> str:
    digest = hashlib.sha256()
    with path.open("rb") as fh:
        for chunk in iter(lambda: fh.read(1 << 20), b""):
            digest.update(chunk)
    return digest.hexdigest()


def _iso_week(day: dt.date) -> str:
    iso = day.isocalendar()
    return f"{iso.year:04d}-W{iso.week:02d}"


def _git_commit() -> str:
    try:
        out = subprocess.run(
            ["git", "rev-parse", "HEAD"],
            cwd=str(REPO_ROOT),
            capture_output=True,
            text=True,
            timeout=15,
            check=True,
        )
        return out.stdout.strip() or "UNKNOWN"
    except Exception:  # noqa: BLE001
        return "UNKNOWN"


def _stream_filename(key: Key) -> str:
    return f"{key[0]}_{key[1].replace('.', '_')}.jsonl"


def _find_stream(key: Key, roots: Sequence[Path]) -> Path | None:
    filename = _stream_filename(key)
    for root in roots:
        candidate = Path(root) / "QM" / "q08_trades" / filename
        if candidate.is_file():
            return candidate
    return None


def _file_pointer(path: Path) -> dict[str, Any]:
    p = Path(path)
    if not p.exists():
        return {"path": str(p), "status": "EVIDENCE_MISSING"}
    stat = p.stat()
    return {
        "path": str(p),
        "status": "PRESENT",
        "sha256": _sha256_file(p),
        "size_bytes": stat.st_size,
        "mtime_utc": dt.datetime.fromtimestamp(stat.st_mtime, tz=dt.UTC).isoformat(),
    }


def resolve_qualified_pool(
    *, db_path: Path = DEFAULT_DB_PATH, terminal_gate: str = "Q14"
) -> tuple[list[Key], dict[str, Any]]:
    """Resolve today's qualified (EA,symbol) pool from the live qualified source.

    Primary: ``book_build_guard._qualified_pair_rows`` (contiguous-through-terminal-gate
    census, read-only DB).  Fallback: the durable ``candidate_universe.csv`` audit
    artifact (status=QUALIFIED).  Never reads the empty ``candidate_qualifications`` table.
    """
    import sys

    farm_root = REPO_ROOT / "tools" / "strategy_farm"
    if str(farm_root) not in sys.path:
        sys.path.insert(0, str(farm_root))
    try:
        import book_build_guard  # type: ignore

        rows = book_build_guard._qualified_pair_rows(Path(db_path), terminal_gate)
        pairs = sorted({(int(str(r["ea_id"]).split("_")[-1]) if "_" in str(r["ea_id"]) else int(r["ea_id"]), str(r["symbol"])) for r in rows})
        if pairs:
            return pairs, {"source": "book_build_guard._qualified_pair_rows", "db_path": str(db_path), "terminal_gate": terminal_gate, "count": len(pairs)}
    except Exception as exc:  # noqa: BLE001 - degrade to the durable fallback
        fallback_reason = f"book_build_guard_unavailable: {type(exc).__name__}: {exc}"
    else:
        fallback_reason = "book_build_guard_returned_empty"

    if CANDIDATE_UNIVERSE_CSV.is_file():
        import csv as _csv

        pairs = []
        with CANDIDATE_UNIVERSE_CSV.open(newline="", encoding="utf-8-sig") as fh:
            for row in _csv.DictReader(fh):
                if str(row.get("status", "")).strip().upper() == "QUALIFIED":
                    ea = str(row["ea_id"]).split("_")[-1]
                    pairs.append((int(ea), str(row["symbol"])))
        pairs = sorted(set(pairs))
        return pairs, {"source": "candidate_universe.csv (fallback)", "reason": fallback_reason, "csv_path": str(CANDIDATE_UNIVERSE_CSV), "count": len(pairs)}

    raise SnapshotError(f"qualified pool unavailable and no fallback csv: {fallback_reason}")


def _dxz_incumbents() -> list[dict[str, Any]]:
    incumbents: list[dict[str, Any]] = []
    if DXZ_LIVE_24_MANIFEST.is_file():
        data = json.loads(DXZ_LIVE_24_MANIFEST.read_text(encoding="utf-8"))
        sleeves = [
            {
                "ea_id": int(s["ea_id"]),
                "symbol": str(s["symbol"]),
                "magic": s.get("magic_number"),
                "risk_pct": s.get("risk_percent"),
            }
            for s in data.get("sleeves", [])
        ]
        incumbents.append({
            "label": "live_24",
            "source_path": str(DXZ_LIVE_24_MANIFEST),
            "source_sha256": _sha256_file(DXZ_LIVE_24_MANIFEST),
            "status": "LIVE",
            "sleeves": sleeves,
        })
    if DXZ_V2_28_MANIFEST.is_file():
        data = json.loads(DXZ_V2_28_MANIFEST.read_text(encoding="utf-8"))
        sleeves = [
            {
                "ea_id": int(s["ea_id"]),
                "symbol": str(s["symbol"]),
                "magic": s.get("magic"),
                "risk_pct": s.get("weight_risk_percent"),
                "burn_in_risk_pct": s.get("burn_in_risk_percent"),
                "is_new_sleeve": s.get("is_new_sleeve"),
            }
            for s in data.get("sleeves", [])
        ]
        incumbents.append({
            "label": "planned_v2_28",
            "source_path": str(DXZ_V2_28_MANIFEST),
            "source_sha256": _sha256_file(DXZ_V2_28_MANIFEST),
            "status": "STAGED_NOT_DEPLOYED",
            "sleeves": sleeves,
        })
    return incumbents


def _ftmo_incumbents() -> list[dict[str, Any]]:
    sleeves = [
        {"ea_id": s["ea_id"], "symbol": s["symbol"], "magic": s["magic"], "risk_pct": s["risk_pct"], "ftmo_symbol": s["ftmo_symbol"]}
        for s in FTMO_DEMO_8_ROSTER
    ]
    return [{
        "label": "demo_8",
        "source_path": "audit/ftmo_demo_state.md finding 1.2 (2026-09-15)",
        "source_sha256": "NOT_APPLICABLE",
        "status": "DEMO_RUNNING",
        "sleeves": sleeves,
    }]


def _incumbent_keys(incumbents: Iterable[Mapping[str, Any]]) -> list[Key]:
    keys: set[Key] = set()
    for inc in incumbents:
        for s in inc.get("sleeves", []):
            keys.add((int(s["ea_id"]), str(s["symbol"])))
    return sorted(keys)


def _live_evidence(venue: str) -> dict[str, Any]:
    state = Path(r"D:\QM\reports\state")
    if venue == "dxz":
        dd = _file_pointer(state / "live_book_dd_guard_state.json")
        equity = dd_pct = live_since = None
        if dd.get("status") == "PRESENT":
            try:
                payload = json.loads((state / "live_book_dd_guard_state.json").read_text(encoding="utf-8"))
                equity = payload.get("last_equity")
                dd_pct = payload.get("last_dd_pct")
                live_since = payload.get("equity_observed_at_utc")
            except Exception:  # noqa: BLE001
                pass
        return {
            "status": dd.get("status", "EVIDENCE_MISSING"),
            "live_equity": equity if equity is not None else "EVIDENCE_MISSING",
            "live_dd_pct": dd_pct if dd_pct is not None else "EVIDENCE_MISSING",
            "live_since": live_since if live_since is not None else "EVIDENCE_MISSING",
            "sources": [dd, _file_pointer(state / "live_sleeve_drift.json")],
        }
    pulse = _file_pointer(state / "ftmo_trial_pulse.json")
    equity = None
    if pulse.get("status") == "PRESENT":
        try:
            payload = json.loads((state / "ftmo_trial_pulse.json").read_text(encoding="utf-8"))
            equity = payload.get("equity")
        except Exception:  # noqa: BLE001
            pass
    return {
        "status": pulse.get("status", "EVIDENCE_MISSING"),
        "demo_equity": equity if equity is not None else "EVIDENCE_MISSING",
        "sources": [pulse],
    }


def freeze(
    venue: str,
    out: Path | str,
    *,
    as_of: dt.datetime | None = None,
    seed: int = 0,
    db_path: Path = DEFAULT_DB_PATH,
    qualified_pairs: Sequence[Key] | None = None,
    incumbents: Sequence[Mapping[str, Any]] | None = None,
    stream_source_roots: Sequence[Path] | None = None,
    git_commit: str | None = None,
    extra_config_inputs: Mapping[str, Path] | None = None,
) -> dict[str, Any]:
    """Freeze inputs for ``venue`` into ``out`` and return the written manifest."""
    venue = str(venue).lower()
    if venue not in {"dxz", "ftmo"}:
        raise SnapshotError(f"venue must be dxz or ftmo, got {venue!r}")
    as_of = as_of or dt.datetime.now(tz=dt.UTC)
    out_dir = Path(out)
    stream_dir = out_dir / "streams" / "QM" / "q08_trades"
    inputs_dir = out_dir / "inputs"
    stream_dir.mkdir(parents=True, exist_ok=True)
    inputs_dir.mkdir(parents=True, exist_ok=True)

    roots = list(stream_source_roots) if stream_source_roots is not None else list(DEFAULT_STREAM_SOURCE_ROOTS)

    # Qualified pool
    if qualified_pairs is not None:
        pool = sorted((int(e), str(s)) for e, s in qualified_pairs)
        pool_meta = {"source": "explicit_argument", "count": len(pool)}
    else:
        pool, pool_meta = resolve_qualified_pool(db_path=db_path)

    # Incumbents
    if incumbents is not None:
        incumbent_list = [dict(i) for i in incumbents]
    elif venue == "dxz":
        incumbent_list = _dxz_incumbents()
    else:
        incumbent_list = _ftmo_incumbents()

    inc_keys = _incumbent_keys(incumbent_list)
    all_keys = sorted(set(pool) | set(inc_keys))
    if not all_keys:
        raise SnapshotError(
            "empty qualified pool AND empty incumbent roster: nothing to freeze "
            "(no valid book to recompose)"
        )

    # Copy sealed streams
    stream_records: list[dict[str, Any]] = []
    missing_streams: list[str] = []
    for key in all_keys:
        src = _find_stream(key, roots)
        label = f"{key[0]}:{key[1]}"
        if src is None:
            missing_streams.append(label)
            stream_records.append({"key": label, "status": "EVIDENCE_MISSING"})
            continue
        dest = stream_dir / _stream_filename(key)
        shutil.copyfile(src, dest)
        stream_records.append({
            "key": label,
            "status": "PRESENT",
            "source_path": str(src),
            "sha256": _sha256_file(dest),
            "size_bytes": dest.stat().st_size,
        })

    # Copy incumbent manifests into inputs/
    for inc in incumbent_list:
        src_path = Path(inc.get("source_path", ""))
        if src_path.is_file():
            dest = inputs_dir / src_path.name
            shutil.copyfile(src_path, dest)
            inc["frozen_input_path"] = str(dest.relative_to(out_dir)).replace("\\", "/")
            inc["frozen_input_sha256"] = _sha256_file(dest)

    # Venue constraints + contract config
    config_inputs: dict[str, Any] = {}
    to_pin = {"concentration_tail_policy": CONCENTRATION_POLICY}
    if venue == "ftmo":
        to_pin["ftmo_probability_contract"] = FTMO_CONTRACT
    for name, path in {**to_pin, **(extra_config_inputs or {})}.items():
        config_inputs[name] = _file_pointer(Path(path))

    # Live/demo evidence
    live = _live_evidence(venue)

    manifest = {
        "schema": SCHEMA,
        "venue": venue,
        "frozen_at_utc": as_of.isoformat(),
        "iso_week": _iso_week(as_of.date()),
        "seed": int(seed),
        "git_commit": git_commit or _git_commit(),
        "stream_source_roots": [str(r) for r in roots],
        "qualified_pool": {
            "count": len(pool),
            "definition": "contiguous Q02..terminal-gate PASS-class (book_build_guard predicate A)",
            "pairs": [f"{e}:{s}" for e, s in pool],
            "meta": pool_meta,
        },
        "incumbents": incumbent_list,
        "all_keys": [f"{e}:{s}" for e, s in all_keys],
        "streams": {
            "count_present": sum(1 for r in stream_records if r["status"] == "PRESENT"),
            "count_missing": len(missing_streams),
            "missing": missing_streams,
            "records": stream_records,
            "stream_root": "streams",
        },
        "config_inputs": config_inputs,
        "live_evidence": live,
    }
    manifest_path = out_dir / "manifest.json"
    manifest_path.write_text(json.dumps(manifest, indent=2, sort_keys=True) + "\n", encoding="utf-8")
    return manifest


def load_snapshot(snapshot_dir: Path | str) -> dict[str, Any]:
    """Load + verify a frozen snapshot manifest. Re-hashes every copied stream (section 70)."""
    snapshot_dir = Path(snapshot_dir)
    manifest_path = snapshot_dir / "manifest.json"
    if not manifest_path.is_file():
        raise SnapshotError(f"snapshot manifest missing: {manifest_path}")
    manifest = json.loads(manifest_path.read_text(encoding="utf-8"))
    if manifest.get("schema") != SCHEMA:
        raise SnapshotError(f"snapshot schema must be {SCHEMA}")
    stream_dir = snapshot_dir / "streams" / "QM" / "q08_trades"
    for record in manifest.get("streams", {}).get("records", []):
        if record.get("status") != "PRESENT":
            continue
        ea, sym = record["key"].split(":", 1)
        path = stream_dir / _stream_filename((int(ea), sym))
        if not path.is_file():
            raise SnapshotError(f"frozen stream missing on disk: {path}")
        actual = _sha256_file(path)
        if actual != record.get("sha256"):
            raise SnapshotError(
                f"frozen stream sha mismatch for {record['key']}: "
                f"manifest {record.get('sha256')}, disk {actual}"
            )
    return manifest
