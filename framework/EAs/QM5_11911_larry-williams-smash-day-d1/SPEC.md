# QM5_11911_larry-williams-smash-day-d1 - Strategy Spec

**EA ID:** QM5_11911
**Slug:** larry-williams-smash-day-d1
**Source:** c2f8e3d5-4a91-5b67-9c48-a3b7d6e4f2c9
**Author of this spec:** Codex
**Last revised:** 2026-07-08

---

## 1. Strategy Logic

The EA trades Larry Williams' D1 Smash Day reversal on liquid DWX forex pairs. A bullish setup requires a D1 bar with higher high, higher low, and higher close versus the prior bar, but with a close substantially below its own open by more than 0.5 ATR(14); a bearish setup is the mirror. A triggered long buys after the setup high is breached, a triggered short sells after the setup low is breached, with the stop beyond the setup bar and a 2R target.

---

## 2. Parameters

| Parameter | Default | Range | Meaning |
|---|---|---|---|
| strategy_atr_period | 14 | 2-100 | ATR period used to define a substantial open-close reversal. |
| strategy_atr_smash_mult | 0.5 | 0.1-3.0 | Minimum open-close distance as a multiple of ATR. |
| strategy_order_validity | 5 | 1-20 | Number of D1 bars a detected setup remains valid. |
| strategy_rr_ratio | 2.0 | 0.5-5.0 | Take-profit multiple of initial stop distance. |
| strategy_time_stop_bars | 10 | 1-60 | Maximum D1 bars to hold a position. |
| strategy_buffer_pips | 1.0 | 0.0-20.0 | Break trigger buffer beyond the setup bar extreme. |

---

## 3. Symbol Universe

**Designed for:**
- EURUSD.DWX - major FX pair with deep DWX history.
- GBPUSD.DWX - major FX pair with deep DWX history.
- USDJPY.DWX - major FX pair with deep DWX history.
- USDCAD.DWX - major FX pair with deep DWX history.
- USDCHF.DWX - major FX pair with deep DWX history.
- AUDUSD.DWX - major FX pair with deep DWX history.
- NZDUSD.DWX - major FX pair with deep DWX history.
- EURJPY.DWX - liquid FX cross included by the approved card.
- GBPJPY.DWX - liquid FX cross included by the approved card.
- AUDJPY.DWX - liquid FX cross included by the approved card.

**Explicitly NOT for:**
- Non-DWX symbols - the V5 farm only backtests registered DWX instruments.
- Illiquid/exotic FX crosses - the source pattern relies on clean daily OHLC structure.

---

## 4. Timeframe

| Aspect | Value |
|---|---|
| Base timeframe | D1 |
| Multi-timeframe refs | none |
| Bar gating | QM_IsNewBar(_Symbol, PERIOD_CURRENT) |

---

## 5. Expected Behaviour

| Metric | Expected |
|---|---|
| Trades / year / symbol | 30 |
| Typical hold time | 1 to 10 trading days |
| Expected drawdown profile | Medium; clustered losses in persistent trends without reversal follow-through. |
| Regime preference | Intra-bar exhaustion reversal after directional daily pressure. |
| Win rate target (qualitative) | Medium, with positive expectancy driven by 2R winners. |

---

## 6. Source Citation

This card was mechanised from:

**Source ID:** c2f8e3d5-4a91-5b67-9c48-a3b7d6e4f2c9
**Source type:** seminar manual / book-lineage strategy source
**Pointer:** D:/QM/strategy_farm/artifacts/cards_approved/QM5_11911_larry-williams-smash-day-d1.md
**R1-R4 verdict (Q00):** all PASS / see artifacts/cards_approved/QM5_11911_larry-williams-smash-day-d1.md

---

## 7. Risk Model

| Phase | Risk mode | Value |
|---|---|---|
| Backtest (Q02 - Q10) | RISK_FIXED | $1,000 per trade (HR4) |
| Live burn-in (Q13) | RISK_PERCENT | Min-lot equivalent |
| Full live (post-Q13 PASS) | RISK_PERCENT | Allocated by Q11 portfolio (typically 0.3% - 0.5%) |

ENV to mode validation is enforced by QM_FrameworkInit (EA_INPUT_RISK_MODE_MISMATCH).

---

## Revision History

| Version | Date | Reason | Notes |
|---|---|---|---|
| v1 | 2026-07-08 | Reconstructed missing Q01 spec during Q02 ONINIT infra repair | 2223a6fb-cc63-493e-8059-c844da84358e |
