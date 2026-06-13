# QM5_10346_et-turtle-intra - Strategy Spec

**EA ID:** QM5_10346
**Slug:** et-turtle-intra
**Source:** d6ae8bae-7b94-5209-9be7-fb72a1c3e3fe
**Author of this spec:** Codex
**Last revised:** 2026-06-13

---

## 1. Strategy Logic

This EA evaluates completed H1 bars for Turtle-style Donchian breakouts. System 1 enters long when the H1 close is above the prior 20-bar high, enters short when it is below the prior 20-bar low, and exits on the opposing prior 10-bar channel. System 2 uses a wider 55-bar entry channel and 20-bar exit channel, and is preferred when both systems trigger on the same bar. System 1 signals are skipped after the previous System 1 trade on the same symbol closed profitably; entries use a 2.0 ATR(20) protective stop and channel-based stop tightening.

---

## 2. Parameters

| Parameter | Default | Range | Meaning |
|---|---:|---|---|
| strategy_system1_entry_bars | 20 | 1 or higher | System 1 Donchian entry lookback. |
| strategy_system1_exit_bars | 10 | 1 or higher | System 1 opposing Donchian exit lookback. |
| strategy_system2_entry_bars | 55 | 1 or higher | System 2 Donchian entry lookback. |
| strategy_system2_exit_bars | 20 | 1 or higher | System 2 opposing Donchian exit lookback. |
| strategy_atr_period | 20 | 1 or higher | ATR period for initial stop and channel width filter. |
| strategy_atr_stop_mult | 2.0 | greater than 0 | Initial protective stop distance in ATR multiples. |
| strategy_min_channel_atr_mult | 1.5 | 0 or higher | Minimum Donchian channel width as an ATR multiple; 0 disables. |
| strategy_skip_s1_after_win | true | true or false | Skip System 1 after the last System 1 winner on the same symbol. |
| strategy_session_start_hour | 7 | 0 to 23 | Broker-hour start for the liquid-session gate. |
| strategy_session_end_hour | 20 | 0 to 24 | Broker-hour end for the liquid-session gate. |
| strategy_max_spread_points | 80.0 | 0 or higher | Maximum spread in points; 0 disables the spread gate. |
| strategy_max_hold_bars | 480 | 0 or higher | Catastrophic time stop in H1 bars; 0 disables. |

---

## 3. Symbol Universe

**Designed for:**
- EURUSD.DWX - liquid major FX pair with native DWX data and continuous H1 bars.
- GBPUSD.DWX - liquid major FX pair with native DWX data and enough intraday trend behavior for Donchian tests.
- USDJPY.DWX - liquid major FX pair with native DWX data and distinct session participation.
- XAUUSD.DWX - liquid metal CFD with native DWX data and trend-following suitability.
- GDAXI.DWX - available DWX DAX custom symbol used as the matrix-valid port of the card's GER40.DWX leg.

**Explicitly NOT for:**
- GER40.DWX - card-stated DAX name, but absent from `framework/registry/dwx_symbol_matrix.csv`.

---

## 4. Timeframe

| Aspect | Value |
|---|---|
| Base timeframe | H1 |
| Multi-timeframe refs | none |
| Bar gating | `QM_IsNewBar(_Symbol, PERIOD_CURRENT)` via framework `OnTick` |

---

## 5. Expected Behaviour

| Metric | Expected |
|---|---|
| Trades / year / symbol | 35 |
| Expected trade frequency | H1 Donchian breakout with 20/10 or 55/20 channels; conservative estimate 35 trades/year/symbol after skip-after-win and session filters. |
| Typical hold time | Hours to 20 trading days, bounded by channel exits and the catastrophic time stop. |
| Expected drawdown profile | Many small losses with occasional larger trend capture. |
| Regime preference | Intraday trend-following breakout and volatility expansion. |
| Win rate target (qualitative) | low to medium |

---

## 6. Source Citation

This card was mechanised from:

**Source ID:** d6ae8bae-7b94-5209-9be7-fb72a1c3e3fe
**Source type:** forum
**Pointer:** Elite Trader thread by handle `1a2b3cppp`: `https://www.elitetrader.com/et/threads/has-anyone-tried-turtle-methodology-intraday-here-are-the-rules.216252/`
**R1-R4 verdict (Q00):** all PASS per `artifacts/cards_approved/QM5_10346_et-turtle-intra.md`

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
| v1 | 2026-06-13 | Initial build from card | cc219676-e3fe-48a0-a7c0-4fb327e1e475 |
