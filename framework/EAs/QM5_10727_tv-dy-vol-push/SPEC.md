# QM5_10727_tv-dy-vol-push - Strategy Spec

**EA ID:** QM5_10727
**Slug:** `tv-dy-vol-push`
**Source:** `d11962d5-19ca-5b8b-b5fc-e3bd0a620ed7` (TradingView protected-source script)
**Author of this spec:** Codex
**Last revised:** 2026-05-31

---

## 1. Strategy Logic

The EA trades an intraday opening-range volume breakout on M1 bars. It records the high, low, and peak tick volume of the first five broker-time minutes after the configured session open, then allows entries for two hours after the sample window. A long opens when a closed M1 bar closes above the opening range high with tick volume at least 75 percent of the opening peak; a short opens on the mirrored break below the opening range low. If the first break direction has already occurred, only the opposite-side break can create the second daily trade, matching the card's reversal mode.

Exits are the broker TP at 2.0R, broker SL at the wider structure stop, or a session-end flat close at the configured broker-time close. The structure stop is below the lower of opening-range low and the post-sample low for longs, and above the higher of opening-range high and post-sample high for shorts; trades are skipped when that stop is outside the card's 0.3x to 3.0x ATR(14) distance band.

---

## 2. Parameters

| Parameter | Default | Range | Meaning |
|---|---:|---|---|
| `strategy_session_open_hour` | 16 | 0-23 | Broker-time hour used as the session open. |
| `strategy_session_open_minute` | 30 | 0-59 | Broker-time minute used as the session open. |
| `strategy_session_close_hour` | 22 | 0-23 | Broker-time hour for the session-end flat exit. |
| `strategy_session_close_minute` | 55 | 0-59 | Broker-time minute for the session-end flat exit. |
| `strategy_sample_minutes` | 5 | >=1 | Number of M1 bars used to form the opening range and volume peak. |
| `strategy_entry_window_hours` | 2.0 | >0 | Hours after the sample window where breakout entries are allowed. |
| `strategy_volume_threshold_pct` | 75.0 | 1-100+ | Breakout-bar tick volume threshold as percent of opening peak volume. |
| `strategy_max_trades_per_day` | 2 | >=1 | Maximum daily signal count per magic number. |
| `strategy_atr_period` | 14 | >=1 | ATR period used for stop-distance validation. |
| `strategy_min_stop_atr` | 0.3 | >0 | Minimum stop distance as ATR multiple. |
| `strategy_max_stop_atr` | 3.0 | >0 | Maximum stop distance as ATR multiple. |
| `strategy_rr` | 2.0 | >0 | Take-profit reward:risk multiple. |
| `strategy_stop_buffer_points` | 1 | >=0 | Point buffer placed beyond the selected structure stop. |
| `strategy_max_spread_points` | 0 | >=0 | Optional flat-entry spread cap; 0 disables it because the card gives no spread filter. |

---

## 3. Symbol Universe

**Designed for:**
- `NDX.DWX` - US large-cap index exposure with liquid intraday movement.
- `WS30.DWX` - US large-cap index exposure and the available Dow 30 basket member.
- `GDAXI.DWX` - Verified DWX DAX symbol used as the available port for card-stated `GER40.DWX`.
- `SP500.DWX` - S&P 500 custom symbol; valid for backtest only per DWX symbol discipline.
- `XAUUSD.DWX` - Metal exposure listed directly by the card and available in the DWX matrix.

**Explicitly NOT for:**
- `GER40.DWX` - Card-stated name is not present in `dwx_symbol_matrix.csv`; this build registers `GDAXI.DWX` instead.
- `SPX500.DWX`, `SPY.DWX`, `ES.DWX` - Not canonical available DWX symbols for S&P 500 exposure.

---

## 4. Timeframe

| Aspect | Value |
|---|---|
| Base timeframe | `M1` |
| Multi-timeframe refs | none |
| Bar gating | `QM_IsNewBar(_Symbol, PERIOD_CURRENT)` (framework default before `Strategy_EntrySignal`) |

---

## 5. Expected Behaviour

| Metric | Expected |
|---|---|
| Trades / year / symbol | `160` |
| Typical hold time | Intraday; exits by SL, 2.0R TP, or same-session flat close. |
| Expected drawdown profile | Breakout/reversal profile with losses bounded by structure stop filtered to 0.3x-3.0x ATR(14). |
| Regime preference | Volatility expansion / opening-range breakout. |
| Win rate target (qualitative) | Medium; reward:risk baseline is 2.0R. |

---

## 6. Source Citation

This card was mechanised from:

**Source ID:** `d11962d5-19ca-5b8b-b5fc-e3bd0a620ed7`
**Source type:** TradingView protected-source strategy
**Pointer:** TradingView script `D.Y Volume Push / Reversal Strategy`, author handle `Yeruham`, published Jan 24 2026, `https://www.tradingview.com/script/G6Rt77Y6-D-Y-Volume-Push-Reversal-Strategy/`
**R1-R4 verdict (Q00):** all R1-R4 PASS per `artifacts/cards_approved/QM5_10727_tv-dy-vol-push.md`

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
| v1 | 2026-05-31 | Initial build from card | b31d4fd3-5ec0-4275-a83e-ee38eda90dcd |
