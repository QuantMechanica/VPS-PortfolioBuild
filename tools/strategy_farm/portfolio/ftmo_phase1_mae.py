"""FTMO Phase-1 pass/fail probability with intraday-DD (MAE) reconstruction.

The closed-daily prop_challenge_sim can't model the 5%/day + 10%/max limits because
those are INTRADAY equity events (docs: q08-stream reimpl was 4.5x off). This tool
uses the fresh-format q08 streams that carry, per trade, entry_time + mae_acct
(worst floating loss in account currency) and reconstructs a CONSERVATIVE intraday
worst-equity path:

  - each trade is "open" over [entry_day, close_day]; its worst floating = mae_acct
  - open_mae[day] = sum of mae_acct of every trade spanning that day (worst-case: all
    positions simultaneously at their MAE) -> conservative LOWER bound on pass rate
  - equity_low[day] = running realized balance at day-start + open_mae[day]
  - daily breach if the day's dip exceeds 5% of start-of-day equity
  - max breach if equity_low ever <= 90% of 100k
  - pass if realized balance reaches +10% before any breach

Block-bootstrap over calendar days gives P(pass) for a given horizon. Scale per sleeve
= deployment RISK_FIXED / q08 base (inferred per stream from the stop-loss cluster).
Stufe-2 (exact) would need per-bar portfolio equity; this is the conservative Stufe-1.
"""
from __future__ import annotations
import json, glob, os, re, random, collections, statistics, datetime as dt, argparse, csv, math
from pathlib import Path
from zoneinfo import ZoneInfo

Q08 = Path(r"C:/Users/Administrator/AppData/Roaming/MetaQuotes/Terminal/Common/Files/QM/q08_trades")
FDIR = Path(r"C:/Users/Administrator/AppData/Roaming/MetaQuotes/Terminal/81A933A9AFC5DE3C23B15CAB19C63850/MQL5/Presets")
START = 100_000.0
DAILY_LIMIT = 0.05 * START
MAXLOSS_FLOOR = START * (1 - 0.10)
TARGET = START * 1.10
EPSILON = 1e-9
FTMO_TZ = ZoneInfo("Europe/Prague")
SYMMAP = {"US100": "NDX", "GER40": "GDAXI", "USOIL": "XTIUSD"}
LEGACY_Q08_MONEY_BASIS = "LEGACY_ONE_ENTRY_ONE_EXIT_CLOSE_COMMISSION_V0"
FULL_POSITION_LIFECYCLE_ACTUAL_V1 = "FULL_POSITION_LIFECYCLE_ACTUAL_V1"
FULL_LIFECYCLE_FEE_TOLERANCE = 0.005


class Q08MoneyBasisError(ValueError):
    """The row declares an unsupported or malformed Q08 money basis."""


class Q08MoneyRowError(ValueError):
    """The row does not satisfy its declared Q08 money-basis contract."""


def q08_money_basis(row):
    """Return the explicit basis, or the historical basis for an unmarked row.

    Absence is the only legacy discriminator.  An explicit null, empty string, or
    unknown marker is not legacy evidence and therefore fails closed.
    """
    if "money_basis" not in row:
        return LEGACY_Q08_MONEY_BASIS
    basis = row["money_basis"]
    if basis != FULL_POSITION_LIFECYCLE_ACTUAL_V1:
        raise Q08MoneyBasisError(f"unsupported q08 money_basis: {basis!r}")
    return basis


def q08_stream_money_basis(rows):
    """Return one homogeneous trade-stream basis, failing closed on mixtures."""
    bases = {
        q08_money_basis(row)
        for row in rows
        if str(row.get("event") or "TRADE_CLOSED") == "TRADE_CLOSED"
    }
    if len(bases) > 1:
        raise Q08MoneyBasisError(
            "mixed q08 money_basis values: " + ",".join(sorted(bases))
        )
    return next(iter(bases), None)


def _marked_money_number(row, field):
    if field not in row:
        raise Q08MoneyRowError(f"marked q08 row missing {field}")
    value = row[field]
    if isinstance(value, bool) or not isinstance(value, (int, float)):
        raise Q08MoneyRowError(f"marked q08 row has non-numeric {field}")
    number = float(value)
    if not math.isfinite(number):
        raise Q08MoneyRowError(f"marked q08 row has non-finite {field}")
    return number


