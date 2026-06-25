# QM5_12493_lean-fx-sma-rev - Strategy Spec

**EA ID:** QM5_12493
**Slug:** lean-fx-sma-rev
**Source:** 0c46ae4f-60c5-56c3-92ed-17b4db7ef318 (see QuantConnect Lean source citation in the approved card)
**Author of this spec:** Codex
**Last revised:** 2026-06-25

---

## 1. Strategy Logic

The EA trades EURUSD.DWX on H1 bars. It calculates SMA(5) on closed H1 closes and looks for a reversal signal during the New York 10:00 to 15:00 session: a close crossing below the SMA enters long, and a close crossing above the SMA enters short. It does not re-enter the same signal direction until the opposite signal appears. Positions close at 15:01 New York time or when the opposite SMA-cross signal appears first.

---

## 2. Parameters

| Parameter | Default | Range | Meaning |
|---|---|---|---|
| strategy_sma_period | 5 | 3-10 in Q03 | SMA period for the closed-bar reversal signal |
| strategy_session_start_ny_hour | 10 | 9-11 in Q03 | New York session entry start hour |
| strategy_session_start_ny_min | 0 | 0-59 | New York session entry start minute |
| strategy_session_end_ny_hour | 15 | 14-16 in Q03 | New York session end hour used for entries and time exit |
| strategy_session_end_ny_min | 1 | 0-59 | Minute past session end used for the 15:01 New York flat exit |
| strategy_atr_period | 14 | fixed baseline | ATR period for the initial hard stop |
| strategy_atr_stop_mult | 2.0 | 1.5-3.0 in Q03 | Initial stop distance multiplier |
| strategy_spread_pct_of_stop | 15.0 | 0-100 | Skip entries when live spread exceeds this percent of the ATR stop distance |

---

## 3. Symbol Universe

**Designed for:**
- EURUSD.DWX - the approved card directly ports the original EURUSD forex strategy to the canonical Darwinex EURUSD custom symbol.

**Explicitly NOT for:**
- Index and commodity .DWX symbols - the source and card are FX-session reversal logic, not index or commodity market structure.

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
| Trades / year / symbol | 120 |
| Typical hold time | Intraday, from entry until 15:01 New York or opposite signal |
| Expected drawdown profile | Medium, controlled by fixed ATR stop and one-position framework behaviour |
| Regime preference | Mean-revert / intraday-session-pattern |
| Win rate target (qualitative) | Medium |

---

## 6. Source Citation

This card was mechanised from:

**Source ID:** 0c46ae4f-60c5-56c3-92ed-17b4db7ef318
**Source type:** other
**Pointer:** https://github.com/QuantConnect/Lean/blob/261366a7e26ae942df858ab20df4fef8fa07de67/Algorithm.Python/Alphas/IntradayReversalCurrencyMarketsAlpha.py#L17-L112
**R1-R4 verdict (Q00):** all PASS / see `artifacts/cards_approved/QM5_12493_lean-fx-sma-rev.md`

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
| v1 | 2026-06-25 | Initial build from card | e22dae54-8856-4bae-a84a-f52917344317 |
