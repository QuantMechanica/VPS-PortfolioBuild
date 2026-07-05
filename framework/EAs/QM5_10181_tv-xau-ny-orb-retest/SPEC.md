# QM5_10181_tv-xau-ny-orb-retest — Strategy Spec

**EA ID:** QM5_10181
**Slug:** `tv-xau-ny-orb-retest`
**Source:** `30591366-874b-5bee-b47c-da2fca20b728` (see `strategy-seeds/sources/tradingview-popular-pine-scripts/`)
**Author of this spec:** Claude
**Last revised:** 2026-07-05

---

## 1. Strategy Logic

The EA uses M5 bars. It computes a 1H EMA(50) for directional bias (long when the last closed 1H bar is above the EMA, short when below). Each day it builds a New York opening range from 09:30 to 09:45 ET (converted from broker time); the day is skipped if the range height exceeds 2.0 × M5 ATR(14). After the range is locked, the EA waits for a confirmed strong-body breakout candle (body ≥ 70% of candle range, range ≥ 1.2 × ATR, close outside the OR level) aligned with the bias. It then waits for price to pull back to the broken OR level and re-close in the breakout direction — that retest bar is the entry. Stop loss is the nearest structural swing pivot below (long) or above (short) the OR level; if the pivot distance is less than 0.5 ATR it is widened to 0.5 ATR; trades are skipped if the distance exceeds 2.5 ATR. Take profit is 2.5R. Any open position is time-exited by 16:00 ET. Maximum one trade per day.

---

## 2. Parameters

| Parameter | Default | Range | Meaning |
|---|---|---|---|
| `strategy_ema_period_h1` | 50 | 5-200 | Period for the 1H directional bias EMA |
| `strategy_atr_period_m5` | 14 | 5-50 | ATR period on M5 for OR-height filter and stop guards |
| `strategy_or_max_atr_mult` | 2.0 | >0 | Skip day if OR height exceeds this ATR multiple |
| `strategy_break_body_ratio` | 0.70 | 0-1 | Breakout candle body/range minimum ratio |
| `strategy_break_range_atr_mult` | 1.20 | >0 | Breakout candle range minimum as ATR multiple |
| `strategy_pivot_left` | 3 | 1-20 | Left bars required for swing pivot confirmation |
| `strategy_pivot_right` | 3 | 1-20 | Right bars required for swing pivot confirmation |
| `strategy_pivot_scan_bars` | 48 | 10-200 | How far back to scan for a swing pivot stop |
| `strategy_min_stop_atr_mult` | 0.50 | >=0 | Widen stop to this ATR multiple if pivot is too close |
| `strategy_max_stop_atr_mult` | 2.50 | >0 | Skip trade if stop exceeds this ATR multiple |
| `strategy_take_profit_rr` | 2.50 | >0 | Take-profit distance as RR multiple of stop |
| `strategy_or_start_hhmm_ny` | 930 | 0-2359 | Opening range start in New York time (HHMM) |
| `strategy_or_end_hhmm_ny` | 945 | 0-2359 | Opening range end in New York time (HHMM) |
| `strategy_time_exit_hhmm_ny` | 1600 | 0-2359 | Force-close time in New York time (HHMM) |

> Note: framework-level inputs (RISK_PERCENT, RISK_FIXED, PORTFOLIO_WEIGHT,
> qm_news_mode, qm_rng_seed, qm_stress_reject_probability, qm_friday_close_*)
> are documented in `framework/V5_FRAMEWORK_DESIGN.md` — do NOT re-document
> them here. Only list strategy-specific inputs.

---

## 3. Symbol Universe

**Designed for:**
- `XAUUSD.DWX` — Primary card target; TradingView source is XAUUSD-specific. DWX custom symbol fully supported.
- `NDX.DWX` — Card R3 secondary robustness port; NY-session ORB mechanics apply to US index CFDs.
- `WS30.DWX` — Card R3 secondary robustness port; same NY-session coverage.
- `GDAXI.DWX` — Card R3 lists GER40.DWX; GDAXI.DWX is the DWX matrix canonical for DAX 40 (GER40.DWX is not in the matrix).

**Explicitly NOT for:**
- `GER40.DWX` — Not present in `dwx_symbol_matrix.csv`; GDAXI.DWX substituted.
- Forex pairs with Asian-session dominant liquidity — strategy is tuned to the NY 09:30 open.

---

## 4. Timeframe

| Aspect | Value |
|---|---|
| Base timeframe | `M5` |
| Multi-timeframe refs | `H1` (EMA bias read, single closed bar) |
| Bar gating | `QM_IsNewBar(_Symbol, PERIOD_CURRENT)` |

---

## 5. Expected Behaviour

| Metric | Expected |
|---|---|
| Trades / year / symbol | ~110 |
| Typical hold time | Intraday; flat by 16:00 ET |
| Expected drawdown profile | One trade per day maximum; stop size 0.5-2.5 ATR |
| Regime preference | Opening-range breakout with retest confirmation |
| Win rate target (qualitative) | Medium; 2.5R target with strong-candle filter |

---

## 6. Source Citation

This card was mechanised from:

**Source ID:** `30591366-874b-5bee-b47c-da2fca20b728`
**Source type:** TradingView open-source strategy
**Pointer:** https://www.tradingview.com/script/XhSNuRUR-XAUUSD-NY-ORB-Advanced/ (author: DanTheMan278, published 2026-05-16)
**R1–R4 verdict (Q00):** all PASS / see `artifacts/cards_approved/QM5_10181_tv-xau-ny-orb-retest.md`

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
| v1 | 2026-05-24 | Initial build from card | prior session |
| v2 | 2026-07-05 | OnTick ordering fix (2026-07-02 audit); SPEC.md added | a3419ae6-bcf4-4a32-bd55-c9b834db0626 |
