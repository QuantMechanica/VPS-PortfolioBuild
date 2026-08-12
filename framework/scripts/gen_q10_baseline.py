"""Generate the Q10 baseline JSON for KS-test kill-switch (FW4).

Per 2026-05-23 pipeline rewrite (Vault Q10 Full-History Confirmation + Q13
Live Burn-In on DXZ). When an (EA, symbol) pair PASSes Q10, this script
parses the canonical full-history report and writes a sorted trade-net-
profit baseline that the live KS-test compares against.

Output default — STAGING, never live (WP-11 OWNER gate, 2026-07-25 review):
    D:/QM/reports/state/q10_baselines_staging/QM5_<ea>_<symbol_underscored>.json

Every generating mode (single, --discover, the automated Q10-PASS trigger)
writes to STAGING by default. Publishing a corrected baseline into the live
MT5 Common file sandbox is OWNER-gated and requires the explicit
`--deploy-live` flag, which prints a loud line stating it is writing into the
live kill-switch path:
    <Common>/Files/QM/baselines/QM5_<ea>_<symbol_underscored>.json

The one live EA consumer (`QM_KillSwitchKS.mqh`) reads its baseline ONLY from
Common at OnInit. Staging therefore changes nothing for a running/live EA:
the live kill-switch distribution does not move until an OWNER-authorized copy
(or a `--deploy-live` run) lands a file in Common. Deploying corrected
baselines into the live path was explicitly declared OWNER-gated.

The stored distribution MUST be the same quantity the live kill-switch feeds
its KS window. The live path (QM_Common.mqh:805-808, 835) sums, per closing
deal, `DEAL_PROFIT + DEAL_SWAP + DEAL_COMMISSION` and calls
`QM_KillSwitchKSOnTradeClosed(net)`. So the baseline is per-trade NET, read
from the report's Profit + Swap + Commission columns — by NAME, never by
position (a positional read picks spaced-thousands fragments like
'-1 023.75' -> '023.75' and numeric-comment cells like 'sl 0.74059' from the
wrong column; see WP-11 / 2026-07-25 gate autopsy claim 3).

JSON schema:
    {
      "ea_id": 1056,
      "symbol": "NDX.DWX",
      "spec_version": "Q10-2026-05-23",
      "generated_at_utc": "...",
      "n": 412,
      "mean": 69.05,
      "std": 348.21,
      "trades_sorted": [...]      # per-trade NET, sorted ascending
      "hash": "<sha256 of trades_sorted>"
    }

Usage:
    # Single (EA, symbol) -> writes into the STAGING baselines dir (default, safe)
    python gen_q10_baseline.py --ea-id 1056 --symbol NDX.DWX \
        --report D:/QM/reports/pipeline/QM5_1056/Q10/NDX.DWX/report.htm

    # Regenerate into an explicit scratch dir (still not live)
    python gen_q10_baseline.py --discover D:/QM/reports/pipeline \
        --out-dir D:/QM/reports/state/q10_baselines_regen

    # OWNER-gated: publish into the live MT5 Common kill-switch dir (loud warning)
    python gen_q10_baseline.py --ea-id 1056 --symbol NDX.DWX \
        --report D:/QM/reports/pipeline/QM5_1056/Q10/NDX.DWX/report.htm --deploy-live

    # Verify one existing baseline against a freshly-parsed report (read-only)
    python gen_q10_baseline.py --verify \
        --baseline "<Common>/Files/QM/baselines/QM5_1056_NDX_DWX.json" \
        --report D:/QM/reports/pipeline/QM5_1056/Q10/NDX.DWX/report.htm

    # Audit every Q10-PASS baseline against its source report (read-only, no writes)
    python gen_q10_baseline.py --audit D:/QM/reports
"""

from __future__ import annotations

import argparse
import datetime as dt
import hashlib
import json
import os
import re
import statistics
import sys
from pathlib import Path

# --- STAGING (default) vs LIVE Common (OWNER-gated) --------------------------
# WP-11 OWNER gate (Codex review 2026-07-25): generation defaults to a STAGING
# directory and NEVER touches the live MT5 Common kill-switch dir unless the
# operator passes --deploy-live. The live loader (QM_KillSwitchKS.mqh) reads
# only from Common at OnInit, so staging is inert for live books; promoting a
# corrected baseline into Common is an OWNER-authorized action.
STAGING_DIR = Path(r"D:\QM\reports\state\q10_baselines_staging")

