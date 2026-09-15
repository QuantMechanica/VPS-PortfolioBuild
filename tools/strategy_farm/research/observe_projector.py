"""OBSERVE projector — the pre-Q00 evidence inventory (slice C5).

Reads ``farm_state.sqlite`` READ-ONLY (URI ``mode=ro`` + ``PRAGMA query_only``)
through the canonical ``work_items_clean`` TEMP view (installed exactly the way
the existing tools do, via :mod:`work_item_clean_view`), joined to ``ea_metrics``,
``work_item_holds`` and ``sources``, and idea->EA via
``framework/registry/ea_id_registry.csv``.

It emits a **versioned dataset directory** ``<out_root>/<stamp>/`` of CSV files
plus a content-addressed ``manifest.json`` (schema ``qm.research-dataset/v1``).
The projector has **no pandas dependency** — stdlib ``csv`` + ``sqlite3`` only —
so it runs on the farm Python311 (numpy-only) as well as under the research venv.

Hard invariants (design doc sec 0, sec 1.2, sec 1.3):

* Never mutates the DB; never re-walks the gzip evidence trees.
* Every OBSERVE row carries ``verdict_taxonomy`` so INFRA vs strategy vs
  measurement vs invalid are kept provably apart; the manifest's
  ``verdict_taxonomy_split`` enumerates *every* taxonomy -> disposition so the
  separation is auditable, not implicit. A dataset with a missing sha256 is not
  consumable (fail closed).

CLI::

    python observe_projector.py --db <farm_state.sqlite> --out-root <dir> [--limit N]
"""

from __future__ import annotations

import argparse
import csv
import datetime as dt
import hashlib
import json
import re
import sqlite3
import subprocess
import sys
from collections import Counter
from pathlib import Path
from typing import Any, Iterable

# Self-bootstrap the sibling module path so this works whether imported as
# ``research.observe_projector`` (package) or run as a bare script.
_SF = Path(__file__).resolve().parents[1]
if str(_SF) not in sys.path:
    sys.path.insert(0, str(_SF))

import work_item_clean_view  # noqa: E402


DATASET_SCHEMA = "qm.research-dataset/v1"

DEFAULT_DB = Path(r"D:\QM\strategy_farm\state\farm_state.sqlite")
# Small few-MB artifacts default to the C: repo/reports side, never a large D:
# intermediate (design doc sec 2.3 F5 reconciliation option (b)). The caller
# always injects the out root in tests; production supplies it explicitly.
DEFAULT_OUT_ROOT = Path(r"C:\QM\repo\artifacts\research_datasets")
DEFAULT_REGISTRY = _SF.parents[1] / "framework" / "registry" / "ea_id_registry.csv"

# Coarse idea-family taxonomy aligned to farmctl.strategy_card_fingerprint's
# dedupe vocabulary (design doc sec 2.5), extended with structural classes. This
# is a local, read-only classifier over the registry slug so we never import or
# touch farmctl.py. Order matters: first hit wins.
_FAMILY_KEYWORDS: tuple[tuple[str, tuple[str, ...]], ...] = (
    ("news", ("news", "nfp", "cpi")),
    ("fomc", ("fomc", "fed", "rate-decision")),
    ("carry", ("carry", "swap", "rollover")),
    ("seasonal", ("season", "turn-of", "day-of-week", "month", "calendar")),
    ("gap", ("gap", "opening-range", "orb", "open-box")),
    ("breakout", ("break", "breakout", "donchian", "channel", "turtle", "range")),
    ("mean_reversion", ("mr", "mean-rev", "reversion", "bounce", "fade", "stretch", "bollinger", "rsi")),
    ("momentum", ("momo", "momentum", "roc", "thrust")),
    ("volatility", ("vol", "atr", "squeeze", "keltner", "stddev")),
    ("pairs", ("pair", "cointegration", "spread", "basket", "dual")),
    ("trend", ("trend", "ema", "sma", "ma-cross", "macd", "supertrend", "st-adx", "adx")),
    ("pattern", ("pinbar", "engulf", "candle", "pattern", "wyckoff", "smc", "fvg")),
)


def _stamp_utc(now: dt.datetime | None = None) -> str:
    moment = (now or dt.datetime.now(dt.UTC)).astimezone(dt.UTC).replace(microsecond=0)
    return moment.strftime("%Y-%m-%dT%H-%M-%SZ")


