# QM5_11701_fsr-trix14-zerolinecross — Strategy Spec

**EA ID:** QM5_11701
**Slug:** `fsr-trix14-zerolinecross`
**Source:** `30796091-5c65-5467-9f28-77d938217c26` (see `strategy-seeds/sources/30796091-5c65-5467-9f28-77d938217c26/`)
**Author of this spec:** Claude
**Last revised:** 2026-06-11

---

## 1. Strategy Logic

The EA trades TRIX(14) zero-line crosses on the H1 timeframe. TRIX is the rate of change of a triple-smoothed 14-period EMA of close. A long entry fires when TRIX crosses from at-or-below zero to above zero on the close of an H1 bar; a short entry fires on the mirror condition. Each trade is protected by a 2×ATR(14) stop loss and a 4×ATR(14) take profit (2:1 risk-reward). Only one position per symbol is held at a time; a new signal while a position is open is skipped. An optional `strategy_exit_on_reverse` input closes the trade early on the opposite zero-cross instead of waiting for SL/TP.

---

## 2. Parameters

| Parameter | Default | Range | Meaning |
|---|---|---|---|
| `strategy_trix_period` | 14 | 5–50 | Triple-EMA smoothing period for TRIX |
| `strategy_atr_period` | 14 | 5–50 | ATR period used for stop and TP sizing |
| `strategy_atr_sl_mult` | 2.0 | 1.0–5.0 | Stop distance = N × ATR(14) |
| `strategy_atr_tp_mult` | 4.0 | 2.0–10.0 | TP distance = M × ATR(14); default gives 2:1 R:R |
| `strategy_exit_on_reverse` | false | true/false | If true, close on opposite TRIX zero-cross instead of SL/TP only |

---

## 3. Symbol Universe

**Designed for:**
- `EURUSD.DWX` — primary majors pair; high liquidity, well-behaved TRIX signals on H1
- `GBPUSD.DWX` — major pair with trending behaviour compatible with zero-line momentum
- `USDJPY.DWX` — major pair with strong directional phases; TRIX zero-cross suited to trend regime
- `AUDUSD.DWX` — major pair; commodity-linked trend properties; card-specified target

**Explicitly NOT for:**
- Indices (NDX.DWX, WS30.DWX, SP500.DWX) — card targets FX only; index point-value risk sizing differs

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
| Trades / year / symbol | ~20 |
| Typical hold time | hours to days |
| Expected drawdown profile | moderate; trend-following, whipsaw risk in ranging markets |
| Regime preference | trend |
| Win rate target (qualitative) | medium |

---

## 6. Source Citation

**Source ID:** `30796091-5c65-5467-9f28-77d938217c26`
**Source type:** forum
**Pointer:** Anonymous, 'Trix Strategy Trading System — Method #2: Zero-Line Cross', forexstrategiesresources.com (309), 2013
**R1–R4 verdict (Q00):** all PASS per `artifacts/cards_approved/QM5_11701_fsr-trix14-zerolinecross.md`

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
| v1 | 2026-06-11 | Initial build from card | fe236be4-1292-4d1f-b6d2-27946456a7ce |
