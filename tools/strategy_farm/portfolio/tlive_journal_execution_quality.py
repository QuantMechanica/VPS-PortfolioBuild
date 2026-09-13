"""Read-only live execution-quality measurement for the T_Live terminal.

Parses the Darwinex-Zero live MT5 terminal journals (broker-time, account
4000090541), joins each executed deal (fill) to the order that produced it,
and — for pending (stop/limit) orders whose trigger price is logged — computes
adverse slippage in price points.  Market orders carry no requested/quoted
price in the MT5 journal, so their slippage is NOT measurable and they are
reported as fills-without-reference (documented limitation).

Sleeve (EA) attribution joins the journal order id to the EA JSON logs'
``TM_OPEN`` ticket; unattributed fills fall back to symbol-only and are marked.

The module is strictly read-only: it opens the terminal journals and EA logs
for reading only, never uses the MetaTrader5 API, never starts a terminal, and
writes exclusively under the caller-provided --out-dir.

Grammar matched (message body, after the ``'<account>':`` prefix):

  order done (carries reference price for pending orders + placement latency):
    order #<id> <buy|sell>[ <stop|limit>] <vol> / <vol> <SYMBOL> at <price|market> done in <ms> ms

  deal / fill (join key: based on order #<id>):
    deal #<id> <buy|sell> <vol> <SYMBOL> at <price> done (based on order #<id>)

  cancel completed (pending order withdrawn, never filled):
    cancel #<id> <buy|sell>[ <stop|limit>] <vol> <SYMBOL> at market done in <ms> ms

  rejection / failure (bracketed reason):
    failed <market buy|market sell|modify|cancel order|cancel> ... [<reason>]

No ``requote`` / ``off quotes`` / ``rejected`` phrasings occur in these journals
(verified across the corpus); the rejection statistics therefore consist of the
``failed ... [reason]`` lines and completed cancels.
"""

from __future__ import annotations

import argparse
import csv
import datetime as dt
import hashlib
import json
import math
import os
import re
from collections import defaultdict
from decimal import Decimal
from pathlib import Path
from typing import Optional

# House minimum-sample rule, mirrored from build_slippage_ledger_v2.py.
MINIMUM_SAMPLES_PER_SYMBOL = 30

ACCOUNT = "4000090541"
NUM = r"[-+]?(?:\d+(?:\.\d*)?|\.\d+)"

ORDER_DONE_RE = re.compile(
    rf"order\s+#(?P<order>\d+)\s+(?P<side>buy|sell)(?:\s+(?P<ptype>stop|limit))?\s+"
    rf"(?P<vol>{NUM})\s*/\s*{NUM}\s+(?P<symbol>\S+)\s+at\s+"
    rf"(?P<price>market|{NUM})\s+done\s+in\s+(?P<lat>{NUM})\s+ms",
    re.IGNORECASE,
)
DEAL_RE = re.compile(
    rf"deal\s+#(?P<deal>\d+)\s+(?P<side>buy|sell)\s+(?P<vol>{NUM})\s+"
    rf"(?P<symbol>\S+)\s+at\s+(?P<price>{NUM})\s+done\s+"
    rf"\(based on order\s+#(?P<order>\d+)\)",
    re.IGNORECASE,
)
CANCEL_DONE_RE = re.compile(
    rf"cancel\s+#(?P<order>\d+)\s+(?P<side>buy|sell)(?:\s+(?P<ptype>stop|limit))?\s+"
    rf"{NUM}\s+(?P<symbol>\S+)\s+at\s+market\s+done\s+in\s+{NUM}\s+ms",
    re.IGNORECASE,
)
FAILED_RE = re.compile(
    r"failed\s+(?P<what>market buy|market sell|modify|cancel order|cancel)\b"
    r".*?\[(?P<reason>[^\]]+)\]",
    re.IGNORECASE,
)
ORDER_ID_RE = re.compile(r"#(?P<id>\d+)")
SYMBOL_TOKEN_RE = re.compile(r"\b([A-Z][A-Z0-9]{2,15})\b")


def sha256(path: Path) -> str:
    h = hashlib.sha256()
    with open(path, "rb") as fh:
        for chunk in iter(lambda: fh.read(1 << 20), b""):
            h.update(chunk)
    return h.hexdigest()


