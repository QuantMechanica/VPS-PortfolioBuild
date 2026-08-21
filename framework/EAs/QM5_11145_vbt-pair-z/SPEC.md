# QM5_11145_vbt-pair-z — Strategy Spec

**EA ID:** QM5_11145
**Slug:** `vbt-pair-z`
**Source:** `3f3833d9-8676-52e4-a822-2c5fc87bbe20` (vectorbt `examples/PairsTrading.ipynb`)
**Author of this spec:** Claude
**Last revised:** 2026-08-21

---

## 1. Strategy Logic

Relative-value pairs (statistical-arbitrage) trade on two cointegrated `.DWX`
symbols, evaluated on completed D1 bars. On each new D1 bar the EA fits a rolling
OLS regression of `log(host_close)` on `log(partner_close)` over the trailing
`Period` bars, forms the spread `spread = log(host) - (intercept + slope*log(partner))`,
and standardises it into a z-score `z = (spread - mean(spread)) / std(spread)`.

Entry trades the SPREAD market-neutrally: when `z > +z_upper` the spread is rich,
so the EA SELLs the host leg and BUYs the partner leg (short-spread); when
`z < -z_lower` the spread is cheap, so it BUYs the host leg and SELLs the partner
leg (long-spread). Exit is mean-reversion zero-cross: a short-spread closes when
`z <= 0`, a long-spread closes when `z >= 0`. A pair-level safety stop closes both
legs if `|z|` expands to `safety_z` after entry, and a time stop closes the pair
after `time_stop_bars` D1 bars. Both legs are sent through the framework basket
order path at their registered slots. The approved safety exit is expressed in
z-space rather than as a native price stop, so the implementation converts the
distance from entry z to `safety_z` into a log-price sizing distance, allocates
`RISK_FIXED` equally to the two legs, and submits explicit lots with no native
SL. One position per (magic, symbol); both legs are opened and closed together,
and a failed second leg or later orphan leg triggers immediate rollback.

---

## 2. Parameters

| Parameter | Default | Range | Meaning |
|---|---|---|---|
| `strategy_partner_symbol` | `GBPUSD.DWX` | any registered partner `.DWX` | Leg-2 (partner) symbol read for the spread and traded opposite the host |
| `strategy_partner_slot` | 1 | 0-9999 | Partner leg's registered magic slot in `magic_numbers.csv` |
| `strategy_period` | 100 | 60-150 | Rolling OLS + z-score lookback in D1 bars |
| `strategy_z_upper` | 1.96 | 1.5-2.25 | Short-spread entry threshold (z above this) |
| `strategy_z_lower` | 1.96 | 1.5-2.25 | Long-spread entry threshold magnitude (z below `-z_lower`) |
| `strategy_safety_z` | 3.25 | 3.0-3.5 | Pair safety exit when `\|z\|` expands beyond this |
| `strategy_time_stop_bars` | 30 | 10-60 | Close the pair after N D1 bars if no reversion |
| `strategy_min_d1_bars` | 160 | >= Period+buffer | Skip until both legs have enough synced D1 history |
| `strategy_leg_risk_split` | 0.5 | >0 and <=0.5 | Share of the package `RISK_FIXED` budget assigned to each leg; 0.5/0.5 is the Q02 baseline |

---

## 3. Symbol Universe

The card registered three host/partner alternatives. A tester instance can bind
only one host, partner, and set of lots, so Q02 uses one canonical logical basket
rather than the old physical-leg fan-out.

**Canonical Q02 basket:**
- Logical identity: `QM5_11145_EURUSD_GBPUSD_PAIR_Z_D1`.
- Host: `EURUSD.DWX` (slot 0).
- Partner: `GBPUSD.DWX` (slot 1).

**Approved alternates, not part of this Q02 identity:**
- `AUDUSD.DWX` (slot 2) / `NZDUSD.DWX` (slot 3).
- `GDAXI.DWX` (slot 4) / `NDX.DWX` (slot 5). The card named `GER40.DWX`; `GDAXI.DWX` is the actual DAX-40 registry symbol.

**Explicitly NOT for:**
- `SP500.DWX` — backtest-only (broker routes no orders); a pairs EA whose legs must both be live-tradable cannot promote an SP500 leg.
- Single-symbol or uncorrelated symbols — the strategy is only meaningful on a cointegrated two-symbol pair.

---

## 4. Timeframe

| Aspect | Value |
|---|---|
| Base timeframe | `D1` on host `EURUSD.DWX` |
| Multi-timeframe refs | partner-symbol D1 closes (cross-symbol, same TF) |
| Bar gating | `QM_IsNewBar(_Symbol, PERIOD_CURRENT)` (default) |

---

## 5. Expected Behaviour

| Metric | Expected |
|---|---|
| Trades / year / symbol | ~8 (card: 6-16 spread trades/year/pair) |
| Typical hold time | days to a few weeks (mean-reversion of the spread) |
| Expected drawdown profile | bounded; risk-fixed per leg, market-neutral, safety z-stop caps tail |
| Regime preference | mean-revert (spread reversion around its rolling mean) |
| Win rate target (qualitative) | medium |

---

## 6. Source Citation

This card was mechanised from:

**Source ID:** `3f3833d9-8676-52e4-a822-2c5fc87bbe20`
**Source type:** forum/repo (GitHub notebook)
**Pointer:** `https://github.com/polakowo/vectorbt/blob/master/examples/PairsTrading.ipynb`
**R1–R4 verdict (Q00):** all PASS / see `artifacts/cards_approved/QM5_11145_vbt-pair-z.md`

---

## 7. Risk Model

| Phase | Risk mode | Value |
|---|---|---|
| Backtest (Q02 – Q10) | RISK_FIXED | $1,000 per trade (HR4) |
| Live burn-in (Q13) | RISK_PERCENT | Min-lot equivalent |
| Full live (post-Q13 PASS) | RISK_PERCENT | Allocated by Q11 portfolio (typically 0.3% – 0.5%) |

ENV→mode validation is enforced by `QM_FrameworkInit` (`EA_INPUT_RISK_MODE_MISMATCH`).
The canonical backtest preset fixes `RISK_FIXED=1000`, `RISK_PERCENT=0`, and
news filtering off. The six former component presets were retired because they
omitted `strategy_partner_symbol`/`strategy_partner_slot`; five therefore ran a
different pair than their filename, while the obsolete `GER40.DWX` host could
not produce a report. Those terminal rows are infrastructure/mistest evidence,
not economic evidence for this logical basket.

---

## Revision History

| Version | Date | Reason | Notes |
|---|---|---|---|
| v1 | 2026-06-17 | Initial build from card | two-leg basket pairs EA; GER40.DWX→GDAXI.DWX port |
| v1.1 | 2026-08-21 | Q02 infrastructure recovery | canonical EURUSD/GBPUSD logical basket; explicit two-leg model-distance sizing; stale physical-leg presets retired |
