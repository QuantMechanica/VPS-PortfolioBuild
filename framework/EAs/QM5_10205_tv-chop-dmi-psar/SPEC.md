# QM5_10205_tv-chop-dmi-psar - Strategy Spec

**EA ID:** QM5_10205
**Slug:** tv-chop-dmi-psar
**Source:** 30591366-874b-5bee-b47c-da2fca20b728
**Author of this spec:** Codex
**Last revised:** 2026-06-10

---

## 1. Strategy Logic

This EA trades H1 trend entries from the TradingView CHOP Zone Entry Strategy with DMI/ADX and PSAR exits. It opens long when smoothed CHOP(14) is above 61.8, ADX(14) is above 25, and the PSAR trend state is bullish when follow-trend mode is enabled. It opens short when smoothed CHOP(14) is below 38.2, ADX(14) is above 25, and the PSAR trend state is bearish when follow-trend mode is enabled. It exits on DMI cross with ADX below 25, on a PSAR trend flip, on an opposite entry signal after the current position is closed, or by the CHOP fallback rule when both DMI and PSAR exits are disabled.

---

## 2. Parameters

| Parameter | Default | Range | Meaning |
|---|---:|---|---|
| strategy_chop_period | 14 | 2-100 | Lookback for the Choppiness Index calculation. |
| strategy_chop_smooth | 4 | 1-20 | Simple smoothing length applied to CHOP values. |
| strategy_chop_bull_threshold | 61.8 | 0-100 | CHOP level required for long entries. |
| strategy_chop_bear_threshold | 38.2 | 0-100 | CHOP level required for short entries. |
| strategy_dmi_period | 14 | 2-100 | DMI/ADX period used for entry confirmation and DMI exits. |
| strategy_adx_key_level | 25.0 | 1-100 | Minimum ADX for entries and weak-trend exit level. |
| strategy_follow_trend | true | true/false | Require PSAR trend agreement for entries. |
| strategy_use_dmi_exit | true | true/false | Enable the DMI cross exit rule. |
| strategy_use_psar_exit | true | true/false | Enable the PSAR trend-flip exit rule and PSAR trailing stop. |
| strategy_psar_start | 0.015 | 0.001-1.0 | PSAR acceleration start value from the source defaults. |
| strategy_psar_increment | 0.001 | 0.001-1.0 | PSAR acceleration increment from the source defaults. |
| strategy_psar_maximum | 0.2 | 0.01-1.0 | PSAR maximum acceleration factor from the source defaults. |
| strategy_psar_warmup_bars | 120 | 20-500 | Bounded closed-bar window used to compute PSAR state. |
| strategy_atr_period | 14 | 2-100 | ATR period for the emergency stop. |
| strategy_emergency_atr_mult | 3.0 | 0.1-20.0 | ATR multiple for the emergency stop when PSAR is unavailable or wider. |
| strategy_spread_stop_fraction | 0.15 | 0.0-1.0 | Maximum spread as a fraction of current stop distance. |

---

## 3. Symbol Universe

**Designed for:**
- EURUSD.DWX - card-stated DWX forex target.
- GBPUSD.DWX - card-stated DWX forex target.
- XAUUSD.DWX - card-stated DWX gold target.
- GDAXI.DWX - DWX matrix DAX equivalent used for card-stated GER40.DWX, which is not present in the matrix.
- NDX.DWX - card-stated DWX index target.

**Explicitly NOT for:**
- GER40.DWX - not present in `framework/registry/dwx_symbol_matrix.csv`; replaced by GDAXI.DWX for build registration.

---

## 4. Timeframe

| Aspect | Value |
|---|---|
| Base timeframe | H1 |
| Multi-timeframe refs | none |
| Bar gating | `QM_IsNewBar(_Symbol, PERIOD_CURRENT)` via the V5 skeleton entry gate |

---

## 5. Expected Behaviour

| Metric | Expected |
|---|---|
| Trades / year / symbol | 80 |
| Typical hold time | hours to several days |
| Expected drawdown profile | about 18% expected drawdown from the approved card frontmatter |
| Regime preference | trend-following with CHOP regime gate |
| Win rate target (qualitative) | medium |

---

## 6. Source Citation

This card was mechanised from:

**Source ID:** 30591366-874b-5bee-b47c-da2fca20b728
**Source type:** TradingView script
**Pointer:** TradingView `CHOP Zone Entry Strategy + DMI/PSAR Exit`, author `IronCasper`, updated 2021-01-02, https://www.tradingview.com/script/GrP0zABg-CHOP-Zone-Entry-Strategy-DMI-PSAR-Exit/
**R1-R4 verdict (Q00):** all PASS per `artifacts/cards_approved/QM5_10205_tv-chop-dmi-psar.md`

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
| v1 | 2026-06-10 | Initial build from card | ae692219-9c5a-4391-9ca3-6dc3e3fef6a3 |