def decode_bytes(raw: bytes) -> str:
    """Decode by BOM: UTF-16 LE/BE, UTF-8-SIG, else UTF-8."""
    if raw[:2] == b"\xff\xfe":
        return raw.decode("utf-16-le", errors="replace")
    if raw[:2] == b"\xfe\xff":
        return raw.decode("utf-16-be", errors="replace")
    if raw[:3] == b"\xef\xbb\xbf":
        return raw.decode("utf-8-sig", errors="replace")
    return raw.decode("utf-8", errors="replace")


def read_text(path: Path) -> str:
    return decode_bytes(path.read_bytes())


def parse_broker_ts(datestr: str, hms: str) -> str:
    """datestr=YYYYMMDD ; hms=HH:MM:SS.mmm -> ISO broker-time string."""
    try:
        d = dt.datetime.strptime(datestr, "%Y%m%d").date()
        t = hms.strip()
        return f"{d.isoformat()}T{t}"
    except ValueError:
        return f"{datestr}T{hms}"


def _decimals(price_str: str) -> int:
    if "." in price_str:
        return len(price_str.split(".", 1)[1].rstrip())
    return 0


def parse_journal_dir(journal_dir: Path, since: Optional[str]):
    """Return (orders, deals, cancels, rejections, files, symbol_decimals)."""
    orders: dict[str, dict] = {}
    deals: list[dict] = []
    cancels: list[dict] = []
    rejections: list[dict] = []
    files: list[Path] = []
    symbol_decimals: dict[str, int] = defaultdict(int)

    for path in sorted(journal_dir.glob("2026*.log")):
        datestr = path.stem
        if since and datestr < since:
            continue
        files.append(path)
        for line in read_text(path).splitlines():
            parts = line.split("\t")
            if len(parts) < 5 or parts[3] != "Trades":
                continue
            hms = parts[2]
            body = "\t".join(parts[4:])
            if ACCOUNT not in body:
                continue
            ts = parse_broker_ts(datestr, hms)

            m = ORDER_DONE_RE.search(body)
            if m:
                sym = m.group("symbol")
                price = m.group("price")
                is_market = price.lower() == "market"
                if not is_market:
                    symbol_decimals[sym] = max(symbol_decimals[sym], _decimals(price))
                orders[m.group("order")] = {
                    "order_id": m.group("order"),
                    "ts_broker": ts,
                    "side": m.group("side").lower(),
                    "order_type": (m.group("ptype") or "market").lower(),
                    "volume": m.group("vol"),
                    "symbol": sym,
                    "ref_price": ("" if is_market else price),
                    "latency_ms": m.group("lat"),
                }
                continue

            m = DEAL_RE.search(body)
            if m:
                sym = m.group("symbol")
                symbol_decimals[sym] = max(symbol_decimals[sym], _decimals(m.group("price")))
                deals.append({
                    "deal_id": m.group("deal"),
                    "ts_broker": ts,
                    "side": m.group("side").lower(),
                    "volume": m.group("vol"),
                    "symbol": sym,
                    "fill_price": m.group("price"),
                    "order_id": m.group("order"),
                })
                continue

            m = CANCEL_DONE_RE.search(body)
            if m:
                cancels.append({
                    "ts_broker": ts,
                    "order_id": m.group("order"),
                    "side": m.group("side").lower(),
                    "symbol": m.group("symbol"),
                    "kind": "cancel_completed",
                    "reason": "",
                    "raw": body.strip(),
                })
                continue

            m = FAILED_RE.search(body)
            if m:
                oid = ""
                om = ORDER_ID_RE.search(body)
                if om:
                    oid = om.group("id")
                sym = ""
                sm = SYMBOL_TOKEN_RE.search(body.split("[", 1)[0])
                # skip the leading verb tokens; look for an uppercase symbol token
                for cand in SYMBOL_TOKEN_RE.findall(body.split("[", 1)[0]):
                    if cand not in ("USD",):
                        sym = cand
                        break
                rejections.append({
                    "ts_broker": ts,
                    "order_id": oid,
                    "side": "",
                    "symbol": sym,
                    "kind": "failed_" + m.group("what").lower().replace(" ", "_"),
                    "reason": m.group("reason"),
                    "raw": body.strip(),
                })
                continue

    return orders, deals, cancels, rejections, files, dict(symbol_decimals)


