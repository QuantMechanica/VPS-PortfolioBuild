#!/usr/bin/env python
"""Exit-Surgery Scan v2 -- deterministic hold-gradient + Tier-B MAE scan over a roster.

Replicates the 2026-07-04 Exit-Surgery method (adaptive hold-time buckets, surgery
signal score HIGH/WEAK/NO_CASE/NO_DATA, WR gradient early->late) and adds the
2026-07-06 Tier-B MAE check (winners' MAE as a fraction of the losers' median
|mae_acct| stop anchor). Reads sealed per-sleeve Q08 trade streams (JSONL) and,
where a Q08 work item + MT5 report can be resolved read-only, classifies exit
deals from the report.htm Deals-table comment column.

The tool is read-only: it opens farm_state.sqlite with mode=ro, never writes the DB,
never starts a terminal, and only writes CSV/JSON under --out-dir.

Method sources (quoted verbatim in the evidence doc):
  docs/research/EXIT_SURGERY_SCAN_2026-07-04.md  section "## 1. Method"
  docs/research/EXIT_SURGERY_TIER_B_MAE_VERDICT_2026-07-06.md
"""
from __future__ import annotations

import argparse
import csv
import gzip
import hashlib
import json
import math
import re
import sqlite3
from dataclasses import dataclass, field
from pathlib import Path

DEFAULT_DB = "D:/QM/strategy_farm/state/farm_state.sqlite"

# ---------------------------------------------------------------------------
# Bucket sets (verbatim edges from the 2026-07-04 method, expressed in hours)
# ---------------------------------------------------------------------------
HOUR = 1.0
DAY = 24.0
WEEK = 168.0

BUCKET_SETS = {
    # avg hold < 8h
    "short": [
        ("<1h", 0.0, 1.0),
        ("1-4h", 1.0, 4.0),
        ("4-12h", 4.0, 12.0),
        ("12-48h", 12.0, 48.0),
        (">48h", 48.0, math.inf),
    ],
    # avg hold 8-48h
    "medium": [
        ("<2h", 0.0, 2.0),
        ("2-8h", 2.0, 8.0),
        ("8-24h", 8.0, 24.0),
        ("1-3d", 24.0, 72.0),
        (">3d", 72.0, math.inf),
    ],
    # avg hold > 48h
    "long": [
        ("<12h", 0.0, 12.0),
        ("12-48h", 12.0, 48.0),
        ("2-7d", 48.0, 168.0),
        ("1-4wk", 168.0, 672.0),
        (">4wk", 672.0, math.inf),
    ],
}

MIN_TRADES = 30
MIN_BUCKET_N = 5
MIN_QUALIFYING_BUCKETS = 3

# Surgery-score thresholds (2026-07-04 method: "WR gradient early->late > 8-15 pp").
GRADIENT_HIGH_PP = 15.0   # HIGH requires an unambiguous > 15 pp gradient
GRADIENT_WEAK_PP = 8.0    # WEAK requires at least a mild positive slope
WR_EARLY_MAX = 45.0       # HIGH requires early WR < 45 %

# Tier-B MAE (2026-07-06): stop_binding if >=25 % of winners reach >=0.5x the anchor.
STOP_BINDING_SHARE = 0.25


def sha256_file(path: Path) -> str:
    h = hashlib.sha256()
    with open(path, "rb") as fh:
        for chunk in iter(lambda: fh.read(1 << 20), b""):
            h.update(chunk)
    return h.hexdigest()


def percentile(sorted_vals: list[float], q: float) -> float:
    """Linear-interpolation percentile (q in [0,1]) over an already-sorted list."""
    if not sorted_vals:
        return float("nan")
    if len(sorted_vals) == 1:
        return sorted_vals[0]
    pos = q * (len(sorted_vals) - 1)
    lo = int(math.floor(pos))
    hi = int(math.ceil(pos))
    if lo == hi:
        return sorted_vals[lo]
    frac = pos - lo
    return sorted_vals[lo] * (1 - frac) + sorted_vals[hi] * frac


