# QM5_10558_mql5-mfi-slow - Strategy Spec

**EA ID:** QM5_10558
**Slug:** `mql5-mfi-slow`
**Source:** `b8b5125a-c67f-5bbc-baff-33456e08f5b2` (see MQL5 CodeBase citation)
**Author of this spec:** Codex
**Last revised:** 2026-05-29

---

## 1. Strategy Logic

The EA computes Money Flow Index on closed H6 bars and treats a slowdown reversal at an extreme as the source indicator's colored arrow event. It opens long when MFI was falling into the oversold zone and turns upward on the just-closed bar, and it opens short when MFI was rising into the overbought zone and turns downward on the just-closed bar. A long closes on the opposite bearish arrow, and a short closes on the opposite bullish arrow. Every entry also carries the P2 baseline ATR(14) 2.0 hard stop and a 1.5R target.

---

## 2. Parameters

| Parameter | Default | Range | Meaning |
|---|---|---|---|
| `strategy_signal_tf` | `PERIOD_H6` | H4-H12 sweep intended | Timeframe used for closed-bar MFI signal evaluation. |
| `strategy_mfi_period` | `14` | 2-100 | Lookback period for Money Flow Index. |
| `strategy_oversold_level` | `30.0` | 0-50 | Extreme level where bullish slowdown reversals are accepted. |
| `strategy_overbought_level` | `70.0` | 50-100 | Extreme level where bearish slowdown reversals are accepted. |
| `strategy_slowdown_bars` | `2` | 1-10 | Prior bars that must show MFI moving into the extreme before reversal. |
| `strategy_atr_period` | `14` | 2-100 | ATR period for hard stop placement. |
| `strategy_atr_sl_mult` | `2.0` | 0.1-10 | ATR multiple for initial stop loss. |
| `strategy_reward_r_multiple` | `1.5` | 0.1-10 | Take-profit distance as an R multiple of the initial stop. |
| `strategy_ema_filter_enabled` | `false` | true/false | Optional P3 EMA200 side filter from the card. |
| `strategy_ema_period` | `200` | 10-400 | EMA period used when the optional trend filter is enabled. |
| `strategy_max_spread_points` | `0` | 0-10000 | Optional spread ceiling; 0 disables this strategy-specific filter. |

---

## 3. Symbol Universe

**Designed for:**
- `GBPJPY.DWX` - primary source-test style FX cross and listed in the card basket.
- `GBPUSD.DWX` - liquid GBP major listed in the card basket.
- `EURUSD.DWX` - liquid major FX pair listed in the card basket.
- `XAUUSD.DWX` - liquid metal symbol listed in the card basket and compatible with volume-derived MFI reversal logic.

**Explicitly NOT for:**
- `SPX500.DWX` - not a canonical DWX custom symbol.

---

## 4. Timeframe

| Aspect | Value |
|---|---|
| Base timeframe | `H6` |
| Multi-timeframe refs | none by default |
| Bar gating | `QM_IsNewBar(_Symbol, PERIOD_CURRENT)` (default) |

---

## 5. Expected Behaviour

| Metric | Expected |
|---|---|
| Trades / year / symbol | `35` |
| Typical hold time | hours to days |
| Expected drawdown profile | Oscillator reversal drawdowns can cluster during persistent trends. |
| Regime preference | mean-revert |
| Win rate target (qualitative) | medium |

---

## 6. Source Citation

This card was mechanised from:

**Source ID:** `b8b5125a-c67f-5bbc-baff-33456e08f5b2`
**Source type:** MQL5 CodeBase
**Pointer:** `https://www.mql5.com/en/code/16561`
**R1-R4 verdict (Q00):** all PASS / see `artifacts/cards_approved/QM5_10558_mql5-mfi-slow.md`

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
| v1 | 2026-05-29 | Initial build from card | eca2b65c-0178-4583-ae61-277032aa3700 |