# 2026-07-06 audit: baselines MUST live inside the MT5 file sandbox or no EA
# can ever read them (drive-letter paths are invalid for MQL5 FileOpen — the
# historical D:/QM/data/baselines target made the KS kill path permanently
# dormant). QM_KillSwitchKS loads `QM\baselines\QM5_<id>_<sym>.json` local-
# first, then Common\Files via FILE_COMMON; this is the shared Common root so
# every terminal (factory + T_Live) sees the same baseline. This is now the
# OWNER-GATED --deploy-live target only, NOT the default output.
BASELINE_DIR = Path(
    r"C:\Users\Administrator\AppData\Roaming\MetaQuotes\Terminal\Common\Files\QM\baselines"
)

# The live loader (QM_KillSwitchKS.mqh:157) rejects a baseline with fewer than
# 10 samples, so a shorter distribution never arms the kill path. Mirror that
# floor here: a baseline below it is useless, so refuse to write one.
EA_MIN_BASELINE_N = 10

# MT5 .htm report parsing. MT5 reports are UTF-16 LE BOM by default.
#
# The deals table is a localised HTML table. We resolve its columns BY NAME
# from the header row and read Profit / Swap / Commission out of the named
# cells — never by counting numbers on the stripped row. Closing deals are
# marked in the Direction column: 'out' (English), 'aus' (German) or
# 'sortie' (French); the header labels are localised the same way, so each
# column is matched against a localisation-tolerant alias set.
ROW_RE = re.compile(r"<tr[^>]*>(.*?)</tr>", re.DOTALL | re.IGNORECASE)
CELL_RE = re.compile(r"<t[dh][^>]*>(.*?)</t[dh]>", re.DOTALL | re.IGNORECASE)
TAG_RE = re.compile(r"<[^>]+>")

# Header-cell aliases (lower-cased) for the four columns we must resolve.
_COL_ALIASES: dict[str, set[str]] = {
    "direction": {"direction", "richtung", "sens"},
    "commission": {"commission", "commissions", "kommission", "gebühr", "gebuhr"},
    "swap": {"swap", "swaps"},
    "profit": {"profit", "profits", "gewinn", "bénéfice", "benefice"},
}
# Closing-deal markers in the Direction column (English / German / French).
_CLOSING_MARKERS = {"out", "aus", "sortie"}


class ReportParseError(RuntimeError):
    """Raised when the deals table cannot be resolved or a closing deal's
    numeric cell will not parse. We FAIL LOUD rather than write a short or
    silently-wrong baseline: a truncated baseline still loads in the live EA,
    which then tests live results against the wrong distribution — the exact
    failure mode WP-11 exists to close."""


class LiveBaselineGuardError(RuntimeError):
    """Raised when a write would land in the LIVE MT5 Common kill-switch dir
    (BASELINE_DIR) or a path nested inside it WITHOUT explicit authorization
    (allow_live=True, which only the --deploy-live CLI route sets). Writing the
    live path moves the live kill-switch distribution that running EAs read at
    OnInit, so it must never happen implicitly via out_dir alone — --deploy-live
    is the single sanctioned Common-write route (WP-11 OWNER gate)."""


def read_mt5_report(path: Path) -> str:
    """Read an MT5 .htm report — UTF-16 LE BOM by default; fall back to utf-8."""
    raw = path.read_bytes()
    if raw[:2] == b"\xff\xfe":
        return raw.decode("utf-16", errors="replace")
    return raw.decode("utf-8", errors="replace")


def _cell_text(cell_html: str) -> str:
    """Strip tags/entities from one <td>/<th> cell to readable text."""
    txt = TAG_RE.sub("", cell_html)
    txt = txt.replace("&nbsp;", " ").replace("\xa0", " ")
    return txt.strip()


def _row_cells(row_html: str) -> list[str]:
    return [_cell_text(c) for c in CELL_RE.findall(row_html)]


