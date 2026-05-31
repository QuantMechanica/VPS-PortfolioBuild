# QM5_10700_tv-liq-break - Strategy Spec

**EA ID:** QM5_10700
**Slug:** tv-liq-break
**Source:** d11962d5-19ca-5b8b-b5fc-e3bd0a620ed7 (TradingView open-source strategy)
**Author of this spec:** Codex
**Last revised:** 2026-05-31

---

## 1. Strategy Logic

The EA looks for a contraction pattern made from two recent pivot highs and two recent pivot lows. A valid contraction exists when the newest pivot high is below the prior pivot high and the newest pivot low is above the prior pivot low. On the close of a bar, the EA buys when price closes through the prior liquidity high and sells when price closes through the prior liquidity low. The P2 baseline uses an ATR stop and a fixed 2R take profit; there is no discretionary exit beyond SL, TP, and framework Friday close.

---

## 2. Parameters

| Parameter | Default | Range | Meaning |
|---|---:|---|---|
| strategy_contraction_lookback | 10 | 2+ | Pivot lookback used to confirm contraction highs and lows. |
| strategy_liquidity_length | 20 | 2+ | Number of prior closed bars used to define liquidity high and low. |
| strategy_atr_period | 20 | 1+ | ATR period for the P2 baseline stop. |
| strategy_atr_sl_mult | 3.0 | greater than 0 | ATR multiplier for stop distance. |
| strategy_target_rr | 2.0 | greater than 0 | Take-profit multiple of initial stop risk. |
| strategy_use_fixed_pct_stop | false | true/false | Secondary branch switch for the source fixed-percent stop. |
| strategy_fixed_stop_pct | 0.01 | greater than 0 | Fixed stop distance as a fraction of entry price when enabled. |
| strategy_allow_long | true | true/false | Enables long breakouts. |
| strategy_allow_short | true | true/false | Enables short breakouts. |
| strategy_max_spread_points | 0 | 0+ | Optional spread cap; 0 disables the cap. |

Framework-level inputs are documented in `framework/V5_FRAMEWORK_DESIGN.md` and are not repeated here.

---

## 3. Symbol Universe

**Designed for:**
- EURUSD.DWX - liquid major FX pair from the card's P2 basket.
- GBPUSD.DWX - liquid major FX pair from the card's P2 basket.
- USDJPY.DWX - liquid major FX pair from the card's P2 basket.
- XAUUSD.DWX - canonical DWX gold symbol for the card's XAUUSD leg.
- GDAXI.DWX - matrix-backed DAX leg used in place of card-stated GER40.DWX.
- NDX.DWX - liquid US index CFD from the card's P2 basket.

**Explicitly NOT for:**
- GER40.DWX - not present in `framework/registry/dwx_symbol_matrix.csv`; GDAXI.DWX is the registered DAX equivalent.
- Symbols outside `dwx_symbol_matrix.csv` - no broker/custom-symbol data guarantee for P2.

---

## 4. Timeframe

| Aspect | Value |
|---|---|
| Base timeframe | H1 |
| Multi-timeframe refs | none |
| Bar gating | QM_IsNewBar(_Symbol, PERIOD_CURRENT) via the framework OnTick gate |

P3 may test H4 and H6 per the card; the EA blocks timeframes outside H1, H4, and H6.

---

## 5. Expected Behaviour

| Metric | Expected |
|---|---|
| Trades / year / symbol | 80 |
| Typical hold time | Not specified in card frontmatter; expected to be hours to days because exits are ATR SL, 2R TP, and Friday close. |
| Expected drawdown profile | False breakouts after long compressions are the primary risk; wide ATR stops may reduce count on volatile CFDs. |
| Regime preference | Volatility-expansion breakout after contraction. |
| Win rate target (qualitative) | Medium; fixed 2R target allows lower hit rate than 1R exits. |

---

## 6. Source Citation

This card was mechanised from:

**Source ID:** d11962d5-19ca-5b8b-b5fc-e3bd0a620ed7
**Source type:** TradingView open-source strategy
**Pointer:** https://www.tradingview.com/script/UUHabgvo-Liquidity-Breakout-Strategy-presentTrading/
**R1-R4 verdict (Q00):** all PASS per `artifacts/cards_approved/QM5_10700_tv-liq-break.md`

---

## 7. Risk Model

| Phase | Risk mode | Value |
|---|---|---|
| Backtest (Q02 - Q10) | RISK_FIXED | $1,000 per trade (HR4) |
| Live burn-in (Q13) | RISK_PERCENT | Min-lot equivalent |
| Full live (post-Q13 PASS) | RISK_PERCENT | Allocated by Q11 portfolio, typically 0.3% to 0.5% |

ENV-to-mode validation is enforced by `QM_FrameworkInit` (`EA_INPUT_RISK_MODE_MISMATCH`).

---

## Revision History

| Version | Date | Reason | Notes |
|---|---|---|---|
| v1 | 2026-05-31 | Initial build from card | c69cf70b-2bd4-47f1-9f29-152b427ce441 |
