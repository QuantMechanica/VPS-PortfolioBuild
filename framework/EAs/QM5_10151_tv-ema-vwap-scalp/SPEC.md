# QM5_10151_tv-ema-vwap-scalp — Strategy Spec

**EA ID:** QM5_10151
**Slug:** `tv-ema-vwap-scalp`
**Source:** `30591366-874b-5bee-b47c-da2fca20b728` (see `strategy-seeds/sources/30591366-874b-5bee-b47c-da2fca20b728/`)
**Author of this spec:** Codex
**Last revised:** 2026-05-25

---

## 1. Strategy Logic

The EA trades M5 bars by default. It goes long when EMA(9) crosses above EMA(21)
on the last closed bar and that close is above the session VWAP; it goes short
when EMA(9) crosses below EMA(21) and the close is below session VWAP.
Positions use an initial stop at 1.5 ATR(14) and a take-profit at 2.0 ATR(14)
unless the optional trailing mode is enabled. Reversal exit is available as a
strategy input and closes the current position when the opposite valid signal is
observed.

---

## 2. Parameters

| Parameter | Default | Range | Meaning |
|---|---|---|---|
| `strategy_signal_tf` | PERIOD_M5 | (see source) | (see strategy logic) |
| `strategy_fast_ema_period` | 9 | 2-100 | Fast EMA period for crossover entry |
| `strategy_slow_ema_period` | 21 | 3-200 | Slow EMA period for crossover entry |
| `strategy_atr_period` | 14 | 2-100 | ATR period for stop, target, and trailing variants |
| `strategy_atr_sl_mult` | 1.5 | 0.1-10.0 | Initial stop distance in ATR multiples |
| `strategy_atr_tp_mult` | 2.0 | 0.1-20.0 | Fixed take-profit distance in ATR multiples |
| `strategy_reversal_exit` | true | true/false | Close on the opposite valid EMA/VWAP signal |
| `strategy_trailing_enabled` | false | true/false | Replace fixed target with ATR trailing when enabled |
| `strategy_trail_activate_atr` | 1.0 | 0.1-10.0 | Favorable ATR move required before trailing starts |
| `strategy_trail_atr_mult` | 1.0 | 0.1-10.0 | ATR trailing-stop distance |
| `strategy_session_start_hhmm` | 1300 | 0-2359 | Broker-time intraday session start |
| `strategy_session_end_hhmm` | 2200 | 0-2359 | Broker-time intraday session end |
| `strategy_max_spread_points` | 250 | 0-10000 | Maximum spread in points; 0 disables the spread gate |

> Framework-level inputs (RISK_PERCENT, RISK_FIXED, PORTFOLIO_WEIGHT,
> qm_news_mode, qm_rng_seed, qm_stress_reject_probability,
> qm_friday_close_*) are documented in
> `framework/V5_FRAMEWORK_DESIGN.md` — not re-listed here.

---

## 3. Symbol Universe

**Designed for:**
- `AUDCAD.DWX` — registered in magic_numbers.csv for this EA
- `AUDCHF.DWX` — registered in magic_numbers.csv for this EA
- `AUDJPY.DWX` — registered in magic_numbers.csv for this EA
- `AUDNZD.DWX` — registered in magic_numbers.csv for this EA
- `AUDUSD.DWX` — registered in magic_numbers.csv for this EA
- `CADCHF.DWX` — registered in magic_numbers.csv for this EA
- `CADJPY.DWX` — registered in magic_numbers.csv for this EA
- `CHFJPY.DWX` — registered in magic_numbers.csv for this EA
- `EURAUD.DWX` — registered in magic_numbers.csv for this EA
- `EURCAD.DWX` — registered in magic_numbers.csv for this EA
- `EURCHF.DWX` — registered in magic_numbers.csv for this EA
- `EURGBP.DWX` — registered in magic_numbers.csv for this EA
- `EURJPY.DWX` — registered in magic_numbers.csv for this EA
- `EURNZD.DWX` — registered in magic_numbers.csv for this EA
- `EURUSD.DWX` — registered in magic_numbers.csv for this EA
- `GBPAUD.DWX` — registered in magic_numbers.csv for this EA
- `GBPCAD.DWX` — registered in magic_numbers.csv for this EA
- `GBPCHF.DWX` — registered in magic_numbers.csv for this EA
- `GBPJPY.DWX` — registered in magic_numbers.csv for this EA
- `GBPNZD.DWX` — registered in magic_numbers.csv for this EA
- `GBPUSD.DWX` — registered in magic_numbers.csv for this EA
- `GDAXI.DWX` — registered in magic_numbers.csv for this EA
- `NDX.DWX` — registered in magic_numbers.csv for this EA
- `NZDCAD.DWX` — registered in magic_numbers.csv for this EA
- `NZDCHF.DWX` — registered in magic_numbers.csv for this EA
- `NZDJPY.DWX` — registered in magic_numbers.csv for this EA
- `NZDUSD.DWX` — registered in magic_numbers.csv for this EA
- `SP500.DWX` — registered in magic_numbers.csv for this EA
- `UK100.DWX` — registered in magic_numbers.csv for this EA
- `USDCAD.DWX` — registered in magic_numbers.csv for this EA
- `USDCHF.DWX` — registered in magic_numbers.csv for this EA
- `USDJPY.DWX` — registered in magic_numbers.csv for this EA
- `WS30.DWX` — registered in magic_numbers.csv for this EA
- `XAGUSD.DWX` — registered in magic_numbers.csv for this EA
- `XAUUSD.DWX` — registered in magic_numbers.csv for this EA
- `XNGUSD.DWX` — registered in magic_numbers.csv for this EA
- `XTIUSD.DWX` — registered in magic_numbers.csv for this EA

**Explicitly NOT for:** any symbol not in the list above (no implicit
universe expansion at runtime; the `QM_SymbolGuard` framework helper
rejects foreign symbols).

---

## 4. Timeframe

| Aspect | Value |
|---|---|
| Base timeframe | `M5` |
| Multi-timeframe refs | none |
| Bar gating | `QM_IsNewBar(_Symbol, PERIOD_CURRENT)` (default) |

---

## 5. Expected Behaviour

| Metric | Expected |
|---|---|
| Trades / year / symbol | 600 |
| Cadence note | intraday scalping; high turnover |
| Typical hold time | minutes to hours |
| Expected drawdown profile | frequent small losses bounded by ATR stops |
| Regime preference | liquid intraday trend-following |
| Win rate target (qualitative) | medium |

---

## 6. Source Citation

This card was mechanised from:

**Source ID:** `30591366-874b-5bee-b47c-da2fca20b728`
**Pointer:** `strategy-seeds/sources/30591366-874b-5bee-b47c-da2fca20b728/`
**R1–R4 verdict (Q00):** all PASS — see
`artifacts/cards_approved/QM5_10151_tv-ema-vwap-scalp.md`

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
| v1 | 2026-05-25 | Initial build from card | 3e9a16fe-a6ab-4a41-bbd0-1aa16a2c91ba |
