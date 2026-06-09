# QM5_10242_tv-keltner-dual - Strategy Spec

**EA ID:** QM5_10242
**Slug:** tv-keltner-dual
**Source:** 30591366-874b-5bee-b47c-da2fca20b728
**Author of this spec:** Codex
**Last revised:** 2026-06-09

---

## 1. Strategy Logic

The EA implements the card's two Keltner Channel Strategy modes as a selectable input. Default trend mode buys when EMA(9) crosses above EMA(21) on the closed bar and the close is above EMA(50), and sells when EMA(9) crosses below EMA(21) while the close is below EMA(50). Reversal mode buys when the close crosses below the lower Keltner band and sells when the close crosses above the upper Keltner band. Trend positions exit on the opposite EMA(9)/EMA(21) cross; reversal positions exit when price crosses back through the Keltner middle band. All entries use a 1.5 ATR stop and 2.0 ATR target.

---

## 2. Parameters

| Parameter | Default | Range | Meaning |
|---|---:|---|---|
| strategy_mode | 0 | 0 or 1 | 0 trades trend-following EMA cross mode; 1 trades Keltner reversal mode. |
| strategy_fast_ema_period | 9 | integer > 0 | Fast EMA for trend-mode entry and exit cross. |
| strategy_slow_ema_period | 21 | integer > 0 | Slow EMA for trend-mode entry and exit cross. |
| strategy_trend_ema_period | 50 | integer > 0 | Trend-mode price filter EMA. |
| strategy_keltner_period | 20 | integer > 0 | EMA middle-line period for Keltner reversal mode. |
| strategy_keltner_atr_period | 20 | integer > 0 | ATR period for Keltner band width. |
| strategy_keltner_atr_mult | 2.0 | decimal > 0 | ATR multiplier for upper and lower Keltner bands. |
| strategy_atr_period | 14 | integer > 0 | ATR period for stop and target distance. |
| strategy_atr_sl_mult | 1.5 | decimal > 0 | ATR multiple for initial stop loss. |
| strategy_atr_tp_mult | 2.0 | decimal > 0 | ATR multiple for initial take profit. |

Framework-level inputs are documented in `framework/V5_FRAMEWORK_DESIGN.md`.

---

## 3. Symbol Universe

**Designed for:**
- XAUUSD.DWX - card highlights XAUUSD and volatility-channel behaviour suits gold.
- XTIUSD.DWX - card highlights crude oil and DWX provides the oil custom symbol.
- NDX.DWX - card highlights NASDAQ/NQ and DWX provides Nasdaq 100 exposure.
- GDAXI.DWX - DAX port for the card's GER40.DWX reference; `GER40.DWX` is not in the DWX matrix.
- SP500.DWX - card names SP500.DWX; build-time registration is valid for backtest-only S&P 500 exposure.

**Explicitly NOT for:**
- GER40.DWX - not present in `framework/registry/dwx_symbol_matrix.csv`; use GDAXI.DWX for DAX exposure.
- SPX500.DWX, SPY.DWX, ES.DWX - unavailable aliases; SP500.DWX is the canonical S&P 500 custom symbol.

---

## 4. Timeframe

| Aspect | Value |
|---|---|
| Base timeframe | H1 for smoke and P2 baseline start |
| Additional card timeframe | H4 is also generated for P2 because the card says P2 should start with H1/H4 |
| Multi-timeframe refs | none |
| Bar gating | `QM_IsNewBar()` in the framework `OnTick` path |

---

## 5. Expected Behaviour

| Metric | Expected |
|---|---|
| Trades / year / symbol | 60 |
| Expected trade frequency | medium; card implies roughly monthly-to-weekly activity across H1/H4 variants |
| Typical hold time | not stated in frontmatter; exits are signal cross, ATR stop, or ATR target |
| Expected drawdown profile | not stated in frontmatter; controlled by fixed-risk ATR stops |
| Regime preference | trend-following by default, with optional mean-reversion Keltner reversal mode |
| Win rate target (qualitative) | not specified by card |

---

## 6. Source Citation

This card was mechanised from:

**Source ID:** 30591366-874b-5bee-b47c-da2fca20b728
**Source type:** TradingView script page
**Pointer:** https://www.tradingview.com/script/OQGzolcI-Keltner-Channel-Strategy/
**R1-R4 verdict (Q00):** all PASS per `artifacts/cards_approved/QM5_10242_tv-keltner-dual.md`

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
| v1 | 2026-06-09 | Initial build from card | aea2042c-ed61-40aa-b5d6-5154db01c2d0 |