def classify_family(slug: Any) -> str:
    """Map a registry slug to a coarse hypothesis family (read-only heuristic)."""

    text = str(slug or "").lower()
    if not text:
        return "unclassified"
    for family, needles in _FAMILY_KEYWORDS:
        if any(needle in text for needle in needles):
            return family
    return "other"


# --- White-space classifiers (directive §45/§46; audit research_universe_whitespace.md)
# The whitespace audit found the projector was missing timeframe, session,
# holding-duration and symbol-class fields — the exact axes §46 white-space
# research and the §47 FTMO gap value most. These are deterministic, read-only
# heuristics over the already-projected columns (setfile_path + registry slug +
# symbol); they invent nothing (an underivable value is the empty string).

# Timeframe token, matched on an underscore/dot-delimited setfile path segment.
# Order the alternation longest-first so ``M15`` wins over ``M1`` at the same spot.
_TIMEFRAME_RE = re.compile(
    r"(?<![A-Za-z0-9])(MN1|W1|D1|H4|H1|M30|M15|M5|M1)(?![A-Za-z0-9])"
)

# Holding-duration class per timeframe (matches the audit's holding buckets:
# scalp M1-M5, intraday M15-H1, swing H4, position D1+).
_HOLDING_BY_TF = {
    "M1": "scalp",
    "M5": "scalp",
    "M15": "intraday",
    "M30": "intraday",
    "H1": "intraday",
    "H4": "swing",
    "D1": "position",
    "W1": "position",
    "MN1": "position",
}

# Symbol-class token sets (base name, ``.DWX`` / suffix stripped, upper-cased).
_FX_MAJORS = frozenset(
    {"EURUSD", "GBPUSD", "USDJPY", "USDCHF", "USDCAD", "AUDUSD", "NZDUSD"}
)
_METALS = frozenset({"XAUUSD", "XAGUSD", "XPTUSD", "XPDUSD"})
_INDICES = frozenset(
    {
        "SP500", "US500", "NDX", "US100", "NAS100", "GDAXI", "GER40", "GER30",
        "WS30", "US30", "DJ30", "UK100", "FTSE100", "NIKKEI", "JP225", "JPN225",
        "STOXX50", "EU50", "AUS200", "HK50", "ES35", "SPA35", "FRA40", "NETH25",
    }
)
_ENERGY = frozenset(
    {"XTIUSD", "XBRUSD", "USOIL", "UKOIL", "XNGUSD", "NATGAS", "WTI", "BRENT"}
)
_CRYPTO_TOKENS = ("BTC", "ETH", "LTC", "XRP", "DOGE", "SOL", "ADA")

# Session / time-of-day keyword families (matched on the registry slug). Order
# matters: the opening-range/ORB family is checked before the city sessions so a
# generic ``session-open`` is not mislabelled, then city sessions, then overnight.
_SESSION_KEYWORDS: tuple[tuple[str, tuple[str, ...]], ...] = (
    ("open", ("opening-range", "opening_range", "orb", "open-box", "openbox",
              "session-open", "session_open", "session-break", "session_break",
              "openrange")),
    ("london", ("london", "-lo-", "eu-session", "europe-session")),
    ("ny", ("newyork", "new-york", "ny-session", "us-session", "ny-open")),
    ("asian", ("asian", "asia", "tokyo", "sydney")),
    ("overnight", ("overnight", "seasonal", "turn-of", "day-of-week", "carry",
                   "rollover", "holdover")),
)


def classify_timeframe(setfile_path: Any) -> str:
    """Extract the MT5 timeframe token from a setfile path, or '' if absent."""

    match = _TIMEFRAME_RE.search(str(setfile_path or ""))
    return match.group(1) if match else ""


def classify_holding(timeframe: Any) -> str:
    """Map a timeframe token to a holding-duration class ('' when unknown)."""

    return _HOLDING_BY_TF.get(str(timeframe or "").upper(), "")


def classify_symbol_class(symbol: Any) -> str:
    """Coarse asset class from a (possibly ``.DWX``-suffixed) symbol name."""

    base = str(symbol or "").upper().split(".")[0].strip()
    if not base:
        return ""
    if base in _METALS or base.startswith(("XAU", "XAG", "XPT", "XPD")):
        return "metal"
    if base in _ENERGY or "OIL" in base or base.startswith(("XNG", "XTI", "XBR")):
        return "energy"
    if base in _INDICES:
        return "index"
    if any(tok in base for tok in _CRYPTO_TOKENS):
        return "crypto"
    if base in _FX_MAJORS:
        return "fx_major"
    if len(base) == 6 and base.isalpha():
        return "fx_cross"
    return "other"


