# QM5_11501_langer-engulfing-d1-swing - Strategy Spec

**EA ID:** QM5_11501
**Slug:** langer-engulfing-d1-swing
**Source:** 8ca13fce-d951-53be-9c60-35620d56354d
**Author of this spec:** Codex
**Last revised:** 2026-06-26

---

## 1. Strategy Logic

This EA trades daily engulfing candles in the direction of the prevailing D1 trend. A long setup requires the last closed D1 bar to engulf the prior bar, close bullish, and close above SMA(200); it places a Buy Stop five pips above that engulfing bar's high with the stop at the engulfing low. A short setup is symmetric below SMA(200), using a Sell Stop five pips below the engulfing low and the stop at the engulfing high. Once filled, the EA moves the stop to break-even after the first profitable D1 close, trails to the most recent three-bar D1 low or high, and closes after ten D1 bars if still open.

---

## 2. Parameters

| Parameter | Default | Range | Meaning |
|---|---|---|---|
| strategy_sma_period | 200 | 50-400 | D1 SMA trend-filter period. |
| strategy_entry_buffer_pips | 5.0 | 4.0-6.0 | Stop-order offset beyond the engulfing bar extreme. |
| strategy_sl_cap_pips | 100.0 | 20.0-100.0 | Maximum initial stop distance used in P2. |
| strategy_trail_bars | 3 | 2-5 | Number of closed D1 bars used for trailing low or high. |
| strategy_max_hold_bars | 10 | 1-20 | Maximum position hold in D1 bars. |
| strategy_spread_cap_pips | 30.0 | 0.0-30.0 | Blocks only genuinely wide spreads; zero modeled spread remains allowed. |
| strategy_no_friday_entry | true | true/false | Suppresses new Friday entries while allowing management and exits. |

Framework-level inputs are documented in `framework/V5_FRAMEWORK_DESIGN.md`.

---

## 3. Symbol Universe

**Designed for:**
- EURUSD.DWX - card-listed major FX pair with D1 DWX data.
- GBPUSD.DWX - card-listed major FX pair with D1 DWX data.
- USDJPY.DWX - card-listed major FX pair with D1 DWX data.
- AUDUSD.DWX - card-listed major FX pair with D1 DWX data.
- USDCAD.DWX - card-listed major FX pair with D1 DWX data.

**Explicitly NOT for:**
- Non-DWX symbols - build and backtest artifacts must use canonical `.DWX` research symbols.
- Index and commodity symbols - the card targets a D1 FX basket only.

---

## 4. Timeframe

| Aspect | Value |
|---|---|
| Base timeframe | D1 |
| Multi-timeframe refs | none |
| Bar gating | `QM_IsNewBar(_Symbol, PERIOD_CURRENT)` via the framework entry gate |

---

## 5. Expected Behaviour

| Metric | Expected |
|---|---|
| Trades / year / symbol | 40 |
| Typical hold time | 1 to 10 D1 bars |
| Expected drawdown profile | Swing-trade drawdown driven by clustered failed engulfing breakouts. |
| Regime preference | Trend-aligned reversal and continuation swing conditions. |
| Win rate target (qualitative) | medium |

---

## 6. Source Citation

This card was mechanised from:

**Source ID:** 8ca13fce-d951-53be-9c60-35620d56354d
**Source type:** book
**Pointer:** Paul Langer, "The Black Book of Forex Trading", swing trading strategy; approved card at `D:/QM/strategy_farm/artifacts/cards_approved/QM5_11501_langer-engulfing-d1-swing.md`
**R1-R4 verdict (Q00):** all R1-R4 PASS per `artifacts/cards_approved/QM5_11501_langer-engulfing-d1-swing.md`, with the card's R1 conditional source-quality note preserved.

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
| v1 | 2026-06-26 | Initial build from card | 96866d63-8663-4972-a575-5cc2a389acce |
