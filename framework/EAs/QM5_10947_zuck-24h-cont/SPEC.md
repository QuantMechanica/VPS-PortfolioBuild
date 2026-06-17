# QM5_10947_zuck-24h-cont - Strategy Spec

**EA ID:** QM5_10947
**Slug:** zuck-24h-cont
**Source:** 21ef3dfd-fac6-5d5d-b9a0-5ba447992f94
**Author of this spec:** Codex
**Last revised:** 2026-06-17

---

## 1. Strategy Logic

This EA trades a daily twenty-four-hour continuation rule. On each new D1 bar it compares the prior daily close with the day before it, computes `ret1 = close_D1[1] / close_D1[2] - 1`, and opens long when that return is greater than `trigger_atr_frac * ATR(14,D1) / close_D1[2]`. It opens short when the prior-day return is below the negative threshold, uses an ATR emergency stop, skips Friday entries by default, and exits after the configured hold period.

---

## 2. Parameters

| Parameter | Default | Range | Meaning |
|---|---:|---|---|
| `strategy_trigger_atr_frac` | 0.25 | 0.10-0.40 | Minimum prior-day move as a fraction of ATR divided by price. |
| `strategy_atr_period` | 14 | fixed by card | ATR period used for the entry threshold and emergency stop. |
| `strategy_atr_stop_mult` | 1.25 | 0.8-1.75 | Stop distance as a multiple of D1 ATR. |
| `strategy_hold_hours` | 24 | 12-36 | Time stop in broker-time hours after position open. |
| `strategy_skip_friday` | true | true/false | Blocks new Friday entries to avoid weekend holds. |
| `strategy_spread_atr_h1_pd` | 14 | fixed by card | H1 ATR period for the spread cap. |
| `strategy_spread_pct_of_atr_h1` | 10.0 | fixed by card | Blocks entries when spread exceeds this percent of H1 ATR. |

---

## 3. Symbol Universe

**Designed for:**
- `EURUSD.DWX` - card-listed FX major with DWX OHLC availability.
- `USDJPY.DWX` - card-listed FX major with DWX OHLC availability.
- `GBPUSD.DWX` - card-listed FX major with DWX OHLC availability.
- `XAUUSD.DWX` - card-listed gold symbol with DWX OHLC availability.
- `NDX.DWX` - card-listed Nasdaq 100 index CFD with DWX OHLC availability.
- `WS30.DWX` - card-listed Dow 30 index CFD with DWX OHLC availability.

**Explicitly NOT for:**
- Symbols outside `framework/registry/dwx_symbol_matrix.csv` - no validated DWX history for Q02 baseline.

---

## 4. Timeframe

| Aspect | Value |
|---|---|
| Base timeframe | D1 |
| Multi-timeframe refs | H1 ATR for spread filter |
| Bar gating | `QM_IsNewBar(_Symbol, PERIOD_CURRENT)` via framework `OnTick` gate |

---

## 5. Expected Behaviour

| Metric | Expected |
|---|---|
| Trades / year / symbol | 180 |
| Typical hold time | 24 hours |
| Expected drawdown profile | Symmetric daily momentum with ATR-defined per-trade loss cap. |
| Regime preference | Short-term momentum / daily continuation |
| Win rate target (qualitative) | Medium |

---

## 6. Source Citation

This card was mechanised from:

**Source ID:** 21ef3dfd-fac6-5d5d-b9a0-5ba447992f94
**Source type:** book
**Pointer:** Gregory Zuckerman, The Man Who Solved the Market, Portfolio/Penguin, 2019, ISBN 9780735217980.
**R1-R4 verdict (Q00):** all PASS per `artifacts/cards_approved/QM5_10947_zuck-24h-cont.md`

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
| v1 | 2026-06-17 | Initial build from card | f7cdeb44-9d50-4afe-b0a6-47dc8ef62555 |