def classify_session(slug: Any) -> str:
    """Infer a session / time-of-day intent from the slug ('unspecified' default)."""

    text = str(slug or "").lower()
    if not text:
        return "unspecified"
    for label, needles in _SESSION_KEYWORDS:
        if any(needle in text for needle in needles):
            return label
    return "unspecified"


def extract_parameter_sensitivity(detail_json_text: Any) -> dict[str, Any] | None:
    """Derive a parameter-sensitivity summary from an OPT_CENSUS ``detail_json``.

    An optimisation census records one entry per parameter-configuration run
    under ``runs`` (each carrying ``profit_factor`` / ``net_profit``). The spread
    of the objective across those runs is a genuine, computed parameter-
    sensitivity signal (a flat plateau vs a single spike). Returns None when the
    payload carries no usable ``runs`` list — the field is emitted only *where
    derivable*, never invented.
    """

    text = str(detail_json_text or "").strip()
    if not text or text == "{}":
        return None
    try:
        data = json.loads(text)
    except (ValueError, TypeError):
        return None
    if not isinstance(data, dict):
        return None
    runs = data.get("runs")
    if not isinstance(runs, list) or not runs:
        return None
    pfs: list[float] = []
    nets: list[float] = []
    for run in runs:
        if not isinstance(run, dict):
            continue
        pf = run.get("profit_factor")
        net = run.get("net_profit")
        if isinstance(pf, (int, float)) and not isinstance(pf, bool):
            pfs.append(float(pf))
        if isinstance(net, (int, float)) and not isinstance(net, bool):
            nets.append(float(net))
    if not pfs:
        return None
    n = len(pfs)
    pf_min, pf_max = min(pfs), max(pfs)
    pf_mean = sum(pfs) / n
    if n >= 2:
        variance = sum((x - pf_mean) ** 2 for x in pfs) / n
        pf_std = variance ** 0.5
        pf_cv = (pf_std / pf_mean) if pf_mean not in (0.0, -0.0) else None
        derivation = "objective_spread_over_census_runs"
    else:
        pf_cv = None
        derivation = "single_run"
    return {
        "n_runs": int(data.get("n_runs") or n),
        "pf_min": round(pf_min, 6),
        "pf_max": round(pf_max, 6),
        "pf_range": round(pf_max - pf_min, 6),
        "pf_mean": round(pf_mean, 6),
        "pf_cv": (round(pf_cv, 6) if pf_cv is not None else ""),
        "net_min": (round(min(nets), 6) if nets else ""),
        "net_max": (round(max(nets), 6) if nets else ""),
        "derivation": derivation,
    }


def _registry_ea_key(raw: Any) -> str:
    """Normalize a registry ``ea_id`` (bare int) to the ``QM5_<num>`` work-item key."""

    token = str(raw or "").strip()
    if not token:
        return ""
    if token.upper().startswith("QM5_"):
        return token
    digits = "".join(ch for ch in token if ch.isdigit())
    return f"QM5_{digits}" if digits else token


def _reason_class(taxonomy: str, verdict: str | None, reason: str | None) -> str:
    """Deterministic coarse reason class, keeping INFRA transport residue apart."""

    tax = (taxonomy or "").lower()
    token = (verdict or "").upper()
    if tax == "infra":
        haystack = f"{reason or ''} {token}".upper()
        for infra_token in work_item_clean_view.INFRA_REASON_TOKENS:
            if infra_token in haystack:
                return infra_token
        return "INFRA_OTHER"
    if not token:
        return "OPEN"
    if token.startswith("ZERO"):
        return "ZERO_TRADES"
    if token.startswith("RETIR"):
        return "RETIRE"
    if token.startswith("PASS"):
        return "PASS"
    if token.startswith("FAIL"):
        return "FAIL_PORTFOLIO" if "PORTFOLIO" in token else "FAIL"
    if token in {"MEASURED", "PRESCREEN_MEASURED"}:
        return "MEASURED"
    if token.startswith(("SKIPPED", "SUPERSEDED", "CANCELLED", "BLOCKED", "OBSOLETE")):
        return token.split("_", 1)[0]
    return token