def parse_money(cell: str) -> float:
    """Parse one numeric report cell to a float, or raise ValueError.

    MT5 groups thousands with a space/NBSP ('-1 023.75') and, in the reports
    this factory produces, uses '.' as the decimal mark; some localised
    reports use ','. Strip grouping spaces, normalise the decimal mark, keep
    the sign. Because the caller already selected the *correct* cell by column
    name, exactly one number lives here — there is no positional ambiguity to
    resolve (that ambiguity is precisely the old parser's bug)."""
    s = cell.replace("\xa0", "").replace(" ", "").strip()
    if not s:
        raise ValueError("empty numeric cell")
    if "," in s and "." in s:
        # both present: the right-most separator is the decimal mark
        if s.rfind(",") > s.rfind("."):
            s = s.replace(".", "").replace(",", ".")
        else:
            s = s.replace(",", "")
    elif "," in s:
        # comma only: MT5 money cells always carry a 2-digit fraction, so a
        # lone comma is the decimal mark, not a thousands separator
        s = s.replace(",", ".")
    return float(s)


def _resolve_deal_columns(header_cells: list[str]) -> dict[str, int] | None:
    """Map direction/commission/swap/profit to column indices from a candidate
    header row, or return None if this row is not the deals header."""
    idx: dict[str, int] = {}
    for i, cell in enumerate(header_cells):
        key = cell.strip().lower()
        for logical, aliases in _COL_ALIASES.items():
            if key in aliases and logical not in idx:
                idx[logical] = i
    if all(k in idx for k in ("direction", "commission", "swap", "profit")):
        return idx
    return None


def extract_per_trade_nets(htm: str) -> list[float]:
    """Extract per-trade NET profit for every closing deal in the report's
    deals table, in chronological (report) order.

    NET = Profit + Swap + Commission, read from the named columns — the exact
    quantity the live kill-switch feeds its KS window (QM_Common.mqh:805-808).

    Raises ReportParseError if the deals header cannot be resolved or a closing
    deal's Profit/Swap/Commission cell will not parse (fail loud — never emit a
    short or silently-wrong baseline)."""
    cols: dict[str, int] | None = None
    need = 0
    nets: list[float] = []
    for row_html in ROW_RE.findall(htm):
        cells = _row_cells(row_html)
        if cols is None:
            cols = _resolve_deal_columns(cells)
            if cols is not None:
                need = max(cols.values())
            continue
        if len(cells) <= need:
            continue  # summary / next-section / short row, not a deals data row
        direction = cells[cols["direction"]].strip().lower()
        if direction not in _CLOSING_MARKERS:
            continue  # opening deal, balance row, non-closing entry
        try:
            profit = parse_money(cells[cols["profit"]])
            swap = parse_money(cells[cols["swap"]])
            commission = parse_money(cells[cols["commission"]])
        except ValueError as exc:
            raise ReportParseError(
                f"unparseable closing-deal cell(s) in row {cells!r}: {exc}"
            ) from exc
        nets.append(profit + swap + commission)
    if cols is None:
        raise ReportParseError(
            "deals-table header not found "
            "(no row resolved direction+commission+swap+profit columns)"
        )
    return nets


def _baseline_payload(ea_id: int, symbol: str, nets: list[float]) -> dict:
    sorted_nets = sorted(nets)
    n = len(sorted_nets)
    mean = statistics.fmean(sorted_nets) if n > 0 else 0.0
    std = statistics.pstdev(sorted_nets) if n > 1 else 0.0
    body_for_hash = ",".join(f"{v:.6f}" for v in sorted_nets)
    h = hashlib.sha256(body_for_hash.encode("utf-8")).hexdigest()
    return {
        "ea_id": ea_id,
        "symbol": symbol,
        "spec_version": "Q10-2026-05-23",
        "generated_at_utc": dt.datetime.now(dt.UTC).isoformat(),
        "n": n,
        "mean": round(mean, 6),
        "std": round(std, 6),
        "trades_sorted": sorted_nets,
        "hash": h,
    }


def _resolves_into_live_dir(candidate: Path) -> bool:
    """True when `candidate` refers to the LIVE MT5 Common kill-switch dir
    (BASELINE_DIR) or a path nested inside it.

    Both sides are normalized with resolve() + os.path.normcase, so `..`
    segments, forward/back-slash mixes and (on Windows) letter case cannot
    smuggle a write into the live kill-switch path. BASELINE_DIR is read at call
    time so tests can patch the constant to a throwaway dir."""
    live = os.path.normcase(str(BASELINE_DIR.resolve()))
    cand = os.path.normcase(str(Path(candidate).resolve()))
    return cand == live or cand.startswith(live + os.sep)


