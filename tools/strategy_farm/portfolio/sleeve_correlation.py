"""Are our swap-immune sleeves actually uncorrelated?

The decisive question, never measured. The whole path to a viable book runs
through it:

  - individually the sleeves are slow (0.7-2.6 %/yr) and cannot be scaled, since
    each carries 2-8 % drawdown against a 10 % cap;
  - but N *uncorrelated* sleeves give book drawdown ~ d/sqrt(N), permitting
    scaling by sqrt(N), which multiplies the return;
  - at ~10 uncorrelated sleeves the same material reaches ~1 %/month, which is
    where a funded account and a challenge attempt both become worth having.

If instead they are highly correlated — all long the same index drift, all firing
on the same sessions — stacking adds exposure, not diversification, and no book
construction helps.

Method: daily P&L series per sleeve from its trade stream, aligned on common
dates. Overlap is reported alongside, because sleeves that never trade the same
days cannot be combined meaningfully either.
"""
import json
import math
import sqlite3
from collections import defaultdict
from datetime import datetime, timezone
from pathlib import Path

STREAMS = Path(r"D:\QM\reports\portfolio\sleeve_streams\QM\q08_trades")
PNL_KEYS = ("net", "profit_acct", "net_acct", "pnl_acct", "profit")
MIN_TRADES = 50
MAX_OVERNIGHT = 5.0

con = sqlite3.connect(r"file:D:/QM/strategy_farm/state/farm_state.sqlite?mode=ro", uri=True)
con.row_factory = sqlite3.Row
verdicts = {}
for r in con.execute(
    "select ea_id, symbol, phase, verdict from work_items "
    "where phase in ('Q05','Q08') and status='done' order by updated_at"
):
    verdicts[(r["ea_id"], str(r["symbol"]).upper(), r["phase"])] = str(r["verdict"])


def parse_ts(v):
    if v is None:
        return None
    if isinstance(v, (int, float)):
        try:
            return datetime.fromtimestamp(float(v), tz=timezone.utc)
        except Exception:
            return None
    t = str(v).strip()
    try:
        return datetime.fromisoformat(t.replace("Z", "+00:00"))
    except ValueError:
        pass
    for f in ("%Y.%m.%d %H:%M:%S", "%Y-%m-%d %H:%M:%S", "%Y.%m.%d %H:%M"):
        try:
            return datetime.strptime(t[:19], f)
        except ValueError:
            continue
    return None


series = {}
for path in sorted(STREAMS.glob("*.jsonl")):
    bare, _, stem = path.stem.partition("_")
    ea = f"QM5_{bare}"
    sym_full = stem.replace("_DWX", ".DWX").upper()
    if verdicts.get((ea, sym_full, "Q05")) in ("FAIL", "FAIL_HARD"):
        continue
    if verdicts.get((ea, sym_full, "Q08")) in ("FAIL", "FAIL_HARD"):
        continue

    daily = defaultdict(float)
    n = overnight = 0
    try:
        with path.open(encoding="utf-8", errors="replace") as fh:
            for line in fh:
                line = line.strip()
                if not line:
                    continue
                try:
                    row = json.loads(line)
                except json.JSONDecodeError:
                    continue
                if str(row.get("event") or "TRADE_CLOSED") != "TRADE_CLOSED":
                    continue
                pnl = None
                for k in PNL_KEYS:
                    if k in row:
                        try:
                            pnl = float(row[k])
                        except (TypeError, ValueError):
                            pnl = None
                        break
                close = parse_ts(row.get("time"))
                entry = parse_ts(row.get("entry_time"))
                if pnl is None or close is None:
                    continue
                n += 1
                daily[close.date()] += pnl
                if entry and entry.date() != close.date():
                    overnight += 1
    except OSError:
        continue
    if n < MIN_TRADES or 100.0 * overnight / max(n, 1) > MAX_OVERNIGHT:
        continue
    series[f"{bare}:{sym_full.replace('.DWX','')}"] = daily

print(f"swap-immune sleeves with >={MIN_TRADES} trades: {len(series)}")
for k, v in sorted(series.items()):
    print(f"  {k:20} trading days: {len(v)}")
print()


def corr(a, b):
    common = sorted(set(a) & set(b))
    if len(common) < 30:
        return float("nan"), len(common)
    xs = [a[d] for d in common]
    ys = [b[d] for d in common]
    mx = sum(xs) / len(xs)
    my = sum(ys) / len(ys)
    sxy = sum((x - mx) * (y - my) for x, y in zip(xs, ys))
    sxx = sum((x - mx) ** 2 for x in xs)
    syy = sum((y - my) ** 2 for y in ys)
    if sxx <= 0 or syy <= 0:
        return float("nan"), len(common)
    return sxy / math.sqrt(sxx * syy), len(common)


keys = sorted(series)
pairs = []
for i, ka in enumerate(keys):
    for kb in keys[i + 1:]:
        c, overlap = corr(series[ka], series[kb])
        if not math.isnan(c):
            pairs.append((abs(c), c, ka, kb, overlap))

pairs.sort(reverse=True)
print(f"comparable pairs (>=30 shared trading days): {len(pairs)}")
if pairs:
    vals = [p[1] for p in pairs]
    print(f"mean |corr|      : {sum(abs(v) for v in vals)/len(vals):.3f}")
    print(f"max  |corr|      : {max(abs(v) for v in vals):.3f}")
    print(f"pairs above 0.30 : {sum(1 for v in vals if abs(v) > 0.30)}")
    print(f"pairs below 0.10 : {sum(1 for v in vals if abs(v) < 0.10)}")
    print()
    print("most correlated:")
    for a, c, ka, kb, ov in pairs[:6]:
        print(f"  {ka:18} {kb:18} corr {c:+.3f}  ({ov} shared days)")
    print()
    print("least correlated:")
    for a, c, ka, kb, ov in pairs[-6:]:
        print(f"  {ka:18} {kb:18} corr {c:+.3f}  ({ov} shared days)")