def _window(start: Any, end: Any) -> str:
    lo = str(start or "").strip()
    hi = str(end or "").strip()
    if lo and hi:
        return f"{lo}..{hi}"
    return lo or hi or ""


def _sha256_file(path: Path) -> str:
    digest = hashlib.sha256()
    with path.open("rb") as stream:
        for chunk in iter(lambda: stream.read(1 << 20), b""):
            digest.update(chunk)
    return digest.hexdigest()


def _git_commit(repo_root: Path) -> str | None:
    try:
        result = subprocess.run(
            ["git", "-C", str(repo_root), "rev-parse", "HEAD"],
            capture_output=True,
            text=True,
            timeout=10,
            check=False,
        )
    except (OSError, subprocess.SubprocessError):
        return None
    out = (result.stdout or "").strip()
    return out or None


def _table_exists(connection: sqlite3.Connection, name: str) -> bool:
    row = connection.execute(
        "SELECT 1 FROM sqlite_master WHERE type IN ('table','view') AND name = ?",
        (name,),
    ).fetchone()
    return row is not None


def _table_columns(connection: sqlite3.Connection, name: str) -> set[str]:
    return {
        str(row[1])
        for row in connection.execute(f"PRAGMA table_info({name})")
    }


def _write_csv(path: Path, header: list[str], rows: Iterable[dict[str, Any]]) -> int:
    count = 0
    with path.open("w", encoding="utf-8", newline="") as handle:
        writer = csv.DictWriter(handle, fieldnames=header, extrasaction="ignore")
        writer.writeheader()
        for row in rows:
            writer.writerow({key: ("" if row.get(key) is None else row.get(key)) for key in header})
            count += 1
    return count


def load_idea_families(registry_path: Path) -> dict[str, dict[str, str]]:
    """Read the idea->EA->family map from the registry CSV (read-only)."""

    families: dict[str, dict[str, str]] = {}
    if not registry_path.exists():
        return families
    with registry_path.open("r", encoding="utf-8", newline="") as handle:
        reader = csv.DictReader(handle)
        for row in reader:
            ea_key = _registry_ea_key(row.get("ea_id"))
            if not ea_key:
                continue
            slug = str(row.get("slug") or "").strip()
            families[ea_key] = {
                "ea_id": ea_key,
                "strategy_id": str(row.get("strategy_id") or "").strip(),
                "slug": slug,
                "family": classify_family(slug),
                "status": str(row.get("status") or "").strip(),
            }
    return families


# --- SQL used per emitted file (recorded verbatim in the manifest) -----------

_SQL_GATE_OUTCOMES = (
    "SELECT id, ea_id, symbol, phase, verdict, verdict_taxonomy, verdict_reason, "
    "setfile_path, data_window_start, data_window_end, created_at "
    "FROM work_items_clean ORDER BY created_at, id{limit}"
)

_SQL_HOLDS = (
    "SELECT work_item_id, hold_code, reason, active FROM work_item_holds "
    "ORDER BY work_item_id{limit}"
)

_SQL_SOURCES = (
    "SELECT id, source_type, lane, status, uri, title FROM sources ORDER BY id{limit}"
)