def median(vals: list[float]) -> float:
    if not vals:
        return float("nan")
    s = sorted(vals)
    return percentile(s, 0.5)


# ---------------------------------------------------------------------------
# Stream loading
# ---------------------------------------------------------------------------
@dataclass
class Trade:
    entry_time: int
    exit_time: int
    net: float
    mae_acct: float
    hold_h: float
    mfe_acct: float = 0.0   # best floating profit; absent in pre-2026-09-13 streams -> 0.0


def stream_filename(ea_id: int, symbol: str) -> str:
    return f"{ea_id}_{symbol.replace('.', '_')}.jsonl"


def find_stream(roots: list[Path], ea_id: int, symbol: str) -> Path | None:
    fn = stream_filename(ea_id, symbol)
    for root in roots:
        cand = root / "QM" / "q08_trades" / fn
        if cand.exists():
            return cand
    return None


def load_trades(path: Path) -> list[Trade]:
    trades: list[Trade] = []
    with open(path, "r", encoding="utf-8") as fh:
        for line in fh:
            line = line.strip()
            if not line:
                continue
            rec = json.loads(line)
            if rec.get("event") != "TRADE_CLOSED":
                continue
            entry = int(rec["entry_time"])
            exit_t = int(rec["time"])
            hold_h = (exit_t - entry) / 3600.0
            trades.append(
                Trade(
                    entry_time=entry,
                    exit_time=exit_t,
                    net=float(rec.get("net", 0.0)),
                    mae_acct=float(rec.get("mae_acct", 0.0)),
                    hold_h=hold_h,
                    mfe_acct=float(rec.get("mfe_acct", 0.0)),
                )
            )
    # deterministic chronological order (exit time, then entry time)
    trades.sort(key=lambda t: (t.exit_time, t.entry_time))
    return trades


def choose_bucket_set(avg_hold_h: float) -> str:
    if avg_hold_h < 8.0:
        return "short"
    if avg_hold_h <= 48.0:
        return "medium"
    return "long"


# ---------------------------------------------------------------------------
# Report exit-class parsing (secondary; read-only)
# ---------------------------------------------------------------------------
def classify_comment(comment: str) -> str:
    c = comment.strip().lower()
    if "qm_tm" in c or "time_stop" in c:
        return "TIME_MGMT"
    if c.startswith("tp "):
        return "TP"
    if c.startswith("sl "):
        return "SL"
    if c == "":
        return "OTHER"
    # explicit signal-close labels
    if "signal" in c or "cross" in c or "reverse" in c or "reversal" in c or "exit_signal" in c:
        return "SIGNAL"
    return "OTHER"


def _decode_report(raw: bytes) -> str:
    if raw[:2] in (b"\xff\xfe", b"\xfe\xff"):
        return raw.decode("utf-16")
    try:
        return raw.decode("utf-8")
    except UnicodeDecodeError:
        return raw.decode("utf-16", errors="replace")


def parse_report_exit_classes(report_path: Path) -> list[str]:
    """Return the exit (direction=out) deal comment classes, in chronological order."""
    p = report_path
    if not p.exists() and Path(str(p) + ".gz").exists():
        p = Path(str(p) + ".gz")
    if not p.exists():
        return []
    raw = gzip.open(p, "rb").read() if p.suffix == ".gz" else open(p, "rb").read()
    txt = _decode_report(raw)
    i = txt.find("Deals")
    if i < 0:
        return []
    classes: list[str] = []
    for row in re.findall(r"<tr[^>]*>(.*?)</tr>", txt[i:], re.S):
        cells = [re.sub(r"<[^>]+>", "", c).strip()
                 for c in re.findall(r"<td[^>]*>(.*?)</td>", row, re.S)]
        if len(cells) >= 13 and cells[4] == "out":
            classes.append(classify_comment(cells[12]))
    return classes


