# QM5_11458_goodwin-friday-monday-gap-d1 - Strategy Spec

**EA ID:** QM5_11458
**Slug:** `goodwin-friday-monday-gap-d1`
**Source:** `545042dd-9b9a-5428-a067-d60fdae46c08` (see `sources/goodwin-trading-secrets-inner-circle`)
**Author of this spec:** Codex
**Last revised:** 2026-06-11

---

## 1. Strategy Logic

The EA trades a D1 Friday exhaustion setup from Andrew Goodwin's weekend-effect pattern. After a closed Friday bar, it sells when Friday opened below Thursday's open, closed below Friday's open, had a wider range than Thursday, and closed below the lowest close of the prior 10 D1 bars. It buys the mirror condition when Friday opened and closed strongly upward, range expanded, and Friday closed above the highest close of the prior 10 D1 bars. Positions use an ATR stop and are closed by the strategy exit hook on the Monday broker day.

---

## 2. Parameters

| Parameter | Default | Range | Meaning |
|---|---|---|---|
| `strategy_extreme_lookback` | 10 | 1-100 | Number of prior D1 closes, excluding the Friday signal bar, used for lowest/highest close confirmation. |
| `strategy_atr_period` | 14 | 1-200 | ATR period used for the required V5 stop. |
| `strategy_atr_sl_mult` | 2.0 | >0 | Multiplier applied to ATR(14) for stop distance. |
| `strategy_max_sl_pips` | 150.0 | 0-1000 | Maximum stop distance in pips; 0 disables the cap. |
| `strategy_friday_day` | 5 | 0-6 | Broker day-of-week value for the Friday signal bar. |
| `strategy_monday_day` | 1 | 0-6 | Broker day-of-week value for Monday exit. |

Framework-level inputs are documented in `framework/V5_FRAMEWORK_DESIGN.md`.

---

## 3. Symbol Universe

**Designed for:**
- `EURUSD.DWX` - card-listed FX major for the exploratory FX weekend-gap adaptation.
- `GBPUSD.DWX` - card-listed FX major with liquid DWX D1 history.
- `USDJPY.DWX` - card-listed FX major with liquid DWX D1 history.
- `AUDUSD.DWX` - card-listed FX major with liquid DWX D1 history.
- `USDCAD.DWX` - card-listed FX major with liquid DWX D1 history.

**Explicitly NOT for:**
- Equity index symbols - Goodwin's source used S&P futures, but this approved card specifies an FX adaptation and lists only FX majors for P2.
- Non-DWX broker symbols - the framework and registries require canonical `.DWX` symbols for research and backtest.

---

## 4. Timeframe

| Aspect | Value |
|---|---|
| Base timeframe | `D1` |
| Multi-timeframe refs | none |
| Bar gating | `QM_IsNewBar(_Symbol, PERIOD_CURRENT)` through the V5 skeleton |

---

## 5. Expected Behaviour

| Metric | Expected |
|---|---|
| Trades / year / symbol | 8 |
| Typical hold time | Weekend to Monday broker day |
| Expected drawdown profile | Low-frequency mean-reversion with gap and weekend-transfer risk. |
| Regime preference | Mean-revert after Friday range expansion and 10-bar close extreme. |
| Win rate target (qualitative) | medium |

---

## 6. Source Citation

This card was mechanised from:

**Source ID:** `545042dd-9b9a-5428-a067-d60fdae46c08`
**Source type:** book
**Pointer:** Andrew Goodwin, *Trading Secrets of the Inner Circle*, Market Place Books, 1997; local lineage captured in the approved source record.
**R1-R4 verdict (Q00):** all R1-R4 PASS per `artifacts/cards_approved/QM5_11458_goodwin-friday-monday-gap-d1.md`

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
| v1 | 2026-06-11 | Initial build from card | a5405c61-b848-41e1-ab7c-23e26c7889d6 |
