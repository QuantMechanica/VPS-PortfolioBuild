# QM5_9504_brooks-failed-channel-h4 - Strategy Spec

**EA ID:** QM5_9504
**Slug:** brooks-failed-channel-h4
**Source:** 6e967762-b26d-59a3-b076-35c17f2e7c36
**Author of this spec:** Codex
**Last revised:** 2026-07-07

---

## 1. Strategy Logic

This EA looks for a slow, narrow H4 channel without a preceding spike bar. An up-channel must drift higher for 6-14 bars, stay within a 2.5 ATR range, then fail by closing back below the channel origin; a final bearish reversal bar confirms the short. A down-channel mirrors the same rules for a long. The EA enters at market on the next H4 bar, uses a structural stop beyond the post-break recovery extreme, and exits by projected origin target, time stop, framework Friday close, or broker SL/TP.

---

## 2. Parameters

| Parameter | Default | Range | Meaning |
|---|---:|---|---|
| strategy_tf | PERIOD_H4 | H4 | Signal timeframe from the card. |
| strategy_atr_period | 14 | 10-20 | ATR period for channel scaling, break thresholds, stops, and spread cap. |
| strategy_channel_min_bars | 6 | 6-14 | Minimum pure-channel length. |
| strategy_channel_max_bars | 14 | 6-14 | Maximum pure-channel length. |
| strategy_stage2_max_bars | 12 | 8-16 | Maximum bars from channel anchor to origin break. |
| strategy_stage3_max_bars | 8 | 5-10 | Maximum bars from break to confirming reversal bar. |
| strategy_no_spike_atr_mult | 1.5 | 1.2-2.0 | Reject channel windows containing a wide spike bar. |
| strategy_drift_edge_min | 4 | 3-6 | Minimum directional bar-count edge inside the channel. |
| strategy_progress_atr_min | 1.0 | 0.8-1.5 | Required net channel progress versus origin. |
| strategy_range_atr_max | 2.5 | 2.0-3.0 | Maximum high-low range of the pure-channel window. |
| strategy_break_atr | 0.3 | 0.2-0.5 | Origin break threshold. |
| strategy_reversal_range_atr | 0.8 | 0.6-1.2 | Minimum confirming reversal-bar range. |
| strategy_reversal_tail_frac | 0.3 | 0.2-0.4 | Maximum wrong-side tail fraction on the confirming bar. |
| strategy_reversal_extreme_atr | 0.5 | 0.3-0.8 | Confirmation must close near the prior break extreme. |
| strategy_stop_buffer_atr | 0.3 | 0.2-0.5 | Structural stop buffer beyond recovery high/low. |
| strategy_target_projection_frac | 0.5 | 0.4-0.7 | Profit target projection from channel origin in the failure direction. |
| strategy_time_stop_bars | 24 | 16-32 | H4 bars before a strategy time exit. |
| strategy_spread_atr_max | 0.20 | 0.10-0.30 | Entry blocked if live spread exceeds this fraction of H4 ATR. |
| strategy_cooldown_bars | 24 | 12-36 | Bars to wait after a closed position before a fresh setup. |

---

## 3. Symbol Universe

**Designed for:**
- EURUSD.DWX - FX major, price-only H4 structure.
- GBPUSD.DWX - FX major, price-only H4 structure.
- USDJPY.DWX - FX major, price-only H4 structure.
- AUDUSD.DWX - FX major, price-only H4 structure.
- USDCAD.DWX - FX major, price-only H4 structure.
- USDCHF.DWX - FX major, price-only H4 structure.
- NZDUSD.DWX - FX major, price-only H4 structure.
- XAUUSD.DWX - liquid metal CFD included by the approved card.
- XTIUSD.DWX - liquid energy CFD included by the approved card.
- GDAXI.DWX - DAX index CFD included by the approved card.
- NDX.DWX - Nasdaq index CFD included by the approved card.
- WS30.DWX - Dow index CFD included by the approved card.
- UK100.DWX - FTSE index CFD included by the approved card.

**Explicitly NOT for:**
- FRA40.DWX - card-listed symbol absent from `dwx_symbol_matrix.csv` at build time.
- JP225.DWX - card-listed symbol absent from `dwx_symbol_matrix.csv` at build time.

---

## 4. Timeframe

| Aspect | Value |
|---|---|
| Base timeframe | H4 |
| Multi-timeframe refs | none |
| Bar gating | `QM_IsNewBar(_Symbol, PERIOD_CURRENT)` with H4 setfiles |

---

## 5. Expected Behaviour

| Metric | Expected |
|---|---|
| Trades / year / symbol | 24 |
| Typical hold time | Several H4 bars to 24 H4 bars |
| Expected drawdown profile | Stop-driven losses after failed channel breaks re-enter the original trend. |
| Regime preference | Mean-reversion / failed-breakout after mature pure channels |
| Win rate target (qualitative) | medium |

---

## 6. Source Citation

This card was mechanised from:

**Source ID:** 6e967762-b26d-59a3-b076-35c17f2e7c36
**Source type:** forum / book lineage
**Pointer:** `D:/QM/strategy_farm/artifacts/cards_approved/QM5_9504_brooks-failed-channel-h4.md`
**R1-R4 verdict (Q00):** all PASS per `artifacts/cards_approved/QM5_9504_brooks-failed-channel-h4.md`

---

## 7. Risk Model

| Phase | Risk mode | Value |
|---|---|---|
| Backtest (Q02 - Q10) | RISK_FIXED | $1,000 per trade (HR4) |
| Live burn-in (Q13) | RISK_PERCENT | Min-lot equivalent |
| Full live (post-Q13 PASS) | RISK_PERCENT | Allocated by Q11 portfolio (typically 0.3% - 0.5%) |

ENV->mode validation is enforced by `QM_FrameworkInit` (`EA_INPUT_RISK_MODE_MISMATCH`).

---

## Revision History

| Version | Date | Reason | Notes |
|---|---|---|---|
| v1 | 2026-07-07 | Initial build from card | ae47b4dd-f3a2-48f0-8f18-2554b3861ecc |

