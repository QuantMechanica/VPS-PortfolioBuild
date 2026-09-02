# QM5_41283_audusd-dollar-stress-tr — Strategy Spec

**EA ID:** QM5_41283
**Slug:** `audusd-dollar-stress-tr`
**Source:** `AI-CODEX-AUDUSD-DOLLAR-STRESS-TREND-20260902` (see `strategy-seeds/sources/AI-CODEX-AUDUSD-DOLLAR-STRESS-TREND-20260902/`)
**Author of this spec:** Codex
**Last revised:** 2026-09-02

---

## 1. Strategy Logic

Once per new AUDUSD D1 bar, the EA aligns the latest completed AUDUSD,
EURUSD, GBPUSD, and SP500 bars. It shorts AUDUSD only when SP500 closes below
the mean of its prior 50 closes with a negative 20-session return, the mean
five-session return of EURUSD/GBPUSD/AUDUSD is at most -1%, and AUDUSD closes
strictly below its prior 20 daily lows. The position starts with a two-ATR hard
stop, trails only tighter at completed close plus two ATR, and exits when the
composite stress gate clears or after ten D1 bar shifts.

## 2. Parameters

| Parameter | Default | Range | Meaning |
|---|---:|---:|---|
| `strategy_signal_tf` | `PERIOD_D1` | locked D1 | Signal, execution, and management timeframe |
| `strategy_sp_sma_days` | 50 | locked 50 | Ex-current SP500 close-mean window |
| `strategy_sp_return_days` | 20 | locked 20 | SP500 simple-return interval |
| `strategy_usd_return_days` | 5 | locked 5 | Simple-return interval for each USD cross |
| `strategy_usd_threshold` | -0.010 | locked -0.010 | Inclusive mean EURUSD/GBPUSD/AUDUSD return boundary |
| `strategy_breakout_days` | 20 | locked 20 | Prior completed AUDUSD-low window |
| `strategy_atr_period` | 14 | locked 14 | Completed D1 ATR period |
| `strategy_stop_atr` | 2.0 | locked 2.0 | Initial hard-stop ATR multiple |
| `strategy_trail_atr` | 2.0 | locked 2.0 | Monotone close-plus-ATR trail multiple |
| `strategy_max_hold_bars` | 10 | locked 10 | Maximum D1 bar shifts from broker open time |
| `strategy_max_spread_points` | 50 | locked 50 | Positive-spread entry ceiling; zero tester spread is valid |
| `strategy_deviation_points` | 20 | locked 20 | Framework market-order deviation allowance |

## 3. Symbol Universe

**Designed for:**

- `AUDUSD.DWX` — the only execution carrier and the commodity-currency side of the approved dollar-stress hypothesis.
- `EURUSD.DWX` — signal-only broad-USD component; it never receives an order.
- `GBPUSD.DWX` — signal-only broad-USD component; it never receives an order.
- `SP500.DWX` — signal-only global-stress regime input; it never receives an order.

**Explicitly NOT for:**

- `NZDUSD.DWX` — the source names it as a possible sibling, but the approved single-symbol baseline requires a separate identity and validation.
- Any JPY or CHF cross — those express a different safe-haven/carry-unwind mechanism.
- Any symbol absent from `dwx_symbol_matrix.csv` — unsupported runtime data are forbidden.

## 4. Timeframe

| Aspect | Value |
|---|---|
| Base timeframe | `D1` |
| Multi-timeframe refs | none; all four symbols use synchronized D1 bars |
| Bar gating | one `QM_IsNewBar(AUDUSD.DWX, PERIOD_D1)` consume per tick |

## 5. Expected Behaviour

| Metric | Expected |
|---|---|
| Trades / year / symbol | approximately 12; retire below 10 distinct entry days in any full post-warm-up year |
| Typical hold time | one to ten D1 bar shifts |
| Expected drawdown profile | sparse clustered losses and gap risk around violent risk-off reversals |
| Regime preference | global risk-off dollar-strength continuation |
| Win rate target (qualitative) | low to medium; payoff must come from sustained downside continuation |

## 6. Source Citation

This card was mechanised from:

**Source ID:** `AI-CODEX-AUDUSD-DOLLAR-STRESS-TREND-20260902`
**Source type:** OWNER research program plus bounded official journal abstracts and governed synthesis
**Pointer:** `strategy-seeds/sources/AI-CODEX-AUDUSD-DOLLAR-STRESS-TREND-20260902/source.md`
**R1–R4 verdict (Q00):** bounded R1 plus R2–R4 PASS; see `strategy-seeds/cards/approved/QM5_41283_audusd-dollar-stress-tr_card.md`

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
| v1 | 2026-09-02 | Initial build from card | agent task `3e575e50-46b2-46f4-8601-ad4344fd5449` |