def load_sleeve_index(ea_log_dir: Path):
    """Map order/ticket id -> ea_id from TM_OPEN payloads (ok fills)."""
    ticket_to_ea: dict[str, int] = {}
    files: list[Path] = []
    if not ea_log_dir or not ea_log_dir.exists():
        return ticket_to_ea, files
    for path in sorted(ea_log_dir.glob("QM5_*_ea-*.log")):
        files.append(path)
        for line in read_text(path).splitlines():
            line = line.strip()
            if "TM_OPEN" not in line:
                continue
            try:
                rec = json.loads(line)
            except json.JSONDecodeError:
                continue
            payload = rec.get("payload") or {}
            ticket = payload.get("ticket")
            ea_id = rec.get("ea_id")
            if ticket and ea_id and payload.get("ok"):
                ticket_to_ea[str(ticket)] = int(ea_id)
    return ticket_to_ea, files


def load_backtest_reference(stream_root: Path):
    """Per ea_id: mean |net| and mean gross per backtest trade from Q08 streams."""
    ref: dict[int, dict] = {}
    files: list[Path] = []
    if not stream_root or not stream_root.exists():
        return ref, files
    agg: dict[int, dict] = defaultdict(lambda: {"abs_net": 0.0, "gross": 0.0, "n": 0})
    for path in sorted(stream_root.glob("*.jsonl")):
        files.append(path)
        ea_id = None
        try:
            ea_id = int(path.stem.split("_", 1)[0])
        except ValueError:
            continue
        for line in read_text(path).splitlines():
            line = line.strip()
            if not line:
                continue
            try:
                rec = json.loads(line)
            except json.JSONDecodeError:
                continue
            net = rec.get("net")
            if net is None:
                continue
            comm = (rec.get("entry_commission") or 0.0) + (rec.get("exit_commission") or 0.0)
            swap = rec.get("swap") or 0.0
            # gross = raw price P&L before financing/commission costs
            gross = float(net) + float(comm) - float(swap)
            a = agg[ea_id]
            a["abs_net"] += abs(float(net))
            a["gross"] += abs(gross)
            a["n"] += 1
    for ea_id, a in agg.items():
        if a["n"]:
            ref[ea_id] = {
                "bt_n_trades": a["n"],
                "bt_mean_abs_net": a["abs_net"] / a["n"],
                "bt_mean_abs_gross": a["gross"] / a["n"],
            }
    return ref, files


def p95_nearest_rank(values: list[float]) -> Optional[float]:
    """95th percentile, nearest-rank ceil, no interpolation (mirrors v2)."""
    if not values:
        return None
    s = sorted(values)
    rank = math.ceil(Decimal("0.95") * len(s))
    rank = max(1, min(rank, len(s)))
    return s[rank - 1]


def _mean(vals):
    return sum(vals) / len(vals) if vals else None


def _median(vals):
    if not vals:
        return None
    s = sorted(vals)
    n = len(s)
    mid = n // 2
    return s[mid] if n % 2 else (s[mid - 1] + s[mid]) / 2.0


def build_fills(orders, deals, ticket_to_ea, symbol_point, tick_values):
    """One row per deal, joined to its order; slippage for pending orders only."""
    fills = []
    unmatched = 0
    matched_pending = 0
    matched_market = 0
    for d in deals:
        oid = d["order_id"]
        o = orders.get(oid)
        sym = d["symbol"]
        point = symbol_point.get(sym)
        ea_id = ticket_to_ea.get(oid)
        matched = o is not None
        ref_price = o["ref_price"] if o else ""
        order_type = o["order_type"] if o else ""
        latency = o["latency_ms"] if o else ""
        slip_points = ""
        money = ""
        tick_val = tick_values.get(sym) if tick_values else None
        tick_src = ""
        if matched and ref_price not in ("", None) and point:
            F = float(d["fill_price"])
            P = float(ref_price)
            if d["side"] == "buy":
                slip = (F - P) / point
            else:
                slip = (P - F) / point
            slip_points = slip
            matched_pending += 1
            if tick_val is not None:
                money = slip * tick_val * float(d["volume"])
                tick_src = "tick_value_override_json"
        elif matched and (ref_price in ("", None)):
            matched_market += 1
        else:
            unmatched += 1
        fills.append({
            "deal_id": d["deal_id"],
            "ts_broker": d["ts_broker"],
            "symbol": sym,
            "side": d["side"],
            "volume": d["volume"],
            "fill_price": d["fill_price"],
            "order_id": oid,
            "order_type": order_type,
            "ref_price": ref_price,
            "point": ("" if point is None else point),
            "point_source": ("inferred_from_price_decimals" if point else ""),
            "slippage_points": slip_points,
            "latency_ms": latency,
            "money_impact": money,
            "tick_value_source": tick_src,
            "ea_id": ("" if ea_id is None else ea_id),
            "sleeve_attribution": ("ticket_join" if ea_id is not None else "symbol_only"),
            "matched_order": matched,
            "slippage_eligible": bool(slip_points != ""),
        })
    coverage = {
        "deal_lines": len(deals),
        "matched_pending_with_ref": matched_pending,
        "matched_market_no_ref": matched_market,
        "unmatched_deal_lines": unmatched,
    }
    return fills, coverage


