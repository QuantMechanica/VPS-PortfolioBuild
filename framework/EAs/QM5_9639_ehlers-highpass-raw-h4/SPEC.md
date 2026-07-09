# QM5_9639_ehlers-highpass-raw-h4 - Strategy Spec

**EA ID:** QM5_9639
**Slug:** `ehlers-highpass-raw-h4`
**Source:** `6e967762-b26d-59a3-b076-35c17f2e7c36` (see `strategy-seeds/sources/6e967762-b26d-59a3-b076-35c17f2e7c36/`)
**Author of this spec:** Codex
**Last revised:** 2026-07-09

---

## 1. Strategy Logic

This EA trades H4 turns in John Ehlers' raw high-pass filter computed from median price. It enters long when the last closed H4 high-pass value crosses above zero, the close is above EMA(100), and the high-pass magnitude is not larger than 1.2 times ATR(14). Short entries mirror the rule below zero and below EMA(100). The stop is beyond the most recent five-bar swing plus a 0.20 ATR buffer, the take-profit is 1.7R, and open trades exit on an opposite high-pass zero-cross or after 14 H4 bars.

---

## 2. Parameters

| Parameter | Default | Range | Meaning |
|---|---|---|---|
| `strategy_hp_period` | 48 | >=3 | Ehlers high-pass filter period. |
| `strategy_ema_period` | 100 | >=2 | H4 EMA trend gate period. |
| `strategy_atr_period` | 14 | >=2 | ATR period for impulse cap and swing buffer. |
| `strategy_max_hp_atr_mult` | 1.20 | >0 | Maximum absolute high-pass value versus ATR at entry. |
| `strategy_swing_lookback` | 5 | >=2 | Closed H4 bars scanned for swing stop placement. |
| `strategy_swing_atr_buffer` | 0.20 | >=0 | ATR buffer beyond the swing stop. |
| `strategy_reward_risk` | 1.70 | >0 | Fixed take-profit distance in R multiples. |
| `strategy_time_stop_h4_bars` | 14 | >=1 | H4 bars before a time-stop exit. |
| `strategy_warmup_h4_bars` | 220 | >=60 | Closed H4 bars used to seed the high-pass recurrence. |

> Note: framework-level inputs (RISK_PERCENT, RISK_FIXED, PORTFOLIO_WEIGHT,
> qm_news_mode, qm_rng_seed, qm_stress_reject_probability, qm_friday_close_*)
> are documented in `framework/V5_FRAMEWORK_DESIGN.md` - do NOT re-document
> them here. Only list strategy-specific inputs.

---

## 3. Symbol Universe

**Designed for:**
- `EURUSD.DWX` - card target FX major with liquid DWX H4 history.
- `GBPUSD.DWX` - card target FX major with liquid DWX H4 history.
- `USDJPY.DWX` - card target FX major that adds JPY-side currency diversity.
- `XAUUSD.DWX` - card target gold validation market for the same H4 filter logic.

**Explicitly NOT for:**
- Symbols outside `dwx_symbol_matrix.csv` - not valid for DWX backtest registration.
- M15 or lower timeframe scalping symbols - this card is H4 closed-bar only.

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
| Trades / year / symbol | `55` |
| Typical hold time | `hours to several days; hard time stop at 14 H4 bars` |
| Expected drawdown profile | `moderate, ATR-bounded losses during choppy filter whipsaws` |
| Regime preference | `cycle-turning-point entries aligned with H4 trend direction` |
| Win rate target (qualitative) | `medium` |

---

## 6. Source Citation

This card was mechanised from:

**Source ID:** `6e967762-b26d-59a3-b076-35c17f2e7c36`
**Source type:** `forum / Ehlers indicator lineage`
**Pointer:** `https://www.forexfactory.com/thread/post/15555134`
**R1-R4 verdict (Q00):** all PASS per `artifacts/cards_approved/QM5_9639_ehlers-highpass-raw-h4.md`

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
| v1 | 2026-07-09 | Initial build from card | 955f2332-ba67-4074-b411-57c6f82fb002 |

