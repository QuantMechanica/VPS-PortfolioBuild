# QM5_10922_grimes-kc-fade — Strategy Spec

**EA ID:** QM5_10922
**Slug:** grimes-kc-fade
**Source:** fbfd7f6e-462a-55c8-9efa-9005a70c9f5c (see approved card citation)
**Author of this spec:** Codex
**Last revised:** 2026-06-06

---

## 1. Strategy Logic

This EA trades an H4 mean-reversion fade after an isolated close outside a Keltner channel. The channel midline is EMA(20), the bands are EMA(20) plus or minus 2.25 ATR(20), and an event is recorded when a closed bar finishes beyond either band by at least the same ATR distance. A long is entered when price closes back above the lower band within 3 H4 bars of a downside event; a short is entered when price closes back below the upper band within 3 H4 bars of an upside event. The stop is beyond the high or low made since the outside-band event plus 0.20 ATR, the target is the EMA touch unless that is farther than 1.25R, and open trades are force-closed after 8 H4 bars.

---

## 2. Parameters

| Parameter | Default | Range | Meaning |
|---|---|---|---|
| strategy_timeframe | PERIOD_H4 | H4 intended | Base timeframe for the Keltner fade logic |
| strategy_ema_period | 20 | >= 2 | EMA midline period |
| strategy_atr_period | 20 | >= 2 | ATR period for channel width, stop buffer, and stop-distance cap |
| strategy_keltner_atr_mult | 2.25 | > 0 | ATR multiplier for upper and lower Keltner bands |
| strategy_slope_bars | 5 | >= 1 | EMA slope lookback used to classify event context |
| strategy_trigger_window_bars | 3 | >= 1 | Maximum H4 bars allowed between outside-band event and re-entry trigger |
| strategy_slide_filter_bars | 5 | >= 1 | Blocks fades after repeated closes outside or touching the same band |
| strategy_stop_buffer_atr | 0.20 | >= 0 | ATR buffer beyond the event high or low for stop placement |
| strategy_max_stop_atr | 3.00 | > 0 | Rejects entries whose stop distance exceeds this ATR multiple |
| strategy_fallback_target_r | 1.25 | > 0 | R-multiple target used if EMA touch is farther away |
| strategy_time_exit_bars | 8 | >= 0 | Maximum holding period in H4 bars |
| strategy_max_spread_stop_frac | 0.10 | > 0 | Rejects entries when spread exceeds this fraction of stop distance |

---

## 3. Symbol Universe

**Designed for:**
- SP500.DWX — S&P 500 index exposure named in the card and present in the DWX matrix as a backtest-only custom symbol
- NDX.DWX — Nasdaq 100 index exposure named in the card and present in the DWX matrix
- GDAXI.DWX — verified DWX DAX equivalent for the card's unavailable GER40.DWX symbol
- XAUUSD.DWX — gold exposure named in the card and present in the DWX matrix

**Explicitly NOT for:**
- GER40.DWX — card-stated name is not present in `dwx_symbol_matrix.csv`; GDAXI.DWX is the registered DAX port

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
| Trades / year / symbol | 18 |
| Typical hold time | Up to 8 H4 bars |
| Expected drawdown profile | Mean-reversion losses cluster during persistent band-walk trends |
| Regime preference | Mean-revert / Keltner extension exhaustion |
| Win rate target (qualitative) | medium |

---

## 6. Source Citation

This card was mechanised from:

**Source ID:** fbfd7f6e-462a-55c8-9efa-9005a70c9f5c
**Source type:** blog
**Pointer:** Adam H. Grimes, "A shift in perspective", 2019-03-04, and "How I Trade (part 2/2)", 2023-11-06
**R1–R4 verdict (Q00):** all PASS / see `artifacts/cards_approved/QM5_10922_grimes-kc-fade.md`

---

## 7. Risk Model

| Phase | Risk mode | Value |
|---|---|---|
| Backtest (Q02 – Q10) | RISK_FIXED | $1,000 per trade (HR4) |
| Live burn-in (Q13) | RISK_PERCENT | Min-lot equivalent |
| Full live (post-Q13 PASS) | RISK_PERCENT | Allocated by Q11 portfolio (typically 0.3% – 0.5%) |

ENV->mode validation is enforced by `QM_FrameworkInit` (`EA_INPUT_RISK_MODE_MISMATCH`).

---

## Revision History

| Version | Date | Reason | Notes |
|---|---|---|---|
| v1 | 2026-06-06 | Initial build from card | 06e3ab5d-8dd7-46be-b8ba-8fa365cf0ad1 |