def _full_lifecycle_money_values(row):
    values = {
        field: _marked_money_number(row, field)
        for field in (
            "profit",
            "swap",
            "fee",
            "entry_commission",
            "exit_commission",
            "commission",
            "net",
        )
    }
    # MAE is required and finite for this consumer, but it is deliberately not
    # part of the versioned full-lifecycle money identity above.
    values["mae_acct"] = _marked_money_number(row, "mae_acct")
    expected_commission = values["entry_commission"] + values["exit_commission"]
    if not math.isclose(
        values["commission"], expected_commission, rel_tol=0.0, abs_tol=1e-6
    ):
        raise Q08MoneyRowError(
            "marked q08 commission != entry_commission + exit_commission"
        )
    expected_net = values["profit"] + values["swap"] + values["commission"]
    if abs(values["fee"]) > FULL_LIFECYCLE_FEE_TOLERANCE:
        raise Q08MoneyRowError("marked q08 row has unsupported non-zero fee")
    expected_net += values["fee"]
    if not math.isclose(values["net"], expected_net, rel_tol=0.0, abs_tol=1e-6):
        raise Q08MoneyRowError(
            "marked q08 net != profit + swap + commission + fee"
        )
    return values


def load_ftmo_book():
    """Return {(ea,symdwx): {'risk_fixed':.., 'tf':..}} from FTMO set files."""
    book = {}
    for f in glob.glob(str(FDIR / "*.set")):
        n = os.path.basename(f)
        raw = open(f, 'rb').read(); txt = raw.decode('utf-16-le', 'ignore') if b'\x00' in raw[:40] else raw.decode('utf-8', 'ignore')
        rf = re.search(r'^RISK_FIXED\s*=\s*([0-9.]+)', txt, re.M)
        ea = re.search(r'QM5_(\d+)', n); sy = re.search(r'r25p1_([A-Za-z0-9.]+)_([HDM]\d+)', n)
        if rf and ea and sy:
            symtok = sy.group(1).replace('.cash', '')
            symdwx = SYMMAP.get(symtok, symtok) + ".DWX"
            book[(int(ea.group(1)), symdwx)] = {"risk_fixed": float(rf.group(1)), "tf": sy.group(2)}
    return book


def load_trades(ea, sym):
    p = Q08 / f"{ea}_{sym.replace('.', '_')}.jsonl"
    if not p.exists():
        return None, False
    rows = []
    fresh = False
    for line in open(p, encoding="utf-8"):
        line = line.strip()
        if not line:
            continue
        try:
            o = json.loads(line)
        except Exception:
            continue
        if "mae_acct" in o and "entry_time" in o:
            fresh = True
        rows.append(o)
    q08_stream_money_basis(rows)
    return rows, fresh


def q08_round_trip_values(row):
    """Return report-reconciled net and MAE for either supported Q08 schema.

    Historical unmarked rows contain only closing-side commission, so their
    fixed-volume one-entry/one-exit correction is retained.  Marked lifecycle-v1
    rows already contain actual entry and exit commission in ``net`` and must
    not be charged a second time.  Their ``mae_acct`` remains the framework's
    floating-MAE measure (with the producer's close-loss cap), not a versioned
    full-lifecycle commission measure.  The consumer adds only the row's actual
    allocated entry commission to obtain conservative account MAE; exit
    commission is already represented by the close-loss cap when relevant.
    """
    basis = q08_money_basis(row)
    if basis == FULL_POSITION_LIFECYCLE_ACTUAL_V1:
        values = _full_lifecycle_money_values(row)
        net = values["net"]
        mae = min(0.0, values["mae_acct"] + values["entry_commission"])
        # The lifecycle-v1 producer already caps mae_acct at the full-lifecycle
        # net.  Adding entry commission is conservative only until it would
        # count that cost twice and push MAE below the realized lifecycle loss.
        if net < 0.0:
            mae = max(net, mae)
        return net, mae

    close_commission = float(row.get("commission", 0.0))
    net = float(row["net"]) + close_commission
    mae = min(0.0, float(row.get("mae_acct", 0.0)) + close_commission, net)
    return net, mae


