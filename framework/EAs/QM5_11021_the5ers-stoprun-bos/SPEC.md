# QM5_11021_the5ers-stoprun-bos - Strategy Spec

**EA ID:** QM5_11021
**Slug:** the5ers-stoprun-bos
**Source:** 1d445184-7c47-57da-9856-a123682a932d (see `strategy-seeds/sources/1d445184-7c47-57da-9856-a123682a932d/`)
**Author of this spec:** Codex
**Last revised:** 2026-06-18

---

## 1. Strategy Logic

The EA trades M30 stop-hunt reversals only when D1 and H4 closes agree with EMA(50) and the latest H4 confirmed swing sequence points the same way. A long setup requires an M30 sweep below a prior confirmed swing low, a close back above that level, and a break above the last pre-sweep M30 swing high; shorts mirror the rule. The entry is a limit order at 50% of the last opposite-colour candle body before the break, with the stop beyond the stop-hunt extreme by 0.25 ATR(48), a 2R take profit, break-even after +1R, and a 24-bar time stop.

---

## 2. Parameters

| Parameter | Default | Range | Meaning |
|---|---:|---|---|
| `strategy_htf_ema_period` | 50 | >= 1 | EMA period used on D1 and H4 for directional bias. |
| `strategy_h4_swing_fractal` | 2 | >= 1 | Half-width for confirmed H4 swing sequence checks. |
| `strategy_m30_swing_fractal` | 2 | >= 1 | Half-width for confirmed M30 sweep and BOS swings. |
| `strategy_sweep_lookback` | 24 | P3 candidates 16, 24, 32 | Prior M30 bars used to find the swept swing extreme. |
| `strategy_atr_period` | 48 | >= 1 | ATR period for sweep penetration, stop buffer, and range filter. |
| `strategy_sweep_atr_mult` | 0.10 | > 0 | Minimum stop-hunt penetration as ATR multiple. |
| `strategy_max_range_atr_mult` | 2.50 | > 0 | Rejects oversized stop-hunt candles above this ATR multiple. |
| `strategy_origin_fill_pct` | 0.50 | P3 candidates 0.50, 0.618, 0.75 | Fraction of the origin candle body used for limit entry. |
| `strategy_entry_expiry_bars` | 8 | >= 1 | Pending limit order expiry in M30 bars. |
| `strategy_sl_atr_mult` | 0.25 | > 0 | ATR buffer beyond the stop-hunt extreme. |
| `strategy_tp_rr` | 2.00 | P3 candidates 1.5, 2.0 | Take-profit multiple of initial risk. |
| `strategy_time_stop_bars` | 24 | >= 1 | Maximum open hold in M30 bars. |
| `strategy_sess1_start_uk` | 6 | 0-23 | First London-local entry window start hour. |
| `strategy_sess1_end_uk` | 9 | 1-24 | First London-local entry window end hour, exclusive. |
| `strategy_sess2_start_uk` | 13 | 0-23 | Second London-local entry window start hour. |
| `strategy_sess2_end_uk` | 16 | 1-24 | Second London-local entry window end hour, exclusive. |

---

## 3. Symbol Universe

**Designed for:**
- `EURUSD.DWX` - major FX pair with DWX M30, H4, and D1 OHLC suitable for stop-run structure.
- `GBPUSD.DWX` - major FX pair with London and New York session liquidity.
- `USDJPY.DWX` - major FX pair with reliable DWX OHLC and ATR data.
- `EURJPY.DWX` - liquid FX cross with session-driven sweep behaviour.
- `GBPJPY.DWX` - liquid FX cross with high London session activity.
- `XAUUSD.DWX` - liquid CFD with DWX OHLC and ATR data for stop-run structure.

**Explicitly NOT for:**
- Non-DWX or unavailable symbols - the build registers only symbols present in `framework/registry/dwx_symbol_matrix.csv`.

---

## 4. Timeframe

| Aspect | Value |
|---|---|
| Base timeframe | `M30` |
| Multi-timeframe refs | `D1` EMA(50) and close, `H4` EMA(50), close, and swing sequence |
| Bar gating | `QM_IsNewBar(_Symbol, PERIOD_CURRENT)` (default) |

---

## 5. Expected Behaviour

| Metric | Expected |
|---|---|
| Trades / year / symbol | `80` |
| Typical hold time | Intraday, up to 24 M30 bars |
| Expected drawdown profile | Reversal setups with fixed 1R initial risk and 2R target; losses cluster in failed session reversals. |
| Regime preference | Session-reversal / liquidity-sweep with break-of-structure confirmation |
| Win rate target (qualitative) | Medium |

---

## 6. Source Citation

This card was mechanised from:

**Source ID:** `1d445184-7c47-57da-9856-a123682a932d`
**Source type:** blog
**Pointer:** `https://the5ers.com/important-characteristics/`
**R1-R4 verdict (Q00):** all PASS / see `artifacts/cards_approved/QM5_11021_the5ers-stoprun-bos.md`

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
| v1 | 2026-06-18 | Initial build from card | ce3315d8-3df4-4787-aa19-0e135abdc781 |
