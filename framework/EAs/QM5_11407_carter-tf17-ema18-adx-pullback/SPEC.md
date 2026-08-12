# QM5_11407_carter-tf17-ema18-adx-pullback — Strategy Spec

**EA ID:** QM5_11407
**Slug:** carter-tf17-ema18-adx-pullback
**Source:** 29c77a02-59bd-52f7-bcb3-b3108d5f1e79
**Author of this spec:** Codex
**Last revised:** 2026-08-02

---

## 1. Strategy Logic

On H4, the EA looks back three closed bars for the first pullback touch of EMA(18) after price was on one side of the average. ADX(12) must be above 25 both immediately before the pullback and on the touch bar; it then places a buy stop one pip above the touch-bar high in an uptrend, or a sell stop one pip below the touch-bar low in a downtrend. The stop uses the recent three-bar swing with a maximum distance of 70 pips, the target is 2.0 × ATR(14), and the stop moves to exact break-even after a favourable move of 1.0 × the entry ATR.

---

## 2. Parameters

| Parameter | Default | Range | Meaning |
|---|---:|---|---|
| strategy_ema_period | 18 | 14, 18, 21 | EMA period defining dynamic support or resistance; card P3 sweep values. |
| strategy_adx_period | 12 | 12, 14, 20 | ADX period used before and during the pullback; card P3 sweep values. |
| strategy_adx_threshold | 25.0 | 20, 25, 30 | Minimum ADX state; card P3 sweep values. |
| strategy_touch_lookback_bars | 3 | 1–3 | Number of recent closed H4 bars scanned for the first EMA touch. |
| strategy_entry_buffer_pips | 1 | 1 | Stop-entry offset beyond the touch-bar extreme. |
| strategy_swing_lookback | 3 | 2–20 | Closed bars used by the framework structure-stop helper. |
| strategy_sl_cap_pips | 70 | 1–70 | Maximum entry-to-stop distance for P2. |
| strategy_atr_period | 14 | 2–100 | ATR period used for target and break-even distance. |
| strategy_atr_tp_mult | 2.0 | > 0 | ATR multiple used for the card-authorized target alternative. |
| strategy_be_trigger_atr | 1.0 | > 0 | Favourable ATR move that triggers exact break-even. |
| strategy_spread_cap_pips | 20 | 1–20 | Maximum real spread; zero modelled DWX spread remains valid. |

Framework inputs, including RISK_PERCENT, RISK_FIXED, PORTFOLIO_WEIGHT, news, seed, stress, and Friday-close controls, are documented in framework/V5_FRAMEWORK_DESIGN.md and are not repeated here.

---

## 3. Symbol Universe

**Designed for:**

- EURUSD.DWX — liquid major FX pair explicitly named by the approved card.
- GBPUSD.DWX — liquid major FX pair explicitly named by the approved card.
- USDJPY.DWX — liquid major FX pair explicitly named by the approved card.
- AUDUSD.DWX — liquid major FX pair explicitly named by the approved card.

**Explicitly NOT for:**

- Any unregistered symbol — the card authorizes only the four FX pairs above for this build.

---

## 4. Timeframe

| Aspect | Value |
|---|---|
| Base timeframe | H4 |
| Multi-timeframe refs | none |
| Bar gating | QM_IsNewBar() on the H4 setfile chart; all signal reads explicitly use PERIOD_H4 |

---

## 5. Expected Behaviour

| Metric | Expected |
|---|---|
| Trades / year / symbol | Approximately 40, from card frontmatter. |
| Expected trade frequency | Approximately 40 per year per symbol; no separate frequency field is present in the card. |
| Typical hold time | Not stated in the approved card; exits are price-based rather than time-based. |
| Expected drawdown profile | Not stated in the approved card. |
| Regime preference | Strong H4 trends that retain ADX above 25 during an EMA18 pullback. |
| Win rate target (qualitative) | Not stated in the approved card. |

---

## 6. Source Citation

This card was mechanised from:

**Source ID:** 29c77a02-59bd-52f7-bcb3-b3108d5f1e79
**Source type:** book / local PDF
**Pointer:** Thomas Carter, 20 Trend Following Systems (2014), Strategy #17; C:\Users\Administrator\Dropbox\Finanzen\Forex\###  Forex to read\514732392-Forex-Trend-Following-Strategy.pdf
**R1–R4 verdict (Q00):** R1 lineage recorded and R2–R4 PASS per artifacts/cards_approved/QM5_11407_carter-tf17-ema18-adx-pullback.md

---

## 7. Risk Model

| Phase | Risk mode | Value |
|---|---|---|
| Backtest (Q02 – Q10) | RISK_FIXED | $1,000 per trade (HR4) |
| Live burn-in (Q13) | RISK_PERCENT | Min-lot equivalent |
| Full live (post-Q13 PASS) | RISK_PERCENT | Allocated by Q11 portfolio (typically 0.3% – 0.5%) |

ENV→mode validation is enforced by QM_FrameworkInit (EA_INPUT_RISK_MODE_MISMATCH).

---

## Revision History

| Version | Date | Reason | Notes |
|---|---|---|---|
| v1 | 2026-08-02 | Initial build from card | 3ec60180-4303-4469-998c-85f8f56afa2c |