def resolve_report_path(ea_id: int, symbol: str, bundle: dict | None, db_path: str) -> Path | None:
    """ea_id+symbol -> q08 work item -> aggregate.json evidence_path -> baseline report.htm.

    The bundle key is matched on the exact stream filename (ea_id AND symbol), never on
    ea_id alone: a multi-symbol EA (e.g. 11421 on AUDUSD and EURUSD) would otherwise
    cross-map one symbol's report onto the other's stream.
    """
    if not bundle:
        return None
    want = stream_filename(ea_id, symbol)
    wid = None
    for res in bundle.get("results", []):
        if int(res.get("ea_int", -1)) == ea_id and res.get("filename") == want:
            wid = res.get("q08_work_item_id")
            break
    if not wid:
        return None
    try:
        con = sqlite3.connect(f"file:{db_path}?mode=ro", uri=True)
        try:
            cur = con.execute("SELECT evidence_path FROM work_items WHERE id=?", (wid,))
            row = cur.fetchone()
        finally:
            con.close()
    except sqlite3.Error:
        return None
    if not row or not row[0]:
        return None
    agg_path = Path(row[0])
    if not agg_path.exists():
        return None
    try:
        agg = json.loads(agg_path.read_text(encoding="utf-8"))
    except (OSError, json.JSONDecodeError):
        return None
    for keypath in (("baseline_run", "baseline_report_path"),
                    ("portfolio_stream", "source_report_path")):
        node = agg
        ok = True
        for k in keypath:
            if isinstance(node, dict) and k in node:
                node = node[k]
            else:
                ok = False
                break
        if ok and isinstance(node, str) and node:
            rp = Path(node)
            if rp.exists() or Path(str(rp) + ".gz").exists():
                return rp
    return None


# ---------------------------------------------------------------------------
# Core scan
# ---------------------------------------------------------------------------
@dataclass
class BucketStat:
    label: str
    n: int
    wr: float          # percent
    net: float
    avg_net: float


@dataclass
class SleeveResult:
    ea_id: int
    symbol: str
    n_trades: int
    avg_hold_h: float
    bucket_set: str
    buckets: list[BucketStat]
    wr_early: float
    wr_late: float
    gradient_pp: float
    early_net: float
    time_mgmt_share_early: float
    exit_class_source: str
    mae_winner_med: float
    mae_winner_p75: float
    mae_winner_p90: float
    mae_anchor: float
    n_winners: int
    share_ge_0_5: float
    share_ge_0_7: float
    share_ge_0_9: float
    stop_binding: bool
    verdict: str
    reason: str
    # Symmetric MFE / giveback summary (2026-09-13). Defaulted so the NO_STREAM row and any
    # other construction site remain valid; score_sleeve fills them from mfe_giveback().
    n_winners_mfe: int = 0
    mfe_winner_med: float = float("nan")
    giveback_med: float = float("nan")
    giveback_p75: float = float("nan")
    giveback_p90: float = float("nan")
    giveback_mean: float = float("nan")


def bucketize(trades: list[Trade], bucket_set: str) -> list[BucketStat]:
    stats: list[BucketStat] = []
    for label, lo, hi in BUCKET_SETS[bucket_set]:
        members = [t for t in trades if lo <= t.hold_h < hi]
        n = len(members)
        if n == 0:
            stats.append(BucketStat(label, 0, float("nan"), 0.0, float("nan")))
            continue
        wins = sum(1 for t in members if t.net > 0)
        net = sum(t.net for t in members)
        stats.append(BucketStat(label, n, 100.0 * wins / n, net, net / n))
    return stats


