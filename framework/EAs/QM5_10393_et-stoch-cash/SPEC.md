# QM5_10393_et-stoch-cash - Strategy Spec

**EA ID:** QM5_10393
**Slug:** et-stoch-cash
**Source:** d6ae8bae-7b94-5209-9be7-fb72a1c3e3fe
**Author of this spec:** Codex
**Last revised:** 2026-05-25

---

## 1. Strategy Logic

The EA trades M5 index data during the mapped regular session. A long entry is taken on a completed bar when tick volume is above its 20-bar median, fast stochastic %K crosses above 50, and fast %K is above fast %D. A short entry is the mirror image, with fast %K crossing below 50 and below fast %D. Open trades are closed when the slow stochastic level or %K/%D cross exits, when fast %K crosses back through the midline, or when the mapped session close is reached.

---

## 2. Parameters

| Parameter | Default | Range | Meaning |
|---|---:|---|---|
| strategy_fast_k_period | 5 | 5-8 | Fast stochastic %K length for entry crosses. |
| strategy_fast_d_period | 3 | 3 | Fast stochastic %D smoothing. |
| strategy_fast_slowing | 3 | 3 | Fast stochastic slowing. |
| strategy_slow_k_period | 14 | 14-21 | Slow stochastic %K length for exits. |
| strategy_slow_d_period | 3 | 3 | Slow stochastic %D smoothing. |
| strategy_slow_slowing | 3 | 3 | Slow stochastic slowing. |
| strategy_entry_midline | 50.0 | 45.0-55.0 | Fast stochastic midline entry and fast exit threshold. |
| strategy_slow_long_exit | 80.0 | 80.0 | Long slow-stochastic level exit. |
| strategy_slow_short_exit | 20.0 | 20.0 | Short slow-stochastic level exit. |
| strategy_use_volume_filter | true | true/false | Require signal-bar tick volume above the 20-bar median. |
| strategy_volume_lookback | 20 | 20 | Tick-volume median lookback. |
| strategy_session_start_hhmm | 1630 | broker HHMM | Mapped regular-session start. |
| strategy_session_flat_hhmm | 2200 | broker HHMM | Mapped 15:00 source-time/session-flat close. |
| strategy_atr_period | 14 | 14 | Protective ATR stop period. |
| strategy_atr_sl_mult | 1.5 | 1.0-2.0 | Protective ATR stop multiple. |
| strategy_min_stop_spreads | 4 | 4 | Minimum stop distance in current spreads. |
| strategy_max_spread_points | 250 | positive integer | Maximum spread allowed for new entries. |

---

## 3. Symbol Universe

**Designed for:**
- SP500.DWX - S&P 500 custom symbol matching the source's ES/SPX-style index exposure; backtest-only per DWX discipline.
- NDX.DWX - Nasdaq 100 live-tradable US large-cap index analogue.
- WS30.DWX - Dow 30 live-tradable US large-cap index analogue.
- GDAXI.DWX - available DAX custom symbol used as the matrix-valid port for the card's GER40.DWX target.

**Explicitly NOT for:**
- GER40.DWX - not present in `dwx_symbol_matrix.csv`; ported to GDAXI.DWX.
- SPX500.DWX, SPY.DWX, ES.DWX - unavailable phantom S&P variants; SP500.DWX is the only registered S&P 500 custom symbol.

---

## 4. Timeframe

| Aspect | Value |
|---|---|
| Base timeframe | M5 |
| Multi-timeframe refs | none |
| Bar gating | `QM_IsNewBar(_Symbol, PERIOD_CURRENT)` (default) |

---

## 5. Expected Behaviour

| Metric | Expected |
|---|---|
| Trades / year / symbol | 160 |
| Typical hold time | Intraday, usually minutes to same-session close |
| Expected drawdown profile | High-cadence oscillator drawdowns driven by transaction costs and choppy regimes |
| Regime preference | Intraday stochastic momentum during regular sessions |
| Win rate target (qualitative) | medium |

---

## 6. Source Citation

This card was mechanised from:

**Source ID:** d6ae8bae-7b94-5209-9be7-fb72a1c3e3fe
**Source type:** forum
**Pointer:** https://www.elitetrader.com/et/threads/chicken-little-studies-the-hershey-methods.150691/
**R1-R4 verdict (Q00):** all PASS / see `artifacts/cards_approved/QM5_10393_et-stoch-cash.md`

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
| v1 | 2026-05-25 | Initial build from card | 53099837-7469-4127-b32a-35c1fe0f994d |