def _agg_rows(fills, rejections, key_fn, bt_ref_by_key):
    """Aggregate fills/rejections into grouped stat rows."""
    groups = defaultdict(list)
    for f in fills:
        groups[key_fn(f)].append(f)
    rej_counts = defaultdict(int)
    for r in rejections:
        rej_counts[r.get("_group", "")] += 1
    rows = []
    for key in sorted(groups, key=lambda k: str(k)):
        gf = groups[key]
        # slippage sample unit = filled pending order (dedup partial fills, vol-weighted)
        by_order = defaultdict(list)
        for f in gf:
            if f["slippage_eligible"]:
                by_order[f["order_id"]].append(f)
        slips = []
        latencies = []
        zero = 0
        for oid, dl in by_order.items():
            tot_vol = sum(float(x["volume"]) for x in dl)
            if tot_vol <= 0:
                continue
            vw_slip = sum(float(x["slippage_points"]) * float(x["volume"]) for x in dl) / tot_vol
            slips.append(vw_slip)
            if abs(vw_slip) < 1e-12:
                zero += 1
            if dl[0]["latency_ms"] != "":
                latencies.append(float(dl[0]["latency_ms"]))
        n_slip = len(slips)
        bt = bt_ref_by_key.get(key, {})
        row = {
            "group": key,
            "n_fills": len(gf),
            "n_orders_filled": len({f["order_id"] for f in gf if f["matched_order"]}),
            "n_slippage_samples": n_slip,
            "mean_adverse_points": _mean(slips),
            "median_adverse_points": _median(slips),
            "p95_adverse_points": p95_nearest_rank(slips),
            "share_zero_slippage": (zero / n_slip if n_slip else None),
            "mean_latency_ms": _mean(latencies),
            "rejections": rej_counts.get(key, 0),
            "bt_mean_abs_net_per_trade": bt.get("bt_mean_abs_net"),
            "execution_drag": "NOT_COMPUTABLE_NO_TICK_VALUE",
            "power": ("OK" if n_slip >= MINIMUM_SAMPLES_PER_SYMBOL else "UNDERPOWERED"),
        }
        rows.append(row)
    return rows


def write_csv(path: Path, rows: list[dict], fields: list[str]):
    with open(path, "w", newline="", encoding="utf-8") as fh:
        w = csv.DictWriter(fh, fieldnames=fields)
        w.writeheader()
        for r in rows:
            w.writerow({k: r.get(k, "") for k in fields})


