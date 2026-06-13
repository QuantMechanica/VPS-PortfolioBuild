# QM5_10608_mql5-cog - Strategy Spec

**EA ID:** QM5_10608
**Slug:** `mql5-cog`
**Source:** `b8b5125a-c67f-5bbc-baff-33456e08f5b2` (see `strategy-seeds/sources/b8b5125a-c67f-5bbc-baff-33456e08f5b2/`)
**Author of this spec:** Codex
**Last revised:** 2026-06-13

---

## 1. Strategy Logic

This EA evaluates the Center of Gravity oscillator on each completed H4 bar using the source defaults: period 10, close price, and a 3-bar signal smoothing line. It opens long when the main line crosses above the signal line and opens short when the main line crosses below the signal line. Open positions close on the opposite main/signal cross or after 16 completed H4 bars. The initial protective stop is a catastrophic 2.5 x ATR(14) stop from the entry price.

---

## 2. Parameters

| Parameter | Default | Range | Meaning |
|---|---|---|---|
| `strategy_cog_period` | 10 | 2-100 | Center of Gravity lookback period from the source default. |
| `strategy_signal_period` | 3 | 1-50 | Signal-line smoothing period from the source default. |
| `strategy_atr_period` | 14 | 2-100 | ATR period for the catastrophic stop. |
| `strategy_atr_sl_mult` | 2.5 | 0.5-10.0 | ATR multiplier for the catastrophic stop distance. |
| `strategy_max_hold_bars` | 16 | 1-200 | Time stop measured in completed base-timeframe bars. |
| `strategy_use_ema_filter` | false | true/false | Optional P3 200 EMA direction filter; disabled in baseline. |
| `strategy_ema_period` | 200 | 20-400 | EMA period used only when the optional direction filter is enabled. |

---

## 3. Symbol Universe

**Designed for:**
- `USDCHF.DWX` - Source test instrument was USDCHF on H4.
- `EURUSD.DWX` - Liquid DWX FX major suitable for closed-bar oscillator crosses.
- `GBPUSD.DWX` - Liquid DWX FX major suitable for closed-bar oscillator crosses.
- `USDJPY.DWX` - Liquid DWX FX major suitable for closed-bar oscillator crosses.
- `XAUUSD.DWX` - Liquid DWX commodity CFD included by the approved card's baseline basket.

**Explicitly NOT for:**
- Non-DWX symbols - research and backtest artifacts must use canonical `.DWX` symbols.

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
| Trades / year / symbol | `80` |
| Typical hold time | Up to 16 H4 bars, usually shorter on reverse cross |
| Expected drawdown profile | Oscillator reversal drawdown bounded by 2.5 x ATR(14) catastrophic stops |
| Regime preference | Cycle reversal / oscillator line-cross regimes |
| Win rate target (qualitative) | medium |

---

## 6. Source Citation

This card was mechanised from:

**Source ID:** `b8b5125a-c67f-5bbc-baff-33456e08f5b2`
**Source type:** MQL5 CodeBase
**Pointer:** `https://www.mql5.com/en/code/1140`
**R1-R4 verdict (Q00):** all PASS / see `artifacts/cards_approved/QM5_10608_mql5-cog.md`

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
| v1 | 2026-06-13 | Initial build from card | 4d370202-f784-4c7e-b66c-844027526706 |
