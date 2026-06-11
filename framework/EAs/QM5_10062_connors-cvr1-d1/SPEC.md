# QM5_10062_connors-cvr1-d1 - Strategy Spec

**EA ID:** QM5_10062
**Slug:** connors-cvr1-d1
**Source:** ef14a5d7-e3f1-52be-910a-3ca6b736a152
**Author of this spec:** Codex
**Last revised:** 2026-06-11

---

## 1. Strategy Logic

The EA trades daily index reversals from the Connors CVR 1 rule. On each D1 closed bar it reads the imported VIX daily OHLC series, buys the index when VIX makes a 5-day high and closes below its open, and sells the index when VIX makes a 5-day low and closes above its open. Entries are market entries on the next available D1 open tick, with a fixed initial stop at 2.5 times ATR(14,D1). Positions close after 3 D1 bars or earlier when the opposite CVR 1 signal appears.

---

## 2. Parameters

| Parameter | Default | Range | Meaning |
|---|---:|---|---|
| strategy_vix_symbol | VIX.DWX | valid imported custom symbol | Custom daily VIX OHLC series used for the CVR 1 signal. |
| strategy_vix_lookback | 5 | 2-20 | Number of D1 VIX bars used for the high/low extreme test. |
| strategy_atr_period | 14 | 2-100 | D1 ATR period for the fixed protective stop and spread filter. |
| strategy_atr_sl_mult | 2.5 | 0.1-10.0 | ATR multiple used to place the initial stop from entry. |
| strategy_spread_atr_mult | 0.25 | 0.0-2.0 | Maximum spread as a fraction of ATR(14,D1). |
| strategy_hold_bars | 3 | 1-10 | Maximum hold in D1 bars before strategy exit. |

Framework-level inputs are documented in `framework/V5_FRAMEWORK_DESIGN.md`.

---

## 3. Symbol Universe

**Designed for:**
- SP500.DWX - S&P 500 analogue named by the card; valid backtest-only custom symbol.
- NDX.DWX - Nasdaq 100 live-validation analogue named by the card.
- WS30.DWX - Dow 30 live-validation analogue named by the card.

**Explicitly NOT for:**
- SPX500.DWX - not the canonical available S&P 500 custom symbol.
- SPY.DWX - not present in the DWX symbol matrix for this build.
- ES.DWX - not present in the DWX symbol matrix for this build.

---

## 4. Timeframe

| Aspect | Value |
|---|---|
| Base timeframe | D1 |
| Multi-timeframe refs | VIX daily OHLC custom series; ATR(14,D1) on traded symbol |
| Bar gating | `QM_IsNewBar(_Symbol, PERIOD_CURRENT)` through framework OnTick |

---

## 5. Expected Behaviour

| Metric | Expected |
|---|---|
| Trades / year / symbol | 25 |
| Typical hold time | 2 to 3 days |
| Expected drawdown profile | Bounded by fixed 2.5 ATR initial stops and one position per symbol/magic. |
| Regime preference | Volatility reversal / short-term mean reversion |
| Win rate target (qualitative) | medium |

---

## 6. Source Citation

This card was mechanised from:

**Source ID:** ef14a5d7-e3f1-52be-910a-3ca6b736a152
**Source type:** public article
**Pointer:** https://tradingmarkets.com/recent/market_timing_using_the_vix-665086
**R1-R4 verdict (Q00):** all PASS per `artifacts/cards_approved/QM5_10062_connors-cvr1-d1.md`

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
| v1 | 2026-06-11 | Initial build from card | 7184b3a7-2d75-4d5c-82d8-7835dd4743fb |