def mae_tier_b(trades: list[Trade]) -> tuple[float, int, float, float, float, float, float, float, bool]:
    """Return (anchor, n_winners, med, p75, p90, share.5, share.7, share.9, stop_binding)."""
    losers = [abs(t.mae_acct) for t in trades if t.net < 0]
    winners = [abs(t.mae_acct) for t in trades if t.net > 0]
    nan = float("nan")
    if not losers or not winners:
        return (nan, len(winners), nan, nan, nan, nan, nan, nan, False)
    anchor = median(losers)
    if anchor <= 0:
        return (anchor, len(winners), nan, nan, nan, nan, nan, nan, False)
    ratios = sorted(w / anchor for w in winners)
    nw = len(ratios)
    med = percentile(ratios, 0.5)
    p75 = percentile(ratios, 0.75)
    p90 = percentile(ratios, 0.90)
    s5 = sum(1 for r in ratios if r >= 0.5) / nw
    s7 = sum(1 for r in ratios if r >= 0.7) / nw
    s9 = sum(1 for r in ratios if r >= 0.9) / nw
    return (anchor, nw, med, p75, p90, s5, s7, s9, s5 >= STOP_BINDING_SHARE)


def mfe_giveback(trades: list[Trade]) -> tuple[int, float, float, float, float, float]:
    """Symmetric MFE summary to :func:`mae_tier_b`: how much of the peak favourable
    excursion winners give back before the exit fills.

    For every winner (net > 0) carrying a positive tracked MFE, the giveback ratio is
    ``(mfe_acct - max(net, 0)) / mfe_acct`` in ``[0, 1)``: 0 means the trade exited at its
    peak, 0.5 means half the peak open profit was surrendered before the close. A high
    median giveback is the quantitative case that a trailing stop or earlier exit would
    recover open profit -- the measurement that was impossible while MFE was captured
    nowhere (Exit-Surgery Scan v2, 2026-09-13).

    Returns ``(n_winners_mfe, mfe_winner_med, giveback_med, giveback_p75, giveback_p90,
    giveback_mean)``. ``n_winners_mfe`` is 0 with all-NaN stats when no winner carries a
    positive MFE -- e.g. a legacy stream with no ``mfe_acct`` field, where every value
    defaults to 0.0, so the whole tool degrades cleanly on pre-capture history.
    """
    pairs = [(t.mfe_acct, t.net) for t in trades if t.net > 0 and t.mfe_acct > 0]
    nan = float("nan")
    if not pairs:
        return (0, nan, nan, nan, nan, nan)
    mfes = sorted(mfe for mfe, _ in pairs)
    givebacks = sorted((mfe - max(net, 0.0)) / mfe for mfe, net in pairs)
    nw = len(givebacks)
    return (
        nw,
        percentile(mfes, 0.5),
        percentile(givebacks, 0.5),
        percentile(givebacks, 0.75),
        percentile(givebacks, 0.90),
        sum(givebacks) / nw,
    )


