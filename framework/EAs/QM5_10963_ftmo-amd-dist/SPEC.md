# QM5_10963_ftmo-amd-dist — Strategy Spec

**EA ID:** QM5_10963
**Slug:** `ftmo-amd-dist`
**Source:** `c11dc4d3-bdfb-5076-aeed-5d943e9ef03f` (FTMO AMD article)
**Author of this spec:** Claude
**Last revised:** 2026-06-06

---

## 1. Strategy Logic

This EA trades the FTMO Accumulation–Manipulation–Distribution (AMD) pattern on
M15 during the London and New York sessions. At each session open it measures an
"accumulation" range over the first 8 M15 bars; the range is valid only when its
width is 0.4–1.2× ATR(14,M15) (and ≤ 1.8× ATR as an explicit skip cap) and its
average tick volume is no higher than the 20-bar tick-volume average. It then
waits, in the direction of the H1 trend bias (bullish when H1 close > EMA(50) and
EMA(50) > EMA(200); bearish for the mirror), for a liquidity sweep that pushes at
least 0.25× ATR beyond the accumulation edge. After such a manipulation sweep, if
price closes back inside the range and then closes beyond the opposite accumulation
edge on a bar whose tick volume is ≥ 1.2× its 20-bar average (all within 6 M15 bars),
the EA enters at market in the bias direction. Stop loss sits 0.2× ATR beyond the
manipulation extreme; the final take-profit is 2.5× R, the stop is moved to
break-even once price reaches +1R, and any open trade is closed at the end of the
active session. One attempt per symbol per session.

---

## 2. Parameters

| Parameter | Default | Range | Meaning |
|---|---|---|---|
| `strat_sess1_start_hhmm` | 1000 | 0-2359 | London accumulation start (broker time) |
| `strat_sess1_end_hhmm` | 1700 | 0-2359 | London session time-exit (broker time) |
| `strat_sess2_start_hhmm` | 1500 | 0-2359 | New York accumulation start (broker time) |
| `strat_sess2_end_hhmm` | 2200 | 0-2359 | New York session time-exit (broker time) |
| `strat_acc_bars` | 8 | 4-16 | Accumulation window length in M15 bars |
| `strat_setup_window_bars` | 6 | 2-12 | Sweep / reclaim search window in M15 bars |
| `strat_atr_period` | 14 | 5-50 | ATR(M15) period |
| `strat_vol_avg_period` | 20 | 10-50 | Tick-volume average window (M15 bars) |
| `strat_acc_range_atr_max` | 1.2 | 0.5-2.0 | Max accumulation range as multiple of ATR |
| `strat_acc_range_atr_min` | 0.4 | 0.1-1.0 | Skip if accumulation range < mult × ATR |
| `strat_acc_range_atr_cap` | 1.8 | 1.0-3.0 | Skip if accumulation range > mult × ATR |
| `strat_sweep_atr_mult` | 0.25 | 0.1-1.0 | Sweep depth past range edge (× ATR) |
| `strat_sl_atr_buffer` | 0.2 | 0.0-1.0 | SL buffer past manipulation extreme (× ATR) |
| `strat_vol_confirm_mult` | 1.2 | 1.0-2.0 | Breakout volume ≥ mult × 20-bar average |
| `strat_tp_r_mult` | 2.5 | 1.0-5.0 | Final take-profit at mult × R |
| `strat_ema_fast` | 50 | 10-100 | H1 bias fast EMA period |
| `strat_ema_slow` | 200 | 100-400 | H1 bias slow EMA period |

---

## 3. Symbol Universe

**Designed for:**
- `EURUSD.DWX` — deep, liquid FX major with clean London/NY session structure and tick volume.
- `GBPUSD.DWX` — high session-driven volatility; strong AMD sweep behaviour around London.
- `XAUUSD.DWX` — metal with pronounced session liquidity sweeps; AMD distribution common.
- `NDX.DWX` — US index (Nasdaq 100, live-tradable) with strong NY-session manipulation moves.

**Explicitly NOT for:**
- `SP500.DWX` — backtest-only (broker does not route orders); not registered for this EA.

---

## 4. Timeframe

| Aspect | Value |
|---|---|
| Base timeframe | `M15` |
| Multi-timeframe refs | `H1 EMA(50)/EMA(200) + H1 close for trend bias` |
| Bar gating | `QM_IsNewBar(_Symbol, PERIOD_CURRENT)` (default) |

---

## 5. Expected Behaviour

| Metric | Expected |
|---|---|
| Trades / year / symbol | `~55 (card range 35-80)` |
| Typical hold time | `intraday — minutes to a few hours, closed by session end` |
| Expected drawdown profile | `controlled; SL at manipulation extreme, BE after 1R, 2.5R target` |
| Regime preference | `breakout / volatility-expansion off failed session sweeps` |
| Win rate target (qualitative) | `medium` |

---

## 6. Source Citation

This card was mechanised from:

**Source ID:** `c11dc4d3-bdfb-5076-aeed-5d943e9ef03f`
**Source type:** `institutional blog (FTMO)`
**Pointer:** `https://ftmo.com/en/how-to-use-accumulation-manipulation-and-distribution-in-trading/`
**R1–R4 verdict (Q00):** all PASS / see `artifacts/cards_approved/QM5_10963_ftmo-amd-dist.md`

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
| v1 | 2026-06-06 | Initial build from card | 9d53c11a-621d-4d81-b842-03a07fe8d7d5 |
