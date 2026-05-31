# QM5_10517_mql5-pct-chan - Strategy Spec

**EA ID:** QM5_10517
**Slug:** `mql5-pct-chan`
**Source:** `b8b5125a-c67f-5bbc-baff-33456e08f5b2` (see `strategy-seeds/sources/b8b5125a-c67f-5bbc-baff-33456e08f5b2/`)
**Author of this spec:** Codex
**Last revised:** 2026-05-28

---

## 1. Strategy Logic

The EA evaluates completed H1 bars against a Percentage Crossover Channel. In baseline mode it buys when the last closed bar's low touches or crosses the lower channel and sells when the last closed bar's high touches or crosses the upper channel. If the optional middle-line mode is enabled, it buys when close crosses the middle line downward and sells when close crosses the middle line upward. When an opposite signal appears while this EA already has a position open, the position is closed and the new opposite signal is submitted.

---

## 2. Parameters

| Parameter | Default | Range | Meaning |
|---|---|---|---|
| `strategy_channel_percent` | 50.0 | > 0 | Percentage channel width input from the source indicator. |
| `strategy_use_middle_cross` | false | true/false | false trades channel borders; true trades middle-line crossing mode. |
| `strategy_channel_lookback` | 300 | >= 10 | Closed-bar history used to reconstruct the recursive channel state. |
| `strategy_atr_period` | 14 | > 0 | ATR period for the hard stop. |
| `strategy_atr_sl_mult` | 1.5 | > 0 | Stop distance as ATR multiple. |
| `strategy_tp_r_multiple` | 1.25 | > 0 | Take profit distance as multiple of initial risk. |
| `strategy_reverse_trade` | false | true/false | Optional source-style inversion of signal direction, disabled for baseline. |

> Note: framework-level inputs (RISK_PERCENT, RISK_FIXED, PORTFOLIO_WEIGHT,
> qm_news_mode, qm_rng_seed, qm_stress_reject_probability, qm_friday_close_*)
> are documented in `framework/V5_FRAMEWORK_DESIGN.md`.

---

## 3. Symbol Universe

**Designed for:**
- `EURUSD.DWX` - R3 card basket FX major with liquid H1 history.
- `GBPUSD.DWX` - R3 card basket FX major with liquid H1 history.
- `USDJPY.DWX` - R3 card basket FX major with liquid H1 history.
- `XAUUSD.DWX` - R3 card basket metal symbol explicitly approved by the card.

**Explicitly NOT for:**
- Non-DWX symbols - build and pipeline use the Darwinex `.DWX` research symbols only.

---

## 4. Timeframe

| Aspect | Value |
|---|---|
| Base timeframe | `H1` |
| Multi-timeframe refs | none |
| Bar gating | `QM_IsNewBar(_Symbol, PERIOD_CURRENT)` (default) |

---

## 5. Expected Behaviour

| Metric | Expected |
|---|---|
| Trades / year / symbol | `85` |
| Typical hold time | H1 swing trades, usually hours to a few days |
| Expected drawdown profile | Mean-reversion channel entries with fixed ATR stop and 1.25R target. |
| Regime preference | channel reversion / swing-trading |
| Win rate target (qualitative) | medium |

---

## 6. Source Citation

This card was mechanised from:

**Source ID:** `b8b5125a-c67f-5bbc-baff-33456e08f5b2`
**Source type:** MQL5 CodeBase
**Pointer:** `https://www.mql5.com/en/code/19913`
**R1-R4 verdict (Q00):** all PASS / see `artifacts/cards_approved/QM5_10517_mql5-pct-chan.md`

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
| v1 | 2026-05-28 | Initial build from card | db8c5587-5ea0-4885-8eae-96a5305efbd9 |