def infer_base_risk(rows):
    """q08 RISK_FIXED base ~ the stop-loss cluster: use the 20th percentile of losing
    net (a full stop-out ~ -risk). Fallback 1000."""
    corrected = [q08_round_trip_values(row)[0] for row in rows]
    losses = sorted(abs(net) for net in corrected if net < 0)
    if len(losses) >= 20:
        return statistics.median(losses[int(len(losses) * 0.5):])  # upper-half median of losses
    return 1000.0


def ftmo_calendar_day(timestamp: int | float) -> dt.date:
    """Map a UTC epoch timestamp to FTMO's CE(S)T calendar day."""
    return dt.datetime.fromtimestamp(timestamp, tz=dt.UTC).astimezone(FTMO_TZ).date()


def continuous_calendar_days(days):
    """Return every calendar day between the first and last observation."""
    observed = sorted(set(days))
    if not observed:
        return []
    output = []
    current = observed[0]
    while current <= observed[-1]:
        output.append(current)
        current += dt.timedelta(days=1)
    return output


def build_daily(book, risk_multiplier=1.0):
    """Return CE(S)T days, realized PnL, open MAE, and trade-open counts."""
    realized = collections.defaultdict(float)
    open_mae = collections.defaultdict(float)
    trade_opens = collections.defaultdict(int)
    loaded, stale = [], []
    for (ea, sym), meta in book.items():
        rows, fresh = load_trades(ea, sym)
        if rows is None or not fresh:
            stale.append((ea, sym)); continue
        loaded.append((ea, sym))
        base = infer_base_risk(rows)
        scale = meta["risk_fixed"] / base if base > 0 else 0.0
        for r in rows:
            raw_net, raw_mae = q08_round_trip_values(r)
            net = raw_net * scale * risk_multiplier
            mae = raw_mae * scale * risk_multiplier
            cday = ftmo_calendar_day(r["time"])
            eday = ftmo_calendar_day(r.get("entry_time", r["time"]))
            realized[cday] += net
            trade_opens[eday] += 1
            d = eday
            while d <= cday:
                open_mae[d] += mae
                d += dt.timedelta(days=1)
    days = continuous_calendar_days(set(realized) | set(open_mae) | set(trade_opens))
    return days, realized, open_mae, trade_opens, loaded, stale


def evaluate_window(seq, target=TARGET):
    """Evaluate (realized, open_mae, trade_opens) rows under FTMO Phase-1 rules."""
    bal = START
    trading_days = 0
    for rz, om, opens in seq:
        if opens > 0:
            trading_days += 1
        day_low = bal + om          # worst intraday before this day's closes realize
        if bal - day_low >= DAILY_LIMIT:      # >5% intraday drop from day-start
            return "daily_breach"
        if day_low <= MAXLOSS_FLOOR:          # >10% below start
            return "max_breach"
        bal += rz
        if bal + EPSILON >= target and trading_days >= 4:
            return "passed"
    return "not_reached"


def bootstrap(pairs, horizon, block, runs, seed, target=TARGET):
    rng = random.Random(seed); c = collections.Counter()
    n = len(pairs)
    for _ in range(runs):
        seq = sample_sequence(pairs, horizon, block, rng)
        c[evaluate_window(seq, target=target)] += 1
    return c


def sample_sequence(pairs, horizon, block, rng):
    seq = []
    n = len(pairs)
    while len(seq) < horizon:
        start = rng.randrange(n)
        for offset in range(block):
            seq.append(pairs[(start + offset) % n])
            if len(seq) == horizon:
                break
    return seq


def bootstrap_two_phase(
    pairs,
    horizon_per_phase,
    block,
    runs,
    seed,
    phase1_target=TARGET,
    phase2_target=105_000.0,
):
    rng = random.Random(seed)
    counts = collections.Counter()
    for _ in range(runs):
        phase1 = evaluate_window(
            sample_sequence(pairs, horizon_per_phase, block, rng), target=phase1_target
        )
        if phase1 != "passed":
            counts[f"phase1_{phase1}"] += 1
            continue
        phase2 = evaluate_window(
            sample_sequence(pairs, horizon_per_phase, block, rng), target=phase2_target
        )
        if phase2 != "passed":
            counts[f"phase2_{phase2}"] += 1
            continue
        counts["passed"] += 1
    return counts


