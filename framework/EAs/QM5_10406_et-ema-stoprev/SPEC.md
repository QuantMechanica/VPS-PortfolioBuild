# QM5_10406_et-ema-stoprev - Strategy Spec

**EA ID:** QM5_10406
**Slug:** `et-ema-stoprev`
**Source:** `d6ae8bae-7b94-5209-9be7-fb72a1c3e3fe` (see `strategy-seeds/sources/d6ae8bae-7b94-5209-9be7-fb72a1c3e3fe/`)
**Author of this spec:** Codex
**Last revised:** 2026-05-25

---

## 1. Strategy Logic

The EA runs on M1 bars and reads EMA(200) on closed prices. If the prior close was below EMA and the latest closed bar crosses above EMA, it arms a contrarian short trigger at that bar's high plus the configured tick offset. If the prior close was above EMA and the latest closed bar crosses below EMA, it arms a contrarian long trigger at that bar's low minus the configured tick offset. Open trades use a fixed ATR target, a bounded protective stop equal to the smaller of ATR stop distance and target distance, and a time exit at the session end.

---

## 2. Parameters

| Parameter | Default | Range | Meaning |
|---|---:|---|---|
| `strategy_ema_period` | 200 | 100-200 | EMA length used for the cross trigger. |
| `strategy_atr_period` | 20 | 1-100 | ATR period used for target and protective stop sizing. |
| `strategy_trigger_ticks` | 4.0 | 2.0-10.0 | Tick offset beyond the signal bar high or low. |
| `strategy_target_atr_mult` | 1.0 | 0.5-1.5 | Profit target distance as an ATR multiple. |
| `strategy_stop_atr_mult` | 1.0 | 0.5-1.5 | Protective stop ATR multiple before the target-distance cap. |
| `strategy_session_start_hhmm` | 820 | 0-2359 | Session start in HHMM form. |
| `strategy_session_end_hhmm` | 1315 | 0-2359 | Session end and time-exit point in HHMM form. |
| `strategy_max_spread_stop_pct` | 15.0 | 0.0-100.0 | Maximum spread as a percent of stop distance. |

---

## 3. Symbol Universe

**Designed for:**
- `SP500.DWX` - S&P 500 custom symbol; direct SP500/SPX/ES-style index port for backtest.
- `NDX.DWX` - Nasdaq 100 index CFD, part of the portable US large-cap basket.
- `WS30.DWX` - Dow 30 index CFD, part of the portable US large-cap basket.
- `GDAXI.DWX` - DAX 40 custom symbol; canonical DWX replacement for card-stated `GER40.DWX`.

**Explicitly NOT for:**
- `GER40.DWX` - not present in `dwx_symbol_matrix.csv`; `GDAXI.DWX` is the available DAX symbol.
- `SPX500.DWX`, `SPY.DWX`, `ES.DWX` - unavailable S&P variants; `SP500.DWX` is the canonical custom symbol.

---

## 4. Timeframe

| Aspect | Value |
|---|---|
| Base timeframe | `M1` |
| Multi-timeframe refs | none |
| Bar gating | `QM_IsNewBar(_Symbol, PERIOD_CURRENT)` (default) |

---

## 5. Expected Behaviour

| Metric | Expected |
|---|---|
| Trades / year / symbol | `90` |
| Typical hold time | Intraday, within the 08:20-13:15 session window. |
| Expected drawdown profile | High implementation risk from counterintuitive contrarian trigger direction and tight intraday targets. |
| Regime preference | Intraday EMA cross reversal / stop-entry trigger. |
| Win rate target (qualitative) | medium |

---

## 6. Source Citation

This card was mechanised from:

**Source ID:** `d6ae8bae-7b94-5209-9be7-fb72a1c3e3fe`
**Source type:** forum
**Pointer:** `https://www.elitetrader.com/et/threads/easylanguage-code.251026/`
**R1-R4 verdict (Q00):** all PASS / see `artifacts/cards_approved/QM5_10406_et-ema-stoprev.md`

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
| v1 | 2026-05-25 | Initial build from card | 2bb5b512-3aed-43aa-a117-da8f3f709bc8 |
