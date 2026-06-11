# QM5_11479_davey-k-low-volume-mean-reversion-d1 - Strategy Spec

**EA ID:** QM5_11479
**Slug:** `davey-k-low-volume-mean-reversion-d1`
**Source:** `29ffaa6d-5bb8-5962-92d9-4e35a35e4d53` (see `sources/davey-kevin-my-5-favorite-entries`)
**Author of this spec:** Codex
**Last revised:** 2026-06-11

---

## 1. Strategy Logic

This EA trades a D1 low-volume mean-reversion signal from Kevin Davey's low-volume reversal entry. On each new D1 bar, it checks whether the prior bar had tick volume below the mean of the previous five bars and closed at the lowest or highest close in the lookback window. A lowest-close signal opens a BUY at market with stop one ATR below the signal bar low, capped at 80 pips, and a take profit 1.5 ATR above entry; a highest-close signal mirrors this for SELL. Positions also close after three D1 bars if neither stop nor target has executed.

---

## 2. Parameters

| Parameter | Default | Range | Meaning |
|---|---|---|---|
| `strategy_len` | 10 | 2+ | N-bar closing-low/high lookback. |
| `strategy_volume_avg_bars` | 5 | 1+ | Tick-volume average lookback, excluding the signal bar. |
| `strategy_atr_period` | 14 | 1+ | ATR period used for stop and target distances. |
| `strategy_sl_atr_mult` | 1.0 | >0 | ATR multiple placed beyond the signal bar extreme for the stop. |
| `strategy_tp_atr_mult` | 1.5 | >0 | ATR multiple from entry to take profit. |
| `strategy_time_stop_bars` | 3 | 1+ | D1 bars after which an open position is closed. |
| `strategy_sl_cap_pips` | 80.0 | >=0 | Maximum stop distance in pips; 0 disables the cap. |
| `strategy_spread_cap_pips` | 25.0 | >=0 | Maximum entry spread in pips; 0 disables the cap. |

> Note: framework-level inputs (RISK_PERCENT, RISK_FIXED, PORTFOLIO_WEIGHT,
> qm_news_mode, qm_rng_seed, qm_stress_reject_probability, qm_friday_close_*)
> are documented in `framework/V5_FRAMEWORK_DESIGN.md` and are not re-documented here.

---

## 3. Symbol Universe

**Designed for:**
- `EURUSD.DWX` - card-listed D1 FX major with DWX tick volume.
- `GBPUSD.DWX` - card-listed D1 FX major with DWX tick volume.
- `USDJPY.DWX` - card-listed D1 FX major with DWX tick volume.
- `AUDUSD.DWX` - card-listed D1 FX major with DWX tick volume.
- `USDCAD.DWX` - card-listed D1 FX major with DWX tick volume.

**Explicitly NOT for:**
- Non-FX `.DWX` symbols - the card's R3 evidence and filters are for DWX FX tick-volume D1 instruments.

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
| Trades / year / symbol | 15 |
| Typical hold time | up to 3 D1 bars |
| Expected drawdown profile | Mean-reversion losses cluster when low-volume extremes continue into genuine breakouts. |
| Regime preference | mean-revert |
| Win rate target (qualitative) | medium |

---

## 6. Source Citation

This card was mechanised from:

**Source ID:** `29ffaa6d-5bb8-5962-92d9-4e35a35e4d53`
**Source type:** article
**Pointer:** Kevin J. Davey, "My 5 Favorite Entries", Entry #3: Low Volume Reversal.
**R1-R4 verdict (Q00):** all PASS / see `artifacts/cards_approved/QM5_11479_davey-k-low-volume-mean-reversion-d1.md`

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
| v1 | 2026-06-11 | Initial build from card | 1f28c1ea-4bde-4c2c-bd27-fb34a3523050 |
