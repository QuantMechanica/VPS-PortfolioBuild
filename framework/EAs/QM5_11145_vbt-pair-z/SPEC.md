# QM5_11145_vbt-pair-z — Strategy Spec

**EA ID:** QM5_11145
**Slug:** `vbt-pair-z`
**Source:** `3f3833d9-8676-52e4-a822-2c5fc87bbe20` (vectorbt `examples/PairsTrading.ipynb`)
**Author of this spec:** Claude
**Last revised:** 2026-06-17

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
after `time_stop_bars` D1 bars. The host leg is sent through the framework magic
(slot = `qm_magic_slot_offset`); the partner leg is sent on a foreign `.DWX`
symbol through the framework basket order path at its own registered slot. One
position per (magic, symbol); both legs are always opened and closed together.

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
| `strategy_leg_risk_split` | 0.5 | 0.25-1.0 | Documentary share of RISK_FIXED notionally per leg (lots sized per-leg by framework) |

---

## 3. Symbol Universe

Pairs trade — registered as three economically-cointegrated host/partner pairs.
Host = leg1 (`qm_magic_slot_offset`), partner = leg2 (`strategy_partner_slot`).

**Designed for:**
- `EURUSD.DWX` (slot 0, host A) / `GBPUSD.DWX` (slot 1, partner A) — two USD majors driven by the same USD factor; classic tightly-cointegrated EUR/GBP relative-value pair.
- `AUDUSD.DWX` (slot 2, host B) / `NZDUSD.DWX` (slot 3, partner B) — antipodean commodity-currency pair, the strongest persistent FX cointegration relationship.
- `GDAXI.DWX` (slot 4, host C) / `NDX.DWX` (slot 5, partner C) — DAX-40 vs Nasdaq-100 index-CFD pair; correlated global equity beta. **Card named GER40.DWX; ported to GDAXI.DWX (the actual DAX-40 `.DWX` symbol in `dwx_symbol_matrix.csv`).**

**Explicitly NOT for:**
- `SP500.DWX` — backtest-only (broker routes no orders); a pairs EA whose legs must both be live-tradable cannot promote an SP500 leg.
- Single-symbol or uncorrelated symbols — the strategy is only meaningful on a cointegrated two-symbol pair.

---

## 4. Timeframe

| Aspect | Value |
|---|---|
| Base timeframe | `D1` |
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

---

## Revision History

| Version | Date | Reason | Notes |
|---|---|---|---|
| v1 | 2026-06-17 | Initial build from card | two-leg basket pairs EA; GER40.DWX→GDAXI.DWX port |