def score_sleeve(trades: list[Trade], exit_classes: list[str] | None) -> SleeveResult | dict:
    """Compute the sleeve verdict. `exit_classes` (report out-deals) may be None."""
    n = len(trades)
    avg_hold = sum(t.hold_h for t in trades) / n if n else float("nan")
    bset = choose_bucket_set(avg_hold) if n else "medium"
    buckets = bucketize(trades, bset) if n else []

    # exit class per trade by chronological index alignment (only if counts match)
    exit_class_source = "none"
    per_trade_class: list[str] | None = None
    if exit_classes is not None and len(exit_classes) == n and n > 0:
        per_trade_class = exit_classes  # trades already sorted chronologically
        exit_class_source = "report"

    qualifying = [b for b in buckets if b.n >= MIN_BUCKET_N]

    # MAE tier-B (always computed where possible)
    (anchor, nw, med, p75, p90, s5, s7, s9, stop_binding) = mae_tier_b(trades)

    # Symmetric MFE / giveback summary (always computed where possible; degrades to n=0/NaN
    # on legacy streams that carry no mfe_acct field).
    (n_win_mfe, mfe_med, gb_med, gb_p75, gb_p90, gb_mean) = mfe_giveback(trades)

    if n < MIN_TRADES or len(qualifying) < MIN_QUALIFYING_BUCKETS:
        verdict = "NO_DATA"
        reason = (f"n_trades={n} (<{MIN_TRADES}) or qualifying_buckets="
                  f"{len(qualifying)} (<{MIN_QUALIFYING_BUCKETS})")
        wr_early = wr_late = gradient = early_net = float("nan")
        tm_share_early = float("nan")
    else:
        early = qualifying[0]
        late = qualifying[-1]
        wr_early = early.wr
        wr_late = late.wr
        gradient = wr_late - wr_early
        early_net = early.net
        late_net = late.net

        # TIME_MGMT share of early exits
        tm_share_early = float("nan")
        if per_trade_class is not None:
            lo = next(lo for lbl, lo, hi in BUCKET_SETS[bset] if lbl == early.label)
            hi = next(hi for lbl, lo2, hi in BUCKET_SETS[bset] if lbl == early.label)
            idx = [i for i, t in enumerate(trades) if lo <= t.hold_h < hi]
            if idx:
                tm = sum(1 for i in idx if per_trade_class[i] == "TIME_MGMT")
                tm_share_early = tm / len(idx)

        if early_net < 0 and wr_early < WR_EARLY_MAX and gradient > GRADIENT_HIGH_PP and late_net > 0:
            verdict = "HIGH"
            reason = (f"early '{early.label}' net={early_net:.0f} wr={wr_early:.0f}% -> "
                      f"late '{late.label}' net={late_net:.0f} wr={wr_late:.0f}%; "
                      f"gradient={gradient:.0f}pp")
        elif gradient > GRADIENT_WEAK_PP:
            verdict = "WEAK"
            reason = (f"positive but ambiguous slope: gradient={gradient:.0f}pp "
                      f"(early_net={early_net:.0f}, late_net={late_net:.0f})")
        else:
            verdict = "NO_CASE"
            reason = (f"flat/negative gradient={gradient:.0f}pp "
                      f"(later holds not better; exits not the culprit)")

    return SleeveResult(
        ea_id=0, symbol="", n_trades=n, avg_hold_h=avg_hold, bucket_set=bset,
        buckets=buckets, wr_early=wr_early, wr_late=wr_late, gradient_pp=gradient,
        early_net=early_net, time_mgmt_share_early=tm_share_early,
        exit_class_source=exit_class_source, mae_winner_med=med, mae_winner_p75=p75,
        mae_winner_p90=p90, mae_anchor=anchor, n_winners=nw, share_ge_0_5=s5,
        share_ge_0_7=s7, share_ge_0_9=s9, stop_binding=stop_binding,
        verdict=verdict, reason=reason,
        n_winners_mfe=n_win_mfe, mfe_winner_med=mfe_med, giveback_med=gb_med,
        giveback_p75=gb_p75, giveback_p90=gb_p90, giveback_mean=gb_mean,
    )


def load_bundle(roots: list[Path]) -> dict | None:
    for root in roots:
        cand = root / "bundle_manifest.json"
        if cand.exists():
            try:
                return json.loads(cand.read_text(encoding="utf-8"))
            except (OSError, json.JSONDecodeError):
                return None
    return None


def _fmt(x: float, nd: int = 4) -> str:
    if x is None or (isinstance(x, float) and math.isnan(x)):
        return ""
    return f"{round(x, nd)}"


