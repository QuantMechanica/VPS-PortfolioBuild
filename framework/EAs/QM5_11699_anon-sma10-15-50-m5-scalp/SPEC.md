# QM5_11699_anon-sma10-15-50-m5-scalp - Strategy Spec

**EA ID:** QM5_11699
**Slug:** anon-sma10-15-50-m5-scalp
**Source:** ab5976cd-6e9a-5ef5-ae97-24e98ad245cb (see `sources/anon-5-minute-forex-scalping-strategy`)
**Author of this spec:** Codex
**Last revised:** 2026-06-11

---

## 1. Strategy Logic

This EA trades the closed M5 bar after price has fully cleared the short moving averages in the direction of the SMA(50) trend filter. A long signal requires the prior closed bar's close above SMA(50) and its low above both SMA(10) and SMA(15). A short signal requires the prior closed bar's close below SMA(50) and its high below both SMA(10) and SMA(15). Entries are market orders on the next bar with a 2 x ATR(14) stop and a 2:1 reward/risk target; there is no discretionary exit beyond SL, TP, and framework Friday close.

---

## 2. Parameters

| Parameter | Default | Range | Meaning |
|---|---|---|---|
| `strategy_fast_sma_period` | 10 | >=1 | Fast close-price SMA used as the first complete-candle clearance level. |
| `strategy_trigger_sma_period` | 15 | >=1 | Second close-price SMA that the signal candle must fully clear. |
| `strategy_trend_sma_period` | 50 | >=1 | Close-price SMA trend filter for long/short bias. |
| `strategy_atr_period` | 14 | >=1 | M5 ATR period used to size the initial stop. |
| `strategy_atr_sl_mult` | 2.0 | >0 | Stop distance multiplier applied to ATR(14). |
| `strategy_reward_risk` | 2.0 | >0 | Take-profit multiple of the stop distance. |
| `strategy_cooldown_bars` | 1 | >=0 | Minimum number of closed bars skipped after an entry signal. |

> Note: framework-level inputs (RISK_PERCENT, RISK_FIXED, PORTFOLIO_WEIGHT,
> qm_news_mode, qm_rng_seed, qm_stress_reject_probability, qm_friday_close_*)
> are documented in `framework/V5_FRAMEWORK_DESIGN.md` - do NOT re-document
> them here. Only list strategy-specific inputs.

---

## 3. Symbol Universe

**Designed for:**
- `EURUSD.DWX` - card target and available DWX major FX M5 symbol.
- `GBPUSD.DWX` - card target and available DWX major FX M5 symbol.
- `USDJPY.DWX` - card target and available DWX major FX M5 symbol.
- `AUDUSD.DWX` - card target and available DWX major FX M5 symbol.
- `USDCAD.DWX` - card target and available DWX major FX M5 symbol.

**Explicitly NOT for:**
- Non-FX index, metals, and energy `.DWX` symbols - the approved card targets only the named FX pairs.

---

## 4. Timeframe

| Aspect | Value |
|---|---|
| Base timeframe | M5 |
| Multi-timeframe refs | none |
| Bar gating | `QM_IsNewBar(_Symbol, PERIOD_CURRENT)` (default) |

---

## 5. Expected Behaviour

| Metric | Expected |
|---|---|
| Trades / year / symbol | 300 |
| Typical hold time | Intraday scalp; expected minutes to hours because TP and SL are ATR-based on M5. |
| Expected drawdown profile | Frequent small fixed-risk losses during choppy conditions, bounded per trade by the ATR stop. |
| Regime preference | Trend / scalping |
| Win rate target (qualitative) | Medium |

---

## 6. Source Citation

This card was mechanised from:

**Source ID:** ab5976cd-6e9a-5ef5-ae97-24e98ad245cb
**Source type:** self-published PDF
**Pointer:** `sources/anon-5-minute-forex-scalping-strategy`
**R1-R4 verdict (Q00):** all R1-R4 PASS per `artifacts/cards_approved/QM5_11699_anon-sma10-15-50-m5-scalp.md`

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
| v1 | 2026-06-11 | Initial build from card | 73e62034-e8eb-4980-9fd2-38fbcff32d71 |
