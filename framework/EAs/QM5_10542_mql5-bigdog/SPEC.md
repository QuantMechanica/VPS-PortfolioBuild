# QM5_10542_mql5-bigdog - Strategy Spec

**EA ID:** QM5_10542
**Slug:** `mql5-bigdog`
**Source:** `b8b5125a-c67f-5bbc-baff-33456e08f5b2` (see `strategy-seeds/sources/b8b5125a-c67f-5bbc-baff-33456e08f5b2/`)
**Author of this spec:** Codex
**Last revised:** 2026-05-29

---

## 1. Strategy Logic

After the 14:00-16:00 terminal-time window is complete, the EA measures that session's high and low on M15 bars. If the range is no wider than the configured maximum, it places a buy stop at the session high plus buffer and a sell stop at the session low minus buffer. The long stop uses the session low as SL, the short stop uses the session high as SL, both use the configured fixed-point TP, and the remaining pending order is deleted when one side fills or at the configured day-end hour.

---

## 2. Parameters

| Parameter | Default | Range | Meaning |
|---|---:|---|---|
| `strategy_timeframe` | `PERIOD_M15` | `PERIOD_M15` | Timeframe used for the source-recommended session range. |
| `strategy_range_start_h` | `14` | `0-23` | Terminal-time hour where the range measurement starts. |
| `strategy_range_end_h` | `16` | `1-23` | Terminal-time hour where the range measurement ends and orders may be placed. |
| `strategy_max_range_points` | `50` | `1+` | Maximum session range, in symbol points, allowed before skipping the day. |
| `strategy_breakout_buffer_points` | `0` | `0+` | Extra points added beyond the session high/low for stop entries. |
| `strategy_take_profit_points` | `30` | `1+` | Fixed TP distance, in symbol points, from the triggered stop entry. |
| `strategy_delete_hour` | `23` | `0-23` | Terminal-time hour when unfilled pending stop orders are deleted. |

> Note: framework-level inputs (RISK_PERCENT, RISK_FIXED, PORTFOLIO_WEIGHT,
> qm_news_mode, qm_rng_seed, qm_stress_reject_probability, qm_friday_close_*)
> are documented in `framework/V5_FRAMEWORK_DESIGN.md` and are not repeated here.

---

## 3. Symbol Universe

**Designed for:**
- `EURUSD.DWX` - source session breakout is FX-compatible and this is in the card's R3 basket.
- `GBPUSD.DWX` - source session breakout is FX-compatible and this is in the card's R3 basket.
- `XAUUSD.DWX` - source uses OHLC range and pending stops, both available on the DWX gold custom symbol.
- `GDAXI.DWX` - verified DWX DAX symbol used as the matrix-compliant port for card-stated `GER40.DWX`.

**Explicitly NOT for:**
- `GER40.DWX` - not present in `dwx_symbol_matrix.csv`; `GDAXI.DWX` is the registered DAX equivalent.

---

## 4. Timeframe

| Aspect | Value |
|---|---|
| Base timeframe | `M15` |
| Multi-timeframe refs | none |
| Bar gating | `QM_IsNewBar(_Symbol, PERIOD_CURRENT)` (default) |

---

## 5. Expected Behaviour

| Metric | Expected |
|---|---|
| Trades / year / symbol | `110` |
| Typical hold time | intraday, from afternoon breakout until SL/TP, Friday close, or broker day-end pending expiry |
| Expected drawdown profile | fixed-risk breakout losses when the 14:00-16:00 range is faded after trigger |
| Regime preference | volatility-expansion / breakout |
| Win rate target (qualitative) | medium |

---

## 6. Source Citation

This card was mechanised from:

**Source ID:** `b8b5125a-c67f-5bbc-baff-33456e08f5b2`
**Source type:** `MQL5 CodeBase`
**Pointer:** `https://www.mql5.com/en/code/17250`
**R1-R4 verdict (Q00):** all PASS / see `artifacts/cards_approved/QM5_10542_mql5-bigdog.md`

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
| v1 | 2026-05-29 | Initial build from card | 91d283d5-e2e3-4a9f-8085-87b1a1971d82 |
