# QM5_10410_et-donch-6x4 - Strategy Spec

**EA ID:** QM5_10410
**Slug:** et-donch-6x4
**Source:** d6ae8bae-7b94-5209-9be7-fb72a1c3e3fe
**Author of this spec:** Codex
**Last revised:** 2026-05-25

---

## 1. Strategy Logic

The EA trades a short Donchian breakout on the active chart timeframe. When flat, it places a buy stop at the highest high of the last 6 completed bars and a sell stop at the lowest low of the last 6 completed bars. A long position uses the lowest low of the last 4 completed bars as its channel exit stop; a short position uses the highest high of the last 4 completed bars. If that channel stop is wider than 2.5 ATR(20) from entry, the emergency ATR stop is used instead.

---

## 2. Parameters

| Parameter | Default | Range | Meaning |
|---|---|---|---|
| `strategy_entry_bars` | 6 | >=2 | Completed bars used for buy-stop high and sell-stop low. |
| `strategy_exit_bars` | 4 | >=1 | Completed bars used for channel exit stop. |
| `strategy_atr_period` | 20 | >=2 | ATR period for emergency stop distance. |
| `strategy_emergency_atr_mult` | 2.5 | >0 | Maximum stop distance from entry in ATR units. |
| `strategy_order_expiry_bars` | 1 | >=1 | Pending stop order lifetime in chart bars. |

> Note: framework-level inputs are documented in `framework/V5_FRAMEWORK_DESIGN.md`.

---

## 3. Symbol Universe

**Designed for:**
- `EURUSD.DWX` - liquid FX major named by the approved R3 basket.
- `GBPUSD.DWX` - liquid FX major named by the approved R3 basket.
- `XAUUSD.DWX` - liquid metal market named by the approved R3 basket.
- `GDAXI.DWX` - verified DWX DAX custom symbol used for the card's `GER40.DWX` intent.
- `NDX.DWX` - liquid equity index CFD named by the approved R3 basket.

**Explicitly NOT for:**
- `GER40.DWX` - not present in `framework/registry/dwx_symbol_matrix.csv`; substituted with `GDAXI.DWX`.

---

## 4. Timeframe

| Aspect | Value |
|---|---|
| Base timeframe | `H1` |
| Multi-timeframe refs | none |
| Bar gating | `QM_IsNewBar(_Symbol, PERIOD_CURRENT)` (default) |

---

## 5. Expected Behaviour

| Metric | Expected |
|---|---|
| Trades / year / symbol | `90` |
| Typical hold time | hours to a few days |
| Expected drawdown profile | Very short breakout system can whipsaw in noisy ranges. |
| Regime preference | breakout / short-horizon trend |
| Win rate target (qualitative) | medium |

---

## 6. Source Citation

This card was mechanised from:

**Source ID:** d6ae8bae-7b94-5209-9be7-fb72a1c3e3fe
**Source type:** forum
**Pointer:** https://www.elitetrader.com/et/threads/easy-language-problem.26386/
**R1-R4 verdict (Q00):** all PASS / see `artifacts/cards_approved/QM5_10410_et-donch-6x4.md`

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
| v1 | 2026-05-25 | Initial build from card | e277b402-ee19-4dac-b652-d4ddf20229d7 |
