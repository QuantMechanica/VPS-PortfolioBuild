# QM5_10564_mql5-fisher-sign - Strategy Spec

**EA ID:** QM5_10564
**Slug:** `mql5-fisher-sign`
**Source:** `b8b5125a-c67f-5bbc-baff-33456e08f5b2` (see `strategy-seeds/sources/b8b5125a-c67f-5bbc-baff-33456e08f5b2/`)
**Author of this spec:** Codex
**Last revised:** 2026-05-29

---

## 1. Strategy Logic

The EA trades the Fisher_org_v1_Sign closed-bar reversal rule from the approved card. It computes the Fisher value from the selected timeframe using a high-low window and the source levels `+1.5` and `-1.5`. A long entry fires when the closed-bar Fisher value crosses up through the lower level, and a short entry fires when it crosses down through the upper level. An open long closes on the next bearish Fisher sign, and an open short closes on the next bullish Fisher sign, with the framework hard stop, target, Friday close, news, and kill-switch protections still active.

---

## 2. Parameters

| Parameter | Default | Range | Meaning |
|---|---|---|---|
| `strategy_signal_tf` | `PERIOD_H4` | M1-MN1 | Timeframe used for the Fisher signal calculation. |
| `strategy_fisher_length` | `7` | `2-200` | High-low lookback length used by the Fisher_org_v1_Sign formula. |
| `strategy_fisher_up_level` | `1.5` | `0.1-5.0` | Upper Fisher level; crossing down through it creates a bearish sign. |
| `strategy_fisher_dn_level` | `-1.5` | `-5.0--0.1` | Lower Fisher level; crossing up through it creates a bullish sign. |
| `strategy_fisher_warmup_bars` | `300` | `50-2000` | Closed-bar history used to stabilise the recursive Fisher value. |
| `strategy_atr_period` | `14` | `2-200` | ATR period used for the hard stop. |
| `strategy_atr_sl_mult` | `2.0` | `0.1-10.0` | ATR multiplier for initial stop distance. |
| `strategy_target_r_multiple` | `1.5` | `0.1-10.0` | Profit target expressed as R multiple of the stop distance. |

> Note: framework-level inputs (RISK_PERCENT, RISK_FIXED, PORTFOLIO_WEIGHT,
> qm_news_mode, qm_rng_seed, qm_stress_reject_probability, qm_friday_close_*)
> are documented in `framework/V5_FRAMEWORK_DESIGN.md` - do NOT re-document
> them here. Only list strategy-specific inputs.

---

## 3. Symbol Universe

**Designed for:**
- `AUDUSD.DWX` - source test used AUDUSD H4 and the pair is in the approved R3 basket.
- `EURUSD.DWX` - liquid major FX pair suitable for portable oscillator reversal logic.
- `GBPUSD.DWX` - liquid major FX pair suitable for portable oscillator reversal logic.
- `XAUUSD.DWX` - liquid metal CFD included in the approved R3 basket.

**Explicitly NOT for:**
- Non-DWX symbols - build and backtest artifacts must use canonical `.DWX` names only.

---

## 4. Timeframe

| Aspect | Value |
|---|---|
| Base timeframe | `H4` |
| Multi-timeframe refs | none |
| Bar gating | `QM_IsNewBar(_Symbol, PERIOD_CURRENT)` (default) |

---

## 5. Expected Behaviour

| Metric | Expected |
|---|---|
| Trades / year / symbol | `50` |
| Typical hold time | hours to several days |
| Expected drawdown profile | Moderate oscillator-reversal drawdowns during persistent one-way trends. |
| Regime preference | mean-revert / oscillator reversal |
| Win rate target (qualitative) | medium |

---

## 6. Source Citation

This card was mechanised from:

**Source ID:** `b8b5125a-c67f-5bbc-baff-33456e08f5b2`
**Source type:** MQL5 CodeBase
**Pointer:** `https://www.mql5.com/en/code/15887`
**R1-R4 verdict (Q00):** all PASS / see `artifacts/cards_approved/QM5_10564_mql5-fisher-sign.md`

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
| v1 | 2026-05-29 | Initial build from card | 0df54ab6-c94a-4d03-a35c-46e249e1df37 |
