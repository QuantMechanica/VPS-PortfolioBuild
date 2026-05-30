# QM5_10418_et-sma5-trend - Strategy Spec

**EA ID:** QM5_10418
**Slug:** et-sma5-trend
**Source:** d6ae8bae-7b94-5209-9be7-fb72a1c3e3fe (see `artifacts/cards_approved/QM5_10418_et-sma5-trend.md`)
**Author of this spec:** Codex
**Last revised:** 2026-05-25

---

## 1. Strategy Logic

This EA trades closed M2 bars during two intraday session windows. It enters long when the last closed bar closes above the 5-period SMA and that SMA is rising versus the prior closed bar; it enters short when the close is below the 5-period SMA and that SMA is falling. The baseline distance gate is enabled: close-to-SMA distance must be between 0.05% and 3.0% of the SMA. Open positions exit when the closed bar crosses back through the SMA, breaks the previous bar invalidation level, or the session window ends; each entry also receives a 1.0 ATR(20) emergency stop.

---

## 2. Parameters

| Parameter | Default | Range | Meaning |
|---|---:|---|---|
| `strategy_signal_tf` | `PERIOD_M2` | M2, M5 in P3 | Signal timeframe for SMA, ATR, entries, and exits. |
| `strategy_sma_period` | 5 | 5, 8, 10 in P3 | SMA period applied to close. |
| `strategy_atr_period` | 20 | fixed baseline | ATR period used for the emergency stop. |
| `strategy_atr_stop_mult` | 1.0 | 0.75-1.50 | Emergency stop distance as an ATR multiple. |
| `strategy_distance_gate_on` | true | true, false in P3 | Enables the close-to-SMA distance gate. |
| `strategy_distance_min_pct` | 0.05 | none, 0.05, 0.10 in P3 | Minimum close-to-SMA distance as percent of SMA. |
| `strategy_distance_max_pct` | 3.0 | none, 1.0, 3.0 in P3 | Maximum close-to-SMA distance as percent of SMA. |
| `strategy_session1_start_hhmm` | 1530 | 0000-2359 | First trade-window start in broker time. |
| `strategy_session1_end_hhmm` | 1730 | 0000-2359 | First trade-window end in broker time. |
| `strategy_session2_start_hhmm` | 2100 | 0000-2359 | Last-hour trade-window start in broker time. |
| `strategy_session2_end_hhmm` | 2200 | 0000-2359 | Last-hour trade-window end in broker time. |

---

## 3. Symbol Universe

**Designed for:**
- `SP500.DWX` - S&P 500 custom symbol specified by the card for S&P-specific behavior.
- `NDX.DWX` - Nasdaq 100 index exposure included in the card's portable DWX basket.
- `WS30.DWX` - Dow 30 index exposure included in the card's portable DWX basket.
- `GDAXI.DWX` - Matrix-valid DAX custom symbol used as the port for card-stated `GER40.DWX`.
- `XAUUSD.DWX` - Gold symbol specified by the card for metals testing.

**Explicitly NOT for:**
- `GER40.DWX` - not present in `framework/registry/dwx_symbol_matrix.csv`; use `GDAXI.DWX`.
- `SPX500.DWX`, `SPY.DWX`, `ES.DWX` - unavailable S&P 500 variants; use `SP500.DWX`.

---

## 4. Timeframe

| Aspect | Value |
|---|---|
| Base timeframe | `M2` |
| Multi-timeframe refs | none |
| Bar gating | `QM_IsNewBar(_Symbol, PERIOD_CURRENT)` (default) |

---

## 5. Expected Behaviour

| Metric | Expected |
|---|---|
| Trades / year / symbol | 180 |
| Typical hold time | intraday, within the first two hours or final hour session windows |
| Expected drawdown profile | short-SMA trend entries can cluster in choppy sessions; distance gate should reduce near-SMA noise |
| Regime preference | intraday trend-following |
| Win rate target (qualitative) | medium |

---

## 6. Source Citation

This card was mechanised from:

**Source ID:** d6ae8bae-7b94-5209-9be7-fb72a1c3e3fe
**Source type:** forum
**Pointer:** wdbaker, Lets build a trading system, Elite Trader, 2002-09-07, https://www.elitetrader.com/et/threads/lets-build-a-trading-system.8601/
**R1-R4 verdict (Q00):** all R1-R4 PASS per `artifacts/cards_approved/QM5_10418_et-sma5-trend.md`

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
| v1 | 2026-05-25 | Initial build from card | 2ee9592b-86d8-4d05-b6da-2bf3ae172a50 |
