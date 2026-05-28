# QM5_10476_mql5-pamxa - Strategy Spec

**EA ID:** QM5_10476
**Slug:** `mql5-pamxa`
**Source:** `b8b5125a-c67f-5bbc-baff-33456e08f5b2` (see `strategy-seeds/sources/b8b5125a-c67f-5bbc-baff-33456e08f5b2/`)
**Author of this spec:** Codex
**Last revised:** 2026-05-28

---

## 1. Strategy Logic

The EA waits for a completed D1 Awesome Oscillator zero-line cross to define the active regime. After a bullish D1 cross, it buys when the completed H1 Stochastic K value pulls below the lower zone; after a bearish D1 cross, it sells when H1 Stochastic K rises above the upper zone. The regime expires after five days if no H1 trigger appears. Positions use a 1.5 x H1 ATR(14) stop, a 2R target, and close on an opposite D1 AO regime cross or framework Friday close.

---

## 2. Parameters

| Parameter | Default | Range | Meaning |
|---|---|---|---|
| `strategy_ao_fast_period` | 5 | 1-100 | Fast SMA period for the D1 median-price Awesome Oscillator calculation. |
| `strategy_ao_slow_period` | 34 | 2-200 | Slow SMA period for the D1 median-price Awesome Oscillator calculation. |
| `strategy_stoch_k_period` | 5 | 1-100 | H1 Stochastic K period. |
| `strategy_stoch_d_period` | 3 | 1-50 | H1 Stochastic D period. |
| `strategy_stoch_slowing` | 3 | 1-50 | H1 Stochastic slowing period. |
| `strategy_stoch_lower_level` | 20.0 | 0-100 | Long pullback threshold after a bullish D1 AO regime cross. |
| `strategy_stoch_upper_level` | 80.0 | 0-100 | Short pullback threshold after a bearish D1 AO regime cross. |
| `strategy_regime_expiry_days` | 5 | 1-20 | Maximum age of the AO regime signal before it expires. |
| `strategy_atr_period` | 14 | 1-100 | H1 ATR period used for the stop. |
| `strategy_atr_sl_mult` | 1.5 | 0.1-10.0 | Stop distance multiplier applied to H1 ATR. |
| `strategy_target_rr` | 2.0 | 0.1-10.0 | Take-profit multiple of initial risk. |

---

## 3. Symbol Universe

**Designed for:**
- `EURUSD.DWX` - liquid DWX FX major named by the card basket.
- `GBPUSD.DWX` - liquid DWX FX major named by the card basket.
- `USDJPY.DWX` - liquid DWX FX major named by the card basket.
- `USDCHF.DWX` - liquid DWX FX major named by the card basket.
- `USDCAD.DWX` - liquid DWX FX major named by the card basket.
- `AUDUSD.DWX` - liquid DWX FX major named by the card basket.
- `NZDUSD.DWX` - liquid DWX FX major named by the card basket.
- `XAUUSD.DWX` - liquid DWX gold symbol explicitly included by the card.

**Explicitly NOT for:**
- Non-DWX symbols - registry and pipeline runs require canonical `.DWX` names.

---

## 4. Timeframe

| Aspect | Value |
|---|---|
| Base timeframe | `H1` |
| Multi-timeframe refs | `D1` Awesome Oscillator regime, `H1` Stochastic trigger and ATR stop |
| Bar gating | `QM_IsNewBar(_Symbol, PERIOD_CURRENT)` for entries; `QM_IsNewBar(_Symbol, PERIOD_D1)` for AO exit checks |

---

## 5. Expected Behaviour

| Metric | Expected |
|---|---|
| Trades / year / symbol | `30` |
| Typical hold time | Not specified in frontmatter; expected to be hours to days due to H1 entries with D1 regime gating. |
| Expected drawdown profile | Not specified in frontmatter; fixed-risk, one-position trend-pullback exposure. |
| Regime preference | Momentum pullback within D1 AO trend regime. |
| Win rate target (qualitative) | Not specified in frontmatter; medium target implied by 2R exits. |

---

## 6. Source Citation

This card was mechanised from:

**Source ID:** `b8b5125a-c67f-5bbc-baff-33456e08f5b2`
**Source type:** MQL5 CodeBase
**Pointer:** MQL5 CodeBase, "Day Trading PAMXA - expert for MetaTrader 5", https://www.mql5.com/en/code/23201
**R1-R4 verdict (Q00):** all R1-R4 PASS per `artifacts/cards_approved/QM5_10476_mql5-pamxa.md`

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
| v1 | 2026-05-28 | Initial build from card | b69ae29d-1c11-4d28-9b4c-505dde9995c7 |
