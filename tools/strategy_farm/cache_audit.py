"""Audit MT5 custom-history and tester-cache coverage for strategy farm EAs."""

from __future__ import annotations

import argparse
import json
import re
from collections import defaultdict
from pathlib import Path
from typing import Any


DEFAULT_REPO_ROOT = Path(__file__).resolve().parents[2]
DEFAULT_MT5_ROOT = Path(r"D:\QM\mt5")
VALID_TFS = ("MN1", "W1", "D1", "H12", "H8", "H6", "H4", "H3", "H2", "H1",
             "M30", "M20", "M15", "M12", "M10", "M6", "M5", "M4", "M3", "M2", "M1")
PERIOD_ALIASES = {
    "D1": "Daily",
    "W1": "Weekly",
    "MN1": "Monthly",
}
TESTER_CACHE_RE = re.compile(
    r"^(?P<ea>QM5_\d{4}_.+?)\.(?P<symbol>.+?\.DWX)\.(?P<period>[^.]+)\."
    r"(?P<start>\d{8})_(?P<end>\d{8})\."
)


def canonical_period(period: str) -> str:
    """Normalize setfile periods to the spelling used by MT5 tester cache."""
    return PERIOD_ALIASES.get(period, period)


def contiguous_ranges(years: list[int]) -> list[dict[str, int]]:
    if not years:
        return []
    ranges: list[dict[str, int]] = []
    start = prev = years[0]
    for year in years[1:]:
        if year == prev + 1:
            prev = year
            continue
        ranges.append({"from_year": start, "to_year": prev})
        start = prev = year
    ranges.append({"from_year": start, "to_year": prev})
    return ranges


def collect_history_coverage(mt5_root: Path = DEFAULT_MT5_ROOT) -> dict[str, dict[str, Any]]:
    """Return symbol -> history years/terminals from Bases/Custom/history/*.hcc."""
    coverage: dict[str, dict[str, Any]] = {}
    for hcc in mt5_root.glob("T*/Bases/Custom/history/*/*.hcc"):
        if not hcc.stem.isdigit():
            continue
        terminal = hcc.parts[len(mt5_root.parts)]
        symbol = hcc.parent.name
        year = int(hcc.stem)
        entry = coverage.setdefault(symbol, {"years": set(), "terminals": defaultdict(list)})
        entry["years"].add(year)
        entry["terminals"][terminal].append(year)
    out: dict[str, dict[str, Any]] = {}
    for symbol, entry in sorted(coverage.items()):
        years = sorted(entry["years"])
        out[symbol] = {
            "years": years,
            "ranges": contiguous_ranges(years),
            "terminals": {
                terminal: contiguous_ranges(sorted(set(vals)))
                for terminal, vals in sorted(entry["terminals"].items())
            },
        }
    return out


def collect_tester_cache(mt5_root: Path = DEFAULT_MT5_ROOT) -> dict[str, dict[str, Any]]:
    """Return symbol -> period -> cached tester date ranges parsed from .tst names."""
    cache: dict[str, dict[str, list[dict[str, Any]]]] = defaultdict(lambda: defaultdict(list))
    for tst in mt5_root.glob("T*/Tester/cache/*.tst"):
        m = TESTER_CACHE_RE.match(tst.name)
        if not m:
            continue
        terminal = tst.parts[len(mt5_root.parts)]
        cache[m.group("symbol")][m.group("period")].append({
            "terminal": terminal,
            "ea": m.group("ea"),
            "from": m.group("start"),
            "to": m.group("end"),
            "path": str(tst),
        })
    return {
        symbol: {period: sorted(rows, key=lambda r: (r["from"], r["to"], r["terminal"], r["ea"]))
                 for period, rows in sorted(periods.items())}
        for symbol, periods in sorted(cache.items())
    }


def parse_ea_setfile_requirements(repo_root: Path = DEFAULT_REPO_ROOT) -> dict[str, list[dict[str, str]]]:
    """Infer EA symbol/period requirements from canonical *_backtest.set names."""
    eas_root = repo_root / "framework" / "EAs"
    period_pat = re.compile(r"_(" + "|".join(VALID_TFS) + r")_backtest\.set$")
    reqs: dict[str, set[tuple[str, str, str]]] = defaultdict(set)
    for sets_dir in eas_root.glob("QM5_*/sets"):
        ea_dir = sets_dir.parent
        for setfile in sets_dir.glob("*_backtest.set"):
            m = period_pat.search(setfile.name)
            if not m:
                continue
            period = m.group(1)
            prefix = f"{ea_dir.name}_"
            if not setfile.name.startswith(prefix):
                continue
            symbol = setfile.name[len(prefix):setfile.name.rfind(f"_{period}_backtest.set")]
            reqs[ea_dir.name].add((symbol, period, str(setfile)))
    return {
        ea: [
            {"symbol": symbol, "period": period, "setfile": setfile}
            for symbol, period, setfile in sorted(rows)
        ]
        for ea, rows in sorted(reqs.items())
    }