def write_baseline(
    ea_id: int,
    symbol: str,
    nets: list[float],
    out_dir: Path | None = None,
    allow_live: bool = False,
) -> Path:
    # Safe by default: with no explicit out_dir this writes to STAGING, never
    # the live Common kill-switch dir. The live dir is reached only when the CLI
    # resolves out_dir=BASELINE_DIR under --deploy-live (OWNER-gated), which is
    # the ONLY route that sets allow_live=True.
    target_dir = out_dir if out_dir is not None else STAGING_DIR
    # OWNER gate at the function boundary: refuse to write into the live MT5
    # Common kill-switch dir (or anything nested in it) unless the caller
    # explicitly authorized it. A direct caller passing BASELINE_DIR without
    # allow_live=True must fail loud rather than silently move the live
    # kill-switch distribution (WP-11) — --deploy-live is not the only Common
    # route otherwise.
    if _resolves_into_live_dir(target_dir) and not allow_live:
        raise LiveBaselineGuardError(
            f"refusing to write Q10 baseline into the LIVE MT5 Common kill-switch "
            f"directory {target_dir}: this path is OWNER-gated and requires "
            f"allow_live=True (set only by the --deploy-live CLI route). Write to "
            f"the staging/scratch dir instead."
        )
    target_dir.mkdir(parents=True, exist_ok=True)
    sym_clean = symbol.replace(".", "_")
    out_path = target_dir / f"QM5_{ea_id}_{sym_clean}.json"

    # Review 27c36fb7 flow 5 (2026-07-06): a live EA calls QM_KillSwitchKSInit
    # with the BROKER chart symbol (e.g. 'NDX'), while Q10 evidence is .DWX-
    # keyed ('NDX_DWX') — without an alias no live EA would ever find its
    # baseline and the KS distribution path would stay silently dormant on
    # live books. Emit a suffix-stripped alias alongside the canonical file.
    alias_path = None
    if sym_clean.upper().endswith("_DWX"):
        alias_clean = sym_clean[: -len("_DWX")]
        if alias_clean:
            alias_path = target_dir / f"QM5_{ea_id}_{alias_clean}.json"

    payload = _baseline_payload(ea_id, symbol, nets)
    body = json.dumps(payload, indent=2)
    out_path.write_text(body, encoding="utf-8")
    if alias_path is not None:
        alias_path.write_text(body, encoding="utf-8")
    return out_path


def process_one(
    ea_id: int,
    symbol: str,
    report_path: Path,
    out_dir: Path | None = None,
    allow_live: bool = False,
) -> bool:
    if not report_path.exists():
        print(f"  FAIL  report not found: {report_path}", file=sys.stderr)
        return False
    htm = read_mt5_report(report_path)
    try:
        nets = extract_per_trade_nets(htm)
    except ReportParseError as exc:
        # Fail loud: a malformed report must never yield a written baseline.
        print(f"  FAIL  report unparseable: {exc}", file=sys.stderr)
        return False
    if len(nets) < EA_MIN_BASELINE_N:
        print(
            f"  FAIL  too few closing deals: {len(nets)} "
            f"(EA loader floor is {EA_MIN_BASELINE_N})",
            file=sys.stderr,
        )
        return False
    out = write_baseline(ea_id, symbol, nets, out_dir=out_dir, allow_live=allow_live)
    print(f"  PASS  QM5_{ea_id} {symbol}  n={len(nets)}  -> {out}")
    return True


def discover_q10_pass(pipeline_root: Path) -> list[tuple[int, str, Path]]:
    """Walk D:/QM/reports/pipeline/QM5_*/Q10/<symbol>/report.htm and
    enumerate PASS reports."""
    out: list[tuple[int, str, Path]] = []
    if not pipeline_root.exists():
        return out
    for ea_dir in sorted(pipeline_root.iterdir()):
        if not ea_dir.is_dir() or not ea_dir.name.startswith("QM5_"):
            continue
        try:
            ea_id = int(ea_dir.name.split("_")[1])
        except (IndexError, ValueError):
            continue
        q10 = ea_dir / "Q10"
        if not q10.exists():
            continue
        for sym_dir in sorted(q10.iterdir()):
            if not sym_dir.is_dir():
                continue
            report = sym_dir / "report.htm"
            if report.exists():
                out.append((ea_id, sym_dir.name, report))
    return out


