# QM5_10570_mql5-stepma-nrtr - Strategy Spec

**EA ID:** QM5_10570
**Slug:** `mql5-stepma-nrtr`
**Source:** `b8b5125a-c67f-5bbc-baff-33456e08f5b2` (see `strategy-seeds/sources/b8b5125a-c67f-5bbc-baff-33456e08f5b2/`)
**Author of this spec:** Codex
**Last revised:** 2026-05-29

---

## 1. Strategy Logic

This EA trades the StepMA_NRTR closed-bar color point signal on H4 bars. A bullish StepMA_NRTR trend flip on the latest closed bar opens a long position when no same-symbol magic position is active; a bearish flip opens a short position under the same one-position rule. Open positions close on the opposite StepMA_NRTR point when enabled, at the broker SL/TP, at the framework Friday close, or through the V5 kill-switch. The hard stop is 2.0 ATR(14) by default and the take profit is 1.5R.

---

## 2. Parameters

| Parameter | Default | Range | Meaning |
|---|---|---|---|
| `strategy_stepma_length` | 10 | >= 2 | Volatility lookback length used by the StepMA_NRTR step-size calculation. |
| `strategy_stepma_kv` | 1.0 | > 0 | Sensitivity multiplier applied to the StepMA_NRTR step size. |
| `strategy_stepma_step_size` | 0 | >= 0 | Fixed step size in points; 0 uses the dynamic high-low range method. |
| `strategy_stepma_percentage` | 0.0 | >= 0 | Source indicator percentage offset parameter retained for P2/P3 sweeps. |
| `strategy_stepma_high_low` | true | true/false | Uses high/low mode when true and close/close mode when false. |
| `strategy_atr_period` | 14 | >= 1 | ATR period used for the V5 hard stop. |
| `strategy_atr_sl_mult` | 2.0 | > 0 | ATR multiple for the stop loss. |
| `strategy_tp_rr` | 1.5 | > 0 | Reward/risk multiple for the take profit. |
| `strategy_warmup_bars` | 180 | >= strategy_stepma_length + 20 | Closed-bar history used to seed the StepMA_NRTR state. |
| `strategy_exit_on_opposite` | true | true/false | Whether an opposite StepMA_NRTR point closes an open position. |
| `strategy_max_spread_points` | 0 | >= 0 | Optional spread guard in points; 0 disables the guard. |

---

## 3. Symbol Universe

**Designed for:**
- `EURUSD.DWX` - source test used EURUSD H4 and the card includes it in the P2 basket.
- `EURJPY.DWX` - liquid DWX FX pair suited to H4 trend color-point logic.
- `GBPJPY.DWX` - liquid DWX FX cross suited to H4 trend color-point logic.
- `XAUUSD.DWX` - DWX metals symbol included by the card for portable trend behavior.

**Explicitly NOT for:**
- Non-DWX symbols - build and pipeline artifacts must use the canonical `.DWX` matrix symbols.

---

## 4. Timeframe

| Aspect | Value |
|---|---|
| Base timeframe | `H4` |
| Multi-timeframe refs | `none` |
| Bar gating | `QM_IsNewBar(_Symbol, PERIOD_CURRENT)` (default) |

---

## 5. Expected Behaviour

| Metric | Expected |
|---|---|
| Trades / year / symbol | `35` |
| Typical hold time | `hours to days` |
| Expected drawdown profile | `moderate trend-following drawdown during choppy reversals` |
| Regime preference | `trend` |
| Win rate target (qualitative) | `medium` |

---

## 6. Source Citation

This card was mechanised from:

**Source ID:** `b8b5125a-c67f-5bbc-baff-33456e08f5b2`
**Source type:** `MQL5 CodeBase`
**Pointer:** `https://www.mql5.com/en/code/15237`
**R1-R4 verdict (Q00):** all PASS / see `artifacts/cards_approved/QM5_10570_mql5-stepma-nrtr.md`

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
| v1 | 2026-05-29 | Initial build from card | 100fcbd0-0930-472a-998f-ae534cc383c0 |
