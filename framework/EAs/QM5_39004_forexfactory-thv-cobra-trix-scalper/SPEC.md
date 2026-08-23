# QM5_39004_forexfactory-thv-cobra-trix-scalper — Strategy Spec

**EA ID:** QM5_39004
**Slug:** `forexfactory-thv-cobra-trix-scalper`
**Source:** `forexfactory-thv-cobra-trix-scalper-official-source`
**Author of this spec:** Gemini
**Last revised:** 2026-08-23

---

## 1. Strategy Logic

The strategy implements the Cobraforex THV system on the 5-minute (M5) timeframe. It uses Fast Trix (Triple Exponential Moving Average period 9) and Slow Trix (Triple EMA period 18) crossover triggers confirmed by THV Coral (Smoothed Moving Average SMMA period 20) baseline trend direction and zero-line alignment.

Long entry executes on a closed M5 bar when Close is above the Coral line, Fast Trix is greater than Slow Trix, and Fast Trix is above zero. Short entry executes when Close is below the Coral line, Fast Trix is less than Slow Trix, and Fast Trix is below zero. Stop loss is placed beyond the Coral band with a 2-pip buffer, and take profit is targeted at 2.0 times the stop loss distance (1:2.0 R:R). Open trades are closed when Fast Trix changes slope direction.

The Coral stop is exact: invalid stop geometry rejects entry rather than substituting an ATR stop. Fast-Trix direction is reconstructed from the current broker-side position type after restart, so exit behavior does not depend on entry-process memory. Exit management runs before entry-only rollover, spread, daily-loss, and news admission.

---

## 2. Parameters

| Parameter | Default | Range | Meaning |
|---|---|---|---|
| `InpCoralPeriod` | 20 | 14-30 | THV Coral SMMA baseline period |
| `InpFastTrix` | 9 | 5-12 | Fast Trix derivative period |
| `InpSlowTrix` | 18 | 12-24 | Slow Trix derivative period |
| `strategy_atr_period` | 14 | 7-28 | ATR period on M5 |
| `strategy_sl_buffer_pips` | 2.0 | 1.0-5.0 | Stop loss buffer beyond Coral in pips |
| `strategy_tp_rr` | 2.0 | 1.5-3.5 | Take profit risk-to-reward multiple |
| `strategy_rollover_start_hhmm` | 2355 | fixed | GMT rollover blackout start |
| `strategy_rollover_end_hhmm` | 5 | fixed | GMT rollover blackout end |
| `strategy_spread_filter_mult` | 1.8 | fixed | ATR spread ceiling multiplier |
| `strategy_max_slippage_ticks` | 3 | 1-3 | Maximum market-order deviation in trade ticks |
| `strategy_daily_loss_halt_pct` | 2.0 | >0-2.0 | Realized daily loss entry halt |
| `strategy_daily_hard_stop_pct` | 2.5 | >0-2.5 | Kill-switch daily drawdown ceiling |
| `strategy_total_dd_halt_pct` | 5.0 | >0-5.0 | Kill-switch total drawdown ceiling |
| `strategy_per_trade_risk_cap_pct` | 0.5 | >0-0.5 | Per-trade percentage-risk ceiling |

---

## 3. Symbol Universe

**Designed for:**
- `EURUSD.DWX` — Primary liquid FX pair with high M5 volume and narrow spread suitable for scalping.
- `USDJPY.DWX` — Major FX pair with persistent intraday trend momentum.
- `GBPUSD.DWX` — High volatility FX pair with clear Coral / TRIX trend separation.

**Explicitly NOT for:**
- Non-DWX symbols absent from `framework/registry/dwx_symbol_matrix.csv`.

---

## 4. Timeframe

| Aspect | Value |
|---|---|
| Base timeframe | `PERIOD_M5` |
| Multi-timeframe refs | none |
| Bar gating | `QM_IsNewBar(_Symbol, PERIOD_M5)` |

---

## 5. Expected Behaviour

| Metric | Expected |
|---|---|
| Trades / year / symbol | 150 |
| Typical hold time | 15-60 minutes |
| Expected drawdown profile | < 2.7% maximum drawdown |
| Regime preference | Intraday trend continuation and momentum scalping |
| Win rate target (qualitative) | High (70-80% win rate) |

---

## 6. Source Citation

This card was mechanised from:

**Source ID:** `forexfactory-thv-cobra-trix-scalper-official-source`
**Source type:** `forum`
**Pointer:** `Cobraforex (2009-2024). THV System V3/V4. Forex Factory (>8M Views).`
**R1–R4 verdict (Q00):** all PASS / see `artifacts/cards_approved/QM5_39004_forexfactory-thv-cobra-trix-scalper.md`

---

## 7. Risk Model

| Phase | Risk mode | Value |
|---|---|---|
| Backtest (Q02 – Q10) | RISK_FIXED | $1,000 per trade (HR4) |
| Live burn-in (Q13) | RISK_PERCENT | Min-lot equivalent |
| Full live (post-Q13 PASS) | RISK_PERCENT | Allocated by Q11 portfolio (typically 0.3% – 0.5%) |

---

## Revision History

| Version | Date | Reason | Notes |
|---|---|---|---|
| v1 | 2026-08-18 | Initial build from card | Gemini build pass |
| v2 | 2026-08-23 | Card-contract remediation | Exact Coral stop, restart-safe Trix exit, UTC rollover, loss rails, and slippage cap |
