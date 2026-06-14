# QM5_10901_carter-sma-x - Strategy Spec

**EA ID:** QM5_10901
**Slug:** carter-sma-x
**Source:** 6facee24-8a58-5bbf-88e9-38d44291db50 (see `strategy-seeds/sources/6facee24-8a58-5bbf-88e9-38d44291db50/`)
**Author of this spec:** Codex
**Last revised:** 2026-06-14

---

## 1. Strategy Logic

The EA trades the GBPUSD H1 SMA 9/100 crossover from the Carter source. It opens a long position when SMA(9) crosses above SMA(100) on the last closed H1 bar, and it opens a short position when SMA(9) crosses below SMA(100). Each entry has a fixed 50-pip stop loss and fixed 100-pip take profit. An open position is closed early when the same SMA pair crosses in the reverse direction.

---

## 2. Parameters

| Parameter | Default | Range | Meaning |
|---|---|---|---|
| `strategy_fast_sma_period` | 9 | 1-99 | Fast SMA period used for crossover signals. |
| `strategy_slow_sma_period` | 100 | 2+ | Slow SMA period; must be greater than the fast period. |
| `strategy_stop_pips` | 50 | 1+ | Fixed stop distance from entry in pips. |
| `strategy_take_pips` | 100 | 1+ | Fixed take-profit distance from entry in pips. |

Note: framework-level inputs are documented in `framework/V5_FRAMEWORK_DESIGN.md`.

---

## 3. Symbol Universe

**Designed for:**
- `GBPUSD.DWX` - Source symbol GBPUSD is present in the DWX matrix and matches the card's R3 PASS statement.

**Explicitly NOT for:**
- Other `.DWX` symbols - The approved card names GBPUSD only and does not authorize cross-symbol expansion.

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
| Trades / year / symbol | `25` |
| Typical hold time | hours to days |
| Expected drawdown profile | Trend-following whipsaws during range-bound GBPUSD periods. |
| Regime preference | trend |
| Win rate target (qualitative) | medium |

---

## 6. Source Citation

This card was mechanised from:

**Source ID:** 6facee24-8a58-5bbf-88e9-38d44291db50
**Source type:** book
**Pointer:** `G:/My Drive/QuantMechanica/Ebook/PDF resources/20 Forex Trading Strategies - Thomas Carter.pdf`, Strategy #2, page 8
**R1-R4 verdict (Q00):** all PASS / see `artifacts/cards_approved/QM5_10901_carter-sma-x.md`

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
| v1 | 2026-06-14 | Initial build from card | 6b09b6ba-adb1-4122-9541-a69475000dd9 |
