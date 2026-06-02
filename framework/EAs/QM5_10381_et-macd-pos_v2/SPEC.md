# QM5_10381_et-macd-pos - Strategy Spec

**EA ID:** QM5_10381
**Slug:** `et-macd-pos`
**Source:** `d6ae8bae-7b94-5209-9be7-fb72a1c3e3fe` (see `strategy-seeds/sources/d6ae8bae-7b94-5209-9be7-fb72a1c3e3fe/`)
**Author of this spec:** Codex
**Last revised:** 2026-05-25

---

## 1. Strategy Logic

The EA trades M5 MACD signal-line crosses during the regular index session. A long entry is allowed when MACD crosses above its signal line on the last closed bar and both values are above zero. A short entry is allowed when MACD crosses below its signal line and both values are below zero. Each trade uses a fixed stop and fixed profit target by default, with a selectable ATR bracket ablation, and all open positions are closed after the session exit time.

---

## 2. Parameters

| Parameter | Default | Range | Meaning |
|---|---|---|---|
| `strategy_macd_fast` | 12 | 1-100 | Fast EMA period for MACD. |
| `strategy_macd_slow` | 26 | 2-200 | Slow EMA period for MACD; must exceed fast period. |
| `strategy_macd_signal` | 9 | 1-100 | EMA period for the MACD signal line. |
| `strategy_allow_long` | true | true/false | Enables long entries. |
| `strategy_allow_short` | true | true/false | Enables short entries. |
| `strategy_session_start_hour` | 9 | 0-23 | Broker-time session start hour. |
| `strategy_session_start_min` | 30 | 0-59 | Broker-time session start minute. |
| `strategy_entry_cutoff_hour` | 15 | 0-23 | Broker-time final entry cutoff hour. |
| `strategy_entry_cutoff_min` | 30 | 0-59 | Broker-time final entry cutoff minute. |
| `strategy_exit_hour` | 16 | 0-23 | Broker-time session flatten hour. |
| `strategy_exit_min` | 5 | 0-59 | Broker-time session flatten minute. |
| `strategy_stop_mode` | 0 | 0-1 | 0 uses source fixed money bracket; 1 uses ATR bracket. |
| `strategy_stop_money` | 600.0 | >0 | Source stop amount converted to price distance through symbol tick value. |
| `strategy_profit_money` | 400.0 | >0 | Source target amount converted to price distance through symbol tick value. |
| `strategy_atr_period` | 20 | 1-200 | ATR period used when `strategy_stop_mode=1`. |
| `strategy_atr_sl_mult` | 1.0 | >0 | ATR stop multiplier for the ATR ablation. |
| `strategy_atr_tp_mult` | 0.67 | >0 | ATR target multiplier for the ATR ablation. |
| `strategy_max_spread_points` | 0 | >=0 | Optional entry spread gate in points; 0 disables it. |

---

## 3. Symbol Universe

**Designed for:**
- `SP500.DWX` - S&P 500 index exposure named by the card and available as a backtest-only custom symbol.
- `NDX.DWX` - Nasdaq 100 index CFD fallback in the card's portable index basket.
- `WS30.DWX` - Dow 30 index CFD fallback in the card's portable index basket.
- `GDAXI.DWX` - Available DWX DAX symbol used for the card's `GER40.DWX` DAX exposure.

**Explicitly NOT for:**
- `GER40.DWX` - not present in `framework/registry/dwx_symbol_matrix.csv`; DAX exposure is registered as `GDAXI.DWX`.

---

## 4. Timeframe

| Aspect | Value |
|---|---|
| Base timeframe | `M5` |
| Multi-timeframe refs | none |
| Bar gating | `QM_IsNewBar(_Symbol, PERIOD_CURRENT)` (default) |

---

## 5. Expected Behaviour

| Metric | Expected |
|---|---|
| Trades / year / symbol | `80` |
| Typical hold time | intraday, minutes to same-session close |
| Expected drawdown profile | medium whipsaw risk from MACD momentum crosses |
| Regime preference | intraday momentum |
| Win rate target (qualitative) | medium |

---

## 6. Source Citation

This card was mechanised from:

**Source ID:** `d6ae8bae-7b94-5209-9be7-fb72a1c3e3fe`
**Source type:** `forum`
**Pointer:** `https://www.elitetrader.com/et/threads/spm-boot-camp.141888/page-9`
**R1-R4 verdict (Q00):** all PASS / see `artifacts/cards_approved/QM5_10381_et-macd-pos.md`

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
| v1 | 2026-05-25 | Initial build from card | 8204b544-07c8-4686-9022-3aaf21ea7d4b |
| v2 | 2026-06-02 | Fix qm_ea_id 9999→10381 (skeleton placeholder never updated) | ONINIT_FAILED root cause |
