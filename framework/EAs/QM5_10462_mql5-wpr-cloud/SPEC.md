# QM5_10462_mql5-wpr-cloud - Strategy Spec

**EA ID:** QM5_10462
**Slug:** `mql5-wpr-cloud`
**Source:** `b8b5125a-c67f-5bbc-baff-33456e08f5b2` (see `strategy-seeds/sources/b8b5125a-c67f-5bbc-baff-33456e08f5b2/`)
**Author of this spec:** Codex
**Last revised:** 2026-05-28

---

## 1. Strategy Logic

The EA trades Williams %R zone exits on H1 bars. It enters long when Williams %R was in the lower zone on the previous closed bar and leaves that lower zone on the latest closed bar. It enters short when Williams %R was in the upper zone on the previous closed bar and leaves that upper zone on the latest closed bar. Open positions close on the opposite zone-leave signal, or through the protective ATR stop, 2R target, and framework Friday close.

---

## 2. Parameters

| Parameter | Default | Range | Meaning |
|---|---|---|---|
| `strategy_timeframe` | `PERIOD_H1` | H1 baseline | Signal timeframe for WPR and ATR reads |
| `strategy_wpr_period` | `14` | `2+` | Williams %R lookback length |
| `strategy_lower_zone` | `-80.0` | `-100` to `0` | Lower oversold zone threshold |
| `strategy_upper_zone` | `-20.0` | `-100` to `0` | Upper overbought zone threshold |
| `strategy_atr_period` | `14` | `1+` | ATR period for protective stop |
| `strategy_atr_sl_mult` | `1.5` | `>0` | ATR multiple for stop loss |
| `strategy_tp_r_mult` | `2.0` | `>0` | Protective take-profit multiple of initial risk |

---

## 3. Symbol Universe

**Designed for:**
- `EURUSD.DWX` - liquid DWX FX major with complete OHLC history for oscillator testing
- `GBPUSD.DWX` - liquid DWX FX major with complete OHLC history for oscillator testing
- `USDJPY.DWX` - liquid DWX FX major with complete OHLC history for oscillator testing
- `USDCHF.DWX` - liquid DWX FX major with complete OHLC history for oscillator testing
- `USDCAD.DWX` - liquid DWX FX major with complete OHLC history for oscillator testing
- `AUDUSD.DWX` - liquid DWX FX major with complete OHLC history for oscillator testing
- `NZDUSD.DWX` - liquid DWX FX major with complete OHLC history for oscillator testing
- `XAUUSD.DWX` - card explicitly includes XAUUSD alongside liquid FX majors

**Explicitly NOT for:**
- Index `.DWX` symbols - card scope is FX majors and XAUUSD, not equity indices

---

## 4. Timeframe

| Aspect | Value |
|---|---|
| Base timeframe | `H1` |
| Multi-timeframe refs | `none` |
| Bar gating | `QM_IsNewBar(_Symbol, PERIOD_CURRENT)` (default) |

---

## 5. Expected Behaviour

| Metric | Expected |
|---|---|
| Trades / year / symbol | `60` |
| Typical hold time | hours to a few days |
| Expected drawdown profile | bounded mean-reversion drawdowns from ATR stops and 2R targets |
| Regime preference | mean-revert / oscillator reversal |
| Win rate target (qualitative) | medium |

---

## 6. Source Citation

This card was mechanised from:

**Source ID:** `b8b5125a-c67f-5bbc-baff-33456e08f5b2`
**Source type:** `MQL5 CodeBase`
**Pointer:** `https://www.mql5.com/en/code/39767`
**R1-R4 verdict (Q00):** all PASS / see `artifacts/cards_approved/QM5_10462_mql5-wpr-cloud.md`

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
| v1 | 2026-05-28 | Initial build from card | 88406c97-317e-4bfb-b605-dccdbae647bb |
