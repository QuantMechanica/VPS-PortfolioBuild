# QM5_12623_comm-mom-rev-interaction-xauusd - Strategy Spec

**EA ID:** QM5_12623
**Slug:** `comm-mom-rev-interaction-xauusd`
**Source:** `05abad87-420d-5a51-8a9b-3c35ad795385`
**Author of this spec:** Codex
**Last revised:** 2026-07-01

---

## 1. Strategy Logic

This EA trades XAUUSD once per calendar month on the first D1 bar of the new month. It computes the 3-month return from the most recently closed D1 bar to the close 63 D1 bars earlier. A positive 3-month return is a long momentum signal and a negative 3-month return is a short momentum signal.

The momentum signal is filtered by the 4-week return from the most recently closed D1 bar to the close 20 D1 bars earlier. A long signal is tradable only when the 4-week return is at least -1%. A short signal is tradable only when the 4-week return is no greater than +1%. If the short-term return contradicts the momentum direction, the EA skips a new entry for that monthly rebalance and holds any existing position. If the filtered direction flips, the EA closes the opposite position and opens the new direction. If the 3-month momentum return is exactly flat, any existing position is closed.

Each new trade uses an ATR stop: `SL = entry price +/- ATR(14, D1) * 2.5`. There is no take profit, trailing stop, break-even rule, pyramiding, or partial close.

---

## 2. Parameters

| Parameter | Default | Range | Meaning |
|---|---:|---|---|
| `strategy_momentum_lookback_d1_bars` | 63 | 21-252 | D1 lookback for the medium-term momentum return. |
| `strategy_reversal_lookback_d1_bars` | 20 | 5-63 | D1 lookback for the short-term reversal confirmation return. |
| `strategy_reversal_deadband` | 0.01 | 0.00-0.25 | Allowed short-term counter-move before a momentum setup is blocked. |
| `strategy_min_d1_bars` | 75 | 30-400 | Minimum D1 history before evaluating signals. |
| `strategy_atr_period` | 14 | 2-100 | ATR period for the hard stop. |
| `strategy_atr_sl_mult` | 2.5 | 0.5-10.0 | ATR multiple used for the hard stop. |
| `strategy_spread_days` | 20 | 0-64 | Number of recent D1 bars used to estimate median spread. |
| `strategy_spread_mult` | 3.0 | 0.0-10.0 | Skip entries when current spread is above this multiple of median D1 spread. |

---

## 3. Symbol Universe

**Designed for:**
- `XAUUSD.DWX` - gold is the approved instrument on the card and fits the commodity momentum/reversal source.

**Explicitly NOT for:**
- `XAGUSD.DWX` - not part of this approved card.
- `XTIUSD.DWX` - not part of this approved card.
- Forex, index, rate, and crypto symbols - outside the single-symbol XAUUSD approval scope.

---

## 4. Timeframe

| Aspect | Value |
|---|---|
| Base timeframe | `D1` |
| Multi-timeframe refs | none |
| Bar gating | `QM_IsNewBar(_Symbol, PERIOD_CURRENT)` with monthly rebalance key from `QM_CalendarPeriodKey(PERIOD_MN1)` |

---

## 5. Expected Behaviour

| Metric | Expected |
|---|---|
| Trades / year / symbol | about 9 |
| Typical hold time | weeks to months |
| Expected drawdown profile | commodity trend drawdowns with lower churn than short-term reversal cards |
| Regime preference | medium-term trend that is not fighting a sharp 4-week reversal |
| Win rate target (qualitative) | medium |

---

## 6. Source Citation

This card was mechanised from:

**Source ID:** `05abad87-420d-5a51-8a9b-3c35ad795385`
**Source type:** paper
**Pointer:** https://doi.org/10.1080/14697688.2018.1436534
**R1-R4 verdict (Q00):** all PASS; see `D:/QM/strategy_farm/artifacts/cards_approved/QM5_12623_comm-mom-rev-interaction-xauusd.md`

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
| v1 | 2026-07-01 | Initial build from approved card | build commit pending |
