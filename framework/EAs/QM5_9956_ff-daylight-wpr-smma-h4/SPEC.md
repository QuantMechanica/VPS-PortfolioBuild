# QM5_9956_ff-daylight-wpr-smma-h4 — Strategy Spec

**EA ID:** QM5_9956
**Slug:** `ff-daylight-wpr-smma-h4`
**Source:** `6e967762-b26d-59a3-b076-35c17f2e7c36`
**Author of this spec:** Claude
**Last revised:** 2026-06-11

---

## 1. Strategy Logic

On every closed H4 bar, the EA checks for "daylight" between a current SMMA(5) of close (green line) and the same SMMA read 5 bars earlier (red line). A long setup requires green > red by at least 0.05×ATR(14), the last H4 close above the green line, and the WPR(14) subwindow SMMA(8) above SMMA(21) by at least 2 points. If all three conditions are met, the EA may enter long at market within the next 3 H4 bars. The short setup mirrors these conditions with red > green and WPR SMMA(8) below SMMA(21). Exits fire on the earlier of: the opposite daylight or WPR-cross signal, a 12-bar time stop, or the TP at 1.2R. The stop loss is placed at the tighter of 1.2×ATR below entry or the 5-bar swing low; entry is skipped if price is more than 1.0×ATR from the green line.

---

## 2. Parameters

| Parameter | Default | Range | Meaning |
|---|---|---|---|
| `strategy_wpr_period` | 14 | 5-30 | Williams %R lookback period |
| `strategy_smma_period` | 5 | 3-20 | Period for main chart SMMA (green and red lines) |
| `strategy_smma_shift` | 5 | 1-20 | Bars separating green from red SMMA (daylight measure) |
| `strategy_wpr_smma_fast` | 8 | 3-20 | Fast SMMA period applied to WPR values |
| `strategy_wpr_smma_slow` | 21 | 5-50 | Slow SMMA period applied to WPR values |
| `strategy_atr_period` | 14 | 7-30 | ATR period for SL, spread, daylight scaling |
| `strategy_daylight_mult` | 0.05 | 0.01-0.2 | Min MA gap as fraction of ATR to confirm daylight |
| `strategy_sl_atr_mult` | 1.2 | 0.5-3.0 | SL distance = mult × ATR(14) |
| `strategy_tp_rr` | 1.2 | 0.5-5.0 | TP distance = rr × R (risk distance) |
| `strategy_entry_atr_mult` | 1.0 | 0.5-3.0 | Skip if entry farther than mult×ATR from green line |
| `strategy_max_entry_bars` | 3 | 1-5 | Max bars after first qualifying close to enter |
| `strategy_max_hold_bars` | 12 | 4-48 | Time stop in H4 bars |
| `strategy_swing_lookback` | 5 | 3-20 | Bars to scan for swing-based SL |
| `strategy_spread_atr_mult` | 0.12 | 0.05-0.5 | Skip if spread > mult × ATR |
| `strategy_wpr_min_sep` | 2.0 | 0.5-10.0 | Min WPR SMMA separation to trigger signal |

---

## 3. Symbol Universe

**Designed for:**
- `EURUSD.DWX` — major FX pair, liquid H4 bars, responsive to trend-following rules
- `GBPUSD.DWX` — major FX pair with sufficient volatility for ATR-based stops
- `USDJPY.DWX` — major FX pair, different regime characteristics add diversification
- `XAUUSD.DWX` — liquid metal, strong trending behaviour suitable for daylight strategy
- `NDX.DWX` — Nasdaq 100 index CFD, strong trend character on H4

**Explicitly NOT for:**
- `SP500.DWX` — card does not list it; use NDX.DWX for US large-cap index exposure

---

## 4. Timeframe

| Aspect | Value |
|---|---|
| Base timeframe | `H4` |
| Multi-timeframe refs | none |
| Bar gating | `QM_IsNewBar(_Symbol, PERIOD_CURRENT)` (default) + `EnsureStateAdvanced()` for WPR-SMMA cache |

---

## 5. Expected Behaviour

| Metric | Expected |
|---|---|
| Trades / year / symbol | ~40 |
| Typical hold time | 2–48 hours (4–12 H4 bars) |
| Expected drawdown profile | Medium, ~10–20% depending on symbol; SL-ATR bounded |
| Regime preference | trend |
| Win rate target (qualitative) | medium |

---

## 6. Source Citation

This card was mechanised from:

**Source ID:** `6e967762-b26d-59a3-b076-35c17f2e7c36`
**Source type:** forum
**Pointer:** LauraT, "Daylight Trading Strategy", ForexFactory, 2021, https://www.forexfactory.com/thread/1086170-daylight-trading-strategy
**R1–R4 verdict (Q00):** all PASS per `artifacts/cards_approved/QM5_9956_ff-daylight-wpr-smma-h4.md`

---

## 7. Risk Model

| Phase | Risk mode | Value |
|---|---|---|
| Backtest (Q02 – Q10) | RISK_FIXED | $1,000 per trade (HR4) |
| Live burn-in (Q13) | RISK_PERCENT | Min-lot equivalent |
| Full live (post-Q13 PASS) | RISK_PERCENT | Allocated by Q11 portfolio (typically 0.3% – 0.5%) |

ENV→mode validation is enforced by `QM_FrameworkInit` (`EA_INPUT_RISK_MODE_MISMATCH`).

---

## Revision History

| Version | Date | Reason | Notes |
|---|---|---|---|
| v1 | 2026-06-11 | Initial build from card | 087010a1-f83e-4868-8098-f59b69a9b921 |
