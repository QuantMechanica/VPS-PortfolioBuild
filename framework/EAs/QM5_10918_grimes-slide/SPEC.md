# QM5_10918_grimes-slide - Strategy Spec

**EA ID:** QM5_10918
**Slug:** grimes-slide
**Source:** fbfd7f6e-462a-55c8-9efa-9005a70c9f5c
**Author of this spec:** Codex
**Last revised:** 2026-06-06

---

## 1. Strategy Logic

The EA trades sustained pressure along a Keltner channel on H4 bars. It goes long when at least five of the last eight closes are above the upper EMA(20) plus 2.25 ATR(20) band, or close enough below it, EMA(20) slopes upward, pullbacks stay shallow, and the last closed bar closes at a new five-bar high. It mirrors the same logic for shorts against the lower band. Stops start beyond the last five completed bars with an ATR buffer, then trail every three H4 bars; positions close when the last close crosses back through EMA(20) or after 30 H4 bars.

---

## 2. Parameters

| Parameter | Default | Range | Meaning |
|---|---|---|---|
| strategy_timeframe | PERIOD_H4 | H4 fixed for baseline | Timeframe used for all card logic. |
| strategy_ema_period | 20 | >= 2 | Keltner channel midline EMA period. |
| strategy_atr_period | 20 | >= 2 | ATR period for channel width, stop buffers, and stop-distance checks. |
| strategy_channel_atr_mult | 2.25 | > 0 | ATR multiplier added to and subtracted from EMA(20) for channel bands. |
| strategy_pressure_lookback | 8 | >= 1 | Number of completed bars tested for band pressure. |
| strategy_pressure_min_bars | 5 | 1 to lookback | Minimum bars that must press the relevant channel band. |
| strategy_pressure_near_atr | 0.15 | >= 0 | Distance below or above the band still counted as pressure. |
| strategy_pullback_atr_mult | 0.75 | >= 0 | Maximum allowed shallow pullback depth as a multiple of ATR(20). |
| strategy_breakout_lookback | 5 | >= 1 | Prior bars used for new high or new low trigger. |
| strategy_initial_stop_bars | 5 | >= 1 | Bars used to place the initial structural stop. |
| strategy_initial_stop_atr | 0.25 | >= 0 | ATR buffer beyond the initial structural stop. |
| strategy_max_stop_atr | 3.5 | > 0 | Reject entries whose initial stop distance exceeds this multiple of ATR. |
| strategy_trail_interval_bars | 3 | >= 1 | Bar interval for tightening the trailing stop. |
| strategy_trail_window_bars | 3 | >= 1 | Completed bars used for the trailing stop structure. |
| strategy_trail_atr_buffer | 0.20 | >= 0 | ATR buffer beyond the trailing structure stop. |
| strategy_max_hold_bars | 30 | >= 1 | Maximum holding period in H4 bars. |
| strategy_max_spread_stop_frac | 0.10 | >= 0 | Maximum spread as a fraction of initial stop distance. |

---

## 3. Symbol Universe

**Designed for:**
- XAUUSD.DWX - Gold supports ATR/Keltner trend-following regimes from the card basket.
- XTIUSD.DWX - Oil supports commodity band-slide trend regimes from the card basket.
- GDAXI.DWX - DAX index proxy for the card's GER40 target; this is the DWX matrix canonical DAX symbol.
- NDX.DWX - Nasdaq 100 index exposure from the card basket.

**Explicitly NOT for:**
- GER40.DWX - Not present in the DWX symbol matrix; GDAXI.DWX is used instead.

---

## 4. Timeframe

| Aspect | Value |
|---|---|
| Base timeframe | H4 |
| Multi-timeframe refs | none |
| Bar gating | QM_IsNewBar(_Symbol, PERIOD_CURRENT) (default) |

---

## 5. Expected Behaviour

| Metric | Expected |
|---|---|
| Trades / year / symbol | 12 |
| Typical hold time | Up to 30 H4 bars |
| Expected drawdown profile | Trend-following open-target system with losing trades controlled by ATR/structure stops. |
| Regime preference | Low-volatility band-slide trend mode on H4 |
| Win rate target (qualitative) | medium |

---

## 6. Source Citation

This card was mechanised from:

**Source ID:** fbfd7f6e-462a-55c8-9efa-9005a70c9f5c
**Source type:** blog
**Pointer:** Adam H. Grimes, Slip and slide along the bands, 2015-08-06
**R1-R4 verdict (Q00):** all PASS / see `artifacts/cards_approved/QM5_10918_grimes-slide.md`

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
| v1 | 2026-06-06 | Initial build from card | bcc7f8af-cbbe-44f3-8830-700cf9898c10 |
