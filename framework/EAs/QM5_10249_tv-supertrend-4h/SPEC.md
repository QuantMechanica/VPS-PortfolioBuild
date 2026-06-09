# QM5_10249_tv-supertrend-4h — Strategy Spec

**EA ID:** QM5_10249
**Slug:** `tv-supertrend-4h`
**Source:** `30591366-874b-5bee-b47c-da2fca20b728` (see `strategy-seeds/sources/30591366-874b-5bee-b47c-da2fca20b728/`)
**Author of this spec:** Codex
**Last revised:** 2026-06-09

---

## 1. Strategy Logic

The EA calculates a SuperTrend line on closed H4 bars using ATR and opens long
when SuperTrend flips from downtrend to uptrend. It opens short when SuperTrend
flips from uptrend to downtrend. The initial stop is the current SuperTrend
line, half the position is closed at 0.75R, the stop is moved to break-even
after that partial, and any remaining position is closed after an opposite
SuperTrend flip. If a break-even protected position disappears while the
SuperTrend direction is unchanged, RSI re-entry is allowed when RSI crosses
out of oversold for longs or out of overbought for shorts.

---

## 2. Parameters

| Parameter | Default | Range | Meaning |
|---|---|---|---|
| `strategy_atr_period` | 10 | 1-100 | ATR period used for SuperTrend. |
| `strategy_atr_mult` | 3.0 | 0.1-10.0 | ATR multiplier used for the SuperTrend stop line. |
| `strategy_supertrend_warmup` | 120 | 20-500 | Closed bars used to stabilize the SuperTrend recurrence. |
| `strategy_partial_rr` | 0.75 | 0.1-5.0 | Reward-to-risk threshold for the partial close. |
| `strategy_partial_fraction` | 0.50 | 0.01-0.99 | Fraction of open volume to close at the partial target. |
| `strategy_rsi_period` | 14 | 2-100 | RSI period for break-even re-entry. |
| `strategy_rsi_oversold` | 30.0 | 1-50 | Long re-entry threshold crossed upward. |
| `strategy_rsi_overbought` | 70.0 | 50-99 | Short re-entry threshold crossed downward. |

> Framework-level inputs (RISK_PERCENT, RISK_FIXED, PORTFOLIO_WEIGHT,
> qm_news_mode, qm_rng_seed, qm_stress_reject_probability,
> qm_friday_close_*) are documented in
> `framework/V5_FRAMEWORK_DESIGN.md` — not re-listed here.

---

## 3. Symbol Universe

**Designed for:**
- `XAUUSD.DWX` — registered in magic_numbers.csv for this EA
- `XTIUSD.DWX` — registered in magic_numbers.csv for this EA
- `NDX.DWX` — registered in magic_numbers.csv for this EA
- `GDAXI.DWX` — DAX equivalent for the card's GER40 port, registered in magic_numbers.csv
- `EURUSD.DWX` — registered in magic_numbers.csv for this EA

**Explicitly NOT for:**
- `BTCUSD.DWX` — card names it only "if available"; it is not present in `dwx_symbol_matrix.csv`.
- `GER40.DWX` — not present in `dwx_symbol_matrix.csv`; use `GDAXI.DWX`.
- Any symbol not listed above — no implicit universe expansion at runtime.

---

## 4. Timeframe

| Aspect | Value |
|---|---|
| Base timeframe | `H4` |
| Multi-timeframe refs | none |
| Bar gating | `QM_IsNewBar(_Symbol, PERIOD_CURRENT)` (default) |

---

## 5. Expected Behaviour

| Metric | Expected |
|---|---|
| Trades / year / symbol | 50 |
| Cadence note | see card body |
| Typical hold time | hours to days |
| Expected drawdown profile | trend-following whipsaw risk bounded by fixed per-trade risk |
| Regime preference | trend / volatility-expansion |
| Win rate target (qualitative) | medium |

---

## 6. Source Citation

This card was mechanised from:

**Source ID:** `30591366-874b-5bee-b47c-da2fca20b728`
**Source type:** TradingView script page
**Pointer:** `https://www.tradingview.com/script/N0nYQBlh/`
**R1–R4 verdict (Q00):** all PASS per `artifacts/cards_approved/QM5_10249_tv-supertrend-4h.md`

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
| v1 | 2026-06-09 | Initial build from card | b0f552bc-ada1-4a81-b6a2-495fba4a610f |
