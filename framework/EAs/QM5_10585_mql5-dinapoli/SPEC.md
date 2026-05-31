# QM5_10585_mql5-dinapoli - Strategy Spec

**EA ID:** QM5_10585
**Slug:** `mql5-dinapoli`
**Source:** `b8b5125a-c67f-5bbc-baff-33456e08f5b2` (see MQL5 CodeBase citation)
**Author of this spec:** Codex
**Last revised:** 2026-05-29

---

## 1. Strategy Logic

The EA evaluates a DiNapoli-style stochastic main/signal cross on closed H6 bars. It opens long when the just-closed bar confirms the main line crossing above the signal line, and it opens short when the just-closed bar confirms the main line crossing below the signal line. A long closes on the opposite bearish cross, and a short closes on the opposite bullish cross. Each entry also carries the P2 baseline ATR(14) 2.0 hard stop and a 1.5R target.

---

## 2. Parameters

| Parameter | Default | Range | Meaning |
|---|---|---|---|
| `strategy_signal_tf` | `PERIOD_H6` | H4-H8 sweep intended | Timeframe used for closed-bar stochastic cross evaluation. |
| `strategy_stoch_k_period` | `8` | 1+ | Stochastic main-line lookback period. |
| `strategy_stoch_d_period` | `3` | 1+ | Stochastic signal-line period. |
| `strategy_stoch_slowing` | `3` | 1+ | Stochastic slowing period. |
| `strategy_atr_period` | `14` | 2-100 | ATR period for hard stop placement. |
| `strategy_atr_sl_mult` | `2.0` | 0.1-10 | ATR multiple for initial stop loss. |
| `strategy_reward_r_multiple` | `1.5` | 0.1-10 | Take-profit distance as an R multiple of the initial stop. |
| `strategy_max_spread_points` | `0` | 0-10000 | Optional spread ceiling; 0 disables this strategy-specific filter. |

---

## 3. Symbol Universe

**Designed for:**
- `GBPJPY.DWX` - source test used GBPJPY H6 and the card lists it as the primary P2 basket member.
- `EURUSD.DWX` - liquid major FX pair listed in the card basket.
- `USDJPY.DWX` - liquid JPY major listed in the card basket.
- `XAUUSD.DWX` - liquid metal symbol listed in the card basket and compatible with oscillator cross logic.

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
| Trades / year / symbol | `40` |
| Typical hold time | hours to days |
| Expected drawdown profile | Oscillator cross drawdowns can cluster during choppy whipsaws or persistent trend reversals. |
| Regime preference | closed-bar oscillator reversal / momentum turn |
| Win rate target (qualitative) | medium |

---

## 6. Source Citation

This card was mechanised from:

**Source ID:** `b8b5125a-c67f-5bbc-baff-33456e08f5b2`
**Source type:** MQL5 CodeBase
**Pointer:** `https://www.mql5.com/en/code/13547`
**R1-R4 verdict (Q00):** all PASS / see `artifacts/cards_approved/QM5_10585_mql5-dinapoli.md`

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
| v1 | 2026-05-29 | Initial build from card | 95ef3086-beac-4f70-bc30-33ae4c88195b |
