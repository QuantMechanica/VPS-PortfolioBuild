# QM5_10437_mql5-prevhi-brk — Strategy Spec

**EA ID:** QM5_10437
**Slug:** `mql5-prevhi-brk`
**Source:** `b8b5125a-c67f-5bbc-baff-33456e08f5b2` (see `strategy-seeds/sources/b8b5125a-c67f-5bbc-baff-33456e08f5b2/`)
**Author of this spec:** Codex
**Last revised:** 2026-05-27

---

## 1. Strategy Logic

At the start of each D1 period, the EA uses the previous D1 high and low as breakout levels while running on an H1 chart. It enters long when price breaks the previous D1 high and enters short when price breaks the previous D1 low, with at most one entry per symbol and D1 period. The stop is half of the previous D1 range, clamped between 1.0x and 2.5x ATR(14,H1), and the target is 1.0R. Positions normally close by SL or TP, with a V5 safety time stop at the next D1 period.

---

## 2. Parameters

| Parameter | Default | Range | Meaning |
|---|---|---|---|
| `strategy_level_tf` | `PERIOD_D1` | MT5 timeframe enum | Source period used for previous high/low breakout levels. |
| `strategy_atr_period` | `14` | `1..200` | ATR period for H1 stop clamp and D1 range filter. |
| `strategy_sl_range_mult` | `0.5` | `0.1..5.0` | Raw stop distance as a multiple of previous D1 range. |
| `strategy_sl_min_atr_h1` | `1.0` | `0.1..10.0` | Minimum stop distance in ATR(14,H1) multiples. |
| `strategy_sl_max_atr_h1` | `2.5` | `0.1..10.0` | Maximum stop distance in ATR(14,H1) multiples. |
| `strategy_tp_rr` | `1.0` | `0.1..10.0` | Take-profit distance in R multiples of initial stop. |
| `strategy_range_min_atr` | `0.5` | `0.1..10.0` | Minimum previous D1 range in ATR(14,D1) multiples. |
| `strategy_range_max_atr` | `2.5` | `0.1..10.0` | Maximum previous D1 range in ATR(14,D1) multiples. |
| `strategy_rollover_skip_minutes` | `10` | `0..240` | Minutes after D1 rollover during which new entries are blocked. |

---

## 3. Symbol Universe

**Designed for:**
- `EURUSD.DWX` — card R3 forex basket member with DWX OHLC and tick data.
- `GBPUSD.DWX` — card R3 forex basket member with DWX OHLC and tick data.
- `USDJPY.DWX` — card R3 forex basket member with DWX OHLC and tick data.
- `XAUUSD.DWX` — card R3 metals basket member with DWX OHLC and tick data.

**Explicitly NOT for:**
- `SPX500.DWX` — not present in the DWX symbol matrix.
- `SPY.DWX` — not present in the DWX symbol matrix.
- `ES.DWX` — not present in the DWX symbol matrix.

---

## 4. Timeframe

| Aspect | Value |
|---|---|
| Base timeframe | `H1` |
| Multi-timeframe refs | `D1` previous high/low and ATR(14,D1) range filter |
| Bar gating | `QM_IsNewBar(_Symbol, PERIOD_CURRENT)` (default) |

---

## 5. Expected Behaviour

| Metric | Expected |
|---|---|
| Trades / year / symbol | `120` |
| Typical hold time | Same D1 period, usually hours; safety exit at next D1 period. |
| Expected drawdown profile | Breakout strategy with frequent small SL/TP outcomes and volatility-filtered entries. |
| Regime preference | Volatility-expansion / breakout |
| Win rate target (qualitative) | Medium |

---

## 6. Source Citation

This card was mechanised from:

**Source ID:** `b8b5125a-c67f-5bbc-baff-33456e08f5b2`
**Source type:** `MQL5 CodeBase`
**Pointer:** `https://www.mql5.com/en/code/69545`
**R1–R4 verdict (Q00):** all PASS / see `artifacts/cards_approved/QM5_10437_mql5-prevhi-brk.md`

---

## 7. Risk Model

| Phase | Risk mode | Value |
|---|---|---|
| Backtest (Q02 – Q10) | RISK_FIXED | $1,000 per trade (HR4) |
| Live burn-in (Q13) | RISK_PERCENT | Min-lot equivalent |
| Full live (post-Q13 PASS) | RISK_PERCENT | Allocated by Q11 portfolio (typically 0.3% – 0.5%) |

ENV->mode validation is enforced by `QM_FrameworkInit` (`EA_INPUT_RISK_MODE_MISMATCH`).

---

## Revision History

| Version | Date | Reason | Notes |
|---|---|---|---|
| v1 | 2026-05-27 | Initial build from card | 1e2a43ef-a19a-4c66-beec-5fb85ce0043b |