# --- verification / audit (read-only; never writes a baseline) ---------------


def _distribution_diff(stored: list[float], fresh: list[float]) -> dict:
    """Summarise how a stored baseline distribution differs from a freshly
    parsed one. Both are compared as sorted multisets."""
    s = sorted(stored)
    f = sorted(fresh)
    diff: dict = {
        "n_stored": len(s),
        "n_fresh": len(f),
        "mean_stored": round(statistics.fmean(s), 4) if s else 0.0,
        "mean_fresh": round(statistics.fmean(f), 4) if f else 0.0,
        "std_stored": round(statistics.pstdev(s), 4) if len(s) > 1 else 0.0,
        "std_fresh": round(statistics.pstdev(f), 4) if len(f) > 1 else 0.0,
        "min_stored": s[0] if s else None,
        "min_fresh": f[0] if f else None,
        "max_stored": s[-1] if s else None,
        "max_fresh": f[-1] if f else None,
    }
    if len(s) == len(f):
        pairwise = [abs(a - b) for a, b in zip(s, f)]
        diff["max_abs_elem_diff"] = round(max(pairwise), 4) if pairwise else 0.0
        diff["n_elems_differ"] = sum(1 for d in pairwise if d > 1e-6)
    else:
        diff["max_abs_elem_diff"] = None
        diff["n_elems_differ"] = None
    diff["identical"] = (
        len(s) == len(f) and all(abs(a - b) <= 1e-6 for a, b in zip(s, f))
    )
    return diff


def _ks_ecdf(sorted_arr: list[float], x: float) -> float:
    n = len(sorted_arr)
    if n == 0:
        return 0.0
    lo, hi = 0, n
    while lo < hi:
        mid = (lo + hi) // 2
        if sorted_arr[mid] <= x:
            lo = mid + 1
        else:
            hi = mid
    return lo / n


def _ks_two_sample_d(a_sorted: list[float], b_sorted: list[float]) -> float:
    max_diff = 0.0
    for x in a_sorted:
        d = abs(_ks_ecdf(a_sorted, x) - _ks_ecdf(b_sorted, x))
        if d > max_diff:
            max_diff = d
    for x in b_sorted:
        d = abs(_ks_ecdf(a_sorted, x) - _ks_ecdf(b_sorted, x))
        if d > max_diff:
            max_diff = d
    return max_diff


def ks_self_divergence(
    baseline_sorted: list[float],
    chrono_nets: list[float],
    window_max: int = 50,
    window_min: int = 30,
    alpha_c: float = 1.358,
) -> dict:
    """Replay the EA's own KS check (QM_KillSwitchKS.mqh) using the stored
    baseline against the correctly-parsed source history fed in chronologically
    through the same 50-deep ring / 30-sample-minimum / D_crit machinery.
    Reports whether the baseline would ever flag its own source history as
    divergent — a false-kill risk. This is a forensic replay, not a backtest."""
    n1 = len(baseline_sorted)
    ring: list[float] = []
    ever = False
    first_at = None
    worst_ratio = 0.0
    for i, v in enumerate(chrono_nets):
        if len(ring) < window_max:
            ring.append(v)
        else:
            ring[i % window_max] = v
        count = i + 1
        if count < window_min:
            continue
        live = sorted(ring)
        n2 = len(live)
        d = _ks_two_sample_d(baseline_sorted, live)
        d_crit = alpha_c * ((n1 + n2) / (n1 * n2)) ** 0.5 if n1 and n2 else 1.0
        ratio = d / d_crit if d_crit else 0.0
        if ratio > worst_ratio:
            worst_ratio = ratio
        if d > d_crit and not ever:
            ever = True
            first_at = count
    return {
        "self_divergent": ever,
        "first_divergent_at_trade": first_at,
        "worst_d_over_dcrit": round(worst_ratio, 4),
    }


