# QM5_10378_et-daily-limfade - Strategy Spec

**EA ID:** QM5_10378
**Slug:** et-daily-limfade
**Source:** d6ae8bae-7b94-5209-9be7-fb72a1c3e3fe (see `strategy-seeds/sources/d6ae8bae-7b94-5209-9be7-fb72a1c3e3fe/`)
**Author of this spec:** Codex
**Last revised:** 2026-05-25

---

## 1. Strategy Logic

The EA evaluates completed daily bars on index CFDs. It fades the prior day's extremes by placing a passive limit beyond the prior low or prior high, with the offset normalized as a fraction of ATR(14). A long limit is placed below the prior low after a down-open relative to the prior close; a short limit is placed above the prior high after an up-open relative to the prior close. Exits are bounded by an ATR stop, a target at the prior close or a minimum ATR target, a 24-hour time stop, and the framework Friday close.

---

## 2. Parameters

| Parameter | Default | Range | Meaning |
|---|---|---|---|
| `strategy_atr_period` | 14 | 1-100 | ATR period used for offset, stop, and target normalization. |
| `strategy_offset_atr` | 0.05 | 0.02-0.15 | Limit-entry offset as a fraction of ATR. |
| `strategy_stop_atr` | 1.0 | 0.5-1.5 | Protective stop distance as a multiple of ATR. |
| `strategy_target_atr` | 0.5 | 0.5-1.0 | Minimum target distance when the prior close is too close to entry. |
| `strategy_expiration_hours` | 23 | 1-48 | Pending limit order expiration in hours. |
| `strategy_max_hold_hours` | 24 | 1-72 | Maximum open-position holding time. |
| `strategy_min_spread_mult` | 4 | 1-20 | Skip entries when the ATR offset is less than this multiple of current spread. |

---

## 3. Symbol Universe

**Designed for:**
- `SP500.DWX` - S&P 500 custom-symbol port of the source ES/index logic.
- `NDX.DWX` - liquid US large-cap index CFD for Nasdaq exposure.
- `WS30.DWX` - liquid US large-cap index CFD for Dow exposure.
- `GDAXI.DWX` - canonical DWX DAX symbol, used as the available port for the card's `GER40.DWX`.

**Explicitly NOT for:**
- `GER40.DWX` - not present in `framework/registry/dwx_symbol_matrix.csv`; `GDAXI.DWX` is the registered DAX port.
- Forex, metals, and energy `.DWX` symbols - outside the card's index-CFD scope.

---

## 4. Timeframe

| Aspect | Value |
|---|---|
| Base timeframe | `D1` |
| Multi-timeframe refs | none |
| Bar gating | `QM_IsNewBar(_Symbol, PERIOD_CURRENT)` (default) |

---

## 5. Expected Behaviour

| Metric | Expected |
|---|---|
| Trades / year / symbol | 80 |
| Typical hold time | one trading day or less |
| Expected drawdown profile | Counter-extreme losses during strong trend continuation beyond prior daily extremes. |
| Regime preference | mean-revert |
| Win rate target (qualitative) | medium |

---

## 6. Source Citation

This card was mechanised from:

**Source ID:** d6ae8bae-7b94-5209-9be7-fb72a1c3e3fe
**Source type:** forum
**Pointer:** https://www.elitetrader.com/et/threads/free-code-experiment.50225/
**R1-R4 verdict (Q00):** all PASS / see `artifacts/cards_approved/QM5_10378_et-daily-limfade.md`

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
| v1 | 2026-05-25 | Initial build from card | 77c68ae8-9e9b-4f5e-b7fb-906ec3c96b2c |