def has_history_window(
    symbol: str,
    period: str,
    from_year: int,
    to_year: int,
    *,
    mt5_root: Path = DEFAULT_MT5_ROOT,
) -> tuple[bool, dict[str, Any]]:
    """Check whether current MT5 cache can support symbol/period over year window."""
    history = collect_history_coverage(mt5_root)
    tester_cache = collect_tester_cache(mt5_root)
    required = set(range(from_year, to_year + 1))
    history_years = set(history.get(symbol, {}).get("years", []))
    period_name = canonical_period(period)
    tester_rows = tester_cache.get(symbol, {}).get(period_name, [])
    tester_years: set[int] = set()
    for row in tester_rows:
        try:
            start_year = int(str(row["from"])[:4])
            end_year = int(str(row["to"])[:4])
        except ValueError:
            continue
        tester_years.update(range(start_year, end_year + 1))
    combined_years = history_years | tester_years
    missing = sorted(required - combined_years)
    detail = {
        "symbol": symbol,
        "period": period,
        "required_years": sorted(required),
        "history_years": sorted(history_years),
        "tester_cache_years": sorted(tester_years),
        "missing_years": missing,
    }
    return not missing, detail


def has_ea_history_window(
    ea_id: str,
    from_year: int,
    to_year: int,
    *,
    repo_root: Path = DEFAULT_REPO_ROOT,
    mt5_root: Path = DEFAULT_MT5_ROOT,
) -> tuple[bool, dict[str, Any]]:
    """Check whether every canonical setfile symbol for an EA covers a year window."""
    reqs_by_ea = parse_ea_setfile_requirements(repo_root)
    matching = [(ea, reqs) for ea, reqs in reqs_by_ea.items() if ea == ea_id or ea.startswith(f"{ea_id}_")]
    if not matching:
        return False, {
            "ea_id": ea_id,
            "required_years": list(range(from_year, to_year + 1)),
            "reason": "ea_setfile_requirements_not_found",
        }
    ea_name, reqs = matching[0]
    checks = []
    ok = True
    for req in reqs:
        symbol_ok, detail = has_history_window(
            req["symbol"],
            req["period"],
            from_year,
            to_year,
            mt5_root=mt5_root,
        )
        ok = ok and symbol_ok
        checks.append(detail)
    missing_symbols = [row for row in checks if row["missing_years"]]
    return ok, {
        "ea_id": ea_id,
        "ea_dir": ea_name,
        "required_years": list(range(from_year, to_year + 1)),
        "symbols_checked": len(checks),
        "missing_symbols": missing_symbols,
        "symbols": checks,
    }


def build_audit(repo_root: Path = DEFAULT_REPO_ROOT, mt5_root: Path = DEFAULT_MT5_ROOT) -> dict[str, Any]:
    history = collect_history_coverage(mt5_root)
    tester_cache = collect_tester_cache(mt5_root)
    ea_reqs = parse_ea_setfile_requirements(repo_root)
    eas: dict[str, Any] = {}
    for ea, reqs in ea_reqs.items():
        rows = []
        for req in reqs:
            symbol = req["symbol"]
            period = req["period"]
            period_name = canonical_period(period)
            rows.append({
                **req,
                "history": history.get(symbol, {"years": [], "ranges": [], "terminals": {}}),
                "tester_cache": tester_cache.get(symbol, {}).get(period_name, []),
            })
        eas[ea] = rows
    return {
        "mt5_root": str(mt5_root),
        "repo_root": str(repo_root),
        "history_symbols": history,
        "tester_cache_symbols": tester_cache,
        "eas": eas,
    }


def print_text_report(audit: dict[str, Any], ea_filter: str | None = None) -> None:
    eas = audit["eas"]
    for ea, rows in eas.items():
        if ea_filter and ea_filter not in ea:
            continue
        print(ea)
        for row in rows:
            ranges = row["history"].get("ranges") or []
            range_text = ",".join(
                f"{r['from_year']}-{r['to_year']}" if r["from_year"] != r["to_year"] else str(r["from_year"])
                for r in ranges
            ) or "none"
            tester = row.get("tester_cache") or []
            tester_text = ",".join(f"{r['terminal']}:{r['from']}-{r['to']}" for r in tester) or "none"
            print(f"  {row['symbol']} {row['period']}: history={range_text}; tester_cache={tester_text}")


def main() -> int:
    ap = argparse.ArgumentParser(description="Audit MT5 cache/history coverage for framework EAs.")
    ap.add_argument("--repo-root", type=Path, default=DEFAULT_REPO_ROOT)
    ap.add_argument("--mt5-root", type=Path, default=DEFAULT_MT5_ROOT)
    ap.add_argument("--ea", help="Substring filter, e.g. QM5_1056")
    ap.add_argument("--json", action="store_true", help="Emit full JSON report")
    args = ap.parse_args()

    audit = build_audit(args.repo_root, args.mt5_root)
    if args.json:
        print(json.dumps(audit, indent=2, sort_keys=True))
    else:
        print_text_report(audit, args.ea)
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