def verify_one(baseline_path: Path, report_path: Path) -> dict:
    """Re-parse report_path with the corrected parser and compare to the stored
    baseline JSON. Read-only. Returns a structured divergence record."""
    stored = json.loads(baseline_path.read_text(encoding="utf-8", errors="replace"))
    stored_trades = list(stored.get("trades_sorted", []))
    htm = read_mt5_report(report_path)
    fresh_nets = extract_per_trade_nets(htm)  # may raise ReportParseError
    rec = {
        "baseline": str(baseline_path),
        "report": str(report_path),
        "ea_id": stored.get("ea_id"),
        "symbol": stored.get("symbol"),
    }
    rec.update(_distribution_diff(stored_trades, fresh_nets))
    rec["ks_self_divergence"] = ks_self_divergence(sorted(stored_trades), fresh_nets)
    return rec


def _iter_q10_pass_aggregates(reports_root: Path):
    """Yield the newest PASS aggregate.json per (ea,symbol) under reports_root."""
    best: dict[tuple, tuple[Path, dict]] = {}
    for dirpath, _dirs, files in os.walk(reports_root):
        if "aggregate.json" not in files:
            continue
        if (os.sep + "Q10" + os.sep) not in (dirpath + os.sep):
            continue
        p = Path(dirpath) / "aggregate.json"
        try:
            d = json.loads(p.read_text(encoding="utf-8", errors="replace"))
        except (OSError, json.JSONDecodeError):
            continue
        if d.get("phase") != "Q10" or d.get("verdict") != "PASS":
            continue
        key = (d.get("ea_id"), str(d.get("symbol")))
        g = d.get("generated_at_utc", "")
        if key not in best or g > best[key][1].get("generated_at_utc", ""):
            best[key] = (p, d)
    for key, (_p, d) in sorted(best.items(), key=lambda x: (x[0][0] or 0, x[0][1])):
        yield d


def audit_all(reports_root: Path, baseline_dir: Path) -> int:
    """Audit every Q10-PASS baseline against its source report. Read-only."""
    n_seen = n_missing = n_unparseable = n_changed = n_selfdiv = 0
    print(
        "ea_id\tsymbol\tn_old\tn_new\tdN\tmin_old\tmin_new\tmean_old\tmean_new"
        "\tchanged\tself_div\tworst_D/Dcrit"
    )
    for d in _iter_q10_pass_aggregates(reports_root):
        ea_id = d.get("ea_id")
        symbol = str(d.get("symbol"))
        report = d.get("report_htm")
        sym_clean = symbol.replace(".", "_")
        baseline_path = baseline_dir / f"QM5_{ea_id}_{sym_clean}.json"
        n_seen += 1
        if not baseline_path.exists():
            print(f"{ea_id}\t{symbol}\tMISSING_BASELINE\t{baseline_path}")
            n_missing += 1
            continue
        if not report or not Path(report).exists():
            print(f"{ea_id}\t{symbol}\tMISSING_REPORT\t{report}")
            n_missing += 1
            continue
        try:
            rec = verify_one(baseline_path, Path(report))
        except ReportParseError as exc:
            print(f"{ea_id}\t{symbol}\tUNPARSEABLE\t{exc}")
            n_unparseable += 1
            continue
        changed = not rec["identical"]
        sd = rec["ks_self_divergence"]["self_divergent"]
        if changed:
            n_changed += 1
        if sd:
            n_selfdiv += 1
        print(
            f"{ea_id}\t{symbol}\t{rec['n_stored']}\t{rec['n_fresh']}"
            f"\t{(rec['n_fresh'] or 0) - (rec['n_stored'] or 0)}"
            f"\t{rec['min_stored']}\t{rec['min_fresh']}"
            f"\t{rec['mean_stored']}\t{rec['mean_fresh']}"
            f"\t{'YES' if changed else 'no'}\t{'YES' if sd else 'no'}"
            f"\t{rec['ks_self_divergence']['worst_d_over_dcrit']}"
        )
    print(
        f"\naudited={n_seen}  changed={n_changed}  self_divergent={n_selfdiv}"
        f"  missing={n_missing}  unparseable={n_unparseable}"
    )
    return 0


