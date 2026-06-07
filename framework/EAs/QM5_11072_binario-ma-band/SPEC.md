# QM5_11072_binario-ma-band - Strategy Spec

**EA ID:** QM5_11072
**Slug:** binario-ma-band
**Source:** 0693c604-4f96-56ef-be79-15efe9f48b86
**Author of this spec:** Codex
**Last revised:** 2026-06-07

---

## 1. Strategy Logic

The EA trades a D1 EMA channel built from two 144-period exponential moving averages: one applied to high prices and one applied to low prices. On each new D1 bar it reconciles the current pending orders and maintains a buy-stop above the high EMA plus spread and a sell-stop below the low EMA. A long trade uses the opposite low-EMA channel edge minus one pip as stop loss and a target above the high EMA; a short trade mirrors the rule below the low EMA. Open positions have their SL and TP moved as the closed-bar MA channel changes.

---

## 2. Parameters

| Parameter | Default | Range | Meaning |
|---|---|---|---|
| strategy_ma_period | 144 | 2-1000 | EMA period for the high-price and low-price channel. |
| strategy_pip_difference | 20 | 0-1000 | Pip offset added outside the EMA channel for pending stop entries. |
| strategy_take_profit_pips | 115 | 1-5000 | Additional pip distance used with the entry offset to form the take-profit level. |

Framework-level inputs are documented in `framework/V5_FRAMEWORK_DESIGN.md`.

---

## 3. Symbol Universe

**Designed for:**
- EURUSD.DWX - Source example is EUR/USD D1 and the card names it in the primary P2 basket.
- GBPUSD.DWX - Major liquid DWX FX pair named in the card's primary P2 basket.
- USDJPY.DWX - Major liquid DWX FX pair named in the card's primary P2 basket.
- USDCAD.DWX - Major liquid DWX FX pair named in the card's primary P2 basket.

**Explicitly NOT for:**
- Non-DWX symbols - Build, baseline, and registry discipline require canonical `.DWX` symbols.
- Symbols outside `dwx_symbol_matrix.csv` - The broker/tester data universe is limited to registered DWX symbols.

---

## 4. Timeframe

| Aspect | Value |
|---|---|
| Base timeframe | D1 |
| Multi-timeframe refs | none |
| Bar gating | `QM_IsNewBar(_Symbol, PERIOD_CURRENT)` via framework OnTick entry gate |

---

## 5. Expected Behaviour

| Metric | Expected |
|---|---|
| Trades / year / symbol | 26 |
| Typical hold time | Not explicit in frontmatter; D1 pending breakout interpretation implies multi-day holds until channel SL/TP. |
| Expected drawdown profile | Breakout strategy; losses are bounded by the opposite EMA channel edge plus one-pip buffer. |
| Regime preference | Not explicit in frontmatter; inferred as breakout / volatility expansion from the MA-channel stop-entry rule. |
| Win rate target (qualitative) | medium |

---

## 6. Source Citation

This card was mechanised from:

**Source ID:** 0693c604-4f96-56ef-be79-15efe9f48b86
**Source type:** GitHub repository / MQL5 source
**Pointer:** https://github.com/EarnForex/Binario and https://www.earnforex.com/metatrader-expert-advisors/Binario/
**R1-R4 verdict (Q00):** all PASS / see `artifacts/cards_approved/QM5_11072_binario-ma-band.md`

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
| v1 | 2026-06-07 | Initial build from card | 1e88c241-ec51-4716-9c04-be8d4c7fcbed |