def parse_number_list(raw, value_type, label, allow_zero=False):
    try:
        values = [value_type(item.strip()) for item in raw.split(",") if item.strip()]
    except ValueError as exc:
        raise argparse.ArgumentTypeError(f"invalid {label}: {raw}") from exc
    invalid = any(value < 0 if allow_zero else value <= 0 for value in values)
    if not values or invalid:
        requirement = "non-negative" if allow_zero else "positive"
        raise argparse.ArgumentTypeError(f"{label} must contain {requirement} values")
    return values


def evaluate_grid(book, scales, horizons, seeds, block, runs, target=TARGET):
    current_scale = sum(meta["risk_fixed"] for meta in book.values()) / 1000.0
    if current_scale <= 0.0:
        raise ValueError("book has no positive deployment scale")
    output = []
    inventory = None
    for target_scale in scales:
        multiplier = target_scale / current_scale
        days, realized, open_mae, trade_opens, loaded, stale = build_daily(
            book, risk_multiplier=multiplier
        )
        if inventory is None:
            inventory = (days, loaded, stale)
        pairs = [
            (realized.get(day, 0.0), open_mae.get(day, 0.0), trade_opens.get(day, 0))
            for day in days
        ]
        for horizon in horizons:
            counts = collections.Counter()
            for seed in seeds:
                counts.update(bootstrap(pairs, horizon, block, runs, seed, target=target))
            total = sum(counts.values())
            output.append(
                {
                    "ftmo_scale": target_scale,
                    "target_pct": (target / START - 1.0) * 100.0,
                    "horizon_days": horizon,
                    "runs": total,
                    "seeds": ",".join(str(seed) for seed in seeds),
                    "pass_pct": counts["passed"] / total * 100.0,
                    "daily_breach_pct": counts["daily_breach"] / total * 100.0,
                    "max_breach_pct": counts["max_breach"] / total * 100.0,
                    "not_reached_pct": counts["not_reached"] / total * 100.0,
                }
            )
    return current_scale, inventory, output


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("--runs", type=int, default=8000)
    ap.add_argument("--block", type=int, default=5)
    ap.add_argument("--horizons", default="30,60")
    ap.add_argument("--seeds", default="7")
    ap.add_argument(
        "--scales",
        help="comma-separated target total deployment scales; default is the preset scale",
    )
    ap.add_argument("--csv", type=Path)
    ap.add_argument("--target-pct", type=float, default=10.0)
    args = ap.parse_args()
    book = load_ftmo_book()
    print(f"FTMO book: {len(book)} sleeves")
    horizons = parse_number_list(args.horizons, int, "horizons")
    seeds = parse_number_list(args.seeds, int, "seeds", allow_zero=True)
    preset_scale = sum(meta["risk_fixed"] for meta in book.values()) / 1000.0
    scales = (
        parse_number_list(args.scales, float, "scales") if args.scales else [preset_scale]
    )
    if args.target_pct <= 0.0:
        ap.error("--target-pct must be positive")
    current_scale, inventory, rows = evaluate_grid(
        book, scales, horizons, seeds, args.block, args.runs,
        target=START * (1.0 + args.target_pct / 100.0),
    )
    days, loaded, stale = inventory
    print(f"loaded (fresh MAE): {len(loaded)}  |  stale (need re-run): {len(stale)} -> {stale}")
    if not days:
        print("no fresh streams yet"); return
    print(f"calendar days {len(days)} ({days[0]}..{days[-1]}), preset scale {current_scale:.2f}")
    if len(loaded) < len(book):
        print(f"\n[PARTIAL BOOK — {len(loaded)}/{len(book)} sleeves; mechanics test only, not the final number]")
    for row in rows:
        print(
            f"  scale {row['ftmo_scale']:4.2f} horizon {row['horizon_days']:3d}d: "
            f"PASS {row['pass_pct']:5.1f}% "
            f"(daily {row['daily_breach_pct']:.1f}%, max {row['max_breach_pct']:.1f}%, "
            f"not-reached {row['not_reached_pct']:.1f}%)"
        )
    if args.csv:
        args.csv.parent.mkdir(parents=True, exist_ok=True)
        with args.csv.open("w", newline="", encoding="utf-8") as handle:
            writer = csv.DictWriter(handle, fieldnames=list(rows[0]))
            writer.writeheader()
            writer.writerows(rows)
        print(f"csv: {args.csv}")


if __name__ == "__main__":
    main()