def _resolve_out_dir(args) -> Path:
    """Resolve the generation target directory, safe by default.

    Precedence: explicit --out-dir wins (but may NOT name the live Common dir,
    or a path nested in it, without --deploy-live); else --deploy-live selects
    the live MT5 Common kill-switch dir (with a loud warning); else STAGING. The
    live Common dir is NEVER the default — it is reached only via --deploy-live."""
    if args.out_dir is not None:
        # --deploy-live is the ONLY sanctioned route into the live kill-switch
        # dir. An explicit --out-dir that resolves into it (exactly, or nested)
        # without the flag is refused — otherwise --deploy-live would not be the
        # exclusive Common-write route (WP-11).
        if _resolves_into_live_dir(args.out_dir) and not args.deploy_live:
            print(
                f"REFUSED: --out-dir {args.out_dir} resolves into the LIVE MT5 "
                f"Common kill-switch directory {BASELINE_DIR}. Writing the live "
                "kill-switch path is OWNER-gated — re-run with --deploy-live to "
                "publish into live (it prints a loud warning), or point --out-dir "
                "at a staging/scratch directory.",
                file=sys.stderr,
            )
            sys.exit(2)
        return args.out_dir
    if args.deploy_live:
        print(
            "!!! --deploy-live: writing Q10 baseline(s) into the LIVE MT5 Common "
            f"kill-switch directory {BASELINE_DIR} — live EAs read this path at "
            "OnInit. This is an OWNER-gated promotion into the live kill-switch path.",
            file=sys.stderr,
        )
        return BASELINE_DIR
    return STAGING_DIR


def main() -> int:
    ap = argparse.ArgumentParser(description="Generate / verify Q10 KS-test baseline JSON")
    ap.add_argument("--ea-id", type=int, help="EA id (with --symbol + --report)")
    ap.add_argument("--symbol", help="symbol e.g. NDX.DWX")
    ap.add_argument("--report", type=Path, help="path to Q10 MT5 .htm report")
    ap.add_argument("--discover", type=Path, help="walk pipeline root and emit baselines for every Q10-PASS")
    ap.add_argument("--out-dir", type=Path, help="write baselines to this explicit dir (overrides the staging default; may NOT name the live Common dir, or a path nested in it, without --deploy-live)")
    ap.add_argument("--deploy-live", action="store_true",
                    help="OWNER-GATED: publish into the live MT5 Common kill-switch dir instead of staging (prints a loud warning). Default writes to staging.")
    ap.add_argument("--verify", action="store_true", help="verify --baseline against --report (read-only)")
    ap.add_argument("--baseline", type=Path, help="existing baseline JSON to verify")
    ap.add_argument("--audit", type=Path, help="reports root: audit every Q10-PASS baseline vs its source report (read-only)")
    ap.add_argument("--baseline-dir", type=Path, default=BASELINE_DIR, help="baseline dir for --audit (default: live Common)")
    args = ap.parse_args()

    if args.audit:
        return audit_all(args.audit, args.baseline_dir)

    if args.verify:
        if not (args.baseline and args.report):
            print("--verify requires --baseline and --report", file=sys.stderr)
            return 2
        try:
            rec = verify_one(args.baseline, args.report)
        except ReportParseError as exc:
            print(f"UNPARSEABLE: {exc}", file=sys.stderr)
            return 1
        print(json.dumps(rec, indent=2))
        return 0

    # Generation modes below WRITE. Resolve the target dir safe-by-default:
    # staging unless --out-dir or the OWNER-gated --deploy-live is supplied.
    if args.deploy_live and args.out_dir is not None:
        print("--deploy-live and --out-dir are mutually exclusive", file=sys.stderr)
        return 2
    out_dir = _resolve_out_dir(args)
    # Only the OWNER-gated --deploy-live route authorizes a live-dir write; it is
    # the single place allow_live is set for the write_baseline boundary guard.
    allow_live = bool(args.deploy_live)

    if args.discover:
        targets = discover_q10_pass(args.discover)
        if not targets:
            print(f"no Q10 reports found under {args.discover}", file=sys.stderr)
            return 1
        n_pass = sum(
            1 for (ea, sym, rep) in targets
            if process_one(ea, sym, rep, out_dir=out_dir, allow_live=allow_live)
        )
        print(f"\n{n_pass}/{len(targets)} baselines written.")
        return 0 if n_pass == len(targets) else 1

    if not (args.ea_id and args.symbol and args.report):
        ap.print_usage(sys.stderr)
        return 2

    return 0 if process_one(
        args.ea_id, args.symbol, args.report, out_dir=out_dir, allow_live=allow_live
    ) else 1


if __name__ == "__main__":
    sys.exit(main())