def project(
    db_path: Path | str,
    out_root: Path | str,
    *,
    registry_path: Path | str | None = None,
    limit: int | None = None,
    now: dt.datetime | None = None,
) -> dict[str, Any]:
    """Emit a versioned OBSERVE dataset directory and return the manifest dict."""

    db_path = Path(db_path)
    out_root = Path(out_root)
    registry_path = Path(registry_path) if registry_path is not None else DEFAULT_REGISTRY

    stamp = _stamp_utc(now)
    dataset_dir = out_root / stamp
    dataset_dir.mkdir(parents=True, exist_ok=True)

    db_stat = db_path.stat()
    limit_clause = f" LIMIT {int(limit)}" if limit is not None else ""

    row_counts: dict[str, int] = {}
    query_text: dict[str, str] = {}
    taxonomy_counter: Counter[str] = Counter()

    # Load the idea->slug/family map up front: the white-space session classifier
    # (directive §46) keys off the registry slug, so it must be available inside
    # the gate loop, not only for idea_families.csv further down.
    families = load_idea_families(registry_path)

    connection = work_item_clean_view.open_clean_view_connection(db_path)
    try:
        connection.row_factory = sqlite3.Row

        # gate_outcomes.csv -- one row per run, taxonomy-labelled, plus the
        # white-space axes (timeframe/holding/symbol_class/session).
        gate_sql = _SQL_GATE_OUTCOMES.format(limit=limit_clause)
        query_text["gate_outcomes.csv"] = gate_sql
        gate_rows: list[dict[str, Any]] = []
        for row in connection.execute(gate_sql):
            taxonomy = str(row["verdict_taxonomy"] or "unknown")
            taxonomy_counter[taxonomy] += 1
            timeframe = classify_timeframe(row["setfile_path"])
            slug = (families.get(str(row["ea_id"] or "")) or {}).get("slug", "")
            gate_rows.append(
                {
                    "work_item_id": row["id"],
                    "ea_id": row["ea_id"],
                    "symbol": row["symbol"],
                    "phase": row["phase"],
                    "verdict": row["verdict"],
                    "verdict_taxonomy": taxonomy,
                    "reason_class": _reason_class(taxonomy, row["verdict"], row["verdict_reason"]),
                    "window": _window(row["data_window_start"], row["data_window_end"]),
                    "timeframe": timeframe,
                    "holding_class": classify_holding(timeframe),
                    "symbol_class": classify_symbol_class(row["symbol"]),
                    "session": classify_session(slug),
                    "created": row["created_at"],
                }
            )
        row_counts["gate_outcomes.csv"] = _write_csv(
            dataset_dir / "gate_outcomes.csv",
            [
                "work_item_id",
                "ea_id",
                "symbol",
                "phase",
                "verdict",
                "verdict_taxonomy",
                "reason_class",
                "window",
                "timeframe",
                "holding_class",
                "symbol_class",
                "session",
                "created",
            ],
            gate_rows,
        )

        # ea_metrics.csv -- normalized headline scalars (read the table, not gzip).
        metrics_header = [
            "work_item_id",
            "ea_id",
            "symbol",
            "phase",
            "verdict",
            "net_profit",
            "profit_factor",
            "trades",
            "drawdown_money",
            "drawdown_pct",
            "sharpe",
        ]
        if _table_exists(connection, "ea_metrics"):
            metric_sql = (
                "SELECT work_item_id, ea_id, symbol, phase, verdict, net_profit, "
                "profit_factor, trades, drawdown_money, drawdown_pct, sharpe "
                f"FROM ea_metrics ORDER BY work_item_id{limit_clause}"
            )
            metric_rows = [dict(r) for r in connection.execute(metric_sql)]
        else:
            metric_sql = "-- ea_metrics table absent"
            metric_rows = []
        query_text["ea_metrics.csv"] = metric_sql
        row_counts["ea_metrics.csv"] = _write_csv(
            dataset_dir / "ea_metrics.csv", metrics_header, metric_rows
        )

        # holds.csv
        if _table_exists(connection, "work_item_holds"):
            holds_sql = _SQL_HOLDS.format(limit=limit_clause)
            hold_rows = [dict(r) for r in connection.execute(holds_sql)]
        else:
            holds_sql = "-- work_item_holds table absent"
            hold_rows = []
        query_text["holds.csv"] = holds_sql
        row_counts["holds.csv"] = _write_csv(
            dataset_dir / "holds.csv",
            ["work_item_id", "hold_code", "reason", "active"],
            hold_rows,
        )

        # sources.csv -- DISCOVER intake feed + provenance (reference data).
        if _table_exists(connection, "sources"):
            sources_sql = _SQL_SOURCES.format(limit=limit_clause)
            source_rows = [dict(r) for r in connection.execute(sources_sql)]
        else:
            sources_sql = "-- sources table absent"
            source_rows = []
        query_text["sources.csv"] = sources_sql
        row_counts["sources.csv"] = _write_csv(
            dataset_dir / "sources.csv",
            ["id", "source_type", "lane", "status", "uri", "title"],
            source_rows,
        )

        # parameter_sensitivity.csv -- derived ONLY where an ea_metrics.detail_json
        # carries an optimisation-census ``runs`` list (directive §45 "parameters
        # that do not matter"; audit missing field (d)). A row is emitted only when
        # the sensitivity is genuinely derivable — never invented for the rest.
        param_header = [
            "work_item_id", "ea_id", "symbol", "phase",
            "n_runs", "pf_min", "pf_max", "pf_range", "pf_mean", "pf_cv",
            "net_min", "net_max", "derivation",
        ]
        param_rows: list[dict[str, Any]] = []
        if _table_exists(connection, "ea_metrics"):
            param_sql = (
                "SELECT work_item_id, ea_id, symbol, phase, detail_json "
                f"FROM ea_metrics ORDER BY work_item_id{limit_clause}"
            )
            for r in connection.execute(param_sql):
                sens = extract_parameter_sensitivity(r["detail_json"])
                if sens is None:
                    continue
                entry = {
                    "work_item_id": r["work_item_id"],
                    "ea_id": r["ea_id"],
                    "symbol": r["symbol"],
                    "phase": r["phase"],
                }
                entry.update(sens)
                param_rows.append(entry)
        else:
            param_sql = "-- ea_metrics table absent"
        query_text["parameter_sensitivity.csv"] = param_sql
        row_counts["parameter_sensitivity.csv"] = _write_csv(
            dataset_dir / "parameter_sensitivity.csv", param_header, param_rows
        )
    finally:
        connection.close()

    # idea_families.csv -- derived from the registry slug/family metadata (loaded
    # once above and reused here).
    query_text["idea_families.csv"] = f"-- derived from {registry_path.name} (slug->family heuristic)"
    row_counts["idea_families.csv"] = _write_csv(
        dataset_dir / "idea_families.csv",
        ["ea_id", "strategy_id", "slug", "family", "status"],
        families.values(),
    )

    # Every taxonomy -> its dataset disposition, so the split is provably complete.
    economic = {"strategy"}
    infra = {"infra"}
    measurement = {"measurement", "prescreen_measurement"}
    invalid = {"invalid"}
    taxonomy_split: dict[str, dict[str, Any]] = {}
    for taxonomy, count in sorted(taxonomy_counter.items()):
        if taxonomy in economic:
            disposition = "economic"
        elif taxonomy in infra:
            disposition = "infra"
        elif taxonomy in measurement:
            disposition = "measurement"
        elif taxonomy in invalid:
            disposition = "invalid"
        else:
            disposition = "excluded"
        taxonomy_split[taxonomy] = {"rows": count, "disposition": disposition}

    sha256: dict[str, str] = {}
    for name in sorted(row_counts):
        sha256[name] = _sha256_file(dataset_dir / name)

    manifest = {
        "schema": DATASET_SCHEMA,
        "stamp_utc": stamp,
        "dataset_id": None,  # filled below = sha256 of this manifest's file bytes
        "source_db_path": str(db_path.resolve()),
        "source_db_size_bytes": db_stat.st_size,
        "source_db_mtime_utc": dt.datetime.fromtimestamp(db_stat.st_mtime, dt.UTC)
        .replace(microsecond=0)
        .isoformat(),
        "row_counts": row_counts,
        "verdict_taxonomy_split": taxonomy_split,
        "sha256": sha256,
        "query_text": query_text,
        "registry_path": str(registry_path.resolve()) if registry_path.exists() else str(registry_path),
        "git_commit": _git_commit(_SF.parents[1]),
        "limit": int(limit) if limit is not None else None,
        "farm_state_snapshot_note": (
            "farm_state.sqlite is a live, growing DB; this dataset is a timestamped "
            "snapshot, not reproducible-forever. Content-address via the per-file "
            "sha256 map and this manifest's own sha256 (dataset_id)."
        ),
    }

    manifest_path = dataset_dir / "manifest.json"
    manifest_path.write_text(
        json.dumps(manifest, indent=2, sort_keys=True) + "\n", encoding="utf-8", newline="\n"
    )
    # dataset_id = sha256 of the manifest file the consumer will hash.
    manifest["dataset_id"] = _sha256_file(manifest_path)
    manifest["dataset_dir"] = str(dataset_dir.resolve())
    return manifest


def main(argv: list[str] | None = None) -> int:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--db", type=Path, default=DEFAULT_DB)
    parser.add_argument("--out-root", type=Path, default=DEFAULT_OUT_ROOT)
    parser.add_argument("--registry", type=Path, default=None)
    parser.add_argument("--limit", type=int, default=None)
    args = parser.parse_args(argv)

    manifest = project(
        args.db,
        args.out_root,
        registry_path=args.registry,
        limit=args.limit,
    )
    print(json.dumps({
        "dataset_dir": manifest["dataset_dir"],
        "dataset_id": manifest["dataset_id"],
        "row_counts": manifest["row_counts"],
        "verdict_taxonomy_split": manifest["verdict_taxonomy_split"],
    }, indent=2, sort_keys=True))
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
