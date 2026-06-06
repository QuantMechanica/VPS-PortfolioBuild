# QM5_10936_grimes-accum-close - Strategy Spec

**EA ID:** QM5_10936
**Slug:** `grimes-accum-close`
**Source:** `fbfd7f6e-462a-55c8-9efa-9005a70c9f5c` (see approved strategy card)
**Author of this spec:** Codex
**Last revised:** 2026-06-06

---

## 1. Strategy Logic

The EA trades M15 index breakouts after an intraday accumulation phase. The first eight M15 bars of the configured liquid session define the opening range, bars 9 through 22 must remain compressed around that midpoint, and the setup requires at least two failed probes through the prior eight-bar extreme that close back inside the opening range. It enters long on a late close above the consolidation high after 60% of the session has elapsed, or short on the mirrored close below the consolidation low. The stop is placed 0.25 ATR beyond the consolidation, the target is 1.5R, the stop moves to breakeven at 0.8R, and the EA exits at session close or after two closed bars back inside the consolidation.

---

## 2. Parameters

| Parameter | Default | Range | Meaning |
|---|---|---|---|
| `strategy_timeframe` | `PERIOD_M15` | M15 expected | Timeframe for the setup rules. |
| `strategy_session_start_hhmm` | `1400` | 0000-2359 | Broker-time liquid session start. |
| `strategy_session_end_hhmm` | `2200` | 0000-2359 | Broker-time session close and forced exit time. |
| `strategy_opening_range_bars` | `8` | 1-12 | Number of first session bars used for the opening range. |
| `strategy_consolidation_start_bar` | `9` | 2-30 | First session bar in the consolidation window. |
| `strategy_consolidation_end_bar` | `22` | 3-40 | Last session bar in the consolidation window. |
| `strategy_atr_period` | `20` | 5-100 | ATR period used for compression, probes, stop, and breakout-bar checks. |
| `strategy_ema_period` | `20` | 5-100 | EMA period used as the VWAP proxy. |
| `strategy_adx_period` | `14` | 5-100 | ADX period for the pre-breakout range filter. |
| `strategy_midpoint_atr_mult` | `1.50` | 0.5-5.0 | Maximum distance from the opening-range midpoint during consolidation. |
| `strategy_probe_atr_mult` | `0.10` | 0.01-1.0 | Minimum failed-probe depth through the prior eight-bar extreme. |
| `strategy_vwap_proxy_atr_mult` | `0.75` | 0.1-3.0 | Maximum close distance beyond EMA(20) during consolidation. |
| `strategy_adx_max_before_breakout` | `30.0` | 5-60 | Rejects pre-breakout trend strength above this ADX value. |
| `strategy_breakout_bar_atr_max` | `2.0` | 0.5-5.0 | Rejects terminal breakout bars larger than this ATR multiple. |
| `strategy_stop_atr_mult` | `0.25` | 0.05-2.0 | ATR buffer beyond the consolidation for the stop. |
| `strategy_target_r_mult` | `1.50` | 0.5-5.0 | Profit target in R. |
| `strategy_breakeven_r_mult` | `0.80` | 0.1-3.0 | R multiple that moves the stop to breakeven. |
| `strategy_min_width_r_mult` | `0.75` | 0.1-2.0 | Minimum consolidation width versus R after spread cost. |
| `strategy_max_spread_points` | `500` | 1-5000 | Entry spread ceiling in points. |
| `strategy_history_bars` | `96` | 32-300 | Bounded M15 bars read for session structure. |

---

## 3. Symbol Universe

**Designed for:**
- `SP500.DWX` - S&P 500 custom symbol matching the card's US index target.
- `NDX.DWX` - Nasdaq 100 index CFD for liquid US large-cap breakout behaviour.
- `WS30.DWX` - Dow 30 index CFD for liquid US large-cap breakout behaviour.
- `GDAXI.DWX` - Matrix-listed DAX custom symbol used for the card's GER40/DAX leg.

**Explicitly NOT for:**
- Forex pairs - the card is built around index session behaviour.
- Single-stock CFDs - the card targets broad index accumulation and breakout pressure.

---

## 4. Timeframe

| Aspect | Value |
|---|---|
| Base timeframe | `M15` |
| Multi-timeframe refs | none |
| Bar gating | `QM_IsNewBar(_Symbol, PERIOD_CURRENT)` via framework entry hook |

---

## 5. Expected Behaviour

| Metric | Expected |
|---|---|
| Trades / year / symbol | `18` |
| Typical hold time | Intraday; target or same-session close. |
| Expected drawdown profile | Breakout failures cluster in choppy late-session conditions. |
| Regime preference | Late-session accumulation range breakout. |
| Win rate target (qualitative) | Medium. |

---

## 6. Source Citation

This card was mechanised from:

**Source ID:** `fbfd7f6e-462a-55c8-9efa-9005a70c9f5c`
**Source type:** blog
**Pointer:** Adam H. Grimes, "Beyond the News: A Dive Into Breakout Behavior", 2023-10-09, https://www.adamhgrimes.com/beyond-the-news-a-dive-into-breakout-behavior/
**R1-R4 verdict (Q00):** all PASS / see `artifacts/cards_approved/QM5_10936_grimes-accum-close.md`

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
| v1 | 2026-06-06 | Initial build from card | a238482d-1160-4f7b-a9a8-9d32af5837df |