def main(argv=None):
    ap = argparse.ArgumentParser(description=__doc__)
    ap.add_argument("--journal-dir", required=True)
    ap.add_argument("--ea-log-dir", default="")
    ap.add_argument("--stream-root", default="")
    ap.add_argument("--out-dir", required=True)
    ap.add_argument("--since", default="", help="YYYYMMDD inclusive lower bound")
    ap.add_argument("--tick-value-json", default="",
                    help="Optional JSON {symbol: usd_per_point_per_lot}; enables money impact. "
                         "Default: none -> slippage reported in POINTS only.")
    args = ap.parse_args(argv)

    journal_dir = Path(args.journal_dir)
    ea_log_dir = Path(args.ea_log_dir) if args.ea_log_dir else None
    stream_root = Path(args.stream_root) if args.stream_root else None
    out_dir = Path(args.out_dir)
    out_dir.mkdir(parents=True, exist_ok=True)
    since = args.since or None

    tick_values = {}
    if args.tick_value_json and Path(args.tick_value_json).exists():
        tick_values = json.loads(Path(args.tick_value_json).read_text(encoding="utf-8"))

    orders, deals, cancels, rejections, jfiles, sym_dec = parse_journal_dir(journal_dir, since)
    symbol_point = {s: 10 ** (-dec) for s, dec in sym_dec.items()}
    ticket_to_ea, eafiles = load_sleeve_index(ea_log_dir) if ea_log_dir else ({}, [])
    bt_ref, sfiles = load_backtest_reference(stream_root) if stream_root else ({}, [])

    fills, coverage = build_fills(orders, deals, ticket_to_ea, symbol_point, tick_values)

    # attach group keys to rejections for per-group counts
    ea_by_symbol = defaultdict(set)
    for f in fills:
        if f["ea_id"] != "":
            ea_by_symbol[f["symbol"]].add(f["ea_id"])

    def sym_key(f):
        return f["symbol"]

    def sleeve_key(f):
        if f["ea_id"] != "":
            return f"{f['ea_id']}"
        return f"UNATTRIBUTED_{f['symbol']}"

    for r in rejections:
        r_sym = r.get("symbol", "")
        r["_group_symbol"] = r_sym
        oid = r.get("order_id", "")
        ea = ticket_to_ea.get(oid)
        r["_group_sleeve"] = str(ea) if ea is not None else (f"UNATTRIBUTED_{r_sym}" if r_sym else "")

    # by symbol
    for r in rejections:
        r["_group"] = r["_group_symbol"]
    bt_by_symbol = {}
    by_symbol = _agg_rows(fills, rejections, sym_key, bt_by_symbol)

    # by sleeve
    for r in rejections:
        r["_group"] = r["_group_sleeve"]
    bt_by_sleeve = {}
    for f in fills:
        if f["ea_id"] != "":
            k = str(f["ea_id"])
            if int(f["ea_id"]) in bt_ref:
                bt_by_sleeve[k] = bt_ref[int(f["ea_id"])]
    by_sleeve = _agg_rows(fills, rejections, sleeve_key, bt_by_sleeve)

    fill_fields = ["deal_id", "ts_broker", "symbol", "side", "volume", "fill_price",
                   "order_id", "order_type", "ref_price", "point", "point_source",
                   "slippage_points", "latency_ms", "money_impact", "tick_value_source",
                   "ea_id", "sleeve_attribution", "matched_order", "slippage_eligible"]
    order_fields = ["order_id", "ts_broker", "side", "order_type", "volume", "symbol",
                    "ref_price", "latency_ms"]
    rej_fields = ["ts_broker", "kind", "order_id", "symbol", "reason", "raw"]
    agg_fields = ["group", "n_fills", "n_orders_filled", "n_slippage_samples",
                  "mean_adverse_points", "median_adverse_points", "p95_adverse_points",
                  "share_zero_slippage", "mean_latency_ms", "rejections",
                  "bt_mean_abs_net_per_trade", "execution_drag", "power"]

    write_csv(out_dir / "fills.csv", fills, fill_fields)
    write_csv(out_dir / "orders.csv", list(orders.values()), order_fields)
    write_csv(out_dir / "rejections.csv", rejections + cancels, rej_fields)
    write_csv(out_dir / "by_symbol.csv", by_symbol, agg_fields)
    write_csv(out_dir / "by_sleeve.csv", by_sleeve, agg_fields)

    manifest = {
        "artifact": "TLIVE_JOURNAL_EXECUTION_QUALITY",
        "account": ACCOUNT,
        "generated_utc": dt.datetime.now(dt.timezone.utc).isoformat(),
        "since": since,
        "read_only": True,
        "money_impact_computable": bool(tick_values),
        "minimum_samples_per_symbol": MINIMUM_SAMPLES_PER_SYMBOL,
        "symbol_point_sizes": symbol_point,
        "symbol_point_source": "inferred_from_price_decimals",
        "counts": {
            "journal_files": len(jfiles),
            "ea_log_files": len(eafiles),
            "stream_files": len(sfiles),
            "orders_done": len(orders),
            "deal_lines": len(deals),
            "cancels_completed": len(cancels),
            "failed_lines": len(rejections),
            "sleeve_ticket_joins": len(ticket_to_ea),
        },
        "parse_coverage": coverage,
        "inputs": {
            "journals": {p.name: {"sha256": sha256(p), "bytes": p.stat().st_size}
                         for p in jfiles},
            "ea_logs": {p.name: {"sha256": sha256(p), "bytes": p.stat().st_size}
                        for p in eafiles},
            "streams": {p.name: {"sha256": sha256(p), "bytes": p.stat().st_size}
                        for p in sfiles},
        },
    }
    (out_dir / "manifest.json").write_text(
        json.dumps(manifest, indent=1, default=str), encoding="utf-8")

    print(json.dumps({
        "orders_done": len(orders),
        "deal_lines": len(deals),
        "coverage": coverage,
        "by_symbol": len(by_symbol),
        "by_sleeve": len(by_sleeve),
        "out_dir": str(out_dir),
    }, indent=1))
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
