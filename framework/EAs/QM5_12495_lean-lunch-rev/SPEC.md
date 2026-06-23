# QM5_12495_lean-lunch-rev - Strategy Spec

**EA ID:** QM5_12495
**Slug:** lean-lunch-rev
**Source:** 0c46ae4f-60c5-56c3-92ed-17b4db7ef318
**Author of this spec:** Codex
**Last revised:** 2026-06-23

---

## 1. Strategy Logic

This EA trades H1 lunch-hour mean reversion on liquid index `.DWX` symbols. On the H1 bar whose broker-time equivalent maps to 12:00 US Eastern, it computes RateOfChangePercent over the prior three closed H1 bars. If the close-to-noon move is positive it enters short, and if the move is negative it enters long. The EA uses an ATR(14) x 2.0 hard stop and closes after one H1 bar, with no intraday re-entry after the daily lunch signal.

---

## 2. Parameters

| Parameter | Default | Range | Meaning |
|---|---:|---|---|
| strategy_lunch_hour_et | 12 | 11-13 | Lunch-hour gate in US Eastern time. |
| strategy_roc_period | 3 | 2-5 | H1 closed-bar RateOfChangePercent lookback. |
| strategy_hold_hours | 1 | 1-3 | Number of H1 bars to hold before time-stop exit. |
| strategy_atr_period | 14 | 14 fixed baseline | ATR period used for the hard stop. |
| strategy_atr_stop_mult | 2.0 | 1.5-3.0 | ATR multiplier for the hard stop. |
| strategy_roc_deadband_pct | 0.0 | 0.0+ | Minimum absolute ROC percent required to trade; zero follows the card literally. |
| strategy_spread_pct_of_stop | 15.0 | 0.0+ | Blocks only genuinely wide positive spreads relative to stop distance. |

---

## 3. Symbol Universe

**Designed for:**
- SP500.DWX - S&P 500 proxy named in the card R3 porting plan; valid backtest-only custom symbol.
- NDX.DWX - Nasdaq 100 index proxy named in the card R3 porting plan and live-routable validation basket.
- WS30.DWX - Dow 30 index proxy named in the card R3 porting plan and live-routable validation basket.

**Explicitly NOT for:**
- SPX500.DWX, SPY.DWX, ES.DWX - unavailable or non-canonical S&P variants; SP500.DWX is the canonical DWX symbol.
- Sector ETFs - the card does not specify sector-level lunch effects, and these are not in the approved R3 basket.

---

## 4. Timeframe

| Aspect | Value |
|---|---|
| Base timeframe | H1 |
| Multi-timeframe refs | none |
| Bar gating | QM_IsNewBar(_Symbol, PERIOD_CURRENT) |

---

## 5. Expected Behaviour

| Metric | Expected |
|---|---|
| Trades / year / symbol | 200 |
| Typical hold time | 1 hour |
| Expected drawdown profile | Medium risk from intraday index mean reversion with ATR stop containment. |
| Regime preference | mean-revert, intraday-session-pattern |
| Win rate target (qualitative) | medium |

---

## 6. Source Citation

This card was mechanised from:

**Source ID:** 0c46ae4f-60c5-56c3-92ed-17b4db7ef318
**Source type:** GitHub source file
**Pointer:** https://github.com/QuantConnect/Lean/blob/261366a7e26ae942df858ab20df4fef8fa07de67/Algorithm.Python/Alphas/MeanReversionLunchBreakAlpha.py#L17-L123
**R1-R4 verdict (Q00):** all R1-R4 PASS per `artifacts/cards_approved/QM5_12495_lean-lunch-rev.md`

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
| v1 | 2026-06-23 | Initial build from card | b6ebac07-7ce4-4c22-826f-2a3507da402b |