def run_scan(roster_path: Path, stream_roots: list[Path], db_path: str, out_dir: Path) -> dict:
    roster = json.loads(roster_path.read_text(encoding="utf-8"))
    sleeves = roster.get("selected_book") or roster.get("sleeves") or []
    roster_sha = roster.get("selected_book_roster_sha256")

    # search order: explicit --stream-root(s) first, else roster-declared roots
    if not stream_roots:
        stream_roots = []
        for key in ("stream_root", "incumbent_stream_root"):
            if roster.get(key):
                stream_roots.append(Path(roster[key]))

    bundle = load_bundle(stream_roots)

    results: list[SleeveResult] = []
    missing: list[str] = []
    used_streams: dict[str, str] = {}
    used_reports: dict[str, str] = {}

    ordered = sorted(sleeves, key=lambda r: (int(r["ea_id"]), str(r["symbol"])))
    for row in ordered:
        ea_id = int(row["ea_id"])
        symbol = str(row["symbol"])
        key = f"{ea_id}:{symbol}"
        stream = find_stream(stream_roots, ea_id, symbol)
        if stream is None:
            missing.append(key)
            res = SleeveResult(
                ea_id=ea_id, symbol=symbol, n_trades=0, avg_hold_h=float("nan"),
                bucket_set="", buckets=[], wr_early=float("nan"), wr_late=float("nan"),
                gradient_pp=float("nan"), early_net=float("nan"),
                time_mgmt_share_early=float("nan"), exit_class_source="none",
                mae_winner_med=float("nan"), mae_winner_p75=float("nan"),
                mae_winner_p90=float("nan"), mae_anchor=float("nan"), n_winners=0,
                share_ge_0_5=float("nan"), share_ge_0_7=float("nan"),
                share_ge_0_9=float("nan"), stop_binding=False,
                verdict="NO_STREAM", reason="stream file not found in any stream root",
            )
            results.append(res)
            continue

        used_streams[key] = sha256_file(stream)
        trades = load_trades(stream)

        report_path = resolve_report_path(ea_id, symbol, bundle, db_path)
        exit_classes = None
        if report_path is not None:
            exit_classes = parse_report_exit_classes(report_path)
            rp = report_path if report_path.exists() else Path(str(report_path) + ".gz")
            if rp.exists():
                used_reports[key] = sha256_file(rp)

        res = score_sleeve(trades, exit_classes)
        res.ea_id = ea_id
        res.symbol = symbol
        results.append(res)

    out_dir.mkdir(parents=True, exist_ok=True)
    _write_sleeve_summary(out_dir / "sleeve_summary.csv", results)
    _write_hold_buckets(out_dir / "hold_buckets.csv", results)
    _write_mae_winners(out_dir / "mae_winners.csv", results)
    _write_mfe_winners(out_dir / "mfe_winners.csv", results)

    manifest = {
        "schema": "qm.exit-surgery-scan-v2/manifest/v1",
        "tool": "tools/strategy_farm/research/exit_surgery_scan_v2.py",
        "roster_path": str(roster_path),
        "roster_sha256_declared": roster_sha,
        "roster_file_sha256": sha256_file(roster_path),
        "db_path": db_path,
        "stream_roots": [str(r) for r in stream_roots],
        "n_sleeves": len(results),
        "n_missing_streams": len(missing),
        "missing_streams": missing,
        "verdict_counts": _verdict_counts(results),
        "input_stream_sha256": used_streams,
        "input_report_sha256": used_reports,
        "params": {
            "min_trades": MIN_TRADES, "min_bucket_n": MIN_BUCKET_N,
            "min_qualifying_buckets": MIN_QUALIFYING_BUCKETS,
            "gradient_high_pp": GRADIENT_HIGH_PP, "gradient_weak_pp": GRADIENT_WEAK_PP,
            "wr_early_max": WR_EARLY_MAX, "stop_binding_share": STOP_BINDING_SHARE,
        },
    }
    (out_dir / "manifest.json").write_text(
        json.dumps(manifest, indent=2, sort_keys=True) + "\n", encoding="utf-8")
    return manifest


def _verdict_counts(results: list[SleeveResult]) -> dict:
    counts: dict[str, int] = {}
    for r in results:
        counts[r.verdict] = counts.get(r.verdict, 0) + 1
    return dict(sorted(counts.items()))


def _write_sleeve_summary(path: Path, results: list[SleeveResult]) -> None:
    cols = ["ea_id", "symbol", "n_trades", "avg_hold_h", "bucket_set", "wr_early",
            "wr_late", "gradient_pp", "early_net", "time_mgmt_share_early",
            "exit_class_source", "mae_winner_med", "mae_winner_p75", "mae_winner_p90",
            "share_ge_0_5", "stop_binding", "verdict", "reason"]
    with open(path, "w", newline="", encoding="utf-8") as fh:
        w = csv.writer(fh)
        w.writerow(cols)
        for r in results:
            w.writerow([
                r.ea_id, r.symbol, r.n_trades, _fmt(r.avg_hold_h, 2), r.bucket_set,
                _fmt(r.wr_early, 1), _fmt(r.wr_late, 1), _fmt(r.gradient_pp, 1),
                _fmt(r.early_net, 2), _fmt(r.time_mgmt_share_early, 4),
                r.exit_class_source, _fmt(r.mae_winner_med, 4), _fmt(r.mae_winner_p75, 4),
                _fmt(r.mae_winner_p90, 4), _fmt(r.share_ge_0_5, 4),
                str(r.stop_binding).lower(), r.verdict, r.reason,
            ])


def _write_hold_buckets(path: Path, results: list[SleeveResult]) -> None:
    with open(path, "w", newline="", encoding="utf-8") as fh:
        w = csv.writer(fh)
        w.writerow(["ea_id", "symbol", "bucket_set", "bucket", "n", "wr", "net", "avg_net"])
        for r in results:
            for b in r.buckets:
                w.writerow([r.ea_id, r.symbol, r.bucket_set, b.label, b.n,
                            _fmt(b.wr, 1), _fmt(b.net, 2), _fmt(b.avg_net, 2)])


def _write_mae_winners(path: Path, results: list[SleeveResult]) -> None:
    with open(path, "w", newline="", encoding="utf-8") as fh:
        w = csv.writer(fh)
        w.writerow(["ea_id", "symbol", "n_winners", "anchor", "med", "p75", "p90",
                    "share_ge_0_5", "share_ge_0_7", "share_ge_0_9", "stop_binding"])
        for r in results:
            w.writerow([r.ea_id, r.symbol, r.n_winners, _fmt(r.mae_anchor, 4),
                        _fmt(r.mae_winner_med, 4), _fmt(r.mae_winner_p75, 4),
                        _fmt(r.mae_winner_p90, 4), _fmt(r.share_ge_0_5, 4),
                        _fmt(r.share_ge_0_7, 4), _fmt(r.share_ge_0_9, 4),
                        str(r.stop_binding).lower()])


def _write_mfe_winners(path: Path, results: list[SleeveResult]) -> None:
    """Symmetric to _write_mae_winners: winners' MFE + giveback-ratio distribution."""
    with open(path, "w", newline="", encoding="utf-8") as fh:
        w = csv.writer(fh)
        w.writerow(["ea_id", "symbol", "n_winners_mfe", "mfe_winner_med", "giveback_med",
                    "giveback_p75", "giveback_p90", "giveback_mean"])
        for r in results:
            w.writerow([r.ea_id, r.symbol, r.n_winners_mfe, _fmt(r.mfe_winner_med, 4),
                        _fmt(r.giveback_med, 4), _fmt(r.giveback_p75, 4),
                        _fmt(r.giveback_p90, 4), _fmt(r.giveback_mean, 4)])


def build_arg_parser() -> argparse.ArgumentParser:
    p = argparse.ArgumentParser(description="Exit-Surgery Scan v2 (deterministic).")
    p.add_argument("--roster", required=True, type=Path)
    p.add_argument("--stream-root", action="append", default=[], type=Path,
                   help="Repeatable. Search order = given order. "
                        "Falls back to roster stream_root then incumbent_stream_root.")
    p.add_argument("--db", default=DEFAULT_DB, help="farm_state.sqlite (opened read-only).")
    p.add_argument("--out-dir", required=True, type=Path)
    return p


def main(argv: list[str] | None = None) -> int:
    args = build_arg_parser().parse_args(argv)
    manifest = run_scan(args.roster, list(args.stream_root), args.db, args.out_dir)
    print(json.dumps({
        "n_sleeves": manifest["n_sleeves"],
        "verdict_counts": manifest["verdict_counts"],
        "n_missing_streams": manifest["n_missing_streams"],
        "out_dir": str(args.out_dir),
    }, indent=2))
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
